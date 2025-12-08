//+------------------------------------------------------------------+
//|                                           09_Grid_Recovery_EA.mq5 |
//|                                    EA License Management System   |
//|                                                                    |
//| STRATEGY: Grid Trading with Recovery                               |
//| LOGIC: Places grid orders at fixed intervals. When price moves     |
//|        against position, opens recovery orders with increased lot. |
//|        Closes all when total profit target is reached.             |
//| TIMEFRAME: Any                                                     |
//| PAIRS: Range-bound pairs (EURCHF, AUDNZD)                         |
//| WARNING: High risk strategy, use with caution                      |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

//--- Input parameters
input string   EA_ApiKey = "";           // API Key
input string   EA_ApiSecret = "";        // API Secret
input double   InitialLot = 0.01;        // Initial Lot Size
input double   LotMultiplier = 1.5;      // Lot Multiplier
input int      GridStep = 200;           // Grid Step (points)
input int      MaxOrders = 5;            // Maximum Orders
input double   TakeProfitMoney = 10;     // Take Profit ($)
input int      MagicNumber = 100009;     // Magic Number

//--- Global variables
CLicenseValidator* g_license;
bool g_isLicensed = false;
int g_orderCount = 0;
double g_lastOrderPrice = 0;
ENUM_ORDER_TYPE g_direction = ORDER_TYPE_BUY;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "grid_recovery_ea", "1.0.0");
   g_isLicensed = g_license.ValidateLicense();
   
   if(!g_isLicensed)
   {
      Print("License validation failed: ", g_license.GetLastError());
      return INIT_FAILED;
   }
   
   Print("Grid Recovery EA initialized successfully");
   Print("WARNING: This is a high-risk strategy. Use with caution!");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_license != NULL)
   {
      delete g_license;
      g_license = NULL;
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   //--- Count current positions and calculate profit
   double totalProfit = 0;
   g_orderCount = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            g_orderCount++;
            totalProfit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            
            if(g_orderCount == 1)
            {
               g_lastOrderPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               g_direction = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
            }
         }
      }
   }
   
   //--- Check if profit target reached
   if(g_orderCount > 0 && totalProfit >= TakeProfitMoney)
   {
      CloseAllPositions();
      return;
   }
   
   //--- Open initial order if no positions
   if(g_orderCount == 0)
   {
      //--- Simple trend detection for initial direction
      double ma = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
      double close = iClose(_Symbol, PERIOD_CURRENT, 0);
      
      double maValue[];
      ArraySetAsSeries(maValue, true);
      int maHandle = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
      if(CopyBuffer(maHandle, 0, 0, 1, maValue) > 0)
      {
         g_direction = (close > maValue[0]) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      }
      IndicatorRelease(maHandle);
      
      OpenGridOrder(InitialLot);
      return;
   }
   
   //--- Check if we need to open recovery order
   if(g_orderCount < MaxOrders)
   {
      double currentPrice = (g_direction == ORDER_TYPE_BUY) ? 
                            SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                            SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double gridDistance = GridStep * point;
      
      bool needRecovery = false;
      
      if(g_direction == ORDER_TYPE_BUY && currentPrice <= g_lastOrderPrice - gridDistance)
      {
         needRecovery = true;
      }
      else if(g_direction == ORDER_TYPE_SELL && currentPrice >= g_lastOrderPrice + gridDistance)
      {
         needRecovery = true;
      }
      
      if(needRecovery)
      {
         double newLot = InitialLot * MathPow(LotMultiplier, g_orderCount);
         newLot = NormalizeDouble(newLot, 2);
         OpenGridOrder(newLot);
      }
   }
}

//+------------------------------------------------------------------+
//| Open a grid order                                                  |
//+------------------------------------------------------------------+
void OpenGridOrder(double lot)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   double price = (g_direction == ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lot;
   request.type = g_direction;
   request.price = price;
   request.sl = 0;
   request.tp = 0;
   request.magic = MagicNumber;
   request.comment = "Grid #" + IntegerToString(g_orderCount + 1);
   request.deviation = 10;
   
   if(OrderSend(request, result))
   {
      g_lastOrderPrice = price;
      Print("Grid order opened: Lot=", lot, " Price=", price);
   }
   else
   {
      Print("OrderSend failed: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Close all positions                                                |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
            PositionGetString(POSITION_SYMBOL) == _Symbol)
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
   
   Print("All grid positions closed. Profit target reached!");
}
//+------------------------------------------------------------------+
