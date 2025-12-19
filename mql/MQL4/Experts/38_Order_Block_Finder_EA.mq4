//+------------------------------------------------------------------+
//|                                      38_Order_Block_Finder_EA.mq4 |
//|                                    My Algo Stack - Trading Infrastructure   |
//+------------------------------------------------------------------+
//| UTILITY: Order Block & Supply/Demand Zone Finder                  |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "order_block_finder_ea"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200
#define LICENSE_GRACE_PERIOD 86400

input string   LicenseKey = "";
input int      LookbackBars = 100;
input double   MinMoveMultiplier = 2.0;
input int      ATR_Period = 14;
input bool     AlertOnApproach = true;
input int      ApproachPips = 20;
input color    DemandColor = clrDodgerBlue;
input color    SupplyColor = clrCrimson;

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

struct OrderBlock { double high; double low; datetime time; bool isBullish; bool isValid; };
OrderBlock g_orderBlocks[];

int OnInit()
{
   if(!ValidateLicense()) { Print("LICENSE ERROR: ", g_licenseError); Alert("License Error: ", g_licenseError); return INIT_FAILED; }
   ArrayResize(g_orderBlocks, 0);
   Print("Order Block Finder EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { ObjectsDeleteAll(0, "OB_"); }

void OnTick()
{
   // Manage open positions (Trailing Stop & BreakEven)
   ManagePositions();
   if(!PeriodicLicenseCheck()) { ExpertRemove(); return; }
   static datetime lastBar = 0; if(lastBar == iTime(Symbol(), Period(), 0)) return; lastBar = iTime(Symbol(), Period(), 0);
   double atr = iATR(Symbol(), Period(), ATR_Period, 0);
   FindOrderBlocks(atr); DrawOrderBlocks(); CheckPriceApproach();
}

void FindOrderBlocks(double atr) { ArrayResize(g_orderBlocks, 0); double minMove = atr * MinMoveMultiplier; for(int i = 3; i < LookbackBars; i++) { double open_i = iOpen(Symbol(), Period(), i); double close_i = iClose(Symbol(), Period(), i); double high_i = iHigh(Symbol(), Period(), i); double low_i = iLow(Symbol(), Period(), i); bool isBearishCandle = close_i < open_i; bool isBullishCandle = close_i > open_i; if(isBearishCandle) { for(int j = i - 1; j >= 1; j--) { double moveUp = iHigh(Symbol(), Period(), j) - low_i; if(moveUp >= minMove) { OrderBlock ob; ob.high = high_i; ob.low = low_i; ob.time = iTime(Symbol(), Period(), i); ob.isBullish = true; ob.isValid = true; for(int k = i - 1; k >= 1; k--) if(iClose(Symbol(), Period(), k) < ob.low) { ob.isValid = false; break; } if(ob.isValid) { ArrayResize(g_orderBlocks, ArraySize(g_orderBlocks) + 1); g_orderBlocks[ArraySize(g_orderBlocks) - 1] = ob; } break; } } } if(isBullishCandle) { for(int j = i - 1; j >= 1; j--) { double moveDown = high_i - iLow(Symbol(), Period(), j); if(moveDown >= minMove) { OrderBlock ob; ob.high = high_i; ob.low = low_i; ob.time = iTime(Symbol(), Period(), i); ob.isBullish = false; ob.isValid = true; for(int k = i - 1; k >= 1; k--) if(iClose(Symbol(), Period(), k) > ob.high) { ob.isValid = false; break; } if(ob.isValid) { ArrayResize(g_orderBlocks, ArraySize(g_orderBlocks) + 1); g_orderBlocks[ArraySize(g_orderBlocks) - 1] = ob; } break; } } } } }
void DrawOrderBlocks() { ObjectsDeleteAll(0, "OB_"); for(int i = 0; i < ArraySize(g_orderBlocks); i++) { if(!g_orderBlocks[i].isValid) continue; string name = "OB_" + IntegerToString(i); color clr = g_orderBlocks[i].isBullish ? DemandColor : SupplyColor; ObjectCreate(0, name, OBJ_RECTANGLE, 0, g_orderBlocks[i].time, g_orderBlocks[i].high, TimeCurrent() + PeriodSeconds() * 50, g_orderBlocks[i].low); ObjectSetInteger(0, name, OBJPROP_COLOR, clr); ObjectSetInteger(0, name, OBJPROP_FILL, true); ObjectSetInteger(0, name, OBJPROP_BACK, true); } }
void CheckPriceApproach() { if(!AlertOnApproach) return; double approachDistance = ApproachPips * Point; static datetime lastAlert = 0; if(TimeCurrent() - lastAlert < 300) return; for(int i = 0; i < ArraySize(g_orderBlocks); i++) { if(!g_orderBlocks[i].isValid) continue; if(g_orderBlocks[i].isBullish && Bid <= g_orderBlocks[i].high + approachDistance && Bid >= g_orderBlocks[i].low) { Alert("Price approaching DEMAND zone"); lastAlert = TimeCurrent(); return; } if(!g_orderBlocks[i].isBullish && Bid >= g_orderBlocks[i].low - approachDistance && Bid <= g_orderBlocks[i].high) { Alert("Price approaching SUPPLY zone"); lastAlert = TimeCurrent(); return; } } }
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
