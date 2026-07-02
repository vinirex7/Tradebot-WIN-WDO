//+------------------------------------------------------------------+
//| Script de emergência: fecha TODAS as posições do Magic 202601   |
//+------------------------------------------------------------------+
#property script_show_inputs
#include <Trade\Trade.mqh>

void OnStart()
  {
   CTrade trade;
   trade.SetExpertMagicNumber(202601);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      string sym = PositionGetSymbol(i);
      if(PositionGetInteger(POSITION_MAGIC) == 202601)
        {
         trade.PositionClose(PositionGetInteger(POSITION_TICKET));
         Print("Fechada: ", sym, " ticket:", PositionGetInteger(POSITION_TICKET));
        }
     }
   Print("=== Todas as posições do Bot fechadas ===");
  }
//+------------------------------------------------------------------+