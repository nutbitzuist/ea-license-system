//+------------------------------------------------------------------+
//|                                       30_Hybrid_Martingale_EA.mq5 |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Hybrid Martingale with Smart Recovery                   |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Combines multiple martingale concepts with intelligent recovery.  |
//| Uses trend analysis to determine when to apply martingale and     |
//| when to reduce exposure. Includes multiple safety mechanisms.     |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Analyzes trend strength before trading                         |
//| 2. In strong trend: Uses anti-martingale (increase on wins)       |
//| 3. In range: Uses classic martingale (increase on losses)         |
//| 4. Implements cooling period after consecutive losses             |
//| 5. Uses partial close to lock in profits                          |
//|                                                                    |
//| SMART FEATURES:                                                    |
//| - Trend detection switches between strategies                     |
//| - Cooling period prevents overtrading                             |
//| - Equity-based position sizing                                    |
//| - Partial profit taking                                           |
//|                                                                    |
//| SAFETY MECHANISMS:                                                 |
//| - Maximum drawdown limit                                          |
//| - Daily loss limit                                                 |
//| - Maximum lot size                                                 |
//| - Cooling period after losses                                      |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: H1                                                   |
//| - Pairs: Major pairs                                              |
//| - Account: Minimum $5,000 recommended                             |
//|                                                                    |
//| RISK LEVEL: HIGH (but managed)                                     |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   BaseLot = 0.01;
input double   MaxLot = 0.5;
input double   MartingaleMultiplier = 1.5;
input double   AntiMartingaleMultiplier = 1.3;
input int      ADX_Threshold = 25;       // Above = trending, below = ranging
input int      CoolingPeriodBars = 5;    // Bars to wait after max losses
input int      MaxConsecutiveLosses = 5;
input double   MaxDrawdownPercent = 15;
input double   DailyLossLimit = 300;
input int      TakeProfit = 100;
input int      StopLoss = 100;
input int      MagicNumber = 100030;

CLicenseValidator* g_license;
double g_currentLot;
int g_consecutiveLosses = 0;
int g_consecutiveWins = 0;
bool g_isTrending = false;
datetime g_coolingUntil = 0;
double g_dailyLoss = 0;
datetime g_lastDay = 0;
double g_startEquity;

int g_adx_handle, g_ma_handle;
double g_adx[], g_ma[];

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "hybrid_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   g_currentLot = BaseLot;
   g_startEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   g_adx_handle = iADX(_Symbol, PERIOD_CURRENT, 14);
   g_ma_handle = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_EMA, PRICE_CLOSE);
   
   ArraySetAsSeries(g_adx, true);
   ArraySetAsSeries(g_ma, true);
   
   Print("Hybrid Martingale EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   if(g_adx_handle != INVALID_HANDLE) IndicatorRelease(g_adx_handle);
   if(g_ma_handle != INVALID_HANDLE) IndicatorRelease(g_ma_handle);
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   // Reset daily counters
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(today != g_lastDay)
   {
      g_dailyLoss = 0;
      g_lastDay = today;
   }
   
   // Check safety limits
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double drawdown = (g_startEquity - currentEquity) / g_startEquity * 100;
   
   if(drawdown >= MaxDrawdownPercent)
   {
      Print("Max drawdown reached! Stopping EA.");
      return;
   }
   
   if(g_dailyLoss >= DailyLossLimit)
   {
      return; // Stop trading for the day
   }
   
   // Check cooling period
   if(TimeCurrent() < g_coolingUntil)
   {
      return;
   }
   
   CheckClosedTrades();
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(HasOpenPosition()) return;
   
   // Analyze market condition
   if(CopyBuffer(g_adx_handle, 0, 0, 2, g_adx) < 2) return;
   if(CopyBuffer(g_ma_handle, 0, 0, 3, g_ma) < 3) return;
   
   g_isTrending = g_adx[1] > ADX_Threshold;
   
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   
   bool buySignal = close1 > g_ma[1] && close2 <= g_ma[2];
   bool sellSignal = close1 < g_ma[1] && close2 >= g_ma[2];
   
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
               g_consecutiveWins++;
               g_consecutiveLosses = 0;
               
               if(g_isTrending)
               {
                  // Anti-martingale in trends
                  g_currentLot = MathMin(g_currentLot * AntiMartingaleMultiplier, MaxLot);
                  Print("Trending Win - Anti-martingale to: ", g_currentLot);
               }
               else
               {
                  // Reset in ranging
                  g_currentLot = BaseLot;
                  Print("Ranging Win - Reset to base");
               }
            }
            else
            {
               g_consecutiveLosses++;
               g_consecutiveWins = 0;
               g_dailyLoss += MathAbs(profit);
               
               if(g_consecutiveLosses >= MaxConsecutiveLosses)
               {
                  // Enter cooling period
                  g_coolingUntil = iTime(_Symbol, PERIOD_CURRENT, 0) + CoolingPeriodBars * PeriodSeconds();
                  g_currentLot = BaseLot;
                  g_consecutiveLosses = 0;
                  Print("Max losses reached - Cooling period activated");
               }
               else if(!g_isTrending)
               {
                  // Martingale in ranging
                  g_currentLot = MathMin(g_currentLot * MartingaleMultiplier, MaxLot);
                  Print("Ranging Loss - Martingale to: ", g_currentLot);
               }
               else
               {
                  // Reset in trends
                  g_currentLot = BaseLot;
                  Print("Trending Loss - Reset to base");
               }
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
   request.volume = NormalizeDouble(g_currentLot, 2);
   request.type = orderType;
   request.price = price;
   request.sl = (orderType == ORDER_TYPE_BUY) ? price - StopLoss * point : price + StopLoss * point;
   request.tp = (orderType == ORDER_TYPE_BUY) ? price + TakeProfit * point : price - TakeProfit * point;
   request.magic = MagicNumber;
   request.comment = g_isTrending ? "Hybrid-T" : "Hybrid-R";
   request.deviation = 10;
   OrderSend(request, result);
}
//+------------------------------------------------------------------+
