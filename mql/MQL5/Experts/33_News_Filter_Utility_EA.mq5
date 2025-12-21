//+------------------------------------------------------------------+
//|                                    33_News_Filter_Utility_EA.mq5  |
//|                                    My Algo Stack - Trading Infrastructure   |
//+------------------------------------------------------------------+
//| UTILITY: News Filter & Trading Hours Manager                      |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Manages trading based on time and high-impact news events.        |
//| Can close all trades before news, pause trading during news,      |
//| and restrict trading to specific hours.                           |
//|                                                                    |
//| FEATURES:                                                          |
//| - Trading hours filter (e.g., London/NY sessions only)            |
//| - Friday close before weekend                                     |
//| - Monday gap protection                                           |
//| - Manual news time input                                          |
//| - Close all trades before specified time                          |
//|                                                                    |
//| HOW TO USE:                                                        |
//| 1. Set your preferred trading hours                               |
//| 2. Input known news times manually                                |
//| 3. EA will manage other EAs' trades accordingly                   |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

//=============================================================================
// LICENSE CONFIGURATION - DO NOT MODIFY
//=============================================================================
#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "news_filter_utility_ea"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200  // Check every 12 hours (in seconds)
#define LICENSE_GRACE_PERIOD 86400    // 24 hours grace if server unreachable

//=============================================================================
// USER INPUT PARAMETERS
//=============================================================================
input string   LicenseKey = "";          // License Key (from dashboard)
input bool     EnableTradingHours = true;
input int      TradingStartHour = 8;     // Start hour (server time)
input int      TradingEndHour = 20;      // End hour (server time)
input bool     EnableFridayClose = true;
input int      FridayCloseHour = 20;     // Close all on Friday at this hour
input bool     EnableMondayDelay = true;
input int      MondayStartHour = 2;      // Start trading Monday at this hour
input bool     EnableNewsFilter = true;
input string   NewsTime1 = "";           // News time 1 (HH:MM format)
input string   NewsTime2 = "";           // News time 2 (HH:MM format)
input string   NewsTime3 = "";           // News time 3 (HH:MM format)
input int      NewsBufferMinutes = 30;   // Minutes before/after news to avoid
input bool     CloseBeforeNews = false;  // Close positions before news
input int      MagicFilter = 0;          // 0 = manage all trades

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

bool g_tradingAllowed = true;

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
   
   Print("News Filter Utility EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "NF_");
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
   
   g_tradingAllowed = CheckTradingAllowed();
   UpdateDisplay();
   
   // Close trades if needed
   if(!g_tradingAllowed && CloseBeforeNews)
   {
      CloseAllTrades();
   }
}

bool CheckTradingAllowed()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   
   // Friday close
   if(EnableFridayClose && dt.day_of_week == 5 && dt.hour >= FridayCloseHour)
   {
      return false;
   }
   
   // Weekend
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
   {
      return false;
   }
   
   // Monday delay
   if(EnableMondayDelay && dt.day_of_week == 1 && dt.hour < MondayStartHour)
   {
      return false;
   }
   
   // Trading hours
   if(EnableTradingHours)
   {
      if(dt.hour < TradingStartHour || dt.hour >= TradingEndHour)
      {
         return false;
      }
   }
   
   // News filter
   if(EnableNewsFilter)
   {
      if(IsNearNewsTime(NewsTime1) || IsNearNewsTime(NewsTime2) || IsNearNewsTime(NewsTime3))
      {
         return false;
      }
   }
   
   return true;
}

bool IsNearNewsTime(string newsTime)
{
   if(StringLen(newsTime) < 5) return false;
   
   string parts[];
   if(StringSplit(newsTime, ':', parts) != 2) return false;
   
   int newsHour = (int)StringToInteger(parts[0]);
   int newsMin = (int)StringToInteger(parts[1]);
   
   MqlDateTime dt;
   TimeCurrent(dt);
   
   int currentMinutes = dt.hour * 60 + dt.min;
   int newsMinutes = newsHour * 60 + newsMin;
   
   return MathAbs(currentMinutes - newsMinutes) <= NewsBufferMinutes;
}

void CloseAllTrades()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(MagicFilter > 0 && PositionGetInteger(POSITION_MAGIC) != MagicFilter) continue;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {}; ZeroMemory(request); ZeroMemory(result);
      request.action = TRADE_ACTION_DEAL;
      request.position = PositionGetTicket(i);
      request.symbol = _Symbol;
      request.volume = PositionGetDouble(POSITION_VOLUME);
      request.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      request.price = request.type == ORDER_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      request.deviation = 10;
      if(!OrderSend(request, result)) Print("OrderSend failed: ", GetLastError());
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

// Export function for other EAs to check
bool IsTradingAllowed() export
{
   return g_tradingAllowed;
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
      
      if(PositionGetInteger(POSITION_MAGIC) != MagicFilter || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
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
                  MqlTradeResult result = {}; ZeroMemory(request); ZeroMemory(result);
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
                  MqlTradeResult result = {}; ZeroMemory(request); ZeroMemory(result);
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
                  MqlTradeResult result = {}; ZeroMemory(request); ZeroMemory(result);
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
                  MqlTradeResult result = {}; ZeroMemory(request); ZeroMemory(result);
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
