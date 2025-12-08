//+------------------------------------------------------------------+
//|                                     25_Fibonacci_Martingale_EA.mq5|
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Fibonacci Martingale                                     |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Uses Fibonacci sequence for lot sizing instead of doubling.       |
//| Sequence: 1, 1, 2, 3, 5, 8, 13, 21...                             |
//| This provides a more gradual increase than classic martingale.    |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Start with base lot (e.g., 0.01)                               |
//| 2. After loss, next lot = current + previous (Fibonacci)          |
//| 3. After win, go back 2 steps in sequence                         |
//| 4. Uses stochastic for entry signals                              |
//|                                                                    |
//| FIBONACCI LOT PROGRESSION:                                         |
//| Trade 1: 0.01 (1x)                                                |
//| Trade 2: 0.01 (1x)                                                |
//| Trade 3: 0.02 (2x)                                                |
//| Trade 4: 0.03 (3x)                                                |
//| Trade 5: 0.05 (5x)                                                |
//| Trade 6: 0.08 (8x)                                                |
//|                                                                    |
//| ADVANTAGES:                                                        |
//| - Slower lot growth than 2x martingale                            |
//| - More sustainable progression                                     |
//| - Win recovery moves back in sequence                             |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: M30-H1                                               |
//| - Pairs: Any liquid pair                                          |
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
input double   BaseLot = 0.01;
input int      MaxFibLevel = 10;         // Max Fibonacci level
input int      TakeProfit = 100;
input int      StopLoss = 100;
input int      Stoch_K = 14;
input int      Stoch_D = 3;
input int      Stoch_Slowing = 3;
input int      MagicNumber = 100025;

CLicenseValidator* g_license;
int g_fibLevel = 0;
int g_stoch_handle;
double g_stochK[], g_stochD[];

// Fibonacci sequence
int GetFibonacci(int n)
{
   if(n <= 1) return 1;
   int a = 1, b = 1;
   for(int i = 2; i <= n; i++)
   {
      int temp = a + b;
      a = b;
      b = temp;
   }
   return b;
}

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "fibonacci_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   g_stoch_handle = iStochastic(_Symbol, PERIOD_CURRENT, Stoch_K, Stoch_D, Stoch_Slowing, MODE_SMA, STO_LOWHIGH);
   ArraySetAsSeries(g_stochK, true);
   ArraySetAsSeries(g_stochD, true);
   
   Print("Fibonacci Martingale EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   if(g_stoch_handle != INVALID_HANDLE) IndicatorRelease(g_stoch_handle);
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   CheckClosedTrades();
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(HasOpenPosition()) return;
   
   if(g_fibLevel >= MaxFibLevel)
   {
      Print("Max Fibonacci level reached. Resetting...");
      g_fibLevel = 0;
   }
   
   if(CopyBuffer(g_stoch_handle, 0, 0, 3, g_stochK) < 3) return;
   if(CopyBuffer(g_stoch_handle, 1, 0, 3, g_stochD) < 3) return;
   
   bool buySignal = g_stochK[1] > g_stochD[1] && g_stochK[2] <= g_stochD[2] && g_stochK[1] < 30;
   bool sellSignal = g_stochK[1] < g_stochD[1] && g_stochK[2] >= g_stochD[2] && g_stochK[1] > 70;
   
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
               g_fibLevel++;
               Print("Loss - Fibonacci level: ", g_fibLevel, " Next lot: ", BaseLot * GetFibonacci(g_fibLevel));
            }
            else
            {
               g_fibLevel = MathMax(0, g_fibLevel - 2);  // Go back 2 levels on win
               Print("Win! Fibonacci level: ", g_fibLevel);
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
   double lot = BaseLot * GetFibonacci(g_fibLevel);
   lot = NormalizeDouble(lot, 2);
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lot;
   request.type = orderType;
   request.price = price;
   request.sl = (orderType == ORDER_TYPE_BUY) ? price - StopLoss * point : price + StopLoss * point;
   request.tp = (orderType == ORDER_TYPE_BUY) ? price + TakeProfit * point : price - TakeProfit * point;
   request.magic = MagicNumber;
   request.comment = "Fib L" + IntegerToString(g_fibLevel);
   request.deviation = 10;
   OrderSend(request, result);
}
//+------------------------------------------------------------------+
