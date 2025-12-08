//+------------------------------------------------------------------+
//|                                          13_Price_Action_EA.mq4   |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Price Action Pattern Recognition                        |
//| Detects Pin Bars, Engulfing patterns at key levels.              |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   PinBarWickRatio = 0.6;
input double   PinBarBodyRatio = 0.3;
input int      KeyLevelLookback = 20;
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
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   double open1 = iOpen(Symbol(), Period(), 1);
   double high1 = iHigh(Symbol(), Period(), 1);
   double low1 = iLow(Symbol(), Period(), 1);
   double close1 = iClose(Symbol(), Period(), 1);
   double open2 = iOpen(Symbol(), Period(), 2);
   double close2 = iClose(Symbol(), Period(), 2);
   
   double range1 = high1 - low1;
   double body1 = MathAbs(close1 - open1);
   
   bool buySignal = false, sellSignal = false;
   
   if(range1 > 0)
   {
      double lowerWick = MathMin(open1, close1) - low1;
      double upperWick = high1 - MathMax(open1, close1);
      
      // Bullish Pin Bar
      if(lowerWick / range1 >= PinBarWickRatio && body1 / range1 <= PinBarBodyRatio)
         if(IsAtKeyLow(low1)) buySignal = true;
      
      // Bearish Pin Bar
      if(upperWick / range1 >= PinBarWickRatio && body1 / range1 <= PinBarBodyRatio)
         if(IsAtKeyHigh(high1)) sellSignal = true;
   }
   
   // Bullish Engulfing
   if(close2 < open2 && close1 > open1 && close1 > open2 && open1 < close2)
      if(IsAtKeyLow(low1)) buySignal = true;
   
   // Bearish Engulfing
   if(close2 > open2 && close1 < open1 && close1 < open2 && open1 > close2)
      if(IsAtKeyHigh(high1)) sellSignal = true;
   
   ManageOrders(buySignal, sellSignal);
}

bool IsAtKeyLow(double price)
{
   double lowestLow = iLow(Symbol(), Period(), 1);
   for(int i = 2; i <= KeyLevelLookback; i++)
      if(iLow(Symbol(), Period(), i) < lowestLow) lowestLow = iLow(Symbol(), Period(), i);
   return MathAbs(price - lowestLow) < 50 * Point;
}

bool IsAtKeyHigh(double price)
{
   double highestHigh = iHigh(Symbol(), Period(), 1);
   for(int i = 2; i <= KeyLevelLookback; i++)
      if(iHigh(Symbol(), Period(), i) > highestHigh) highestHigh = iHigh(Symbol(), Period(), i);
   return MathAbs(price - highestHigh) < 50 * Point;
}

void ManageOrders(bool buySignal, bool sellSignal)
{
   bool hasOrder = false;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
            hasOrder = true;
   
   if(!hasOrder)
   {
      if(buySignal) OpenOrder(OP_BUY);
      else if(sellSignal) OpenOrder(OP_SELL);
   }
}

void OpenOrder(int orderType)
{
   double price = (orderType == OP_BUY) ? Ask : Bid;
   double sl = (orderType == OP_BUY) ? price - StopLoss * Point : price + StopLoss * Point;
   double tp = (orderType == OP_BUY) ? price + TakeProfit * Point : price - TakeProfit * Point;
   OrderSend(Symbol(), orderType, LotSize, price, 10, sl, tp, "Price Action", MagicNumber, 0, clrNONE);
}
//+------------------------------------------------------------------+
