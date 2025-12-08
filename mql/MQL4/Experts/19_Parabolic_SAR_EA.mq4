//+------------------------------------------------------------------+
//|                                         19_Parabolic_SAR_EA.mq4   |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Parabolic SAR Trend Following                           |
//| Uses SAR for trend direction with ADX filter for strength.        |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   SAR_Step = 0.02;
input double   SAR_Maximum = 0.2;
input int      ADX_Period = 14;
input int      ADX_Threshold = 25;
input double   LotSize = 0.1;
input int      MagicNumber = 100019;

CLicenseValidator* g_license;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "parabolic_sar_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   Print("Parabolic SAR EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   double sar0 = iSAR(Symbol(), Period(), SAR_Step, SAR_Maximum, 0);
   UpdateTrailingStops(sar0);
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   double sar1 = iSAR(Symbol(), Period(), SAR_Step, SAR_Maximum, 1);
   double sar2 = iSAR(Symbol(), Period(), SAR_Step, SAR_Maximum, 2);
   double close1 = iClose(Symbol(), Period(), 1);
   double close2 = iClose(Symbol(), Period(), 2);
   double adx = iADX(Symbol(), Period(), ADX_Period, PRICE_CLOSE, MODE_MAIN, 1);
   
   bool sarBelowPrice1 = sar1 < close1;
   bool sarBelowPrice2 = sar2 < close2;
   bool strongTrend = adx > ADX_Threshold;
   
   bool buySignal = sarBelowPrice1 && !sarBelowPrice2 && strongTrend;
   bool sellSignal = !sarBelowPrice1 && sarBelowPrice2 && strongTrend;
   
   ManageOrders(buySignal, sellSignal, sar0);
}

void UpdateTrailingStops(double sarValue)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         {
            if(OrderType() == OP_BUY && sarValue < Bid && sarValue > OrderStopLoss())
               OrderModify(OrderTicket(), OrderOpenPrice(), sarValue, OrderTakeProfit(), 0, clrNONE);
            else if(OrderType() == OP_SELL && sarValue > Ask && (OrderStopLoss() == 0 || sarValue < OrderStopLoss()))
               OrderModify(OrderTicket(), OrderOpenPrice(), sarValue, OrderTakeProfit(), 0, clrNONE);
         }
      }
   }
}

void ManageOrders(bool buySignal, bool sellSignal, double sarValue)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         {
            if((OrderType() == OP_BUY && sellSignal) || (OrderType() == OP_SELL && buySignal))
               CloseOrder(OrderTicket());
            else
               return;
         }
      }
   }
   
   if(buySignal) OpenOrder(OP_BUY, sarValue);
   else if(sellSignal) OpenOrder(OP_SELL, sarValue);
}

void OpenOrder(int orderType, double sarValue)
{
   double price = (orderType == OP_BUY) ? Ask : Bid;
   OrderSend(Symbol(), orderType, LotSize, price, 10, sarValue, 0, "Parabolic SAR", MagicNumber, 0, clrNONE);
}

void CloseOrder(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   OrderClose(ticket, OrderLots(), (OrderType() == OP_BUY) ? Bid : Ask, 10, clrNONE);
}
//+------------------------------------------------------------------+
