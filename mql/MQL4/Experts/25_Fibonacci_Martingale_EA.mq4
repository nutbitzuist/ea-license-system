//+------------------------------------------------------------------+
//|                                     25_Fibonacci_Martingale_EA.mq4|
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Fibonacci Martingale - Uses Fib sequence for lot sizing|
//| Sequence: 1,1,2,3,5,8,13... More gradual than 2x doubling        |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   BaseLot = 0.01;
input int      MaxFibLevel = 10;
input int      TakeProfit = 100;
input int      StopLoss = 100;
input int      Stoch_K = 14;
input int      Stoch_D = 3;
input int      Stoch_Slowing = 3;
input int      MagicNumber = 100025;

CLicenseValidator* g_license;
int g_fibLevel = 0;
int g_lastOrderTicket = 0;

int GetFibonacci(int n)
{
   if(n <= 1) return 1;
   int a = 1, b = 1;
   for(int i = 2; i <= n; i++) { int temp = a + b; a = b; b = temp; }
   return b;
}

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "fibonacci_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   Print("Fibonacci Martingale EA initialized");
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
   if(g_fibLevel >= MaxFibLevel) { g_fibLevel = 0; }
   
   double k1 = iStochastic(Symbol(), Period(), Stoch_K, Stoch_D, Stoch_Slowing, MODE_SMA, 0, MODE_MAIN, 1);
   double k2 = iStochastic(Symbol(), Period(), Stoch_K, Stoch_D, Stoch_Slowing, MODE_SMA, 0, MODE_MAIN, 2);
   double d1 = iStochastic(Symbol(), Period(), Stoch_K, Stoch_D, Stoch_Slowing, MODE_SMA, 0, MODE_SIGNAL, 1);
   double d2 = iStochastic(Symbol(), Period(), Stoch_K, Stoch_D, Stoch_Slowing, MODE_SMA, 0, MODE_SIGNAL, 2);
   
   if(k1 > d1 && k2 <= d2 && k1 < 30) OpenOrder(OP_BUY);
   else if(k1 < d1 && k2 >= d2 && k1 > 70) OpenOrder(OP_SELL);
}

void CheckClosedTrades()
{
   if(g_lastOrderTicket > 0 && OrderSelect(g_lastOrderTicket, SELECT_BY_TICKET, MODE_HISTORY))
   {
      if(OrderCloseTime() > 0)
      {
         double profit = OrderProfit() + OrderSwap();
         if(profit < 0) g_fibLevel++;
         else g_fibLevel = MathMax(0, g_fibLevel - 2);
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
   double lot = NormalizeDouble(BaseLot * GetFibonacci(g_fibLevel), 2);
   double price = (orderType == OP_BUY) ? Ask : Bid;
   double sl = (orderType == OP_BUY) ? price - StopLoss * Point : price + StopLoss * Point;
   double tp = (orderType == OP_BUY) ? price + TakeProfit * Point : price - TakeProfit * Point;
   int ticket = OrderSend(Symbol(), orderType, lot, price, 10, sl, tp, "Fib L" + IntegerToString(g_fibLevel), MagicNumber, 0, clrNONE);
   if(ticket > 0) g_lastOrderTicket = ticket;
}
//+------------------------------------------------------------------+
