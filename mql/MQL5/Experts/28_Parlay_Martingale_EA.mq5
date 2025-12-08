//+------------------------------------------------------------------+
//|                                       28_Parlay_Martingale_EA.mq5 |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Parlay (Let It Ride) Martingale                         |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Reinvests profits from winning trades into the next trade.        |
//| After a win, the next trade uses original lot + profit.           |
//| After a loss, resets to base lot. Aggressive profit compounding.  |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Start with base lot                                            |
//| 2. Win: Next lot = base + (profit / pip value)                    |
//| 3. Loss: Reset to base lot                                        |
//| 4. Optional: Take profit after X consecutive wins                 |
//|                                                                    |
//| PARLAY PROGRESSION EXAMPLE:                                        |
//| Trade 1: 0.01 lot → Win $10                                       |
//| Trade 2: 0.02 lot (reinvest) → Win $20                            |
//| Trade 3: 0.04 lot (reinvest) → Win $40                            |
//| Trade 4: 0.08 lot (reinvest) → Loss → Reset                       |
//|                                                                    |
//| ADVANTAGES:                                                        |
//| - Profits compound quickly                                        |
//| - Limited risk (only lose base lot)                               |
//| - Great for winning streaks                                        |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: H1-H4                                                |
//| - Pairs: Trending pairs                                           |
//| - Account: Minimum $2,000 recommended                             |
//|                                                                    |
//| RISK LEVEL: HIGH                                                   |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   BaseLot = 0.01;
input int      MaxParlays = 4;           // Max consecutive parlays
input int      TakeProfit = 100;
input int      StopLoss = 100;
input int      ADX_Period = 14;
input int      ADX_Threshold = 25;
input int      MagicNumber = 100028;

CLicenseValidator* g_license;
double g_currentLot;
double g_accumulatedProfit = 0;
int g_parlayCount = 0;
int g_adx_handle;
double g_adx[], g_plusDI[], g_minusDI[];

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "parlay_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   g_currentLot = BaseLot;
   g_adx_handle = iADX(_Symbol, PERIOD_CURRENT, ADX_Period);
   ArraySetAsSeries(g_adx, true);
   ArraySetAsSeries(g_plusDI, true);
   ArraySetAsSeries(g_minusDI, true);
   
   Print("Parlay Martingale EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   if(g_adx_handle != INVALID_HANDLE) IndicatorRelease(g_adx_handle);
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   CheckClosedTrades();
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(HasOpenPosition()) return;
   
   // Check max parlays
   if(g_parlayCount >= MaxParlays)
   {
      Print("Max parlays reached! Taking profit and resetting.");
      g_parlayCount = 0;
      g_currentLot = BaseLot;
      g_accumulatedProfit = 0;
   }
   
   if(CopyBuffer(g_adx_handle, 0, 0, 2, g_adx) < 2) return;
   if(CopyBuffer(g_adx_handle, 1, 0, 2, g_plusDI) < 2) return;
   if(CopyBuffer(g_adx_handle, 2, 0, 2, g_minusDI) < 2) return;
   
   if(g_adx[1] < ADX_Threshold) return;  // Only trade in strong trends
   
   bool buySignal = g_plusDI[1] > g_minusDI[1];
   bool sellSignal = g_minusDI[1] > g_plusDI[1];
   
   if(buySignal) OpenPosition(ORDER_TYPE_BUY);
   else if(sellSignal) OpenPosition(ORDER_TYPE_SELL);
}

void CheckClosedTrades()
{
   static int lastDealsTotal = 0;
   HistorySelect(0, TimeCurrent());
   int dealsTotal = HistoryDealsTotal();
   
   if(dealsTotal > lastDealsTotal)
   {
      for(int i = lastDealsTotal; i < dealsTotal; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber &&
            HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            
            if(profit > 0)
            {
               g_accumulatedProfit += profit;
               g_parlayCount++;
               
               // Calculate new lot based on accumulated profit
               double pipValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
               double additionalLots = (g_accumulatedProfit / (TakeProfit * pipValue));
               g_currentLot = NormalizeDouble(BaseLot + additionalLots * 0.01, 2);
               
               Print("Win! Parlay #", g_parlayCount, " - Accumulated: $", g_accumulatedProfit, " Next lot: ", g_currentLot);
            }
            else
            {
               Print("Loss - Resetting parlay");
               g_parlayCount = 0;
               g_currentLot = BaseLot;
               g_accumulatedProfit = 0;
            }
         }
      }
   }
   lastDealsTotal = dealsTotal;
}

bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionSelectByTicket(PositionGetTicket(i)))
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
            return true;
   return false;
}

void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = g_currentLot;
   request.type = orderType;
   request.price = price;
   request.sl = (orderType == ORDER_TYPE_BUY) ? price - StopLoss * point : price + StopLoss * point;
   request.tp = (orderType == ORDER_TYPE_BUY) ? price + TakeProfit * point : price - TakeProfit * point;
   request.magic = MagicNumber;
   request.comment = "Parlay #" + IntegerToString(g_parlayCount + 1);
   request.deviation = 10;
   OrderSend(request, result);
}
//+------------------------------------------------------------------+
