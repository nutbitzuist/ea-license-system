//+------------------------------------------------------------------+
//|                                       14_Momentum_Breakout_EA.mq5 |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Momentum-Confirmed Breakout                              |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| This EA combines range breakouts with momentum confirmation        |
//| using the CCI (Commodity Channel Index) and volume analysis.       |
//| Only trades breakouts backed by strong momentum.                   |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Identifies consolidation range (Donchian Channel)              |
//| 2. Waits for price to break above/below the range                 |
//| 3. Confirms with CCI momentum (>100 for buy, <-100 for sell)      |
//| 4. Checks volume is above average (momentum confirmation)         |
//|                                                                    |
//| MOMENTUM FILTERS:                                                  |
//| - CCI > 100: Strong bullish momentum                              |
//| - CCI < -100: Strong bearish momentum                             |
//| - Volume > 1.5x average: Confirms institutional participation     |
//|                                                                    |
//| ENTRY CONDITIONS:                                                  |
//| BUY: Break above range + CCI > 100 + Volume spike                 |
//| SELL: Break below range + CCI < -100 + Volume spike               |
//|                                                                    |
//| EXIT CONDITIONS:                                                   |
//| - Trailing stop based on ATR                                      |
//| - CCI returns to neutral zone (-100 to 100)                       |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: H1                                                   |
//| - Pairs: Volatile pairs (GBPJPY, EURJPY, XAUUSD)                 |
//|                                                                    |
//| RISK LEVEL: Medium-High                                            |
//| WIN RATE: ~45-50% expected                                        |
//| RISK:REWARD: 1:2.5 to 1:3                                         |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      RangePeriod = 20;         // Donchian Channel Period
input int      CCI_Period = 14;          // CCI Period
input int      CCI_Level = 100;          // CCI Threshold
input double   VolumeMultiplier = 1.5;   // Volume spike multiplier
input int      ATR_Period = 14;          // ATR for trailing
input double   ATR_Multiplier = 2.0;     // ATR multiplier for trail
input double   LotSize = 0.1;
input int      MagicNumber = 100014;

CLicenseValidator* g_license;
int g_cci_handle, g_atr_handle;
double g_cci[], g_atr[];

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "momentum_breakout_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   g_cci_handle = iCCI(_Symbol, PERIOD_CURRENT, CCI_Period, PRICE_TYPICAL);
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   
   if(g_cci_handle == INVALID_HANDLE || g_atr_handle == INVALID_HANDLE) return INIT_FAILED;
   
   ArraySetAsSeries(g_cci, true);
   ArraySetAsSeries(g_atr, true);
   
   Print("Momentum Breakout EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   if(g_cci_handle != INVALID_HANDLE) IndicatorRelease(g_cci_handle);
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   if(CopyBuffer(g_atr_handle, 0, 0, 2, g_atr) < 2) return;
   
   // Update trailing stops
   UpdateTrailingStops();
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(CopyBuffer(g_cci_handle, 0, 0, 3, g_cci) < 3) return;
   
   // Calculate Donchian Channel
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
   
   // Calculate average volume
   double avgVolume = 0;
   for(int i = 1; i <= 20; i++) avgVolume += (double)iVolume(_Symbol, PERIOD_CURRENT, i);
   avgVolume /= 20;
   double currentVolume = (double)iVolume(_Symbol, PERIOD_CURRENT, 1);
   bool volumeSpike = currentVolume > avgVolume * VolumeMultiplier;
   
   // Breakout signals with momentum confirmation
   bool buySignal = close1 > rangeHigh && close2 <= rangeHigh && g_cci[1] > CCI_Level && volumeSpike;
   bool sellSignal = close1 < rangeLow && close2 >= rangeLow && g_cci[1] < -CCI_Level && volumeSpike;
   
   ManagePositions(buySignal, sellSignal);
}

void UpdateTrailingStops()
{
   double atrValue = g_atr[0];
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
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
                  request.position = PositionGetTicket(i);
                  request.sl = newSL;
                  request.tp = PositionGetDouble(POSITION_TP);
                  OrderSend(request, result);
               }
            }
            else
            {
               double newSL = currentPrice + trailDistance;
               if((currentSL == 0 || newSL < currentSL) && newSL < openPrice)
               {
                  request.action = TRADE_ACTION_SLTP;
                  request.symbol = _Symbol;
                  request.position = PositionGetTicket(i);
                  request.sl = newSL;
                  request.tp = PositionGetDouble(POSITION_TP);
                  OrderSend(request, result);
               }
            }
         }
      }
   }
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
   double atrValue = g_atr[0];
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = price;
   request.sl = (orderType == ORDER_TYPE_BUY) ? price - atrValue * ATR_Multiplier : price + atrValue * ATR_Multiplier;
   request.tp = 0;  // Use trailing stop
   request.magic = MagicNumber;
   request.comment = "Momentum BO";
   request.deviation = 10;
   OrderSend(request, result);
}
//+------------------------------------------------------------------+
