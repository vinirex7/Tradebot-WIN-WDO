//+------------------------------------------------------------------+
//|  VerificarAmbiente.mq5 — Diagnóstico pré-live DualTrendScalper  |
//|  Execute ANTES de colocar o bot em operação real                |
//+------------------------------------------------------------------+
#property copyright "vinirex7"
#property version   "1.00"
#property script_show_inputs false

void OnStart()
{
   Print("========================================");
   Print("  VERIFICACAO DE AMBIENTE - DTS v1.00");
   Print("========================================");

   // Conta
   Print("--- CONTA ---");
   Print("Login   : ", AccountInfoInteger(ACCOUNT_LOGIN));
   Print("Servidor: ", AccountInfoString(ACCOUNT_SERVER));
   Print("Saldo   : R$ ", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));
   Print("Margem L: R$ ", DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE),2));
   Print("Moeda   : ", AccountInfoString(ACCOUNT_CURRENCY));
   Print("Trade   : ", AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) ? "PERMITIDO" : "BLOQUEADO");
   Print("AutoTrd : ", AccountInfoInteger(ACCOUNT_TRADE_EXPERT)  ? "PERMITIDO" : "BLOQUEADO");

   // Terminal
   Print("--- TERMINAL ---");
   Print("Versao  : ", TerminalInfoString(TERMINAL_NAME));
   Print("Build   : ", TerminalInfoInteger(TERMINAL_BUILD));
   Print("AutoTrd : ", TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ? "SIM" : "NAO");
   Print("Conectado: ",TerminalInfoInteger(TERMINAL_CONNECTED)    ? "SIM" : "NAO");

   // Símbolos
   string syms[] = {"WINFUT", "WDOFUT"};
   for(int i = 0; i < 2; i++)
   {
      string s = syms[i];
      bool   ok = SymbolSelect(s, true);
      double bid = SymbolInfoDouble(s, SYMBOL_BID);
      double ask = SymbolInfoDouble(s, SYMBOL_ASK);
      double tv  = SymbolInfoDouble(s, SYMBOL_TRADE_TICK_VALUE);
      double ts  = SymbolInfoDouble(s, SYMBOL_TRADE_TICK_SIZE);
      double marg = 0;
      OrderCalcMargin(ORDER_TYPE_BUY, s, 1, ask, marg);
      Print(StringFormat("--- %s | OK:%s BID:%.0f ASK:%.0f TV:%.2f TS:%.0f Margem1L:R$%.0f ---",
            s, ok?"SIM":"NAO", bid, ask, tv, ts, marg));
   }

   // Ping estimado
   Print("--- LATENCIA (estimativa) ---");
   uint t0 = GetTickCount();
   SymbolInfoDouble("WINFUT", SYMBOL_BID);
   uint lat = GetTickCount() - t0;
   Print(StringFormat("Latencia estimada: %d ms %s", lat,
         lat < 50 ? "[OK - EXCELENTE]" : lat < 150 ? "[OK]" : "[ATENCAO - ALTA]"));

   Print("======================================");
   Print("  VERIFICACAO CONCLUIDA");
   Print("  Servidor XP: mt5.xpi.com.br:443");
   Print("======================================");
}
