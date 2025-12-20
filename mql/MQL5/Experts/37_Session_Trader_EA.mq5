//+------------------------------------------------------------------+
//|                                        37_Session_Trader_EA.mq5   |
//|                                    My Algo Stack - Trading Infrastructure   |
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
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

//=============================================================================
// LICENSE CONFIGURATION - DO NOT MODIFY
//=============================================================================
#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "session_trader_ea"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200  // Check every 12 hours (in seconds)
#define LICENSE_GRACE_PERIOD 86400    // 24 hours grace if server unreachable

//=============================================================================
// USER INPUT PARAMETERS
//=============================================================================
input string   LicenseKey = "";          // License Key (from dashboard)
input int      GMTOffset = 0;            // Your broker's GMT offset
input bool     AlertOnOverlap = true;
input bool     ShowSessionBoxes = true;

//--- MONEY MANAGEMENT ---
input bool     UseMoneyManagement = true;   // Use Risk % for Lot Size
input double   RiskPercent        = 2.0;    // Risk per trade (%)

//--- TRAILING STOP & BREAK EVEN ---
input bool     UseTrailingStop    = true;   // Enable Trailing Stop
input int      TrailingStop       = 50;     // Trailing Stop (points)
input int      TrailingStep       = 10;     // Trailing Step (points)

input bool     UseBreakEven       = true;   // Enable Break Even
input int      BreakEvenTrigger   = 30;     // Points profit to trigger BE
input int      BreakEvenLock      = 5;      // Points to lock in profit

//--- FORWARD DECLARATIONS ---
void ManagePositions();
double GetLotSize(double slPoints);

// Session times in GMT
int g_sydneyStart = 22, g_sydneyEnd = 7;
int g_tokyoStart = 0, g_tokyoEnd = 9;
int g_londonStart = 8, g_londonEnd = 17;
int g_nyStart = 13, g_nyEnd = 22;

//=============================================================================
// LICENSE VALIDATOR (EMBEDDED - NO EXTERNAL FILES NEEDED)
//=============================================================================
datetime g_lastValidation = 0;
bool g_isLicensed = false;
string g_licenseError = "";

bool ValidateLicense()
{
   if(StringLen(LicenseKey) < 10)
   {
      g_licenseError = "Invalid License Key. Get your key from the dashboard.";
      return false;
   }
   
   string accountNum = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   string broker = AccountInfoString(ACCOUNT_COMPANY);
   
   string jsonBody = StringFormat(
      "{\"accountNumber\":\"%s\",\"brokerName\":\"%s\",\"eaCode\":\"%s\",\"eaVersion\":\"%s\",\"terminalType\":\"MT5\"}",
      accountNum, broker, LICENSE_EA_CODE, LICENSE_EA_VERSION
   );
   
   string headers = StringFormat("Content-Type: application/json\r\nX-API-Key: %s", LicenseKey);
   
   char postData[];
   char resultData[];
   string resultHeaders;
   
   StringToCharArray(jsonBody, postData, 0, StringLen(jsonBody));
   ArrayResize(postData, StringLen(jsonBody));
   
   int statusCode = WebRequest("POST", LICENSE_API_URL, headers, 10000, postData, resultData, resultHeaders);
   
   if(statusCode == -1)
   {
      int err = GetLastError();
      if(err == 4060)
         g_licenseError = "Add URL to allowed list: Tools -> Options -> Expert Advisors -> Add: https://myalgostack.com";
      else
         g_licenseError = "Server connection failed. Error: " + IntegerToString(err);
      
      if(g_lastValidation > 0 && (TimeCurrent() - g_lastValidation) < LICENSE_GRACE_PERIOD)
         return g_isLicensed;
      return false;
   }
   
   string response = CharArrayToString(resultData);
   bool isValid = (StringFind(response, "\"valid\":true") >= 0);
   
   if(!isValid)
   {
      int msgStart = StringFind(response, "\"message\":\"") + 11;
      int msgEnd = StringFind(response, "\"", msgStart);
      if(msgStart > 10 && msgEnd > msgStart)
         g_licenseError = StringSubstr(response, msgStart, msgEnd - msgStart);
      else
         g_licenseError = "License validation failed. Check your License Key.";
   }
   
   g_lastValidation = TimeCurrent();
   g_isLicensed = isValid;
   return isValid;
}

bool PeriodicLicenseCheck()
{
   if(!g_isLicensed) return false;
   if((TimeCurrent() - g_lastValidation) < LICENSE_CHECK_INTERVAL) return true;
   return ValidateLicense();
}


