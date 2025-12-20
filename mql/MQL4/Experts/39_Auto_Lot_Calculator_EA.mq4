//+------------------------------------------------------------------+
//|                                     39_Auto_Lot_Calculator_EA.mq4 |
//|                                    My Algo Stack - Trading Infrastructure   |
//+------------------------------------------------------------------+
//| UTILITY: Automatic Lot Size Calculator                            |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "auto_lot_calculator_ea"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200
#define LICENSE_GRACE_PERIOD 86400

enum SIZING_METHOD { FIXED_RISK, FIXED_FRACTIONAL, KELLY_CRITERION };

input string        LicenseKey = "";
input SIZING_METHOD Method = FIXED_RISK;
input double        RiskPercent = 1.0;
input double        FractionalPercent = 5.0;
input double        WinRate = 55.0;
input double        AvgWinLossRatio = 1.5;
input double        KellyFraction = 0.5;
input int           DefaultSL = 50;
input bool          ShowPanel = true;

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

int OnInit()
{
   if(!ValidateLicense()) { Print("LICENSE ERROR: ", g_licenseError); Alert("License Error: ", g_licenseError); return INIT_FAILED; }
   Print("Auto Lot Calculator EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { ObjectsDeleteAll(0, "ALC_"); }

void OnTick()
{
   // Manage open positions (Trailing Stop & BreakEven)
   ManagePositions();
   if(!PeriodicLicenseCheck()) { ExpertRemove(); return; }
   double optimalLot = CalculateOptimalLot();
   if(ShowPanel) UpdatePanel(optimalLot);
}

double CalculateOptimalLot() { double balance = AccountBalance(); double lot = 0.01; switch(Method) { case FIXED_RISK: lot = CalculateFixedRiskLot(balance); break; case FIXED_FRACTIONAL: lot = CalculateFixedFractionalLot(balance); break; case KELLY_CRITERION: lot = CalculateKellyLot(balance); break; } double minLot = MarketInfo(Symbol(), MODE_MINLOT); double maxLot = MarketInfo(Symbol(), MODE_MAXLOT); double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP); lot = MathMax(minLot, MathMin(maxLot, lot)); lot = MathFloor(lot / lotStep) * lotStep; return NormalizeDouble(lot, 2); }
double CalculateFixedRiskLot(double balance) { double riskAmount = balance * RiskPercent / 100; double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE); double slValue = DefaultSL * pipValue; if(slValue > 0) return riskAmount / slValue; return 0.01; }
double CalculateFixedFractionalLot(double balance) { double marginAmount = balance * FractionalPercent / 100; double marginRequired = MarketInfo(Symbol(), MODE_MARGINREQUIRED); if(marginRequired > 0) return marginAmount / marginRequired; return 0.01; }
double CalculateKellyLot(double balance) { double p = WinRate / 100; double q = 1 - p; double b = AvgWinLossRatio; double kellyPercent = (b * p - q) / b; kellyPercent = MathMax(0, kellyPercent) * KellyFraction; double riskAmount = balance * kellyPercent; double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE); double slValue = DefaultSL * pipValue; if(slValue > 0) return riskAmount / slValue; return 0.01; }
void UpdatePanel(double optimalLot) { double balance = AccountBalance(); int y = 20; CreateOrUpdateLabel("ALC_Title", 20, y, "=== LOT CALCULATOR ===", clrGold); y += 20; CreateOrUpdateLabel("ALC_Method", 20, y, "Method: " + EnumToString(Method), clrWhite); y += 15; CreateOrUpdateLabel("ALC_Balance", 20, y, "Balance: $" + DoubleToString(balance, 2), clrWhite); y += 15; CreateOrUpdateLabel("ALC_Risk", 20, y, "Risk: " + DoubleToString(RiskPercent, 1) + "%", clrWhite); y += 15; CreateOrUpdateLabel("ALC_Lot", 20, y, "OPTIMAL LOT: " + DoubleToString(optimalLot, 2), clrLime); }
void CreateOrUpdateLabel(string name, int x, int y, string text, color clr) { if(ObjectFind(0, name) < 0) { ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0); ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y); ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10); } ObjectSetString(0, name, OBJPROP_TEXT, text); ObjectSetInteger(0, name, OBJPROP_COLOR, clr); }
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
