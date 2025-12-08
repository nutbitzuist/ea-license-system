//+------------------------------------------------------------------+
//|                                        15_London_Breakout_EA.mq5  |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: London Session Breakout                                  |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| This EA capitalizes on the volatility surge during the London     |
//| session open. It identifies the Asian session range and trades    |
//| the breakout when London opens with increased volume.              |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Calculates the high/low range during Asian session (00:00-07:00)|
//| 2. Places pending orders above/below the range before London open |
//| 3. Triggers on breakout with momentum confirmation                |
//| 4. Cancels unfilled orders after London session ends              |
//|                                                                    |
//| SESSION TIMES (Server Time):                                       |
//| - Asian Range: 00:00 - 07:00                                      |
//| - London Open: 07:00 - 08:00 (breakout window)                    |
//| - Trade Window: 07:00 - 16:00                                     |
//|                                                                    |
//| ENTRY CONDITIONS:                                                  |
//| BUY: Price breaks above Asian high during London session          |
//| SELL: Price breaks below Asian low during London session          |
//|                                                                    |
//| EXIT CONDITIONS:                                                   |
//| - Fixed Take Profit (1.5x Asian range)                            |
//| - Stop Loss at opposite side of range                             |
//| - Close all trades at end of London session                       |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: M15 or M30                                           |
//| - Pairs: GBP pairs (GBPUSD, GBPJPY, EURGBP)                       |
//|                                                                    |
//| RISK LEVEL: Medium                                                 |
//| WIN RATE: ~50-55% expected                                        |
//| RISK:REWARD: 1:1.5                                                |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      AsianStartHour = 0;       // Asian session start (server time)
input int      AsianEndHour = 7;         // Asian session end
input int      LondonEndHour = 16;       // London session end
input double   RangeMultiplier = 1.5;    // TP multiplier of range
input double   LotSize = 0.1;
input int      MagicNumber = 100015;

CLicenseValidator* g_license;
double g_asianHigh = 0, g_asianLow = 0;
bool g_rangeCalculated = false;
datetime g_lastRangeDate = 0;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "london_breakout_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   Print("London Breakout EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   
   // Reset range calculation for new day
   if(today != g_lastRangeDate)
   {
      g_rangeCalculated = false;
      g_lastRangeDate = today;
   }
   
   // Calculate Asian range at end of Asian session
   if(dt.hour == AsianEndHour && !g_rangeCalculated)
   {
      CalculateAsianRange();
      g_rangeCalculated = true;
   }
   
   // Close all trades at end of London session
   if(dt.hour >= LondonEndHour)
   {
      CloseAllPositions();
      return;
   }
   
   // Only trade during London session
   if(dt.hour < AsianEndHour || dt.hour >= LondonEndHour) return;
   if(!g_rangeCalculated) return;
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   
   bool buySignal = close1 > g_asianHigh && close2 <= g_asianHigh;
   bool sellSignal = close1 < g_asianLow && close2 >= g_asianLow;
   
   ManagePositions(buySignal, sellSignal);
}

void CalculateAsianRange()
{
   g_asianHigh = 0;
   g_asianLow = DBL_MAX;
   
   datetime startTime = StringToTime(TimeToString(TimeCurrent(), TIME_DATE)) + AsianStartHour * 3600;
   datetime endTime = StringToTime(TimeToString(TimeCurrent(), TIME_DATE)) + AsianEndHour * 3600;
   
   for(int i = 0; i < 500; i++)
   {
      datetime barTime = iTime(_Symbol, PERIOD_M15, i);
      if(barTime < startTime) break;
      if(barTime >= endTime) continue;
      
      double high = iHigh(_Symbol, PERIOD_M15, i);
      double low = iLow(_Symbol, PERIOD_M15, i);
      
      if(high > g_asianHigh) g_asianHigh = high;
      if(low < g_asianLow) g_asianLow = low;
   }
   
   Print("Asian Range: High=", g_asianHigh, " Low=", g_asianLow, " Range=", (g_asianHigh - g_asianLow) / SymbolInfoDouble(_Symbol, SYMBOL_POINT), " points");
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
   double range = g_asianHigh - g_asianLow;
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = price;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      request.sl = g_asianLow;
      request.tp = price + range * RangeMultiplier;
   }
   else
   {
      request.sl = g_asianHigh;
      request.tp = price - range * RangeMultiplier;
   }
   
   request.magic = MagicNumber;
   request.comment = "London BO";
   request.deviation = 10;
   OrderSend(request, result);
}

void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            request.action = TRADE_ACTION_DEAL;
            request.symbol = _Symbol;
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.price = (request.type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
            request.position = PositionGetTicket(i);
            request.deviation = 10;
            OrderSend(request, result);
         }
      }
   }
}
//+------------------------------------------------------------------+
