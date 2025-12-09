//+------------------------------------------------------------------+
//|                                        35_Spread_Monitor_EA.mq4   |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| UTILITY: Spread Monitor & Alert System                            |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   MaxSpreadPips = 3.0;
input bool     EnableAlerts = true;

CLicenseValidator* g_license;
double g_minSpread = 999999;
double g_maxSpread = 0;
double g_avgSpread = 0;
double g_spreadSum = 0;
int g_spreadCount = 0;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "spread_monitor_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   Print("Spread Monitor EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   ObjectsDeleteAll(0, "SM_");
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   int digits = (int)MarketInfo(Symbol(), MODE_DIGITS);
   double pipMultiplier = (digits == 3 || digits == 5) ? 10 : 1;
   double spreadPoints = MarketInfo(Symbol(), MODE_SPREAD);
   double spreadPips = spreadPoints / pipMultiplier;
   
   if(spreadPips < g_minSpread) g_minSpread = spreadPips;
   if(spreadPips > g_maxSpread) g_maxSpread = spreadPips;
   g_spreadSum += spreadPips;
   g_spreadCount++;
   g_avgSpread = g_spreadSum / g_spreadCount;
   
   UpdateDisplay(spreadPips);
   
   if(spreadPips > MaxSpreadPips)
   {
      static datetime lastAlert = 0;
      if(TimeCurrent() - lastAlert > 60)
      {
         if(EnableAlerts) Alert(Symbol(), " HIGH SPREAD: ", DoubleToString(spreadPips, 1), " pips");
         lastAlert = TimeCurrent();
      }
   }
}

void UpdateDisplay(double currentSpread)
{
   color spreadColor = clrLime;
   if(currentSpread > MaxSpreadPips) spreadColor = clrRed;
   else if(currentSpread > MaxSpreadPips * 0.7) spreadColor = clrOrange;
   
   int y = 20;
   CreateOrUpdateLabel("SM_Title", 20, y, "=== SPREAD MONITOR ===", clrGold); y += 20;
   CreateOrUpdateLabel("SM_Current", 20, y, "Current: " + DoubleToString(currentSpread, 1) + " pips", spreadColor); y += 15;
   CreateOrUpdateLabel("SM_Avg", 20, y, "Average: " + DoubleToString(g_avgSpread, 1) + " pips", clrWhite); y += 15;
   CreateOrUpdateLabel("SM_Min", 20, y, "Min: " + DoubleToString(g_minSpread, 1) + " pips", clrWhite); y += 15;
   CreateOrUpdateLabel("SM_Max", 20, y, "Max: " + DoubleToString(g_maxSpread, 1) + " pips", clrWhite); y += 15;
   
   string status = currentSpread <= MaxSpreadPips ? "OK TO TRADE" : "SPREAD TOO HIGH";
   CreateOrUpdateLabel("SM_Status", 20, y, status, spreadColor);
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
