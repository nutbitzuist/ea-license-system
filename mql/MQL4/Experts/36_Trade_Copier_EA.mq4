//+------------------------------------------------------------------+
//|                                          36_Trade_Copier_EA.mq4   |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
//| UTILITY: Local Trade Copier (Master/Slave)                        |
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

void OnDeinit(const int reason) { if(g_license != NULL) { delete g_license; g_license = NULL; } }

void OnTick()
{
   if(!g_license.PeriodicCheck()) return;
   
   if(Mode == MODE_MASTER) MasterLogic();
   else SlaveLogic();
}

void MasterLogic()
{
   string signal = "";
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      signal += IntegerToString(OrderTicket()) + "," + OrderSymbol() + "," + IntegerToString(OrderType()) + "," +
                DoubleToString(OrderLots(), 2) + "," + DoubleToString(OrderStopLoss(), 5) + "," + 
                DoubleToString(OrderTakeProfit(), 5) + ";";
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
   
   string positions[];
   StringSplit(signal, ';', positions);
   
   int masterTickets[];
   ArrayResize(masterTickets, 0);
   
   for(int i = 0; i < ArraySize(positions); i++)
   {
      if(StringLen(positions[i]) < 5) continue;
      
      string parts[];
      StringSplit(positions[i], ',', parts);
      if(ArraySize(parts) < 6) continue;
      
      int masterTicket = (int)StringToInteger(parts[0]);
      string sym = parts[1];
      int type = (int)StringToInteger(parts[2]);
      double lot = StringToDouble(parts[3]) * LotMultiplier;
      double sl = StringToDouble(parts[4]);
      double tp = StringToDouble(parts[5]);
      
      ArrayResize(masterTickets, ArraySize(masterTickets) + 1);
      masterTickets[ArraySize(masterTickets) - 1] = masterTicket;
      
      if(!HasCopiedOrder(masterTicket))
      {
         if(ReverseTrades) type = (type == OP_BUY) ? OP_SELL : OP_BUY;
         OpenCopiedOrder(sym, type, lot, sl, tp, masterTicket);
      }
   }
   
   CloseMissingOrders(masterTickets);
}

bool HasCopiedOrder(int masterTicket)
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() == MagicNumber)
      {
         if(StringFind(OrderComment(), "MT" + IntegerToString(masterTicket)) >= 0)
            return true;
      }
   }
   return false;
}

void OpenCopiedOrder(string sym, int type, double lot, double sl, double tp, int masterTicket)
{
   double price = (type == OP_BUY) ? MarketInfo(sym, MODE_ASK) : MarketInfo(sym, MODE_BID);
   if(!CopySLTP) { sl = 0; tp = 0; }
   OrderSend(sym, type, NormalizeDouble(lot, 2), price, 10, sl, tp, "MT" + IntegerToString(masterTicket), MagicNumber, 0, clrNONE);
}

void CloseMissingOrders(int &masterTickets[])
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      
      bool found = false;
      for(int j = 0; j < ArraySize(masterTickets); j++)
      {
         if(StringFind(OrderComment(), "MT" + IntegerToString(masterTickets[j])) >= 0)
         { found = true; break; }
      }
      
      if(!found) OrderClose(OrderTicket(), OrderLots(), (OrderType() == OP_BUY) ? Bid : Ask, 10, clrNONE);
   }
}

void WriteSignal(string signal)
{
   int handle = FileOpen(SignalFile, FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(handle != INVALID_HANDLE) { FileWriteString(handle, signal); FileClose(handle); }
}

string ReadSignal()
{
   string signal = "";
   int handle = FileOpen(SignalFile, FILE_READ|FILE_TXT|FILE_COMMON);
   if(handle != INVALID_HANDLE) { signal = FileReadString(handle); FileClose(handle); }
   return signal;
}
//+------------------------------------------------------------------+
