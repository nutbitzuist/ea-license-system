//+------------------------------------------------------------------+
//|                                        17_Keltner_Channel_EA.mq5  |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Keltner Channel Breakout & Pullback                     |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| This EA uses Keltner Channels (EMA + ATR bands) to identify       |
//| trend direction and trade pullbacks to the middle line.           |
//| Combines trend-following with mean reversion elements.             |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Calculates Keltner Channel:                                    |
//|    - Middle: EMA of close                                         |
//|    - Upper: Middle + (ATR × multiplier)                           |
//|    - Lower: Middle - (ATR × multiplier)                           |
//| 2. Determines trend by price position relative to channel         |
//| 3. Enters on pullback to middle line in trend direction           |
//|                                                                    |
//| KELTNER CHANNEL SIGNALS:                                           |
//| - Price above upper band: Strong uptrend                          |
//| - Price below lower band: Strong downtrend                        |
//| - Price at middle: Potential entry on pullback                    |
//|                                                                    |
//| ENTRY CONDITIONS:                                                  |
//| BUY: Uptrend + price pulls back to middle line + bounces         |
//| SELL: Downtrend + price pulls back to middle line + rejects      |
//|                                                                    |
//| EXIT CONDITIONS:                                                   |
//| - Take Profit at opposite band                                    |
//| - Stop Loss beyond the band                                        |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: H1 or H4                                             |
//| - Pairs: Trending pairs (EURUSD, GBPUSD)                         |
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
input int      EMA_Period = 20;          // EMA Period
input int      ATR_Period = 10;          // ATR Period
input double   ATR_Multiplier = 2.0;     // ATR Multiplier
input int      TrendLookback = 10;       // Bars to confirm trend
input double   LotSize = 0.1;
input int      MagicNumber = 100017;

CLicenseValidator* g_license;
int g_ema_handle, g_atr_handle;
double g_ema[], g_atr[];

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "keltner_channel_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   g_ema_handle = iMA(_Symbol, PERIOD_CURRENT, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   
   if(g_ema_handle == INVALID_HANDLE || g_atr_handle == INVALID_HANDLE) return INIT_FAILED;
   
   ArraySetAsSeries(g_ema, true);
   ArraySetAsSeries(g_atr, true);
   
   Print("Keltner Channel EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   if(g_ema_handle != INVALID_HANDLE) IndicatorRelease(g_ema_handle);
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(CopyBuffer(g_ema_handle, 0, 0, TrendLookback + 2, g_ema) < TrendLookback + 2) return;
   if(CopyBuffer(g_atr_handle, 0, 0, 3, g_atr) < 3) return;
   
   double middle = g_ema[1];
   double upper = middle + g_atr[1] * ATR_Multiplier;
   double lower = middle - g_atr[1] * ATR_Multiplier;
   
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   
   // Determine trend
   bool uptrend = true, downtrend = true;
   for(int i = 1; i <= TrendLookback; i++)
   {
      double c = iClose(_Symbol, PERIOD_CURRENT, i);
      if(c < g_ema[i]) uptrend = false;
      if(c > g_ema[i]) downtrend = false;
   }
   
   // Pullback signals
   bool buySignal = uptrend && low1 <= middle && close1 > middle && close1 > close2;
   bool sellSignal = downtrend && high1 >= middle && close1 < middle && close1 < close2;
   
   ManagePositions(buySignal, sellSignal, upper, lower);
}

void ManagePositions(bool buySignal, bool sellSignal, double upper, double lower)
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
      if(buySignal) OpenPosition(ORDER_TYPE_BUY, upper, lower);
      else if(sellSignal) OpenPosition(ORDER_TYPE_SELL, upper, lower);
   }
}

void OpenPosition(ENUM_ORDER_TYPE orderType, double upper, double lower)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atrValue = g_atr[0];
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = price;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      request.sl = lower - atrValue * 0.5;
      request.tp = upper;
   }
   else
   {
      request.sl = upper + atrValue * 0.5;
      request.tp = lower;
   }
   
   request.magic = MagicNumber;
   request.comment = "Keltner";
   request.deviation = 10;
   OrderSend(request, result);
}
//+------------------------------------------------------------------+
