//+------------------------------------------------------------------+
//|                                   29_Oscar_Grind_Martingale_EA.mq5|
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Oscar's Grind Martingale                                 |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| A conservative progression system that aims for 1 unit profit     |
//| per cycle. Increases bet by 1 unit after a win, keeps same bet    |
//| after a loss. Resets when 1 unit profit is achieved.              |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Start with 1 unit bet                                          |
//| 2. After loss: Keep same bet                                      |
//| 3. After win: Increase bet by 1 unit                              |
//| 4. Goal: Achieve +1 unit profit, then reset                       |
//| 5. Never bet more than needed to reach +1 profit                  |
//|                                                                    |
//| OSCAR'S GRIND EXAMPLE:                                             |
//| Bet 1: Lose (-1)                                                   |
//| Bet 1: Lose (-2)                                                   |
//| Bet 1: Win (-1)                                                    |
//| Bet 2: Lose (-3)                                                   |
//| Bet 2: Win (-1)                                                    |
//| Bet 2: Win (+1) → Reset!                                          |
//|                                                                    |
//| ADVANTAGES:                                                        |
//| - Very conservative progression                                    |
//| - Clear profit target per cycle                                   |
//| - Lower variance than other systems                               |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: H1-H4                                                |
//| - Pairs: Any                                                      |
//| - Account: Minimum $2,000 recommended                             |
//|                                                                    |
//| RISK LEVEL: MEDIUM                                                 |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   UnitLot = 0.01;           // 1 unit = this lot size
input int      MaxUnits = 10;            // Maximum units per bet
input int      TakeProfit = 100;
input int      StopLoss = 100;
input int      MACD_Fast = 12;
input int      MACD_Slow = 26;
input int      MACD_Signal = 9;
input int      MagicNumber = 100029;

CLicenseValidator* g_license;
int g_currentUnits = 1;
double g_cycleProfit = 0;
int g_macd_handle;
double g_macdMain[], g_macdSignal[];

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "oscar_grind_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   g_macd_handle = iMACD(_Symbol, PERIOD_CURRENT, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
   ArraySetAsSeries(g_macdMain, true);
   ArraySetAsSeries(g_macdSignal, true);
   
   Print("Oscar's Grind Martingale EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   if(g_macd_handle != INVALID_HANDLE) IndicatorRelease(g_macd_handle);
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   CheckClosedTrades();
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(HasOpenPosition()) return;
   
   if(CopyBuffer(g_macd_handle, 0, 0, 3, g_macdMain) < 3) return;
   if(CopyBuffer(g_macd_handle, 1, 0, 3, g_macdSignal) < 3) return;
   
   double hist1 = g_macdMain[1] - g_macdSignal[1];
   double hist2 = g_macdMain[2] - g_macdSignal[2];
   
   bool buySignal = hist1 > 0 && hist2 <= 0;
   bool sellSignal = hist1 < 0 && hist2 >= 0;
   
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
            double pipValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
            double unitValue = UnitLot * TakeProfit * pipValue;
            
            if(profit > 0)
            {
               g_cycleProfit += profit;
               
               // Check if cycle complete (1 unit profit)
               if(g_cycleProfit >= unitValue)
               {
                  Print("Oscar's Grind cycle complete! Profit: $", g_cycleProfit);
                  g_currentUnits = 1;
                  g_cycleProfit = 0;
               }
               else
               {
                  // Increase by 1 unit, but don't exceed what's needed
                  double needed = unitValue - g_cycleProfit;
                  int maxNeeded = (int)MathCeil(needed / (UnitLot * TakeProfit * pipValue));
                  g_currentUnits = MathMin(g_currentUnits + 1, MathMin(maxNeeded, MaxUnits));
                  Print("Win - Units: ", g_currentUnits, " Cycle profit: $", g_cycleProfit);
               }
            }
            else
            {
               g_cycleProfit += profit;  // profit is negative
               // Keep same bet after loss
               Print("Loss - Units: ", g_currentUnits, " Cycle profit: $", g_cycleProfit);
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
   double lot = NormalizeDouble(UnitLot * g_currentUnits, 2);
   
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
   request.comment = "Oscar " + IntegerToString(g_currentUnits) + "u";
   request.deviation = 10;
   OrderSend(request, result);
}
//+------------------------------------------------------------------+
