//+------------------------------------------------------------------+
//|                                         40_Trade_Journal_EA.mq4   |
//|                                    My Algo Stack - Trading Infrastructure   |
//+------------------------------------------------------------------+
//| UTILITY: Automatic Trade Journal & Statistics                     |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "trade_journal_ea"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200
#define LICENSE_GRACE_PERIOD 86400

input string   LicenseKey = "";
input string   JournalFileName = "trade_journal.csv";
input bool     ShowStats = true;

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

int g_totalTrades = 0; int g_winningTrades = 0; int g_losingTrades = 0; double g_grossProfit = 0; double g_grossLoss = 0; double g_maxDrawdown = 0; double g_peakBalance = 0; int g_lastHistoryTotal = 0;

int OnInit()
{
   if(!ValidateLicense()) { Print("LICENSE ERROR: ", g_licenseError); Alert("License Error: ", g_licenseError); return INIT_FAILED; }
   g_peakBalance = AccountBalance();
   if(!FileIsExist(JournalFileName, FILE_COMMON)) { int handle = FileOpen(JournalFileName, FILE_WRITE|FILE_CSV|FILE_COMMON); if(handle != INVALID_HANDLE) { FileWrite(handle, "Ticket", "Symbol", "Type", "Lots", "OpenTime", "OpenPrice", "CloseTime", "ClosePrice", "Profit", "Pips", "Duration(min)"); FileClose(handle); } }
   LoadStats();
   Print("Trade Journal EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { ObjectsDeleteAll(0, "TJ_"); }

void OnTick()
{
   // Manage open positions (Trailing Stop & BreakEven)
   ManagePositions();
   if(!PeriodicLicenseCheck()) { ExpertRemove(); return; }
   CheckNewClosedTrades(); UpdateDrawdown();
   if(ShowStats) UpdateStatsDisplay();
}

void CheckNewClosedTrades() { int historyTotal = OrdersHistoryTotal(); if(historyTotal > g_lastHistoryTotal) { for(int i = g_lastHistoryTotal; i < historyTotal; i++) { if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue; if(OrderType() > OP_SELL) continue; LogTrade(); UpdateStats(); } } g_lastHistoryTotal = historyTotal; }
void LogTrade() { int digits = (int)MarketInfo(OrderSymbol(), MODE_DIGITS); double pipMultiplier = (digits == 3 || digits == 5) ? 10 : 1; double pips = (OrderType() == OP_BUY) ? (OrderClosePrice() - OrderOpenPrice()) / Point / pipMultiplier : (OrderOpenPrice() - OrderClosePrice()) / Point / pipMultiplier; int duration = (int)((OrderCloseTime() - OrderOpenTime()) / 60); int handle = FileOpen(JournalFileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON); if(handle != INVALID_HANDLE) { FileSeek(handle, 0, SEEK_END); FileWrite(handle, IntegerToString(OrderTicket()), OrderSymbol(), (OrderType() == OP_BUY ? "BUY" : "SELL"), DoubleToString(OrderLots(), 2), TimeToString(OrderOpenTime()), DoubleToString(OrderOpenPrice(), digits), TimeToString(OrderCloseTime()), DoubleToString(OrderClosePrice(), digits), DoubleToString(OrderProfit(), 2), DoubleToString(pips, 1), IntegerToString(duration)); FileClose(handle); } }
void UpdateStats() { double profit = OrderProfit() + OrderSwap() + OrderCommission(); g_totalTrades++; if(profit > 0) { g_winningTrades++; g_grossProfit += profit; } else { g_losingTrades++; g_grossLoss += MathAbs(profit); } }
void UpdateDrawdown() { double balance = AccountBalance(); if(balance > g_peakBalance) g_peakBalance = balance; double drawdown = g_peakBalance - balance; if(drawdown > g_maxDrawdown) g_maxDrawdown = drawdown; }
void LoadStats() { g_lastHistoryTotal = OrdersHistoryTotal(); for(int i = 0; i < g_lastHistoryTotal; i++) { if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue; if(OrderType() > OP_SELL) continue; double profit = OrderProfit() + OrderSwap() + OrderCommission(); g_totalTrades++; if(profit > 0) { g_winningTrades++; g_grossProfit += profit; } else { g_losingTrades++; g_grossLoss += MathAbs(profit); } } }
void UpdateStatsDisplay() { double winRate = g_totalTrades > 0 ? (double)g_winningTrades / g_totalTrades * 100 : 0; double profitFactor = g_grossLoss > 0 ? g_grossProfit / g_grossLoss : 0; double avgWin = g_winningTrades > 0 ? g_grossProfit / g_winningTrades : 0; double avgLoss = g_losingTrades > 0 ? g_grossLoss / g_losingTrades : 0; double netPL = g_grossProfit - g_grossLoss; int y = 20; CreateOrUpdateLabel("TJ_Title", 20, y, "=== TRADE JOURNAL ===", clrGold); y += 20; CreateOrUpdateLabel("TJ_Total", 20, y, "Total: " + IntegerToString(g_totalTrades), clrWhite); y += 15; CreateOrUpdateLabel("TJ_WinLoss", 20, y, "W/L: " + IntegerToString(g_winningTrades) + "/" + IntegerToString(g_losingTrades), clrWhite); y += 15; CreateOrUpdateLabel("TJ_WinRate", 20, y, "Win Rate: " + DoubleToString(winRate, 1) + "%", winRate >= 50 ? clrLime : clrRed); y += 15; CreateOrUpdateLabel("TJ_PF", 20, y, "PF: " + DoubleToString(profitFactor, 2), profitFactor >= 1 ? clrLime : clrRed); y += 15; CreateOrUpdateLabel("TJ_AvgWin", 20, y, "Avg Win: $" + DoubleToString(avgWin, 2), clrLime); y += 15; CreateOrUpdateLabel("TJ_AvgLoss", 20, y, "Avg Loss: $" + DoubleToString(avgLoss, 2), clrRed); y += 15; CreateOrUpdateLabel("TJ_NetPL", 20, y, "Net P/L: $" + DoubleToString(netPL, 2), netPL >= 0 ? clrLime : clrRed); }
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
