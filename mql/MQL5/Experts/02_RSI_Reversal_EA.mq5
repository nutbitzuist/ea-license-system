//+------------------------------------------------------------------+
//|                                             02_RSI_Reversal_EA.mq5 |
//|                                    EA License Management System   |
//|                                                                    |
//| STRATEGY: RSI Overbought/Oversold Reversal                        |
//| LOGIC: Buy when RSI crosses above oversold level (30), sell when   |
//|        RSI crosses below overbought level (70). Mean reversion.    |
//| TIMEFRAME: H4 recommended                                          |
//| PAIRS: Range-bound pairs work best                                 |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

//--- Input parameters
input string   EA_ApiKey = "";           // API Key
input string   EA_ApiSecret = "";        // API Secret
input int      RSI_Period = 14;          // RSI Period
input int      OverboughtLevel = 70;     // Overbought Level
input int      OversoldLevel = 30;       // Oversold Level
input double   LotSize = 0.1;            // Lot Size
input int      StopLoss = 150;           // Stop Loss (points)
input int      TakeProfit = 100;         // Take Profit (points)
input int      MagicNumber = 100002;     // Magic Number

//--- Global variables
CLicenseValidator* g_license;
bool g_isLicensed = false;
double g_rsi[];
int g_rsi_handle;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "rsi_reversal_ea", "1.0.0");
   g_isLicensed = g_license.ValidateLicense();
   
   if(!g_isLicensed)
   {
      Print("License validation failed: ", g_license.GetLastError());
      return INIT_FAILED;
   }
   
   g_rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   
   if(g_rsi_handle == INVALID_HANDLE)
   {
      Print("Failed to create RSI indicator");
      return INIT_FAILED;
   }
   
   ArraySetAsSeries(g_rsi, true);
   
   Print("RSI Reversal EA initialized successfully");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_license != NULL)
   {
      delete g_license;
      g_license = NULL;
   }
   
   if(g_rsi_handle != INVALID_HANDLE) IndicatorRelease(g_rsi_handle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(lastBar == currentBar) return;
   lastBar = currentBar;
   
   if(CopyBuffer(g_rsi_handle, 0, 0, 3, g_rsi) < 3) return;
   
   //--- RSI crossover signals
   bool buySignal = g_rsi[1] > OversoldLevel && g_rsi[2] <= OversoldLevel;
   bool sellSignal = g_rsi[1] < OverboughtLevel && g_rsi[2] >= OverboughtLevel;
   
   //--- Check existing positions
   bool hasPosition = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            hasPosition = true;
            break;
         }
      }
   }
   
   if(!hasPosition)
   {
      if(buySignal) OpenPosition(ORDER_TYPE_BUY);
      else if(sellSignal) OpenPosition(ORDER_TYPE_SELL);
   }
}

//+------------------------------------------------------------------+
//| Open a new position                                                |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = 0, tp = 0;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(orderType == ORDER_TYPE_BUY)
   {
      sl = price - StopLoss * point;
      tp = price + TakeProfit * point;
   }
   else
   {
      sl = price + StopLoss * point;
      tp = price - TakeProfit * point;
   }
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.magic = MagicNumber;
   request.comment = "RSI Reversal";
   request.deviation = 10;
   
   if(!OrderSend(request, result))
   {
      Print("OrderSend failed: ", GetLastError());
   }
}
//+------------------------------------------------------------------+
