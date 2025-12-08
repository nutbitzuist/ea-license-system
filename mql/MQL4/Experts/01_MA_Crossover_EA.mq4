//+------------------------------------------------------------------+
//|                                            01_MA_Crossover_EA.mq4 |
//|                                    EA License Management System   |
//|                                                                    |
//| STRATEGY: Moving Average Crossover                                 |
//| LOGIC: Buy when fast MA crosses above slow MA, sell when crosses   |
//|        below. Uses EMA for faster response to price changes.       |
//| TIMEFRAME: H1 recommended                                          |
//| PAIRS: Major pairs (EURUSD, GBPUSD, USDJPY)                       |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

//--- Input parameters
input string   EA_ApiKey = "";           // API Key
input string   EA_ApiSecret = "";        // API Secret
input int      FastMA_Period = 10;       // Fast MA Period
input int      SlowMA_Period = 50;       // Slow MA Period
input int      MA_Method = MODE_EMA;     // MA Method
input double   LotSize = 0.1;            // Lot Size
input int      StopLoss = 100;           // Stop Loss (points)
input int      TakeProfit = 200;         // Take Profit (points)
input int      MagicNumber = 100001;     // Magic Number

//--- Global variables
CLicenseValidator* g_license;
bool g_isLicensed = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "ma_crossover_ea", "1.0.0");
   g_isLicensed = g_license.ValidateLicense();
   
   if(!g_isLicensed)
   {
      Print("License validation failed: ", g_license.GetLastError());
      return INIT_FAILED;
   }
   
   Print("MA Crossover EA initialized successfully");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_license != NULL)
   {
      delete g_license;
      g_license = NULL;
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   static datetime lastBar = 0;
   datetime currentBar = iTime(Symbol(), Period(), 0);
   if(lastBar == currentBar) return;
   lastBar = currentBar;
   
   //--- Get MA values
   double fastMA1 = iMA(Symbol(), Period(), FastMA_Period, 0, MA_Method, PRICE_CLOSE, 1);
   double fastMA2 = iMA(Symbol(), Period(), FastMA_Period, 0, MA_Method, PRICE_CLOSE, 2);
   double slowMA1 = iMA(Symbol(), Period(), SlowMA_Period, 0, MA_Method, PRICE_CLOSE, 1);
   double slowMA2 = iMA(Symbol(), Period(), SlowMA_Period, 0, MA_Method, PRICE_CLOSE, 2);
   
   //--- Crossover signals
   bool buySignal = fastMA1 > slowMA1 && fastMA2 <= slowMA2;
   bool sellSignal = fastMA1 < slowMA1 && fastMA2 >= slowMA2;
   
   //--- Check existing orders
   int buyCount = 0, sellCount = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         {
            if(OrderType() == OP_BUY)
            {
               buyCount++;
               if(sellSignal) CloseOrder(OrderTicket());
            }
            else if(OrderType() == OP_SELL)
            {
               sellCount++;
               if(buySignal) CloseOrder(OrderTicket());
            }
         }
      }
   }
   
   //--- Open new orders
   if(buyCount == 0 && sellCount == 0)
   {
      if(buySignal) OpenOrder(OP_BUY);
      else if(sellSignal) OpenOrder(OP_SELL);
   }
}

//+------------------------------------------------------------------+
//| Open a new order                                                   |
//+------------------------------------------------------------------+
void OpenOrder(int orderType)
{
   double price = (orderType == OP_BUY) ? Ask : Bid;
   double sl = 0, tp = 0;
   
   if(orderType == OP_BUY)
   {
      sl = price - StopLoss * Point;
      tp = price + TakeProfit * Point;
   }
   else
   {
      sl = price + StopLoss * Point;
      tp = price - TakeProfit * Point;
   }
   
   int ticket = OrderSend(Symbol(), orderType, LotSize, price, 10, sl, tp, "MA Crossover", MagicNumber, 0, clrNONE);
   
   if(ticket < 0)
   {
      Print("OrderSend failed: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Close an order                                                     |
//+------------------------------------------------------------------+
void CloseOrder(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   
   double price = (OrderType() == OP_BUY) ? Bid : Ask;
   
   if(!OrderClose(ticket, OrderLots(), price, 10, clrNONE))
   {
      Print("OrderClose failed: ", GetLastError());
   }
}
//+------------------------------------------------------------------+
