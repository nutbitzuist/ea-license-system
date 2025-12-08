//+------------------------------------------------------------------+
//|                                           09_Grid_Recovery_EA.mq4 |
//|                                    EA License Management System   |
//|                                                                    |
//| STRATEGY: Grid Trading with Recovery                               |
//| LOGIC: Places grid orders, increases lot on drawdown, closes all   |
//|        when profit target reached.                                 |
//| WARNING: High risk strategy                                        |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   InitialLot = 0.01;
input double   LotMultiplier = 1.5;
input int      GridStep = 200;
input int      MaxOrders = 5;
input double   TakeProfitMoney = 10;
input int      MagicNumber = 100009;

CLicenseValidator* g_license;
bool g_isLicensed = false;
int g_orderCount = 0;
double g_lastOrderPrice = 0;
int g_direction = OP_BUY;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "grid_recovery_ea", "1.0.0");
   g_isLicensed = g_license.ValidateLicense();
   if(!g_isLicensed) { Print("License failed"); return INIT_FAILED; }
   Print("Grid Recovery EA initialized - WARNING: High risk!");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   double totalProfit = 0;
   g_orderCount = 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         {
            g_orderCount++;
            totalProfit += OrderProfit() + OrderSwap();
            if(g_orderCount == 1)
            {
               g_lastOrderPrice = OrderOpenPrice();
               g_direction = OrderType();
            }
         }
      }
   }
   
   if(g_orderCount > 0 && totalProfit >= TakeProfitMoney)
   {
      CloseAllOrders();
      return;
   }
   
   if(g_orderCount == 0)
   {
      double ma = iMA(Symbol(), PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
      g_direction = (Close[0] > ma) ? OP_BUY : OP_SELL;
      OpenGridOrder(InitialLot);
      return;
   }
   
   if(g_orderCount < MaxOrders)
   {
      double currentPrice = (g_direction == OP_BUY) ? Bid : Ask;
      double gridDistance = GridStep * Point;
      
      bool needRecovery = false;
      if(g_direction == OP_BUY && currentPrice <= g_lastOrderPrice - gridDistance)
         needRecovery = true;
      else if(g_direction == OP_SELL && currentPrice >= g_lastOrderPrice + gridDistance)
         needRecovery = true;
      
      if(needRecovery)
      {
         double newLot = NormalizeDouble(InitialLot * MathPow(LotMultiplier, g_orderCount), 2);
         OpenGridOrder(newLot);
      }
   }
}

void OpenGridOrder(double lot)
{
   double price = (g_direction == OP_BUY) ? Ask : Bid;
   int ticket = OrderSend(Symbol(), g_direction, lot, price, 10, 0, 0, "Grid #" + IntegerToString(g_orderCount + 1), MagicNumber, 0, clrNONE);
   if(ticket > 0)
   {
      g_lastOrderPrice = price;
      Print("Grid order opened: Lot=", lot);
   }
}

void CloseAllOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         {
            double price = (OrderType() == OP_BUY) ? Bid : Ask;
            OrderClose(OrderTicket(), OrderLots(), price, 10, clrNONE);
         }
      }
   }
   Print("All grid orders closed - Profit target reached!");
}
//+------------------------------------------------------------------+
