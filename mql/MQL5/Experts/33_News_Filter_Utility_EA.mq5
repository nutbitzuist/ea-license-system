//+------------------------------------------------------------------+
//|                                    33_News_Filter_Utility_EA.mq5  |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| UTILITY: News Filter & Trading Hours Manager                      |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Manages trading based on time and high-impact news events.        |
//| Can close all trades before news, pause trading during news,      |
//| and restrict trading to specific hours.                           |
//|                                                                    |
//| FEATURES:                                                          |
//| - Trading hours filter (e.g., London/NY sessions only)            |
//| - Friday close before weekend                                     |
//| - Monday gap protection                                           |
//| - Manual news time input                                          |
//| - Close all trades before specified time                          |
//|                                                                    |
//| HOW TO USE:                                                        |
//| 1. Set your preferred trading hours                               |
//| 2. Input known news times manually                                |
//| 3. EA will manage other EAs' trades accordingly                   |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input bool     EnableTradingHours = true;
input int      TradingStartHour = 8;     // Start hour (server time)
input int      TradingEndHour = 20;      // End hour (server time)
input bool     EnableFridayClose = true;
input int      FridayCloseHour = 20;     // Close all on Friday at this hour
input bool     EnableMondayDelay = true;
input int      MondayStartHour = 2;      // Start trading Monday at this hour
input bool     EnableNewsFilter = true;
input string   NewsTime1 = "";           // News time 1 (HH:MM format)
input string   NewsTime2 = "";           // News time 2 (HH:MM format)
input string   NewsTime3 = "";           // News time 3 (HH:MM format)
input int      NewsBufferMinutes = 30;   // Minutes before/after news to avoid
input bool     CloseBeforeNews = false;  // Close positions before news
input int      MagicFilter = 0;          // 0 = manage all trades

CLicenseValidator* g_license;
bool g_tradingAllowed = true;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "news_filter_utility_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   Print("News Filter Utility EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   ObjectsDeleteAll(0, "NF_");
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   g_tradingAllowed = CheckTradingAllowed();
   UpdateDisplay();
   
   // Close trades if needed
   if(!g_tradingAllowed && CloseBeforeNews)
   {
      CloseAllTrades();
   }
}

bool CheckTradingAllowed()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   
   // Friday close
   if(EnableFridayClose && dt.day_of_week == 5 && dt.hour >= FridayCloseHour)
   {
      return false;
   }
   
   // Weekend
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
   {
      return false;
   }
   
   // Monday delay
   if(EnableMondayDelay && dt.day_of_week == 1 && dt.hour < MondayStartHour)
   {
      return false;
   }
   
   // Trading hours
   if(EnableTradingHours)
   {
      if(dt.hour < TradingStartHour || dt.hour >= TradingEndHour)
      {
         return false;
      }
   }
   
   // News filter
   if(EnableNewsFilter)
   {
      if(IsNearNewsTime(NewsTime1) || IsNearNewsTime(NewsTime2) || IsNearNewsTime(NewsTime3))
      {
         return false;
      }
   }
   
   return true;
}

bool IsNearNewsTime(string newsTime)
{
   if(StringLen(newsTime) < 5) return false;
   
   string parts[];
   if(StringSplit(newsTime, ':', parts) != 2) return false;
   
   int newsHour = (int)StringToInteger(parts[0]);
   int newsMin = (int)StringToInteger(parts[1]);
   
   MqlDateTime dt;
   TimeCurrent(dt);
   
   int currentMinutes = dt.hour * 60 + dt.min;
   int newsMinutes = newsHour * 60 + newsMin;
   
   return MathAbs(currentMinutes - newsMinutes) <= NewsBufferMinutes;
}

void CloseAllTrades()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(MagicFilter > 0 && PositionGetInteger(POSITION_MAGIC) != MagicFilter) continue;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      request.action = TRADE_ACTION_DEAL;
      request.position = PositionGetTicket(i);
      request.symbol = _Symbol;
      request.volume = PositionGetDouble(POSITION_VOLUME);
      request.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      request.price = request.type == ORDER_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      request.deviation = 10;
      OrderSend(request, result);
   }
}

void UpdateDisplay()
{
   string status = g_tradingAllowed ? "TRADING ALLOWED" : "TRADING PAUSED";
   color clr = g_tradingAllowed ? clrLime : clrRed;
   
   if(ObjectFind(0, "NF_Status") < 0)
   {
      ObjectCreate(0, "NF_Status", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "NF_Status", OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, "NF_Status", OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, "NF_Status", OBJPROP_FONTSIZE, 12);
   }
   
   ObjectSetString(0, "NF_Status", OBJPROP_TEXT, status);
   ObjectSetInteger(0, "NF_Status", OBJPROP_COLOR, clr);
}

// Export function for other EAs to check
bool IsTradingAllowed() export
{
   return g_tradingAllowed;
}
//+------------------------------------------------------------------+
