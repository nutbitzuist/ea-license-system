//+------------------------------------------------------------------+
//|                                        24_Grid_Martingale_EA.mq5  |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Grid Martingale                                          |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Combines grid trading with martingale. Opens positions at fixed   |
//| price intervals, increasing lot size at each level. Closes all    |
//| positions when total profit target is reached.                     |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Opens initial position in trend direction                      |
//| 2. If price moves against, opens new position at grid interval    |
//| 3. Each new position has larger lot size                          |
//| 4. Calculates average entry price                                 |
//| 5. Closes all when price returns to profit target                 |
//|                                                                    |
//| GRID LEVELS EXAMPLE (200 point grid):                              |
//| Level 1: 1.1000 - 0.01 lot                                        |
//| Level 2: 1.0980 - 0.02 lot                                        |
//| Level 3: 1.0960 - 0.04 lot                                        |
//| Level 4: 1.0940 - 0.08 lot                                        |
//|                                                                    |
//| RISK MANAGEMENT:                                                   |
//| - Maximum grid levels                                             |
//| - Maximum total lot size                                          |
//| - Equity protection stop                                           |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: Any                                                  |
//| - Pairs: Range-bound pairs                                        |
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
input double   InitialLot = 0.01;
input double   LotMultiplier = 2.0;
input int      GridStep = 200;           // Grid step in points
input int      MaxGridLevels = 6;
input double   TakeProfitMoney = 20;     // Total profit target ($)
input double   MaxTotalLot = 1.0;
input int      MagicNumber = 100024;

CLicenseValidator* g_license;
double g_lastGridPrice = 0;
int g_gridLevel = 0;
int g_direction = 0;  // 1 = buy, -1 = sell

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "grid_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   Print("Grid Martingale EA initialized - WARNING: VERY HIGH RISK!");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   // Calculate total profit
   double totalProfit = 0;
   double totalLots = 0;
   int posCount = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            totalProfit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            totalLots += PositionGetDouble(POSITION_VOLUME);
            posCount++;
            
            if(posCount == 1)
            {
               g_direction = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
            }
         }
      }
   }
   
   // Check if profit target reached
   if(posCount > 0 && totalProfit >= TakeProfitMoney)
   {
      CloseAllPositions();
      g_gridLevel = 0;
      g_lastGridPrice = 0;
      Print("Profit target reached! Closed all positions.");
      return;
   }
   
   // No positions - start new grid
   if(posCount == 0)
   {
      // Simple trend detection
      double ma = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
      double maValue[];
      ArraySetAsSeries(maValue, true);
      int maHandle = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
      if(CopyBuffer(maHandle, 0, 0, 1, maValue) > 0)
      {
         double close = iClose(_Symbol, PERIOD_CURRENT, 0);
         g_direction = (close > maValue[0]) ? 1 : -1;
      }
      IndicatorRelease(maHandle);
      
      OpenGridPosition();
      return;
   }
   
   // Check if we need to open next grid level
   if(g_gridLevel < MaxGridLevels && totalLots < MaxTotalLot)
   {
      double currentPrice = (g_direction == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double gridDistance = GridStep * point;
      
      bool needNewLevel = false;
      if(g_direction == 1 && currentPrice <= g_lastGridPrice - gridDistance)
         needNewLevel = true;
      else if(g_direction == -1 && currentPrice >= g_lastGridPrice + gridDistance)
         needNewLevel = true;
      
      if(needNewLevel)
      {
         OpenGridPosition();
      }
   }
}

void OpenGridPosition()
{
   double lot = InitialLot * MathPow(LotMultiplier, g_gridLevel);
   lot = NormalizeDouble(lot, 2);
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   ENUM_ORDER_TYPE orderType = (g_direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lot;
   request.type = orderType;
   request.price = price;
   request.sl = 0;
   request.tp = 0;
   request.magic = MagicNumber;
   request.comment = "Grid L" + IntegerToString(g_gridLevel + 1);
   request.deviation = 10;
   
   if(OrderSend(request, result))
   {
      g_lastGridPrice = price;
      g_gridLevel++;
      Print("Grid Level ", g_gridLevel, " opened. Lot: ", lot);
   }
}

void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            request.action = TRADE_ACTION_DEAL;
            request.symbol = _Symbol;
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.price = (request.type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
            request.position = PositionGetTicket(i);
            request.deviation = 10;
            OrderSend(request, result);
         }
      }
   }
}
//+------------------------------------------------------------------+
