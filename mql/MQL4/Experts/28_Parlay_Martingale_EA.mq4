//+------------------------------------------------------------------+
//|                                       28_Parlay_Martingale_EA.mq4 |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Parlay (Let It Ride) - Reinvests profits into next trade|
//| Great for winning streaks, limited risk on losses                |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   BaseLot = 0.01;
input int      MaxParlays = 4;
input int      TakeProfit = 100;
input int      StopLoss = 100;
input int      ADX_Period = 14;
input int      ADX_Threshold = 25;
input int      MagicNumber = 100028;

CLicenseValidator* g_license;
double g_currentLot;
double g_accumulatedProfit = 0;
int g_parlayCount = 0;
int g_lastOrderTicket = 0;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "parlay_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   g_currentLot = BaseLot;
   Print("Parlay Martingale EA initialized");
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
   if(g_parlayCount >= MaxParlays) { g_parlayCount = 0; g_currentLot = BaseLot; g_accumulatedProfit = 0; }
   
   double adx = iADX(Symbol(), Period(), ADX_Period, PRICE_CLOSE, MODE_MAIN, 1);
   double plusDI = iADX(Symbol(), Period(), ADX_Period, PRICE_CLOSE, MODE_PLUSDI, 1);
   double minusDI = iADX(Symbol(), Period(), ADX_Period, PRICE_CLOSE, MODE_MINUSDI, 1);
   
   if(adx < ADX_Threshold) return;
   
   if(plusDI > minusDI) OpenOrder(OP_BUY);
   else OpenOrder(OP_SELL);
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
            g_accumulatedProfit += profit;
            g_parlayCount++;
            double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE);
            double additionalLots = (g_accumulatedProfit / (TakeProfit * pipValue));
            g_currentLot = NormalizeDouble(BaseLot + additionalLots * 0.01, 2);
         }
         else
         {
            g_parlayCount = 0;
            g_currentLot = BaseLot;
            g_accumulatedProfit = 0;
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
   int ticket = OrderSend(Symbol(), orderType, g_currentLot, price, 10, sl, tp, "Parlay #" + IntegerToString(g_parlayCount + 1), MagicNumber, 0, clrNONE);
   if(ticket > 0) g_lastOrderTicket = ticket;
}
//+------------------------------------------------------------------+
