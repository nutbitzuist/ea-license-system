//+------------------------------------------------------------------+
//|                                      21_Classic_Martingale_EA.mq4 |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Classic Martingale - Doubles lot after each loss       |
//| WARNING: HIGH RISK - Requires large account balance              |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   InitialLot = 0.01;
input double   LotMultiplier = 2.0;
input double   MaxLot = 1.0;
input int      MaxTrades = 8;
input int      TakeProfit = 100;
input int      StopLoss = 100;
input int      MA_Fast = 10;
input int      MA_Slow = 20;
input double   DailyLossLimit = 500;
input int      MagicNumber = 100021;

CLicenseValidator* g_license;
double g_currentLot;
int g_consecutiveLosses = 0;
double g_dailyLoss = 0;
datetime g_lastDay = 0;
int g_lastOrderTicket = 0;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "classic_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   g_currentLot = InitialLot;
   Print("Classic Martingale EA initialized - WARNING: HIGH RISK!");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(today != g_lastDay) { g_dailyLoss = 0; g_lastDay = today; }
   if(g_dailyLoss >= DailyLossLimit) return;
   
   CheckClosedTrades();
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   if(HasOpenOrder()) return;
   if(g_consecutiveLosses >= MaxTrades) { g_consecutiveLosses = 0; g_currentLot = InitialLot; return; }
   
   double maFast = iMA(Symbol(), Period(), MA_Fast, 0, MODE_EMA, PRICE_CLOSE, 1);
   double maFast2 = iMA(Symbol(), Period(), MA_Fast, 0, MODE_EMA, PRICE_CLOSE, 2);
   double maSlow = iMA(Symbol(), Period(), MA_Slow, 0, MODE_EMA, PRICE_CLOSE, 1);
   double maSlow2 = iMA(Symbol(), Period(), MA_Slow, 0, MODE_EMA, PRICE_CLOSE, 2);
   
   if(maFast > maSlow && maFast2 <= maSlow2) OpenOrder(OP_BUY);
   else if(maFast < maSlow && maFast2 >= maSlow2) OpenOrder(OP_SELL);
}

void CheckClosedTrades()
{
   if(g_lastOrderTicket > 0 && OrderSelect(g_lastOrderTicket, SELECT_BY_TICKET, MODE_HISTORY))
   {
      if(OrderCloseTime() > 0)
      {
         double profit = OrderProfit() + OrderSwap();
         if(profit < 0)
         {
            g_consecutiveLosses++;
            g_dailyLoss += MathAbs(profit);
            g_currentLot = MathMin(g_currentLot * LotMultiplier, MaxLot);
         }
         else
         {
            g_consecutiveLosses = 0;
            g_currentLot = InitialLot;
         }
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
   int ticket = OrderSend(Symbol(), orderType, NormalizeDouble(g_currentLot, 2), price, 10, sl, tp, "Martingale #" + IntegerToString(g_consecutiveLosses + 1), MagicNumber, 0, clrNONE);
   if(ticket > 0) g_lastOrderTicket = ticket;
}
//+------------------------------------------------------------------+
