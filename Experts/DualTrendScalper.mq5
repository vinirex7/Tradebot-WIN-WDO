//+------------------------------------------------------------------+
//|  DualTrendScalper.mq5                                           |
//|  Bot de Day Trade WIN & WDO — B3                                |
//|  Plataforma: MetaTrader 5 | Timeframe: M5 | Filtro: M15        |
//|  Corretora : XP Investimentos (mt5.xpi.com.br:443)             |
//|  Repo      : github.com/vinirex7/Tradebot-WIN-WDO              |
//+------------------------------------------------------------------+
#property copyright   "vinirex7"
#property link        "https://github.com/vinirex7/Tradebot-WIN-WDO"
#property version     "1.00"
#property description "DualTrendScalper — Bot WIN & WDO para B3"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include "..\Include\RiskManager.mqh"
#include "..\Include\SignalEngine.mqh"
#include "..\Include\TradeLogger.mqh"
#include "..\Include\TimeFilter.mqh"

//--- Inputs: Símbolos
input group "=== Símbolos ==="
input string   Inp_Simbolo1       = "WINFUT";
input string   Inp_Simbolo2       = "WDOFUT";

//--- Inputs: Indicadores
input group "=== Indicadores ==="
input int      Inp_EMA_Rapida     = 9;
input int      Inp_EMA_Lenta      = 21;
input int      Inp_EMA_Tendencia  = 50;
input int      Inp_MACD_Rapida    = 12;
input int      Inp_MACD_Lenta     = 26;
input int      Inp_MACD_Sinal     = 9;
input int      Inp_ATR_Periodo    = 14;

//--- Inputs: Gestão de Risco
input group "=== Gestão de Risco ==="
input double   Inp_Risco_Reais    = 50.0;   // Risco máximo por operação (R$)
input double   Inp_Perda_Diaria   = 150.0;  // Trava de perda diária (R$)
input double   Inp_Ganho_Diario   = 300.0;  // Meta de ganho diário (R$)
input double   Inp_ATR_Mult_SL    = 1.2;    // Multiplicador SL (x ATR)
input double   Inp_RR_Ratio       = 2.0;    // Relação Risco/Retorno mínima
input bool     Inp_UseTrailing    = true;
input bool     Inp_UseBreakEven   = true;
input double   Inp_BE_Trigger     = 0.30;   // % do alvo para ativar break-even
input double   Inp_Trail_Trigger  = 0.50;   // % do alvo para ativar trailing

//--- Inputs: Filtros de Horário
input group "=== Filtros de Horário ==="
input int      Inp_Hora_Ini_1     = 9;
input int      Inp_Min_Ini_1      = 30;
input int      Inp_Hora_Fim_1     = 12;
input int      Inp_Min_Fim_1      = 0;
input int      Inp_Hora_Ini_2     = 14;
input int      Inp_Min_Ini_2      = 0;
input int      Inp_Hora_Fim_2     = 16;
input int      Inp_Min_Fim_2      = 30;
input int      Inp_Hora_FimPregao = 18;
input int      Inp_Min_FimPregao  = 10;

//--- Inputs: Gerais
input group "=== Configurações Gerais ==="
input long     Inp_MagicNumber    = 202601;
input bool     Inp_LogEnabled     = true;
input string   Inp_LogFile        = "DTS_Log";

//--- Objetos globais
CTrade         g_Trade;
CPositionInfo  g_Pos;
CRiskManager   g_Risk;
CSignalEngine  g_Signal;
CTradeLogger   g_Logger;
CTimeFilter    g_Time;

