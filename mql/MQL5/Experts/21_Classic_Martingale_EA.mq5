//+------------------------------------------------------------------+
//|                                      21_Classic_Martingale_EA.mq5 |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Classic Martingale                                       |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| The classic martingale strategy doubles the lot size after each   |
//| losing trade. When a winning trade occurs, it resets to the       |
//| initial lot size. Simple but effective in ranging markets.        |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Opens initial trade based on simple MA crossover               |
//| 2. If trade loses, next trade is 2x the lot size                  |
//| 3. If trade wins, reset to initial lot size                       |
//| 4. Continues until max lot size or max trades reached             |
//|                                                                    |
//| RISK MANAGEMENT:                                                   |
//| - Maximum lot size limit                                          |
//| - Maximum consecutive trades limit                                 |
//| - Daily loss limit                                                 |
//|                                                                    |
//| WARNING: HIGH RISK STRATEGY                                        |
//| - Can lead to significant drawdowns                               |
//| - Requires large account balance                                   |
//| - Not suitable for trending markets                               |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: M15-H1                                               |
//| - Pairs: Range-bound pairs (EURCHF, AUDNZD)                       |
//| - Account: Minimum $10,000 recommended                            |
//|                                                                    |
//| RISK LEVEL: VERY HIGH                                              |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   InitialLot = 0.01;        // Initial Lot Size
input double   LotMultiplier = 2.0;      // Lot Multiplier after loss
input double   MaxLot = 1.0;             // Maximum Lot Size
input int      MaxTrades = 8;            // Maximum Consecutive Trades
input int      TakeProfit = 100;         // Take Profit (points)
input int      StopLoss = 100;           // Stop Loss (points)
input int      MA_Fast = 10;             // Fast MA Period
input int      MA_Slow = 20;             // Slow MA Period
input double   DailyLossLimit = 500;     // Daily Loss Limit ($)
input int      MagicNumber = 100021;

CLicenseValidator* g_license;
double g_currentLot;
int g_consecutiveLosses = 0;
double g_dailyLoss = 0;
datetime g_lastDay = 0;
int g_maFast_handle, g_maSlow_handle;
double g_maFast[], g_maSlow[];

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "classic_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   g_currentLot = InitialLot;
   g_maFast_handle = iMA(_Symbol, PERIOD_CURRENT, MA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   g_maSlow_handle = iMA(_Symbol, PERIOD_CURRENT, MA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   
   ArraySetAsSeries(g_maFast, true);
   ArraySetAsSeries(g_maSlow, true);
   
   Print("Classic Martingale EA initialized - WARNING: HIGH RISK!");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   if(g_maFast_handle != INVALID_HANDLE) IndicatorRelease(g_maFast_handle);
   if(g_maSlow_handle != INVALID_HANDLE) IndicatorRelease(g_maSlow_handle);
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   // Reset daily loss counter
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(today != g_lastDay)
   {
      g_dailyLoss = 0;
      g_lastDay = today;
   }
   
   // Check daily loss limit
   if(g_dailyLoss >= DailyLossLimit)
   {
      return; // Stop trading for the day
   }
   
   // Check for closed trades to update martingale
   CheckClosedTrades();
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   // Check if we have open positions
   if(HasOpenPosition()) return;
   
   // Check max trades
   if(g_consecutiveLosses >= MaxTrades)
   {
      Print("Max consecutive trades reached. Resetting...");
      g_consecutiveLosses = 0;
      g_currentLot = InitialLot;
      return;
   }
   
   if(CopyBuffer(g_maFast_handle, 0, 0, 3, g_maFast) < 3) return;
   if(CopyBuffer(g_maSlow_handle, 0, 0, 3, g_maSlow) < 3) return;
   
   bool buySignal = g_maFast[1] > g_maSlow[1] && g_maFast[2] <= g_maSlow[2];
   bool sellSignal = g_maFast[1] < g_maSlow[1] && g_maFast[2] >= g_maSlow[2];
   
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
            
            if(profit < 0)
            {
               g_consecutiveLosses++;
               g_dailyLoss += MathAbs(profit);
               g_currentLot = MathMin(g_currentLot * LotMultiplier, MaxLot);
               Print("Loss #", g_consecutiveLosses, " - Next lot: ", g_currentLot);
            }
            else
            {
               Print("Win! Profit: ", profit, " - Resetting to initial lot");
               g_consecutiveLosses = 0;
               g_currentLot = InitialLot;
            }
         }
      }
   }
   lastDealsTotal = dealsTotal;
}

bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
            return true;
   }
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
   request.volume = NormalizeDouble(g_currentLot, 2);
   request.type = orderType;
   request.price = price;
   request.sl = (orderType == ORDER_TYPE_BUY) ? price - StopLoss * point : price + StopLoss * point;
   request.tp = (orderType == ORDER_TYPE_BUY) ? price + TakeProfit * point : price - TakeProfit * point;
   request.magic = MagicNumber;
   request.comment = "Martingale #" + IntegerToString(g_consecutiveLosses + 1);
   request.deviation = 10;
   
   if(OrderSend(request, result))
      Print("Opened ", (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"), " Lot: ", g_currentLot);
}
//+------------------------------------------------------------------+
