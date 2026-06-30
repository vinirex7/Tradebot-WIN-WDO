//+------------------------------------------------------------------+
//|  VerificarAmbiente.mq5 — Diagnóstico pré-live da conta XP       |
//|  Execute ANTES de ativar o EA no ambiente real                   |
//+------------------------------------------------------------------+
#property script_show_inputs

input string VerSimbolo1 = "WINFUT";
input string VerSimbolo2 = "WDOFUT";

void OnStart()
{
   string sep = "═══════════════════════════════════";
   Print(sep); Print("   VERIFICAÇÃO DE AMBIENTE — B3 BOT   "); Print(sep);

   Print("▶ CONTA:");
   Print("  Nome:      ", AccountInfoString(ACCOUNT_NAME));
   Print("  Login:     ", AccountInfoInteger(ACCOUNT_LOGIN));
   Print("  Servidor:  ", AccountInfoString(ACCOUNT_SERVER));
   Print("  Saldo:     R$ ", AccountInfoDouble(ACCOUNT_BALANCE));
   Print("  Tipo:      ", AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO?"DEMO":"REAL");
   Print("  Trade: ", (bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)?"OK":"DESABILITADO");
   Print("  EA:    ", (bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT)?"OK":"DESABILITADO — Habilite em Ferramentas > Opções > Expert Advisors");

   string syms[] = {VerSimbolo1, VerSimbolo2};
   for(int i=0;i<2;i++)
   {
      string s=syms[i];
      Print(""); Print("▶ SÍMBOLO: ", s);
      bool sel=SymbolSelect(s,true);
      Print("  Disponível: ", sel?"SIM":"NÃO — verifique Ctrl+U");
      if(!sel) continue;
      Print(StringFormat("  Bid/Ask:  %.2f / %.2f",SymbolInfoDouble(s,SYMBOL_BID),SymbolInfoDouble(s,SYMBOL_ASK)));
      Print(StringFormat("  Tick Val: R$ %.4f",SymbolInfoDouble(s,SYMBOL_TRADE_TICK_VALUE)));
      Print(StringFormat("  Margem 1ct: R$ %.2f",SymbolInfoDouble(s,SYMBOL_MARGIN_INITIAL)));
      double pnl1pt=(SymbolInfoDouble(s,SYMBOL_POINT)/SymbolInfoDouble(s,SYMBOL_TRADE_TICK_SIZE))*SymbolInfoDouble(s,SYMBOL_TRADE_TICK_VALUE);
      Print(StringFormat("  R$/ponto (1ct): R$ %.2f",pnl1pt));
   }

   Print(""); Print("▶ TERMINAL:");
   Print("  Build: ",TerminalInfoInteger(TERMINAL_BUILD));
   Print("  Trade: ",TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)?"OK":"BLOQUEADO");
   Print("  Ping: ",TerminalInfoInteger(TERMINAL_PING_LAST)," ms");
   Print("  Path: ",TerminalInfoString(TERMINAL_DATA_PATH));
   Print(sep);

   bool tradeOK=(bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)&&(bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
   bool symsOK=SymbolInfoDouble(VerSimbolo1,SYMBOL_ASK)>0&&SymbolInfoDouble(VerSimbolo2,SYMBOL_ASK)>0;
   if(tradeOK&&symsOK) Alert("Ambiente OK. Pronto para operar!");
   else Alert("Pendências encontradas. Revise o log (Ctrl+T > Experts).");
}
