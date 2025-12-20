//+------------------------------------------------------------------+
//|                                        37_Session_Trader_EA.mq4   |
//|                                    My Algo Stack - Trading Infrastructure   |
//+------------------------------------------------------------------+
//| UTILITY: Trading Session Indicator & Timer                        |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "session_trader_ea"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200
#define LICENSE_GRACE_PERIOD 86400

input string   LicenseKey = "";
input int      GMTOffset = 0;
input bool     AlertOnOverlap = true;

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

datetime g_lastValidation = 0; bool g_isLicensed = false; string g_licenseError = "";
bool ValidateLicense() { if(StringLen(LicenseKey) < 10) { g_licenseError = "Invalid License Key"; return false; } string jsonBody = StringFormat("{\"accountNumber\":\"%s\",\"brokerName\":\"%s\",\"eaCode\":\"%s\",\"eaVersion\":\"%s\",\"terminalType\":\"MT4\"}", IntegerToString(AccountNumber()), AccountCompany(), LICENSE_EA_CODE, LICENSE_EA_VERSION); string headers = StringFormat("Content-Type: application/json\r\nX-API-Key: %s", LicenseKey); char postData[], resultData[]; string resultHeaders; StringToCharArray(jsonBody, postData, 0, StringLen(jsonBody)); ArrayResize(postData, StringLen(jsonBody)); int statusCode = WebRequest("POST", LICENSE_API_URL, headers, 10000, postData, resultData, resultHeaders); if(statusCode == -1) { g_licenseError = "Connection failed"; if(g_lastValidation > 0 && (TimeCurrent() - g_lastValidation) < LICENSE_GRACE_PERIOD) return g_isLicensed; return false; } string response = CharArrayToString(resultData); bool isValid = (StringFind(response, "\"valid\":true") >= 0); g_lastValidation = TimeCurrent(); g_isLicensed = isValid; return isValid; }
bool PeriodicLicenseCheck() { if(!g_isLicensed) return false; if((TimeCurrent() - g_lastValidation) < LICENSE_CHECK_INTERVAL) return true; return ValidateLicense(); }

int g_sydneyStart = 22, g_sydneyEnd = 7;
int g_tokyoStart = 0, g_tokyoEnd = 9;
int g_londonStart = 8, g_londonEnd = 17;
int g_nyStart = 13, g_nyEnd = 22;

