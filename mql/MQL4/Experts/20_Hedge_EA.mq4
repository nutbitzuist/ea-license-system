//+------------------------------------------------------------------+
//|                                                 20_Hedge_EA.mq4   |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Hedging with Correlation                                 |
//| Opens both buy and sell, closes losing side when trend emerges.   |
//| NOTE: Requires broker that allows hedging.                        |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      ADX_Period = 14;
input int      ADX_Threshold = 30;
input int      ATR_Period = 14;
input double   ATR_Multiplier = 2.0;
input double   LotSize = 0.1;
input int      MagicNumber = 100020;

CLicenseValidator* g_license;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "hedge_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   Print("Hedge EA initialized - Requires hedging-enabled broker");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   double adx = iADX(Symbol(), Period(), ADX_Period, PRICE_CLOSE, MODE_MAIN, 0);
   double plusDI = iADX(Symbol(), Period(), ADX_Period, PRICE_CLOSE, MODE_PLUSDI, 0);
   double minusDI = iADX(Symbol(), Period(), ADX_Period, PRICE_CLOSE, MODE_MINUSDI, 0);
   double atr = iATR(Symbol(), Period(), ATR_Period, 0);
   
   int buyCount = 0, sellCount = 0;
   int buyTicket = 0, sellTicket = 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         {
            if(OrderType() == OP_BUY) { buyCount++; buyTicket = OrderTicket(); }
            else { sellCount++; sellTicket = OrderTicket(); }
         }
      }
   }
   
   // Open hedge if no positions
   if(buyCount == 0 && sellCount == 0)
   {
      OpenHedge();
      return;
   }
   
   // If both positions exist, check for trend to close losing side
   if(buyCount > 0 && sellCount > 0)
   {
      if(adx > ADX_Threshold)
      {
         if(plusDI > minusDI)
         {
            CloseOrder(sellTicket);
            Print("Uptrend confirmed, closed SELL hedge");
         }
         else
         {
            CloseOrder(buyTicket);
            Print("Downtrend confirmed, closed BUY hedge");
         }
      }
      return;
   }
   
   // If only one position, manage trailing stop
   if(buyCount > 0 || sellCount > 0)
   {
      UpdateTrailingStop(buyCount > 0 ? buyTicket : sellTicket, atr);
   }
}

void OpenHedge()
{
   // Open BUY
   int buyTicket = OrderSend(Symbol(), OP_BUY, LotSize, Ask, 10, 0, 0, "Hedge BUY", MagicNumber, 0, clrNONE);
   if(buyTicket > 0) Print("Hedge BUY opened");
   
   // Open SELL
   int sellTicket = OrderSend(Symbol(), OP_SELL, LotSize, Bid, 10, 0, 0, "Hedge SELL", MagicNumber, 0, clrNONE);
   if(sellTicket > 0) Print("Hedge SELL opened");
}

void UpdateTrailingStop(int ticket, double atr)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   
   double trailDistance = atr * ATR_Multiplier;
   double currentSL = OrderStopLoss();
   double openPrice = OrderOpenPrice();
   
   if(OrderType() == OP_BUY)
   {
      double newSL = Bid - trailDistance;
      if(newSL > currentSL && newSL > openPrice)
         OrderModify(ticket, openPrice, newSL, 0, 0, clrNONE);
   }
   else
   {
      double newSL = Ask + trailDistance;
      if((currentSL == 0 || newSL < currentSL) && newSL < openPrice)
         OrderModify(ticket, openPrice, newSL, 0, 0, clrNONE);
   }
}

void CloseOrder(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   OrderClose(ticket, OrderLots(), (OrderType() == OP_BUY) ? Bid : Ask, 10, clrNONE);
}
//+------------------------------------------------------------------+
