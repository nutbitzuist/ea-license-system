//+------------------------------------------------------------------+
//|                                           10_News_Filter_EA.mq5   |
//|                                    EA License Management System   |
//|                                                                    |
//| STRATEGY: Breakout with Volatility Filter                          |
//| LOGIC: Trades breakouts from consolidation ranges. Uses ADX to     |
//|        filter for strong trends and avoids low volatility periods. |
//|        Includes time filter to avoid news events.                  |
//| TIMEFRAME: M30-H1 recommended                                      |
//| PAIRS: All major pairs                                             |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

//--- Input parameters
input string   EA_ApiKey = "";           // API Key
input string   EA_ApiSecret = "";        // API Secret
input int      RangePeriod = 20;         // Range Lookback Period
input int      ADX_Period = 14;          // ADX Period
input int      ADX_Threshold = 25;       // ADX Threshold
input double   LotSize = 0.1;            // Lot Size
input int      StopLoss = 150;           // Stop Loss (points)
input int      TakeProfit = 200;         // Take Profit (points)
input int      StartHour = 8;            // Trading Start Hour (Server)
input int      EndHour = 20;             // Trading End Hour (Server)
input int      MagicNumber = 100010;     // Magic Number

//--- Global variables
CLicenseValidator* g_license;
bool g_isLicensed = false;
double g_adx[], g_plusDI[], g_minusDI[];
int g_adx_handle;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "news_filter_ea", "1.0.0");
   g_isLicensed = g_license.ValidateLicense();
   
   if(!g_isLicensed)
   {
      Print("License validation failed: ", g_license.GetLastError());
      return INIT_FAILED;
   }
   
   g_adx_handle = iADX(_Symbol, PERIOD_CURRENT, ADX_Period);
   
   if(g_adx_handle == INVALID_HANDLE)
   {
      Print("Failed to create ADX indicator");
      return INIT_FAILED;
   }
   
   ArraySetAsSeries(g_adx, true);
   ArraySetAsSeries(g_plusDI, true);
   ArraySetAsSeries(g_minusDI, true);
   
   Print("News Filter EA initialized successfully");
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
   
   if(g_adx_handle != INVALID_HANDLE) IndicatorRelease(g_adx_handle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   //--- Time filter
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < StartHour || dt.hour >= EndHour)
   {
      return; // Outside trading hours
   }
   
   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(lastBar == currentBar) return;
   lastBar = currentBar;
   
   //--- Get ADX values
   if(CopyBuffer(g_adx_handle, 0, 0, 3, g_adx) < 3) return;      // ADX
   if(CopyBuffer(g_adx_handle, 1, 0, 3, g_plusDI) < 3) return;   // +DI
   if(CopyBuffer(g_adx_handle, 2, 0, 3, g_minusDI) < 3) return;  // -DI
   
   //--- Check ADX threshold
   if(g_adx[1] < ADX_Threshold)
   {
      return; // Low volatility, skip
   }
   
   //--- Calculate range
   double rangeHigh = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double rangeLow = iLow(_Symbol, PERIOD_CURRENT, 1);
   
   for(int i = 2; i <= RangePeriod; i++)
   {
      double high = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low = iLow(_Symbol, PERIOD_CURRENT, i);
      if(high > rangeHigh) rangeHigh = high;
      if(low < rangeLow) rangeLow = low;
   }
   
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   
   //--- Breakout signals with DI confirmation
   bool buySignal = close1 > rangeHigh && close2 <= rangeHigh && g_plusDI[1] > g_minusDI[1];
   bool sellSignal = close1 < rangeLow && close2 >= rangeLow && g_minusDI[1] > g_plusDI[1];
   
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
   request.comment = "Breakout Filter";
   request.deviation = 10;
   
   if(!OrderSend(request, result))
   {
      Print("OrderSend failed: ", GetLastError());
   }
}
//+------------------------------------------------------------------+
