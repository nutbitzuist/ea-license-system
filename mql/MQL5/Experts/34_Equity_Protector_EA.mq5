//+------------------------------------------------------------------+
//|                                       34_Equity_Protector_EA.mq5  |
//|                                    My Algo Stack - Trading Infrastructure   |
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
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

//=============================================================================
// LICENSE CONFIGURATION - DO NOT MODIFY
//=============================================================================
#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "equity_protector_ea"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200  // Check every 12 hours (in seconds)
#define LICENSE_GRACE_PERIOD 86400    // 24 hours grace if server unreachable

//=============================================================================
// USER INPUT PARAMETERS
//=============================================================================
input string   LicenseKey = "";          // License Key (from dashboard)
input double   MaxDrawdownPercent = 10;  // Max drawdown % from peak
input double   MaxDrawdownDollars = 0;   // Max drawdown $ (0 = disabled)
input double   DailyLossLimit = 0;       // Daily loss limit $ (0 = disabled)
input double   DailyProfitTarget = 0;    // Daily profit target $ (0 = disabled)
input bool     EnableTrailingEquity = true;
input double   TrailingEquityPercent = 5; // Trail equity by this %
input bool     EnableAlerts = true;
input bool     CloseAllOnLimit = true;
input bool     RemoveEAOnLimit = false;

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

double g_peakEquity = 0;
double g_dailyStartBalance = 0;
datetime g_lastDay = 0;
double g_trailingEquityLevel = 0;

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
   
   g_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_trailingEquityLevel = g_peakEquity * (1 - TrailingEquityPercent / 100);
   
   Print("Equity Protector EA initialized");
   Print("Peak Equity: $", g_peakEquity);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "EP_");
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
