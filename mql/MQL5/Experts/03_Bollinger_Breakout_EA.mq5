//+------------------------------------------------------------------+
//|                                        03_Bollinger_Breakout_EA.mq5|
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
double g_bbUpper[], g_bbLower[], g_bbMiddle[];
int g_bb_handle;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
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
   
   g_bb_handle = iBands(_Symbol, PERIOD_CURRENT, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
   
   if(g_bb_handle == INVALID_HANDLE)
   {
      Print("Failed to create Bollinger Bands indicator");
      return INIT_FAILED;
   }
   
   ArraySetAsSeries(g_bbUpper, true);
   ArraySetAsSeries(g_bbLower, true);
   ArraySetAsSeries(g_bbMiddle, true);
   
   Print("Bollinger Breakout EA initialized successfully");
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
   
   if(g_bb_handle != INVALID_HANDLE) IndicatorRelease(g_bb_handle);
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
   
   if(CopyBuffer(g_bb_handle, 1, 0, 3, g_bbUpper) < 3) return;  // Upper band
   if(CopyBuffer(g_bb_handle, 2, 0, 3, g_bbLower) < 3) return;  // Lower band
   if(CopyBuffer(g_bb_handle, 0, 0, 3, g_bbMiddle) < 3) return; // Middle band
   
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   
   //--- Breakout signals
   bool buySignal = close1 > g_bbUpper[1] && close2 <= g_bbUpper[2];
   bool sellSignal = close1 < g_bbLower[1] && close2 >= g_bbLower[2];
   
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
            
            //--- Exit when price returns to middle band
            double currentClose = iClose(_Symbol, PERIOD_CURRENT, 0);
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && currentClose < g_bbMiddle[0])
            {
               ClosePosition(PositionGetTicket(i));
               hasPosition = false;
            }
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && currentClose > g_bbMiddle[0])
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
   request.comment = "BB Breakout";
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
