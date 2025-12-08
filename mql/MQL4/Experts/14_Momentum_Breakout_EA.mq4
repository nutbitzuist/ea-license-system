//+------------------------------------------------------------------+
//|                                       14_Momentum_Breakout_EA.mq4 |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Momentum-Confirmed Breakout                              |
//| Combines range breakouts with CCI momentum and volume spikes.     |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      RangePeriod = 20;
input int      CCI_Period = 14;
input int      CCI_Level = 100;
input double   VolumeMultiplier = 1.5;
input int      ATR_Period = 14;
input double   ATR_Multiplier = 2.0;
input double   LotSize = 0.1;
input int      MagicNumber = 100014;

CLicenseValidator* g_license;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "momentum_breakout_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   Print("Momentum Breakout EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   double atrValue = iATR(Symbol(), Period(), ATR_Period, 0);
   UpdateTrailingStops(atrValue);
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   double cci = iCCI(Symbol(), Period(), CCI_Period, PRICE_TYPICAL, 1);
   
   double rangeHigh = iHigh(Symbol(), Period(), 1);
   double rangeLow = iLow(Symbol(), Period(), 1);
   for(int i = 2; i <= RangePeriod; i++)
   {
      if(iHigh(Symbol(), Period(), i) > rangeHigh) rangeHigh = iHigh(Symbol(), Period(), i);
      if(iLow(Symbol(), Period(), i) < rangeLow) rangeLow = iLow(Symbol(), Period(), i);
   }
   
   double close1 = iClose(Symbol(), Period(), 1);
   double close2 = iClose(Symbol(), Period(), 2);
   
   double avgVolume = 0;
   for(int i = 1; i <= 20; i++) avgVolume += (double)iVolume(Symbol(), Period(), i);
   avgVolume /= 20;
   bool volumeSpike = iVolume(Symbol(), Period(), 1) > avgVolume * VolumeMultiplier;
   
   bool buySignal = close1 > rangeHigh && close2 <= rangeHigh && cci > CCI_Level && volumeSpike;
   bool sellSignal = close1 < rangeLow && close2 >= rangeLow && cci < -CCI_Level && volumeSpike;
   
   ManageOrders(buySignal, sellSignal, atrValue);
}

void UpdateTrailingStops(double atrValue)
{
   double trailDistance = atrValue * ATR_Multiplier;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         {
            if(OrderType() == OP_BUY)
            {
               double newSL = Bid - trailDistance;
               if(newSL > OrderStopLoss() && newSL > OrderOpenPrice())
                  OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE);
            }
            else
            {
               double newSL = Ask + trailDistance;
               if((OrderStopLoss() == 0 || newSL < OrderStopLoss()) && newSL < OrderOpenPrice())
                  OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE);
            }
         }
      }
   }
}

void ManageOrders(bool buySignal, bool sellSignal, double atrValue)
{
   bool hasOrder = false;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
            hasOrder = true;
   
   if(!hasOrder)
   {
      if(buySignal) OpenOrder(OP_BUY, atrValue);
      else if(sellSignal) OpenOrder(OP_SELL, atrValue);
   }
}

void OpenOrder(int orderType, double atrValue)
{
   double price = (orderType == OP_BUY) ? Ask : Bid;
   double sl = (orderType == OP_BUY) ? price - atrValue * ATR_Multiplier : price + atrValue * ATR_Multiplier;
   OrderSend(Symbol(), orderType, LotSize, price, 10, sl, 0, "Momentum BO", MagicNumber, 0, clrNONE);
}
//+------------------------------------------------------------------+
