//+------------------------------------------------------------------+
//|                                          36_Trade_Copier_EA.mq5   |
//|                                    My Algo Stack - Trading Infrastructure   |
//+------------------------------------------------------------------+
//| UTILITY: Local Trade Copier                                        |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Copies trades between MT5 terminals on the same computer.         |
//| Can work as Master (sender) or Slave (receiver).                  |
//|                                                                    |
//| FEATURES:                                                          |
//| - Copy trades between accounts                                    |
//| - Lot size multiplier                                             |
//| - Reverse copy option                                             |
//| - Symbol mapping                                                   |
//| - Copy SL/TP or set custom                                        |
//|                                                                    |
//| HOW TO USE:                                                        |
//| 1. Run as MASTER on source account                                |
//| 2. Run as SLAVE on destination account                            |
//| 3. Both must use same file path                                   |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

//=============================================================================
// LICENSE CONFIGURATION - DO NOT MODIFY
//=============================================================================
#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "trade_copier_ea"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200  // Check every 12 hours (in seconds)
#define LICENSE_GRACE_PERIOD 86400    // 24 hours grace if server unreachable

//=============================================================================
// USER INPUT PARAMETERS
//=============================================================================
input string   LicenseKey = "";          // License Key (from dashboard)
enum COPIER_MODE { MODE_MASTER, MODE_SLAVE };

input COPIER_MODE Mode = MODE_SLAVE;
input string      SignalFile = "trade_signal.txt";
input double      LotMultiplier = 1.0;
input bool        ReverseTrades = false;
input bool        CopySLTP = true;
input int         CustomSL = 0;          // Custom SL pips (0 = copy from master)
input int         CustomTP = 0;          // Custom TP pips (0 = copy from master)
input int         MagicNumber = 100036;

//--- MONEY MANAGEMENT ---
input bool     UseMoneyManagement = true;   // Use Risk % for Lot Size
input double   RiskPercent        = 2.0;    // Risk per trade (%)

//--- TRAILING STOP & BREAK EVEN ---
input bool     UseTrailingStop    = true;   // Enable Trailing Stop
input int      TrailingStop       = 50;     // Trailing Stop (points)
input int      TrailingStep       = 10;     // Trailing Step (points)

input bool     UseBreakEven       = true;   // Enable Break Even
input int      BreakEvenTrigger   = 30;     // Points profit to trigger BE
input int      BreakEvenLock      = 5;      // Points to lock in profit

//--- FORWARD DECLARATIONS ---
void ManagePositions();
double GetLotSize(double slPoints);

string g_lastSignal = "";

//=============================================================================
// LICENSE VALIDATOR (EMBEDDED - NO EXTERNAL FILES NEEDED)
//=============================================================================
datetime g_lastValidation = 0;
bool g_isLicensed = false;
string g_licenseError = "";

bool ValidateLicense()
{
   if(StringLen(LicenseKey) < 10)
   {
      g_licenseError = "Invalid License Key. Get your key from the dashboard.";
      return false;
   }
   
   string accountNum = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   string broker = AccountInfoString(ACCOUNT_COMPANY);
   
   string jsonBody = StringFormat(
      "{\"accountNumber\":\"%s\",\"brokerName\":\"%s\",\"eaCode\":\"%s\",\"eaVersion\":\"%s\",\"terminalType\":\"MT5\"}",
      accountNum, broker, LICENSE_EA_CODE, LICENSE_EA_VERSION
   );
   
   string headers = StringFormat("Content-Type: application/json\r\nX-API-Key: %s", LicenseKey);
   
   char postData[];
   char resultData[];
   string resultHeaders;
   
   StringToCharArray(jsonBody, postData, 0, StringLen(jsonBody));
   ArrayResize(postData, StringLen(jsonBody));
   
   int statusCode = WebRequest("POST", LICENSE_API_URL, headers, 10000, postData, resultData, resultHeaders);
   
   if(statusCode == -1)
   {
      int err = GetLastError();
      if(err == 4060)
         g_licenseError = "Add URL to allowed list: Tools -> Options -> Expert Advisors -> Add: https://myalgostack.com";
      else
         g_licenseError = "Server connection failed. Error: " + IntegerToString(err);
      
      if(g_lastValidation > 0 && (TimeCurrent() - g_lastValidation) < LICENSE_GRACE_PERIOD)
         return g_isLicensed;
      return false;
   }
   
   string response = CharArrayToString(resultData);
   bool isValid = (StringFind(response, "\"valid\":true") >= 0);
   
   if(!isValid)
   {
      int msgStart = StringFind(response, "\"message\":\"") + 11;
      int msgEnd = StringFind(response, "\"", msgStart);
      if(msgStart > 10 && msgEnd > msgStart)
         g_licenseError = StringSubstr(response, msgStart, msgEnd - msgStart);
      else
         g_licenseError = "License validation failed. Check your License Key.";
   }
   
   g_lastValidation = TimeCurrent();
   g_isLicensed = isValid;
   return isValid;
}

