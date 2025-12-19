import os
import re

MQL4_DIR = "/Users/nut/Downloads/ea-license-system/mql/MQL4"
MQL5_DIR = "/Users/nut/Downloads/ea-license-system/mql/MQL5"

# Branding replacements
REPLACEMENTS = [
    # Copyright
    ('"EA License System"', '"My Algo Stack"'),
    ("EA License System", "My Algo Stack"),
    # Header comments
    ("EA License Management System", "My Algo Stack - Trading Infrastructure"),
    # Domain migration - NEW!
    ("ea-license-system-one.vercel.app", "myalgostack.com"),
]

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content
    
    for old, new in REPLACEMENTS:
        content = content.replace(old, new)
    
    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False

def process_directory(directory):
    count = 0
    for root, dirs, files in os.walk(directory):
        for filename in files:
            if filename.endswith(('.mq4', '.mq5', '.mqh')):
                filepath = os.path.join(root, filename)
                if process_file(filepath):
                    print(f"Updated: {filename}")
                    count += 1
    return count

def main():
    print("=== Rebranding MQL Files to 'My Algo Stack' ===\n")
    
    print("Processing MQL4 files...")
    count4 = process_directory(MQL4_DIR)
    
    print("\nProcessing MQL5 files...")
    count5 = process_directory(MQL5_DIR)
    
    print(f"\n=== Done! Updated {count4 + count5} files ===")

if __name__ == "__main__":
    main()
