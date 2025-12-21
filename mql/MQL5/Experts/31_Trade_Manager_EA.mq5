//+------------------------------------------------------------------+
//|                                          31_Trade_Manager_EA.mq5  |
//|                                    My Algo Stack - Trading Infrastructure   |
//+------------------------------------------------------------------+
//| UTILITY: Trade Manager                                             |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Comprehensive trade management tool that helps manage open        |
//| positions with advanced features like trailing stops, break-even, |
//| partial closes, and time-based exits.                             |
//|                                                                    |
//| FEATURES:                                                          |
//| - Auto trailing stop (ATR-based or fixed)                         |
//| - Break-even after X pips profit                                  |
//| - Partial close at profit targets                                 |
//| - Time-based trade closure                                        |
//| - Works with any manually opened trades                           |
//|                                                                    |
//| HOW TO USE:                                                        |
//| 1. Attach to any chart                                            |
//| 2. Open trades manually or with other EAs                         |
//| 3. This EA will manage all trades on the symbol                   |
//|                                                                    |
//| RECOMMENDED FOR:                                                   |
//| - Manual traders who want automated management                    |
//| - Combining with signal-only EAs                                  |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

//=============================================================================
// LICENSE CONFIGURATION - DO NOT MODIFY
//=============================================================================
#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "trade_manager_ea"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200  // Check every 12 hours (in seconds)
#define LICENSE_GRACE_PERIOD 86400    // 24 hours grace if server unreachable

//=============================================================================
// USER INPUT PARAMETERS
//=============================================================================
input string   LicenseKey = "";          // License Key (from dashboard)
input bool     EnableTrailing = true;
input bool     UseATRTrailing = true;
input int      ATR_Period = 14;
input double   ATR_Multiplier = 2.0;
input int      FixedTrailingPips = 30;
input bool     EnableBreakEven = true;
input int      BreakEvenTriggerPips = 20;
input int      BreakEvenPlusPips = 5;
input bool     EnablePartialClose = true;
input int      PartialCloseTriggerPips = 50;
input double   PartialClosePercent = 50;
input bool     EnableTimeClose = false;
input int      MaxTradeHours = 24;
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

int g_atr_handle;
double g_atr[];

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
   
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   ArraySetAsSeries(g_atr, true);
   
   Print("Trade Manager EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
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
   
   if(CopyBuffer(g_atr_handle, 0, 0, 1, g_atr) < 1) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(MagicFilter > 0 && PositionGetInteger(POSITION_MAGIC) != MagicFilter) continue;
      
      ulong ticket = PositionGetTicket(i);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double volume = PositionGetDouble(POSITION_VOLUME);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      bool isBuy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double profitPips = isBuy ? (currentPrice - openPrice) / point : (openPrice - currentPrice) / point;
      
      // Time-based close
      if(EnableTimeClose && MaxTradeHours > 0)
      {
         if(TimeCurrent() - openTime >= MaxTradeHours * 3600)
         {
            ClosePosition(ticket);
            continue;
         }
      }
      
      // Partial close
      if(EnablePartialClose && profitPips >= PartialCloseTriggerPips && volume > 0.01)
      {
         double closeVolume = NormalizeDouble(volume * PartialClosePercent / 100, 2);
         if(closeVolume >= 0.01)
         {
            PartialClosePosition(ticket, closeVolume);
         }
      }
      
      // Break-even
      if(EnableBreakEven && profitPips >= BreakEvenTriggerPips)
      {
         double beLevel = isBuy ? openPrice + BreakEvenPlusPips * point : openPrice - BreakEvenPlusPips * point;
         if((isBuy && currentSL < beLevel) || (!isBuy && (currentSL > beLevel || currentSL == 0)))
         {
            ModifySL(ticket, beLevel);
         }
      }
      
      // Trailing stop
      if(EnableTrailing && profitPips > 0)
      {
         double trailDistance = UseATRTrailing ? g_atr[0] * ATR_Multiplier : FixedTrailingPips * point;
         double newSL = isBuy ? currentPrice - trailDistance : currentPrice + trailDistance;
         
         if(isBuy && newSL > currentSL && newSL > openPrice)
            ModifySL(ticket, newSL);
         else if(!isBuy && (currentSL == 0 || newSL < currentSL) && newSL < openPrice)
            ModifySL(ticket, newSL);
      }
   }
}

void ModifySL(ulong ticket, double newSL)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.sl = NormalizeDouble(newSL, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
   request.tp = PositionGetDouble(POSITION_TP);
   if(!OrderSend(request, result)) Print("OrderSend failed: ", GetLastError());
}

void ClosePosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = _Symbol;
   request.volume = PositionGetDouble(POSITION_VOLUME);
   request.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = request.type == ORDER_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   request.deviation = 10;
   if(!OrderSend(request, result)) Print("OrderSend failed: ", GetLastError());
}

void PartialClosePosition(ulong ticket, double volume)
{
   if(!PositionSelectByTicket(ticket)) return;
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = _Symbol;
   request.volume = volume;
   request.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = request.type == ORDER_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   request.deviation = 10;
   if(!OrderSend(request, result)) Print("OrderSend failed: ", GetLastError());
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
