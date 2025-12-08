//+------------------------------------------------------------------+
//|                                          08_Ichimoku_Cloud_EA.mq5 |
//|                                    EA License Management System   |
//|                                                                    |
//| STRATEGY: Ichimoku Cloud Trading                                   |
//| LOGIC: Buy when price is above cloud and Tenkan crosses above      |
//|        Kijun. Sell when price is below cloud and Tenkan crosses    |
//|        below Kijun. Strong trend-following system.                 |
//| TIMEFRAME: H4-D1 recommended                                       |
//| PAIRS: Trending pairs                                              |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

//--- Input parameters
input string   EA_ApiKey = "";           // API Key
input string   EA_ApiSecret = "";        // API Secret
input int      Tenkan_Period = 9;        // Tenkan-sen Period
input int      Kijun_Period = 26;        // Kijun-sen Period
input int      Senkou_Period = 52;       // Senkou Span B Period
input double   LotSize = 0.1;            // Lot Size
input int      StopLoss = 200;           // Stop Loss (points)
input int      TakeProfit = 400;         // Take Profit (points)
input int      MagicNumber = 100008;     // Magic Number

//--- Global variables
CLicenseValidator* g_license;
bool g_isLicensed = false;
double g_tenkan[], g_kijun[], g_senkouA[], g_senkouB[];
int g_ichimoku_handle;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "ichimoku_cloud_ea", "1.0.0");
   g_isLicensed = g_license.ValidateLicense();
   
   if(!g_isLicensed)
   {
      Print("License validation failed: ", g_license.GetLastError());
      return INIT_FAILED;
   }
   
   g_ichimoku_handle = iIchimoku(_Symbol, PERIOD_CURRENT, Tenkan_Period, Kijun_Period, Senkou_Period);
   
   if(g_ichimoku_handle == INVALID_HANDLE)
   {
      Print("Failed to create Ichimoku indicator");
      return INIT_FAILED;
   }
   
   ArraySetAsSeries(g_tenkan, true);
   ArraySetAsSeries(g_kijun, true);
   ArraySetAsSeries(g_senkouA, true);
   ArraySetAsSeries(g_senkouB, true);
   
   Print("Ichimoku Cloud EA initialized successfully");
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
   
   if(g_ichimoku_handle != INVALID_HANDLE) IndicatorRelease(g_ichimoku_handle);
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
   
   if(CopyBuffer(g_ichimoku_handle, 0, 0, 3, g_tenkan) < 3) return;  // Tenkan-sen
   if(CopyBuffer(g_ichimoku_handle, 1, 0, 3, g_kijun) < 3) return;   // Kijun-sen
   if(CopyBuffer(g_ichimoku_handle, 2, 0, 30, g_senkouA) < 30) return; // Senkou Span A
   if(CopyBuffer(g_ichimoku_handle, 3, 0, 30, g_senkouB) < 30) return; // Senkou Span B
   
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   
   //--- Cloud levels (shifted 26 periods ahead, so we look at index 26)
   double cloudTop = MathMax(g_senkouA[26], g_senkouB[26]);
   double cloudBottom = MathMin(g_senkouA[26], g_senkouB[26]);
   
   //--- Tenkan/Kijun crossover
   bool tenkanAboveKijun = g_tenkan[1] > g_kijun[1] && g_tenkan[2] <= g_kijun[2];
   bool tenkanBelowKijun = g_tenkan[1] < g_kijun[1] && g_tenkan[2] >= g_kijun[2];
   
   //--- Price position relative to cloud
   bool priceAboveCloud = close1 > cloudTop;
   bool priceBelowCloud = close1 < cloudBottom;
   
   //--- Signals
   bool buySignal = tenkanAboveKijun && priceAboveCloud;
   bool sellSignal = tenkanBelowKijun && priceBelowCloud;
   
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
            
            //--- Close on opposite signal
            if((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && sellSignal) ||
               (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && buySignal))
            {
               ClosePosition(PositionGetTicket(i));
               hasPosition = false;
            }
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
   request.comment = "Ichimoku Cloud";
   request.deviation = 10;
   
   if(!OrderSend(request, result))
   {
      Print("OrderSend failed: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Close a position                                                   |
//+------------------------------------------------------------------+
void ClosePosition(ulong ticket)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   if(!PositionSelectByTicket(ticket)) return;
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = PositionGetDouble(POSITION_VOLUME);
   request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = (request.type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   request.position = ticket;
   request.deviation = 10;
   
   if(!OrderSend(request, result))
   {
      Print("Close position failed: ", GetLastError());
   }
}
//+------------------------------------------------------------------+
