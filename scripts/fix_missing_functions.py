#!/usr/bin/env python3
"""
Final fix script to add missing ValidateLicense and PeriodicLicenseCheck functions.
"""

import os
import re

MQL5_EXPERTS_DIR = "/Users/nut/Downloads/ea-license-system/mql/MQL5/Experts"

LICENSE_VALIDATOR_CODE = '''//=============================================================================
// LICENSE VALIDATOR (EMBEDDED - NO EXTERNAL FILES NEEDED)
//=============================================================================
datetime g_lastValidation = 0;
bool g_isLicensed = false;
string g_licenseError = "";

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
      "{\\"accountNumber\\":\\"%s\\",\\"brokerName\\":\\"%s\\",\\"eaCode\\":\\"%s\\",\\"eaVersion\\":\\"%s\\",\\"terminalType\\":\\"MT5\\"}",
      accountNum, broker, LICENSE_EA_CODE, LICENSE_EA_VERSION
   );
   
   string headers = StringFormat("Content-Type: application/json\\r\\nX-API-Key: %s", LicenseKey);
   
   char postData[];
   char resultData[];
   string resultHeaders;
   
   StringToCharArray(jsonBody, postData, 0, StringLen(jsonBody));
   ArrayResize(postData, StringLen(jsonBody));
   
   int statusCode = WebRequest("POST", LICENSE_API_URL, headers, 10000, postData, resultData, resultHeaders);
   
   if(statusCode == -1)
   {
      int err = GetLastError();
      if(err == 4060)
         g_licenseError = "Add URL to allowed list: Tools -> Options -> Expert Advisors -> Add: https://myalgostack.com";
      else
         g_licenseError = "Server connection failed. Error: " + IntegerToString(err);
      
      if(g_lastValidation > 0 && (TimeCurrent() - g_lastValidation) < LICENSE_GRACE_PERIOD)
         return g_isLicensed;
      return false;
   }
   
   string response = CharArrayToString(resultData);
   bool isValid = (StringFind(response, "\\"valid\\":true") >= 0);
   
   if(!isValid)
   {
      int msgStart = StringFind(response, "\\"message\\":\\"") + 11;
      int msgEnd = StringFind(response, "\\"", msgStart);
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

'''

def fix_file(filepath):
    """Add missing ValidateLicense function to a file"""
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check if file already has ValidateLicense function
    if 'bool ValidateLicense()' in content:
        print(f"OK: {os.path.basename(filepath)}")
        return False
    
    # Check if file has LICENSE_API_URL (was updated by script)
    if '#define LICENSE_API_URL' not in content:
        print(f"SKIP (not updated): {os.path.basename(filepath)}")
        return False
    
    # Find position after global variables (before OnInit)
    # Look for pattern: int OnInit()
    oninit_match = re.search(r'\n(int OnInit\(\))', content)
    if not oninit_match:
        print(f"ERROR (no OnInit): {os.path.basename(filepath)}")
        return False
    
    # Insert the license validator code before OnInit
    insert_pos = oninit_match.start()
    new_content = content[:insert_pos] + '\n' + LICENSE_VALIDATOR_CODE + content[insert_pos:]
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print(f"FIXED: {os.path.basename(filepath)}")
    return True

def main():
    """Main function"""
    fixed = 0
    ok = 0
    
    for filename in sorted(os.listdir(MQL5_EXPERTS_DIR)):
        if filename.endswith('.mq5'):
            filepath = os.path.join(MQL5_EXPERTS_DIR, filename)
            if fix_file(filepath):
                fixed += 1
            else:
                ok += 1
    
    print(f"\nCompleted: {fixed} fixed, {ok} OK")

if __name__ == "__main__":
    main()
