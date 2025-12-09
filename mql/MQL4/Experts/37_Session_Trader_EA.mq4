//+------------------------------------------------------------------+
//|                                        37_Session_Trader_EA.mq4   |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| UTILITY: Trading Session Indicator & Timer                        |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      GMTOffset = 0;
input bool     AlertOnOverlap = true;

CLicenseValidator* g_license;

int g_sydneyStart = 22, g_sydneyEnd = 7;
int g_tokyoStart = 0, g_tokyoEnd = 9;
int g_londonStart = 8, g_londonEnd = 17;
int g_nyStart = 13, g_nyEnd = 22;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "session_trader_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   Print("Session Trader EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   ObjectsDeleteAll(0, "ST_");
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   int gmtHour = (TimeHour(TimeCurrent()) - GMTOffset + 24) % 24;
   
   bool sydney = IsSessionActive(gmtHour, g_sydneyStart, g_sydneyEnd);
   bool tokyo = IsSessionActive(gmtHour, g_tokyoStart, g_tokyoEnd);
   bool london = IsSessionActive(gmtHour, g_londonStart, g_londonEnd);
   bool ny = IsSessionActive(gmtHour, g_nyStart, g_nyEnd);
   
   int activeSessions = (sydney ? 1 : 0) + (tokyo ? 1 : 0) + (london ? 1 : 0) + (ny ? 1 : 0);
   bool isOverlap = activeSessions >= 2;
   
   UpdateDisplay(sydney, tokyo, london, ny, isOverlap, gmtHour);
   
   static bool wasOverlap = false;
   if(isOverlap && !wasOverlap && AlertOnOverlap)
      Alert("Session overlap started! Best time to trade.");
   wasOverlap = isOverlap;
}

bool IsSessionActive(int currentHour, int startHour, int endHour)
{
   if(startHour < endHour) return currentHour >= startHour && currentHour < endHour;
   else return currentHour >= startHour || currentHour < endHour;
}

void UpdateDisplay(bool sydney, bool tokyo, bool london, bool ny, bool overlap, int gmtHour)
{
   int y = 20;
   CreateOrUpdateLabel("ST_Title", 20, y, "=== TRADING SESSIONS ===", clrGold); y += 20;
   CreateOrUpdateLabel("ST_GMT", 20, y, "GMT: " + IntegerToString(gmtHour) + ":00", clrWhite); y += 20;
   CreateOrUpdateLabel("ST_Sydney", 20, y, "Sydney: " + (sydney ? "ACTIVE" : "Closed"), sydney ? clrLime : clrGray); y += 15;
   CreateOrUpdateLabel("ST_Tokyo", 20, y, "Tokyo: " + (tokyo ? "ACTIVE" : "Closed"), tokyo ? clrLime : clrGray); y += 15;
   CreateOrUpdateLabel("ST_London", 20, y, "London: " + (london ? "ACTIVE" : "Closed"), london ? clrLime : clrGray); y += 15;
   CreateOrUpdateLabel("ST_NY", 20, y, "New York: " + (ny ? "ACTIVE" : "Closed"), ny ? clrLime : clrGray); y += 20;
   
   string status = "";
   color statusColor = clrWhite;
   if(overlap)
   {
      if(london && ny) { status = "LONDON-NY OVERLAP"; statusColor = clrGold; }
      else { status = "SESSION OVERLAP"; statusColor = clrYellow; }
   }
   else if(london || ny) { status = "Good Trading Time"; statusColor = clrLime; }
   else { status = "Low Activity"; statusColor = clrGray; }
   
   CreateOrUpdateLabel("ST_Status", 20, y, status, statusColor);
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
