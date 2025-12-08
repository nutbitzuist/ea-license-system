//+------------------------------------------------------------------+
//|                                        11_Multi_Timeframe_EA.mq5   |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Multi-Timeframe Trend Alignment                          |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| This EA uses a powerful multi-timeframe analysis approach to       |
//| ensure trades are taken only when multiple timeframes agree on     |
//| the trend direction. It checks H4 for the major trend, H1 for     |
//| the intermediate trend, and M15 for entry timing.                  |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. H4 Timeframe: Determines the major trend using 50 EMA          |
//|    - Price above EMA = Bullish bias                               |
//|    - Price below EMA = Bearish bias                               |
//| 2. H1 Timeframe: Confirms intermediate trend with 20 EMA          |
//|    - Must align with H4 direction                                 |
//| 3. M15 Timeframe: Entry trigger using RSI                         |
//|    - Buy: RSI crosses above 30 (oversold recovery)                |
//|    - Sell: RSI crosses below 70 (overbought rejection)            |
//|                                                                    |
//| ENTRY CONDITIONS:                                                  |
//| BUY: H4 bullish + H1 bullish + M15 RSI buy signal                 |
//| SELL: H4 bearish + H1 bearish + M15 RSI sell signal               |
//|                                                                    |
//| EXIT CONDITIONS:                                                   |
//| - Fixed Stop Loss and Take Profit                                 |
//| - Opposite signal closes position                                  |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: M15 (EA handles multi-TF internally)                 |
//| - Pairs: Major pairs (EURUSD, GBPUSD, USDJPY, AUDUSD)            |
//| - Risk: 1-2% per trade                                            |
//|                                                                    |
//| RISK LEVEL: Medium                                                 |
//| WIN RATE: ~55-60% expected                                        |
//| RISK:REWARD: 1:1.5 to 1:2                                         |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      H4_MA_Period = 50;        // H4 MA Period
input int      H1_MA_Period = 20;        // H1 MA Period
input int      RSI_Period = 14;          // RSI Period
input double   LotSize = 0.1;
input int      StopLoss = 200;
input int      TakeProfit = 300;
input int      MagicNumber = 100011;

CLicenseValidator* g_license;
int g_h4_ma_handle, g_h1_ma_handle, g_rsi_handle;
double g_h4_ma[], g_h1_ma[], g_rsi[];

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "multi_timeframe_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   g_h4_ma_handle = iMA(_Symbol, PERIOD_H4, H4_MA_Period, 0, MODE_EMA, PRICE_CLOSE);
   g_h1_ma_handle = iMA(_Symbol, PERIOD_H1, H1_MA_Period, 0, MODE_EMA, PRICE_CLOSE);
   g_rsi_handle = iRSI(_Symbol, PERIOD_M15, RSI_Period, PRICE_CLOSE);
   
   if(g_h4_ma_handle == INVALID_HANDLE || g_h1_ma_handle == INVALID_HANDLE || g_rsi_handle == INVALID_HANDLE)
      return INIT_FAILED;
   
   ArraySetAsSeries(g_h4_ma, true);
   ArraySetAsSeries(g_h1_ma, true);
   ArraySetAsSeries(g_rsi, true);
   
   Print("Multi-Timeframe EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   if(g_h4_ma_handle != INVALID_HANDLE) IndicatorRelease(g_h4_ma_handle);
   if(g_h1_ma_handle != INVALID_HANDLE) IndicatorRelease(g_h1_ma_handle);
   if(g_rsi_handle != INVALID_HANDLE) IndicatorRelease(g_rsi_handle);
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_M15, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_M15, 0);
   
   if(CopyBuffer(g_h4_ma_handle, 0, 0, 2, g_h4_ma) < 2) return;
   if(CopyBuffer(g_h1_ma_handle, 0, 0, 2, g_h1_ma) < 2) return;
   if(CopyBuffer(g_rsi_handle, 0, 0, 3, g_rsi) < 3) return;
   
   double h4_close = iClose(_Symbol, PERIOD_H4, 0);
   double h1_close = iClose(_Symbol, PERIOD_H1, 0);
   
   bool h4_bullish = h4_close > g_h4_ma[0];
   bool h1_bullish = h1_close > g_h1_ma[0];
   bool rsi_buy = g_rsi[1] > 30 && g_rsi[2] <= 30;
   bool rsi_sell = g_rsi[1] < 70 && g_rsi[2] >= 70;
   
   bool buySignal = h4_bullish && h1_bullish && rsi_buy;
   bool sellSignal = !h4_bullish && !h1_bullish && rsi_sell;
   
   ManagePositions(buySignal, sellSignal);
}

void ManagePositions(bool buySignal, bool sellSignal)
{
   bool hasPosition = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            hasPosition = true;
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
   request.comment = "MTF EA";
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
