//+------------------------------------------------------------------+
//|                                       23_Smooth_Martingale_EA.mq4 |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Smooth Martingale - Uses smaller 1.3x multiplier       |
//| More gradual progression, better for moderate capital            |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   InitialLot = 0.01;
input double   LotMultiplier = 1.3;
input double   MaxLot = 0.5;
input int      MaxTrades = 15;
input int      TakeProfit = 80;
input int      StopLoss = 80;
input int      BB_Period = 20;
input double   BB_Deviation = 2.0;
input double   EquityStopPercent = 20;
input int      MagicNumber = 100023;

CLicenseValidator* g_license;
double g_currentLot;
int g_consecutiveLosses = 0;
double g_startEquity;
int g_lastOrderTicket = 0;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "smooth_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   g_currentLot = InitialLot;
   g_startEquity = AccountEquity();
   Print("Smooth Martingale EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   if(AccountEquity() < g_startEquity * (1 - EquityStopPercent / 100)) { ExpertRemove(); return; }
   
   CheckClosedTrades();
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   if(HasOpenOrder()) return;
   if(g_consecutiveLosses >= MaxTrades) { g_consecutiveLosses = 0; g_currentLot = InitialLot; return; }
   
   double upper = iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_UPPER, 1);
   double lower = iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_LOWER, 1);
   double close = iClose(Symbol(), Period(), 1);
   
   if(close < lower) OpenOrder(OP_BUY);
   else if(close > upper) OpenOrder(OP_SELL);
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
   int ticket = OrderSend(Symbol(), orderType, NormalizeDouble(g_currentLot, 2), price, 10, sl, tp, "Smooth #" + IntegerToString(g_consecutiveLosses + 1), MagicNumber, 0, clrNONE);
   if(ticket > 0) g_lastOrderTicket = ticket;
}
//+------------------------------------------------------------------+
