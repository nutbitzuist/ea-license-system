//+------------------------------------------------------------------+
//|                                       23_Smooth_Martingale_EA.mq5 |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Smooth Martingale (Gradual Increase)                    |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| A gentler version of martingale that uses a smaller multiplier    |
//| (1.3-1.5x instead of 2x). This reduces the exponential growth     |
//| of lot sizes while still recovering from losses.                   |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Uses Bollinger Bands for entry signals                         |
//| 2. After loss, increases lot by 1.3x (configurable)               |
//| 3. Slower progression = more trades before max lot                |
//| 4. Better for accounts with moderate capital                       |
//|                                                                    |
//| COMPARISON TO CLASSIC:                                             |
//| Classic (2x): 0.01 → 0.02 → 0.04 → 0.08 → 0.16 → 0.32            |
//| Smooth (1.3x): 0.01 → 0.013 → 0.017 → 0.022 → 0.029 → 0.037      |
//|                                                                    |
//| RISK MANAGEMENT:                                                   |
//| - Gradual lot increase                                            |
//| - More trades before reaching max lot                             |
//| - Equity-based stop                                                |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: M30-H1                                               |
//| - Pairs: Range-bound pairs                                        |
//| - Account: Minimum $5,000 recommended                             |
//|                                                                    |
//| RISK LEVEL: HIGH                                                   |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   InitialLot = 0.01;
input double   LotMultiplier = 1.3;      // Smooth multiplier
input double   MaxLot = 0.5;
input int      MaxTrades = 15;           // More trades allowed
input int      TakeProfit = 80;
input int      StopLoss = 80;
input int      BB_Period = 20;
input double   BB_Deviation = 2.0;
input double   EquityStopPercent = 20;   // Stop if equity drops 20%
input int      MagicNumber = 100023;

CLicenseValidator* g_license;
double g_currentLot;
int g_consecutiveLosses = 0;
double g_startEquity;
int g_bb_handle;
double g_bbUpper[], g_bbLower[], g_bbMiddle[];

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "smooth_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   g_currentLot = InitialLot;
   g_startEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_bb_handle = iBands(_Symbol, PERIOD_CURRENT, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
   
   ArraySetAsSeries(g_bbUpper, true);
   ArraySetAsSeries(g_bbLower, true);
   ArraySetAsSeries(g_bbMiddle, true);
   
   Print("Smooth Martingale EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   if(g_bb_handle != INVALID_HANDLE) IndicatorRelease(g_bb_handle);
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   // Equity stop check
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(currentEquity < g_startEquity * (1 - EquityStopPercent / 100))
   {
      Print("Equity stop triggered! Stopping EA.");
      ExpertRemove();
      return;
   }
   
   CheckClosedTrades();
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(HasOpenPosition()) return;
   
   if(g_consecutiveLosses >= MaxTrades)
   {
      g_consecutiveLosses = 0;
      g_currentLot = InitialLot;
      return;
   }
   
   if(CopyBuffer(g_bb_handle, 1, 0, 2, g_bbUpper) < 2) return;
   if(CopyBuffer(g_bb_handle, 2, 0, 2, g_bbLower) < 2) return;
   
   double close = iClose(_Symbol, PERIOD_CURRENT, 1);
   
   bool buySignal = close < g_bbLower[1];
   bool sellSignal = close > g_bbUpper[1];
   
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
               g_currentLot = MathMin(g_currentLot * LotMultiplier, MaxLot);
            }
            else
            {
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
   request.comment = "Smooth #" + IntegerToString(g_consecutiveLosses + 1);
   request.deviation = 10;
   OrderSend(request, result);
}
//+------------------------------------------------------------------+
