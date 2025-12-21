//+------------------------------------------------------------------+
//|                                           43_Grid_Trader_EA.mq5  |
//|                    My Algo Stack - Trading Infrastructure        |
//|                                                                   |
//| STRATEGY: Grid Trading for Ranging Markets                        |
//| LOGIC: Opens grid of buy and sell orders at fixed intervals.      |
//|        Profits from price oscillations in range-bound markets.    |
//|        Uses ATR for dynamic grid spacing.                         |
//| TIMEFRAME: H1 recommended                                         |
//| PAIRS: Range-bound pairs (EURCHF, AUDNZD)                         |
//| WARNING: High risk strategy - use with caution!                   |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.50"
#property strict

//=============================================================================
// LICENSE CONFIGURATION - DO NOT MODIFY
//=============================================================================
#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "grid_trader_v1"
#define LICENSE_EA_VERSION "1.5.0"
#define LICENSE_CHECK_INTERVAL 43200
#define LICENSE_GRACE_PERIOD 86400

//=============================================================================
// USER INPUT PARAMETERS
//=============================================================================
input string   LicenseKey = "";
input int      GridLevels = 5;
input int      GridSpacing = 50;
input bool     UseDynamicGrid = true;
input int      ATR_Period = 14;
input double   ATR_Multiplier = 1.0;
input double   LotSize = 0.01;
input double   LotMultiplier = 1.0;
input int      TakeProfit = 30;
input int      MagicNumber = 430001;

input double   MaxDrawdownPercent = 20.0;
input int      MaxOpenOrders = 10;
input double   ProfitTarget = 0;

//=============================================================================
// LICENSE VALIDATOR
//=============================================================================
datetime g_lastValidation = 0;
bool g_isLicensed = false;
string g_licenseError = "";
double g_initialEquity = 0;

bool ValidateLicense()
{
   if(StringLen(LicenseKey) < 10)
   {
      g_licenseError = "Invalid License Key. Get your key from the dashboard.";
      return false;
   }
   
   string accountNum = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   string broker = AccountInfoString(ACCOUNT_COMPANY);
   
   string jsonBody = StringFormat(
      "{\"accountNumber\":\"%s\",\"brokerName\":\"%s\",\"eaCode\":\"%s\",\"eaVersion\":\"%s\",\"terminalType\":\"MT5\"}",
      accountNum, broker, LICENSE_EA_CODE, LICENSE_EA_VERSION
   );
   
   string headers = StringFormat(
      "Content-Type: application/json\r\nX-API-Key: %s",
      LicenseKey
   );
   
   char postData[];
   char resultData[];
   string resultHeaders;
   
   StringToCharArray(jsonBody, postData, 0, StringLen(jsonBody));
   ArrayResize(postData, StringLen(jsonBody));
   
   int statusCode = WebRequest(
      "POST",
      LICENSE_API_URL,
      headers,
      10000,
      postData,
      resultData,
      resultHeaders
   );
   
   if(statusCode == -1)
   {
      int err = GetLastError();
      if(err == 4060)
         g_licenseError = "Add URL to allowed list: Tools -> Options -> Expert Advisors -> Add: https://myalgostack.com";
      else
         g_licenseError = "Server connection failed. Error: " + IntegerToString(err);
      
      if(g_lastValidation > 0 && (TimeCurrent() - g_lastValidation) < LICENSE_GRACE_PERIOD)
      {
         Print("License server unreachable, using grace period");
         return g_isLicensed;
      }
      return false;
   }
   
   string response = CharArrayToString(resultData);
   bool isValid = (StringFind(response, "\"valid\":true") >= 0);
   
   if(!isValid)
   {
      int msgStart = StringFind(response, "\"message\":\"") + 11;
      int msgEnd = StringFind(response, "\"", msgStart);
      if(msgStart > 10 && msgEnd > msgStart)
         g_licenseError = StringSubstr(response, msgStart, msgEnd - msgStart);
      else
         g_licenseError = "License validation failed. Check your License Key.";
   }
   
   g_lastValidation = TimeCurrent();
   g_isLicensed = isValid;
   
   return isValid;
}

bool PeriodicLicenseCheck()
{
   if(!g_isLicensed) return false;
   if((TimeCurrent() - g_lastValidation) < LICENSE_CHECK_INTERVAL) return true;
   return ValidateLicense();
}

//=============================================================================
// EA VARIABLES
//=============================================================================
double g_atr[];
int g_atr_handle;

int OnInit()
{
   Print("=== Grid Trader EA v1.5.0 ===");
   Print("Validating license...");
   
   if(!ValidateLicense())
   {
      Print("LICENSE ERROR: ", g_licenseError);
      Alert("License Error: ", g_licenseError);
      return INIT_FAILED;
   }
   
   Print("License validated successfully!");
   Print("Account: ", AccountInfoInteger(ACCOUNT_LOGIN), " | Broker: ", AccountInfoString(ACCOUNT_COMPANY));
   Print("WARNING: Grid trading is HIGH RISK! Use appropriate lot sizes.");
   
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   
   if(g_atr_handle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator");
      return INIT_FAILED;
   }
   
   ArraySetAsSeries(g_atr, true);
   g_initialEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   Print("Grid Trader EA initialized and ready to trade");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   Print("Grid Trader EA stopped. Reason: ", reason);
}

