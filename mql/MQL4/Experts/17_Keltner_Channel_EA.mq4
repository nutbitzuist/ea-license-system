//+------------------------------------------------------------------+
//|                                        17_Keltner_Channel_EA.mq4  |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Keltner Channel Breakout & Pullback                     |
//| Uses EMA + ATR bands for trend and pullback entries.              |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      EMA_Period = 20;
input int      ATR_Period = 10;
input double   ATR_Multiplier = 2.0;
input int      TrendLookback = 10;
input double   LotSize = 0.1;
input int      MagicNumber = 100017;

CLicenseValidator* g_license;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "keltner_channel_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   Print("Keltner Channel EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   double ema = iMA(Symbol(), Period(), EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
   double atr = iATR(Symbol(), Period(), ATR_Period, 1);
   double upper = ema + atr * ATR_Multiplier;
   double lower = ema - atr * ATR_Multiplier;
   
   double close1 = iClose(Symbol(), Period(), 1);
   double close2 = iClose(Symbol(), Period(), 2);
   double low1 = iLow(Symbol(), Period(), 1);
   double high1 = iHigh(Symbol(), Period(), 1);
   
   // Determine trend
   bool uptrend = true, downtrend = true;
   for(int i = 1; i <= TrendLookback; i++)
   {
      double c = iClose(Symbol(), Period(), i);
      double m = iMA(Symbol(), Period(), EMA_Period, 0, MODE_EMA, PRICE_CLOSE, i);
      if(c < m) uptrend = false;
      if(c > m) downtrend = false;
   }
   
   bool buySignal = uptrend && low1 <= ema && close1 > ema && close1 > close2;
   bool sellSignal = downtrend && high1 >= ema && close1 < ema && close1 < close2;
   
   ManageOrders(buySignal, sellSignal, upper, lower, atr);
}

void ManageOrders(bool buySignal, bool sellSignal, double upper, double lower, double atr)
{
   bool hasOrder = false;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
            hasOrder = true;
   
   if(!hasOrder)
   {
      if(buySignal) OpenOrder(OP_BUY, upper, lower, atr);
      else if(sellSignal) OpenOrder(OP_SELL, upper, lower, atr);
   }
}

void OpenOrder(int orderType, double upper, double lower, double atr)
{
   double price = (orderType == OP_BUY) ? Ask : Bid;
   double sl, tp;
   
   if(orderType == OP_BUY)
   {
      sl = lower - atr * 0.5;
      tp = upper;
   }
   else
   {
      sl = upper + atr * 0.5;
      tp = lower;
   }
   
   OrderSend(Symbol(), orderType, LotSize, price, 10, sl, tp, "Keltner", MagicNumber, 0, clrNONE);
}
//+------------------------------------------------------------------+
