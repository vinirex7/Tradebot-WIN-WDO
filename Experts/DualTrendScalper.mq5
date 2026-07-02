//+------------------------------------------------------------------+
//| DUAL TREND SCALPER — WIN & WDO | B3 Day Trade Bot               |
//| MetaTrader 5 (MQL5) | Timeframe: M5 | Filtro: M15               |
//| Corretora: XP Investimentos | Magic: 202601                     |
//+------------------------------------------------------------------+
#property copyright "Tradebot WIN-WDO"
#property version   "1.10"
#property strict
#include <Trade\Trade.mqh>

//--- Parâmetros configuráveis (Inputs)
input string   Simbolo1       = "WINFUT";  // Símbolo 1 (WIN)
input string   Simbolo2       = "WDOFUT";  // Símbolo 2 (WDO)
input int      EMA_Rapida     = 9;         // EMA rápida (M5)
input int      EMA_Lenta      = 21;        // EMA lenta (M5)
input int      EMA_Tendencia  = 50;        // EMA filtro (M15)
input int      MACD_Rapida    = 12;        // MACD rápida
input int      MACD_Lenta     = 26;        // MACD lenta
input int      MACD_Sinal     = 9;         // MACD sinal
input int      ATR_Periodo    = 14;        // ATR período
input double   ATR_Mult_SL    = 1.2;       // Multiplicador SL (ATR×)
input double   RR_Ratio       = 2.0;       // Relação Risco/Retorno
input double   Risco_Reais    = 50.0;      // Risco máximo por trade (R$)
input double   Perda_Diaria   = 150.0;     // Trava de perda diária (R$)
input double   DD_Max         = 500.0;     // Drawdown máximo (R$) → pausa 5 dias
input int      MaxTradesWIN   = 3;         // Máx. trades/dia no WIN
input int      MaxTradesWDO   = 3;         // Máx. trades/dia no WDO
input int      Hora_Ini_1     = 9;         // Janela 1 início (hora)
input int      Min_Ini_1      = 30;        // Janela 1 início (minuto)
input int      Hora_Fim_1     = 12;        // Janela 1 fim (hora)
input int      Min_Fim_1      = 0;         // Janela 1 fim (minuto)
input int      Hora_Ini_2     = 14;        // Janela 2 início (hora)
input int      Min_Ini_2      = 0;         // Janela 2 início (minuto)
input int      Hora_Fim_2     = 16;        // Janela 2 fim (hora)
input int      Min_Fim_2      = 30;        // Janela 2 fim (minuto)
input int      Hora_Fechamento = 18;       // Fechar posições a partir de (hora)
input int      Min_Fechamento  = 10;       // Fechar posições a partir de (minuto)
input bool     UseTrailing    = true;      // Ativar trailing stop
input bool     UseBreakEven   = true;      // Ativar break-even
input double   BE_Pct         = 0.30;      // Break-even após % do alvo atingida
input double   Trailing_Pct   = 0.50;      // Trailing ativo após % do alvo atingida

//--- Variáveis globais
CTrade Trade;
double PerdaDiariaAcum  = 0;
datetime UltimaBarraWIN = 0;
datetime UltimaBarraWDO = 0;
int TradesHojeWIN       = 0;
int TradesHojeWDO       = 0;
datetime DiaAtual       = 0;
bool BotPausado         = false;

//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("DUAL TREND SCALPER v1.10 iniciado. WIN=", Simbolo1, " WDO=", Simbolo2);
   Trade.SetExpertMagicNumber(202601);
   Trade.SetDeviationInPoints(10);
   Trade.SetTypeFilling(ORDER_FILLING_RETURN);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Funções auxiliares de indicadores                                |
//+------------------------------------------------------------------+
double GetEMA(string symbol, ENUM_TIMEFRAMES tf, int periodo, int shift)
  {
   double buf[];
   int handle = iMA(symbol, tf, periodo, 0, MODE_EMA, PRICE_CLOSE);
   if(handle == INVALID_HANDLE) return(0);
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(handle, 0, shift, 1, buf) <= 0) { IndicatorRelease(handle); return(0); }
   IndicatorRelease(handle);
   return(buf[0]);
  }

