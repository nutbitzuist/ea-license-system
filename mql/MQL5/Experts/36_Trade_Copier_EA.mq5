//+------------------------------------------------------------------+
//|                                          36_Trade_Copier_EA.mq5   |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| UTILITY: Local Trade Copier                                        |
//|                                                                    |
//| DESCRIPTION:                                                       |
//| Copies trades between MT5 terminals on the same computer.         |
//| Can work as Master (sender) or Slave (receiver).                  |
//|                                                                    |
//| FEATURES:                                                          |
//| - Copy trades between accounts                                    |
//| - Lot size multiplier                                             |
//| - Reverse copy option                                             |
//| - Symbol mapping                                                   |
//| - Copy SL/TP or set custom                                        |
//|                                                                    |
//| HOW TO USE:                                                        |
//| 1. Run as MASTER on source account                                |
//| 2. Run as SLAVE on destination account                            |
//| 3. Both must use same file path                                   |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"
#property strict

#include <EALicense/LicenseValidator.mqh>

enum COPIER_MODE { MODE_MASTER, MODE_SLAVE };

input string      EA_ApiKey = "";
input string      EA_ApiSecret = "";
input COPIER_MODE Mode = MODE_SLAVE;
input string      SignalFile = "trade_signal.txt";
input double      LotMultiplier = 1.0;
input bool        ReverseTrades = false;
input bool        CopySLTP = true;
input int         CustomSL = 0;          // Custom SL pips (0 = copy from master)
input int         CustomTP = 0;          // Custom TP pips (0 = copy from master)
input int         MagicNumber = 100036;

CLicenseValidator* g_license;
string g_lastSignal = "";

int OnInit()
{
   g_license = new CLicenseValidator();
   g_license.Initialize(EA_ApiKey, EA_ApiSecret, "trade_copier_ea", "1.0.0");
   if(!g_license.ValidateLicense()) { Print("License failed"); return INIT_FAILED; }
   
   Print("Trade Copier EA initialized as ", Mode == MODE_MASTER ? "MASTER" : "SLAVE");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_license != NULL) { delete g_license; g_license = NULL; }
}

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   if(Mode == MODE_MASTER)
      MasterLogic();
   else
      SlaveLogic();
}

void MasterLogic()
{
   // Check for new positions and write to file
   string signal = "";
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      
      string sym = PositionGetString(POSITION_SYMBOL);
      int type = (int)PositionGetInteger(POSITION_TYPE);
      double lot = PositionGetDouble(POSITION_VOLUME);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      ulong ticket = PositionGetTicket(i);
      
      signal += IntegerToString(ticket) + "," + sym + "," + IntegerToString(type) + "," + 
                DoubleToString(lot, 2) + "," + DoubleToString(sl, 5) + "," + DoubleToString(tp, 5) + ";";
   }
   
   if(signal != g_lastSignal)
   {
      WriteSignal(signal);
      g_lastSignal = signal;
   }
}

void SlaveLogic()
{
   string signal = ReadSignal();
   if(signal == "" || signal == g_lastSignal) return;
   
   g_lastSignal = signal;
   
   // Parse and execute signals
   string positions[];
   StringSplit(signal, ';', positions);
   
   // Track which master tickets we've seen
   ulong masterTickets[];
   ArrayResize(masterTickets, 0);
   
   for(int i = 0; i < ArraySize(positions); i++)
   {
      if(StringLen(positions[i]) < 5) continue;
      
      string parts[];
      StringSplit(positions[i], ',', parts);
      if(ArraySize(parts) < 6) continue;
      
      ulong masterTicket = (ulong)StringToInteger(parts[0]);
      string sym = parts[1];
      int type = (int)StringToInteger(parts[2]);
      double lot = StringToDouble(parts[3]) * LotMultiplier;
      double sl = StringToDouble(parts[4]);
      double tp = StringToDouble(parts[5]);
      
      ArrayResize(masterTickets, ArraySize(masterTickets) + 1);
      masterTickets[ArraySize(masterTickets) - 1] = masterTicket;
      
      // Check if we already have this position
      if(!HasCopiedPosition(masterTicket))
      {
         if(ReverseTrades) type = (type == 0) ? 1 : 0;
         OpenCopiedPosition(sym, type, lot, sl, tp, masterTicket);
      }
   }
   
   // Close positions that master closed
   CloseMissingPositions(masterTickets);
}

bool HasCopiedPosition(ulong masterTicket)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         string comment = PositionGetString(POSITION_COMMENT);
         if(StringFind(comment, "MT" + IntegerToString(masterTicket)) >= 0)
            return true;
      }
   }
   return false;
}

void OpenCopiedPosition(string sym, int type, double lot, double sl, double tp, ulong masterTicket)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   double price = (type == 0) ? SymbolInfoDouble(sym, SYMBOL_ASK) : SymbolInfoDouble(sym, SYMBOL_BID);
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = sym;
   request.volume = NormalizeDouble(lot, 2);
   request.type = (type == 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price = price;
   
   if(CopySLTP)
   {
      request.sl = sl;
      request.tp = tp;
   }
   else if(CustomSL > 0 || CustomTP > 0)
   {
      if(CustomSL > 0)
         request.sl = (type == 0) ? price - CustomSL * point : price + CustomSL * point;
      if(CustomTP > 0)
         request.tp = (type == 0) ? price + CustomTP * point : price - CustomTP * point;
   }
   
   request.magic = MagicNumber;
   request.comment = "MT" + IntegerToString(masterTicket);
   request.deviation = 10;
   
   if(OrderSend(request, result))
      Print("Copied trade: ", sym, " ", (type == 0 ? "BUY" : "SELL"), " ", lot);
}

void CloseMissingPositions(ulong &masterTickets[])
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      bool found = false;
      
      for(int j = 0; j < ArraySize(masterTickets); j++)
      {
         if(StringFind(comment, "MT" + IntegerToString(masterTickets[j])) >= 0)
         {
            found = true;
            break;
         }
      }
      
      if(!found)
      {
         // Master closed this position
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         request.action = TRADE_ACTION_DEAL;
         request.position = PositionGetTicket(i);
         request.symbol = PositionGetString(POSITION_SYMBOL);
         request.volume = PositionGetDouble(POSITION_VOLUME);
         request.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
         request.price = request.type == ORDER_TYPE_BUY ? 
            SymbolInfoDouble(request.symbol, SYMBOL_ASK) : SymbolInfoDouble(request.symbol, SYMBOL_BID);
         request.deviation = 10;
         OrderSend(request, result);
      }
   }
}

void WriteSignal(string signal)
{
   int handle = FileOpen(SignalFile, FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(handle != INVALID_HANDLE)
   {
      FileWriteString(handle, signal);
      FileClose(handle);
   }
}

string ReadSignal()
{
   string signal = "";
   int handle = FileOpen(SignalFile, FILE_READ|FILE_TXT|FILE_COMMON);
   if(handle != INVALID_HANDLE)
   {
      signal = FileReadString(handle);
      FileClose(handle);
   }
   return signal;
}
//+------------------------------------------------------------------+
