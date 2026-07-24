//+------------------------------------------------------------------+
//| RiskManager.mqh v2.0 — Gestao de Risco                           |
//| [FIX-2] Pausa drawdown PERSISTENTE via GlobalVariable            |
//| [FIX-3] Lote DINAMICO por risco real (VOLUME_MIN/MAX/STEP)       |
//| [NEW-7] Gain Lock diario configuravel                            |
//+------------------------------------------------------------------+
#ifndef RISK_MANAGER_MQH
#define RISK_MANAGER_MQH

class CRiskManager
  {
private:
   double   m_perdaDiariaAcum;
   double   m_perdaDiariaLimite;
   double   m_ganhoDiarioLimite;
   double   m_ddMax;
   int      m_pausaDias;
   bool     m_pausado;
   datetime m_pausaFim;
   datetime m_diaAtual;
   long     m_magic;
   string   m_gvPausaKey;
   string   m_gvDiaKey;

public:
   void Init(double perdaDiariaLimite, double ganhoDiarioLimite, double ddMax, int pausaDias, long magic)
     {
      m_perdaDiariaAcum    = 0;
      m_perdaDiariaLimite  = perdaDiariaLimite;
      m_ganhoDiarioLimite  = ganhoDiarioLimite;
      m_ddMax              = ddMax;
      m_pausaDias          = pausaDias;
      m_pausado            = false;
      m_pausaFim           = 0;
      m_diaAtual           = 0;
      m_magic              = magic;
      m_gvPausaKey         = "DTS_PausaFim_"  + IntegerToString(magic);
      m_gvDiaKey           = "DTS_DiaAtual_" + IntegerToString(magic);

      // [FIX-2] Restaura estado de pausa persistido entre reinicios do MT5
      if(GlobalVariableCheck(m_gvPausaKey))
        {
         m_pausaFim = (datetime)GlobalVariableGet(m_gvPausaKey);
         if(TimeCurrent() < m_pausaFim)
           {
            m_pausado = true;
            Print("[RiskManager] PAUSADO por drawdown ate ", TimeToString(m_pausaFim));
           }
         else
            GlobalVariableDel(m_gvPausaKey);
        }
      if(GlobalVariableCheck(m_gvDiaKey))
         m_diaAtual = (datetime)GlobalVariableGet(m_gvDiaKey);
     }

   // [FIX-3] Lote dinamico: risco_reais / (sl_pontos * valor_ponto)
   double CalcularLote(const string symbol, double risco_reais, double sl_pontos)
     {
      double tickVal  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double volMin   = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double volMax   = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double volStep  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      if(volStep  <= 0) volStep = 1.0;
      if(tickSize <= 0 || sl_pontos <= 0) return(volMin > 0 ? volMin : 1.0);
      double riscoPorContrato = sl_pontos * (tickVal / tickSize);
      if(riscoPorContrato <= 0) return(volMin > 0 ? volMin : 1.0);
      double lote = risco_reais / riscoPorContrato;
      lote = MathFloor(lote / volStep) * volStep;
      return(MathMax(volMin, MathMin(volMax, lote)));
     }

   bool RiscoViavel(const string symbol, double risco_reais, double sl_pontos, double lote, double tol = 1.5)
     {
      double tickVal  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize <= 0) return false;
      return(sl_pontos * (tickVal/tickSize) * lote <= risco_reais * tol);
     }

   void VerificaResetDiario()
     {
      datetime hoje = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
      if(hoje != m_diaAtual)
        {
         m_diaAtual        = hoje;
         m_perdaDiariaAcum = 0;
         GlobalVariableSet(m_gvDiaKey, (double)m_diaAtual);
         if(m_pausado && TimeCurrent() >= m_pausaFim)
           {
            m_pausado = false;
            GlobalVariableDel(m_gvPausaKey);
            Print("[RiskManager] Pausa encerrada. Bot REATIVADO.");
           }
         Print("[RiskManager] Novo dia: reset de perda diaria.");
        }
     }

   void AtualizarResultadoDiario(const string sym1, const string sym2)
     {
      double resultado = 0;
      HistorySelect(m_diaAtual, TimeCurrent());
      for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = HistoryDealGetTicket(i);
         string sym   = HistoryDealGetString(ticket, DEAL_SYMBOL);
         if((sym == sym1 || sym == sym2) &&
            HistoryDealGetInteger(ticket, DEAL_MAGIC) == m_magic)
            resultado += HistoryDealGetDouble(ticket, DEAL_PROFIT);
        }
      if(resultado < 0)
         m_perdaDiariaAcum = MathAbs(resultado);

      if(m_perdaDiariaAcum >= m_ddMax && !m_pausado)
        {
         m_pausado  = true;
         m_pausaFim = TimeCurrent() + m_pausaDias * 86400;
         GlobalVariableSet(m_gvPausaKey, (double)m_pausaFim);
         Print("!!! DRAWDOWN MAXIMO (R$ ", m_ddMax, "). Pausado ate ", TimeToString(m_pausaFim));
        }
     }

   bool   EstaPausado()                         { return m_pausado; }
   double PerdaDiariaAcum()                     { return m_perdaDiariaAcum; }
   bool   TravaPerdaAtingida()                  { return m_perdaDiariaAcum >= m_perdaDiariaLimite; }
   bool   TravaGanhoAtingida(double pnlHoje)    { return m_ganhoDiarioLimite > 0 && pnlHoje >= m_ganhoDiarioLimite; }
   datetime PausaFim()                          { return m_pausaFim; }
  };

#endif
//+------------------------------------------------------------------+