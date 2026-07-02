//+------------------------------------------------------------------+
//| Script: relatório diário de P&L do Bot (Magic 202601)           |
//+------------------------------------------------------------------+
#property script_show_inputs

void OnStart()
  {
   datetime hoje = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   HistorySelect(hoje, TimeCurrent());
   double total_profit = 0;
   int    total_trades = 0;
   int    wins = 0, losses = 0;

   for(int i = 0; i < HistoryDealsTotal(); i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != 202601) continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      total_profit += profit;
      total_trades++;
      if(profit > 0) wins++; else losses++;
     }

   string msg = StringFormat(
      "=== RELATÓRIO DIÁRIO — DUAL TREND SCALPER ===\n"
      "Data: %s\n"
      "Total de trades: %d\n"
      "Vencedores: %d | Perdedores: %d\n"
      "Taxa de acerto: %.1f%%\n"
      "P&L líquido: R$ %.2f\n"
      "=============================================",
      TimeToString(hoje, TIME_DATE),
      total_trades, wins, losses,
      total_trades > 0 ? (double)wins / total_trades * 100 : 0,
      total_profit
   );
   Print(msg);
   MessageBox(msg, "Relatório Diário Bot", MB_OK | MB_ICONINFORMATION);
  }
//+------------------------------------------------------------------+