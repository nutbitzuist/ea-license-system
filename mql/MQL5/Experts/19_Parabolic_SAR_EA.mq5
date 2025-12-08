//+------------------------------------------------------------------+
//|                                         19_Parabolic_SAR_EA.mq5   |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| STRATEGY: Parabolic SAR Trend Following                           |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| This EA uses the Parabolic SAR indicator to identify trend        |
//| direction and generate entry/exit signals. Combined with ADX      |
//| to filter for strong trends and avoid choppy markets.              |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| 1. Parabolic SAR determines trend direction:                      |
//|    - SAR below price = Uptrend                                    |
//|    - SAR above price = Downtrend                                  |
//| 2. ADX confirms trend strength (must be > threshold)              |
//| 3. Enters on SAR flip with ADX confirmation                       |
//| 4. Uses SAR as trailing stop                                       |
//|                                                                    |
//| PARABOLIC SAR PARAMETERS:                                          |
//| - Step: Acceleration factor (default 0.02)                        |
//| - Maximum: Maximum acceleration (default 0.2)                     |
//|                                                                    |
//| ENTRY CONDITIONS:                                                  |
//| BUY: SAR flips below price + ADX > 25                             |
//| SELL: SAR flips above price + ADX > 25                            |
//|                                                                    |
//| EXIT CONDITIONS:                                                   |
//| - SAR flips (trend reversal)                                      |
//| - Trailing stop at SAR level                                       |
//|                                                                    |
//| RECOMMENDED SETTINGS:                                              |
//| - Timeframe: H1 or H4                                             |
//| - Pairs: Trending pairs                                           |
//|                                                                    |
//| RISK LEVEL: Medium                                                 |
//| WIN RATE: ~45-50% expected                                        |
//| RISK:REWARD: 1:2 to 1:3 (trend riding)                            |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

input string   EA_ApiKey = "";
input string   EA_ApiSecret = "";
input double   SAR_Step = 0.02;          // SAR Step
input double   SAR_Maximum = 0.2;        // SAR Maximum
input int      ADX_Period = 14;          // ADX Period
input int      ADX_Threshold = 25;       // ADX Threshold
input double   LotSize = 0.1;
input int      MagicNumber = 100019;

CLicenseValidator* g_license;
int g_sar_handle, g_adx_handle;
double g_sar[], g_adx[];

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "parabolic_sar_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   g_sar_handle = iSAR(_Symbol, PERIOD_CURRENT, SAR_Step, SAR_Maximum);
   g_adx_handle = iADX(_Symbol, PERIOD_CURRENT, ADX_Period);
   
   if(g_sar_handle == INVALID_HANDLE || g_adx_handle == INVALID_HANDLE) return INIT_FAILED;
   
   ArraySetAsSeries(g_sar, true);
   ArraySetAsSeries(g_adx, true);
   
   Print("Parabolic SAR EA initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
   if(g_sar_handle != INVALID_HANDLE) IndicatorRelease(g_sar_handle);
   if(g_adx_handle != INVALID_HANDLE) IndicatorRelease(g_adx_handle);
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   if(CopyBuffer(g_sar_handle, 0, 0, 3, g_sar) < 3) return;
   if(CopyBuffer(g_adx_handle, 0, 0, 2, g_adx) < 2) return;
   
   // Update trailing stops based on SAR
   UpdateTrailingStops();
   
   static datetime lastBar = 0;
   if(lastBar == iTime(_Symbol, PERIOD_CURRENT, 0)) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   
   bool sarBelowPrice1 = g_sar[1] < close1;
   bool sarBelowPrice2 = g_sar[2] < close2;
   bool strongTrend = g_adx[1] > ADX_Threshold;
   
   // SAR flip signals
   bool buySignal = sarBelowPrice1 && !sarBelowPrice2 && strongTrend;
   bool sellSignal = !sarBelowPrice1 && sarBelowPrice2 && strongTrend;
   
   ManagePositions(buySignal, sellSignal);
}

void UpdateTrailingStops()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            double currentSL = PositionGetDouble(POSITION_SL);
            double sarValue = g_sar[0];
            
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               // SAR should be below price for buy
               if(sarValue < PositionGetDouble(POSITION_PRICE_CURRENT) && sarValue > currentSL)
               {
                  request.action = TRADE_ACTION_SLTP;
                  request.symbol = _Symbol;
                  request.position = PositionGetTicket(i);
                  request.sl = sarValue;
                  request.tp = PositionGetDouble(POSITION_TP);
                  OrderSend(request, result);
               }
            }
            else
            {
               // SAR should be above price for sell
               if(sarValue > PositionGetDouble(POSITION_PRICE_CURRENT) && (currentSL == 0 || sarValue < currentSL))
               {
                  request.action = TRADE_ACTION_SLTP;
                  request.symbol = _Symbol;
                  request.position = PositionGetTicket(i);
                  request.sl = sarValue;
                  request.tp = PositionGetDouble(POSITION_TP);
                  OrderSend(request, result);
               }
            }
         }
      }
   }
}

void ManagePositions(bool buySignal, bool sellSignal)
{
   // Close opposite positions on signal
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            if((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && sellSignal) ||
               (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && buySignal))
            {
               ClosePosition(PositionGetTicket(i));
            }
            else
            {
               return; // Already have position in right direction
            }
         }
      }
   }
   
   if(buySignal) OpenPosition(ORDER_TYPE_BUY);
   else if(sellSignal) OpenPosition(ORDER_TYPE_SELL);
}

void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = price;
   request.sl = g_sar[0];  // Initial SL at SAR
   request.tp = 0;  // No TP, use trailing stop
   request.magic = MagicNumber;
   request.comment = "Parabolic SAR";
   request.deviation = 10;
   OrderSend(request, result);
}

void ClosePosition(ulong ticket)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   if(!PositionSelectByTicket(ticket)) return;
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = PositionGetDouble(POSITION_VOLUME);
   request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = (request.type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   request.position = ticket;
   request.deviation = 10;
   OrderSend(request, result);
}
//+------------------------------------------------------------------+
