//+------------------------------------------------------------------+
//|                                    27_Labouchere_Martingale_EA.mq4|
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Labouchere (Cancellation) - Uses number sequence       |
//| Win: remove ends, Loss: add bet to end. Goal: empty sequence     |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   UnitLot = 0.01;
input int      TakeProfit = 100;
input int      StopLoss = 100;
input int      RSI_Period = 14;
input int      MagicNumber = 100027;

CLicenseValidator* g_license;
int g_sequence[20];
int g_sequenceSize = 4;
int g_lastOrderTicket = 0;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "labouchere_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   ResetSequence();
   Print("Labouchere Martingale EA initialized");
   return INIT_SUCCEEDED;
}

void ResetSequence()
{
   g_sequence[0] = 1; g_sequence[1] = 2; g_sequence[2] = 3; g_sequence[3] = 4;
   g_sequenceSize = 4;
}

int GetCurrentBet()
{
   if(g_sequenceSize == 0) return 1;
   if(g_sequenceSize == 1) return g_sequence[0];
   return g_sequence[0] + g_sequence[g_sequenceSize - 1];
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   CheckClosedTrades();
   if(g_sequenceSize == 0) ResetSequence();
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   if(HasOpenOrder()) return;
   
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
         int bet = GetCurrentBet();
         
         if(profit > 0)
         {
            if(g_sequenceSize >= 2)
            {
               for(int j = 0; j < g_sequenceSize - 2; j++) g_sequence[j] = g_sequence[j + 1];
               g_sequenceSize -= 2;
            }
            else g_sequenceSize = 0;
         }
         else
         {
            if(g_sequenceSize < 20)
            {
               g_sequence[g_sequenceSize] = bet;
               g_sequenceSize++;
            }
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
   int bet = GetCurrentBet();
   double lot = NormalizeDouble(UnitLot * bet, 2);
   double price = (orderType == OP_BUY) ? Ask : Bid;
   double sl = (orderType == OP_BUY) ? price - StopLoss * Point : price + StopLoss * Point;
   double tp = (orderType == OP_BUY) ? price + TakeProfit * Point : price - TakeProfit * Point;
   int ticket = OrderSend(Symbol(), orderType, lot, price, 10, sl, tp, "Labou " + IntegerToString(bet), MagicNumber, 0, clrNONE);
   if(ticket > 0) g_lastOrderTicket = ticket;
}
//+------------------------------------------------------------------+
