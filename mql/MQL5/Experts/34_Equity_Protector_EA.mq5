//+------------------------------------------------------------------+
//|                                       34_Equity_Protector_EA.mq5  |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| UTILITY: Equity Protector & Drawdown Manager                      |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Protects your account by monitoring equity and closing all        |
//| trades when drawdown limits are reached. Essential for risk       |
//| management.                                                        |
//|                                                                    |
//| FEATURES:                                                          |
//| - Maximum drawdown protection (% or $)                            |
//| - Daily loss limit                                                 |
//| - Profit target (close all at target)                             |
//| - Trailing equity stop                                            |
//| - Email/Push alerts                                               |
//|                                                                    |
//| HOW TO USE:                                                        |
//| 1. Set your maximum acceptable drawdown                           |
//| 2. Set daily loss limit                                           |
//| 3. Optionally set profit target                                   |
//| 4. EA monitors and protects automatically                         |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   MaxDrawdownPercent = 10;  // Max drawdown % from peak
input double   MaxDrawdownDollars = 0;   // Max drawdown $ (0 = disabled)
input double   DailyLossLimit = 0;       // Daily loss limit $ (0 = disabled)
input double   DailyProfitTarget = 0;    // Daily profit target $ (0 = disabled)
input bool     EnableTrailingEquity = true;
input double   TrailingEquityPercent = 5; // Trail equity by this %
input bool     EnableAlerts = true;
input bool     CloseAllOnLimit = true;
input bool     RemoveEAOnLimit = false;

CLicenseValidator* g_license;
double g_peakEquity = 0;
double g_dailyStartBalance = 0;
datetime g_lastDay = 0;
double g_trailingEquityLevel = 0;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "equity_protector_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   g_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_trailingEquityLevel = g_peakEquity * (1 - TrailingEquityPercent / 100);
   
   Print("Equity Protector EA initialized");
   Print("Peak Equity: $", g_peakEquity);
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
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Reset daily counters
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(today != g_lastDay)
   {
      g_dailyStartBalance = balance;
      g_lastDay = today;
   }
   
   // Update peak equity
   if(equity > g_peakEquity)
   {
      g_peakEquity = equity;
      if(EnableTrailingEquity)
         g_trailingEquityLevel = g_peakEquity * (1 - TrailingEquityPercent / 100);
   }
   
   // Calculate metrics
   double drawdownPercent = (g_peakEquity - equity) / g_peakEquity * 100;
   double drawdownDollars = g_peakEquity - equity;
   double dailyPL = equity - g_dailyStartBalance;
   
   // Update display
   UpdateDisplay(equity, drawdownPercent, drawdownDollars, dailyPL);
   
   // Check limits
   bool limitHit = false;
   string reason = "";
   
   // Max drawdown %
   if(MaxDrawdownPercent > 0 && drawdownPercent >= MaxDrawdownPercent)
   {
      limitHit = true;
      reason = "Max drawdown % reached: " + DoubleToString(drawdownPercent, 1) + "%";
   }
   
   // Max drawdown $
   if(MaxDrawdownDollars > 0 && drawdownDollars >= MaxDrawdownDollars)
   {
      limitHit = true;
      reason = "Max drawdown $ reached: $" + DoubleToString(drawdownDollars, 2);
   }
   
   // Daily loss limit
   if(DailyLossLimit > 0 && dailyPL <= -DailyLossLimit)
   {
      limitHit = true;
      reason = "Daily loss limit reached: $" + DoubleToString(MathAbs(dailyPL), 2);
   }
   
   // Trailing equity stop
   if(EnableTrailingEquity && equity < g_trailingEquityLevel)
   {
      limitHit = true;
      reason = "Trailing equity stop hit at $" + DoubleToString(g_trailingEquityLevel, 2);
   }
   
   // Daily profit target
   if(DailyProfitTarget > 0 && dailyPL >= DailyProfitTarget)
   {
      if(EnableAlerts) Alert("Daily profit target reached! P/L: $", DoubleToString(dailyPL, 2));
      if(CloseAllOnLimit) CloseAllTrades();
      return;
   }
   
   if(limitHit)
   {
      if(EnableAlerts) Alert("EQUITY PROTECTOR: ", reason);
      Print("EQUITY PROTECTOR: ", reason);
      
      if(CloseAllOnLimit) CloseAllTrades();
      if(RemoveEAOnLimit) ExpertRemove();
   }
}

void CloseAllTrades()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      request.action = TRADE_ACTION_DEAL;
      request.position = PositionGetTicket(i);
      request.symbol = PositionGetString(POSITION_SYMBOL);
      request.volume = PositionGetDouble(POSITION_VOLUME);
      request.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      request.price = request.type == ORDER_TYPE_BUY ? 
         SymbolInfoDouble(request.symbol, SYMBOL_ASK) : SymbolInfoDouble(request.symbol, SYMBOL_BID);
      request.deviation = 50;
      OrderSend(request, result);
   }
}

void UpdateDisplay(double equity, double ddPercent, double ddDollars, double dailyPL)
{
   int y = 20;
   CreateOrUpdateLabel("EP_Title", 20, y, "=== EQUITY PROTECTOR ===", clrGold); y += 20;
   CreateOrUpdateLabel("EP_Equity", 20, y, "Equity: $" + DoubleToString(equity, 2), clrWhite); y += 15;
   CreateOrUpdateLabel("EP_Peak", 20, y, "Peak: $" + DoubleToString(g_peakEquity, 2), clrWhite); y += 15;
   CreateOrUpdateLabel("EP_DD", 20, y, "Drawdown: " + DoubleToString(ddPercent, 1) + "% ($" + DoubleToString(ddDollars, 2) + ")", 
      ddPercent > MaxDrawdownPercent * 0.8 ? clrOrange : clrWhite); y += 15;
   CreateOrUpdateLabel("EP_Daily", 20, y, "Daily P/L: $" + DoubleToString(dailyPL, 2), dailyPL >= 0 ? clrLime : clrRed);
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
