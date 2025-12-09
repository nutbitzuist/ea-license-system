//+------------------------------------------------------------------+
//|                                        37_Session_Trader_EA.mq5   |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| UTILITY: Trading Session Indicator & Timer                        |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Displays current trading sessions (Sydney, Tokyo, London, NY)     |
//| and provides visual cues for session overlaps which are the       |
//| best times to trade.                                               |
//|                                                                    |
//| FEATURES:                                                          |
//| - Shows active sessions                                           |
//| - Highlights session overlaps                                     |
//| - Countdown to next session                                       |
//| - Session statistics                                              |
//| - Best trading time alerts                                        |
//|                                                                    |
//| SESSION TIMES (GMT):                                               |
//| - Sydney: 22:00 - 07:00                                           |
//| - Tokyo: 00:00 - 09:00                                            |
//| - London: 08:00 - 17:00                                           |
//| - New York: 13:00 - 22:00                                         |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      GMTOffset = 0;            // Your broker's GMT offset
input bool     AlertOnOverlap = true;
input bool     ShowSessionBoxes = true;

CLicenseValidator* g_license;

// Session times in GMT
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
   
   MqlDateTime dt;
   TimeCurrent(dt);
   int gmtHour = (dt.hour - GMTOffset + 24) % 24;
   
   bool sydney = IsSessionActive(gmtHour, g_sydneyStart, g_sydneyEnd);
   bool tokyo = IsSessionActive(gmtHour, g_tokyoStart, g_tokyoEnd);
   bool london = IsSessionActive(gmtHour, g_londonStart, g_londonEnd);
   bool ny = IsSessionActive(gmtHour, g_nyStart, g_nyEnd);
   
   int activeSessions = (sydney ? 1 : 0) + (tokyo ? 1 : 0) + (london ? 1 : 0) + (ny ? 1 : 0);
   bool isOverlap = activeSessions >= 2;
   
   UpdateDisplay(sydney, tokyo, london, ny, isOverlap, gmtHour);
   
   // Alert on overlap start
   static bool wasOverlap = false;
   if(isOverlap && !wasOverlap && AlertOnOverlap)
   {
      Alert("Session overlap started! Best time to trade.");
   }
   wasOverlap = isOverlap;
}

bool IsSessionActive(int currentHour, int startHour, int endHour)
{
   if(startHour < endHour)
      return currentHour >= startHour && currentHour < endHour;
   else // Crosses midnight
      return currentHour >= startHour || currentHour < endHour;
}

int HoursUntilSession(int currentHour, int sessionStart)
{
   if(currentHour < sessionStart)
      return sessionStart - currentHour;
   else
      return 24 - currentHour + sessionStart;
}

void UpdateDisplay(bool sydney, bool tokyo, bool london, bool ny, bool overlap, int gmtHour)
{
   int y = 20;
   
   CreateOrUpdateLabel("ST_Title", 20, y, "=== TRADING SESSIONS ===", clrGold); y += 20;
   CreateOrUpdateLabel("ST_GMT", 20, y, "GMT Time: " + IntegerToString(gmtHour) + ":00", clrWhite); y += 20;
   
   CreateOrUpdateLabel("ST_Sydney", 20, y, "Sydney:  " + (sydney ? "ACTIVE" : "Closed"), sydney ? clrLime : clrGray); y += 15;
   CreateOrUpdateLabel("ST_Tokyo", 20, y, "Tokyo:   " + (tokyo ? "ACTIVE" : "Closed"), tokyo ? clrLime : clrGray); y += 15;
   CreateOrUpdateLabel("ST_London", 20, y, "London:  " + (london ? "ACTIVE" : "Closed"), london ? clrLime : clrGray); y += 15;
   CreateOrUpdateLabel("ST_NY", 20, y, "New York:" + (ny ? "ACTIVE" : "Closed"), ny ? clrLime : clrGray); y += 20;
   
   string status = "";
   color statusColor = clrWhite;
   
   if(overlap)
   {
      if(london && ny) { status = "LONDON-NY OVERLAP (Best!)"; statusColor = clrGold; }
      else if(tokyo && london) { status = "TOKYO-LONDON OVERLAP"; statusColor = clrYellow; }
      else if(sydney && tokyo) { status = "SYDNEY-TOKYO OVERLAP"; statusColor = clrYellow; }
      else { status = "SESSION OVERLAP"; statusColor = clrYellow; }
   }
   else if(london || ny)
   {
      status = "Good Trading Time";
      statusColor = clrLime;
   }
   else if(tokyo)
   {
      status = "Moderate Activity";
      statusColor = clrOrange;
   }
   else
   {
      status = "Low Activity";
      statusColor = clrGray;
   }
   
   CreateOrUpdateLabel("ST_Status", 20, y, status, statusColor); y += 20;
   
   // Next session info
   if(!london)
   {
      int hoursToLondon = HoursUntilSession(gmtHour, g_londonStart);
      CreateOrUpdateLabel("ST_Next", 20, y, "London opens in: " + IntegerToString(hoursToLondon) + "h", clrWhite);
   }
   else if(!ny)
   {
      int hoursToNY = HoursUntilSession(gmtHour, g_nyStart);
      CreateOrUpdateLabel("ST_Next", 20, y, "NY opens in: " + IntegerToString(hoursToNY) + "h", clrWhite);
   }
   else
   {
      CreateOrUpdateLabel("ST_Next", 20, y, "Prime trading time!", clrGold);
   }
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
