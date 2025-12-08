//+------------------------------------------------------------------+
//|                                        15_London_Breakout_EA.mq4  |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: London Session Breakout                                  |
//| Trades breakouts of Asian session range during London open.       |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      AsianStartHour = 0;
input int      AsianEndHour = 7;
input int      LondonEndHour = 16;
input double   RangeMultiplier = 1.5;
input double   LotSize = 0.1;
input int      MagicNumber = 100015;

CLicenseValidator* g_license;
double g_asianHigh = 0, g_asianLow = 0;
bool g_rangeCalculated = false;
datetime g_lastRangeDate = 0;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "london_breakout_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   Print("London Breakout EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   int currentHour = TimeHour(TimeCurrent());
   
   if(today != g_lastRangeDate) { g_rangeCalculated = false; g_lastRangeDate = today; }
   
   if(currentHour == AsianEndHour && !g_rangeCalculated)
   {
      CalculateAsianRange();
      g_rangeCalculated = true;
   }
   
   if(currentHour >= LondonEndHour) { CloseAllOrders(); return; }
   if(currentHour < AsianEndHour || currentHour >= LondonEndHour) return;
   if(!g_rangeCalculated) return;
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   double close1 = iClose(Symbol(), Period(), 1);
   double close2 = iClose(Symbol(), Period(), 2);
   
   bool buySignal = close1 > g_asianHigh && close2 <= g_asianHigh;
   bool sellSignal = close1 < g_asianLow && close2 >= g_asianLow;
   
   ManageOrders(buySignal, sellSignal);
}

void CalculateAsianRange()
{
   g_asianHigh = 0;
   g_asianLow = 999999;
   
   for(int i = 0; i < 500; i++)
   {
      datetime barTime = iTime(Symbol(), PERIOD_M15, i);
      int barHour = TimeHour(barTime);
      datetime barDate = StringToTime(TimeToString(barTime, TIME_DATE));
      
      if(barDate < g_lastRangeDate) break;
      if(barDate > g_lastRangeDate) continue;
      if(barHour < AsianStartHour || barHour >= AsianEndHour) continue;
      
      if(iHigh(Symbol(), PERIOD_M15, i) > g_asianHigh) g_asianHigh = iHigh(Symbol(), PERIOD_M15, i);
      if(iLow(Symbol(), PERIOD_M15, i) < g_asianLow) g_asianLow = iLow(Symbol(), PERIOD_M15, i);
   }
   
   Print("Asian Range: ", g_asianHigh, " - ", g_asianLow);
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
   double range = g_asianHigh - g_asianLow;
   double sl = (orderType == OP_BUY) ? g_asianLow : g_asianHigh;
   double tp = (orderType == OP_BUY) ? price + range * RangeMultiplier : price - range * RangeMultiplier;
   OrderSend(Symbol(), orderType, LotSize, price, 10, sl, tp, "London BO", MagicNumber, 0, clrNONE);
}

void CloseAllOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
            OrderClose(OrderTicket(), OrderLots(), (OrderType() == OP_BUY) ? Bid : Ask, 10, clrNONE);
      }
   }
}
//+------------------------------------------------------------------+
