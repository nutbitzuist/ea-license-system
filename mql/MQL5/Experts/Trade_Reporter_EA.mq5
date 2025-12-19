//+------------------------------------------------------------------+
//|                                           Trade_Reporter_EA.mq5   |
//|                        My Algo Stack - Trade Performance Tracking   |
//+------------------------------------------------------------------+
//| UTILITY: Reports all trades to My Algo Stack dashboard            |
//| Run this EA on any chart to track all account trades              |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"

#define TRADE_API_URL "https://myalgostack.com/api/trades"
#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "trade_reporter"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200
#define LICENSE_GRACE_PERIOD 86400

input string   LicenseKey = "";           // Your API Key from Dashboard

//--- Internal variables
datetime g_lastValidation = 0;
bool g_isLicensed = false;
string g_licenseError = "";
int g_lastDealsTotal = 0;

#include <Trade\Trade.mqh>
#include <Trade\DealInfo.mqh>

CDealInfo dealInfo;

//+------------------------------------------------------------------+
//| License Validation                                                |
//+------------------------------------------------------------------+
bool ValidateLicense()
{
   if(StringLen(LicenseKey) < 10)
   {
      g_licenseError = "Invalid License Key";
      return false;
   }
   
   string jsonBody = StringFormat(
      "{\"accountNumber\":\"%s\",\"brokerName\":\"%s\",\"eaCode\":\"%s\",\"eaVersion\":\"%s\",\"terminalType\":\"MT5\"}",
      IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)),
      AccountInfoString(ACCOUNT_COMPANY),
      LICENSE_EA_CODE,
      LICENSE_EA_VERSION
   );
   
   string headers = StringFormat("Content-Type: application/json\r\nX-API-Key: %s", LicenseKey);
   char postData[], resultData[];
   string resultHeaders;
   
   StringToCharArray(jsonBody, postData, 0, StringLen(jsonBody));
   ArrayResize(postData, StringLen(jsonBody));
   
   int statusCode = WebRequest("POST", LICENSE_API_URL, headers, 10000, postData, resultData, resultHeaders);
   
   if(statusCode == -1)
   {
      g_licenseError = "Connection failed";
      if(g_lastValidation > 0 && (TimeCurrent() - g_lastValidation) < LICENSE_GRACE_PERIOD)
         return g_isLicensed;
      return false;
   }
   
   string response = CharArrayToString(resultData);
   bool isValid = (StringFind(response, "\"valid\":true") >= 0);
   
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

//+------------------------------------------------------------------+
//| Report trade to server                                            |
//+------------------------------------------------------------------+
bool ReportDeal(ulong dealTicket)
{
   if(!HistoryDealSelect(dealTicket)) return false;
   
   ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
   if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL) return false;
   
   ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   
   string typeStr = (dealType == DEAL_TYPE_BUY) ? "BUY" : "SELL";
   string status = (dealEntry == DEAL_ENTRY_OUT) ? "CLOSED" : "OPEN";
   
   double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
   double swap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
   double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   double lots = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
   double price = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
   datetime time = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
   long positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
   
   string profitStr = (dealEntry == DEAL_ENTRY_OUT) ? StringFormat(",\"profit\":%.2f", profit + swap + commission) : "";
   
   string jsonBody = StringFormat(
      "{\"accountNumber\":\"%s\",\"ticket\":%d,\"symbol\":\"%s\",\"type\":\"%s\",\"lots\":%.2f,\"openPrice\":%.5f,\"openTime\":\"%s\",\"status\":\"%s\",\"swap\":%.2f,\"commission\":%.2f%s}",
      IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)),
      (int)positionId,
      symbol,
      typeStr,
      lots,
      price,
      TimeToString(time, TIME_DATE|TIME_SECONDS),
      status,
      swap,
      commission,
      profitStr
   );
   
   string headers = StringFormat("Content-Type: application/json\r\nX-API-Key: %s", LicenseKey);
   char postData[], resultData[];
   string resultHeaders;
   
   StringToCharArray(jsonBody, postData, 0, StringLen(jsonBody));
   ArrayResize(postData, StringLen(jsonBody));
   
   int statusCode = WebRequest("POST", TRADE_API_URL, headers, 10000, postData, resultData, resultHeaders);
   
   if(statusCode == 200 || statusCode == 201)
   {
      Print("Deal reported: ", dealTicket, " Status: ", status);
      return true;
   }
   else
   {
      Print("Failed to report deal. Status: ", statusCode);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!ValidateLicense())
   {
      Print("LICENSE ERROR: ", g_licenseError);
      Alert("License Error: ", g_licenseError);
      return INIT_FAILED;
   }
   
   // Get current history count
   HistorySelect(0, TimeCurrent());
   g_lastDealsTotal = HistoryDealsTotal();
   
   Print("Trade Reporter EA initialized - monitoring all trades");
   Comment("Trade Reporter Active\nAccount: ", AccountInfoInteger(ACCOUNT_LOGIN));
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!PeriodicLicenseCheck())
   {
      ExpertRemove();
      return;
   }
   
   // Check for new deals
   HistorySelect(0, TimeCurrent());
   int currentDeals = HistoryDealsTotal();
   
   if(currentDeals > g_lastDealsTotal)
   {
      for(int i = g_lastDealsTotal; i < currentDeals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         ReportDeal(ticket);
      }
   }
   g_lastDealsTotal = currentDeals;
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ReportDeal(trans.deal);
   }
}
//+------------------------------------------------------------------+
