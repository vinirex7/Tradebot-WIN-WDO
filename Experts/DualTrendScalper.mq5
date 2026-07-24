//+------------------------------------------------------------------+
//| DUAL TREND SCALPER v2.0 — WIN & WDO | B3 Day Trade Bot           |
//| MetaTrader 5 (MQL5) | Timeframe: M5 | Filtro: M15               |
//| Corretora: XP Investimentos | Magic: 202601                     |
//|                                                                  |
//| CHANGELOG v2.0 (vs v1.10):                                       |
//|  [FIX-1] Handles criados uma vez em OnInit (sem overhead/tick)   |
//|  [FIX-2] Pausa drawdown PERSISTENTE via GlobalVariable           |
//|  [FIX-3] Lote DINAMICO por risco real (antes: fixo em 1 contrato)|
//|  [NEW-1] Filtro RSI(14) sobrecompra/sobrevenda                   |
//|  [NEW-2] MACD parametrizavel POR SIMBOLO (WIN != WDO)            |
//|  [NEW-3] Janelas de horario INDEPENDENTES por simbolo            |
//|  [NEW-4] Filtro ATR elevado para 70% da media (era 50%)          |
//|  [NEW-5] MACD usa histograma crescente (mais robusto)            |
//|  [NEW-6] Log CSV estruturado via OnTradeTransaction              |
//|  [NEW-7] Gain Lock diario configuravel                           |
//+------------------------------------------------------------------+
#property copyright "Tradebot WIN-WDO"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include "..\Include\RiskManager.mqh"
#include "..\Include\TimeFilter.mqh"
#include "..\Include\SignalEngine.mqh"
#include "..\Include\TradeLogger.mqh"

//--- Simbolos
input string   Simbolo1           = "WINFUT";  // Simbolo 1 (WIN)
input string   Simbolo2           = "WDOFUT";  // Simbolo 2 (WDO)

//--- EMA
input int      EMA_Rapida         = 9;          // EMA rapida (M5)
input int      EMA_Lenta          = 21;         // EMA lenta (M5)
input int      EMA_Tendencia      = 50;         // EMA filtro (M15)

//--- MACD WIN
input int      MACD_R_WIN         = 12;         // MACD rapida - WIN
input int      MACD_L_WIN         = 26;         // MACD lenta - WIN
input int      MACD_S_WIN         = 9;          // MACD sinal - WIN

//--- MACD WDO (parametros independentes do WIN)
input int      MACD_R_WDO         = 8;          // MACD rapida - WDO
input int      MACD_L_WDO         = 21;         // MACD lenta - WDO
input int      MACD_S_WDO         = 5;          // MACD sinal - WDO

//--- ATR e RSI
input int      ATR_Periodo        = 14;         // ATR periodo
input double   ATR_Mult_SL        = 1.2;        // Multiplicador SL (ATRx)
input double   ATR_Filtro_Pct     = 0.70;       // ATR minimo vs media 20 barras
input int      RSI_Periodo        = 14;         // RSI periodo
input double   RSI_Min_Compra     = 40.0;       // RSI minimo para compra
input double   RSI_Max_Venda      = 60.0;       // RSI maximo para venda

//--- Risco e Gestao
input double   RR_Ratio           = 2.0;        // Relacao Risco/Retorno
input double   Risco_Reais        = 50.0;       // Risco maximo por trade (R$)
input double   Perda_Diaria       = 150.0;      // Trava de perda diaria (R$)
input double   Ganho_Diario       = 300.0;      // Gain Lock diario (R$) - 0=off
input double   DD_Max             = 500.0;      // Drawdown maximo (R$)
input int      PausaDias          = 5;          // Dias de pausa apos DD_Max
input int      MaxTradesWIN       = 3;          // Max. trades/dia WIN
input int      MaxTradesWDO       = 3;          // Max. trades/dia WDO

//--- Janelas WIN
input int      WIN_H_Ini1         = 9;
input int      WIN_M_Ini1         = 30;
input int      WIN_H_Fim1         = 11;
input int      WIN_M_Fim1         = 0;
input int      WIN_H_Ini2         = 14;
input int      WIN_M_Ini2         = 0;
input int      WIN_H_Fim2         = 16;
input int      WIN_M_Fim2         = 30;

//--- Janelas WDO
input int      WDO_H_Ini1         = 10;
input int      WDO_M_Ini1         = 0;
input int      WDO_H_Fim1         = 12;
input int      WDO_M_Fim1         = 0;
input int      WDO_H_Ini2         = 14;         // Abertura mercado EUA
input int      WDO_M_Ini2         = 0;
input int      WDO_H_Fim2         = 15;
input int      WDO_M_Fim2         = 30;

//--- Fechamento e posicao
input int      Hora_Fechamento    = 18;
input int      Min_Fechamento     = 10;
input bool     UseTrailing        = true;
input bool     UseBreakEven       = true;
input double   BE_Pct             = 0.30;
input double   Trailing_Pct       = 0.50;