bool PeriodicLicenseCheck()
{
   if(!g_isLicensed) return false;
   if((TimeCurrent() - g_lastValidation) < LICENSE_CHECK_INTERVAL) return true;
   return ValidateLicense();
}


int OnInit()
{
   Print("Validating license...");
   
   if(!ValidateLicense())
   {
      Print("LICENSE ERROR: ", g_licenseError);
      Alert("License Error: ", g_licenseError);
      return INIT_FAILED;
   }
   
   Print("License validated successfully!");
   Print("Account: ", AccountInfoInteger(ACCOUNT_LOGIN), " | Broker: ", AccountInfoString(ACCOUNT_COMPANY));
   
   Print("Trade Copier EA initialized as ", Mode == MODE_MASTER ? "MASTER" : "SLAVE");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   }

void OnTick()
{
   // Manage open positions (Trailing Stop & BreakEven)
   ManagePositions();
   if(!PeriodicLicenseCheck())
   {
      Print("License expired or invalid: ", g_licenseError);
      ExpertRemove();
      return;
   }
   
   if(Mode == MODE_MASTER)
      MasterLogic();
   else
      SlaveLogic();
}

void MasterLogic()
{
   // Check for new positions and write to file
   string signal = "";
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      
      string sym = PositionGetString(POSITION_SYMBOL);
      int type = (int)PositionGetInteger(POSITION_TYPE);
      double lot = PositionGetDouble(POSITION_VOLUME);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      ulong ticket = PositionGetTicket(i);
      
      signal += IntegerToString(ticket) + "," + sym + "," + IntegerToString(type) + "," + 
                DoubleToString(lot, 2) + "," + DoubleToString(sl, 5) + "," + DoubleToString(tp, 5) + ";";
   }
   
   if(signal != g_lastSignal)
   {
      WriteSignal(signal);
      g_lastSignal = signal;
   }
}

void SlaveLogic()
{
   string signal = ReadSignal();
   if(signal == "" || signal == g_lastSignal) return;
   
   g_lastSignal = signal;
   
   // Parse and execute signals
   string positions[];
   StringSplit(signal, ';', positions);
   
   // Track which master tickets we've seen
   ulong masterTickets[];
   ArrayResize(masterTickets, 0);
   
   for(int i = 0; i < ArraySize(positions); i++)
   {
      if(StringLen(positions[i]) < 5) continue;
      
      string parts[];
      StringSplit(positions[i], ',', parts);
      if(ArraySize(parts) < 6) continue;
      
      ulong masterTicket = (ulong)StringToInteger(parts[0]);
      string sym = parts[1];
      int type = (int)StringToInteger(parts[2]);
      double lot = StringToDouble(parts[3]) * LotMultiplier;
      double sl = StringToDouble(parts[4]);
      double tp = StringToDouble(parts[5]);
      
      ArrayResize(masterTickets, ArraySize(masterTickets) + 1);
      masterTickets[ArraySize(masterTickets) - 1] = masterTicket;
      
      // Check if we already have this position
      if(!HasCopiedPosition(masterTicket))
      {
         if(ReverseTrades) type = (type == 0) ? 1 : 0;
         OpenCopiedPosition(sym, type, lot, sl, tp, masterTicket);
      }
   }
   
   // Close positions that master closed
   CloseMissingPositions(masterTickets);
}

bool HasCopiedPosition(ulong masterTicket)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         string comment = PositionGetString(POSITION_COMMENT);
         if(StringFind(comment, "MT" + IntegerToString(masterTicket)) >= 0)
            return true;
      }
   }
   return false;
}

void OpenCopiedPosition(string sym, int type, double lot, double sl, double tp, ulong masterTicket)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   double price = (type == 0) ? SymbolInfoDouble(sym, SYMBOL_ASK) : SymbolInfoDouble(sym, SYMBOL_BID);
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = sym;
   request.volume = NormalizeDouble(lot, 2);
   request.type = (type == 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price = price;
   
   if(CopySLTP)
   {
      request.sl = sl;
      request.tp = tp;
   }
   else if(CustomSL > 0 || CustomTP > 0)
   {
      if(CustomSL > 0)
         request.sl = (type == 0) ? price - CustomSL * point : price + CustomSL * point;
      if(CustomTP > 0)
         request.tp = (type == 0) ? price + CustomTP * point : price - CustomTP * point;
   }
   
   request.magic = MagicNumber;
   request.comment = "MT" + IntegerToString(masterTicket);
   request.deviation = 10;
   
   if(OrderSend(request, result))
      Print("Copied trade: ", sym, " ", (type == 0 ? "BUY" : "SELL"), " ", lot);
}