int OnInit()
{
   if(!ValidateLicense()) { Print("LICENSE ERROR: ", g_licenseError); Alert("License Error: ", g_licenseError); return INIT_FAILED; }
   Print("Session Trader EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { ObjectsDeleteAll(0, "ST_"); }

void OnTick()
{
   // Manage open positions (Trailing Stop & BreakEven)
   ManagePositions();
   if(!PeriodicLicenseCheck()) { ExpertRemove(); return; }
   
   int gmtHour = (TimeHour(TimeCurrent()) - GMTOffset + 24) % 24;
   bool sydney = IsSessionActive(gmtHour, g_sydneyStart, g_sydneyEnd);
   bool tokyo = IsSessionActive(gmtHour, g_tokyoStart, g_tokyoEnd);
   bool london = IsSessionActive(gmtHour, g_londonStart, g_londonEnd);
   bool ny = IsSessionActive(gmtHour, g_nyStart, g_nyEnd);
   int activeSessions = (sydney ? 1 : 0) + (tokyo ? 1 : 0) + (london ? 1 : 0) + (ny ? 1 : 0);
   bool isOverlap = activeSessions >= 2;
   
   UpdateDisplay(sydney, tokyo, london, ny, isOverlap, gmtHour);
   
   static bool wasOverlap = false;
   if(isOverlap && !wasOverlap && AlertOnOverlap) Alert("Session overlap started! Best time to trade.");
   wasOverlap = isOverlap;
}

bool IsSessionActive(int currentHour, int startHour, int endHour) { if(startHour < endHour) return currentHour >= startHour && currentHour < endHour; else return currentHour >= startHour || currentHour < endHour; }

void UpdateDisplay(bool sydney, bool tokyo, bool london, bool ny, bool overlap, int gmtHour) { int y = 20; CreateOrUpdateLabel("ST_Title", 20, y, "=== TRADING SESSIONS ===", clrGold); y += 20; CreateOrUpdateLabel("ST_GMT", 20, y, "GMT: " + IntegerToString(gmtHour) + ":00", clrWhite); y += 20; CreateOrUpdateLabel("ST_Sydney", 20, y, "Sydney: " + (sydney ? "ACTIVE" : "Closed"), sydney ? clrLime : clrGray); y += 15; CreateOrUpdateLabel("ST_Tokyo", 20, y, "Tokyo: " + (tokyo ? "ACTIVE" : "Closed"), tokyo ? clrLime : clrGray); y += 15; CreateOrUpdateLabel("ST_London", 20, y, "London: " + (london ? "ACTIVE" : "Closed"), london ? clrLime : clrGray); y += 15; CreateOrUpdateLabel("ST_NY", 20, y, "New York: " + (ny ? "ACTIVE" : "Closed"), ny ? clrLime : clrGray); y += 20; string status = ""; color statusColor = clrWhite; if(overlap) { if(london && ny) { status = "LONDON-NY OVERLAP"; statusColor = clrGold; } else { status = "SESSION OVERLAP"; statusColor = clrYellow; } } else if(london || ny) { status = "Good Trading Time"; statusColor = clrLime; } else { status = "Low Activity"; statusColor = clrGray; } CreateOrUpdateLabel("ST_Status", 20, y, status, statusColor); }
void CreateOrUpdateLabel(string name, int x, int y, string text, color clr) { if(ObjectFind(0, name) < 0) { ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0); ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y); ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10); } ObjectSetString(0, name, OBJPROP_TEXT, text); ObjectSetInteger(0, name, OBJPROP_COLOR, clr); }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Calculate Lot Size based on Risk %                               |
//+------------------------------------------------------------------+
double GetLotSize(double slPoints)
{
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   double point = Point;
   double accountBalance = AccountBalance();
   
   if(tickSize == 0 || point == 0 || tickValue == 0) return 0.01;
   
   // Calculate risk amount in money
   double riskMoney = accountBalance * (RiskPercent / 100.0);
   
   // Money per lot for 1 point movement = (TickValue / TickSize) * Point
   double moneyPerPointPerLot = (tickValue / tickSize) * point;
   
   if(moneyPerPointPerLot == 0) return 0.01;
   
   // Calculate lots: RiskMoney / (SL_Points * MoneyPerPointPerLot)
   double calculatedLots = riskMoney / (slPoints * moneyPerPointPerLot);
   
   // Normalize lots
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double stepLot = MarketInfo(Symbol(), MODE_LOTSTEP);
   
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
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol()) continue;
      
      // Data
      int type = OrderType();
      double openPrice = OrderOpenPrice();
      double currentSL = OrderStopLoss();
      double currentPrice = (type == OP_BUY) ? Bid : Ask;
      double point = Point;
      
      //--- BREAK EVEN ---
      if(UseBreakEven)
      {
         if(type == OP_BUY)
         {
            if(currentPrice - openPrice > BreakEvenTrigger * point)
            {
               double newSL = openPrice + BreakEvenLock * point;
               if(newSL > currentSL && (currentSL == 0 || newSL > currentSL))
               {
                  if(!OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE))
                     Print("Failed to move SL to BE: ", GetLastError());
               }
            }
         }
         else if(type == OP_SELL)
         {
            if(openPrice - currentPrice > BreakEvenTrigger * point)
            {
               double newSL = openPrice - BreakEvenLock * point;
               if(newSL < currentSL || currentSL == 0)
               {
                  if(!OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE))
                     Print("Failed to move SL to BE: ", GetLastError());
               }
            }
         }
      }
      
      //--- TRAILING STOP ---
      if(UseTrailingStop)
      {
         if(type == OP_BUY)
         {
            if(currentPrice - openPrice > TrailingStop * point)
            {
               double newSL = currentPrice - TrailingStop * point;
               if(newSL > currentSL + TrailingStep * point)
               {
                  if(!OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE))
                     Print("Failed to move Trailing SL: ", GetLastError());
               }
            }
         }
         else if(type == OP_SELL)
         {
            if(openPrice - currentPrice > TrailingStop * point)
            {
               double newSL = currentPrice + TrailingStop * point;
               if(newSL < currentSL - TrailingStep * point || currentSL == 0)
               {
                  if(!OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE))
                     Print("Failed to move Trailing SL: ", GetLastError());
               }
            }
         }
      }
   }
}
