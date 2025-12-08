//+------------------------------------------------------------------+
//|                                        16_Mean_Reversion_EA.mq4   |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Statistical Mean Reversion                               |
//| Uses Z-Score to identify extreme deviations from the mean.        |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      MeanPeriod = 50;
input double   ZScoreThreshold = 2.0;
input double   ZScoreExit = 0.5;
input double   LotSize = 0.1;
input int      StopLoss = 200;
input int      MagicNumber = 100016;

CLicenseValidator* g_license;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "mean_reversion_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   Print("Mean Reversion EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   double ma = iMA(Symbol(), Period(), MeanPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
   double stddev = iStdDev(Symbol(), Period(), MeanPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
   double close = iClose(Symbol(), Period(), 0);
   double zScore = (stddev > 0) ? (close - ma) / stddev : 0;
   
   // Check for exit
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         {
            if(OrderType() == OP_BUY && zScore >= -ZScoreExit)
               CloseOrder(OrderTicket());
            else if(OrderType() == OP_SELL && zScore <= ZScoreExit)
               CloseOrder(OrderTicket());
         }
      }
   }
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   double close1 = iClose(Symbol(), Period(), 1);
   double ma1 = iMA(Symbol(), Period(), MeanPeriod, 0, MODE_SMA, PRICE_CLOSE, 1);
   double stddev1 = iStdDev(Symbol(), Period(), MeanPeriod, 0, MODE_SMA, PRICE_CLOSE, 1);
   double zScore1 = (stddev1 > 0) ? (close1 - ma1) / stddev1 : 0;
   
   bool buySignal = zScore1 < -ZScoreThreshold;
   bool sellSignal = zScore1 > ZScoreThreshold;
   
   ManageOrders(buySignal, sellSignal, ma);
}

void ManageOrders(bool buySignal, bool sellSignal, double targetPrice)
{
   bool hasOrder = false;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
            hasOrder = true;
   
   if(!hasOrder)
   {
      if(buySignal) OpenOrder(OP_BUY, targetPrice);
      else if(sellSignal) OpenOrder(OP_SELL, targetPrice);
   }
}

void OpenOrder(int orderType, double targetPrice)
{
   double price = (orderType == OP_BUY) ? Ask : Bid;
   double sl = (orderType == OP_BUY) ? price - StopLoss * Point : price + StopLoss * Point;
   OrderSend(Symbol(), orderType, LotSize, price, 10, sl, targetPrice, "Mean Revert", MagicNumber, 0, clrNONE);
}

void CloseOrder(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   OrderClose(ticket, OrderLots(), (OrderType() == OP_BUY) ? Bid : Ask, 10, clrNONE);
}
//+------------------------------------------------------------------+
