//+------------------------------------------------------------------+
//|                                             02_RSI_Reversal_EA.mq4 |
//|                                    EA License Management System   |
//|                                                                    |
//| STRATEGY: RSI Overbought/Oversold Reversal                        |
//| LOGIC: Buy when RSI crosses above oversold level (30), sell when   |
//|        RSI crosses below overbought level (70). Mean reversion.    |
//| TIMEFRAME: H4 recommended                                          |
//| PAIRS: Range-bound pairs work best                                 |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

//--- Input parameters
input string   EA_ApiKey = "";           // API Key
input string   EA_ApiSecret = "";        // API Secret
input int      RSI_Period = 14;          // RSI Period
input int      OverboughtLevel = 70;     // Overbought Level
input int      OversoldLevel = 30;       // Oversold Level
input double   LotSize = 0.1;            // Lot Size
input int      StopLoss = 150;           // Stop Loss (points)
input int      TakeProfit = 100;         // Take Profit (points)
input int      MagicNumber = 100002;     // Magic Number

//--- Global variables
CLicenseValidator* g_license;
bool g_isLicensed = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "rsi_reversal_ea", "1.0.0");
   g_isLicensed = g_license.ValidateLicense();
   
   if(!g_isLicensed)
   {
      Print("License validation failed: ", g_license.GetLastError());
      return INIT_FAILED;
   }
   
   Print("RSI Reversal EA initialized successfully");
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
   
   double rsi1 = iRSI(Symbol(), Period(), RSI_Period, PRICE_CLOSE, 1);
   double rsi2 = iRSI(Symbol(), Period(), RSI_Period, PRICE_CLOSE, 2);
   
   bool buySignal = rsi1 > OversoldLevel && rsi2 <= OversoldLevel;
   bool sellSignal = rsi1 < OverboughtLevel && rsi2 >= OverboughtLevel;
   
   bool hasOrder = false;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         {
            hasOrder = true;
            break;
         }
      }
   }
   
   if(!hasOrder)
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
   
   int ticket = OrderSend(Symbol(), orderType, LotSize, price, 10, sl, tp, "RSI Reversal", MagicNumber, 0, clrNONE);
   
   if(ticket < 0)
   {
      Print("OrderSend failed: ", GetLastError());
   }
}
//+------------------------------------------------------------------+
