//+------------------------------------------------------------------+
//|                                        11_Multi_Timeframe_EA.mq4  |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Multi-Timeframe Trend Alignment                          |
//| Uses H4 for major trend, H1 for intermediate, M15 for entry.      |
//| Only trades when all timeframes agree on direction.                |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      H4_MA_Period = 50;
input int      H1_MA_Period = 20;
input int      RSI_Period = 14;
input double   LotSize = 0.1;
input int      StopLoss = 200;
input int      TakeProfit = 300;
input int      MagicNumber = 100011;

CLicenseValidator* g_license;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "multi_timeframe_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   Print("Multi-Timeframe EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), PERIOD_M15, 0)) return;
   lastBar = iTime(Symbol(), PERIOD_M15, 0);
   
   double h4_ma = iMA(Symbol(), PERIOD_H4, H4_MA_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
   double h1_ma = iMA(Symbol(), PERIOD_H1, H1_MA_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
   double h4_close = iClose(Symbol(), PERIOD_H4, 0);
   double h1_close = iClose(Symbol(), PERIOD_H1, 0);
   
   double rsi1 = iRSI(Symbol(), PERIOD_M15, RSI_Period, PRICE_CLOSE, 1);
   double rsi2 = iRSI(Symbol(), PERIOD_M15, RSI_Period, PRICE_CLOSE, 2);
   
   bool h4_bullish = h4_close > h4_ma;
   bool h1_bullish = h1_close > h1_ma;
   bool rsi_buy = rsi1 > 30 && rsi2 <= 30;
   bool rsi_sell = rsi1 < 70 && rsi2 >= 70;
   
   bool buySignal = h4_bullish && h1_bullish && rsi_buy;
   bool sellSignal = !h4_bullish && !h1_bullish && rsi_sell;
   
   ManageOrders(buySignal, sellSignal);
}

void ManageOrders(bool buySignal, bool sellSignal)
{
   bool hasOrder = false;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         {
            hasOrder = true;
            if((OrderType() == OP_BUY && sellSignal) || (OrderType() == OP_SELL && buySignal))
            {
               CloseOrder(OrderTicket());
               hasOrder = false;
            }
         }
      }
   }
   
   if(!hasOrder)
   {
      if(buySignal) OpenOrder(OP_BUY);
      else if(sellSignal) OpenOrder(OP_SELL);
   }
}

void OpenOrder(int orderType)
{
   double price = (orderType == OP_BUY) ? Ask : Bid;
   double sl = (orderType == OP_BUY) ? price - StopLoss * Point : price + StopLoss * Point;
   double tp = (orderType == OP_BUY) ? price + TakeProfit * Point : price - TakeProfit * Point;
   OrderSend(Symbol(), orderType, LotSize, price, 10, sl, tp, "MTF EA", MagicNumber, 0, clrNONE);
}

void CloseOrder(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   OrderClose(ticket, OrderLots(), (OrderType() == OP_BUY) ? Bid : Ask, 10, clrNONE);
}
//+------------------------------------------------------------------+
