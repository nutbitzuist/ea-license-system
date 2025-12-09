//+------------------------------------------------------------------+
//|                                         40_Trade_Journal_EA.mq4   |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| UTILITY: Automatic Trade Journal & Statistics                     |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input string   JournalFileName = "trade_journal.csv";
input bool     ShowStats = true;

CLicenseValidator* g_license;

int g_totalTrades = 0;
int g_winningTrades = 0;
int g_losingTrades = 0;
double g_grossProfit = 0;
double g_grossLoss = 0;
double g_maxDrawdown = 0;
double g_peakBalance = 0;
int g_lastHistoryTotal = 0;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "trade_journal_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   g_peakBalance = AccountBalance();
   
   if(!FileIsExist(JournalFileName, FILE_COMMON))
   {
      int handle = FileOpen(JournalFileName, FILE_WRITE|FILE_CSV|FILE_COMMON);
      if(handle != INVALID_HANDLE)
      {
         FileWrite(handle, "Ticket", "Symbol", "Type", "Lots", "OpenTime", "OpenPrice", 
                   "CloseTime", "ClosePrice", "Profit", "Pips", "Duration(min)");
         FileClose(handle);
      }
   }
   
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
   int historyTotal = OrdersHistoryTotal();
   
   if(historyTotal > g_lastHistoryTotal)
   {
      for(int i = g_lastHistoryTotal; i < historyTotal; i++)
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
         if(OrderType() > OP_SELL) continue; // Skip pending orders
         
         LogTrade();
         UpdateStats();
      }
   }
   g_lastHistoryTotal = historyTotal;
}

void LogTrade()
{
   int digits = (int)MarketInfo(OrderSymbol(), MODE_DIGITS);
   double pipMultiplier = (digits == 3 || digits == 5) ? 10 : 1;
   double pips = (OrderType() == OP_BUY) ? 
      (OrderClosePrice() - OrderOpenPrice()) / Point / pipMultiplier :
      (OrderOpenPrice() - OrderClosePrice()) / Point / pipMultiplier;
   
   int duration = (int)((OrderCloseTime() - OrderOpenTime()) / 60);
   
   int handle = FileOpen(JournalFileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);
   if(handle != INVALID_HANDLE)
   {
      FileSeek(handle, 0, SEEK_END);
      FileWrite(handle, 
         IntegerToString(OrderTicket()),
         OrderSymbol(),
         (OrderType() == OP_BUY ? "BUY" : "SELL"),
         DoubleToString(OrderLots(), 2),
         TimeToString(OrderOpenTime()),
         DoubleToString(OrderOpenPrice(), digits),
         TimeToString(OrderCloseTime()),
         DoubleToString(OrderClosePrice(), digits),
         DoubleToString(OrderProfit(), 2),
         DoubleToString(pips, 1),
         IntegerToString(duration)
      );
      FileClose(handle);
   }
}

void UpdateStats()
{
   double profit = OrderProfit() + OrderSwap() + OrderCommission();
   
   g_totalTrades++;
   
   if(profit > 0) { g_winningTrades++; g_grossProfit += profit; }
   else { g_losingTrades++; g_grossLoss += MathAbs(profit); }
}

void UpdateDrawdown()
{
   double balance = AccountBalance();
   if(balance > g_peakBalance) g_peakBalance = balance;
   
   double drawdown = g_peakBalance - balance;
   if(drawdown > g_maxDrawdown) g_maxDrawdown = drawdown;
}

void LoadStats()
{
   g_lastHistoryTotal = OrdersHistoryTotal();
   
   for(int i = 0; i < g_lastHistoryTotal; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderType() > OP_SELL) continue;
      
      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      g_totalTrades++;
      
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
   double netPL = g_grossProfit - g_grossLoss;
   
   int y = 20;
   CreateOrUpdateLabel("TJ_Title", 20, y, "=== TRADE JOURNAL ===", clrGold); y += 20;
   CreateOrUpdateLabel("TJ_Total", 20, y, "Total: " + IntegerToString(g_totalTrades), clrWhite); y += 15;
   CreateOrUpdateLabel("TJ_WinLoss", 20, y, "W/L: " + IntegerToString(g_winningTrades) + "/" + IntegerToString(g_losingTrades), clrWhite); y += 15;
   CreateOrUpdateLabel("TJ_WinRate", 20, y, "Win Rate: " + DoubleToString(winRate, 1) + "%", winRate >= 50 ? clrLime : clrRed); y += 15;
   CreateOrUpdateLabel("TJ_PF", 20, y, "PF: " + DoubleToString(profitFactor, 2), profitFactor >= 1 ? clrLime : clrRed); y += 15;
   CreateOrUpdateLabel("TJ_AvgWin", 20, y, "Avg Win: $" + DoubleToString(avgWin, 2), clrLime); y += 15;
   CreateOrUpdateLabel("TJ_AvgLoss", 20, y, "Avg Loss: $" + DoubleToString(avgLoss, 2), clrRed); y += 15;
   CreateOrUpdateLabel("TJ_NetPL", 20, y, "Net P/L: $" + DoubleToString(netPL, 2), netPL >= 0 ? clrLime : clrRed);
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
