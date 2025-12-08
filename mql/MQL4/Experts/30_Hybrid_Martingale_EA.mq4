//+------------------------------------------------------------------+
//|                                       30_Hybrid_Martingale_EA.mq4 |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Hybrid Martingale - Switches between strategies        |
//| Trending: Anti-martingale, Ranging: Classic martingale           |
//| Includes cooling period and safety mechanisms                    |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   BaseLot = 0.01;
input double   MaxLot = 0.5;
input double   MartingaleMultiplier = 1.5;
input double   AntiMartingaleMultiplier = 1.3;
input int      ADX_Threshold = 25;
input int      CoolingPeriodBars = 5;
input int      MaxConsecutiveLosses = 5;
input double   MaxDrawdownPercent = 15;
input double   DailyLossLimit = 300;
input int      TakeProfit = 100;
input int      StopLoss = 100;
input int      MagicNumber = 100030;

CLicenseValidator* g_license;
double g_currentLot;
int g_consecutiveLosses = 0;
int g_consecutiveWins = 0;
bool g_isTrending = false;
datetime g_coolingUntil = 0;
double g_dailyLoss = 0;
datetime g_lastDay = 0;
double g_startEquity;
int g_lastOrderTicket = 0;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "hybrid_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   g_currentLot = BaseLot;
   g_startEquity = AccountEquity();
   Print("Hybrid Martingale EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(today != g_lastDay) { g_dailyLoss = 0; g_lastDay = today; }
   
   double drawdown = (g_startEquity - AccountEquity()) / g_startEquity * 100;
   if(drawdown >= MaxDrawdownPercent) return;
   if(g_dailyLoss >= DailyLossLimit) return;
   if(TimeCurrent() < g_coolingUntil) return;
   
   CheckClosedTrades();
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   if(HasOpenOrder()) return;
   
   double adx = iADX(Symbol(), Period(), 14, PRICE_CLOSE, MODE_MAIN, 1);
   g_isTrending = adx > ADX_Threshold;
   
   double ma = iMA(Symbol(), Period(), 20, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ma2 = iMA(Symbol(), Period(), 20, 0, MODE_EMA, PRICE_CLOSE, 2);
   double close1 = iClose(Symbol(), Period(), 1);
   double close2 = iClose(Symbol(), Period(), 2);
   
   if(close1 > ma && close2 <= ma2) OpenOrder(OP_BUY);
   else if(close1 < ma && close2 >= ma2) OpenOrder(OP_SELL);
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
            g_consecutiveLosses = 0;
            if(g_isTrending) g_currentLot = MathMin(g_currentLot * AntiMartingaleMultiplier, MaxLot);
            else g_currentLot = BaseLot;
         }
         else
         {
            g_consecutiveLosses++;
            g_consecutiveWins = 0;
            g_dailyLoss += MathAbs(profit);
            
            if(g_consecutiveLosses >= MaxConsecutiveLosses)
            {
               g_coolingUntil = iTime(Symbol(), Period(), 0) + CoolingPeriodBars * PeriodSeconds();
               g_currentLot = BaseLot;
               g_consecutiveLosses = 0;
            }
            else if(!g_isTrending) g_currentLot = MathMin(g_currentLot * MartingaleMultiplier, MaxLot);
            else g_currentLot = BaseLot;
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
   string comment = g_isTrending ? "Hybrid-T" : "Hybrid-R";
   int ticket = OrderSend(Symbol(), orderType, NormalizeDouble(g_currentLot, 2), price, 10, sl, tp, comment, MagicNumber, 0, clrNONE);
   if(ticket > 0) g_lastOrderTicket = ticket;
}
//+------------------------------------------------------------------+
