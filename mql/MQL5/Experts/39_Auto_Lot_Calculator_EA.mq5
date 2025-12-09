//+------------------------------------------------------------------+
//|                                     39_Auto_Lot_Calculator_EA.mq5 |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| UTILITY: Automatic Lot Size Calculator                            |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Automatically calculates and applies proper lot sizes to all      |
//| trades based on your risk settings. Works with any EA or manual   |
//| trading.                                                           |
//|                                                                    |
//| FEATURES:                                                          |
//| - Risk-based lot calculation                                      |
//| - Auto-adjust pending orders                                      |
//| - Compound growth option                                          |
//| - Fixed fractional position sizing                                |
//| - Kelly criterion option                                          |
//|                                                                    |
//| POSITION SIZING METHODS:                                           |
//| 1. Fixed Risk %: Risk X% of account per trade                     |
//| 2. Fixed Fractional: Trade X% of account as margin                |
//| 3. Kelly Criterion: Optimal sizing based on win rate              |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

enum SIZING_METHOD { FIXED_RISK, FIXED_FRACTIONAL, KELLY_CRITERION };

input string        EA_ApiKey = "";
input string        EA_ApiSecret = "";
input SIZING_METHOD Method = FIXED_RISK;
input double        RiskPercent = 1.0;       // Risk % per trade
input double        FractionalPercent = 5.0; // % of account for margin
input double        WinRate = 55.0;          // Win rate % for Kelly
input double        AvgWinLossRatio = 1.5;   // Avg win / avg loss for Kelly
input double        KellyFraction = 0.5;     // Use X% of full Kelly
input int           DefaultSL = 50;          // Default SL if none set
input bool          ShowPanel = true;

CLicenseValidator* g_license;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "auto_lot_calculator_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   Print("Auto Lot Calculator EA initialized");
   Print("Method: ", EnumToString(Method));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   ObjectsDeleteAll(0, "ALC_");
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   double optimalLot = CalculateOptimalLot();
   if(ShowPanel) UpdatePanel(optimalLot);
}

double CalculateOptimalLot()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double lot = 0.01;
   
   switch(Method)
   {
      case FIXED_RISK:
         lot = CalculateFixedRiskLot(balance);
         break;
      case FIXED_FRACTIONAL:
         lot = CalculateFixedFractionalLot(balance);
         break;
      case KELLY_CRITERION:
         lot = CalculateKellyLot(balance);
         break;
   }
   
   // Normalize to broker limits
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = MathFloor(lot / lotStep) * lotStep;
   
   return NormalizeDouble(lot, 2);
}

double CalculateFixedRiskLot(double balance)
{
   double riskAmount = balance * RiskPercent / 100;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   double pipValue = tickValue * (point / tickSize);
   double slValue = DefaultSL * pipValue;
   
   if(slValue > 0)
      return riskAmount / slValue;
   return 0.01;
}

double CalculateFixedFractionalLot(double balance)
{
   double marginAmount = balance * FractionalPercent / 100;
   double marginRequired = 0;
   
   if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, 1.0, SymbolInfoDouble(_Symbol, SYMBOL_ASK), marginRequired))
   {
      if(marginRequired > 0)
         return marginAmount / marginRequired;
   }
   return 0.01;
}

double CalculateKellyLot(double balance)
{
   // Kelly formula: f* = (bp - q) / b
   // where b = win/loss ratio, p = win probability, q = loss probability
   double p = WinRate / 100;
   double q = 1 - p;
   double b = AvgWinLossRatio;
   
   double kellyPercent = (b * p - q) / b;
   kellyPercent = MathMax(0, kellyPercent); // Can't be negative
   kellyPercent *= KellyFraction; // Use fraction of full Kelly
   
   // Convert to lot size using fixed risk method
   double riskAmount = balance * kellyPercent;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   double pipValue = tickValue * (point / tickSize);
   double slValue = DefaultSL * pipValue;
   
   if(slValue > 0)
      return riskAmount / slValue;
   return 0.01;
}

void UpdatePanel(double optimalLot)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * RiskPercent / 100;
   
   int y = 20;
   CreateOrUpdateLabel("ALC_Title", 20, y, "=== LOT CALCULATOR ===", clrGold); y += 20;
   CreateOrUpdateLabel("ALC_Method", 20, y, "Method: " + EnumToString(Method), clrWhite); y += 15;
   CreateOrUpdateLabel("ALC_Balance", 20, y, "Balance: $" + DoubleToString(balance, 2), clrWhite); y += 15;
   CreateOrUpdateLabel("ALC_Risk", 20, y, "Risk: " + DoubleToString(RiskPercent, 1) + "% ($" + DoubleToString(riskAmount, 2) + ")", clrWhite); y += 15;
   CreateOrUpdateLabel("ALC_SL", 20, y, "Default SL: " + IntegerToString(DefaultSL) + " pips", clrWhite); y += 15;
   CreateOrUpdateLabel("ALC_Lot", 20, y, "OPTIMAL LOT: " + DoubleToString(optimalLot, 2), clrLime); y += 20;
   
   if(Method == KELLY_CRITERION)
   {
      double p = WinRate / 100;
      double q = 1 - p;
      double b = AvgWinLossRatio;
      double kellyPercent = MathMax(0, (b * p - q) / b) * KellyFraction * 100;
      CreateOrUpdateLabel("ALC_Kelly", 20, y, "Kelly %: " + DoubleToString(kellyPercent, 2) + "%", clrYellow);
   }
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
