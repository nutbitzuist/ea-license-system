//+------------------------------------------------------------------+
//|                                          08_Ichimoku_Cloud_EA.mq4 |
//|                                    EA License Management System   |
//|                                                                    |
//| STRATEGY: Ichimoku Cloud Trading                                   |
//| LOGIC: Buy when price above cloud + Tenkan crosses Kijun up.       |
//| TIMEFRAME: H4-D1 recommended                                       |
//| PAIRS: Trending pairs                                              |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      Tenkan_Period = 9;
input int      Kijun_Period = 26;
input int      Senkou_Period = 52;
input double   LotSize = 0.1;
input int      StopLoss = 200;
input int      TakeProfit = 400;
input int      MagicNumber = 100008;

CLicenseValidator* g_license;
bool g_isLicensed = false;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "ichimoku_cloud_ea", "1.0.0");
   g_isLicensed = g_license.ValidateLicense();
   if(!g_isLicensed) { Print("License failed"); return INIT_FAILED; }
   Print("Ichimoku Cloud EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   double tenkan1 = iIchimoku(Symbol(), Period(), Tenkan_Period, Kijun_Period, Senkou_Period, MODE_TENKANSEN, 1);
   double tenkan2 = iIchimoku(Symbol(), Period(), Tenkan_Period, Kijun_Period, Senkou_Period, MODE_TENKANSEN, 2);
   double kijun1 = iIchimoku(Symbol(), Period(), Tenkan_Period, Kijun_Period, Senkou_Period, MODE_KIJUNSEN, 1);
   double kijun2 = iIchimoku(Symbol(), Period(), Tenkan_Period, Kijun_Period, Senkou_Period, MODE_KIJUNSEN, 2);
   double senkouA = iIchimoku(Symbol(), Period(), Tenkan_Period, Kijun_Period, Senkou_Period, MODE_SENKOUSPANA, 0);
   double senkouB = iIchimoku(Symbol(), Period(), Tenkan_Period, Kijun_Period, Senkou_Period, MODE_SENKOUSPANB, 0);
   
   double close1 = iClose(Symbol(), Period(), 1);
   double cloudTop = MathMax(senkouA, senkouB);
   double cloudBottom = MathMin(senkouA, senkouB);
   
   bool tenkanAboveKijun = tenkan1 > kijun1 && tenkan2 <= kijun2;
   bool tenkanBelowKijun = tenkan1 < kijun1 && tenkan2 >= kijun2;
   
   bool buySignal = tenkanAboveKijun && close1 > cloudTop;
   bool sellSignal = tenkanBelowKijun && close1 < cloudBottom;
   
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
   OrderSend(Symbol(), orderType, LotSize, price, 10, sl, tp, "Ichimoku Cloud", MagicNumber, 0, clrNONE);
}

void CloseOrder(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   OrderClose(ticket, OrderLots(), (OrderType() == OP_BUY) ? Bid : Ask, 10, clrNONE);
}
//+------------------------------------------------------------------+
