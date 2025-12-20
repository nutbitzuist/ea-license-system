//+------------------------------------------------------------------+
//|                                      21_Classic_Martingale_EA.mq4 |
//|                                    My Algo Stack - Trading Infrastructure   |
//+------------------------------------------------------------------+
//| STRATEGY: Classic Martingale - Doubles lot after each loss       |
//| WARNING: HIGH RISK - Requires large account balance              |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

//=============================================================================
// LICENSE CONFIGURATION - DO NOT MODIFY
//=============================================================================
#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "classic_martingale_ea"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200
#define LICENSE_GRACE_PERIOD 86400

//=============================================================================
// USER INPUT PARAMETERS
//=============================================================================
input string   LicenseKey = "";          // License Key (from dashboard)
input double   InitialLot = 0.01;        // Initial Lot Size
input double   LotMultiplier = 2.0;      // Lot Multiplier
input double   MaxLot = 1.0;             // Maximum Lot
input int      MaxTrades = 8;            // Maximum Consecutive Trades
input int      TakeProfit = 100;         // Take Profit (points)
input int      StopLoss = 100;           // Stop Loss (points)
input int      MA_Fast = 10;             // Fast MA Period
input int      MA_Slow = 20;             // Slow MA Period
input double   DailyLossLimit = 500;     // Daily Loss Limit ($)
input int      MagicNumber = 100021;     // Magic Number

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

//=============================================================================
// LICENSE VALIDATOR (EMBEDDED)
//=============================================================================
datetime g_lastValidation = 0;
bool g_isLicensed = false;
string g_licenseError = "";

bool ValidateLicense()
{
   if(StringLen(LicenseKey) < 10) { g_licenseError = "Invalid License Key. Get your key from the dashboard."; return false; }
   string jsonBody = StringFormat("{\"accountNumber\":\"%s\",\"brokerName\":\"%s\",\"eaCode\":\"%s\",\"eaVersion\":\"%s\",\"terminalType\":\"MT4\"}", IntegerToString(AccountNumber()), AccountCompany(), LICENSE_EA_CODE, LICENSE_EA_VERSION);
   string headers = StringFormat("Content-Type: application/json\r\nX-API-Key: %s", LicenseKey);
   char postData[], resultData[]; string resultHeaders;
   StringToCharArray(jsonBody, postData, 0, StringLen(jsonBody)); ArrayResize(postData, StringLen(jsonBody));
   int statusCode = WebRequest("POST", LICENSE_API_URL, headers, 10000, postData, resultData, resultHeaders);
   if(statusCode == -1) { g_licenseError = (GetLastError() == 4060) ? "Add URL to allowed list: Tools -> Options -> Expert Advisors" : "Connection failed"; if(g_lastValidation > 0 && (TimeCurrent() - g_lastValidation) < LICENSE_GRACE_PERIOD) return g_isLicensed; return false; }
   string response = CharArrayToString(resultData);
   bool isValid = (StringFind(response, "\"valid\":true") >= 0);
   if(!isValid) g_licenseError = "License validation failed.";
   g_lastValidation = TimeCurrent(); g_isLicensed = isValid;
   return isValid;
}
bool PeriodicLicenseCheck() { if(!g_isLicensed) return false; if((TimeCurrent() - g_lastValidation) < LICENSE_CHECK_INTERVAL) return true; return ValidateLicense(); }

//=============================================================================
// EA LOGIC
//=============================================================================
double g_currentLot;
int g_consecutiveLosses = 0;
double g_dailyLoss = 0;
datetime g_lastDay = 0;
int g_lastOrderTicket = 0;

int OnInit()
{
   Print("=== Classic Martingale EA v1.0.0 ===");
   if(!ValidateLicense()) { Print("LICENSE ERROR: ", g_licenseError); Alert("License Error: ", g_licenseError); return INIT_FAILED; }
   Print("License validated! Account: ", AccountNumber());
   g_currentLot = InitialLot;
   Print("WARNING: HIGH RISK STRATEGY!");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { Print("Classic Martingale EA stopped. Reason: ", reason); }

void OnTick()
{
   // Manage open positions (Trailing Stop & BreakEven)
   ManagePositions();
   if(!PeriodicLicenseCheck()) { ExpertRemove(); return; }
   
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(today != g_lastDay) { g_dailyLoss = 0; g_lastDay = today; }
   if(g_dailyLoss >= DailyLossLimit) return;
   
   CheckClosedTrades();
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   if(HasOpenOrder()) return;
   if(g_consecutiveLosses >= MaxTrades) { g_consecutiveLosses = 0; g_currentLot = InitialLot; return; }
   
   double maFast = iMA(Symbol(), Period(), MA_Fast, 0, MODE_EMA, PRICE_CLOSE, 1);
   double maFast2 = iMA(Symbol(), Period(), MA_Fast, 0, MODE_EMA, PRICE_CLOSE, 2);
   double maSlow = iMA(Symbol(), Period(), MA_Slow, 0, MODE_EMA, PRICE_CLOSE, 1);
   double maSlow2 = iMA(Symbol(), Period(), MA_Slow, 0, MODE_EMA, PRICE_CLOSE, 2);
   
   if(maFast > maSlow && maFast2 <= maSlow2) OpenOrder(OP_BUY);
   else if(maFast < maSlow && maFast2 >= maSlow2) OpenOrder(OP_SELL);
}

void CheckClosedTrades()
{
   if(g_lastOrderTicket > 0 && OrderSelect(g_lastOrderTicket, SELECT_BY_TICKET, MODE_HISTORY))
   {
      if(OrderCloseTime() > 0)
      {
         double profit = OrderProfit() + OrderSwap();
         if(profit < 0) { g_consecutiveLosses++; g_dailyLoss += MathAbs(profit); g_currentLot = MathMin(g_currentLot * LotMultiplier, MaxLot); }
         else { g_consecutiveLosses = 0; g_currentLot = InitialLot; }
         g_lastOrderTicket = 0;
      }
   }
}

bool HasOpenOrder()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         return true;
   return false;
}

void OpenOrder(int orderType)
{
   double price = (orderType == OP_BUY) ? Ask : Bid;
   double sl = (orderType == OP_BUY) ? price - StopLoss * Point : price + StopLoss * Point;
   double tp = (orderType == OP_BUY) ? price + TakeProfit * Point : price - TakeProfit * Point;
   int ticket = OrderSend(Symbol(), orderType, NormalizeDouble(g_currentLot, 2), price, 10, sl, tp, "Martingale #" + IntegerToString(g_consecutiveLosses + 1), MagicNumber, 0, clrNONE);
   if(ticket > 0) g_lastOrderTicket = ticket;
}
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
   
   if(tickSize == 0 || point == 0 || tickValue == 0) return InitialLot;
   
   // Calculate risk amount in money
   double riskMoney = accountBalance * (RiskPercent / 100.0);
   
   // Money per lot for 1 point movement = (TickValue / TickSize) * Point
   double moneyPerPointPerLot = (tickValue / tickSize) * point;
   
   if(moneyPerPointPerLot == 0) return InitialLot;
   
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