datetime       g_UltimaBarraWIN   = 0;
datetime       g_UltimaBarraWDO   = 0;
datetime       g_DiaAtual         = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   Print("==== DualTrendScalper v1.00 ====");
   Print("Simbolo1: ", Inp_Simbolo1, " | Simbolo2: ", Inp_Simbolo2);
   Print("Servidor: ", AccountInfoString(ACCOUNT_SERVER));
   Print("Conta: ",    AccountInfoInteger(ACCOUNT_LOGIN));

   g_Trade.SetExpertMagicNumber(Inp_MagicNumber);
   g_Trade.SetDeviationInPoints(30);
   g_Trade.SetTypeFilling(ORDER_FILLING_IOC);
   g_Trade.SetAsyncMode(false);

   if(!g_Risk.Init(Inp_Risco_Reais, Inp_Perda_Diaria, Inp_Ganho_Diario, Inp_MagicNumber))
      return(INIT_FAILED);

   if(!g_Signal.Init(Inp_EMA_Rapida, Inp_EMA_Lenta, Inp_EMA_Tendencia,
                     Inp_MACD_Rapida, Inp_MACD_Lenta, Inp_MACD_Sinal,
                     Inp_ATR_Periodo, Inp_ATR_Mult_SL, Inp_RR_Ratio))
      return(INIT_FAILED);

   g_Time.Init(Inp_Hora_Ini_1, Inp_Min_Ini_1, Inp_Hora_Fim_1, Inp_Min_Fim_1,
               Inp_Hora_Ini_2, Inp_Min_Ini_2, Inp_Hora_Fim_2, Inp_Min_Fim_2,
               Inp_Hora_FimPregao, Inp_Min_FimPregao);

   if(Inp_LogEnabled)
      g_Logger.Init(Inp_LogFile, Inp_MagicNumber);

   SymbolSelect(Inp_Simbolo1, true);
   SymbolSelect(Inp_Simbolo2, true);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_Signal.Deinit();
   g_Logger.Flush();
   Comment("");
   Print("DualTrendScalper encerrado. Motivo: ", reason);
}

//+------------------------------------------------------------------+
void OnTick()
{
   VerificaResetDiario();

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Comment("Trading nao permitido. Verifique as configuracoes.");
      return;
   }

   if(g_Time.DeveFechamento())
   {
      FecharTodasPosicoes("Fim de pregao");
      return;
   }

   double pnlDia = g_Risk.GetPnLDiario();

   if(g_Risk.TravaPerdaAtingida())
   {
      Comment(StringFormat("TRAVA DE PERDA | P&L: R$ %.2f", pnlDia));
      return;
   }
   if(g_Risk.TravaGanhoAtingida())
   {
      FecharTodasPosicoes("Meta diaria atingida");
      return;
   }

   if(Inp_UseBreakEven || Inp_UseTrailing)
      GerenciarPosicoes();

   ProcessarSimbolo(Inp_Simbolo1, g_UltimaBarraWIN);
   ProcessarSimbolo(Inp_Simbolo2, g_UltimaBarraWDO);

   AtualizarDashboard(pnlDia);
}

//+------------------------------------------------------------------+
void ProcessarSimbolo(const string symbol, datetime &ultimaBarra)
{
   datetime tb[];
   ArraySetAsSeries(tb, true);
   if(CopyTime(symbol, PERIOD_M5, 0, 1, tb) <= 0) return;
   if(tb[0] == ultimaBarra) return;
   ultimaBarra = tb[0];

   if(!g_Time.DentroJanela()) return;
   if(TemPosicao(symbol))    return;

   ENUM_SIGNAL sinal = g_Signal.GetSinal(symbol);
   if(sinal == SIGNAL_NONE) return;

   STradeParams params;
   if(!g_Signal.GetTradeParams(symbol, sinal, params)) return;
   if(!g_Risk.ValidarRisco(symbol, params.sl_dist_pts)) return;

   bool ok = false;
   if(sinal == SIGNAL_BUY)
      ok = g_Trade.Buy(1, symbol, params.entry, params.sl, params.tp, "DTS_LONG");
   else
      ok = g_Trade.Sell(1, symbol, params.entry, params.sl, params.tp, "DTS_SHORT");

   if(ok)
   {
      string msg = StringFormat("[%s] %s %s | E:%.2f SL:%.2f TP:%.2f ATR:%.2f",
         TimeToString(TimeCurrent(), TIME_MINUTES),
         sinal == SIGNAL_BUY ? "COMPRA" : "VENDA",
         symbol, params.entry, params.sl, params.tp, params.atr);
      Print(msg);
      if(Inp_LogEnabled) g_Logger.LogTrade(msg);
   }
   else
      Print("ERRO ao abrir ordem em ", symbol, " | Codigo: ", GetLastError());
}

