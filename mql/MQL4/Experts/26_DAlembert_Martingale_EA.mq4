//+------------------------------------------------------------------+
//|                                     26_DAlembert_Martingale_EA.mq4|
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: D'Alembert - Linear progression (+1 on loss, -1 on win)|
//| More conservative than exponential martingale                    |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   BaseLot = 0.03;
input double   LotIncrement = 0.01;
input double   MinLot = 0.01;
input double   MaxLot = 0.5;
input int      TakeProfit = 120;
input int      StopLoss = 80;
input int      MA_Period = 20;
input int      MagicNumber = 100026;

CLicenseValidator* g_license;
double g_currentLot;
int g_lastOrderTicket = 0;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "dalembert_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   g_currentLot = BaseLot;
   Print("D'Alembert Martingale EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   CheckClosedTrades();
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   if(HasOpenOrder()) return;
   
   double ma1 = iMA(Symbol(), Period(), MA_Period, 0, MODE_SMA, PRICE_CLOSE, 1);
   double ma2 = iMA(Symbol(), Period(), MA_Period, 0, MODE_SMA, PRICE_CLOSE, 2);
   double close1 = iClose(Symbol(), Period(), 1);
   double close2 = iClose(Symbol(), Period(), 2);
   
   if(close1 > ma1 && close2 <= ma2) OpenOrder(OP_BUY);
   else if(close1 < ma1 && close2 >= ma2) OpenOrder(OP_SELL);
}

void CheckClosedTrades()
{
   if(g_lastOrderTicket > 0 && OrderSelect(g_lastOrderTicket, SELECT_BY_TICKET, MODE_HISTORY))
   {
      if(OrderCloseTime() > 0)
      {
         double profit = OrderProfit() + OrderSwap();
         if(profit < 0) g_currentLot = MathMin(g_currentLot + LotIncrement, MaxLot);
         else g_currentLot = MathMax(g_currentLot - LotIncrement, MinLot);
         g_lastOrderTicket = 0;
      }
   }
}

bool HasOpenOrder()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
            return true;
   return false;
}

void OpenOrder(int orderType)
{
   double price = (orderType == OP_BUY) ? Ask : Bid;
   double sl = (orderType == OP_BUY) ? price - StopLoss * Point : price + StopLoss * Point;
   double tp = (orderType == OP_BUY) ? price + TakeProfit * Point : price - TakeProfit * Point;
   int ticket = OrderSend(Symbol(), orderType, NormalizeDouble(g_currentLot, 2), price, 10, sl, tp, "DAlembert", MagicNumber, 0, clrNONE);
   if(ticket > 0) g_lastOrderTicket = ticket;
}
//+------------------------------------------------------------------+