//--- Log
input bool     LogEnabled         = true;
input string   LogFile            = "DTS_Log";

//--- Objetos globais
CTrade         Trade;
CRiskManager   RiskMgr;
CTimeFilter    TimeFilt;
CSignalEngine  SignalEng;
CTradeLogger   Logger;

datetime UltimaBarraWIN = 0;
datetime UltimaBarraWDO = 0;
int      TradesHojeWIN  = 0;
int      TradesHojeWDO  = 0;
datetime DiaAtualLocal  = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   Print("DUAL TREND SCALPER v2.00 iniciado.");
   Trade.SetExpertMagicNumber(202601);
   Trade.SetDeviationInPoints(10);
   Trade.SetTypeFilling(ORDER_FILLING_RETURN);

   RiskMgr.Init(Perda_Diaria, Ganho_Diario, DD_Max, PausaDias, 202601);

   TimeFilt.SetSimbolos(Simbolo1, Simbolo2);
   TimeFilt.InitJanela(0, WIN_H_Ini1, WIN_M_Ini1, WIN_H_Fim1, WIN_M_Fim1,
                           WIN_H_Ini2, WIN_M_Ini2, WIN_H_Fim2, WIN_M_Fim2);
   TimeFilt.InitJanela(1, WDO_H_Ini1, WDO_M_Ini1, WDO_H_Fim1, WDO_M_Fim1,
                           WDO_H_Ini2, WDO_M_Ini2, WDO_H_Fim2, WDO_M_Fim2);
   TimeFilt.InitFechamento(Hora_Fechamento, Min_Fechamento);

   if(!SignalEng.Init(EMA_Rapida, EMA_Lenta, EMA_Tendencia,
                      MACD_R_WIN, MACD_L_WIN, MACD_S_WIN,
                      MACD_R_WDO, MACD_L_WDO, MACD_S_WDO,
                      ATR_Periodo, RSI_Periodo,
                      ATR_Mult_SL, RR_Ratio, ATR_Filtro_Pct,
                      RSI_Min_Compra, RSI_Max_Venda,
                      Simbolo1, Simbolo2))
      return(INIT_FAILED);

   if(LogEnabled) Logger.Init(LogFile, 202601);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   SignalEng.Deinit();
   Logger.Flush();
  }

//+------------------------------------------------------------------+
bool TemPosicaoAberta(const string symbol)
  {
   for(int i = 0; i < PositionsTotal(); i++)
      if(PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_MAGIC) == 202601)
         return true;
   return false;
  }

//+------------------------------------------------------------------+
void FechamentoPregao()
  {
   if(!TimeFilt.DeveFechamento()) return;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      string sym = PositionGetSymbol(i);
      if((sym == Simbolo1 || sym == Simbolo2) && PositionGetInteger(POSITION_MAGIC) == 202601)
        {
         Trade.PositionClose(PositionGetInteger(POSITION_TICKET));
         Print("Posicao fechada por fim de pregao: ", sym);
        }
     }
  }

//+------------------------------------------------------------------+
void GerenciarPosicoes()
  {
   for(int i = 0; i < PositionsTotal(); i++)
     {
      string sym = PositionGetSymbol(i);
      if(sym != Simbolo1 && sym != Simbolo2) continue;
      if(PositionGetInteger(POSITION_MAGIC) != 202601) continue;

      double entrada = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl      = PositionGetDouble(POSITION_SL);
      double tp      = PositionGetDouble(POSITION_TP);
      long   tipo    = PositionGetInteger(POSITION_TYPE);
      double preco   = (tipo==POSITION_TYPE_BUY) ? SymbolInfoDouble(sym,SYMBOL_BID) : SymbolInfoDouble(sym,SYMBOL_ASK);
      double atr     = SignalEng.GetATR(sym);
      double alvo    = MathAbs(tp - entrada);
      double dist    = MathAbs(preco - entrada);
      ulong  ticket  = PositionGetInteger(POSITION_TICKET);

      if(UseBreakEven && sl != entrada && dist >= alvo * BE_Pct)
        {
         if(tipo==POSITION_TYPE_BUY  && sl < entrada) Trade.PositionModify(ticket, entrada, tp);
         if(tipo==POSITION_TYPE_SELL && sl > entrada) Trade.PositionModify(ticket, entrada, tp);
        }

      if(UseTrailing && atr > 0 && dist >= alvo * Trailing_Pct)
        {
         double novoSL;
         if(tipo == POSITION_TYPE_BUY)
           { novoSL = NormalizeDouble(preco - atr, _Digits); if(novoSL > sl) Trade.PositionModify(ticket, novoSL, tp); }
         else
           { novoSL = NormalizeDouble(preco + atr, _Digits); if(novoSL < sl) Trade.PositionModify(ticket, novoSL, tp); }
        }
     }
  }

