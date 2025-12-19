#!/usr/bin/env python3
"""
Script to update all MQL5 Expert Advisors to use embedded license validation
matching the MQL4 format (single LicenseKey input instead of API Key + Secret).
"""

import os
import re

MQL5_EXPERTS_DIR = "/Users/nut/Downloads/ea-license-system/mql/MQL5/Experts"

# The license configuration and validation code template
LICENSE_TEMPLATE = '''//=============================================================================
// LICENSE CONFIGURATION - DO NOT MODIFY
//=============================================================================
#define LICENSE_API_URL "https://myalgostack.com/api/validate"
#define LICENSE_EA_CODE "{ea_code}"
#define LICENSE_EA_VERSION "1.0.0"
#define LICENSE_CHECK_INTERVAL 43200  // Check every 12 hours (in seconds)
#define LICENSE_GRACE_PERIOD 86400    // 24 hours grace if server unreachable

//=============================================================================
// USER INPUT PARAMETERS
//=============================================================================
input string   LicenseKey = "";          // License Key (from dashboard)'''

LICENSE_VALIDATOR_CODE = '''
//=============================================================================
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

def extract_ea_code(filename):
    """Extract EA code from filename for LICENSE_EA_CODE define"""
    # Remove .mq5 extension and number prefix
    name = os.path.basename(filename).replace('.mq5', '')
    # Remove leading number and underscore
    name = re.sub(r'^\d+_', '', name)
    # Convert to lowercase with underscores
    name = name.lower()
    return name

def process_file(filepath):
    """Process a single MQL5 EA file to update the license format"""
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Skip if already updated (has LICENSE_API_URL define)
    if '#define LICENSE_API_URL' in content:
        print(f"SKIP (already updated): {os.path.basename(filepath)}")
        return False
    
    # Extract EA code
    ea_code = extract_ea_code(filepath)
    
    # Remove the #include <EALicense/LicenseValidator.mqh> line
    content = re.sub(r'#include\s*<EALicense/LicenseValidator\.mqh>\s*\n', '', content)
    
    # Find and replace the old input parameters section
    # Pattern to match: input string EA_ApiKey = ""; and EA_ApiSecret = "";
    old_inputs_pattern = r'//--- Input parameters\s*\n\s*input string\s+EA_ApiKey\s*=\s*""\s*;\s*//[^\n]*\n\s*input string\s+EA_ApiSecret\s*=\s*""\s*;\s*//[^\n]*\n'
    
    # Also handle InpApiKey/InpApiSecret pattern
    old_inputs_pattern2 = r'//--- Input parameters\s*\n\s*input string\s+InpApiKey\s*=\s*""\s*;\s*//[^\n]*\n\s*input string\s+InpApiSecret\s*=\s*""\s*;\s*//[^\n]*\n'
    
    license_config = LICENSE_TEMPLATE.format(ea_code=ea_code)
    
    if re.search(old_inputs_pattern, content):
        content = re.sub(old_inputs_pattern, license_config + '\n', content)
    elif re.search(old_inputs_pattern2, content):
        content = re.sub(old_inputs_pattern2, license_config + '\n', content)
    else:
        # Try simpler pattern - just EA_ApiKey and EA_ApiSecret on any lines
        content = re.sub(r'input string\s+(EA_ApiKey|InpApiKey)\s*=\s*""\s*;\s*//[^\n]*\n', '', content)
        content = re.sub(r'input string\s+(EA_ApiSecret|InpApiSecret)\s*=\s*""\s*;\s*//[^\n]*\n', '', content)
        
        # Insert license configuration after #property strict
        content = re.sub(r'(#property strict\s*\n)', r'\1\n' + license_config + '\n', content)
    
    # Remove old global variables for license
    content = re.sub(r'//--- Global variables\s*\n\s*CLicenseValidator\*?\s+g_license\s*;?\s*\n', '//--- Global variables\n', content)
    content = re.sub(r'CLicenseValidator\*?\s+\*?g_license\s*=?\s*NULL\s*;?\s*\n', '', content)
    content = re.sub(r'CLicenseValidator\*?\s+\*?g_licenseValidator\s*=?\s*NULL\s*;?\s*\n', '', content)
    content = re.sub(r'bool\s+g_isLicensed\s*=\s*false\s*;\s*\n', '', content)
    content = re.sub(r'datetime\s+g_lastRevalidation\s*=\s*0\s*;\s*\n', '', content)
    
    # Find the position to insert license validator code (before //+-- for OnInit)
    oninit_pattern = r'(//\+------------------------------------------------------------------\+\s*\n//\|\s*Expert initialization function)'
    
    # Insert license validator code before OnInit
    content = re.sub(oninit_pattern, LICENSE_VALIDATOR_CODE + '\n\n' + r'\1', content)
    
    # Update OnInit to use new validation
    # Replace old license initialization patterns
    old_init_patterns = [
        r'g_license\s*=\s*new\s+CLicenseValidator\s*\(\s*\)\s*;\s*\n\s*g_license\.Initialize\s*\([^)]+\)\s*;\s*\n\s*g_isLicensed\s*=\s*g_license\.ValidateLicense\s*\(\s*\)\s*;\s*\n\s*\n?\s*if\s*\(\s*!\s*g_isLicensed\s*\)\s*\n?\s*\{\s*\n\s*Print\s*\(\s*"License validation failed: "\s*,\s*g_license\.GetLastError\s*\(\s*\)\s*\)\s*;\s*\n\s*return\s+INIT_FAILED\s*;\s*\n\s*\}',
        r'g_license\s*=\s*new\s+CLicenseValidator\s*\(\s*\)\s*;\s*\n\s*g_license\.Initialize\s*\([^)]+\)\s*;\s*\n\s*if\s*\(\s*!\s*g_license\.ValidateLicense\s*\(\s*\)\s*\)\s*\{\s*Print\s*\(\s*"License failed"\s*\)\s*;\s*return\s+INIT_FAILED\s*;\s*\}',
    ]
    
    new_init = '''Print("Validating license...");
   
   if(!ValidateLicense())
   {
      Print("LICENSE ERROR: ", g_licenseError);
      Alert("License Error: ", g_licenseError);
      return INIT_FAILED;
   }
   
   Print("License validated successfully!");
   Print("Account: ", AccountInfoInteger(ACCOUNT_LOGIN), " | Broker: ", AccountInfoString(ACCOUNT_COMPANY));'''
    
    for pattern in old_init_patterns:
        if re.search(pattern, content, re.DOTALL):
            content = re.sub(pattern, new_init, content, flags=re.DOTALL)
            break
    
    # Update OnDeinit to remove license cleanup
    content = re.sub(r'if\s*\(\s*g_license\s*!=\s*NULL\s*\)\s*\n?\s*\{\s*\n?\s*delete\s+g_license\s*;\s*\n?\s*g_license\s*=\s*NULL\s*;\s*\n?\s*\}\s*\n?', '', content)
    content = re.sub(r'if\s*\(\s*g_license\s*!=\s*NULL\s*\)\s*\{\s*delete\s+g_license\s*;\s*g_license\s*=\s*NULL\s*;\s*\}\s*\n?', '', content)
    content = re.sub(r'if\s*\(\s*g_licenseValidator\s*!=\s*NULL\s*\)\s*\n?\s*\{\s*\n?\s*delete\s+g_licenseValidator\s*;\s*\n?\s*g_licenseValidator\s*=\s*NULL\s*;\s*\n?\s*\}\s*\n?', '', content)
    
    # Update OnTick to use PeriodicLicenseCheck
    content = re.sub(r'if\s*\(\s*!\s*g_license\.PeriodicCheck\s*\(\s*\)\s*\)\s*return\s*;', 
                     '''if(!PeriodicLicenseCheck())
   {
      Print("License expired or invalid: ", g_licenseError);
      ExpertRemove();
      return;
   }''', content)
    
    # Clean up any double newlines
    content = re.sub(r'\n{3,}', '\n\n', content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"UPDATED: {os.path.basename(filepath)}")
    return True

def main():
    """Main function to process all MQL5 EAs"""
    updated = 0
    skipped = 0
    
    for filename in sorted(os.listdir(MQL5_EXPERTS_DIR)):
        if filename.endswith('.mq5'):
            filepath = os.path.join(MQL5_EXPERTS_DIR, filename)
            if process_file(filepath):
                updated += 1
            else:
                skipped += 1
    
    print(f"\nCompleted: {updated} updated, {skipped} skipped")

if __name__ == "__main__":
    main()
