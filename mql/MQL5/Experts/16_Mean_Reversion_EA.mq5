//+------------------------------------------------------------------+
//|                                        16_Mean_Reversion_EA.mq5   |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Statistical Mean Reversion                               |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| This EA uses statistical analysis to identify when price has       |
//| deviated significantly from its mean and is likely to revert.      |
//| Uses Z-Score to measure standard deviations from the mean.         |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Calculates the moving average (mean) over N periods            |
//| 2. Calculates standard deviation of price from the mean           |
//| 3. Computes Z-Score: (Price - Mean) / StdDev                      |
//| 4. Trades when Z-Score exceeds threshold (extreme deviation)      |
//|                                                                    |
//| Z-SCORE INTERPRETATION:                                            |
//| - Z > +2.0: Price is 2 std devs above mean (overbought)           |
//| - Z < -2.0: Price is 2 std devs below mean (oversold)             |
//| - Z near 0: Price is at fair value                                |
//|                                                                    |
//| ENTRY CONDITIONS:                                                  |
//| BUY: Z-Score < -2.0 (extremely oversold)                          |
//| SELL: Z-Score > +2.0 (extremely overbought)                       |
//|                                                                    |
//| EXIT CONDITIONS:                                                   |
//| - Z-Score returns to 0 (mean reversion complete)                  |
//| - Fixed Stop Loss for protection                                   |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: H1 or H4                                             |
//| - Pairs: Range-bound pairs (EURCHF, AUDNZD, EURGBP)              |
//|                                                                    |
//| RISK LEVEL: Medium                                                 |
//| WIN RATE: ~60-65% expected                                        |
//| RISK:REWARD: 1:1 to 1:1.5                                         |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      MeanPeriod = 50;          // Period for mean calculation
input double   ZScoreThreshold = 2.0;    // Z-Score entry threshold
input double   ZScoreExit = 0.5;         // Z-Score exit threshold
input double   LotSize = 0.1;
input int      StopLoss = 200;
input int      MagicNumber = 100016;

CLicenseValidator* g_license;
int g_ma_handle, g_stddev_handle;
double g_ma[], g_stddev[];

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "mean_reversion_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   g_ma_handle = iMA(_Symbol, PERIOD_CURRENT, MeanPeriod, 0, MODE_SMA, PRICE_CLOSE);
   g_stddev_handle = iStdDev(_Symbol, PERIOD_CURRENT, MeanPeriod, 0, MODE_SMA, PRICE_CLOSE);
   
   if(g_ma_handle == INVALID_HANDLE || g_stddev_handle == INVALID_HANDLE) return INIT_FAILED;
   
   ArraySetAsSeries(g_ma, true);
   ArraySetAsSeries(g_stddev, true);
   
   Print("Mean Reversion EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   if(g_ma_handle != INVALID_HANDLE) IndicatorRelease(g_ma_handle);
   if(g_stddev_handle != INVALID_HANDLE) IndicatorRelease(g_stddev_handle);
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   if(CopyBuffer(g_ma_handle, 0, 0, 2, g_ma) < 2) return;
   if(CopyBuffer(g_stddev_handle, 0, 0, 2, g_stddev) < 2) return;
   
   double close = iClose(_Symbol, PERIOD_CURRENT, 0);
   double zScore = (g_stddev[0] > 0) ? (close - g_ma[0]) / g_stddev[0] : 0;
   
   // Check for exit on existing positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            // Exit when Z-Score returns to near zero
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && zScore >= -ZScoreExit)
               ClosePosition(PositionGetTicket(i));
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && zScore <= ZScoreExit)
               ClosePosition(PositionGetTicket(i));
         }
      }
   }
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double zScore1 = (g_stddev[1] > 0) ? (close1 - g_ma[1]) / g_stddev[1] : 0;
   
   bool buySignal = zScore1 < -ZScoreThreshold;
   bool sellSignal = zScore1 > ZScoreThreshold;
   
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
   request.tp = g_ma[0];  // Target is the mean
   request.magic = MagicNumber;
   request.comment = "Mean Revert";
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
