//+------------------------------------------------------------------+
//|                                   29_Oscar_Grind_Martingale_EA.mq5|
//|                                    My Algo Stack - Trading Infrastructure   |
//+------------------------------------------------------------------+
//| STRATEGY: Oscar's Grind Martingale                                 |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| A conservative progression system that aims for 1 unit profit     |
//| per cycle. Increases bet by 1 unit after a win, keeps same bet    |
//| after a loss. Resets when 1 unit profit is achieved.              |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Start with 1 unit bet                                          |
//| 2. After loss: Keep same bet                                      |
//| 3. After win: Increase bet by 1 unit                              |
//| 4. Goal: Achieve +1 unit profit, then reset                       |
//| 5. Never bet more than needed to reach +1 profit                  |
//|                                                                    |
//| OSCAR'S GRIND EXAMPLE:                                             |
//| Bet 1: Lose (-1)                                                   |
//| Bet 1: Lose (-2)                                                   |
//| Bet 1: Win (-1)                                                    |
//| Bet 2: Lose (-3)                                                   |
//| Bet 2: Win (-1)                                                    |
//| Bet 2: Win (+1) → Reset!                                          |
//|                                                                    |
//| ADVANTAGES:                                                        |
//| - Very conservative progression                                    |
//| - Clear profit target per cycle                                   |
//| - Lower variance than other systems                               |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: H1-H4                                                |
//| - Pairs: Any                                                      |
//| - Account: Minimum $2,000 recommended                             |
//|                                                                    |
//| RISK LEVEL: MEDIUM                                                 |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

//=============================================================================
// LICENSE CONFIGURATION - DO NOT MODIFY
//=============================================================================
#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "oscar_grind_martingale_ea"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200  // Check every 12 hours (in seconds)
#define LICENSE_GRACE_PERIOD 86400    // 24 hours grace if server unreachable

//=============================================================================
// USER INPUT PARAMETERS
//=============================================================================
input string   LicenseKey = "";          // License Key (from dashboard)
input double   UnitLot = 0.01;           // 1 unit = this lot size
input int      MaxUnits = 10;            // Maximum units per bet
input int      TakeProfit = 100;
input int      StopLoss = 100;
input int      MACD_Fast = 12;
input int      MACD_Slow = 26;
input int      MACD_Signal = 9;
input int      MagicNumber = 100029;

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

int g_currentUnits = 1;
double g_cycleProfit = 0;
int g_macd_handle;
double g_macdMain[], g_macdSignal[];

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
   
   g_macd_handle = iMACD(_Symbol, PERIOD_CURRENT, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
   ArraySetAsSeries(g_macdMain, true);
   ArraySetAsSeries(g_macdSignal, true);
   
   Print("Oscar's Grind Martingale EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_macd_handle != INVALID_HANDLE) IndicatorRelease(g_macd_handle);
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
   
   if(CopyBuffer(g_macd_handle, 0, 0, 3, g_macdMain) < 3) return;
   if(CopyBuffer(g_macd_handle, 1, 0, 3, g_macdSignal) < 3) return;
   
   double hist1 = g_macdMain[1] - g_macdSignal[1];
   double hist2 = g_macdMain[2] - g_macdSignal[2];
   
   bool buySignal = hist1 > 0 && hist2 <= 0;
   bool sellSignal = hist1 < 0 && hist2 >= 0;
   
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
            double pipValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
            double unitValue = UnitLot * TakeProfit * pipValue;
            
            if(profit > 0)
            {
               g_cycleProfit += profit;
               
               // Check if cycle complete (1 unit profit)
               if(g_cycleProfit >= unitValue)
               {
                  Print("Oscar's Grind cycle complete! Profit: $", g_cycleProfit);
                  g_currentUnits = 1;
                  g_cycleProfit = 0;
               }
               else
               {
                  // Increase by 1 unit, but don't exceed what's needed
                  double needed = unitValue - g_cycleProfit;
                  int maxNeeded = (int)MathCeil(needed / (UnitLot * TakeProfit * pipValue));
                  g_currentUnits = MathMin(g_currentUnits + 1, MathMin(maxNeeded, MaxUnits));
                  Print("Win - Units: ", g_currentUnits, " Cycle profit: $", g_cycleProfit);
               }
            }
            else
            {
               g_cycleProfit += profit;  // profit is negative
               // Keep same bet after loss
               Print("Loss - Units: ", g_currentUnits, " Cycle profit: $", g_cycleProfit);
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
   double lot = NormalizeDouble(UnitLot * g_currentUnits, 2);
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lot;
   request.type = orderType;
   request.price = price;
   request.sl = (orderType == ORDER_TYPE_BUY) ? price - StopLoss * point : price + StopLoss * point;
   request.tp = (orderType == ORDER_TYPE_BUY) ? price + TakeProfit * point : price - TakeProfit * point;
   request.magic = MagicNumber;
   request.comment = "Oscar " + IntegerToString(g_currentUnits) + "u";
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
   
   if(tickSize == 0 || point == 0) return UnitLot;
   
   // Calculate risk amount in money
   double riskMoney = accountBalance * (RiskPercent / 100.0);
   
   // Money per lot for 1 point movement = (TickValue / TickSize) * Point
   double moneyPerPointPerLot = (tickValue / tickSize) * point;
   
   if(moneyPerPointPerLot == 0) return UnitLot;
   
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
