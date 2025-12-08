//+------------------------------------------------------------------+
//|                                           18_Williams_R_EA.mq4    |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Williams %R with Trend Filter                           |
//| Trades %R extremes in the direction of the trend.                 |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      WPR_Period = 14;
input int      MA_Period = 100;
input int      OverboughtLevel = -20;
input int      OversoldLevel = -80;
input double   LotSize = 0.1;
input int      StopLoss = 150;
input int      TakeProfit = 225;
input int      MagicNumber = 100018;

CLicenseValidator* g_license;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "williams_r_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   Print("Williams %R EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   double wpr1 = iWPR(Symbol(), Period(), WPR_Period, 1);
   double wpr2 = iWPR(Symbol(), Period(), WPR_Period, 2);
   double ma = iMA(Symbol(), Period(), MA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
   double close1 = iClose(Symbol(), Period(), 1);
   
   bool uptrend = close1 > ma;
   bool downtrend = close1 < ma;
   
   bool wprBuy = wpr1 > OversoldLevel && wpr2 <= OversoldLevel;
   bool wprSell = wpr1 < OverboughtLevel && wpr2 >= OverboughtLevel;
   
   bool buySignal = uptrend && wprBuy;
   bool sellSignal = downtrend && wprSell;
   
   // Check for exit
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         {
            if(OrderType() == OP_BUY && wpr1 > OverboughtLevel)
               CloseOrder(OrderTicket());
            else if(OrderType() == OP_SELL && wpr1 < OversoldLevel)
               CloseOrder(OrderTicket());
         }
      }
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
   OrderSend(Symbol(), orderType, LotSize, price, 10, sl, tp, "Williams %R", MagicNumber, 0, clrNONE);
}

void CloseOrder(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   OrderClose(ticket, OrderLots(), (OrderType() == OP_BUY) ? Bid : Ask, 10, clrNONE);
}
//+------------------------------------------------------------------+
