//+------------------------------------------------------------------+
//|                                        22_Anti_Martingale_EA.mq4  |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Anti-Martingale - Increases lot after wins             |
//| Capitalizes on winning streaks, limits losses                    |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   InitialLot = 0.01;
input double   LotMultiplier = 1.5;
input double   MaxLot = 0.5;
input int      MaxWinStreak = 5;
input int      TakeProfit = 150;
input int      StopLoss = 100;
input int      RSI_Period = 14;
input int      MagicNumber = 100022;

CLicenseValidator* g_license;
double g_currentLot;
int g_consecutiveWins = 0;
int g_lastOrderTicket = 0;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "anti_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   g_currentLot = InitialLot;
   Print("Anti-Martingale EA initialized");
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
   if(g_consecutiveWins >= MaxWinStreak) { g_consecutiveWins = 0; g_currentLot = InitialLot; }
   
   double rsi1 = iRSI(Symbol(), Period(), RSI_Period, PRICE_CLOSE, 1);
   double rsi2 = iRSI(Symbol(), Period(), RSI_Period, PRICE_CLOSE, 2);
   
   if(rsi1 > 30 && rsi2 <= 30) OpenOrder(OP_BUY);
   else if(rsi1 < 70 && rsi2 >= 70) OpenOrder(OP_SELL);
}

void CheckClosedTrades()
{
   if(g_lastOrderTicket > 0 && OrderSelect(g_lastOrderTicket, SELECT_BY_TICKET, MODE_HISTORY))
   {
      if(OrderCloseTime() > 0)
      {
         double profit = OrderProfit() + OrderSwap();
         if(profit > 0)
         {
            g_consecutiveWins++;
            g_currentLot = MathMin(g_currentLot * LotMultiplier, MaxLot);
         }
         else
         {
            g_consecutiveWins = 0;
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
   int ticket = OrderSend(Symbol(), orderType, NormalizeDouble(g_currentLot, 2), price, 10, sl, tp, "AntiMart #" + IntegerToString(g_consecutiveWins + 1), MagicNumber, 0, clrNONE);
   if(ticket > 0) g_lastOrderTicket = ticket;
}
//+------------------------------------------------------------------+