//+------------------------------------------------------------------+
void GerenciarPosicoes()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic() != Inp_MagicNumber) continue;
      if(g_Pos.Symbol() != Inp_Simbolo1 && g_Pos.Symbol() != Inp_Simbolo2) continue;

      string   sym    = g_Pos.Symbol();
      double   entrada = g_Pos.PriceOpen();
      double   sl     = g_Pos.StopLoss();
      double   tp     = g_Pos.TakeProfit();
      long     tipo   = g_Pos.PositionType();
      double   preco  = tipo == POSITION_TYPE_BUY ?
                        SymbolInfoDouble(sym, SYMBOL_BID) :
                        SymbolInfoDouble(sym, SYMBOL_ASK);
      double   atr    = g_Signal.GetATR(sym);
      double   alvo   = MathAbs(tp - entrada);
      double   dist   = MathAbs(preco - entrada);
      ulong    ticket = g_Pos.Ticket();

      if(Inp_UseBreakEven && alvo > 0 && dist >= alvo * Inp_BE_Trigger)
      {
         bool slAbaixo = (tipo == POSITION_TYPE_BUY  && sl < entrada);
         bool slAcima  = (tipo == POSITION_TYPE_SELL && sl > entrada);
         if(slAbaixo || slAcima)
            g_Trade.PositionModify(ticket, entrada, tp);
      }

      if(Inp_UseTrailing && alvo > 0 && dist >= alvo * Inp_Trail_Trigger)
      {
         double novoSL;
         bool   deve = false;
         int    dig  = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

         if(tipo == POSITION_TYPE_BUY)
         {
            novoSL = NormalizeDouble(preco - atr, dig);
            if(novoSL > sl) deve = true;
         }
         else
         {
            novoSL = NormalizeDouble(preco + atr, dig);
            if(novoSL < sl || sl == 0) deve = true;
         }
         if(deve) g_Trade.PositionModify(ticket, novoSL, tp);
      }
   }
}

//+------------------------------------------------------------------+
void FecharTodasPosicoes(const string motivo)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Magic() != Inp_MagicNumber) continue;
      if(g_Pos.Symbol() != Inp_Simbolo1 && g_Pos.Symbol() != Inp_Simbolo2) continue;
      if(g_Trade.PositionClose(g_Pos.Ticket()))
         Print("Posicao fechada [", motivo, "]: ", g_Pos.Symbol());
   }
}

//+------------------------------------------------------------------+
bool TemPosicao(const string symbol)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Symbol() == symbol && g_Pos.Magic() == Inp_MagicNumber)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void VerificaResetDiario()
{
   datetime hoje = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(hoje != g_DiaAtual)
   {
      g_DiaAtual = hoje;
      g_Risk.ResetDiario();
      g_UltimaBarraWIN = 0;
      g_UltimaBarraWDO = 0;
      Print("=== Novo dia: ", TimeToString(hoje, TIME_DATE), " ===");
      if(Inp_LogEnabled) g_Logger.LogDiaSeparator(TimeToString(hoje, TIME_DATE));
   }
}

//+------------------------------------------------------------------+
void AtualizarDashboard(double pnlDia)
{
   bool janela  = g_Time.DentroJanela();
   bool travado = g_Risk.TravaPerdaAtingida() || g_Risk.TravaGanhoAtingida();

   Comment(StringFormat(
      "=== DUAL TREND SCALPER ===\n"
      "Hora atual  : %s\n"
      "Janela ativa: %s\n"
      "P&L dia     : R$ %.2f\n"
      "Trava perda : R$ %.2f\n"
      "Meta ganho  : R$ %.2f\n"
      "Status      : %s\n"
      "Servidor    : %s",
      TimeToString(TimeCurrent(), TIME_MINUTES|TIME_SECONDS),
      janela ? "ABERTA" : "FECHADA",
      pnlDia,
      Inp_Perda_Diaria,
      Inp_Ganho_Diario,
      travado ? "TRAVADO" : (janela ? "OPERANDO" : "AGUARDANDO"),
      AccountInfoString(ACCOUNT_SERVER)
   ));
}

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(HistoryDealSelect(trans.deal))
      {
         long magic = (long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
         if(magic == Inp_MagicNumber)
         {
            double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
            g_Risk.AtualizarPnL(profit);
            if(Inp_LogEnabled)
               g_Logger.LogDeal(trans.deal, profit);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| OnTester — Critério personalizado de otimização               |
//+------------------------------------------------------------------+
double OnTester()
{
   double profit     = TesterStatistics(STAT_PROFIT);
   double maxDD_pct  = TesterStatistics(STAT_EQUITY_DD);
   double trades     = TesterStatistics(STAT_TRADES);
   double profitFact = TesterStatistics(STAT_PROFIT_FACTOR);
   double sharpe     = TesterStatistics(STAT_SHARPE_RATIO);
   double recoveryF  = TesterStatistics(STAT_RECOVERY_FACTOR);

   if(trades    < 100)  return 0.0;
   if(profit    <= 0)   return 0.0;
   if(maxDD_pct > 20)   return 0.0;
   if(profitFact < 1.1) return 0.0;

   return MathMax(0, sharpe * profitFact + recoveryF * 0.1);
}