double GetATR(string symbol, ENUM_TIMEFRAMES tf, int periodo, int shift)
  {
   double buf[];
   int handle = iATR(symbol, tf, periodo);
   if(handle == INVALID_HANDLE) return(0);
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(handle, 0, shift, 1, buf) <= 0) { IndicatorRelease(handle); return(0); }
   IndicatorRelease(handle);
   return(buf[0]);
  }

double GetATRMedia(string symbol, ENUM_TIMEFRAMES tf, int periodo, int lookback)
  {
   double buf[];
   int handle = iATR(symbol, tf, periodo);
   if(handle == INVALID_HANDLE) return(0);
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(handle, 0, 0, lookback, buf) <= 0) { IndicatorRelease(handle); return(0); }
   IndicatorRelease(handle);
   double soma = 0;
   for(int i = 0; i < lookback; i++) soma += buf[i];
   return(soma / lookback);
  }

double GetMACDHistogram(string symbol, ENUM_TIMEFRAMES tf, int shift)
  {
   double buf[];
   int handle = iMACD(symbol, tf, MACD_Rapida, MACD_Lenta, MACD_Sinal, PRICE_CLOSE);
   if(handle == INVALID_HANDLE) return(0);
   ArraySetAsSeries(buf, true);
   // Buffer 1 = histograma no MT5
   if(CopyBuffer(handle, 1, shift, 1, buf) <= 0) { IndicatorRelease(handle); return(0); }
   IndicatorRelease(handle);
   return(buf[0]);
  }

//+------------------------------------------------------------------+
//| Verifica janela horária permitida                                |
//+------------------------------------------------------------------+
bool DentroJanelaHoraria()
  {
   MqlDateTime dt;
   TimeCurrent(dt);
   int minutos = dt.hour * 60 + dt.min;
   int ini1 = Hora_Ini_1 * 60 + Min_Ini_1;
   int fim1 = Hora_Fim_1 * 60 + Min_Fim_1;
   int ini2 = Hora_Ini_2 * 60 + Min_Ini_2;
   int fim2 = Hora_Fim_2 * 60 + Min_Fim_2;
   return((minutos >= ini1 && minutos < fim1) ||
          (minutos >= ini2 && minutos < fim2));
  }

