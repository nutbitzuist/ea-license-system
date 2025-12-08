//+------------------------------------------------------------------+
//|                                     07_Support_Resistance_EA.mq5   |
//|                                    EA License Management System   |
//|                                                                    |
//| STRATEGY: Support/Resistance Bounce Trading                        |
//| LOGIC: Identify S/R levels using recent highs/lows. Buy at support |
//|        with bullish confirmation, sell at resistance with bearish. |
//| TIMEFRAME: H1-H4 recommended                                       |
//| PAIRS: All pairs                                                   |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

//--- Input parameters
input string   EA_ApiKey = "";           // API Key
input string   EA_ApiSecret = "";        // API Secret
input int      LookbackPeriod = 20;      // Lookback for S/R
input int      ZonePoints = 50;          // S/R Zone Size (points)
input double   LotSize = 0.1;            // Lot Size
input int      StopLoss = 100;           // Stop Loss (points)
input int      TakeProfit = 150;         // Take Profit (points)
input int      MagicNumber = 100007;     // Magic Number

//--- Global variables
CLicenseValidator* g_license;
bool g_isLicensed = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "support_resistance_ea", "1.0.0");
   g_isLicensed = g_license.ValidateLicense();
   
   if(!g_isLicensed)
   {
      Print("License validation failed: ", g_license.GetLastError());
      return INIT_FAILED;
   }
   
   Print("Support/Resistance EA initialized successfully");
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
   datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(lastBar == currentBar) return;
   lastBar = currentBar;
   
   //--- Find support and resistance levels
   double support = FindSupport();
   double resistance = FindResistance();
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double zoneSize = ZonePoints * point;
   
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   
   //--- Check for bounce signals
   bool buySignal = false;
   bool sellSignal = false;
   
   //--- Buy at support: price touches support zone and closes bullish
   if(low1 <= support + zoneSize && low1 >= support - zoneSize)
   {
      if(close1 > close2) // Bullish candle
      {
         buySignal = true;
      }
   }
   
   //--- Sell at resistance: price touches resistance zone and closes bearish
   if(high1 >= resistance - zoneSize && high1 <= resistance + zoneSize)
   {
      if(close1 < close2) // Bearish candle
      {
         sellSignal = true;
      }
   }
   
   //--- Check existing positions
   bool hasPosition = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            hasPosition = true;
            break;
         }
      }
   }
   
   if(!hasPosition)
   {
      if(buySignal) OpenPosition(ORDER_TYPE_BUY);
      else if(sellSignal) OpenPosition(ORDER_TYPE_SELL);
   }
}

//+------------------------------------------------------------------+
//| Find support level                                                 |
//+------------------------------------------------------------------+
double FindSupport()
{
   double lowestLow = iLow(_Symbol, PERIOD_CURRENT, 1);
   
   for(int i = 2; i <= LookbackPeriod; i++)
   {
      double low = iLow(_Symbol, PERIOD_CURRENT, i);
      if(low < lowestLow)
      {
         lowestLow = low;
      }
   }
   
   return lowestLow;
}

//+------------------------------------------------------------------+
//| Find resistance level                                              |
//+------------------------------------------------------------------+
double FindResistance()
{
   double highestHigh = iHigh(_Symbol, PERIOD_CURRENT, 1);
   
   for(int i = 2; i <= LookbackPeriod; i++)
   {
      double high = iHigh(_Symbol, PERIOD_CURRENT, i);
      if(high > highestHigh)
      {
         highestHigh = high;
      }
   }
   
   return highestHigh;
}

//+------------------------------------------------------------------+
//| Open a new position                                                |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = 0, tp = 0;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(orderType == ORDER_TYPE_BUY)
   {
      sl = price - StopLoss * point;
      tp = price + TakeProfit * point;
   }
   else
   {
      sl = price + StopLoss * point;
      tp = price - TakeProfit * point;
   }
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.magic = MagicNumber;
   request.comment = "S/R Bounce";
   request.deviation = 10;
   
   if(!OrderSend(request, result))
   {
      Print("OrderSend failed: ", GetLastError());
   }
}
//+------------------------------------------------------------------+
