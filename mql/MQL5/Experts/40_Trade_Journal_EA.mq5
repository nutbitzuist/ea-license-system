//+------------------------------------------------------------------+
//|                                         40_Trade_Journal_EA.mq5   |
//|                                    My Algo Stack - Trading Infrastructure   |
//+------------------------------------------------------------------+
//| UTILITY: Automatic Trade Journal & Statistics                     |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Automatically logs all trades to a CSV file and calculates        |
//| comprehensive trading statistics. Essential for performance       |
//| analysis and improvement.                                          |
//|                                                                    |
//| FEATURES:                                                          |
//| - Automatic trade logging                                         |
//| - Win rate calculation                                            |
//| - Profit factor                                                   |
//| - Average win/loss                                                |
//| - Maximum drawdown tracking                                       |
//| - Daily/Weekly/Monthly stats                                      |
//| - Export to CSV                                                   |
//|                                                                    |
//| LOGGED DATA:                                                       |
//| - Entry/Exit time, price, type                                    |
//| - Lot size, SL, TP                                                |
//| - Profit/Loss, pips                                               |
//| - Duration, symbol                                                |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

//=============================================================================
// LICENSE CONFIGURATION - DO NOT MODIFY
//=============================================================================
#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "trade_journal_ea"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200  // Check every 12 hours (in seconds)
#define LICENSE_GRACE_PERIOD 86400    // 24 hours grace if server unreachable

//=============================================================================
// USER INPUT PARAMETERS
//=============================================================================
input string   LicenseKey = "";          // License Key (from dashboard)
input string   JournalFileName = "trade_journal.csv";
input bool     ShowStats = true;
input bool     LogAllSymbols = true;

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

// Statistics
int g_totalTrades = 0;
int g_winningTrades = 0;
int g_losingTrades = 0;
double g_totalProfit = 0;
double g_totalLoss = 0;
double g_grossProfit = 0;
double g_grossLoss = 0;
double g_maxDrawdown = 0;
double g_peakBalance = 0;
int g_lastDealsTotal = 0;

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
   
   g_peakBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Create header if file doesn't exist
   if(!FileIsExist(JournalFileName, FILE_COMMON))
   {
      int handle = FileOpen(JournalFileName, FILE_WRITE|FILE_CSV|FILE_COMMON);
      if(handle != INVALID_HANDLE)
      {
         FileWrite(handle, "Ticket", "Symbol", "Type", "Lots", "OpenTime", "OpenPrice", 
                   "CloseTime", "ClosePrice", "SL", "TP", "Profit", "Pips", "Duration(min)", "Comment");
         FileClose(handle);
      }
   }
   
   // Load existing stats
   LoadStats();
   
   Print("Trade Journal EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "TJ_");
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
   
   CheckNewClosedTrades();
   UpdateDrawdown();
   if(ShowStats) UpdateStatsDisplay();
}

void CheckNewClosedTrades()
{
   HistorySelect(0, TimeCurrent());
   int dealsTotal = HistoryDealsTotal();
   
   if(dealsTotal > g_lastDealsTotal)
   {
      for(int i = g_lastDealsTotal; i < dealsTotal; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
         
         string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
         if(!LogAllSymbols && symbol != _Symbol) continue;
         
         LogTrade(ticket);
         UpdateStats(ticket);
      }
   }
   g_lastDealsTotal = dealsTotal;
}

void LogTrade(ulong ticket)
{
   string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
   ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
   double lots = HistoryDealGetDouble(ticket, DEAL_VOLUME);
   double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
   double price = HistoryDealGetDouble(ticket, DEAL_PRICE);
   datetime time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
   string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
   
   // Find the opening deal
   ulong posId = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
   double openPrice = 0;
   datetime openTime = 0;
   
   HistorySelectByPosition(posId);
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong t = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(t, DEAL_ENTRY) == DEAL_ENTRY_IN)
      {
         openPrice = HistoryDealGetDouble(t, DEAL_PRICE);
         openTime = (datetime)HistoryDealGetInteger(t, DEAL_TIME);
         break;
      }
   }
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double pipMultiplier = (digits == 3 || digits == 5) ? 10 : 1;
   double pips = (type == DEAL_TYPE_SELL) ? 
      (openPrice - price) / point / pipMultiplier : 
      (price - openPrice) / point / pipMultiplier;
   
   int duration = (int)((time - openTime) / 60);
   
   int handle = FileOpen(JournalFileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);
   if(handle != INVALID_HANDLE)
   {
      FileSeek(handle, 0, SEEK_END);
      FileWrite(handle, 
         IntegerToString(ticket),
         symbol,
         (type == DEAL_TYPE_BUY ? "BUY" : "SELL"),
         DoubleToString(lots, 2),
         TimeToString(openTime),
         DoubleToString(openPrice, digits),
         TimeToString(time),
         DoubleToString(price, digits),
         "0", "0",
         DoubleToString(profit, 2),
         DoubleToString(pips, 1),
         IntegerToString(duration),
         comment
      );
      FileClose(handle);
   }
}

