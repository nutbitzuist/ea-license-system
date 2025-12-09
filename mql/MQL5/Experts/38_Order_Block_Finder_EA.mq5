//+------------------------------------------------------------------+
//|                                      38_Order_Block_Finder_EA.mq5 |
//|                                    EA License Management System   |
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
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      LookbackBars = 100;
input double   MinMoveMultiplier = 2.0;  // Min move = ATR * this
input int      ATR_Period = 14;
input bool     AlertOnApproach = true;
input int      ApproachPips = 20;
input color    DemandColor = clrDodgerBlue;
input color    SupplyColor = clrCrimson;

CLicenseValidator* g_license;
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

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "order_block_finder_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   ArraySetAsSeries(g_atr, true);
   ArrayResize(g_orderBlocks, 0);
   
   Print("Order Block Finder EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   ObjectsDeleteAll(0, "OB_");
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
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
