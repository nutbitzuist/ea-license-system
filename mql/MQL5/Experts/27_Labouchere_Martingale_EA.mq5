//+------------------------------------------------------------------+
//|                                    27_Labouchere_Martingale_EA.mq5|
//|                                    My Algo Stack - Trading Infrastructure   |
//+------------------------------------------------------------------+
//| STRATEGY: Labouchere (Cancellation) Martingale                    |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Uses a number sequence to determine lot sizes. After a win,       |
//| removes numbers from ends of sequence. After a loss, adds the     |
//| lost amount to the end. Goal is to cancel out all numbers.        |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Start with sequence: [1, 2, 3, 4]                              |
//| 2. Bet = first + last number (1+4 = 5 units)                      |
//| 3. Win: Remove first and last → [2, 3]                            |
//| 4. Loss: Add bet to end → [1, 2, 3, 4, 5]                         |
//| 5. When sequence empty, profit = sum of original sequence         |
//|                                                                    |
//| SEQUENCE EXAMPLE:                                                  |
//| Start: [1,2,3] → Bet 4 (1+3)                                      |
//| Loss: [1,2,3,4] → Bet 5 (1+4)                                     |
//| Win: [2,3] → Bet 5 (2+3)                                          |
//| Win: [] → Sequence complete! Profit = 1+2+3 = 6 units            |
//|                                                                    |
//| ADVANTAGES:                                                        |
//| - More controlled than classic martingale                         |
//| - Clear profit target                                              |
//| - Flexible sequence customization                                  |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: H1                                                   |
//| - Pairs: Major pairs                                              |
//| - Account: Minimum $5,000 recommended                             |
//|                                                                    |
//| RISK LEVEL: HIGH                                                   |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

//=============================================================================
// LICENSE CONFIGURATION - DO NOT MODIFY
//=============================================================================
#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "labouchere_martingale_ea"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200  // Check every 12 hours (in seconds)
#define LICENSE_GRACE_PERIOD 86400    // 24 hours grace if server unreachable

//=============================================================================
// USER INPUT PARAMETERS
//=============================================================================
input string   LicenseKey = "";          // License Key (from dashboard)
input double   UnitLot = 0.01;           // Lot per unit
input string   InitSequence = "1,2,3,4"; // Initial sequence
input int      TakeProfit = 100;
input int      StopLoss = 100;
input int      RSI_Period = 14;
input int      MagicNumber = 100027;

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

int g_sequence[];
int g_sequenceSize = 0;
int g_rsi_handle;
double g_rsi[];

void ParseSequence(string seq)
{
   string parts[];
   int count = StringSplit(seq, ',', parts);
   ArrayResize(g_sequence, count);
   g_sequenceSize = count;
   for(int i = 0; i < count; i++)
      g_sequence[i] = (int)StringToInteger(parts[i]);
}

void ResetSequence()
{
   ParseSequence(InitSequence);
   Print("Sequence reset: ", InitSequence);
}

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
   
   ResetSequence();
   g_rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   ArraySetAsSeries(g_rsi, true);
   
   Print("Labouchere Martingale EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_rsi_handle != INVALID_HANDLE) IndicatorRelease(g_rsi_handle);
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
   
   CheckClosedTrades();
   
   // Check if sequence complete
   if(g_sequenceSize == 0)
   {
      Print("Labouchere sequence complete! Resetting...");
      ResetSequence();
   }
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(HasOpenPosition()) return;
   
   if(CopyBuffer(g_rsi_handle, 0, 0, 3, g_rsi) < 3) return;
   
   bool buySignal = g_rsi[1] > 30 && g_rsi[2] <= 30;
   bool sellSignal = g_rsi[1] < 70 && g_rsi[2] >= 70;
   
   if(buySignal) OpenPosition(ORDER_TYPE_BUY);
   else if(sellSignal) OpenPosition(ORDER_TYPE_SELL);
}

int GetCurrentBet()
{
   if(g_sequenceSize == 0) return 1;
   if(g_sequenceSize == 1) return g_sequence[0];
   return g_sequence[0] + g_sequence[g_sequenceSize - 1];
}

void CheckClosedTrades()
{
   static int lastDealsTotal = 0;
   HistorySelect(0, TimeCurrent());
   int dealsTotal = HistoryDealsTotal();
   
   if(dealsTotal > lastDealsTotal)
   {
      for(int i = lastDealsTotal; i < dealsTotal; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber &&
            HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            int bet = GetCurrentBet();
            
            if(profit > 0)
            {
               // Win: Remove first and last
               if(g_sequenceSize >= 2)
               {
                  for(int j = 0; j < g_sequenceSize - 2; j++)
                     g_sequence[j] = g_sequence[j + 1];
                  g_sequenceSize -= 2;
               }
               else
               {
                  g_sequenceSize = 0;
               }
               Print("Win! Sequence size: ", g_sequenceSize);
            }
            else
            {
               // Loss: Add bet to end
               ArrayResize(g_sequence, g_sequenceSize + 1);
               g_sequence[g_sequenceSize] = bet;
               g_sequenceSize++;
               Print("Loss - Added ", bet, " to sequence. Size: ", g_sequenceSize);
            }
         }
      }
   }
   lastDealsTotal = dealsTotal;
}

bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionSelectByTicket(PositionGetTicket(i)))
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
            return true;
   return false;
}

void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   int bet = GetCurrentBet();
   double lot = NormalizeDouble(UnitLot * bet, 2);
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lot;
   request.type = orderType;
   request.price = price;
   request.sl = (orderType == ORDER_TYPE_BUY) ? price - StopLoss * point : price + StopLoss * point;
   request.tp = (orderType == ORDER_TYPE_BUY) ? price + TakeProfit * point : price - TakeProfit * point;
   request.magic = MagicNumber;
   request.comment = "Labou " + IntegerToString(bet);
   request.deviation = 10;
   if(!OrderSend(request, result)) Print("OrderSend failed: ", GetLastError());
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
   
   if(tickSize == 0 || point == 0) return UnitLot;
   
   // Calculate risk amount in money
   double riskMoney = accountBalance * (RiskPercent / 100.0);
   
   // Money per lot for 1 point movement = (TickValue / TickSize) * Point
   double moneyPerPointPerLot = (tickValue / tickSize) * point;
   
   if(moneyPerPointPerLot == 0) return UnitLot;
   
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
