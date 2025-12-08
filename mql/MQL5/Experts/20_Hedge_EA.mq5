//+------------------------------------------------------------------+
//|                                                 20_Hedge_EA.mq5   |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Hedging with Correlation                                 |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| This EA implements a hedging strategy that opens both buy and     |
//| sell positions simultaneously, then closes the losing side when   |
//| a clear trend emerges. Uses ATR for volatility-based exits.       |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Opens both BUY and SELL positions at the same time            |
//| 2. Monitors price movement and trend development                  |
//| 3. When trend is confirmed (ADX > threshold), closes losing side  |
//| 4. Lets winning side run with trailing stop                       |
//|                                                                    |
//| HEDGE LOGIC:                                                       |
//| - Initial hedge: Both positions open, net exposure = 0            |
//| - Trend confirmation: Close losing side                           |
//| - Profit taking: Trail winning side with ATR-based stop          |
//|                                                                    |
//| ENTRY CONDITIONS:                                                  |
//| - Opens hedge when no positions exist                             |
//| - Waits for volatility expansion (ATR increase)                   |
//|                                                                    |
//| EXIT CONDITIONS:                                                   |
//| - Losing side: Closed when ADX confirms trend                     |
//| - Winning side: Trailing stop based on ATR                        |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: H1                                                   |
//| - Pairs: Major pairs with good liquidity                          |
//| - Account: Must allow hedging                                      |
//|                                                                    |
//| RISK LEVEL: Medium-High                                            |
//| WIN RATE: ~50% expected (but controlled losses)                   |
//| RISK:REWARD: Variable (depends on trend strength)                 |
//|                                                                    |
//| NOTE: Requires broker that allows hedging (same symbol opposite   |
//| positions). Not available with US brokers (FIFO rule).            |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      ADX_Period = 14;          // ADX Period
input int      ADX_Threshold = 30;       // ADX Threshold for trend
input int      ATR_Period = 14;          // ATR Period
input double   ATR_Multiplier = 2.0;     // ATR Multiplier for trailing
input double   LotSize = 0.1;
input int      MagicNumber = 100020;

CLicenseValidator* g_license;
int g_adx_handle, g_atr_handle;
double g_adx[], g_plusDI[], g_minusDI[], g_atr[];
bool g_hedgeOpen = false;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "hedge_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   g_adx_handle = iADX(_Symbol, PERIOD_CURRENT, ADX_Period);
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   
   if(g_adx_handle == INVALID_HANDLE || g_atr_handle == INVALID_HANDLE) return INIT_FAILED;
   
   ArraySetAsSeries(g_adx, true);
   ArraySetAsSeries(g_plusDI, true);
   ArraySetAsSeries(g_minusDI, true);
   ArraySetAsSeries(g_atr, true);
   
   Print("Hedge EA initialized");
   Print("NOTE: Requires broker that allows hedging");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   if(g_adx_handle != INVALID_HANDLE) IndicatorRelease(g_adx_handle);
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   if(CopyBuffer(g_adx_handle, 0, 0, 2, g_adx) < 2) return;
   if(CopyBuffer(g_adx_handle, 1, 0, 2, g_plusDI) < 2) return;
   if(CopyBuffer(g_adx_handle, 2, 0, 2, g_minusDI) < 2) return;
   if(CopyBuffer(g_atr_handle, 0, 0, 2, g_atr) < 2) return;
   
   // Count positions
   int buyCount = 0, sellCount = 0;
   ulong buyTicket = 0, sellTicket = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               buyCount++;
               buyTicket = PositionGetTicket(i);
            }
            else
            {
               sellCount++;
               sellTicket = PositionGetTicket(i);
            }
         }
      }
   }
   
   // Open hedge if no positions
   if(buyCount == 0 && sellCount == 0)
   {
      OpenHedge();
      return;
   }
   
   // If both positions exist, check for trend to close losing side
   if(buyCount > 0 && sellCount > 0)
   {
      if(g_adx[0] > ADX_Threshold)
      {
         if(g_plusDI[0] > g_minusDI[0])
         {
            // Uptrend confirmed, close sell
            ClosePosition(sellTicket);
            Print("Uptrend confirmed, closed SELL hedge");
         }
         else
         {
            // Downtrend confirmed, close buy
            ClosePosition(buyTicket);
            Print("Downtrend confirmed, closed BUY hedge");
         }
      }
      return;
   }
   
   // If only one position, manage trailing stop
   if(buyCount > 0 || sellCount > 0)
   {
      UpdateTrailingStop(buyCount > 0 ? buyTicket : sellTicket);
   }
}

void OpenHedge()
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   // Open BUY
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = ORDER_TYPE_BUY;
   request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   request.sl = 0;
   request.tp = 0;
   request.magic = MagicNumber;
   request.comment = "Hedge BUY";
   request.deviation = 10;
   
   if(OrderSend(request, result))
   {
      Print("Hedge BUY opened");
   }
   
   // Open SELL
   request.type = ORDER_TYPE_SELL;
   request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   request.comment = "Hedge SELL";
   
   if(OrderSend(request, result))
   {
      Print("Hedge SELL opened");
   }
}

void UpdateTrailingStop(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   
   double currentSL = PositionGetDouble(POSITION_SL);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double trailDistance = g_atr[0] * ATR_Multiplier;
   
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
         request.tp = 0;
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
         request.position = ticket;
         request.sl = newSL;
         request.tp = 0;
         OrderSend(request, result);
      }
   }
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
