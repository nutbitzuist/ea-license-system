//+------------------------------------------------------------------+
//|                                    27_Labouchere_Martingale_EA.mq5|
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Labouchere (Cancellation) Martingale                    |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Uses a number sequence to determine lot sizes. After a win,       |
//| removes numbers from ends of sequence. After a loss, adds the     |
//| lost amount to the end. Goal is to cancel out all numbers.        |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Start with sequence: [1, 2, 3, 4]                              |
//| 2. Bet = first + last number (1+4 = 5 units)                      |
//| 3. Win: Remove first and last → [2, 3]                            |
//| 4. Loss: Add bet to end → [1, 2, 3, 4, 5]                         |
//| 5. When sequence empty, profit = sum of original sequence         |
//|                                                                    |
//| SEQUENCE EXAMPLE:                                                  |
//| Start: [1,2,3] → Bet 4 (1+3)                                      |
//| Loss: [1,2,3,4] → Bet 5 (1+4)                                     |
//| Win: [2,3] → Bet 5 (2+3)                                          |
//| Win: [] → Sequence complete! Profit = 1+2+3 = 6 units            |
//|                                                                    |
//| ADVANTAGES:                                                        |
//| - More controlled than classic martingale                         |
//| - Clear profit target                                              |
//| - Flexible sequence customization                                  |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: H1                                                   |
//| - Pairs: Major pairs                                              |
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
input double   UnitLot = 0.01;           // Lot per unit
input string   InitSequence = "1,2,3,4"; // Initial sequence
input int      TakeProfit = 100;
input int      StopLoss = 100;
input int      RSI_Period = 14;
input int      MagicNumber = 100027;

CLicenseValidator* g_license;
int g_sequence[];
int g_sequenceSize = 0;
int g_rsi_handle;
double g_rsi[];

void ParseSequence(string seq)
{
   string parts[];
   int count = StringSplit(seq, ',', parts);
   ArrayResize(g_sequence, count);
   g_sequenceSize = count;
   for(int i = 0; i < count; i++)
      g_sequence[i] = (int)StringToInteger(parts[i]);
}

void ResetSequence()
{
   ParseSequence(InitSequence);
   Print("Sequence reset: ", InitSequence);
}

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "labouchere_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   ResetSequence();
   g_rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   ArraySetAsSeries(g_rsi, true);
   
   Print("Labouchere Martingale EA initialized");
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
   
   // Check if sequence complete
   if(g_sequenceSize == 0)
   {
      Print("Labouchere sequence complete! Resetting...");
      ResetSequence();
   }
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(HasOpenPosition()) return;
   
   if(CopyBuffer(g_rsi_handle, 0, 0, 3, g_rsi) < 3) return;
   
   bool buySignal = g_rsi[1] > 30 && g_rsi[2] <= 30;
   bool sellSignal = g_rsi[1] < 70 && g_rsi[2] >= 70;
   
   if(buySignal) OpenPosition(ORDER_TYPE_BUY);
   else if(sellSignal) OpenPosition(ORDER_TYPE_SELL);
}

int GetCurrentBet()
{
   if(g_sequenceSize == 0) return 1;
   if(g_sequenceSize == 1) return g_sequence[0];
   return g_sequence[0] + g_sequence[g_sequenceSize - 1];
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
            int bet = GetCurrentBet();
            
            if(profit > 0)
            {
               // Win: Remove first and last
               if(g_sequenceSize >= 2)
               {
                  for(int j = 0; j < g_sequenceSize - 2; j++)
                     g_sequence[j] = g_sequence[j + 1];
                  g_sequenceSize -= 2;
               }
               else
               {
                  g_sequenceSize = 0;
               }
               Print("Win! Sequence size: ", g_sequenceSize);
            }
            else
            {
               // Loss: Add bet to end
               ArrayResize(g_sequence, g_sequenceSize + 1);
               g_sequence[g_sequenceSize] = bet;
               g_sequenceSize++;
               Print("Loss - Added ", bet, " to sequence. Size: ", g_sequenceSize);
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
   int bet = GetCurrentBet();
   double lot = NormalizeDouble(UnitLot * bet, 2);
   
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
   request.comment = "Labou " + IntegerToString(bet);
   request.deviation = 10;
   OrderSend(request, result);
}
//+------------------------------------------------------------------+
