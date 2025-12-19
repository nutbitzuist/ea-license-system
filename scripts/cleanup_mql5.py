#!/usr/bin/env python3
"""
Cleanup script to remove remnant license code from MQL5 EAs.
"""

import os
import re

MQL5_EXPERTS_DIR = "/Users/nut/Downloads/ea-license-system/mql/MQL5/Experts"

def cleanup_file(filepath):
    """Clean up remnant license code from a file"""
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Remove CLicenseValidator* g_license; line
    content = re.sub(r'CLicenseValidator\*?\s+g_license\s*;\s*\n', '', content)
    content = re.sub(r'CLicenseValidator\s+\*g_licenseValidator\s*=\s*NULL\s*;\s*\n', '', content)
    
    # Remove input string EA_ApiKey = ""; and EA_ApiSecret = "";
    content = re.sub(r'input string\s+EA_ApiKey\s*=\s*""\s*;\s*\n', '', content)
    content = re.sub(r'input string\s+EA_ApiSecret\s*=\s*""\s*;\s*\n', '', content)
    content = re.sub(r'input string\s+InpApiKey\s*=\s*""\s*;\s*[^\n]*\n', '', content)
    content = re.sub(r'input string\s+InpApiSecret\s*=\s*""\s*;\s*[^\n]*\n', '', content)
    
    # Fix the headers string (should use \r\n not actual newline)
    content = content.replace('"Content-Type: application/json\r\nX-API-Key: %s"', 
                               '"Content-Type: application/json\\r\\nX-API-Key: %s"')
    
    # Fix: string headers = StringFormat("Content-Type: application/json\r\n
    # X-API-Key: %s", LicenseKey);
    # Should be on one line
    content = re.sub(
        r'string headers = StringFormat\("Content-Type: application/json\\r\\n\s*X-API-Key: %s", LicenseKey\);',
        'string headers = StringFormat("Content-Type: application/json\\\\r\\\\nX-API-Key: %s", LicenseKey);',
        content
    )
    
    # Another pattern for the headers fix
    content = re.sub(
        r'string headers = StringFormat\("Content-Type: application/json\r\nX-API-Key: %s", LicenseKey\);',
        'string headers = StringFormat("Content-Type: application/json\\\\r\\\\nX-API-Key: %s", LicenseKey);',
        content
    )
    
    # Fix bool g_isLicensed = false; that might be duplicated
    # Only keep the one that's part of the LICENSE VALIDATOR section
    
    # Remove empty lines after //--- Global variables if next line is empty
    content = re.sub(r'(//--- Global variables\n)\n+', r'\1', content)
    
    # Clean up excessive empty lines
    content = re.sub(r'\n{3,}', '\n\n', content)
    
    if content != original_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"CLEANED: {os.path.basename(filepath)}")
        return True
    else:
        print(f"OK: {os.path.basename(filepath)}")
        return False

def main():
    """Main function to clean all MQL5 EAs"""
    cleaned = 0
    ok = 0
    
    for filename in sorted(os.listdir(MQL5_EXPERTS_DIR)):
        if filename.endswith('.mq5'):
            filepath = os.path.join(MQL5_EXPERTS_DIR, filename)
            if cleanup_file(filepath):
                cleaned += 1
            else:
                ok += 1
    
    print(f"\nCompleted: {cleaned} cleaned, {ok} already OK")

if __name__ == "__main__":
    main()
