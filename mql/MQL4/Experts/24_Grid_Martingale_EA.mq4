//+------------------------------------------------------------------+
//|                                        24_Grid_Martingale_EA.mq4  |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Grid Martingale - Opens positions at price intervals   |
//| Closes all when profit target reached. VERY HIGH RISK            |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   InitialLot = 0.01;
input double   LotMultiplier = 2.0;
input int      GridStep = 200;
input int      MaxGridLevels = 6;
input double   TakeProfitMoney = 20;
input double   MaxTotalLot = 1.0;
input int      MagicNumber = 100024;

CLicenseValidator* g_license;
double g_lastGridPrice = 0;
int g_gridLevel = 0;
int g_direction = 0;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "grid_martingale_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   Print("Grid Martingale EA initialized - WARNING: VERY HIGH RISK!");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   double totalProfit = 0;
   double totalLots = 0;
   int posCount = 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         {
            totalProfit += OrderProfit() + OrderSwap();
            totalLots += OrderLots();
            posCount++;
            if(posCount == 1) g_direction = (OrderType() == OP_BUY) ? 1 : -1;
         }
      }
   }
   
   if(posCount > 0 && totalProfit >= TakeProfitMoney)
   {
      CloseAllOrders();
      g_gridLevel = 0;
      g_lastGridPrice = 0;
      return;
   }
   
   if(posCount == 0)
   {
      double ma = iMA(Symbol(), PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
      g_direction = (Close[0] > ma) ? 1 : -1;
      OpenGridOrder();
      return;
   }
   
   if(g_gridLevel < MaxGridLevels && totalLots < MaxTotalLot)
   {
      double currentPrice = (g_direction == 1) ? Bid : Ask;
      double gridDistance = GridStep * Point;
      
      bool needNewLevel = false;
      if(g_direction == 1 && currentPrice <= g_lastGridPrice - gridDistance) needNewLevel = true;
      else if(g_direction == -1 && currentPrice >= g_lastGridPrice + gridDistance) needNewLevel = true;
      
      if(needNewLevel) OpenGridOrder();
   }
}

void OpenGridOrder()
{
   double lot = NormalizeDouble(InitialLot * MathPow(LotMultiplier, g_gridLevel), 2);
   int orderType = (g_direction == 1) ? OP_BUY : OP_SELL;
   double price = (orderType == OP_BUY) ? Ask : Bid;
   
   int ticket = OrderSend(Symbol(), orderType, lot, price, 10, 0, 0, "Grid L" + IntegerToString(g_gridLevel + 1), MagicNumber, 0, clrNONE);
   if(ticket > 0)
   {
      g_lastGridPrice = price;
      g_gridLevel++;
   }
}

void CloseAllOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
            OrderClose(OrderTicket(), OrderLots(), (OrderType() == OP_BUY) ? Bid : Ask, 10, clrNONE);
      }
   }
}
//+------------------------------------------------------------------+
