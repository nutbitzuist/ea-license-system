//+------------------------------------------------------------------+
//|                                           43_Grid_Trader_EA.mq4  |
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
#define LICENSE_CHECK_INTERVAL 43200  // Check every 12 hours (in seconds)
#define LICENSE_GRACE_PERIOD 86400    // 24 hours grace if server unreachable

//=============================================================================
// USER INPUT PARAMETERS
//=============================================================================
input string   LicenseKey = "";           // License Key (from dashboard)
input int      GridLevels = 5;             // Number of grid levels each side
input int      GridSpacing = 50;           // Grid spacing (points)
input bool     UseDynamicGrid = true;      // Use ATR for dynamic grid
input int      ATR_Period = 14;            // ATR Period (if dynamic)
input double   ATR_Multiplier = 1.0;       // ATR Multiplier for spacing
input double   LotSize = 0.01;             // Base Lot Size per level
input double   LotMultiplier = 1.0;        // Lot multiplier per level (1.0 = flat)
input int      TakeProfit = 30;            // Take Profit per level (points)
input int      MagicNumber = 430001;       // Magic Number

//--- RISK MANAGEMENT ---
input double   MaxDrawdownPercent = 20.0;  // Max account drawdown %
input int      MaxOpenOrders = 10;         // Maximum open orders
input double   ProfitTarget = 0;           // Close all at profit $ (0 = disabled)

//--- FORWARD DECLARATIONS ---
void ManageGrid();
void CheckDrawdown();

//=============================================================================
// LICENSE VALIDATOR (EMBEDDED - NO EXTERNAL FILES NEEDED)
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
   
   string accountNum = IntegerToString(AccountNumber());
   string broker = AccountCompany();
   
   string jsonBody = StringFormat(
      "{\"accountNumber\":\"%s\",\"brokerName\":\"%s\",\"eaCode\":\"%s\",\"eaVersion\":\"%s\",\"terminalType\":\"MT4\"}",
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
   
   if((TimeCurrent() - g_lastValidation) < LICENSE_CHECK_INTERVAL)
      return true;
   
   return ValidateLicense();
}

//=============================================================================
// EA LOGIC
//=============================================================================

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
   Print("Account: ", AccountNumber(), " | Broker: ", AccountCompany());
   Print("Grid Trader EA initialized and ready to trade");
   Print("WARNING: Grid trading is HIGH RISK! Use appropriate lot sizes.");
   
   g_initialEquity = AccountEquity();
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
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
   
   // Check drawdown protection
   CheckDrawdown();
   
   // Check profit target
   if(ProfitTarget > 0)
   {
      double totalProfit = 0;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
            {
               totalProfit += OrderProfit() + OrderSwap() + OrderCommission();
            }
         }
      }
      
      if(totalProfit >= ProfitTarget)
      {
         Print("Profit target reached: $", totalProfit);
         CloseAllOrders();
         return;
      }
   }
   
   // Manage grid on new bar
   static datetime lastBar = 0;
   datetime currentBar = iTime(Symbol(), Period(), 0);
   if(lastBar == currentBar) return;
   lastBar = currentBar;
   
   ManageGrid();
}

//+------------------------------------------------------------------+
//| Get current grid spacing (dynamic or fixed)                       |
//+------------------------------------------------------------------+
double GetGridSpacing()
{
   if(UseDynamicGrid)
   {
      double atr = iATR(Symbol(), Period(), ATR_Period, 1);
      return NormalizeDouble(atr * ATR_Multiplier / Point, 0);
   }
   return GridSpacing;
}

//+------------------------------------------------------------------+
//| Manage the grid of orders                                         |
//+------------------------------------------------------------------+
void ManageGrid()
{
   double gridSpace = GetGridSpacing();
   double currentPrice = (Bid + Ask) / 2;
   
   // Count existing orders
   int orderCount = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         {
            orderCount++;
         }
      }
   }
   
   // Check max orders
   if(orderCount >= MaxOpenOrders) return;
   
   // Calculate grid levels
   for(int level = 1; level <= GridLevels && orderCount < MaxOpenOrders; level++)
   {
      double buyPrice = currentPrice - (gridSpace * level * Point);
      double sellPrice = currentPrice + (gridSpace * level * Point);
      double lotForLevel = NormalizeDouble(LotSize * MathPow(LotMultiplier, level - 1), 2);
      
      // Check if buy order exists at this level
      bool buyExists = false;
      bool sellExists = false;
      
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
            {
               if(OrderType() == OP_BUY && MathAbs(OrderOpenPrice() - buyPrice) < gridSpace * Point / 2)
                  buyExists = true;
               if(OrderType() == OP_SELL && MathAbs(OrderOpenPrice() - sellPrice) < gridSpace * Point / 2)
                  sellExists = true;
            }
         }
      }
      
      // Open buy limit at lower level
      if(!buyExists && Bid > buyPrice + 10 * Point)
      {
         double sl = 0;  // No SL for grid
         double tp = buyPrice + TakeProfit * Point;
         
         int ticket = OrderSend(Symbol(), OP_BUYLIMIT, lotForLevel, buyPrice, 10, sl, tp, 
                               "Grid Buy L" + IntegerToString(level), MagicNumber, 0, clrBlue);
         if(ticket > 0) orderCount++;
      }
      
      // Open sell limit at upper level
      if(!sellExists && Ask < sellPrice - 10 * Point)
      {
         double sl = 0;  // No SL for grid
         double tp = sellPrice - TakeProfit * Point;
         
         int ticket = OrderSend(Symbol(), OP_SELLLIMIT, lotForLevel, sellPrice, 10, sl, tp,
                               "Grid Sell L" + IntegerToString(level), MagicNumber, 0, clrRed);
         if(ticket > 0) orderCount++;
      }
   }
}

//+------------------------------------------------------------------+
//| Check drawdown and close all if exceeded                          |
//+------------------------------------------------------------------+
void CheckDrawdown()
{
   if(g_initialEquity <= 0) g_initialEquity = AccountEquity();
   
   double currentEquity = AccountEquity();
   double drawdownPercent = ((g_initialEquity - currentEquity) / g_initialEquity) * 100;
   
   if(drawdownPercent >= MaxDrawdownPercent)
   {
      Print("Maximum drawdown reached: ", drawdownPercent, "%. Closing all orders!");
      Alert("Grid Trader: Max drawdown reached! Closing all orders.");
      CloseAllOrders();
      ExpertRemove();
   }
}

//+------------------------------------------------------------------+
//| Close all orders for this EA                                      |
//+------------------------------------------------------------------+
void CloseAllOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         {
            if(OrderType() == OP_BUY)
            {
               if(!OrderClose(OrderTicket(), OrderLots(), Bid, 10, clrNONE))
                  Print("Failed to close buy order: ", GetLastError());
            }
            else if(OrderType() == OP_SELL)
            {
               if(!OrderClose(OrderTicket(), OrderLots(), Ask, 10, clrNONE))
                  Print("Failed to close sell order: ", GetLastError());
            }
            else  // Pending orders
            {
               if(!OrderDelete(OrderTicket()))
                  Print("Failed to delete pending order: ", GetLastError());
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
