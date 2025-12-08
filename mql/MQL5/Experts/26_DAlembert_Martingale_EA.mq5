//+------------------------------------------------------------------+
//|                                     26_DAlembert_Martingale_EA.mq5|
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: D'Alembert Martingale                                    |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Based on the D'Alembert betting system. Increases lot by fixed    |
//| amount after loss, decreases by fixed amount after win.           |
//| More conservative than classic martingale.                         |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Start with base lot (e.g., 0.03)                               |
//| 2. After loss, add increment (e.g., +0.01)                        |
//| 3. After win, subtract increment (e.g., -0.01)                    |
//| 4. Never go below minimum lot                                      |
//|                                                                    |
//| D'ALEMBERT PROGRESSION EXAMPLE:                                    |
//| Start: 0.03                                                        |
//| Loss: 0.04                                                         |
//| Loss: 0.05                                                         |
//| Win: 0.04                                                          |
//| Win: 0.03                                                          |
//| Loss: 0.04                                                         |
//|                                                                    |
//| ADVANTAGES:                                                        |
//| - Linear progression (not exponential)                            |
//| - More sustainable long-term                                       |
//| - Lower capital requirements                                       |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: H1                                                   |
//| - Pairs: Major pairs                                              |
//| - Account: Minimum $3,000 recommended                             |
//|                                                                    |
//| RISK LEVEL: MEDIUM-HIGH                                            |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   BaseLot = 0.03;           // Starting lot
input double   LotIncrement = 0.01;      // Increment/decrement amount
input double   MinLot = 0.01;
input double   MaxLot = 0.5;
input int      TakeProfit = 120;
input int      StopLoss = 80;
input int      MA_Period = 20;
input int      MagicNumber = 100026;

CLicenseValidator* g_license;
double g_currentLot;
int g_ma_handle;
double g_ma[];

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "dalembert_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   g_currentLot = BaseLot;
   g_ma_handle = iMA(_Symbol, PERIOD_CURRENT, MA_Period, 0, MODE_SMA, PRICE_CLOSE);
   ArraySetAsSeries(g_ma, true);
   
   Print("D'Alembert Martingale EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   if(g_ma_handle != INVALID_HANDLE) IndicatorRelease(g_ma_handle);
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   CheckClosedTrades();
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(HasOpenPosition()) return;
   
   if(CopyBuffer(g_ma_handle, 0, 0, 3, g_ma) < 3) return;
   
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
            
            if(profit < 0)
            {
               g_currentLot = MathMin(g_currentLot + LotIncrement, MaxLot);
               Print("Loss - D'Alembert increase to: ", g_currentLot);
            }
            else
            {
               g_currentLot = MathMax(g_currentLot - LotIncrement, MinLot);
               Print("Win - D'Alembert decrease to: ", g_currentLot);
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
   request.comment = "DAlembert";
   request.deviation = 10;
   OrderSend(request, result);
}
//+------------------------------------------------------------------+
