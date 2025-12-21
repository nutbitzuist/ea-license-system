//+------------------------------------------------------------------+
//|                                        32_Risk_Calculator_EA.mq4  |
//|                                    My Algo Stack - Trading Infrastructure   |
//+------------------------------------------------------------------+
//| UTILITY: Risk Calculator & Position Sizer with One-Click Trading |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "risk_calculator_ea"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200
#define LICENSE_GRACE_PERIOD 86400

input string   LicenseKey = "";
input double   RiskPercent = 1.0;
input int      StopLossPips = 50;
input int      TakeProfitPips = 100;
input bool     ShowPanel = true;

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

double g_calculatedLot = 0;

int OnInit()
{
   if(!ValidateLicense()) { Print("LICENSE ERROR: ", g_licenseError); Alert("License Error: ", g_licenseError); return INIT_FAILED; }
   if(ShowPanel) CreatePanel();
   Print("Risk Calculator EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { ObjectsDeleteAll(0, "RC_"); }

void OnTick()
{
   // Manage open positions (Trailing Stop & BreakEven)
   ManagePositions();
   if(!PeriodicLicenseCheck()) { ExpertRemove(); return; }
   CalculateRisk();
   if(ShowPanel) UpdatePanel();
}

void CalculateRisk() { double balance = AccountBalance(); double riskAmount = balance * RiskPercent / 100; double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE); double slValue = StopLossPips * pipValue; if(slValue > 0) g_calculatedLot = NormalizeDouble(riskAmount / slValue, 2); else g_calculatedLot = 0.01; double minLot = MarketInfo(Symbol(), MODE_MINLOT); double maxLot = MarketInfo(Symbol(), MODE_MAXLOT); g_calculatedLot = MathMax(minLot, MathMin(maxLot, g_calculatedLot)); }
void CreatePanel() { int y = 50; CreateLabel("RC_Title", 20, y, "=== RISK CALCULATOR ===", clrGold); y += 20; CreateLabel("RC_Balance", 20, y, "Balance: $0", clrWhite); y += 15; CreateLabel("RC_Risk", 20, y, "Risk: 0%", clrWhite); y += 15; CreateLabel("RC_Lot", 20, y, "Lot Size: 0.00", clrLime); y += 20; CreateButton("RC_BuyBtn", 20, y, 60, 25, "BUY", clrGreen); CreateButton("RC_SellBtn", 90, y, 60, 25, "SELL", clrRed); }
void UpdatePanel() { double balance = AccountBalance(); double riskAmount = balance * RiskPercent / 100; ObjectSetString(0, "RC_Balance", OBJPROP_TEXT, "Balance: $" + DoubleToString(balance, 2)); ObjectSetString(0, "RC_Risk", OBJPROP_TEXT, "Risk: " + DoubleToString(RiskPercent, 1) + "% ($" + DoubleToString(riskAmount, 2) + ")"); ObjectSetString(0, "RC_Lot", OBJPROP_TEXT, "LOT SIZE: " + DoubleToString(g_calculatedLot, 2)); }
void CreateLabel(string name, int x, int y, string text, color clr) { ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0); ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y); ObjectSetString(0, name, OBJPROP_TEXT, text); ObjectSetInteger(0, name, OBJPROP_COLOR, clr); ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10); }
void CreateButton(string name, int x, int y, int width, int height, string text, color clr) { ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0); ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y); ObjectSetInteger(0, name, OBJPROP_XSIZE, width); ObjectSetInteger(0, name, OBJPROP_YSIZE, height); ObjectSetString(0, name, OBJPROP_TEXT, text); ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr); }
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) { if(id == CHARTEVENT_OBJECT_CLICK) { if(sparam == "RC_BuyBtn") { PlaceTrade(OP_BUY); ObjectSetInteger(0, "RC_BuyBtn", OBJPROP_STATE, false); } else if(sparam == "RC_SellBtn") { PlaceTrade(OP_SELL); ObjectSetInteger(0, "RC_SellBtn", OBJPROP_STATE, false); } } }
void PlaceTrade(int orderType) { double price = (orderType == OP_BUY) ? Ask : Bid; double sl = (orderType == OP_BUY) ? price - StopLossPips * Point : price + StopLossPips * Point; double tp = (orderType == OP_BUY) ? price + TakeProfitPips * Point : price - TakeProfitPips * Point; int ticket = OrderSend(Symbol(), orderType, g_calculatedLot, price, 10, sl, tp, "RiskCalc", 0, 0, clrNONE); if(ticket < 0) Print("OrderSend failed: ", GetLastError()); }
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
   
   if(tickSize == 0 || point == 0 || tickValue == 0) return 0.01;
   
   // Calculate risk amount in money
   double riskMoney = accountBalance * (RiskPercent / 100.0);
   
   // Money per lot for 1 point movement = (TickValue / TickSize) * Point
   double moneyPerPointPerLot = (tickValue / tickSize) * point;
   
   if(moneyPerPointPerLot == 0) return 0.01;
   
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
