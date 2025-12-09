//+------------------------------------------------------------------+
//|                                        35_Spread_Monitor_EA.mq5   |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| UTILITY: Spread Monitor & Alert System                            |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Monitors spread in real-time and provides alerts when spread      |
//| exceeds normal levels. Helps avoid trading during high spread     |
//| periods.                                                           |
//|                                                                    |
//| FEATURES:                                                          |
//| - Real-time spread display                                        |
//| - Average spread calculation                                      |
//| - High spread alerts                                              |
//| - Spread history logging                                          |
//| - Best trading time suggestions                                   |
//|                                                                    |
//| HOW TO USE:                                                        |
//| 1. Attach to chart                                                |
//| 2. Set your maximum acceptable spread                             |
//| 3. EA will alert when spread is too high                          |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   MaxSpreadPips = 3.0;      // Alert when spread exceeds this
input int      AveragePeriod = 100;      // Bars for average calculation
input bool     EnableAlerts = true;
input bool     LogSpreadHistory = false;
input string   LogFileName = "spread_log.csv";

CLicenseValidator* g_license;
double g_spreadHistory[];
int g_historyIndex = 0;
double g_minSpread = 999999;
double g_maxSpread = 0;
double g_avgSpread = 0;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "spread_monitor_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   ArrayResize(g_spreadHistory, AveragePeriod);
   ArrayInitialize(g_spreadHistory, 0);
   
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
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pipMultiplier = (digits == 3 || digits == 5) ? 10 : 1;
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spreadPoints = (ask - bid) / point;
   double spreadPips = spreadPoints / pipMultiplier;
   
   // Update history
   g_spreadHistory[g_historyIndex] = spreadPips;
   g_historyIndex = (g_historyIndex + 1) % AveragePeriod;
   
   // Calculate stats
   if(spreadPips < g_minSpread) g_minSpread = spreadPips;
   if(spreadPips > g_maxSpread) g_maxSpread = spreadPips;
   
   double sum = 0;
   int count = 0;
   for(int i = 0; i < AveragePeriod; i++)
   {
      if(g_spreadHistory[i] > 0)
      {
         sum += g_spreadHistory[i];
         count++;
      }
   }
   g_avgSpread = count > 0 ? sum / count : spreadPips;
   
   // Update display
   UpdateDisplay(spreadPips);
   
   // Check for high spread
   if(spreadPips > MaxSpreadPips)
   {
      static datetime lastAlert = 0;
      if(TimeCurrent() - lastAlert > 60) // Alert once per minute max
      {
         if(EnableAlerts)
         {
            Alert(_Symbol, " HIGH SPREAD: ", DoubleToString(spreadPips, 1), " pips");
         }
         lastAlert = TimeCurrent();
      }
   }
   
   // Log spread
   if(LogSpreadHistory)
   {
      static datetime lastLog = 0;
      if(TimeCurrent() - lastLog >= 60) // Log every minute
      {
         LogSpread(spreadPips);
         lastLog = TimeCurrent();
      }
   }
}

void UpdateDisplay(double currentSpread)
{
   color spreadColor = clrLime;
   if(currentSpread > MaxSpreadPips) spreadColor = clrRed;
   else if(currentSpread > MaxSpreadPips * 0.7) spreadColor = clrOrange;
   else if(currentSpread > MaxSpreadPips * 0.5) spreadColor = clrYellow;
   
   int y = 20;
   CreateOrUpdateLabel("SM_Title", 20, y, "=== SPREAD MONITOR ===", clrGold); y += 20;
   CreateOrUpdateLabel("SM_Current", 20, y, "Current: " + DoubleToString(currentSpread, 1) + " pips", spreadColor); y += 15;
   CreateOrUpdateLabel("SM_Avg", 20, y, "Average: " + DoubleToString(g_avgSpread, 1) + " pips", clrWhite); y += 15;
   CreateOrUpdateLabel("SM_Min", 20, y, "Min: " + DoubleToString(g_minSpread, 1) + " pips", clrWhite); y += 15;
   CreateOrUpdateLabel("SM_Max", 20, y, "Max: " + DoubleToString(g_maxSpread, 1) + " pips", clrWhite); y += 15;
   CreateOrUpdateLabel("SM_Limit", 20, y, "Limit: " + DoubleToString(MaxSpreadPips, 1) + " pips", clrWhite); y += 15;
   
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

void LogSpread(double spread)
{
   int handle = FileOpen(LogFileName, FILE_WRITE|FILE_READ|FILE_CSV|FILE_COMMON);
   if(handle != INVALID_HANDLE)
   {
      FileSeek(handle, 0, SEEK_END);
      FileWrite(handle, TimeToString(TimeCurrent()), _Symbol, DoubleToString(spread, 2));
      FileClose(handle);
   }
}
//+------------------------------------------------------------------+
