//+------------------------------------------------------------------+
//|                                          04_MACD_Divergence_EA.mq4 |
//|                                    EA License Management System   |
//|                                                                    |
//| STRATEGY: MACD Histogram Divergence                                |
//| LOGIC: Trade when MACD histogram crosses zero line with momentum.  |
//| TIMEFRAME: H4 recommended                                          |
//| PAIRS: All major pairs                                             |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      MACD_Fast = 12;
input int      MACD_Slow = 26;
input int      MACD_Signal = 9;
input double   LotSize = 0.1;
input int      StopLoss = 150;
input int      TakeProfit = 250;
input int      MagicNumber = 100004;

CLicenseValidator* g_license;
bool g_isLicensed = false;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "macd_divergence_ea", "1.0.0");
   g_isLicensed = g_license.ValidateLicense();
   if(!g_isLicensed) { Print("License failed"); return INIT_FAILED; }
   Print("MACD Divergence EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   double macdMain1 = iMACD(Symbol(), Period(), MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE, MODE_MAIN, 1);
   double macdMain2 = iMACD(Symbol(), Period(), MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE, MODE_MAIN, 2);
   double macdSignal1 = iMACD(Symbol(), Period(), MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE, MODE_SIGNAL, 1);
   double macdSignal2 = iMACD(Symbol(), Period(), MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE, MODE_SIGNAL, 2);
   
   double hist1 = macdMain1 - macdSignal1;
   double hist2 = macdMain2 - macdSignal2;
   
   bool buySignal = hist1 > 0 && hist2 <= 0;
   bool sellSignal = hist1 < 0 && hist2 >= 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         {
            if((OrderType() == OP_BUY && sellSignal) || (OrderType() == OP_SELL && buySignal))
               CloseOrder(OrderTicket());
            return;
         }
      }
   }
   
   if(buySignal) OpenOrder(OP_BUY);
   else if(sellSignal) OpenOrder(OP_SELL);
}

void OpenOrder(int orderType)
{
   double price = (orderType == OP_BUY) ? Ask : Bid;
   double sl = (orderType == OP_BUY) ? price - StopLoss * Point : price + StopLoss * Point;
   double tp = (orderType == OP_BUY) ? price + TakeProfit * Point : price - TakeProfit * Point;
   OrderSend(Symbol(), orderType, LotSize, price, 10, sl, tp, "MACD Divergence", MagicNumber, 0, clrNONE);
}

void CloseOrder(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   OrderClose(ticket, OrderLots(), (OrderType() == OP_BUY) ? Bid : Ask, 10, clrNONE);
}
//+------------------------------------------------------------------+
