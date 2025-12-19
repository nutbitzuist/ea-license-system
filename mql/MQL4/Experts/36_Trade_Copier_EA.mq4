//+------------------------------------------------------------------+
//|                                          36_Trade_Copier_EA.mq4   |
//|                                    My Algo Stack - Trading Infrastructure   |
//+------------------------------------------------------------------+
//| UTILITY: Local Trade Copier (Master/Slave)                        |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "trade_copier_ea"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200
#define LICENSE_GRACE_PERIOD 86400

enum COPIER_MODE { MODE_MASTER, MODE_SLAVE };

input string      LicenseKey = "";
input COPIER_MODE Mode = MODE_SLAVE;
input string      SignalFile = "trade_signal.txt";
input double      LotMultiplier = 1.0;
input bool        ReverseTrades = false;
input bool        CopySLTP = true;
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

datetime g_lastValidation = 0; bool g_isLicensed = false; string g_licenseError = "";
bool ValidateLicense() { if(StringLen(LicenseKey) < 10) { g_licenseError = "Invalid License Key"; return false; } string jsonBody = StringFormat("{\"accountNumber\":\"%s\",\"brokerName\":\"%s\",\"eaCode\":\"%s\",\"eaVersion\":\"%s\",\"terminalType\":\"MT4\"}", IntegerToString(AccountNumber()), AccountCompany(), LICENSE_EA_CODE, LICENSE_EA_VERSION); string headers = StringFormat("Content-Type: application/json\r\nX-API-Key: %s", LicenseKey); char postData[], resultData[]; string resultHeaders; StringToCharArray(jsonBody, postData, 0, StringLen(jsonBody)); ArrayResize(postData, StringLen(jsonBody)); int statusCode = WebRequest("POST", LICENSE_API_URL, headers, 10000, postData, resultData, resultHeaders); if(statusCode == -1) { g_licenseError = "Connection failed"; if(g_lastValidation > 0 && (TimeCurrent() - g_lastValidation) < LICENSE_GRACE_PERIOD) return g_isLicensed; return false; } string response = CharArrayToString(resultData); bool isValid = (StringFind(response, "\"valid\":true") >= 0); g_lastValidation = TimeCurrent(); g_isLicensed = isValid; return isValid; }
bool PeriodicLicenseCheck() { if(!g_isLicensed) return false; if((TimeCurrent() - g_lastValidation) < LICENSE_CHECK_INTERVAL) return true; return ValidateLicense(); }

string g_lastSignal = "";

