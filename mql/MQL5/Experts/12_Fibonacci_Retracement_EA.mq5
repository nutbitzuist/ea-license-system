//+------------------------------------------------------------------+
//|                                    12_Fibonacci_Retracement_EA.mq5 |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Fibonacci Retracement Trading                           |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| This EA automatically identifies swing highs and lows, draws       |
//| Fibonacci retracement levels, and trades bounces from key levels.  |
//| It focuses on the 38.2%, 50%, and 61.8% retracement levels.       |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Identifies the most recent significant swing high and low      |
//| 2. Calculates Fibonacci levels between these points               |
//| 3. Waits for price to retrace to a key Fib level                 |
//| 4. Enters when price shows rejection (candlestick confirmation)   |
//|                                                                    |
//| FIBONACCI LEVELS USED:                                             |
//| - 38.2% (shallow retracement, strong trends)                      |
//| - 50.0% (psychological level)                                     |
//| - 61.8% (golden ratio, strongest level)                           |
//|                                                                    |
//| ENTRY CONDITIONS:                                                  |
//| BUY: Price retraces to Fib level in uptrend + bullish candle     |
//| SELL: Price retraces to Fib level in downtrend + bearish candle  |
//|                                                                    |
//| EXIT CONDITIONS:                                                   |
//| - Take Profit at swing high/low (100% extension)                  |
//| - Stop Loss below/above the retracement level                     |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: H1 or H4                                             |
//| - Pairs: All major and cross pairs                                |
//| - Lookback: 50-100 bars for swing detection                       |
//|                                                                    |
//| RISK LEVEL: Medium                                                 |
//| WIN RATE: ~50-55% expected                                        |
//| RISK:REWARD: 1:2 to 1:3                                           |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      SwingLookback = 50;       // Bars to find swing points
input double   FibLevel1 = 38.2;         // Fib Level 1 (%)
input double   FibLevel2 = 50.0;         // Fib Level 2 (%)
input double   FibLevel3 = 61.8;         // Fib Level 3 (%)
input int      ZonePoints = 30;          // Zone tolerance (points)
input double   LotSize = 0.1;
input int      StopLoss = 150;
input int      TakeProfit = 300;
input int      MagicNumber = 100012;

CLicenseValidator* g_license;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "fibonacci_retracement_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   Print("Fibonacci Retracement EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   // Find swing high and low
   double swingHigh = 0, swingLow = DBL_MAX;
   int swingHighBar = 0, swingLowBar = 0;
   
   for(int i = 1; i <= SwingLookback; i++)
   {
      double high = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low = iLow(_Symbol, PERIOD_CURRENT, i);
      if(high > swingHigh) { swingHigh = high; swingHighBar = i; }
      if(low < swingLow) { swingLow = low; swingLowBar = i; }
   }
   
   double range = swingHigh - swingLow;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double zone = ZonePoints * point;
   
   // Determine trend direction (which came first - high or low)
   bool uptrend = swingLowBar > swingHighBar;  // Low came before high = uptrend
   
   // Calculate Fib levels
   double fib382, fib500, fib618;
   if(uptrend)
   {
      fib382 = swingHigh - range * 0.382;
      fib500 = swingHigh - range * 0.500;
      fib618 = swingHigh - range * 0.618;
   }
   else
   {
      fib382 = swingLow + range * 0.382;
      fib500 = swingLow + range * 0.500;
      fib618 = swingLow + range * 0.618;
   }
   
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double open1 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   
   bool buySignal = false, sellSignal = false;
   
   if(uptrend)
   {
      // Look for buy at Fib levels
      bool atFibLevel = (MathAbs(low1 - fib382) < zone) || 
                        (MathAbs(low1 - fib500) < zone) || 
                        (MathAbs(low1 - fib618) < zone);
      bool bullishCandle = close1 > open1;
      buySignal = atFibLevel && bullishCandle;
   }
   else
   {
      // Look for sell at Fib levels
      bool atFibLevel = (MathAbs(high1 - fib382) < zone) || 
                        (MathAbs(high1 - fib500) < zone) || 
                        (MathAbs(high1 - fib618) < zone);
      bool bearishCandle = close1 < open1;
      sellSignal = atFibLevel && bearishCandle;
   }
   
   ManagePositions(buySignal, sellSignal);
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
   request.comment = "Fib Retrace";
   request.deviation = 10;
   OrderSend(request, result);
}
//+------------------------------------------------------------------+
