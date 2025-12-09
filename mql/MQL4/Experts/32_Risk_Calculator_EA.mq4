//+------------------------------------------------------------------+
//|                                        32_Risk_Calculator_EA.mq4  |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| UTILITY: Risk Calculator & Position Sizer with One-Click Trading |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   RiskPercent = 1.0;
input int      StopLossPips = 50;
input int      TakeProfitPips = 100;
input bool     ShowPanel = true;

CLicenseValidator* g_license;
double g_calculatedLot = 0;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "risk_calculator_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   if(ShowPanel) CreatePanel();
   Print("Risk Calculator EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   ObjectsDeleteAll(0, "RC_");
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   CalculateRisk();
   if(ShowPanel) UpdatePanel();
}

void CalculateRisk()
{
   double balance = AccountBalance();
   double riskAmount = balance * RiskPercent / 100;
   double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double slValue = StopLossPips * pipValue;
   
   if(slValue > 0) g_calculatedLot = NormalizeDouble(riskAmount / slValue, 2);
   else g_calculatedLot = 0.01;
   
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   g_calculatedLot = MathMax(minLot, MathMin(maxLot, g_calculatedLot));
}

void CreatePanel()
{
   int y = 50;
   CreateLabel("RC_Title", 20, y, "=== RISK CALCULATOR ===", clrGold); y += 20;
   CreateLabel("RC_Balance", 20, y, "Balance: $0", clrWhite); y += 15;
   CreateLabel("RC_Risk", 20, y, "Risk: 0%", clrWhite); y += 15;
   CreateLabel("RC_Lot", 20, y, "Lot Size: 0.00", clrLime); y += 20;
   CreateButton("RC_BuyBtn", 20, y, 60, 25, "BUY", clrGreen);
   CreateButton("RC_SellBtn", 90, y, 60, 25, "SELL", clrRed);
}

void UpdatePanel()
{
   double balance = AccountBalance();
   double riskAmount = balance * RiskPercent / 100;
   
   ObjectSetString(0, "RC_Balance", OBJPROP_TEXT, "Balance: $" + DoubleToString(balance, 2));
   ObjectSetString(0, "RC_Risk", OBJPROP_TEXT, "Risk: " + DoubleToString(RiskPercent, 1) + "% ($" + DoubleToString(riskAmount, 2) + ")");
   ObjectSetString(0, "RC_Lot", OBJPROP_TEXT, "LOT SIZE: " + DoubleToString(g_calculatedLot, 2));
}

void CreateLabel(string name, int x, int y, string text, color clr)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
}

void CreateButton(string name, int x, int y, int width, int height, string text, color clr)
{
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == "RC_BuyBtn") { PlaceTrade(OP_BUY); ObjectSetInteger(0, "RC_BuyBtn", OBJPROP_STATE, false); }
      else if(sparam == "RC_SellBtn") { PlaceTrade(OP_SELL); ObjectSetInteger(0, "RC_SellBtn", OBJPROP_STATE, false); }
   }
}

void PlaceTrade(int orderType)
{
   double price = (orderType == OP_BUY) ? Ask : Bid;
   double sl = (orderType == OP_BUY) ? price - StopLossPips * Point : price + StopLossPips * Point;
   double tp = (orderType == OP_BUY) ? price + TakeProfitPips * Point : price - TakeProfitPips * Point;
   OrderSend(Symbol(), orderType, g_calculatedLot, price, 10, sl, tp, "RiskCalc", 0, 0, clrNONE);
}
//+------------------------------------------------------------------+
