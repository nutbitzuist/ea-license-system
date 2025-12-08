//+------------------------------------------------------------------+
//|                                        22_Anti_Martingale_EA.mq5  |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Anti-Martingale (Reverse Martingale)                    |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| The opposite of classic martingale - increases lot size after     |
//| winning trades and resets after losing trades. Capitalizes on     |
//| winning streaks while limiting losses.                             |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Opens initial trade based on RSI signals                       |
//| 2. If trade wins, next trade is multiplied lot size               |
//| 3. If trade loses, reset to initial lot size                      |
//| 4. Takes profit during winning streaks                            |
//|                                                                    |
//| ADVANTAGES OVER CLASSIC MARTINGALE:                                |
//| - Limited downside risk                                           |
//| - Profits compound during winning streaks                         |
//| - More sustainable long-term                                       |
//|                                                                    |
//| RISK MANAGEMENT:                                                   |
//| - Maximum lot size limit                                          |
//| - Profit target to lock in gains                                  |
//| - Maximum winning streak limit                                     |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: H1-H4                                                |
//| - Pairs: Trending pairs                                           |
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
input double   LotMultiplier = 1.5;      // Lot Multiplier after win
input double   MaxLot = 0.5;
input int      MaxWinStreak = 5;         // Max consecutive wins before reset
input int      TakeProfit = 150;
input int      StopLoss = 100;
input int      RSI_Period = 14;
input int      MagicNumber = 100022;

CLicenseValidator* g_license;
double g_currentLot;
int g_consecutiveWins = 0;
int g_rsi_handle;
double g_rsi[];

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "anti_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   g_currentLot = InitialLot;
   g_rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   ArraySetAsSeries(g_rsi, true);
   
   Print("Anti-Martingale EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   if(g_rsi_handle != INVALID_HANDLE) IndicatorRelease(g_rsi_handle);
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   CheckClosedTrades();
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(HasOpenPosition()) return;
   
   // Reset if max win streak reached
   if(g_consecutiveWins >= MaxWinStreak)
   {
      Print("Max win streak reached! Locking profits and resetting.");
      g_consecutiveWins = 0;
      g_currentLot = InitialLot;
   }
   
   if(CopyBuffer(g_rsi_handle, 0, 0, 3, g_rsi) < 3) return;
   
   bool buySignal = g_rsi[1] > 30 && g_rsi[2] <= 30;
   bool sellSignal = g_rsi[1] < 70 && g_rsi[2] >= 70;
   
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
               g_currentLot = MathMin(g_currentLot * LotMultiplier, MaxLot);
               Print("Win #", g_consecutiveWins, " - Next lot: ", g_currentLot);
            }
            else
            {
               Print("Loss - Resetting to initial lot");
               g_consecutiveWins = 0;
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
   request.comment = "AntiMart #" + IntegerToString(g_consecutiveWins + 1);
   request.deviation = 10;
   OrderSend(request, result);
}
//+------------------------------------------------------------------+
