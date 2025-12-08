//+------------------------------------------------------------------+
//|                                           10_News_Filter_EA.mq4   |
//|                                    EA License Management System   |
//|                                                                    |
//| STRATEGY: Breakout with Volatility Filter                          |
//| LOGIC: Trades breakouts using ADX filter and time restrictions.    |
//| TIMEFRAME: M30-H1 recommended                                      |
//| PAIRS: All major pairs                                             |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      RangePeriod = 20;
input int      ADX_Period = 14;
input int      ADX_Threshold = 25;
input double   LotSize = 0.1;
input int      StopLoss = 150;
input int      TakeProfit = 200;
input int      StartHour = 8;
input int      EndHour = 20;
input int      MagicNumber = 100010;

CLicenseValidator* g_license;
bool g_isLicensed = false;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "news_filter_ea", "1.0.0");
   g_isLicensed = g_license.ValidateLicense();
   if(!g_isLicensed) { Print("License failed"); return INIT_FAILED; }
   Print("News Filter EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   // Time filter
   int currentHour = TimeHour(TimeCurrent());
   if(currentHour < StartHour || currentHour >= EndHour) return;
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   double adx = iADX(Symbol(), Period(), ADX_Period, PRICE_CLOSE, MODE_MAIN, 1);
   double plusDI = iADX(Symbol(), Period(), ADX_Period, PRICE_CLOSE, MODE_PLUSDI, 1);
   double minusDI = iADX(Symbol(), Period(), ADX_Period, PRICE_CLOSE, MODE_MINUSDI, 1);
   
   if(adx < ADX_Threshold) return;
   
   // Calculate range
   double rangeHigh = iHigh(Symbol(), Period(), 1);
   double rangeLow = iLow(Symbol(), Period(), 1);
   for(int i = 2; i <= RangePeriod; i++)
   {
      double high = iHigh(Symbol(), Period(), i);
      double low = iLow(Symbol(), Period(), i);
      if(high > rangeHigh) rangeHigh = high;
      if(low < rangeLow) rangeLow = low;
   }
   
   double close1 = iClose(Symbol(), Period(), 1);
   double close2 = iClose(Symbol(), Period(), 2);
   
   bool buySignal = close1 > rangeHigh && close2 <= rangeHigh && plusDI > minusDI;
   bool sellSignal = close1 < rangeLow && close2 >= rangeLow && minusDI > plusDI;
   
   bool hasOrder = false;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
            hasOrder = true;
   }
   
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
   OrderSend(Symbol(), orderType, LotSize, price, 10, sl, tp, "Breakout Filter", MagicNumber, 0, clrNONE);
}
//+------------------------------------------------------------------+
