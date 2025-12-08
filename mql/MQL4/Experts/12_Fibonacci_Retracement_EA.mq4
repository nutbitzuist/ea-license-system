//+------------------------------------------------------------------+
//|                                    12_Fibonacci_Retracement_EA.mq4|
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Fibonacci Retracement Trading                           |
//| Identifies swing points and trades bounces from 38.2%, 50%, 61.8% |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      SwingLookback = 50;
input int      ZonePoints = 30;
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
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   double swingHigh = 0, swingLow = 999999;
   int swingHighBar = 0, swingLowBar = 0;
   
   for(int i = 1; i <= SwingLookback; i++)
   {
      if(iHigh(Symbol(), Period(), i) > swingHigh) { swingHigh = iHigh(Symbol(), Period(), i); swingHighBar = i; }
      if(iLow(Symbol(), Period(), i) < swingLow) { swingLow = iLow(Symbol(), Period(), i); swingLowBar = i; }
   }
   
   double range = swingHigh - swingLow;
   double zone = ZonePoints * Point;
   bool uptrend = swingLowBar > swingHighBar;
   
   double fib382, fib500, fib618;
   if(uptrend) { fib382 = swingHigh - range * 0.382; fib500 = swingHigh - range * 0.500; fib618 = swingHigh - range * 0.618; }
   else { fib382 = swingLow + range * 0.382; fib500 = swingLow + range * 0.500; fib618 = swingLow + range * 0.618; }
   
   double close1 = iClose(Symbol(), Period(), 1);
   double open1 = iOpen(Symbol(), Period(), 1);
   double low1 = iLow(Symbol(), Period(), 1);
   double high1 = iHigh(Symbol(), Period(), 1);
   
   bool buySignal = false, sellSignal = false;
   
   if(uptrend)
   {
      bool atFib = (MathAbs(low1 - fib382) < zone) || (MathAbs(low1 - fib500) < zone) || (MathAbs(low1 - fib618) < zone);
      if(atFib && close1 > open1) buySignal = true;
   }
   else
   {
      bool atFib = (MathAbs(high1 - fib382) < zone) || (MathAbs(high1 - fib500) < zone) || (MathAbs(high1 - fib618) < zone);
      if(atFib && close1 < open1) sellSignal = true;
   }
   
   ManageOrders(buySignal, sellSignal);
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
   OrderSend(Symbol(), orderType, LotSize, price, 10, sl, tp, "Fib Retrace", MagicNumber, 0, clrNONE);
}
//+------------------------------------------------------------------+
