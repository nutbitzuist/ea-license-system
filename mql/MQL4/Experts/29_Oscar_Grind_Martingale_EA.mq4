//+------------------------------------------------------------------+
//|                                   29_Oscar_Grind_Martingale_EA.mq4|
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Oscar's Grind - Aims for 1 unit profit per cycle       |
//| Conservative: same bet on loss, +1 on win until target reached   |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   UnitLot = 0.01;
input int      MaxUnits = 10;
input int      TakeProfit = 100;
input int      StopLoss = 100;
input int      MACD_Fast = 12;
input int      MACD_Slow = 26;
input int      MACD_Signal = 9;
input int      MagicNumber = 100029;

CLicenseValidator* g_license;
int g_currentUnits = 1;
double g_cycleProfit = 0;
int g_lastOrderTicket = 0;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "oscar_grind_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   Print("Oscar's Grind Martingale EA initialized");
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
   
   double macdMain1 = iMACD(Symbol(), Period(), MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE, MODE_MAIN, 1);
   double macdMain2 = iMACD(Symbol(), Period(), MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE, MODE_MAIN, 2);
   double macdSignal1 = iMACD(Symbol(), Period(), MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE, MODE_SIGNAL, 1);
   double macdSignal2 = iMACD(Symbol(), Period(), MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE, MODE_SIGNAL, 2);
   
   double hist1 = macdMain1 - macdSignal1;
   double hist2 = macdMain2 - macdSignal2;
   
   if(hist1 > 0 && hist2 <= 0) OpenOrder(OP_BUY);
   else if(hist1 < 0 && hist2 >= 0) OpenOrder(OP_SELL);
}

void CheckClosedTrades()
{
   if(g_lastOrderTicket > 0 && OrderSelect(g_lastOrderTicket, SELECT_BY_TICKET, MODE_HISTORY))
   {
      if(OrderCloseTime() > 0)
      {
         double profit = OrderProfit() + OrderSwap();
         double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE);
         double unitValue = UnitLot * TakeProfit * pipValue;
         
         if(profit > 0)
         {
            g_cycleProfit += profit;
            if(g_cycleProfit >= unitValue)
            {
               g_currentUnits = 1;
               g_cycleProfit = 0;
            }
            else
            {
               double needed = unitValue - g_cycleProfit;
               int maxNeeded = (int)MathCeil(needed / (UnitLot * TakeProfit * pipValue));
               g_currentUnits = MathMin(g_currentUnits + 1, MathMin(maxNeeded, MaxUnits));
            }
         }
         else
         {
            g_cycleProfit += profit;
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
   double lot = NormalizeDouble(UnitLot * g_currentUnits, 2);
   double price = (orderType == OP_BUY) ? Ask : Bid;
   double sl = (orderType == OP_BUY) ? price - StopLoss * Point : price + StopLoss * Point;
   double tp = (orderType == OP_BUY) ? price + TakeProfit * Point : price - TakeProfit * Point;
   int ticket = OrderSend(Symbol(), orderType, lot, price, 10, sl, tp, "Oscar " + IntegerToString(g_currentUnits) + "u", MagicNumber, 0, clrNONE);
   if(ticket > 0) g_lastOrderTicket = ticket;
}
//+------------------------------------------------------------------+