//+------------------------------------------------------------------+
double PnLHoje()
  {
   double res = 0;
   HistorySelect(StringToTime(TimeToString(TimeCurrent(),TIME_DATE)), TimeCurrent());
   for(int i = HistoryDealsTotal()-1; i >= 0; i--)
     {
      ulong t = HistoryDealGetTicket(i);
      string s = HistoryDealGetString(t, DEAL_SYMBOL);
      if((s==Simbolo1||s==Simbolo2) && HistoryDealGetInteger(t,DEAL_MAGIC)==202601)
         res += HistoryDealGetDouble(t, DEAL_PROFIT);
     }
   return res;
  }

//+------------------------------------------------------------------+
void ProcessarSimbolo(const string symbol, datetime &ultimaBarra, int &tradesHoje, int maxTrades)
  {
   datetime barraAtual[];
   ArraySetAsSeries(barraAtual, true);
   if(CopyTime(symbol, PERIOD_M5, 0, 1, barraAtual) <= 0) return;
   if(barraAtual[0] == ultimaBarra) return;
   ultimaBarra = barraAtual[0];

   if(RiskMgr.EstaPausado())        return;
   if(RiskMgr.TravaPerdaAtingida()) return;
   if(tradesHoje >= maxTrades)      return;
   if(!TimeFilt.DentroJanela(symbol)) return;
   if(TemPosicaoAberta(symbol))     return;

   double pnlHoje = PnLHoje();
   if(RiskMgr.TravaGanhoAtingida(pnlHoje)) return;

   ENUM_SIGNAL sinal = SignalEng.GetSinal(symbol);
   if(sinal == SIGNAL_NONE) return;

   double slPontos = SignalEng.GetATR(symbol) * ATR_Mult_SL;
   double lote     = RiskMgr.CalcularLote(symbol, Risco_Reais, slPontos);

   STradeParams p;
   if(!SignalEng.GetTradeParams(symbol, sinal, p, lote)) return;
   if(!RiskMgr.RiscoViavel(symbol, Risco_Reais, p.sl_dist_pts, lote)) return;

   bool ok = false;
   if(sinal == SIGNAL_BUY)
      ok = Trade.Buy(lote, symbol, p.entry, p.sl, p.tp, "DTS_LONG");
   else
      ok = Trade.Sell(lote, symbol, p.entry, p.sl, p.tp, "DTS_SHORT");

   if(ok)
     {
      tradesHoje++;
      string dir = (sinal==SIGNAL_BUY) ? "COMPRA" : "VENDA";
      double tickVal  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double riscoCalc = (tickSize > 0) ? p.sl_dist_pts * (tickVal/tickSize) * lote : 0;
      Print(dir," ",symbol," | Lote:",lote," E:",p.entry," SL:",p.sl," TP:",p.tp,
            " ATR:",p.atr," RSI:",p.rsi," MACD:",p.macd_hist);
      if(LogEnabled)
         Logger.LogTrade(symbol, dir, p.entry, p.sl, p.tp, p.atr, p.rsi, p.macd_hist, lote, riscoCalc);
     }
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   RiskMgr.VerificaResetDiario();
   RiskMgr.AtualizarResultadoDiario(Simbolo1, Simbolo2);

   datetime hoje = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(hoje != DiaAtualLocal)
     {
      DiaAtualLocal = hoje;
      TradesHojeWIN = 0;
      TradesHojeWDO = 0;
      if(LogEnabled) Logger.NovoDia();
     }

   FechamentoPregao();
   GerenciarPosicoes();

   ProcessarSimbolo(Simbolo1, UltimaBarraWIN, TradesHojeWIN, MaxTradesWIN);
   ProcessarSimbolo(Simbolo2, UltimaBarraWDO, TradesHojeWDO, MaxTradesWDO);

   double pnlHoje = PnLHoje();
   Comment(StringFormat(
      "DUAL TREND SCALPER v2.00 | %s\n"
      "P&L hoje: R$ %.2f | Perda: R$ %.2f/%.2f | Ganho max: R$ %.2f\n"
      "Trades WIN: %d/%d | WDO: %d/%d\n"
      "Janela WIN: %s | Janela WDO: %s\n"
      "Bot pausado: %s%s",
      TimeToString(TimeCurrent()),
      pnlHoje,
      RiskMgr.PerdaDiariaAcum(), Perda_Diaria, Ganho_Diario,
      TradesHojeWIN, MaxTradesWIN,
      TradesHojeWDO, MaxTradesWDO,
      TimeFilt.DentroJanela(Simbolo1) ? "SIM" : "NAO",
      TimeFilt.DentroJanela(Simbolo2) ? "SIM" : "NAO",
      RiskMgr.EstaPausado() ? "SIM" : "NAO",
      RiskMgr.EstaPausado() ? (" ate " + TimeToString(RiskMgr.PausaFim())) : ""
   ));
  }

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD && LogEnabled)
     {
      ulong ticket = trans.deal;
      if(HistoryDealSelect(ticket))
        {
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == 202601)
            Logger.LogDeal(ticket);
        }
     }
  }
//+------------------------------------------------------------------+