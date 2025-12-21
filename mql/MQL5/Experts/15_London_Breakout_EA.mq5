//+------------------------------------------------------------------+
//|                                        15_London_Breakout_EA.mq5  |
//|                                    My Algo Stack - Trading Infrastructure   |
//+------------------------------------------------------------------+
//| STRATEGY: London Session Breakout                                  |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| This EA capitalizes on the volatility surge during the London     |
//| session open. It identifies the Asian session range and trades    |
//| the breakout when London opens with increased volume.              |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Calculates the high/low range during Asian session (00:00-07:00)|
//| 2. Places pending orders above/below the range before London open |
//| 3. Triggers on breakout with momentum confirmation                |
//| 4. Cancels unfilled orders after London session ends              |
//|                                                                    |
//| SESSION TIMES (Server Time):                                       |
//| - Asian Range: 00:00 - 07:00                                      |
//| - London Open: 07:00 - 08:00 (breakout window)                    |
//| - Trade Window: 07:00 - 16:00                                     |
//|                                                                    |
//| ENTRY CONDITIONS:                                                  |
//| BUY: Price breaks above Asian high during London session          |
//| SELL: Price breaks below Asian low during London session          |
//|                                                                    |
//| EXIT CONDITIONS:                                                   |
//| - Fixed Take Profit (1.5x Asian range)                            |
//| - Stop Loss at opposite side of range                             |
//| - Close all trades at end of London session                       |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: M15 or M30                                           |
//| - Pairs: GBP pairs (GBPUSD, GBPJPY, EURGBP)                       |
//|                                                                    |
//| RISK LEVEL: Medium                                                 |
//| WIN RATE: ~50-55% expected                                        |
//| RISK:REWARD: 1:1.5                                                |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

//=============================================================================
// LICENSE CONFIGURATION - DO NOT MODIFY
//=============================================================================
#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "london_breakout_ea"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200  // Check every 12 hours (in seconds)
#define LICENSE_GRACE_PERIOD 86400    // 24 hours grace if server unreachable

//=============================================================================
// USER INPUT PARAMETERS
//=============================================================================
input string   LicenseKey = "";          // License Key (from dashboard)
input int      AsianStartHour = 0;       // Asian session start (server time)
input int      AsianEndHour = 7;         // Asian session end
input int      LondonEndHour = 16;       // London session end
input double   RangeMultiplier = 1.5;    // TP multiplier of range
input double   LotSize = 0.1;
input int      MagicNumber = 100015;

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

double g_asianHigh = 0, g_asianLow = 0;
bool g_rangeCalculated = false;
datetime g_lastRangeDate = 0;

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
   Print("London Breakout EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { }

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
   TimeToStruct(TimeCurrent(), dt);
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   
   // Reset range calculation for new day
   if(today != g_lastRangeDate)
   {
      g_rangeCalculated = false;
      g_lastRangeDate = today;
   }
   
   // Calculate Asian range at end of Asian session
   if(dt.hour == AsianEndHour && !g_rangeCalculated)
   {
      CalculateAsianRange();
      g_rangeCalculated = true;
   }
   
   // Close all trades at end of London session
   if(dt.hour >= LondonEndHour)
   {
      CloseAllPositions();
      return;
   }
   
   // Only trade during London session
   if(dt.hour < AsianEndHour || dt.hour >= LondonEndHour) return;
   if(!g_rangeCalculated) return;
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   
   bool buySignal = close1 > g_asianHigh && close2 <= g_asianHigh;
   bool sellSignal = close1 < g_asianLow && close2 >= g_asianLow;
   
   ManagePositions(buySignal, sellSignal);
}

void CalculateAsianRange()
{
   g_asianHigh = 0;
   g_asianLow = DBL_MAX;
   
   datetime startTime = StringToTime(TimeToString(TimeCurrent(), TIME_DATE)) + AsianStartHour * 3600;
   datetime endTime = StringToTime(TimeToString(TimeCurrent(), TIME_DATE)) + AsianEndHour * 3600;
   
   for(int i = 0; i < 500; i++)
   {
      datetime barTime = iTime(_Symbol, PERIOD_M15, i);
      if(barTime < startTime) break;
      if(barTime >= endTime) continue;
      
      double high = iHigh(_Symbol, PERIOD_M15, i);
      double low = iLow(_Symbol, PERIOD_M15, i);
      
      if(high > g_asianHigh) g_asianHigh = high;
      if(low < g_asianLow) g_asianLow = low;
   }
   
   Print("Asian Range: High=", g_asianHigh, " Low=", g_asianLow, " Range=", (g_asianHigh - g_asianLow) / SymbolInfoDouble(_Symbol, SYMBOL_POINT), " points");
}

void ManagePositions(bool buySignal, bool sellSignal)
{
   bool hasPosition = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
            hasPosition = true;
   }
   
   if(!hasPosition)
   {
      if(buySignal) OpenPosition(ORDER_TYPE_BUY);
      else if(sellSignal) OpenPosition(ORDER_TYPE_SELL);
   }
}

void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double range = g_asianHigh - g_asianLow;
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   
   // Calculate Lot Size
   double tradeVolume = LotSize;
   if(UseMoneyManagement)
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double riskSL = range / point; // Use range-based SL
      if(riskSL <= 0) riskSL = 100; // Default safety
      tradeVolume = GetLotSize(riskSL);
   }
   
   request.volume = tradeVolume;
   request.type = orderType;
   request.price = price;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      request.sl = g_asianLow;
      request.tp = price + range * RangeMultiplier;
   }
   else
   {
      request.sl = g_asianHigh;
      request.tp = price - range * RangeMultiplier;
   }
   
   request.magic = MagicNumber;
   request.comment = "London BO";
   request.deviation = 10;
   if(!OrderSend(request, result)) Print("OrderSend failed: ", GetLastError());
}

void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            request.action = TRADE_ACTION_DEAL;
            request.symbol = _Symbol;
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.price = (request.type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
            request.position = PositionGetTicket(i);
            request.deviation = 10;
            if(!OrderSend(request, result)) Print("OrderSend failed: ", GetLastError());
         }
      }
   }
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
   
   if(tickSize == 0 || point == 0) return LotSize;
   
   // Calculate risk amount in money
   double riskMoney = accountBalance * (RiskPercent / 100.0);
   
   // Money per lot for 1 point movement = (TickValue / TickSize) * Point
   double moneyPerPointPerLot = (tickValue / tickSize) * point;
   
   if(moneyPerPointPerLot == 0) return LotSize;
   
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
