//+------------------------------------------------------------------+
//|                                     07_Support_Resistance_EA.mq4   |
//|                                    EA License Management System   |
//|                                                                    |
//| STRATEGY: Support/Resistance Bounce Trading                        |
//| LOGIC: Buy at support with bullish confirmation, sell at resistance|
//| TIMEFRAME: H1-H4 recommended                                       |
//| PAIRS: All pairs                                                   |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      LookbackPeriod = 20;
input int      ZonePoints = 50;
input double   LotSize = 0.1;
input int      StopLoss = 100;
input int      TakeProfit = 150;
input int      MagicNumber = 100007;

CLicenseValidator* g_license;
bool g_isLicensed = false;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "support_resistance_ea", "1.0.0");
   g_isLicensed = g_license.ValidateLicense();
   if(!g_isLicensed) { Print("License failed"); return INIT_FAILED; }
   Print("Support/Resistance EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   double support = FindSupport();
   double resistance = FindResistance();
   double zoneSize = ZonePoints * Point;
   
   double close1 = iClose(Symbol(), Period(), 1);
   double close2 = iClose(Symbol(), Period(), 2);
   double low1 = iLow(Symbol(), Period(), 1);
   double high1 = iHigh(Symbol(), Period(), 1);
   
   bool buySignal = (low1 <= support + zoneSize && low1 >= support - zoneSize) && close1 > close2;
   bool sellSignal = (high1 >= resistance - zoneSize && high1 <= resistance + zoneSize) && close1 < close2;
   
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

double FindSupport()
{
   double lowestLow = iLow(Symbol(), Period(), 1);
   for(int i = 2; i <= LookbackPeriod; i++)
   {
      double low = iLow(Symbol(), Period(), i);
      if(low < lowestLow) lowestLow = low;
   }
   return lowestLow;
}

double FindResistance()
{
   double highestHigh = iHigh(Symbol(), Period(), 1);
   for(int i = 2; i <= LookbackPeriod; i++)
   {
      double high = iHigh(Symbol(), Period(), i);
      if(high > highestHigh) highestHigh = high;
   }
   return highestHigh;
}

void OpenOrder(int orderType)
{
   double price = (orderType == OP_BUY) ? Ask : Bid;
   double sl = (orderType == OP_BUY) ? price - StopLoss * Point : price + StopLoss * Point;
   double tp = (orderType == OP_BUY) ? price + TakeProfit * Point : price - TakeProfit * Point;
   OrderSend(Symbol(), orderType, LotSize, price, 10, sl, tp, "S/R Bounce", MagicNumber, 0, clrNONE);
}
//+------------------------------------------------------------------+