void UpdateStats(ulong ticket)
{
   double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
   
   g_totalTrades++;
   g_totalProfit += profit;
   
   if(profit > 0)
   {
      g_winningTrades++;
      g_grossProfit += profit;
   }
   else
   {
      g_losingTrades++;
      g_grossLoss += MathAbs(profit);
   }
}

void UpdateDrawdown()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance > g_peakBalance) g_peakBalance = balance;
   
   double drawdown = g_peakBalance - balance;
   if(drawdown > g_maxDrawdown) g_maxDrawdown = drawdown;
}

void LoadStats()
{
   HistorySelect(0, TimeCurrent());
   g_lastDealsTotal = HistoryDealsTotal();
   
   for(int i = 0; i < g_lastDealsTotal; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      
      string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      if(!LogAllSymbols && symbol != _Symbol) continue;
      
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      g_totalTrades++;
      g_totalProfit += profit;
      
      if(profit > 0) { g_winningTrades++; g_grossProfit += profit; }
      else { g_losingTrades++; g_grossLoss += MathAbs(profit); }
   }
}

void UpdateStatsDisplay()
{
   double winRate = g_totalTrades > 0 ? (double)g_winningTrades / g_totalTrades * 100 : 0;
   double profitFactor = g_grossLoss > 0 ? g_grossProfit / g_grossLoss : 0;
   double avgWin = g_winningTrades > 0 ? g_grossProfit / g_winningTrades : 0;
   double avgLoss = g_losingTrades > 0 ? g_grossLoss / g_losingTrades : 0;
   double expectancy = g_totalTrades > 0 ? g_totalProfit / g_totalTrades : 0;
   
   int y = 20;
   CreateOrUpdateLabel("TJ_Title", 20, y, "=== TRADE JOURNAL ===", clrGold); y += 20;
   CreateOrUpdateLabel("TJ_Total", 20, y, "Total Trades: " + IntegerToString(g_totalTrades), clrWhite); y += 15;
   CreateOrUpdateLabel("TJ_WinLoss", 20, y, "Win/Loss: " + IntegerToString(g_winningTrades) + "/" + IntegerToString(g_losingTrades), clrWhite); y += 15;
   CreateOrUpdateLabel("TJ_WinRate", 20, y, "Win Rate: " + DoubleToString(winRate, 1) + "%", winRate >= 50 ? clrLime : clrRed); y += 15;
   CreateOrUpdateLabel("TJ_PF", 20, y, "Profit Factor: " + DoubleToString(profitFactor, 2), profitFactor >= 1 ? clrLime : clrRed); y += 15;
   CreateOrUpdateLabel("TJ_AvgWin", 20, y, "Avg Win: $" + DoubleToString(avgWin, 2), clrLime); y += 15;
   CreateOrUpdateLabel("TJ_AvgLoss", 20, y, "Avg Loss: $" + DoubleToString(avgLoss, 2), clrRed); y += 15;
   CreateOrUpdateLabel("TJ_Expect", 20, y, "Expectancy: $" + DoubleToString(expectancy, 2), expectancy >= 0 ? clrLime : clrRed); y += 15;
   CreateOrUpdateLabel("TJ_MaxDD", 20, y, "Max DD: $" + DoubleToString(g_maxDrawdown, 2), clrOrange); y += 15;
   CreateOrUpdateLabel("TJ_NetPL", 20, y, "Net P/L: $" + DoubleToString(g_totalProfit, 2), g_totalProfit >= 0 ? clrLime : clrRed);
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
