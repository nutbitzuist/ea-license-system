//+------------------------------------------------------------------+
//|                                      38_Order_Block_Finder_EA.mq4 |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| UTILITY: Order Block & Supply/Demand Zone Finder                  |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input int      LookbackBars = 100;
input double   MinMoveMultiplier = 2.0;
input int      ATR_Period = 14;
input bool     AlertOnApproach = true;
input int      ApproachPips = 20;
input color    DemandColor = clrDodgerBlue;
input color    SupplyColor = clrCrimson;

CLicenseValidator* g_license;

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
   ArrayResize(g_orderBlocks, 0);
   Print("Order Block Finder EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   ObjectsDeleteAll(0, "OB_");
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   static datetime lastBar = 0;
   if(lastBar == iTime(Symbol(), Period(), 0)) return;
   lastBar = iTime(Symbol(), Period(), 0);
   
   double atr = iATR(Symbol(), Period(), ATR_Period, 0);
   FindOrderBlocks(atr);
   DrawOrderBlocks();
   CheckPriceApproach();
}

void FindOrderBlocks(double atr)
{
   ArrayResize(g_orderBlocks, 0);
   double minMove = atr * MinMoveMultiplier;
   
   for(int i = 3; i < LookbackBars; i++)
   {
      double open_i = iOpen(Symbol(), Period(), i);
      double close_i = iClose(Symbol(), Period(), i);
      double high_i = iHigh(Symbol(), Period(), i);
      double low_i = iLow(Symbol(), Period(), i);
      
      bool isBearishCandle = close_i < open_i;
      bool isBullishCandle = close_i > open_i;
      
      if(isBearishCandle)
      {
         for(int j = i - 1; j >= 1; j--)
         {
            double moveUp = iHigh(Symbol(), Period(), j) - low_i;
            if(moveUp >= minMove)
            {
               OrderBlock ob;
               ob.high = high_i; ob.low = low_i; ob.time = iTime(Symbol(), Period(), i);
               ob.isBullish = true; ob.isValid = true;
               
               for(int k = i - 1; k >= 1; k--)
                  if(iClose(Symbol(), Period(), k) < ob.low) { ob.isValid = false; break; }
               
               if(ob.isValid)
               {
                  ArrayResize(g_orderBlocks, ArraySize(g_orderBlocks) + 1);
                  g_orderBlocks[ArraySize(g_orderBlocks) - 1] = ob;
               }
               break;
            }
         }
      }
      
      if(isBullishCandle)
      {
         for(int j = i - 1; j >= 1; j--)
         {
            double moveDown = high_i - iLow(Symbol(), Period(), j);
            if(moveDown >= minMove)
            {
               OrderBlock ob;
               ob.high = high_i; ob.low = low_i; ob.time = iTime(Symbol(), Period(), i);
               ob.isBullish = false; ob.isValid = true;
               
               for(int k = i - 1; k >= 1; k--)
                  if(iClose(Symbol(), Period(), k) > ob.high) { ob.isValid = false; break; }
               
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
      
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, g_orderBlocks[i].time, g_orderBlocks[i].high,
                   TimeCurrent() + PeriodSeconds() * 50, g_orderBlocks[i].low);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
}

void CheckPriceApproach()
{
   if(!AlertOnApproach) return;
   
   double approachDistance = ApproachPips * Point;
   static datetime lastAlert = 0;
   if(TimeCurrent() - lastAlert < 300) return;
   
   for(int i = 0; i < ArraySize(g_orderBlocks); i++)
   {
      if(!g_orderBlocks[i].isValid) continue;
      
      if(g_orderBlocks[i].isBullish && Bid <= g_orderBlocks[i].high + approachDistance && Bid >= g_orderBlocks[i].low)
      { Alert("Price approaching DEMAND zone"); lastAlert = TimeCurrent(); return; }
      
      if(!g_orderBlocks[i].isBullish && Bid >= g_orderBlocks[i].low - approachDistance && Bid <= g_orderBlocks[i].high)
      { Alert("Price approaching SUPPLY zone"); lastAlert = TimeCurrent(); return; }
   }
}
//+------------------------------------------------------------------+
