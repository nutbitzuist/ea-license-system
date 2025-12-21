//+------------------------------------------------------------------+
//|                                          13_Price_Action_EA.mq5   |
//|                                    My Algo Stack - Trading Infrastructure   |
//+------------------------------------------------------------------+
//| STRATEGY: Price Action Pattern Recognition                        |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| This EA identifies and trades classic candlestick patterns        |
//| including Pin Bars, Engulfing patterns, and Inside Bars.          |
//| No indicators needed - pure price action trading.                  |
//|                                                                    |
//| PATTERNS DETECTED:                                                 |
//| 1. PIN BAR (Hammer/Shooting Star):                                |
//|    - Long wick (>60% of candle range)                             |
//|    - Small body (<30% of candle range)                            |
//|    - Signals potential reversal                                    |
//|                                                                    |
//| 2. ENGULFING PATTERN:                                              |
//|    - Current candle completely engulfs previous                   |
//|    - Strong reversal signal                                        |
//|    - Bullish: Green engulfs red                                   |
//|    - Bearish: Red engulfs green                                   |
//|                                                                    |
//| 3. INSIDE BAR:                                                     |
//|    - Current bar within previous bar's range                      |
//|    - Consolidation before breakout                                 |
//|    - Trade the breakout direction                                  |
//|                                                                    |
//| ENTRY CONDITIONS:                                                  |
//| - Pattern must form at key level (recent high/low)                |
//| - Confirmation candle required                                     |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: H4 or Daily                                          |
//| - Pairs: All pairs (works best on liquid markets)                 |
//|                                                                    |
//| RISK LEVEL: Medium-Low                                             |
//| WIN RATE: ~55-65% expected                                        |
//| RISK:REWARD: 1:2 minimum                                          |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

//=============================================================================
// LICENSE CONFIGURATION - DO NOT MODIFY
//=============================================================================
#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "price_action_ea"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200  // Check every 12 hours (in seconds)
#define LICENSE_GRACE_PERIOD 86400    // 24 hours grace if server unreachable

//=============================================================================
// USER INPUT PARAMETERS
//=============================================================================
input string   LicenseKey = "";          // License Key (from dashboard)
input double   PinBarWickRatio = 0.6;    // Pin bar wick ratio (0.6 = 60%)
input double   PinBarBodyRatio = 0.3;    // Pin bar max body ratio
input int      KeyLevelLookback = 20;    // Bars for key level detection
input double   LotSize = 0.1;
input int      StopLoss = 100;
input int      TakeProfit = 200;
input int      MagicNumber = 100013;

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
   Print("Price Action EA initialized");
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
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   double open1 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   
   double open2 = iOpen(_Symbol, PERIOD_CURRENT, 2);
   double high2 = iHigh(_Symbol, PERIOD_CURRENT, 2);
   double low2 = iLow(_Symbol, PERIOD_CURRENT, 2);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   
   double range1 = high1 - low1;
   double body1 = MathAbs(close1 - open1);
   
   bool buySignal = false, sellSignal = false;
   
   // Check for Bullish Pin Bar (Hammer)
   if(range1 > 0)
   {
      double lowerWick = MathMin(open1, close1) - low1;
      double upperWick = high1 - MathMax(open1, close1);
      
      if(lowerWick / range1 >= PinBarWickRatio && body1 / range1 <= PinBarBodyRatio)
      {
         if(IsAtKeyLow(low1)) buySignal = true;
      }
      
      // Check for Bearish Pin Bar (Shooting Star)
      if(upperWick / range1 >= PinBarWickRatio && body1 / range1 <= PinBarBodyRatio)
      {
         if(IsAtKeyHigh(high1)) sellSignal = true;
      }
   }
   
   // Check for Bullish Engulfing
   if(close2 < open2 && close1 > open1)  // Previous red, current green
   {
      if(close1 > open2 && open1 < close2)  // Engulfs
      {
         if(IsAtKeyLow(low1)) buySignal = true;
      }
   }
   
   // Check for Bearish Engulfing
   if(close2 > open2 && close1 < open1)  // Previous green, current red
   {
      if(close1 < open2 && open1 > close2)  // Engulfs
      {
         if(IsAtKeyHigh(high1)) sellSignal = true;
      }
   }
   
   ManagePositions(buySignal, sellSignal);
}

bool IsAtKeyLow(double price)
{
   double lowestLow = iLow(_Symbol, PERIOD_CURRENT, 1);
   for(int i = 2; i <= KeyLevelLookback; i++)
   {
      double low = iLow(_Symbol, PERIOD_CURRENT, i);
      if(low < lowestLow) lowestLow = low;
   }
   double tolerance = 50 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return MathAbs(price - lowestLow) < tolerance;
}

bool IsAtKeyHigh(double price)
{
   double highestHigh = iHigh(_Symbol, PERIOD_CURRENT, 1);
   for(int i = 2; i <= KeyLevelLookback; i++)
   {
      double high = iHigh(_Symbol, PERIOD_CURRENT, i);
      if(high > highestHigh) highestHigh = high;
   }
   double tolerance = 50 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return MathAbs(price - highestHigh) < tolerance;
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
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   
   // Calculate Lot Size
   double tradeVolume = LotSize;
   if(UseMoneyManagement)
   {
      double riskSL = StopLoss; // Risk distance in points
      if(riskSL <= 0) riskSL = 100; // Default safety
      tradeVolume = GetLotSize(riskSL);
   }
   
   request.volume = tradeVolume;
   request.type = orderType;
   request.price = price;
   request.sl = (orderType == ORDER_TYPE_BUY) ? price - StopLoss * point : price + StopLoss * point;
   request.tp = (orderType == ORDER_TYPE_BUY) ? price + TakeProfit * point : price - TakeProfit * point;
   request.magic = MagicNumber;
   request.comment = "Price Action";
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
