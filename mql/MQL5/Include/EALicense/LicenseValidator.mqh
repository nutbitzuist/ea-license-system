//+------------------------------------------------------------------+
//|                                            LicenseValidator.mqh   |
//|                                    My Algo Stack - Trading Infrastructure   |
//+------------------------------------------------------------------+
#property copyright "My Algo Stack"
#property version   "1.00"

#include "Config.mqh"

//+------------------------------------------------------------------+
//| License validation result structure                               |
//+------------------------------------------------------------------+
struct LicenseResult
{
   bool     isValid;
   string   message;
   string   errorCode;
   datetime serverTime;
   int      gracePeriodHours;
};

//+------------------------------------------------------------------+
//| License Validator Class                                           |
//+------------------------------------------------------------------+
class CLicenseValidator
{
private:
   string         m_apiKey;
   string         m_apiSecret;
   string         m_eaCode;
   string         m_eaVersion;
   string         m_apiEndpoint;
   
   datetime       m_lastValidation;
   bool           m_lastValidationResult;
   int            m_gracePeriodHours;
   int            m_validationIntervalSeconds;
   
   string         m_accountNumber;
   string         m_brokerName;
   string         m_terminalType;

public:
   //--- Constructor
   CLicenseValidator(string apiKey, string apiSecret, string eaCode, string eaVersion)
   {
      m_apiKey = apiKey;
      m_apiSecret = apiSecret;
      m_eaCode = eaCode;
      m_eaVersion = eaVersion;
      m_apiEndpoint = LICENSE_API_ENDPOINT;
      
      m_lastValidation = 0;
      m_lastValidationResult = false;
      m_gracePeriodHours = DEFAULT_GRACE_PERIOD_HOURS;
      m_validationIntervalSeconds = VALIDATION_INTERVAL_HOURS * 3600;
      
      // Get account info
      m_accountNumber = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
      m_brokerName = AccountInfoString(ACCOUNT_COMPANY);
      m_terminalType = "MT5";
   }
   
   //--- Main validation method
   bool Validate(string &errorMessage)
   {
      LicenseResult result;
      
      // Check if we can use cached result
      if(CanUseCachedValidation())
      {
         errorMessage = "Using cached validation";
         return m_lastValidationResult;
      }
      
      // Perform server validation
      if(!ValidateWithServer(result))
      {
         // Server unreachable - check grace period
         if(IsWithinGracePeriod())
         {
            errorMessage = "Server unreachable, using grace period";
            return m_lastValidationResult;
         }
         else
         {
            errorMessage = "Server unreachable and grace period expired";
            return false;
         }
      }
      
      // Update cached result
      m_lastValidation = TimeCurrent();
      m_lastValidationResult = result.isValid;
      m_gracePeriodHours = result.gracePeriodHours;
      
      errorMessage = result.message;
      return result.isValid;
   }
   
   //--- Check if periodic revalidation is needed
   bool NeedsRevalidation()
   {
      if(m_lastValidation == 0) return true;
      return (TimeCurrent() - m_lastValidation) > m_validationIntervalSeconds;
   }
   
   //--- Force revalidation
   bool ForceValidate(string &errorMessage)
   {
      m_lastValidation = 0;
      return Validate(errorMessage);
   }
   
   //--- Get last validation time
   datetime GetLastValidationTime()
   {
      return m_lastValidation;
   }
   
   //--- Get validation status
   bool IsValid()
   {
      return m_lastValidationResult;
   }

private:
   //--- Check if cached validation can be used
   bool CanUseCachedValidation()
   {
      if(m_lastValidation == 0) return false;
      return (TimeCurrent() - m_lastValidation) < m_validationIntervalSeconds;
   }
   
   //--- Check if within grace period
   bool IsWithinGracePeriod()
   {
      if(m_lastValidation == 0) return false;
      int graceSeconds = m_gracePeriodHours * 3600;
      return (TimeCurrent() - m_lastValidation) < graceSeconds;
   }
   
   //--- Perform HTTP validation with server
   bool ValidateWithServer(LicenseResult &result)
   {
      // Build request body
      string jsonBody = StringFormat(
         "{\"accountNumber\":\"%s\",\"brokerName\":\"%s\",\"eaCode\":\"%s\",\"eaVersion\":\"%s\",\"terminalType\":\"%s\"}",
         m_accountNumber,
         m_brokerName,
         m_eaCode,
         m_eaVersion,
         m_terminalType
      );
      
      // Set headers
      string headers = StringFormat(
         "Content-Type: application/json\r\nX-API-Key: %s\r\nX-API-Secret: %s",
         m_apiKey,
         m_apiSecret
      );
      
      // Make request
      char postData[];
      char resultData[];
      string resultHeaders;
      
      StringToCharArray(jsonBody, postData, 0, StringLen(jsonBody));
      ArrayResize(postData, StringLen(jsonBody));
      
      int timeout = 10000;  // 10 seconds
      int statusCode = WebRequest(
         "POST",
         m_apiEndpoint + "/api/validate",
         headers,
         timeout,
         postData,
         resultData,
         resultHeaders
      );
      
      if(statusCode == -1)
      {
         int errorCode = GetLastError();
         Print("WebRequest error: ", errorCode);
         Print("Make sure to add ", m_apiEndpoint, " to allowed URLs in Tools -> Options -> Expert Advisors");
         return false;  // Server unreachable
      }
      
      // Parse response
      string response = CharArrayToString(resultData);
      return ParseValidationResponse(response, result);
   }
   
   //--- Parse JSON response
   bool ParseValidationResponse(string json, LicenseResult &result)
   {
      // Check for valid response
      result.isValid = (StringFind(json, "\"valid\":true") >= 0);
      
      // Extract message
      int msgStart = StringFind(json, "\"message\":\"") + 11;
      int msgEnd = StringFind(json, "\"", msgStart);
      if(msgStart > 10 && msgEnd > msgStart)
      {
         result.message = StringSubstr(json, msgStart, msgEnd - msgStart);
      }
      else
      {
         result.message = result.isValid ? "License valid" : "License invalid";
      }
      
      // Extract error code if present
      int errStart = StringFind(json, "\"errorCode\":\"") + 13;
      int errEnd = StringFind(json, "\"", errStart);
      if(errStart > 12 && errEnd > errStart)
      {
         result.errorCode = StringSubstr(json, errStart, errEnd - errStart);
      }
      
      // Extract grace period
      int graceStart = StringFind(json, "\"gracePeriodHours\":") + 19;
      if(graceStart > 18)
      {
         int graceEnd = StringFind(json, ",", graceStart);
         if(graceEnd < 0) graceEnd = StringFind(json, "}", graceStart);
         if(graceEnd > graceStart)
         {
            string graceStr = StringSubstr(json, graceStart, graceEnd - graceStart);
            result.gracePeriodHours = (int)StringToInteger(graceStr);
         }
      }
      
      if(result.gracePeriodHours <= 0)
         result.gracePeriodHours = DEFAULT_GRACE_PERIOD_HOURS;
      
      return true;
   }
};
