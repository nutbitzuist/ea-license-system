//+------------------------------------------------------------------+
//|                                       34_Equity_Protector_EA.mq4  |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| UTILITY: Equity Protector & Drawdown Manager                      |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   MaxDrawdownPercent = 10;
input double   MaxDrawdownDollars = 0;
input double   DailyLossLimit = 0;
input double   DailyProfitTarget = 0;
input bool     EnableAlerts = true;
input bool     CloseAllOnLimit = true;

CLicenseValidator* g_license;
double g_peakEquity = 0;
double g_dailyStartBalance = 0;
datetime g_lastDay = 0;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "equity_protector_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   g_peakEquity = AccountEquity();
   g_dailyStartBalance = AccountBalance();
   Print("Equity Protector EA initialized. Peak: $", g_peakEquity);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   ObjectsDeleteAll(0, "EP_");
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   double equity = AccountEquity();
   double balance = AccountBalance();
   
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(today != g_lastDay) { g_dailyStartBalance = balance; g_lastDay = today; }
   
   if(equity > g_peakEquity) g_peakEquity = equity;
   
   double ddPercent = (g_peakEquity - equity) / g_peakEquity * 100;
   double ddDollars = g_peakEquity - equity;
   double dailyPL = equity - g_dailyStartBalance;
   
   UpdateDisplay(equity, ddPercent, ddDollars, dailyPL);
   
   bool limitHit = false;
   string reason = "";
   
   if(MaxDrawdownPercent > 0 && ddPercent >= MaxDrawdownPercent) { limitHit = true; reason = "Max DD% reached"; }
   if(MaxDrawdownDollars > 0 && ddDollars >= MaxDrawdownDollars) { limitHit = true; reason = "Max DD$ reached"; }
   if(DailyLossLimit > 0 && dailyPL <= -DailyLossLimit) { limitHit = true; reason = "Daily loss limit"; }
   
   if(DailyProfitTarget > 0 && dailyPL >= DailyProfitTarget)
   {
      if(EnableAlerts) Alert("Daily profit target reached!");
      if(CloseAllOnLimit) CloseAllTrades();
      return;
   }
   
   if(limitHit)
   {
      if(EnableAlerts) Alert("EQUITY PROTECTOR: ", reason);
      if(CloseAllOnLimit) CloseAllTrades();
   }
}

void CloseAllTrades()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         OrderClose(OrderTicket(), OrderLots(), (OrderType() == OP_BUY) ? Bid : Ask, 50, clrNONE);
   }
}

void UpdateDisplay(double equity, double ddPercent, double ddDollars, double dailyPL)
{
   int y = 20;
   CreateOrUpdateLabel("EP_Title", 20, y, "=== EQUITY PROTECTOR ===", clrGold); y += 20;
   CreateOrUpdateLabel("EP_Equity", 20, y, "Equity: $" + DoubleToString(equity, 2), clrWhite); y += 15;
   CreateOrUpdateLabel("EP_Peak", 20, y, "Peak: $" + DoubleToString(g_peakEquity, 2), clrWhite); y += 15;
   CreateOrUpdateLabel("EP_DD", 20, y, "DD: " + DoubleToString(ddPercent, 1) + "%", ddPercent > MaxDrawdownPercent * 0.8 ? clrOrange : clrWhite); y += 15;
   CreateOrUpdateLabel("EP_Daily", 20, y, "Daily: $" + DoubleToString(dailyPL, 2), dailyPL >= 0 ? clrLime : clrRed);
}

void CreateOrUpdateLabel(string name, int x, int y, string text, color clr)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}
//+------------------------------------------------------------------+