int OnInit()
{
   Print("Validating license...");
   
   if(!ValidateLicense())
   {
      Print("LICENSE ERROR: ", g_licenseError);
      Alert("License Error: ", g_licenseError);
      return INIT_FAILED;
   }
   
   Print("License validated successfully!");
   Print("Account: ", AccountInfoInteger(ACCOUNT_LOGIN), " | Broker: ", AccountInfoString(ACCOUNT_COMPANY));
   
   Print("Session Trader EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "ST_");
}

void OnTick()
{
   // Manage open positions (Trailing Stop & BreakEven)
   ManagePositions();
   if(!PeriodicLicenseCheck())
   {
      Print("License expired or invalid: ", g_licenseError);
      ExpertRemove();
      return;
   }
   
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


//+------------------------------------------------------------------+
//| Calculate Lot Size based on Risk %                               |
//+------------------------------------------------------------------+
double GetLotSize(double slPoints)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(tickSize == 0 || point == 0) return 0.01;
   
   // Calculate risk amount in money
   double riskMoney = accountBalance * (RiskPercent / 100.0);
   
   // Money per lot for 1 point movement = (TickValue / TickSize) * Point
   double moneyPerPointPerLot = (tickValue / tickSize) * point;
   
   if(moneyPerPointPerLot == 0) return 0.01;
   
   // Calculate lots: RiskMoney / (SL_Points * MoneyPerPointPerLot)
   double calculatedLots = riskMoney / (slPoints * moneyPerPointPerLot);
   
   // Normalize lots
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   calculatedLots = MathFloor(calculatedLots / stepLot) * stepLot;
   
   if(calculatedLots < minLot) calculatedLots = minLot;
   if(calculatedLots > maxLot) calculatedLots = maxLot;
   
   return calculatedLots;
}

//+------------------------------------------------------------------+
//| Manage Positions (Trailing Stop & Break Even)                    |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      // Data
      long type = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      //--- BREAK EVEN ---
      if(UseBreakEven)
      {
         if(type == POSITION_TYPE_BUY)
         {
            if(currentPrice - openPrice > BreakEvenTrigger * point)
            {
               double newSL = openPrice + BreakEvenLock * point;
               if(newSL > currentSL && (currentSL == 0 || newSL > currentSL))
               {
                  MqlTradeRequest request = {};
                  MqlTradeResult result = {};
                  request.action = TRADE_ACTION_SLTP;
                  request.position = ticket;
                  request.sl = newSL;
                  request.tp = PositionGetDouble(POSITION_TP);
                  request.symbol = _Symbol;
                  if(!OrderSend(request, result))
                     Print("Failed to move SL/TP: ", GetLastError());
               }
            }
         }
         else // SELL
         {
            if(openPrice - currentPrice > BreakEvenTrigger * point)
            {
               double newSL = openPrice - BreakEvenLock * point;
               if(newSL < currentSL || currentSL == 0)
               {
                  MqlTradeRequest request = {};
                  MqlTradeResult result = {};
                  request.action = TRADE_ACTION_SLTP;
                  request.position = ticket;
                  request.sl = newSL;
                  request.tp = PositionGetDouble(POSITION_TP);
                  request.symbol = _Symbol;
                  if(!OrderSend(request, result))
                     Print("Failed to move SL/TP: ", GetLastError());
               }
            }
         }
      }
      
      //--- TRAILING STOP ---
      if(UseTrailingStop)
      {
         if(type == POSITION_TYPE_BUY)
         {
            if(currentPrice - openPrice > TrailingStop * point)
            {
               double newSL = currentPrice - TrailingStop * point;
               if(newSL > currentSL + TrailingStep * point)
               {
                  MqlTradeRequest request = {};
                  MqlTradeResult result = {};
                  request.action = TRADE_ACTION_SLTP;
                  request.position = ticket;
                  request.sl = newSL;
                  request.tp = PositionGetDouble(POSITION_TP);
                  request.symbol = _Symbol;
                  if(!OrderSend(request, result))
                     Print("Failed to move SL/TP: ", GetLastError());
               }
            }
         }
         else // SELL
         {
            if(openPrice - currentPrice > TrailingStop * point)
            {
               double newSL = currentPrice + TrailingStop * point;
               if(newSL < currentSL - TrailingStep * point || currentSL == 0)
               {
                  MqlTradeRequest request = {};
                  MqlTradeResult result = {};
                  request.action = TRADE_ACTION_SLTP;
                  request.position = ticket;
                  request.sl = newSL;
                  request.tp = PositionGetDouble(POSITION_TP);
                  request.symbol = _Symbol;
                  if(!OrderSend(request, result))
                     Print("Failed to move SL/TP: ", GetLastError());
               }
            }
         }
      }
   }
}