//+------------------------------------------------------------------+
//| Verifica se há posição aberta no símbolo (Magic 202601)          |
//+------------------------------------------------------------------+
bool TemPosicaoAberta(string symbol)
  {
   for(int i = 0; i < PositionsTotal(); i++)
     {
      if(PositionGetSymbol(i) == symbol &&
         PositionGetInteger(POSITION_MAGIC) == 202601)
         return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Reset diário                                                     |
//+------------------------------------------------------------------+
void VerificaResetDiario()
  {
   datetime hoje = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(hoje != DiaAtual)
     {
      DiaAtual       = hoje;
      PerdaDiariaAcum = 0;
      TradesHojeWIN  = 0;
      TradesHojeWDO  = 0;
      BotPausado     = false;
      Print("=== Novo dia iniciado. Reset de gestão de risco. ===");
     }
  }

//+------------------------------------------------------------------+
//| Rastrear P&L acumulado do dia                                    |
//+------------------------------------------------------------------+
void AtualizarPerdaDiaria()
  {
   double resultado = 0;
   HistorySelect(DiaAtual, TimeCurrent());
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = HistoryDealGetTicket(i);
      string sym   = HistoryDealGetString(ticket, DEAL_SYMBOL);
      if((sym == Simbolo1 || sym == Simbolo2) &&
         HistoryDealGetInteger(ticket, DEAL_MAGIC) == 202601)
         resultado += HistoryDealGetDouble(ticket, DEAL_PROFIT);
     }
   if(resultado < 0) PerdaDiariaAcum = MathAbs(resultado);

   // Verificar drawdown máximo
   if(PerdaDiariaAcum >= DD_Max)
     {
      BotPausado = true;
      Print("!!! DRAWDOWN MÁXIMO ATINGIDO (R$ ", DD_Max, "). Bot pausado por 5 dias. !!!");
     }
  }

//+------------------------------------------------------------------+
//| Fechar todas as posições antes do fechamento do pregão          |
//+------------------------------------------------------------------+
void FechamentoPregao()
  {
   MqlDateTime dt;
   TimeCurrent(dt);
   int minutos = dt.hour * 60 + dt.min;
   int limite  = Hora_Fechamento * 60 + Min_Fechamento;
   if(minutos >= limite)
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         string sym = PositionGetSymbol(i);
         if((sym == Simbolo1 || sym == Simbolo2) &&
            PositionGetInteger(POSITION_MAGIC) == 202601)
           {
            Trade.PositionClose(PositionGetInteger(POSITION_TICKET));
            Print("Posição fechada por fim de pregão: ", sym);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Gerencia trailing stop e break-even                             |
//+------------------------------------------------------------------+
void GerenciarPosicoes()
  {
   for(int i = 0; i < PositionsTotal(); i++)
     {
      string sym = PositionGetSymbol(i);
      if((sym != Simbolo1 && sym != Simbolo2)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != 202601) continue;

      double entrada = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl      = PositionGetDouble(POSITION_SL);
      double tp      = PositionGetDouble(POSITION_TP);
      long   tipo    = PositionGetInteger(POSITION_TYPE);
      double preco   = (tipo == POSITION_TYPE_BUY) ?
                       SymbolInfoDouble(sym, SYMBOL_BID) :
                       SymbolInfoDouble(sym, SYMBOL_ASK);
      double atr     = GetATR(sym, PERIOD_M5, ATR_Periodo, 0);
      double alvo    = MathAbs(tp - entrada);
      double dist    = MathAbs(preco - entrada);
      ulong  ticket  = PositionGetInteger(POSITION_TICKET);

      // --- Break-even
      if(UseBreakEven && sl != entrada && dist >= alvo * BE_Pct)
        {
         if(tipo == POSITION_TYPE_BUY && sl < entrada)
            Trade.PositionModify(ticket, entrada, tp);
         else if(tipo == POSITION_TYPE_SELL && sl > entrada)
            Trade.PositionModify(ticket, entrada, tp);
        }

      // --- Trailing stop
      if(UseTrailing && dist >= alvo * Trailing_Pct)
        {
         double novoSL;
         if(tipo == POSITION_TYPE_BUY)
           {
            novoSL = NormalizeDouble(preco - atr * _Point, _Digits);
            if(novoSL > sl) Trade.PositionModify(ticket, novoSL, tp);
           }
         else
           {
            novoSL = NormalizeDouble(preco + atr * _Point, _Digits);
            if(novoSL < sl) Trade.PositionModify(ticket, novoSL, tp);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Lógica principal para um símbolo                                |
//+------------------------------------------------------------------+
void ProcessarSimbolo(string symbol, datetime &ultimaBarra, int &tradesHoje, int maxTrades)
  {
   // Evitar reprocessamento na mesma barra M5
   datetime barraParcial[];
   ArraySetAsSeries(barraParcial, true);
   if(CopyTime(symbol, PERIOD_M5, 0, 1, barraParcial) <= 0) return;
   if(barraParcial[0] == ultimaBarra) return;
   ultimaBarra = barraParcial[0];

   if(BotPausado) return;
   if(PerdaDiariaAcum >= Perda_Diaria)
     {
      Comment("TRAVA DIÁRIA ATINGIDA. Bot pausado até amanhã.");
      return;
     }
   if(tradesHoje >= maxTrades) return;
   if(!DentroJanelaHoraria()) return;
   if(TemPosicaoAberta(symbol)) return;

   // === Cálculo de indicadores ===
   double ema9_atual  = GetEMA(symbol, PERIOD_M5, EMA_Rapida,  0);
   double ema9_prev   = GetEMA(symbol, PERIOD_M5, EMA_Rapida,  1);
   double ema21_atual = GetEMA(symbol, PERIOD_M5, EMA_Lenta,   0);
   double ema21_prev  = GetEMA(symbol, PERIOD_M5, EMA_Lenta,   1);
   double ema50_m15   = GetEMA(symbol, PERIOD_M15, EMA_Tendencia, 0);
   double macd_hist   = GetMACDHistogram(symbol, PERIOD_M5, 0);
   double atr         = GetATR(symbol, PERIOD_M5, ATR_Periodo, 0);
   double atr_media   = GetATRMedia(symbol, PERIOD_M5, ATR_Periodo, 20);

   if(ema9_atual == 0 || ema21_atual == 0 || atr == 0 || atr_media == 0) return;

   // Filtro de volatilidade: ATR atual >= 50% da média de 20 barras
   if(atr < atr_media * 0.50) return;

   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

   double tickVal  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double slPontos = atr * ATR_Mult_SL;
   double tpPontos = slPontos * RR_Ratio;

   // === SINAL DE COMPRA ===
   bool cruzeAlta    = (ema9_prev < ema21_prev) && (ema9_atual > ema21_atual);
   bool tendAlta     = ask > ema50_m15;
   bool macdPositivo = macd_hist > 0;

   if(cruzeAlta && tendAlta && macdPositivo)
     {
      double sl_preco = NormalizeDouble(ask - slPontos * _Point, _Digits);
      double tp_preco = NormalizeDouble(ask + tpPontos * _Point, _Digits);
      double riscoTrade = slPontos * (tickVal / tickSize);
      if(riscoTrade > Risco_Reais * 1.5) return;
      if(Trade.Buy(1, symbol, ask, sl_preco, tp_preco, "DUAL_LONG"))
        {
         tradesHoje++;
         Print("COMPRA ", symbol, " | Entrada:", ask, " SL:", sl_preco, " TP:", tp_preco, " ATR:", atr);
        }
      return;
     }

   // === SINAL DE VENDA ===
   bool cruzeBaixa   = (ema9_prev > ema21_prev) && (ema9_atual < ema21_atual);
   bool tendBaixa    = bid < ema50_m15;
   bool macdNegativo = macd_hist < 0;

   if(cruzeBaixa && tendBaixa && macdNegativo)
     {
      double sl_preco = NormalizeDouble(bid + slPontos * _Point, _Digits);
      double tp_preco = NormalizeDouble(bid - tpPontos * _Point, _Digits);
      if(Trade.Sell(1, symbol, bid, sl_preco, tp_preco, "DUAL_SHORT"))
        {
         tradesHoje++;
         Print("VENDA ", symbol, " | Entrada:", bid, " SL:", sl_preco, " TP:", tp_preco, " ATR:", atr);
        }
     }
  }

//+------------------------------------------------------------------+
//| Tick principal                                                   |
//+------------------------------------------------------------------+
void OnTick()
  {
   VerificaResetDiario();
   AtualizarPerdaDiaria();
   FechamentoPregao();
   GerenciarPosicoes();
   ProcessarSimbolo(Simbolo1, UltimaBarraWIN, TradesHojeWIN, MaxTradesWIN);
   ProcessarSimbolo(Simbolo2, UltimaBarraWDO, TradesHojeWDO, MaxTradesWDO);

   Comment(StringFormat(
      "DUAL TREND SCALPER v1.10 | %s\n"
      "Perda dia: R$ %.2f / R$ %.2f\n"
      "Trades WIN: %d/%d | WDO: %d/%d\n"
      "Janela ativa: %s | Bot pausado: %s",
      TimeToString(TimeCurrent()),
      PerdaDiariaAcum, Perda_Diaria,
      TradesHojeWIN, MaxTradesWIN,
      TradesHojeWDO, MaxTradesWDO,
      DentroJanelaHoraria() ? "SIM ✓" : "NÃO ✗",
      BotPausado ? "SIM ⛔" : "NÃO"
   ));
  }
//+------------------------------------------------------------------+