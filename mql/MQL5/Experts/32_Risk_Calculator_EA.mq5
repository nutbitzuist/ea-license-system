//+------------------------------------------------------------------+
//|                                        32_Risk_Calculator_EA.mq5  |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| UTILITY: Risk Calculator & Position Sizer                         |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Calculates optimal lot size based on account risk percentage      |
//| and stop loss distance. Displays real-time risk information       |
//| on the chart.                                                      |
//|                                                                    |
//| FEATURES:                                                          |
//| - Real-time lot size calculation                                  |
//| - Risk percentage display                                         |
//| - Pip value calculator                                            |
//| - Margin requirement display                                      |
//| - One-click trade with calculated lot                             |
//|                                                                    |
//| HOW TO USE:                                                        |
//| 1. Set your risk percentage (e.g., 1-2%)                          |
//| 2. Set your stop loss in pips                                     |
//| 3. EA shows optimal lot size on chart                             |
//| 4. Use buttons to place trades with calculated lot                |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   RiskPercent = 1.0;        // Risk % per trade
input int      StopLossPips = 50;        // Default SL in pips
input int      TakeProfitPips = 100;     // Default TP in pips
input bool     ShowPanel = true;
input int      PanelX = 20;
input int      PanelY = 50;

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
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * RiskPercent / 100;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pipValue = tickValue * (point / tickSize);
   double slValue = StopLossPips * pipValue;
   
   if(slValue > 0)
      g_calculatedLot = NormalizeDouble(riskAmount / slValue, 2);
   else
      g_calculatedLot = 0.01;
   
   // Ensure within broker limits
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   g_calculatedLot = MathMax(minLot, MathMin(maxLot, g_calculatedLot));
}

void CreatePanel()
{
   int y = PanelY;
   CreateLabel("RC_Title", PanelX, y, "=== RISK CALCULATOR ===", clrGold); y += 20;
   CreateLabel("RC_Balance", PanelX, y, "Balance: $0", clrWhite); y += 15;
   CreateLabel("RC_Risk", PanelX, y, "Risk: 0%", clrWhite); y += 15;
   CreateLabel("RC_RiskAmt", PanelX, y, "Risk Amount: $0", clrWhite); y += 15;
   CreateLabel("RC_SL", PanelX, y, "Stop Loss: 0 pips", clrWhite); y += 15;
   CreateLabel("RC_PipValue", PanelX, y, "Pip Value: $0", clrWhite); y += 15;
   CreateLabel("RC_Lot", PanelX, y, "Lot Size: 0.00", clrLime); y += 15;
   CreateLabel("RC_Margin", PanelX, y, "Margin: $0", clrWhite); y += 20;
   CreateButton("RC_BuyBtn", PanelX, y, 60, 25, "BUY", clrGreen);
   CreateButton("RC_SellBtn", PanelX + 70, y, 60, 25, "SELL", clrRed);
}

void UpdatePanel()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * RiskPercent / 100;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pipValue = tickValue * (point / tickSize) * g_calculatedLot;
   double margin = 0;
   OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, g_calculatedLot, SymbolInfoDouble(_Symbol, SYMBOL_ASK), margin);
   
   ObjectSetString(0, "RC_Balance", OBJPROP_TEXT, "Balance: $" + DoubleToString(balance, 2));
   ObjectSetString(0, "RC_Risk", OBJPROP_TEXT, "Risk: " + DoubleToString(RiskPercent, 1) + "%");
   ObjectSetString(0, "RC_RiskAmt", OBJPROP_TEXT, "Risk Amount: $" + DoubleToString(riskAmount, 2));
   ObjectSetString(0, "RC_SL", OBJPROP_TEXT, "Stop Loss: " + IntegerToString(StopLossPips) + " pips");
   ObjectSetString(0, "RC_PipValue", OBJPROP_TEXT, "Pip Value: $" + DoubleToString(pipValue, 2));
   ObjectSetString(0, "RC_Lot", OBJPROP_TEXT, "LOT SIZE: " + DoubleToString(g_calculatedLot, 2));
   ObjectSetString(0, "RC_Margin", OBJPROP_TEXT, "Margin: $" + DoubleToString(margin, 2));
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
      if(sparam == "RC_BuyBtn")
      {
         PlaceTrade(ORDER_TYPE_BUY);
         ObjectSetInteger(0, "RC_BuyBtn", OBJPROP_STATE, false);
      }
      else if(sparam == "RC_SellBtn")
      {
         PlaceTrade(ORDER_TYPE_SELL);
         ObjectSetInteger(0, "RC_SellBtn", OBJPROP_STATE, false);
      }
   }
}

void PlaceTrade(ENUM_ORDER_TYPE orderType)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   double price = orderType == ORDER_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = g_calculatedLot;
   request.type = orderType;
   request.price = price;
   request.sl = orderType == ORDER_TYPE_BUY ? price - StopLossPips * point : price + StopLossPips * point;
   request.tp = orderType == ORDER_TYPE_BUY ? price + TakeProfitPips * point : price - TakeProfitPips * point;
   request.deviation = 10;
   request.comment = "RiskCalc";
   
   if(OrderSend(request, result))
      Print("Trade placed: ", orderType == ORDER_TYPE_BUY ? "BUY" : "SELL", " ", g_calculatedLot, " lots");
}
//+------------------------------------------------------------------+