void OnTick()
{
   if(!PeriodicLicenseCheck())
   {
      Print("License expired or invalid: ", g_licenseError);
      ExpertRemove();
      return;
   }
   
   CheckDrawdown();
   
   // Check profit target
   if(ProfitTarget > 0)
   {
      double totalProfit = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionSelectByTicket(PositionGetTicket(i)))
         {
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
               PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
               totalProfit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            }
         }
      }
      
      if(totalProfit >= ProfitTarget)
      {
         Print("Profit target reached: $", totalProfit);
         CloseAllPositions();
         return;
      }
   }
   
   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(lastBar == currentBar) return;
   lastBar = currentBar;
   
   ManageGrid();
}

double GetGridSpacing()
{
   if(UseDynamicGrid)
   {
      if(CopyBuffer(g_atr_handle, 0, 0, 2, g_atr) < 2) return GridSpacing;
      return NormalizeDouble(g_atr[1] * ATR_Multiplier / SymbolInfoDouble(_Symbol, SYMBOL_POINT), 0);
   }
   return GridSpacing;
}

void ManageGrid()
{
   double gridSpace = GetGridSpacing();
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   int positionCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            positionCount++;
         }
      }
   }
   
   int orderCount = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(OrderGetTicket(i)))
      {
         if(OrderGetInteger(ORDER_MAGIC) == MagicNumber && 
            OrderGetString(ORDER_SYMBOL) == _Symbol)
         {
            orderCount++;
         }
      }
   }
   
   int totalOrders = positionCount + orderCount;
   if(totalOrders >= MaxOpenOrders) return;
   
   // Calculate grid levels
   for(int level = 1; level <= GridLevels && totalOrders < MaxOpenOrders; level++)
   {
      double buyPrice = currentPrice - (gridSpace * level * point);
      double sellPrice = currentPrice + (gridSpace * level * point);
      double lotForLevel = NormalizeDouble(LotSize * MathPow(LotMultiplier, level - 1), 2);
      
      bool buyExists = false;
      bool sellExists = false;
      
      // Check existing positions
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionSelectByTicket(PositionGetTicket(i)))
         {
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
               PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
               double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && 
                  MathAbs(openPrice - buyPrice) < gridSpace * point / 2)
                  buyExists = true;
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && 
                  MathAbs(openPrice - sellPrice) < gridSpace * point / 2)
                  sellExists = true;
            }
         }
      }
      
      // Check existing orders
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(OrderSelect(OrderGetTicket(i)))
         {
            if(OrderGetInteger(ORDER_MAGIC) == MagicNumber && 
               OrderGetString(ORDER_SYMBOL) == _Symbol)
            {
               double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
               if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT && 
                  MathAbs(orderPrice - buyPrice) < gridSpace * point / 2)
                  buyExists = true;
               if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT && 
                  MathAbs(orderPrice - sellPrice) < gridSpace * point / 2)
                  sellExists = true;
            }
         }
      }
      
      // Open buy limit
      if(!buyExists && SymbolInfoDouble(_Symbol, SYMBOL_BID) > buyPrice + 10 * point)
      {
         MqlTradeRequest request = {};
         MqlTradeResult result = {}; ZeroMemory(request); ZeroMemory(result);
         
         request.action = TRADE_ACTION_PENDING;
         request.symbol = _Symbol;
         request.volume = lotForLevel;
         request.type = ORDER_TYPE_BUY_LIMIT;
         request.price = buyPrice;
         request.sl = 0;
         request.tp = buyPrice + TakeProfit * point;
         request.magic = MagicNumber;
         request.comment = "Grid Buy L" + IntegerToString(level);
         request.deviation = 10;
         
         if(OrderSend(request, result)) totalOrders++;
      }
      
      // Open sell limit
      if(!sellExists && SymbolInfoDouble(_Symbol, SYMBOL_ASK) < sellPrice - 10 * point)
      {
         MqlTradeRequest request = {};
         MqlTradeResult result = {}; ZeroMemory(request); ZeroMemory(result);
         
         request.action = TRADE_ACTION_PENDING;
         request.symbol = _Symbol;
         request.volume = lotForLevel;
         request.type = ORDER_TYPE_SELL_LIMIT;
         request.price = sellPrice;
         request.sl = 0;
         request.tp = sellPrice - TakeProfit * point;
         request.magic = MagicNumber;
         request.comment = "Grid Sell L" + IntegerToString(level);
         request.deviation = 10;
         
         if(OrderSend(request, result)) totalOrders++;
      }
   }
}

void CheckDrawdown()
{
   if(g_initialEquity <= 0) g_initialEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double drawdownPercent = ((g_initialEquity - currentEquity) / g_initialEquity) * 100;
   
   if(drawdownPercent >= MaxDrawdownPercent)
   {
      Print("Maximum drawdown reached: ", drawdownPercent, "%. Closing all positions!");
      Alert("Grid Trader: Max drawdown reached! Closing all positions.");
      CloseAllPositions();
      DeleteAllOrders();
      ExpertRemove();
   }
}

void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            MqlTradeRequest request = {};
            MqlTradeResult result = {}; ZeroMemory(request); ZeroMemory(result);
            
            request.action = TRADE_ACTION_DEAL;
            request.symbol = _Symbol;
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.price = (request.type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
            request.position = ticket;
            request.deviation = 10;
            
            if(!OrderSend(request, result))
               Print("Failed to close position: ", GetLastError());
         }
      }
   }
}

void DeleteAllOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_MAGIC) == MagicNumber && 
            OrderGetString(ORDER_SYMBOL) == _Symbol)
         {
            MqlTradeRequest request = {};
            MqlTradeResult result = {}; ZeroMemory(request); ZeroMemory(result);
            
            request.action = TRADE_ACTION_REMOVE;
            request.order = ticket;
            
            if(!OrderSend(request, result))
               Print("Failed to delete order: ", GetLastError());
         }
      }
   }
}
//+------------------------------------------------------------------+
