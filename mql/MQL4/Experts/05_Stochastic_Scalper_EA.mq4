//+------------------------------------------------------------------+
//|                                        05_Stochastic_Scalper_EA.mq4|
//|                                    EA License Management System   |
//|                                                                    |
//| STRATEGY: Stochastic Scalping                                      |
//| LOGIC: Quick trades based on stochastic crossovers in zones.       |
//| TIMEFRAME: M15 recommended                                         |
//| PAIRS: High liquidity pairs (EURUSD, USDJPY)                      |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      Stoch_K = 5;
input int      Stoch_D = 3;
input int      Stoch_Slowing = 3;
input int      OverboughtLevel = 80;
input int      OversoldLevel = 20;
input double   LotSize = 0.1;
input int      StopLoss = 50;
input int      TakeProfit = 80;
input int      MagicNumber = 100005;

CLicenseValidator* g_license;
bool g_isLicensed = false;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "stochastic_scalper_ea", "1.0.0");
   g_isLicensed = g_license.ValidateLicense();
   if(!g_isLicensed) { Print("License failed"); return INIT_FAILED; }
   Print("Stochastic Scalper EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   double k1 = iStochastic(Symbol(), Period(), Stoch_K, Stoch_D, Stoch_Slowing, MODE_SMA, 0, MODE_MAIN, 1);
   double k2 = iStochastic(Symbol(), Period(), Stoch_K, Stoch_D, Stoch_Slowing, MODE_SMA, 0, MODE_MAIN, 2);
   double d1 = iStochastic(Symbol(), Period(), Stoch_K, Stoch_D, Stoch_Slowing, MODE_SMA, 0, MODE_SIGNAL, 1);
   double d2 = iStochastic(Symbol(), Period(), Stoch_K, Stoch_D, Stoch_Slowing, MODE_SMA, 0, MODE_SIGNAL, 2);
   
   bool buySignal = k1 > d1 && k2 <= d2 && k1 < OversoldLevel + 10;
   bool sellSignal = k1 < d1 && k2 >= d2 && k1 > OverboughtLevel - 10;
   
   bool hasOrder = false;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
            hasOrder = true;
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
   OrderSend(Symbol(), orderType, LotSize, price, 10, sl, tp, "Stoch Scalper", MagicNumber, 0, clrNONE);
}
//+------------------------------------------------------------------+
