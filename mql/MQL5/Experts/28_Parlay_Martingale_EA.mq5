//+------------------------------------------------------------------+
//|                                       28_Parlay_Martingale_EA.mq5 |
//|                                    My Algo Stack - Trading Infrastructure   |
//+------------------------------------------------------------------+
//| STRATEGY: Parlay (Let It Ride) Martingale                         |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Reinvests profits from winning trades into the next trade.        |
//| After a win, the next trade uses original lot + profit.           |
//| After a loss, resets to base lot. Aggressive profit compounding.  |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Start with base lot                                            |
//| 2. Win: Next lot = base + (profit / pip value)                    |
//| 3. Loss: Reset to base lot                                        |
//| 4. Optional: Take profit after X consecutive wins                 |
//|                                                                    |
//| PARLAY PROGRESSION EXAMPLE:                                        |
//| Trade 1: 0.01 lot → Win $10                                       |
//| Trade 2: 0.02 lot (reinvest) → Win $20                            |
//| Trade 3: 0.04 lot (reinvest) → Win $40                            |
//| Trade 4: 0.08 lot (reinvest) → Loss → Reset                       |
//|                                                                    |
//| ADVANTAGES:                                                        |
//| - Profits compound quickly                                        |
//| - Limited risk (only lose base lot)                               |
//| - Great for winning streaks                                        |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: H1-H4                                                |
//| - Pairs: Trending pairs                                           |
//| - Account: Minimum $2,000 recommended                             |
//|                                                                    |
//| RISK LEVEL: HIGH                                                   |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

//=============================================================================
// LICENSE CONFIGURATION - DO NOT MODIFY
//=============================================================================
#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "parlay_martingale_ea"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200  // Check every 12 hours (in seconds)
#define LICENSE_GRACE_PERIOD 86400    // 24 hours grace if server unreachable

//=============================================================================
// USER INPUT PARAMETERS
//=============================================================================
input string   LicenseKey = "";          // License Key (from dashboard)
input double   BaseLot = 0.01;
input int      MaxParlays = 4;           // Max consecutive parlays
input int      TakeProfit = 100;
input int      StopLoss = 100;
input int      ADX_Period = 14;
input int      ADX_Threshold = 25;
input int      MagicNumber = 100028;

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

double g_currentLot;
double g_accumulatedProfit = 0;
int g_parlayCount = 0;
int g_adx_handle;
double g_adx[], g_plusDI[], g_minusDI[];

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
   
   g_currentLot = BaseLot;
   g_adx_handle = iADX(_Symbol, PERIOD_CURRENT, ADX_Period);
   ArraySetAsSeries(g_adx, true);
   ArraySetAsSeries(g_plusDI, true);
   ArraySetAsSeries(g_minusDI, true);
   
   Print("Parlay Martingale EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_adx_handle != INVALID_HANDLE) IndicatorRelease(g_adx_handle);
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
   
   CheckClosedTrades();
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(HasOpenPosition()) return;
   
   // Check max parlays
   if(g_parlayCount >= MaxParlays)
   {
      Print("Max parlays reached! Taking profit and resetting.");
      g_parlayCount = 0;
      g_currentLot = BaseLot;
      g_accumulatedProfit = 0;
   }
   
   if(CopyBuffer(g_adx_handle, 0, 0, 2, g_adx) < 2) return;
   if(CopyBuffer(g_adx_handle, 1, 0, 2, g_plusDI) < 2) return;
   if(CopyBuffer(g_adx_handle, 2, 0, 2, g_minusDI) < 2) return;
   
   if(g_adx[1] < ADX_Threshold) return;  // Only trade in strong trends
   
   bool buySignal = g_plusDI[1] > g_minusDI[1];
   bool sellSignal = g_minusDI[1] > g_plusDI[1];
   
   if(buySignal) OpenPosition(ORDER_TYPE_BUY);
   else if(sellSignal) OpenPosition(ORDER_TYPE_SELL);
}

void CheckClosedTrades()
{
   static int lastDealsTotal = 0;
   HistorySelect(0, TimeCurrent());
   int dealsTotal = HistoryDealsTotal();
   
   if(dealsTotal > lastDealsTotal)
   {
      for(int i = lastDealsTotal; i < dealsTotal; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber &&
            HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            
            if(profit > 0)
            {
               g_accumulatedProfit += profit;
               g_parlayCount++;
               
               // Calculate new lot based on accumulated profit
               double pipValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
               double additionalLots = (g_accumulatedProfit / (TakeProfit * pipValue));
               g_currentLot = NormalizeDouble(BaseLot + additionalLots * 0.01, 2);
               
               Print("Win! Parlay #", g_parlayCount, " - Accumulated: $", g_accumulatedProfit, " Next lot: ", g_currentLot);
            }
            else
            {
               Print("Loss - Resetting parlay");
               g_parlayCount = 0;
               g_currentLot = BaseLot;
               g_accumulatedProfit = 0;
            }
         }
      }
   }
   lastDealsTotal = dealsTotal;
}

bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionSelectByTicket(PositionGetTicket(i)))
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
            return true;
   return false;
}

void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = g_currentLot;
   request.type = orderType;
   request.price = price;
   request.sl = (orderType == ORDER_TYPE_BUY) ? price - StopLoss * point : price + StopLoss * point;
   request.tp = (orderType == ORDER_TYPE_BUY) ? price + TakeProfit * point : price - TakeProfit * point;
   request.magic = MagicNumber;
   request.comment = "Parlay #" + IntegerToString(g_parlayCount + 1);
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
   
   if(tickSize == 0 || point == 0) return BaseLot;
   
   // Calculate risk amount in money
   double riskMoney = accountBalance * (RiskPercent / 100.0);
   
   // Money per lot for 1 point movement = (TickValue / TickSize) * Point
   double moneyPerPointPerLot = (tickValue / tickSize) * point;
   
   if(moneyPerPointPerLot == 0) return BaseLot;
   
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
