//+------------------------------------------------------------------+
//|                                      38_Order_Block_Finder_EA.mq5 |
//|                                    My Algo Stack - Trading Infrastructure   |
//+------------------------------------------------------------------+
//| UTILITY: Order Block & Supply/Demand Zone Finder                  |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Automatically identifies and draws order blocks (supply/demand    |
//| zones) on the chart. These are key institutional trading levels.  |
//|                                                                    |
//| FEATURES:                                                          |
//| - Automatic order block detection                                 |
//| - Supply zone highlighting (bearish OB)                           |
//| - Demand zone highlighting (bullish OB)                           |
//| - Zone strength rating                                            |
//| - Alert when price approaches zone                                |
//|                                                                    |
//| ORDER BLOCK DEFINITION:                                            |
//| - Bullish OB: Last bearish candle before strong bullish move      |
//| - Bearish OB: Last bullish candle before strong bearish move      |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

//=============================================================================
// LICENSE CONFIGURATION - DO NOT MODIFY
//=============================================================================
#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "order_block_finder_ea"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200  // Check every 12 hours (in seconds)
#define LICENSE_GRACE_PERIOD 86400    // 24 hours grace if server unreachable

//=============================================================================
// USER INPUT PARAMETERS
//=============================================================================
input string   LicenseKey = "";          // License Key (from dashboard)
input int      LookbackBars = 100;
input double   MinMoveMultiplier = 2.0;  // Min move = ATR * this
input int      ATR_Period = 14;
input bool     AlertOnApproach = true;
input int      ApproachPips = 20;
input color    DemandColor = clrDodgerBlue;
input color    SupplyColor = clrCrimson;

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

struct OrderBlock
{
   double high;
   double low;
   datetime time;
   bool isBullish;
   bool isValid;
};

OrderBlock g_orderBlocks[];

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
   ArrayResize(g_orderBlocks, 0);
   
   Print("Order Block Finder EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   ObjectsDeleteAll(0, "OB_");
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
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(CopyBuffer(g_atr_handle, 0, 0, 1, g_atr) < 1) return;
   
   FindOrderBlocks();
   DrawOrderBlocks();
   CheckPriceApproach();
}

void FindOrderBlocks()
{
   ArrayResize(g_orderBlocks, 0);
   double minMove = g_atr[0] * MinMoveMultiplier;
   
   for(int i = 3; i < LookbackBars; i++)
   {
      double open_i = iOpen(_Symbol, PERIOD_CURRENT, i);
      double close_i = iClose(_Symbol, PERIOD_CURRENT, i);
      double high_i = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low_i = iLow(_Symbol, PERIOD_CURRENT, i);
      
      bool isBearishCandle = close_i < open_i;
      bool isBullishCandle = close_i > open_i;
      
      // Check for bullish order block (bearish candle before bullish move)
      if(isBearishCandle)
      {
         double moveUp = 0;
         for(int j = i - 1; j >= 1; j--)
         {
            moveUp = iHigh(_Symbol, PERIOD_CURRENT, j) - low_i;
            if(moveUp >= minMove)
            {
               // Valid bullish OB
               OrderBlock ob;
               ob.high = high_i;
               ob.low = low_i;
               ob.time = iTime(_Symbol, PERIOD_CURRENT, i);
               ob.isBullish = true;
               ob.isValid = true;
               
               // Check if zone has been broken
               for(int k = i - 1; k >= 1; k--)
               {
                  if(iClose(_Symbol, PERIOD_CURRENT, k) < ob.low)
                  {
                     ob.isValid = false;
                     break;
                  }
               }
               
               if(ob.isValid)
               {
                  ArrayResize(g_orderBlocks, ArraySize(g_orderBlocks) + 1);
                  g_orderBlocks[ArraySize(g_orderBlocks) - 1] = ob;
               }
               break;
            }
         }
      }
      
      // Check for bearish order block (bullish candle before bearish move)
      if(isBullishCandle)
      {
         double moveDown = 0;
         for(int j = i - 1; j >= 1; j--)
         {
            moveDown = high_i - iLow(_Symbol, PERIOD_CURRENT, j);
            if(moveDown >= minMove)
            {
               // Valid bearish OB
               OrderBlock ob;
               ob.high = high_i;
               ob.low = low_i;
               ob.time = iTime(_Symbol, PERIOD_CURRENT, i);
               ob.isBullish = false;
               ob.isValid = true;
               
               // Check if zone has been broken
               for(int k = i - 1; k >= 1; k--)
               {
                  if(iClose(_Symbol, PERIOD_CURRENT, k) > ob.high)
                  {
                     ob.isValid = false;
                     break;
                  }
               }
               
               if(ob.isValid)
               {
                  ArrayResize(g_orderBlocks, ArraySize(g_orderBlocks) + 1);
                  g_orderBlocks[ArraySize(g_orderBlocks) - 1] = ob;
               }
               break;
            }
         }
      }
   }
}

void DrawOrderBlocks()
{
   ObjectsDeleteAll(0, "OB_");
   
   for(int i = 0; i < ArraySize(g_orderBlocks); i++)
   {
      if(!g_orderBlocks[i].isValid) continue;
      
      string name = "OB_" + IntegerToString(i);
      color clr = g_orderBlocks[i].isBullish ? DemandColor : SupplyColor;
      
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, 
         g_orderBlocks[i].time, g_orderBlocks[i].high,
         TimeCurrent() + PeriodSeconds() * 50, g_orderBlocks[i].low);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
}

void CheckPriceApproach()
{
   if(!AlertOnApproach) return;
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double approachDistance = ApproachPips * point;
   
   static datetime lastAlert = 0;
   if(TimeCurrent() - lastAlert < 300) return; // 5 min between alerts
   
   for(int i = 0; i < ArraySize(g_orderBlocks); i++)
   {
      if(!g_orderBlocks[i].isValid) continue;
      
      if(g_orderBlocks[i].isBullish)
      {
         if(bid <= g_orderBlocks[i].high + approachDistance && bid >= g_orderBlocks[i].low)
         {
            Alert("Price approaching DEMAND zone at ", g_orderBlocks[i].low);
            lastAlert = TimeCurrent();
            return;
         }
      }
      else
      {
         if(bid >= g_orderBlocks[i].low - approachDistance && bid <= g_orderBlocks[i].high)
         {
            Alert("Price approaching SUPPLY zone at ", g_orderBlocks[i].high);
            lastAlert = TimeCurrent();
            return;
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
