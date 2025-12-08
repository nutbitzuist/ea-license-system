//+------------------------------------------------------------------+
//|                                        05_Stochastic_Scalper_EA.mq5|
//|                                    EA License Management System   |
//|                                                                    |
//| STRATEGY: Stochastic Scalping                                      |
//| LOGIC: Quick trades based on stochastic %K and %D crossovers in    |
//|        overbought/oversold zones. Fast entries and exits.          |
//| TIMEFRAME: M15 recommended                                         |
//| PAIRS: High liquidity pairs (EURUSD, USDJPY)                      |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

//--- Input parameters
input string   EA_ApiKey = "";           // API Key
input string   EA_ApiSecret = "";        // API Secret
input int      Stoch_K = 5;              // Stochastic %K Period
input int      Stoch_D = 3;              // Stochastic %D Period
input int      Stoch_Slowing = 3;        // Stochastic Slowing
input int      OverboughtLevel = 80;     // Overbought Level
input int      OversoldLevel = 20;       // Oversold Level
input double   LotSize = 0.1;            // Lot Size
input int      StopLoss = 50;            // Stop Loss (points)
input int      TakeProfit = 80;          // Take Profit (points)
input int      MagicNumber = 100005;     // Magic Number

//--- Global variables
CLicenseValidator* g_license;
bool g_isLicensed = false;
double g_stochK[], g_stochD[];
int g_stoch_handle;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "stochastic_scalper_ea", "1.0.0");
   g_isLicensed = g_license.ValidateLicense();
   
   if(!g_isLicensed)
   {
      Print("License validation failed: ", g_license.GetLastError());
      return INIT_FAILED;
   }
   
   g_stoch_handle = iStochastic(_Symbol, PERIOD_CURRENT, Stoch_K, Stoch_D, Stoch_Slowing, MODE_SMA, STO_LOWHIGH);
   
   if(g_stoch_handle == INVALID_HANDLE)
   {
      Print("Failed to create Stochastic indicator");
      return INIT_FAILED;
   }
   
   ArraySetAsSeries(g_stochK, true);
   ArraySetAsSeries(g_stochD, true);
   
   Print("Stochastic Scalper EA initialized successfully");
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
   
   if(g_stoch_handle != INVALID_HANDLE) IndicatorRelease(g_stoch_handle);
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
   
   if(CopyBuffer(g_stoch_handle, 0, 0, 3, g_stochK) < 3) return;
   if(CopyBuffer(g_stoch_handle, 1, 0, 3, g_stochD) < 3) return;
   
   //--- Stochastic crossover in zones
   bool buySignal = g_stochK[1] > g_stochD[1] && g_stochK[2] <= g_stochD[2] && g_stochK[1] < OversoldLevel + 10;
   bool sellSignal = g_stochK[1] < g_stochD[1] && g_stochK[2] >= g_stochD[2] && g_stochK[1] > OverboughtLevel - 10;
   
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
   request.comment = "Stoch Scalper";
   request.deviation = 10;
   
   if(!OrderSend(request, result))
   {
      Print("OrderSend failed: ", GetLastError());
   }
}
//+------------------------------------------------------------------+
