//+------------------------------------------------------------------+
//|                                            06_ATR_Trailing_EA.mq5 |
//|                                    EA License Management System   |
//|                                                                    |
//| STRATEGY: ATR-Based Trailing Stop                                  |
//| LOGIC: Enter on trend confirmation (price above/below MA), use     |
//|        ATR multiplier for dynamic trailing stop. Rides trends.     |
//| TIMEFRAME: H1-H4 recommended                                       |
//| PAIRS: Trending pairs                                              |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

//--- Input parameters
input string   EA_ApiKey = "";           // API Key
input string   EA_ApiSecret = "";        // API Secret
input int      MA_Period = 50;           // MA Period for trend
input int      ATR_Period = 14;          // ATR Period
input double   ATR_Multiplier = 2.0;     // ATR Multiplier for SL
input double   LotSize = 0.1;            // Lot Size
input int      MagicNumber = 100006;     // Magic Number

//--- Global variables
CLicenseValidator* g_license;
bool g_isLicensed = false;
double g_ma[], g_atr[];
int g_ma_handle, g_atr_handle;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "atr_trailing_ea", "1.0.0");
   g_isLicensed = g_license.ValidateLicense();
   
   if(!g_isLicensed)
   {
      Print("License validation failed: ", g_license.GetLastError());
      return INIT_FAILED;
   }
   
   g_ma_handle = iMA(_Symbol, PERIOD_CURRENT, MA_Period, 0, MODE_EMA, PRICE_CLOSE);
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   
   if(g_ma_handle == INVALID_HANDLE || g_atr_handle == INVALID_HANDLE)
   {
      Print("Failed to create indicators");
      return INIT_FAILED;
   }
   
   ArraySetAsSeries(g_ma, true);
   ArraySetAsSeries(g_atr, true);
   
   Print("ATR Trailing EA initialized successfully");
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
   
   if(g_ma_handle != INVALID_HANDLE) IndicatorRelease(g_ma_handle);
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   if(CopyBuffer(g_ma_handle, 0, 0, 3, g_ma) < 3) return;
   if(CopyBuffer(g_atr_handle, 0, 0, 3, g_atr) < 3) return;
   
   double close = iClose(_Symbol, PERIOD_CURRENT, 0);
   double atrValue = g_atr[0];
   
   //--- Update trailing stops for existing positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            UpdateTrailingStop(PositionGetTicket(i), atrValue);
         }
      }
   }
   
   //--- Check for new entry on new bar
   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(lastBar == currentBar) return;
   lastBar = currentBar;
   
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   
   //--- Trend signals
   bool buySignal = close1 > g_ma[1] && close2 <= g_ma[2];
   bool sellSignal = close1 < g_ma[1] && close2 >= g_ma[2];
   
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
      if(buySignal) OpenPosition(ORDER_TYPE_BUY, atrValue);
      else if(sellSignal) OpenPosition(ORDER_TYPE_SELL, atrValue);
   }
}

//+------------------------------------------------------------------+
//| Open a new position                                                |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType, double atrValue)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = 0;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      sl = price - atrValue * ATR_Multiplier;
   }
   else
   {
      sl = price + atrValue * ATR_Multiplier;
   }
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = 0;  // No TP, use trailing stop
   request.magic = MagicNumber;
   request.comment = "ATR Trailing";
   request.deviation = 10;
   
   if(!OrderSend(request, result))
   {
      Print("OrderSend failed: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Update trailing stop                                               |
//+------------------------------------------------------------------+
void UpdateTrailingStop(ulong ticket, double atrValue)
{
   if(!PositionSelectByTicket(ticket)) return;
   
   double currentSL = PositionGetDouble(POSITION_SL);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double trailDistance = atrValue * ATR_Multiplier;
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      double newSL = currentPrice - trailDistance;
      if(newSL > currentSL && newSL > openPrice)
      {
         request.action = TRADE_ACTION_SLTP;
         request.symbol = _Symbol;
         request.position = ticket;
         request.sl = newSL;
         request.tp = PositionGetDouble(POSITION_TP);
         OrderSend(request, result);
      }
   }
   else
   {
      double newSL = currentPrice + trailDistance;
      if(newSL < currentSL && newSL < openPrice)
      {
         request.action = TRADE_ACTION_SLTP;
         request.symbol = _Symbol;
         request.position = ticket;
         request.sl = newSL;
         request.tp = PositionGetDouble(POSITION_TP);
         OrderSend(request, result);
      }
   }
}
//+------------------------------------------------------------------+
