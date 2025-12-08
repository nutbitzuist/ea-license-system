//+------------------------------------------------------------------+
//|                                          04_MACD_Divergence_EA.mq5 |
//|                                    EA License Management System   |
//|                                                                    |
//| STRATEGY: MACD Histogram Divergence                                |
//| LOGIC: Trade when MACD histogram crosses zero line with momentum.  |
//|        Buy on positive crossover, sell on negative crossover.      |
//| TIMEFRAME: H4 recommended                                          |
//| PAIRS: All major pairs                                             |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

//--- Input parameters
input string   EA_ApiKey = "";           // API Key
input string   EA_ApiSecret = "";        // API Secret
input int      MACD_Fast = 12;           // MACD Fast EMA
input int      MACD_Slow = 26;           // MACD Slow EMA
input int      MACD_Signal = 9;          // MACD Signal
input double   LotSize = 0.1;            // Lot Size
input int      StopLoss = 150;           // Stop Loss (points)
input int      TakeProfit = 250;         // Take Profit (points)
input int      MagicNumber = 100004;     // Magic Number

//--- Global variables
CLicenseValidator* g_license;
bool g_isLicensed = false;
double g_macdMain[], g_macdSignal[], g_macdHist[];
int g_macd_handle;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "macd_divergence_ea", "1.0.0");
   g_isLicensed = g_license.ValidateLicense();
   
   if(!g_isLicensed)
   {
      Print("License validation failed: ", g_license.GetLastError());
      return INIT_FAILED;
   }
   
   g_macd_handle = iMACD(_Symbol, PERIOD_CURRENT, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
   
   if(g_macd_handle == INVALID_HANDLE)
   {
      Print("Failed to create MACD indicator");
      return INIT_FAILED;
   }
   
   ArraySetAsSeries(g_macdMain, true);
   ArraySetAsSeries(g_macdSignal, true);
   ArraySetAsSeries(g_macdHist, true);
   
   Print("MACD Divergence EA initialized successfully");
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
   
   if(g_macd_handle != INVALID_HANDLE) IndicatorRelease(g_macd_handle);
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
   
   if(CopyBuffer(g_macd_handle, 0, 0, 3, g_macdMain) < 3) return;
   if(CopyBuffer(g_macd_handle, 1, 0, 3, g_macdSignal) < 3) return;
   
   //--- Calculate histogram
   double hist1 = g_macdMain[1] - g_macdSignal[1];
   double hist2 = g_macdMain[2] - g_macdSignal[2];
   
   //--- Zero line crossover signals
   bool buySignal = hist1 > 0 && hist2 <= 0;
   bool sellSignal = hist1 < 0 && hist2 >= 0;
   
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
   request.comment = "MACD Divergence";
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
