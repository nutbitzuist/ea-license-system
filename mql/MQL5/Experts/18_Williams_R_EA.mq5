//+------------------------------------------------------------------+
//|                                           18_Williams_R_EA.mq5    |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Williams %R with Trend Filter                           |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| This EA uses Williams %R oscillator for timing entries while      |
//| using a moving average for trend direction. Only trades in the    |
//| direction of the trend when Williams %R shows extreme readings.   |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Determines trend using 100-period EMA                          |
//| 2. Monitors Williams %R for extreme readings                      |
//| 3. Enters when %R exits extreme zone in trend direction           |
//|                                                                    |
//| WILLIAMS %R LEVELS:                                                |
//| - Above -20: Overbought (potential sell in downtrend)             |
//| - Below -80: Oversold (potential buy in uptrend)                  |
//| - Between -20 and -80: Neutral zone                               |
//|                                                                    |
//| ENTRY CONDITIONS:                                                  |
//| BUY: Uptrend + %R crosses above -80 (exits oversold)             |
//| SELL: Downtrend + %R crosses below -20 (exits overbought)        |
//|                                                                    |
//| EXIT CONDITIONS:                                                   |
//| - %R reaches opposite extreme                                     |
//| - Fixed Stop Loss and Take Profit                                 |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: H1 or H4                                             |
//| - Pairs: All major pairs                                          |
//|                                                                    |
//| RISK LEVEL: Medium                                                 |
//| WIN RATE: ~55-60% expected                                        |
//| RISK:REWARD: 1:1.5                                                |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      WPR_Period = 14;          // Williams %R Period
input int      MA_Period = 100;          // Trend MA Period
input int      OverboughtLevel = -20;    // Overbought Level
input int      OversoldLevel = -80;      // Oversold Level
input double   LotSize = 0.1;
input int      StopLoss = 150;
input int      TakeProfit = 225;
input int      MagicNumber = 100018;

CLicenseValidator* g_license;
int g_wpr_handle, g_ma_handle;
double g_wpr[], g_ma[];

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "williams_r_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   g_wpr_handle = iWPR(_Symbol, PERIOD_CURRENT, WPR_Period);
   g_ma_handle = iMA(_Symbol, PERIOD_CURRENT, MA_Period, 0, MODE_EMA, PRICE_CLOSE);
   
   if(g_wpr_handle == INVALID_HANDLE || g_ma_handle == INVALID_HANDLE) return INIT_FAILED;
   
   ArraySetAsSeries(g_wpr, true);
   ArraySetAsSeries(g_ma, true);
   
   Print("Williams %R EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   if(g_wpr_handle != INVALID_HANDLE) IndicatorRelease(g_wpr_handle);
   if(g_ma_handle != INVALID_HANDLE) IndicatorRelease(g_ma_handle);
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(CopyBuffer(g_wpr_handle, 0, 0, 3, g_wpr) < 3) return;
   if(CopyBuffer(g_ma_handle, 0, 0, 2, g_ma) < 2) return;
   
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   bool uptrend = close1 > g_ma[1];
   bool downtrend = close1 < g_ma[1];
   
   // Williams %R crossover signals
   bool wprBuySignal = g_wpr[1] > OversoldLevel && g_wpr[2] <= OversoldLevel;
   bool wprSellSignal = g_wpr[1] < OverboughtLevel && g_wpr[2] >= OverboughtLevel;
   
   bool buySignal = uptrend && wprBuySignal;
   bool sellSignal = downtrend && wprSellSignal;
   
   // Check for exit on existing positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            // Exit when %R reaches opposite extreme
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && g_wpr[1] > OverboughtLevel)
               ClosePosition(PositionGetTicket(i));
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && g_wpr[1] < OversoldLevel)
               ClosePosition(PositionGetTicket(i));
         }
      }
   }
   
   ManagePositions(buySignal, sellSignal);
}

void ManagePositions(bool buySignal, bool sellSignal)
{
   bool hasPosition = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
            hasPosition = true;
   }
   
   if(!hasPosition)
   {
      if(buySignal) OpenPosition(ORDER_TYPE_BUY);
      else if(sellSignal) OpenPosition(ORDER_TYPE_SELL);
   }
}

void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = price;
   request.sl = (orderType == ORDER_TYPE_BUY) ? price - StopLoss * point : price + StopLoss * point;
   request.tp = (orderType == ORDER_TYPE_BUY) ? price + TakeProfit * point : price - TakeProfit * point;
   request.magic = MagicNumber;
   request.comment = "Williams %R";
   request.deviation = 10;
   OrderSend(request, result);
}

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
   OrderSend(request, result);
}
//+------------------------------------------------------------------+
