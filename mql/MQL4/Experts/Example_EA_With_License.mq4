//+------------------------------------------------------------------+
//|                                      Example_EA_With_License.mq4  |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

//--- Input parameters
input string InpApiKey = "";      // API Key
input string InpApiSecret = "";   // API Secret

//--- Global variables
CLicenseValidator *g_licenseValidator = NULL;
bool g_isLicensed = false;
datetime g_lastRevalidation = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Check if API credentials provided
   if(InpApiKey == "" || InpApiSecret == "")
   {
      Alert("Please enter your API Key and API Secret in EA settings");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Initialize license validator
   g_licenseValidator = new CLicenseValidator(
      InpApiKey,
      InpApiSecret,
      "example_ea",  // EA code - must match dashboard
      "1.0.0"        // EA version
   );
   
   // Perform initial validation
   string errorMessage;
   g_isLicensed = g_licenseValidator.Validate(errorMessage);
   
   if(!g_isLicensed)
   {
      Alert("License validation failed: ", errorMessage);
      delete g_licenseValidator;
      g_licenseValidator = NULL;
      return INIT_FAILED;
   }
   
   Print("License validated successfully: ", errorMessage);
   g_lastRevalidation = TimeCurrent();
   
   // Set timer for periodic revalidation (every 12 hours)
   EventSetTimer(43200);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   
   if(g_licenseValidator != NULL)
   {
      delete g_licenseValidator;
      g_licenseValidator = NULL;
   }
}

//+------------------------------------------------------------------+
//| Timer function - periodic revalidation                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(g_licenseValidator == NULL) return;
   
   string errorMessage;
   g_isLicensed = g_licenseValidator.Validate(errorMessage);
   g_lastRevalidation = TimeCurrent();
   
   if(!g_isLicensed)
   {
      Alert("License revalidation failed: ", errorMessage);
      // Optionally close all positions and stop trading
      // CloseAllOrders();
   }
   else
   {
      Print("License revalidation successful at ", TimeToString(g_lastRevalidation));
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check license before any trading logic
   if(!g_isLicensed)
   {
      // Don't trade if not licensed
      return;
   }
   
   //+------------------------------------------------------------------+
   // YOUR TRADING LOGIC GOES HERE
   //+------------------------------------------------------------------+
   
   // Example: Simple moving average crossover strategy
   // double ma_fast = iMA(Symbol(), 0, 10, 0, MODE_SMA, PRICE_CLOSE, 0);
   // double ma_slow = iMA(Symbol(), 0, 20, 0, MODE_SMA, PRICE_CLOSE, 0);
   
   // Add your trading logic here...
   
}

//+------------------------------------------------------------------+
//| Helper function to close all orders (optional)                    |
//+------------------------------------------------------------------+
void CloseAllOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol())
         {
            if(OrderType() == OP_BUY)
            {
               OrderClose(OrderTicket(), OrderLots(), Bid, 10, clrNone);
            }
            else if(OrderType() == OP_SELL)
            {
               OrderClose(OrderTicket(), OrderLots(), Ask, 10, clrNone);
            }
         }
      }
   }
}
