import os
import re

EXPERTS_DIR = "/Users/nut/Downloads/ea-license-system/mql/MQL5/Experts"

# Code Blocks to Inject
INPUTS_BLOCK = """
//--- MONEY MANAGEMENT ---
input bool     UseMoneyManagement = true;   // Use Risk % for Lot Size
input double   RiskPercent        = 2.0;    // Risk per trade (%)

//--- TRAILING STOP & BREAK EVEN ---
input bool     UseTrailingStop    = true;   // Enable Trailing Stop
input int      TrailingStop       = 50;     // Trailing Stop (points)
input int      TrailingStep       = 10;     // Trailing Step (points)

input bool     UseBreakEven       = true;   // Enable Break Even
input int      BreakEvenTrigger   = 30;     // Points profit to trigger BE
input int      BreakEvenLock      = 5;      // Points to lock in profit

//--- FORWARD DECLARATIONS ---
void ManagePositions();
double GetLotSize(double slPoints);
"""

HELPER_FUNCTIONS_BLOCK = """
//+------------------------------------------------------------------+
//| Calculate Lot Size based on Risk %                               |
//+------------------------------------------------------------------+
double GetLotSize(double slPoints)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(tickSize == 0 || point == 0) return LotSize;
   
   // Calculate risk amount in money
   double riskMoney = accountBalance * (RiskPercent / 100.0);
   
   // Money per lot for 1 point movement = (TickValue / TickSize) * Point
   double moneyPerPointPerLot = (tickValue / tickSize) * point;
   
   if(moneyPerPointPerLot == 0) return LotSize;
   
   // Calculate lots: RiskMoney / (SL_Points * MoneyPerPointPerLot)
   double calculatedLots = riskMoney / (slPoints * moneyPerPointPerLot);
   
   // Normalize lots
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   calculatedLots = MathFloor(calculatedLots / stepLot) * stepLot;
   
   if(calculatedLots < minLot) calculatedLots = minLot;
   if(calculatedLots > maxLot) calculatedLots = maxLot;
   
   return calculatedLots;
}

//+------------------------------------------------------------------+
//| Manage Positions (Trailing Stop & Break Even)                    |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      // Data
      long type = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      //--- BREAK EVEN ---
      if(UseBreakEven)
      {
         if(type == POSITION_TYPE_BUY)
         {
            if(currentPrice - openPrice > BreakEvenTrigger * point)
            {
               double newSL = openPrice + BreakEvenLock * point;
               if(newSL > currentSL && (currentSL == 0 || newSL > currentSL))
               {
                  MqlTradeRequest request = {};
                  MqlTradeResult result = {};
                  request.action = TRADE_ACTION_SLTP;
                  request.position = ticket;
                  request.sl = newSL;
                  request.tp = PositionGetDouble(POSITION_TP);
                  request.symbol = _Symbol;
                  if(!OrderSend(request, result))
                     Print("Failed to move SL/TP: ", GetLastError());
               }
            }
         }
         else // SELL
         {
            if(openPrice - currentPrice > BreakEvenTrigger * point)
            {
               double newSL = openPrice - BreakEvenLock * point;
               if(newSL < currentSL || currentSL == 0)
               {
                  MqlTradeRequest request = {};
                  MqlTradeResult result = {};
                  request.action = TRADE_ACTION_SLTP;
                  request.position = ticket;
                  request.sl = newSL;
                  request.tp = PositionGetDouble(POSITION_TP);
                  request.symbol = _Symbol;
                  if(!OrderSend(request, result))
                     Print("Failed to move SL/TP: ", GetLastError());
               }
            }
         }
      }
      
      //--- TRAILING STOP ---
      if(UseTrailingStop)
      {
         if(type == POSITION_TYPE_BUY)
         {
            if(currentPrice - openPrice > TrailingStop * point)
            {
               double newSL = currentPrice - TrailingStop * point;
               if(newSL > currentSL + TrailingStep * point)
               {
                  MqlTradeRequest request = {};
                  MqlTradeResult result = {};
                  request.action = TRADE_ACTION_SLTP;
                  request.position = ticket;
                  request.sl = newSL;
                  request.tp = PositionGetDouble(POSITION_TP);
                  request.symbol = _Symbol;
                  if(!OrderSend(request, result))
                     Print("Failed to move SL/TP: ", GetLastError());
               }
            }
         }
         else // SELL
         {
            if(openPrice - currentPrice > TrailingStop * point)
            {
               double newSL = currentPrice + TrailingStop * point;
               if(newSL < currentSL - TrailingStep * point || currentSL == 0)
               {
                  MqlTradeRequest request = {};
                  MqlTradeResult result = {};
                  request.action = TRADE_ACTION_SLTP;
                  request.position = ticket;
                  request.sl = newSL;
                  request.tp = PositionGetDouble(POSITION_TP);
                  request.symbol = _Symbol;
                  if(!OrderSend(request, result))
                     Print("Failed to move SL/TP: ", GetLastError());
               }
            }
         }
      }
   }
}
"""

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    filename = os.path.basename(filepath)
    print(f"Processing {filename}...")

    # 1. Insert Inputs and Forward Declarations (Only if missing)
    if "UseMoneyManagement" not in content:
        # Find the last "input" line
        last_input_idx = -1
        for match in re.finditer(r'input\s+.*?;', content):
            last_input_idx = match.end()
        
        if last_input_idx != -1:
            # Check if there is a newline after the last input
            next_char_idx = last_input_idx
            while next_char_idx < len(content):
                if content[next_char_idx] == '\n':
                    next_char_idx += 1
                    break
                next_char_idx += 1
                
            content = content[:next_char_idx] + INPUTS_BLOCK + content[next_char_idx:]
            print(f"  > Added Inputs")
    
    # 2. Inject Logic in OnTick (if not already there)
    # Be robust about finding OnTick start
    on_tick_pattern = r'(void\s+OnTick\s*\([^)]*\)\s*\{)'
    match = re.search(on_tick_pattern, content, re.DOTALL)
    
    if match:
        on_tick_start = match.end()
        # Check if ManagePositions() is called in the first 500 chars after OnTick start
        # This prevents confusing it with Forward Declaration which is at top of file
        on_tick_body_snippet = content[on_tick_start:on_tick_start+500]
        
        if "ManagePositions();" not in on_tick_body_snippet:
            # Insert call at the start of the function
            content = content[:on_tick_start] + "\n   // Manage open positions (Trailing Stop & BreakEven)\n   ManagePositions();" + content[on_tick_start:]
            print(f"  > Added ManagePositions() call to OnTick")
    else:
         print(f"  WARNING: Could not find 'void OnTick() {{' pattern in {filename}")

    # 3. Update OpenPosition Logic
    if "GetLotSize(riskSL)" not in content:
        lot_assignment_pattern = r'request\.volume\s*=\s*(LotSize|.*_LotSize);'
        
        new_lot_logic = """
   // Calculate Lot Size
   double tradeVolume = LotSize;
   if(UseMoneyManagement)
   {
      double riskSL = StopLoss; // Risk distance in points
      if(riskSL <= 0) riskSL = 100; // Default safety
      tradeVolume = GetLotSize(riskSL);
   }
   
   request.volume = tradeVolume;"""

        if re.search(lot_assignment_pattern, content):
            content = re.sub(lot_assignment_pattern, new_lot_logic, content)
            print(f"  > Updated OpenPosition lot calculation")

    # 4. Append Helper Functions
    # Check if the Helper Function BODY is present. 
    # The forward declaration "void ManagePositions();" might be there, so we check for the definition header without semicolon
    if "void ManagePositions()\n{" not in content and "void ManagePositions() \n{" not in content and "void ManagePositions(){" not in content:
        # Check if we didn't already append it (double check unique string inside)
        if "double moneyPerPointPerLot =" not in content:
            content += "\n" + HELPER_FUNCTIONS_BLOCK
            print(f"  > Appended Helper Functions")

    # Write back
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

def main():
    if not os.path.exists(EXPERTS_DIR):
        print("Experts directory not found!")
        return

    files = [f for f in os.listdir(EXPERTS_DIR) if f.endswith('.mq5')]
    files.sort()

    for filename in files:
        if filename == "01_MA_Crossover_EA.mq5":
            continue
        
        filepath = os.path.join(EXPERTS_DIR, filename)
        try:
            process_file(filepath)
        except Exception as e:
            print(f"Error processing {filename}: {str(e)}")

if __name__ == "__main__":
    main()
