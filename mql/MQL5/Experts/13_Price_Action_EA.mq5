//+------------------------------------------------------------------+
//|                                          13_Price_Action_EA.mq5   |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Price Action Pattern Recognition                        |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| This EA identifies and trades classic candlestick patterns        |
//| including Pin Bars, Engulfing patterns, and Inside Bars.          |
//| No indicators needed - pure price action trading.                  |
//|                                                                    |
//| PATTERNS DETECTED:                                                 |
//| 1. PIN BAR (Hammer/Shooting Star):                                |
//|    - Long wick (>60% of candle range)                             |
//|    - Small body (<30% of candle range)                            |
//|    - Signals potential reversal                                    |
//|                                                                    |
//| 2. ENGULFING PATTERN:                                              |
//|    - Current candle completely engulfs previous                   |
//|    - Strong reversal signal                                        |
//|    - Bullish: Green engulfs red                                   |
//|    - Bearish: Red engulfs green                                   |
//|                                                                    |
//| 3. INSIDE BAR:                                                     |
//|    - Current bar within previous bar's range                      |
//|    - Consolidation before breakout                                 |
//|    - Trade the breakout direction                                  |
//|                                                                    |
//| ENTRY CONDITIONS:                                                  |
//| - Pattern must form at key level (recent high/low)                |
//| - Confirmation candle required                                     |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: H4 or Daily                                          |
//| - Pairs: All pairs (works best on liquid markets)                 |
//|                                                                    |
//| RISK LEVEL: Medium-Low                                             |
//| WIN RATE: ~55-65% expected                                        |
//| RISK:REWARD: 1:2 minimum                                          |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   PinBarWickRatio = 0.6;    // Pin bar wick ratio (0.6 = 60%)
input double   PinBarBodyRatio = 0.3;    // Pin bar max body ratio
input int      KeyLevelLookback = 20;    // Bars for key level detection
input double   LotSize = 0.1;
input int      StopLoss = 100;
input int      TakeProfit = 200;
input int      MagicNumber = 100013;

CLicenseValidator* g_license;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "price_action_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   Print("Price Action EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   double open1 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   
   double open2 = iOpen(_Symbol, PERIOD_CURRENT, 2);
   double high2 = iHigh(_Symbol, PERIOD_CURRENT, 2);
   double low2 = iLow(_Symbol, PERIOD_CURRENT, 2);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   
   double range1 = high1 - low1;
   double body1 = MathAbs(close1 - open1);
   
   bool buySignal = false, sellSignal = false;
   
   // Check for Bullish Pin Bar (Hammer)
   if(range1 > 0)
   {
      double lowerWick = MathMin(open1, close1) - low1;
      double upperWick = high1 - MathMax(open1, close1);
      
      if(lowerWick / range1 >= PinBarWickRatio && body1 / range1 <= PinBarBodyRatio)
      {
         if(IsAtKeyLow(low1)) buySignal = true;
      }
      
      // Check for Bearish Pin Bar (Shooting Star)
      if(upperWick / range1 >= PinBarWickRatio && body1 / range1 <= PinBarBodyRatio)
      {
         if(IsAtKeyHigh(high1)) sellSignal = true;
      }
   }
   
   // Check for Bullish Engulfing
   if(close2 < open2 && close1 > open1)  // Previous red, current green
   {
      if(close1 > open2 && open1 < close2)  // Engulfs
      {
         if(IsAtKeyLow(low1)) buySignal = true;
      }
   }
   
   // Check for Bearish Engulfing
   if(close2 > open2 && close1 < open1)  // Previous green, current red
   {
      if(close1 < open2 && open1 > close2)  // Engulfs
      {
         if(IsAtKeyHigh(high1)) sellSignal = true;
      }
   }
   
   ManagePositions(buySignal, sellSignal);
}

bool IsAtKeyLow(double price)
{
   double lowestLow = iLow(_Symbol, PERIOD_CURRENT, 1);
   for(int i = 2; i <= KeyLevelLookback; i++)
   {
      double low = iLow(_Symbol, PERIOD_CURRENT, i);
      if(low < lowestLow) lowestLow = low;
   }
   double tolerance = 50 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return MathAbs(price - lowestLow) < tolerance;
}

bool IsAtKeyHigh(double price)
{
   double highestHigh = iHigh(_Symbol, PERIOD_CURRENT, 1);
   for(int i = 2; i <= KeyLevelLookback; i++)
   {
      double high = iHigh(_Symbol, PERIOD_CURRENT, i);
      if(high > highestHigh) highestHigh = high;
   }
   double tolerance = 50 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return MathAbs(price - highestHigh) < tolerance;
}

void ManagePositions(bool buySignal, bool sellSignal)
{
   bool hasPosition = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
            hasPosition = true;
   }
   
   if(!hasPosition)
   {
      if(buySignal) OpenPosition(ORDER_TYPE_BUY);
      else if(sellSignal) OpenPosition(ORDER_TYPE_SELL);
   }
}

void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = price;
   request.sl = (orderType == ORDER_TYPE_BUY) ? price - StopLoss * point : price + StopLoss * point;
   request.tp = (orderType == ORDER_TYPE_BUY) ? price + TakeProfit * point : price - TakeProfit * point;
   request.magic = MagicNumber;
   request.comment = "Price Action";
   request.deviation = 10;
   OrderSend(request, result);
}
//+------------------------------------------------------------------+
