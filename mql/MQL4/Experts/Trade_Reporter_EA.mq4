//+------------------------------------------------------------------+
//|                                           Trade_Reporter_EA.mq4   |
//|                        My Algo Stack - Trade Performance Tracking   |
//+------------------------------------------------------------------+
//| UTILITY: Reports all trades to My Algo Stack dashboard            |
//| Run this EA on any chart to track all account trades              |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"
#property strict

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
int g_lastOrdersTotal = 0;
int g_lastHistoryTotal = 0;

// Track reported tickets to avoid duplicates
int g_reportedTickets[];

//+------------------------------------------------------------------+
//| License Validation (same as other EAs)                           |
//+------------------------------------------------------------------+
bool ValidateLicense()
{
   if(StringLen(LicenseKey) < 10)
   {
      g_licenseError = "Invalid License Key";
      return false;
   }
   
   string jsonBody = StringFormat(
      "{\"accountNumber\":\"%s\",\"brokerName\":\"%s\",\"eaCode\":\"%s\",\"eaVersion\":\"%s\",\"terminalType\":\"MT4\"}",
      IntegerToString(AccountNumber()),
      AccountCompany(),
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
//| Check if ticket was already reported                              |
//+------------------------------------------------------------------+
bool IsTicketReported(int ticket)
{
   for(int i = 0; i < ArraySize(g_reportedTickets); i++)
   {
      if(g_reportedTickets[i] == ticket) return true;
   }
   return false;
}

void MarkTicketReported(int ticket)
{
   int size = ArraySize(g_reportedTickets);
   ArrayResize(g_reportedTickets, size + 1);
   g_reportedTickets[size] = ticket;
   
   // Keep array manageable (last 1000 tickets)
   if(ArraySize(g_reportedTickets) > 1000)
   {
      int newTickets[];
      ArrayResize(newTickets, 500);
      ArrayCopy(newTickets, g_reportedTickets, 0, 500, 500);
      ArrayCopy(g_reportedTickets, newTickets);
      ArrayResize(g_reportedTickets, 500);
   }
}

//+------------------------------------------------------------------+
//| Report trade to server                                            |
//+------------------------------------------------------------------+
bool ReportTrade(int ticket, bool isClosed)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return false;
   
   int type = OrderType();
   if(type > OP_SELL) return false; // Skip pending orders
   
   string typeStr = (type == OP_BUY) ? "BUY" : "SELL";
   string status = isClosed ? "CLOSED" : "OPEN";
   
   // Calculate pips
   double pips = 0;
   if(isClosed)
   {
      int digits = (int)MarketInfo(OrderSymbol(), MODE_DIGITS);
      double pipMultiplier = (digits == 3 || digits == 5) ? 10 : 1;
      if(type == OP_BUY)
         pips = (OrderClosePrice() - OrderOpenPrice()) / Point / pipMultiplier;
      else
         pips = (OrderOpenPrice() - OrderClosePrice()) / Point / pipMultiplier;
   }
   
   // Build JSON
   string closeTimeStr = isClosed ? StringFormat(",\"closeTime\":\"%s\"", TimeToString(OrderCloseTime(), TIME_DATE|TIME_SECONDS)) : "";
   string closePriceStr = isClosed ? StringFormat(",\"closePrice\":%.5f", OrderClosePrice()) : "";
   string profitStr = isClosed ? StringFormat(",\"profit\":%.2f,\"pips\":%.1f", OrderProfit() + OrderSwap() + OrderCommission(), pips) : "";
   
   string jsonBody = StringFormat(
      "{\"accountNumber\":\"%s\",\"ticket\":%d,\"symbol\":\"%s\",\"type\":\"%s\",\"lots\":%.2f,\"openPrice\":%.5f,\"stopLoss\":%.5f,\"takeProfit\":%.5f,\"openTime\":\"%s\",\"status\":\"%s\",\"swap\":%.2f,\"commission\":%.2f%s%s%s}",
      IntegerToString(AccountNumber()),
      OrderTicket(),
      OrderSymbol(),
      typeStr,
      OrderLots(),
      OrderOpenPrice(),
      OrderStopLoss(),
      OrderTakeProfit(),
      TimeToString(OrderOpenTime(), TIME_DATE|TIME_SECONDS),
      status,
      OrderSwap(),
      OrderCommission(),
      closePriceStr,
      closeTimeStr,
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
      Print("Trade reported: Ticket ", ticket, " Status: ", status);
      return true;
   }
   else
   {
      Print("Failed to report trade. Status: ", statusCode);
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
   
   g_lastOrdersTotal = OrdersTotal();
   g_lastHistoryTotal = OrdersHistoryTotal();
   
   // Report all currently open trades
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderType() > OP_SELL) continue;
      
      ReportTrade(OrderTicket(), false);
      MarkTicketReported(OrderTicket());
   }
   
   Print("Trade Reporter EA initialized - monitoring all trades");
   Comment("Trade Reporter Active\nAccount: ", AccountNumber());
   
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
   
   // Check for new trades (opened)
   int currentOrders = OrdersTotal();
   if(currentOrders > g_lastOrdersTotal)
   {
      for(int i = 0; i < currentOrders; i++)
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderType() > OP_SELL) continue;
         
         int ticket = OrderTicket();
         if(!IsTicketReported(ticket))
         {
            if(ReportTrade(ticket, false))
               MarkTicketReported(ticket);
         }
      }
   }
   g_lastOrdersTotal = currentOrders;
   
   // Check for closed trades (in history)
   int currentHistory = OrdersHistoryTotal();
   if(currentHistory > g_lastHistoryTotal)
   {
      for(int i = g_lastHistoryTotal; i < currentHistory; i++)
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
         if(OrderType() > OP_SELL) continue;
         
         ReportTrade(OrderTicket(), true);
      }
   }
   g_lastHistoryTotal = currentHistory;
}
//+------------------------------------------------------------------+