void CloseMissingPositions(ulong &masterTickets[])
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      bool found = false;
      
      for(int j = 0; j < ArraySize(masterTickets); j++)
      {
         if(StringFind(comment, "MT" + IntegerToString(masterTickets[j])) >= 0)
         {
            found = true;
            break;
         }
      }
      
      if(!found)
      {
         // Master closed this position
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         request.action = TRADE_ACTION_DEAL;
         request.position = PositionGetTicket(i);
         request.symbol = PositionGetString(POSITION_SYMBOL);
         request.volume = PositionGetDouble(POSITION_VOLUME);
         request.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
         request.price = request.type == ORDER_TYPE_BUY ? 
            SymbolInfoDouble(request.symbol, SYMBOL_ASK) : SymbolInfoDouble(request.symbol, SYMBOL_BID);
         request.deviation = 10;
         OrderSend(request, result);
      }
   }
}

void WriteSignal(string signal)
{
   int handle = FileOpen(SignalFile, FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(handle != INVALID_HANDLE)
   {
      FileWriteString(handle, signal);
      FileClose(handle);
   }
}

string ReadSignal()
{
   string signal = "";
   int handle = FileOpen(SignalFile, FILE_READ|FILE_TXT|FILE_COMMON);
   if(handle != INVALID_HANDLE)
   {
      signal = FileReadString(handle);
      FileClose(handle);
   }
   return signal;
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Calculate Lot Size based on Risk %                               |
//+------------------------------------------------------------------+
double GetLotSize(double slPoints)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(tickSize == 0 || point == 0) return 0.01;
   
   // Calculate risk amount in money
   double riskMoney = accountBalance * (RiskPercent / 100.0);
   
   // Money per lot for 1 point movement = (TickValue / TickSize) * Point
   double moneyPerPointPerLot = (tickValue / tickSize) * point;
   
   if(moneyPerPointPerLot == 0) return 0.01;
   
   // Calculate lots: RiskMoney / (SL_Points * MoneyPerPointPerLot)
   double calculatedLots = riskMoney / (slPoints * moneyPerPointPerLot);
   
   // Normalize lots
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   calculatedLots = MathFloor(calculatedLots / stepLot) * stepLot;
   
   if(calculatedLots < minLot) calculatedLots = minLot;
   if(calculatedLots > maxLot) calculatedLots = maxLot;
   
   return calculatedLots;
}

//+------------------------------------------------------------------+
//| Manage Positions (Trailing Stop & Break Even)                    |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      // Data
      long type = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      //--- BREAK EVEN ---
      if(UseBreakEven)
      {
         if(type == POSITION_TYPE_BUY)
         {
            if(currentPrice - openPrice > BreakEvenTrigger * point)
            {
               double newSL = openPrice + BreakEvenLock * point;
               if(newSL > currentSL && (currentSL == 0 || newSL > currentSL))
               {
                  MqlTradeRequest request = {};
                  MqlTradeResult result = {};
                  request.action = TRADE_ACTION_SLTP;
                  request.position = ticket;
                  request.sl = newSL;
                  request.tp = PositionGetDouble(POSITION_TP);
                  request.symbol = _Symbol;
                  if(!OrderSend(request, result))
                     Print("Failed to move SL/TP: ", GetLastError());
               }
            }
         }
         else // SELL
         {
            if(openPrice - currentPrice > BreakEvenTrigger * point)
            {
               double newSL = openPrice - BreakEvenLock * point;
               if(newSL < currentSL || currentSL == 0)
               {
                  MqlTradeRequest request = {};
                  MqlTradeResult result = {};
                  request.action = TRADE_ACTION_SLTP;
                  request.position = ticket;
                  request.sl = newSL;
                  request.tp = PositionGetDouble(POSITION_TP);
                  request.symbol = _Symbol;
                  if(!OrderSend(request, result))
                     Print("Failed to move SL/TP: ", GetLastError());
               }
            }
         }
      }
      
      //--- TRAILING STOP ---
      if(UseTrailingStop)
      {
         if(type == POSITION_TYPE_BUY)
         {
            if(currentPrice - openPrice > TrailingStop * point)
            {
               double newSL = currentPrice - TrailingStop * point;
               if(newSL > currentSL + TrailingStep * point)
               {
                  MqlTradeRequest request = {};
                  MqlTradeResult result = {};
                  request.action = TRADE_ACTION_SLTP;
                  request.position = ticket;
                  request.sl = newSL;
                  request.tp = PositionGetDouble(POSITION_TP);
                  request.symbol = _Symbol;
                  if(!OrderSend(request, result))
                     Print("Failed to move SL/TP: ", GetLastError());
               }
            }
         }
         else // SELL
         {
            if(openPrice - currentPrice > TrailingStop * point)
            {
               double newSL = currentPrice + TrailingStop * point;
               if(newSL < currentSL - TrailingStep * point || currentSL == 0)
               {
                  MqlTradeRequest request = {};
                  MqlTradeResult result = {};
                  request.action = TRADE_ACTION_SLTP;
                  request.position = ticket;
                  request.sl = newSL;
                  request.tp = PositionGetDouble(POSITION_TP);
                  request.symbol = _Symbol;
                  if(!OrderSend(request, result))
                     Print("Failed to move SL/TP: ", GetLastError());
               }
            }
         }
      }
   }
}
