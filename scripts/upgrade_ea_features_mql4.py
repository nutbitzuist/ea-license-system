import os
import re

EXPERTS_DIR = "/Users/nut/Downloads/ea-license-system/mql/MQL4/Experts"

# MQL4 Inputs Code Block
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

# MQL4 Helper Functions Block
HELPER_FUNCTIONS_BLOCK = """
//+------------------------------------------------------------------+
//| Calculate Lot Size based on Risk %                               |
//+------------------------------------------------------------------+
double GetLotSize(double slPoints)
{
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   double point = Point;
   double accountBalance = AccountBalance();
   
   if(tickSize == 0 || point == 0 || tickValue == 0) return LotSize;
   
   // Calculate risk amount in money
   double riskMoney = accountBalance * (RiskPercent / 100.0);
   
   // Money per lot for 1 point movement = (TickValue / TickSize) * Point
   double moneyPerPointPerLot = (tickValue / tickSize) * point;
   
   if(moneyPerPointPerLot == 0) return LotSize;
   
   // Calculate lots: RiskMoney / (SL_Points * MoneyPerPointPerLot)
   double calculatedLots = riskMoney / (slPoints * moneyPerPointPerLot);
   
   // Normalize lots
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double stepLot = MarketInfo(Symbol(), MODE_LOTSTEP);
   
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
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol()) continue;
      
      // Data
      int type = OrderType();
      double openPrice = OrderOpenPrice();
      double currentSL = OrderStopLoss();
      double currentPrice = (type == OP_BUY) ? Bid : Ask;
      double point = Point;
      
      //--- BREAK EVEN ---
      if(UseBreakEven)
      {
         if(type == OP_BUY)
         {
            if(currentPrice - openPrice > BreakEvenTrigger * point)
            {
               double newSL = openPrice + BreakEvenLock * point;
               if(newSL > currentSL && (currentSL == 0 || newSL > currentSL))
               {
                  if(!OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE))
                     Print("Failed to move SL to BE: ", GetLastError());
               }
            }
         }
         else if(type == OP_SELL)
         {
            if(openPrice - currentPrice > BreakEvenTrigger * point)
            {
               double newSL = openPrice - BreakEvenLock * point;
               if(newSL < currentSL || currentSL == 0)
               {
                  if(!OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE))
                     Print("Failed to move SL to BE: ", GetLastError());
               }
            }
         }
      }
      
      //--- TRAILING STOP ---
      if(UseTrailingStop)
      {
         if(type == OP_BUY)
         {
            if(currentPrice - openPrice > TrailingStop * point)
            {
               double newSL = currentPrice - TrailingStop * point;
               if(newSL > currentSL + TrailingStep * point)
               {
                  if(!OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE))
                     Print("Failed to move Trailing SL: ", GetLastError());
               }
            }
         }
         else if(type == OP_SELL)
         {
            if(openPrice - currentPrice > TrailingStop * point)
            {
               double newSL = currentPrice + TrailingStop * point;
               if(newSL < currentSL - TrailingStep * point || currentSL == 0)
               {
                  if(!OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE))
                     Print("Failed to move Trailing SL: ", GetLastError());
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

    # 1. Insert Inputs and Forward Declarations
    if "UseMoneyManagement" not in content:
        # Find the last "input" line
        last_input_idx = -1
        for match in re.finditer(r'input\s+.*?;', content):
            last_input_idx = match.end()
        
        if last_input_idx != -1:
            next_char_idx = last_input_idx
            while next_char_idx < len(content):
                if content[next_char_idx] == '\n':
                    next_char_idx += 1
                    break
                next_char_idx += 1
                
            content = content[:next_char_idx] + INPUTS_BLOCK + content[next_char_idx:]
            print(f"  > Added Inputs")
        else:
             print(f"  WARNING: No inputs found in {filename}")

    # 2. Inject Logic in OnTick
    # Be robust about finding OnTick start
    on_tick_pattern = r'(void\s+OnTick\s*\([^)]*\)\s*\{)'
    match = re.search(on_tick_pattern, content, re.DOTALL)
    
    if match:
        on_tick_start = match.end()
        on_tick_body_snippet = content[on_tick_start:on_tick_start+500]
        
        if "ManagePositions();" not in on_tick_body_snippet:
            content = content[:on_tick_start] + "\n   // Manage open positions (Trailing Stop & BreakEven)\n   ManagePositions();" + content[on_tick_start:]
            print(f"  > Added ManagePositions() call to OnTick")
    else:
         print(f"  WARNING: Could not find 'void OnTick() {{' pattern in {filename}")

    # 3. Update OpenOrder/OrderSend Logic
    # MQL4 OrderSend
    if "GetLotSize(riskSL)" not in content:
        # Match OrderSend call: OrderSend(..., LotSize, ...)
        # We need to capture the whole line to replace it properly
        # pattern: int ticket = OrderSend(...);
        
        order_send_pattern = r'(int\s+\w+\s*=\s*OrderSend\s*\(.*?\);)'
        match = re.search(order_send_pattern, content, re.DOTALL) # use DOTALL if OrderSend spans lines? better safe
        
        if match:
            original_line = match.group(1)
            if "LotSize" in original_line:
                # Construct Replacement
                new_lot_logic = """
   // Calculate Lot Size
   double tradeVolume = LotSize;
   if(UseMoneyManagement)
   {
      double riskSL = StopLoss; // Risk distance in points
      if(riskSL <= 0) riskSL = 100; // Default safety
      tradeVolume = GetLotSize(riskSL);
   }

"""
                # Replace LotSize with tradeVolume in the OrderSend call
                modified_line = original_line.replace("LotSize", "tradeVolume")
                
                # Combine
                replacement = new_lot_logic + "   " + modified_line
                
                content = content.replace(original_line, replacement)
                print(f"  > Updated OrderSend lot calculation")
            else:
                 print(f"  WARNING: 'LotSize' variable not found in OrderSend call in {filename}")

    # 4. Append Helper Functions
    # Check if "double GetLotSize" definition exists
    if "double GetLotSize(double slPoints)\n{" not in content and "double GetLotSize(double slPoints) \n{" not in content:
        # Avoid duplicate append
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

    files = [f for f in os.listdir(EXPERTS_DIR) if f.endswith('.mq4')]
    files.sort()

    for filename in files:
        if filename == "01_MA_Crossover_EA.mq4":
            continue
        
        filepath = os.path.join(EXPERTS_DIR, filename)
        try:
            process_file(filepath)
        except Exception as e:
            print(f"Error processing {filename}: {str(e)}")

if __name__ == "__main__":
    main()