int OnInit()
{
   if(!ValidateLicense()) { Print("LICENSE ERROR: ", g_licenseError); Alert("License Error: ", g_licenseError); return INIT_FAILED; }
   Print("Trade Copier EA initialized as ", Mode == MODE_MASTER ? "MASTER" : "SLAVE");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { Print("Trade Copier EA stopped"); }

void OnTick()
{
   // Manage open positions (Trailing Stop & BreakEven)
   ManagePositions();
   if(!PeriodicLicenseCheck()) { ExpertRemove(); return; }
   if(Mode == MODE_MASTER) MasterLogic();
   else SlaveLogic();
}

void MasterLogic() { string signal = ""; for(int i = 0; i < OrdersTotal(); i++) { if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue; signal += IntegerToString(OrderTicket()) + "," + OrderSymbol() + "," + IntegerToString(OrderType()) + "," + DoubleToString(OrderLots(), 2) + "," + DoubleToString(OrderStopLoss(), 5) + "," + DoubleToString(OrderTakeProfit(), 5) + ";"; } if(signal != g_lastSignal) { WriteSignal(signal); g_lastSignal = signal; } }

void SlaveLogic() { string signal = ReadSignal(); if(signal == "" || signal == g_lastSignal) return; g_lastSignal = signal; string positions[]; StringSplit(signal, ';', positions); int masterTickets[]; ArrayResize(masterTickets, 0); for(int i = 0; i < ArraySize(positions); i++) { if(StringLen(positions[i]) < 5) continue; string parts[]; StringSplit(positions[i], ',', parts); if(ArraySize(parts) < 6) continue; int masterTicket = (int)StringToInteger(parts[0]); string sym = parts[1]; int type = (int)StringToInteger(parts[2]); double lot = StringToDouble(parts[3]) * LotMultiplier; double sl = StringToDouble(parts[4]); double tp = StringToDouble(parts[5]); ArrayResize(masterTickets, ArraySize(masterTickets) + 1); masterTickets[ArraySize(masterTickets) - 1] = masterTicket; if(!HasCopiedOrder(masterTicket)) { if(ReverseTrades) type = (type == OP_BUY) ? OP_SELL : OP_BUY; OpenCopiedOrder(sym, type, lot, sl, tp, masterTicket); } } CloseMissingOrders(masterTickets); }

bool HasCopiedOrder(int masterTicket) { for(int i = 0; i < OrdersTotal(); i++) { if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue; if(OrderMagicNumber() == MagicNumber) { if(StringFind(OrderComment(), "MT" + IntegerToString(masterTicket)) >= 0) return true; } } return false; }
void OpenCopiedOrder(string sym, int type, double lot, double sl, double tp, int masterTicket) { double price = (type == OP_BUY) ? MarketInfo(sym, MODE_ASK) : MarketInfo(sym, MODE_BID); if(!CopySLTP) { sl = 0; tp = 0; } OrderSend(sym, type, NormalizeDouble(lot, 2), price, 10, sl, tp, "MT" + IntegerToString(masterTicket), MagicNumber, 0, clrNONE); }
void CloseMissingOrders(int &masterTickets[]) { for(int i = OrdersTotal() - 1; i >= 0; i--) { if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue; if(OrderMagicNumber() != MagicNumber) continue; bool found = false; for(int j = 0; j < ArraySize(masterTickets); j++) { if(StringFind(OrderComment(), "MT" + IntegerToString(masterTickets[j])) >= 0) { found = true; break; } } if(!found) OrderClose(OrderTicket(), OrderLots(), (OrderType() == OP_BUY) ? Bid : Ask, 10, clrNONE); } }
void WriteSignal(string signal) { int handle = FileOpen(SignalFile, FILE_WRITE|FILE_TXT|FILE_COMMON); if(handle != INVALID_HANDLE) { FileWriteString(handle, signal); FileClose(handle); } }
string ReadSignal() { string signal = ""; int handle = FileOpen(SignalFile, FILE_READ|FILE_TXT|FILE_COMMON); if(handle != INVALID_HANDLE) { signal = FileReadString(handle); FileClose(handle); } return signal; }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Calculate Lot Size based on Risk %                               |
//+------------------------------------------------------------------+
double GetLotSize(double slPoints)
{
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   double point = Point;
   double accountBalance = AccountBalance();
   
   if(tickSize == 0 || point == 0 || tickValue == 0) return LotSize;
   
   // Calculate risk amount in money
   double riskMoney = accountBalance * (RiskPercent / 100.0);
   
   // Money per lot for 1 point movement = (TickValue / TickSize) * Point
   double moneyPerPointPerLot = (tickValue / tickSize) * point;
   
   if(moneyPerPointPerLot == 0) return LotSize;
   
   // Calculate lots: RiskMoney / (SL_Points * MoneyPerPointPerLot)
   double calculatedLots = riskMoney / (slPoints * moneyPerPointPerLot);
   
   // Normalize lots
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double stepLot = MarketInfo(Symbol(), MODE_LOTSTEP);
   
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
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol()) continue;
      
      // Data
      int type = OrderType();
      double openPrice = OrderOpenPrice();
      double currentSL = OrderStopLoss();
      double currentPrice = (type == OP_BUY) ? Bid : Ask;
      double point = Point;
      
      //--- BREAK EVEN ---
      if(UseBreakEven)
      {
         if(type == OP_BUY)
         {
            if(currentPrice - openPrice > BreakEvenTrigger * point)
            {
               double newSL = openPrice + BreakEvenLock * point;
               if(newSL > currentSL && (currentSL == 0 || newSL > currentSL))
               {
                  if(!OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE))
                     Print("Failed to move SL to BE: ", GetLastError());
               }
            }
         }
         else if(type == OP_SELL)
         {
            if(openPrice - currentPrice > BreakEvenTrigger * point)
            {
               double newSL = openPrice - BreakEvenLock * point;
               if(newSL < currentSL || currentSL == 0)
               {
                  if(!OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE))
                     Print("Failed to move SL to BE: ", GetLastError());
               }
            }
         }
      }
      
      //--- TRAILING STOP ---
      if(UseTrailingStop)
      {
         if(type == OP_BUY)
         {
            if(currentPrice - openPrice > TrailingStop * point)
            {
               double newSL = currentPrice - TrailingStop * point;
               if(newSL > currentSL + TrailingStep * point)
               {
                  if(!OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE))
                     Print("Failed to move Trailing SL: ", GetLastError());
               }
            }
         }
         else if(type == OP_SELL)
         {
            if(openPrice - currentPrice > TrailingStop * point)
            {
               double newSL = currentPrice + TrailingStop * point;
               if(newSL < currentSL - TrailingStep * point || currentSL == 0)
               {
                  if(!OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE))
                     Print("Failed to move Trailing SL: ", GetLastError());
               }
            }
         }
      }
   }
}
