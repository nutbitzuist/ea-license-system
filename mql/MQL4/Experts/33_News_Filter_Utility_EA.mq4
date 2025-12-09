//+------------------------------------------------------------------+
//|                                    33_News_Filter_Utility_EA.mq4  |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| UTILITY: News Filter & Trading Hours Manager                      |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input bool     EnableTradingHours = true;
input int      TradingStartHour = 8;
input int      TradingEndHour = 20;
input bool     EnableFridayClose = true;
input int      FridayCloseHour = 20;
input bool     EnableMondayDelay = true;
input int      MondayStartHour = 2;
input bool     CloseOnRestriction = false;
input int      MagicFilter = 0;

CLicenseValidator* g_license;
bool g_tradingAllowed = true;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "news_filter_utility_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   Print("News Filter Utility EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   ObjectsDeleteAll(0, "NF_");
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   g_tradingAllowed = CheckTradingAllowed();
   UpdateDisplay();
   
   if(!g_tradingAllowed && CloseOnRestriction) CloseAllTrades();
}

bool CheckTradingAllowed()
{
   int hour = TimeHour(TimeCurrent());
   int dayOfWeek = TimeDayOfWeek(TimeCurrent());
   
   if(EnableFridayClose && dayOfWeek == 5 && hour >= FridayCloseHour) return false;
   if(dayOfWeek == 0 || dayOfWeek == 6) return false;
   if(EnableMondayDelay && dayOfWeek == 1 && hour < MondayStartHour) return false;
   if(EnableTradingHours && (hour < TradingStartHour || hour >= TradingEndHour)) return false;
   
   return true;
}

void CloseAllTrades()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(MagicFilter > 0 && OrderMagicNumber() != MagicFilter) continue;
      OrderClose(OrderTicket(), OrderLots(), (OrderType() == OP_BUY) ? Bid : Ask, 10, clrNONE);
   }
}

void UpdateDisplay()
{
   string status = g_tradingAllowed ? "TRADING ALLOWED" : "TRADING PAUSED";
   color clr = g_tradingAllowed ? clrLime : clrRed;
   
   if(ObjectFind(0, "NF_Status") < 0)
   {
      ObjectCreate(0, "NF_Status", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "NF_Status", OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, "NF_Status", OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, "NF_Status", OBJPROP_FONTSIZE, 12);
   }
   ObjectSetString(0, "NF_Status", OBJPROP_TEXT, status);
   ObjectSetInteger(0, "NF_Status", OBJPROP_COLOR, clr);
}
//+------------------------------------------------------------------+
