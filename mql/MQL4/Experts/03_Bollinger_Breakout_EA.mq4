//+------------------------------------------------------------------+
//|                                        03_Bollinger_Breakout_EA.mq4|
//|                                    EA License Management System   |
//|                                                                    |
//| STRATEGY: Bollinger Bands Breakout                                 |
//| LOGIC: Buy when price breaks above upper band with momentum,       |
//|        sell when price breaks below lower band. Trend following.   |
//| TIMEFRAME: H1 recommended                                          |
//| PAIRS: Trending pairs (GBPUSD, EURJPY)                            |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

//--- Input parameters
input string   EA_ApiKey = "";           // API Key
input string   EA_ApiSecret = "";        // API Secret
input int      BB_Period = 20;           // Bollinger Period
input double   BB_Deviation = 2.0;       // Bollinger Deviation
input double   LotSize = 0.1;            // Lot Size
input int      StopLoss = 200;           // Stop Loss (points)
input int      TakeProfit = 300;         // Take Profit (points)
input int      MagicNumber = 100003;     // Magic Number

//--- Global variables
CLicenseValidator* g_license;
bool g_isLicensed = false;

//+------------------------------------------------------------------+
int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "bollinger_breakout_ea", "1.0.0");
   g_isLicensed = g_license.ValidateLicense();
   
   if(!g_isLicensed)
   {
      Print("License validation failed: ", g_license.GetLastError());
      return INIT_FAILED;
   }
   
   Print("Bollinger Breakout EA initialized successfully");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   static datetime lastBar = 0;
   datetime currentBar = iTime(Symbol(), Period(), 0);
   if(lastBar == currentBar) return;
   lastBar = currentBar;
   
   double upper1 = iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_UPPER, 1);
   double upper2 = iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_UPPER, 2);
   double lower1 = iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_LOWER, 1);
   double lower2 = iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_LOWER, 2);
   double middle = iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_MAIN, 0);
   
   double close1 = iClose(Symbol(), Period(), 1);
   double close2 = iClose(Symbol(), Period(), 2);
   
   bool buySignal = close1 > upper1 && close2 <= upper2;
   bool sellSignal = close1 < lower1 && close2 >= lower2;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         {
            double currentClose = iClose(Symbol(), Period(), 0);
            if(OrderType() == OP_BUY && currentClose < middle)
               CloseOrder(OrderTicket());
            else if(OrderType() == OP_SELL && currentClose > middle)
               CloseOrder(OrderTicket());
            return;
         }
      }
   }
   
   if(buySignal) OpenOrder(OP_BUY);
   else if(sellSignal) OpenOrder(OP_SELL);
}

//+------------------------------------------------------------------+
void OpenOrder(int orderType)
{
   double price = (orderType == OP_BUY) ? Ask : Bid;
   double sl = (orderType == OP_BUY) ? price - StopLoss * Point : price + StopLoss * Point;
   double tp = (orderType == OP_BUY) ? price + TakeProfit * Point : price - TakeProfit * Point;
   
   int ticket = OrderSend(Symbol(), orderType, LotSize, price, 10, sl, tp, "BB Breakout", MagicNumber, 0, clrNONE);
   if(ticket < 0) Print("OrderSend failed: ", GetLastError());
}

//+------------------------------------------------------------------+
void CloseOrder(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   double price = (OrderType() == OP_BUY) ? Bid : Ask;
   if(!OrderClose(ticket, OrderLots(), price, 10, clrNONE))
      Print("OrderClose failed: ", GetLastError());
}
//+------------------------------------------------------------------+
