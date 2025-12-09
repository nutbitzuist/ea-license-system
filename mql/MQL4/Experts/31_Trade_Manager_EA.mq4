//+------------------------------------------------------------------+
//|                                          31_Trade_Manager_EA.mq4  |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| UTILITY: Trade Manager - Trailing, Break-even, Partial Close     |
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
input int      MagicFilter = 0;

CLicenseValidator* g_license;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "trade_manager_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   Print("Trade Manager EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   double atr = iATR(Symbol(), Period(), ATR_Period, 0);
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(MagicFilter > 0 && OrderMagicNumber() != MagicFilter) continue;
      
      double openPrice = OrderOpenPrice();
      double currentSL = OrderStopLoss();
      double lots = OrderLots();
      bool isBuy = OrderType() == OP_BUY;
      double currentPrice = isBuy ? Bid : Ask;
      double profitPips = isBuy ? (currentPrice - openPrice) / Point : (openPrice - currentPrice) / Point;
      
      // Partial close
      if(EnablePartialClose && profitPips >= PartialCloseTriggerPips && lots > 0.02)
      {
         double closeLots = NormalizeDouble(lots * PartialClosePercent / 100, 2);
         if(closeLots >= 0.01)
            OrderClose(OrderTicket(), closeLots, currentPrice, 10, clrNONE);
      }
      
      // Break-even
      if(EnableBreakEven && profitPips >= BreakEvenTriggerPips)
      {
         double beLevel = isBuy ? openPrice + BreakEvenPlusPips * Point : openPrice - BreakEvenPlusPips * Point;
         if((isBuy && currentSL < beLevel) || (!isBuy && (currentSL > beLevel || currentSL == 0)))
            OrderModify(OrderTicket(), openPrice, beLevel, OrderTakeProfit(), 0, clrNONE);
      }
      
      // Trailing stop
      if(EnableTrailing && profitPips > 0)
      {
         double trailDistance = UseATRTrailing ? atr * ATR_Multiplier : FixedTrailingPips * Point;
         double newSL = isBuy ? currentPrice - trailDistance : currentPrice + trailDistance;
         
         if(isBuy && newSL > currentSL && newSL > openPrice)
            OrderModify(OrderTicket(), openPrice, newSL, OrderTakeProfit(), 0, clrNONE);
         else if(!isBuy && (currentSL == 0 || newSL < currentSL) && newSL < openPrice)
            OrderModify(OrderTicket(), openPrice, newSL, OrderTakeProfit(), 0, clrNONE);
      }
   }
}
//+------------------------------------------------------------------+
