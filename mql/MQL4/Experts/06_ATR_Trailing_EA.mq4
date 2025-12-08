//+------------------------------------------------------------------+
//|                                            06_ATR_Trailing_EA.mq4 |
//|                                    EA License Management System   |
//|                                                                    |
//| STRATEGY: ATR-Based Trailing Stop                                  |
//| LOGIC: Enter on trend confirmation, use ATR for dynamic trailing.  |
//| TIMEFRAME: H1-H4 recommended                                       |
//| PAIRS: Trending pairs                                              |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      MA_Period = 50;
input int      ATR_Period = 14;
input double   ATR_Multiplier = 2.0;
input double   LotSize = 0.1;
input int      MagicNumber = 100006;

CLicenseValidator* g_license;
bool g_isLicensed = false;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "atr_trailing_ea", "1.0.0");
   g_isLicensed = g_license.ValidateLicense();
   if(!g_isLicensed) { Print("License failed"); return INIT_FAILED; }
   Print("ATR Trailing EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   double atrValue = iATR(Symbol(), Period(), ATR_Period, 0);
   
   // Update trailing stops
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         {
            UpdateTrailingStop(OrderTicket(), atrValue);
         }
      }
   }
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   double ma1 = iMA(Symbol(), Period(), MA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ma2 = iMA(Symbol(), Period(), MA_Period, 0, MODE_EMA, PRICE_CLOSE, 2);
   double close1 = iClose(Symbol(), Period(), 1);
   double close2 = iClose(Symbol(), Period(), 2);
   
   bool buySignal = close1 > ma1 && close2 <= ma2;
   bool sellSignal = close1 < ma1 && close2 >= ma2;
   
   bool hasOrder = false;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
            hasOrder = true;
   }
   
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
   OrderSend(Symbol(), orderType, LotSize, price, 10, sl, 0, "ATR Trailing", MagicNumber, 0, clrNONE);
}

void UpdateTrailingStop(int ticket, double atrValue)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   
   double trailDistance = atrValue * ATR_Multiplier;
   double currentSL = OrderStopLoss();
   double openPrice = OrderOpenPrice();
   
   if(OrderType() == OP_BUY)
   {
      double newSL = Bid - trailDistance;
      if(newSL > currentSL && newSL > openPrice)
         OrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE);
   }
   else
   {
      double newSL = Ask + trailDistance;
      if(newSL < currentSL && newSL < openPrice)
         OrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE);
   }
}
//+------------------------------------------------------------------+
