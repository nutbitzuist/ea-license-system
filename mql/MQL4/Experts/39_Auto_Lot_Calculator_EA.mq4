//+------------------------------------------------------------------+
//|                                     39_Auto_Lot_Calculator_EA.mq4 |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| UTILITY: Automatic Lot Size Calculator                            |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

enum SIZING_METHOD { FIXED_RISK, FIXED_FRACTIONAL, KELLY_CRITERION };

input string        EA_ApiKey = "";
input string        EA_ApiSecret = "";
input SIZING_METHOD Method = FIXED_RISK;
input double        RiskPercent = 1.0;
input double        FractionalPercent = 5.0;
input double        WinRate = 55.0;
input double        AvgWinLossRatio = 1.5;
input double        KellyFraction = 0.5;
input int           DefaultSL = 50;
input bool          ShowPanel = true;

CLicenseValidator* g_license;

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "auto_lot_calculator_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   Print("Auto Lot Calculator EA initialized");
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
   double balance = AccountBalance();
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
   
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   
   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = MathFloor(lot / lotStep) * lotStep;
   
   return NormalizeDouble(lot, 2);
}

double CalculateFixedRiskLot(double balance)
{
   double riskAmount = balance * RiskPercent / 100;
   double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double slValue = DefaultSL * pipValue;
   
   if(slValue > 0) return riskAmount / slValue;
   return 0.01;
}

double CalculateFixedFractionalLot(double balance)
{
   double marginAmount = balance * FractionalPercent / 100;
   double marginRequired = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
   
   if(marginRequired > 0) return marginAmount / marginRequired;
   return 0.01;
}

double CalculateKellyLot(double balance)
{
   double p = WinRate / 100;
   double q = 1 - p;
   double b = AvgWinLossRatio;
   
   double kellyPercent = (b * p - q) / b;
   kellyPercent = MathMax(0, kellyPercent) * KellyFraction;
   
   double riskAmount = balance * kellyPercent;
   double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double slValue = DefaultSL * pipValue;
   
   if(slValue > 0) return riskAmount / slValue;
   return 0.01;
}

void UpdatePanel(double optimalLot)
{
   double balance = AccountBalance();
   double riskAmount = balance * RiskPercent / 100;
   
   int y = 20;
   CreateOrUpdateLabel("ALC_Title", 20, y, "=== LOT CALCULATOR ===", clrGold); y += 20;
   CreateOrUpdateLabel("ALC_Method", 20, y, "Method: " + EnumToString(Method), clrWhite); y += 15;
   CreateOrUpdateLabel("ALC_Balance", 20, y, "Balance: $" + DoubleToString(balance, 2), clrWhite); y += 15;
   CreateOrUpdateLabel("ALC_Risk", 20, y, "Risk: " + DoubleToString(RiskPercent, 1) + "%", clrWhite); y += 15;
   CreateOrUpdateLabel("ALC_Lot", 20, y, "OPTIMAL LOT: " + DoubleToString(optimalLot, 2), clrLime);
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
