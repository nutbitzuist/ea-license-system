//+------------------------------------------------------------------+
//|                                          31_Trade_Manager_EA.mq5  |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| UTILITY: Trade Manager                                             |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Comprehensive trade management tool that helps manage open        |
//| positions with advanced features like trailing stops, break-even, |
//| partial closes, and time-based exits.                             |
//|                                                                    |
//| FEATURES:                                                          |
//| - Auto trailing stop (ATR-based or fixed)                         |
//| - Break-even after X pips profit                                  |
//| - Partial close at profit targets                                 |
//| - Time-based trade closure                                        |
//| - Works with any manually opened trades                           |
//|                                                                    |
//| HOW TO USE:                                                        |
//| 1. Attach to any chart                                            |
//| 2. Open trades manually or with other EAs                         |
//| 3. This EA will manage all trades on the symbol                   |
//|                                                                    |
//| RECOMMENDED FOR:                                                   |
//| - Manual traders who want automated management                    |
//| - Combining with signal-only EAs                                  |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input bool     EnableTrailing = true;
input bool     UseATRTrailing = true;
input int      ATR_Period = 14;
input double   ATR_Multiplier = 2.0;
input int      FixedTrailingPips = 30;
input bool     EnableBreakEven = true;
input int      BreakEvenTriggerPips = 20;
input int      BreakEvenPlusPips = 5;
input bool     EnablePartialClose = true;
input int      PartialCloseTriggerPips = 50;
input double   PartialClosePercent = 50;
input bool     EnableTimeClose = false;
input int      MaxTradeHours = 24;
input int      MagicFilter = 0;          // 0 = manage all trades

CLicenseValidator* g_license;
int g_atr_handle;
double g_atr[];

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "trade_manager_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   ArraySetAsSeries(g_atr, true);
   
   Print("Trade Manager EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   if(CopyBuffer(g_atr_handle, 0, 0, 1, g_atr) < 1) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(MagicFilter > 0 && PositionGetInteger(POSITION_MAGIC) != MagicFilter) continue;
      
      ulong ticket = PositionGetTicket(i);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double volume = PositionGetDouble(POSITION_VOLUME);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      bool isBuy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double profitPips = isBuy ? (currentPrice - openPrice) / point : (openPrice - currentPrice) / point;
      
      // Time-based close
      if(EnableTimeClose && MaxTradeHours > 0)
      {
         if(TimeCurrent() - openTime >= MaxTradeHours * 3600)
         {
            ClosePosition(ticket);
            continue;
         }
      }
      
      // Partial close
      if(EnablePartialClose && profitPips >= PartialCloseTriggerPips && volume > 0.01)
      {
         double closeVolume = NormalizeDouble(volume * PartialClosePercent / 100, 2);
         if(closeVolume >= 0.01)
         {
            PartialClosePosition(ticket, closeVolume);
         }
      }
      
      // Break-even
      if(EnableBreakEven && profitPips >= BreakEvenTriggerPips)
      {
         double beLevel = isBuy ? openPrice + BreakEvenPlusPips * point : openPrice - BreakEvenPlusPips * point;
         if((isBuy && currentSL < beLevel) || (!isBuy && (currentSL > beLevel || currentSL == 0)))
         {
            ModifySL(ticket, beLevel);
         }
      }
      
      // Trailing stop
      if(EnableTrailing && profitPips > 0)
      {
         double trailDistance = UseATRTrailing ? g_atr[0] * ATR_Multiplier : FixedTrailingPips * point;
         double newSL = isBuy ? currentPrice - trailDistance : currentPrice + trailDistance;
         
         if(isBuy && newSL > currentSL && newSL > openPrice)
            ModifySL(ticket, newSL);
         else if(!isBuy && (currentSL == 0 || newSL < currentSL) && newSL < openPrice)
            ModifySL(ticket, newSL);
      }
   }
}

void ModifySL(ulong ticket, double newSL)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.sl = NormalizeDouble(newSL, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
   request.tp = PositionGetDouble(POSITION_TP);
   OrderSend(request, result);
}

void ClosePosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = _Symbol;
   request.volume = PositionGetDouble(POSITION_VOLUME);
   request.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = request.type == ORDER_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   request.deviation = 10;
   OrderSend(request, result);
}

void PartialClosePosition(ulong ticket, double volume)
{
   if(!PositionSelectByTicket(ticket)) return;
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = _Symbol;
   request.volume = volume;
   request.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = request.type == ORDER_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   request.deviation = 10;
   OrderSend(request, result);
}
//+------------------------------------------------------------------+
