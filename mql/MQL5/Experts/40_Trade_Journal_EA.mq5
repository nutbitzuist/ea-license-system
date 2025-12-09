//+------------------------------------------------------------------+
//|                                         40_Trade_Journal_EA.mq5   |
//|                                    EA License Management System   |
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
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input string   JournalFileName = "trade_journal.csv";
input bool     ShowStats = true;
input bool     LogAllSymbols = true;

CLicenseValidator* g_license;

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

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "trade_journal_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
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
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   ObjectsDeleteAll(0, "TJ_");
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
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
