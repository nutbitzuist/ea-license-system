//+------------------------------------------------------------------+
//|                                            01_MA_Crossover_EA.mq5 |
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
input ENUM_MA_METHOD MA_Method = MODE_EMA; // MA Method
input double   LotSize = 0.1;            // Lot Size
input int      StopLoss = 100;           // Stop Loss (points)
input int      TakeProfit = 200;         // Take Profit (points)
input int      MagicNumber = 100001;     // Magic Number

//--- Global variables
CLicenseValidator* g_license;
bool g_isLicensed = false;
double g_fastMA[], g_slowMA[];
int g_fastMA_handle, g_slowMA_handle;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize license validator
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "ma_crossover_ea", "1.0.0");
   g_isLicensed = g_license.ValidateLicense();
   
   if(!g_isLicensed)
   {
      Print("License validation failed: ", g_license.GetLastError());
      return INIT_FAILED;
   }
   
   //--- Initialize MA indicators
   g_fastMA_handle = iMA(_Symbol, PERIOD_CURRENT, FastMA_Period, 0, MA_Method, PRICE_CLOSE);
   g_slowMA_handle = iMA(_Symbol, PERIOD_CURRENT, SlowMA_Period, 0, MA_Method, PRICE_CLOSE);
   
   if(g_fastMA_handle == INVALID_HANDLE || g_slowMA_handle == INVALID_HANDLE)
   {
      Print("Failed to create MA indicators");
      return INIT_FAILED;
   }
   
   ArraySetAsSeries(g_fastMA, true);
   ArraySetAsSeries(g_slowMA, true);
   
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
   
   if(g_fastMA_handle != INVALID_HANDLE) IndicatorRelease(g_fastMA_handle);
   if(g_slowMA_handle != INVALID_HANDLE) IndicatorRelease(g_slowMA_handle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Periodic license check
   if(!g_license.PeriodicCheck())
   {
      Print("License check failed");
      return;
   }
   
   //--- Only trade on new bar
   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(lastBar == currentBar) return;
   lastBar = currentBar;
   
   //--- Get MA values
   if(CopyBuffer(g_fastMA_handle, 0, 0, 3, g_fastMA) < 3) return;
   if(CopyBuffer(g_slowMA_handle, 0, 0, 3, g_slowMA) < 3) return;
   
   //--- Check for crossover signals
   bool buySignal = g_fastMA[1] > g_slowMA[1] && g_fastMA[2] <= g_slowMA[2];
   bool sellSignal = g_fastMA[1] < g_slowMA[1] && g_fastMA[2] >= g_slowMA[2];
   
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
   
   //--- Open new position
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
   request.comment = "MA Crossover";
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
