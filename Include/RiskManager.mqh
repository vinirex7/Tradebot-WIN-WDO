//+------------------------------------------------------------------+
//|  RiskManager.mqh — Gestão de Risco DualTrendScalper             |
//|  Trava diária, validação de risco financeiro e margem           |
//+------------------------------------------------------------------+
#pragma once

class CRiskManager
{
private:
   double m_risco_reais;
   double m_perda_max;
   double m_ganho_meta;
   long   m_magic;
   double m_pnl_dia;

public:
   bool Init(double risco, double perda, double ganho, long magic)
   {
      m_risco_reais = risco;
      m_perda_max   = perda;
      m_ganho_meta  = ganho;
      m_magic       = magic;
      m_pnl_dia     = 0.0;
      return true;
   }

   void ResetDiario()         { m_pnl_dia = 0.0; }
   void AtualizarPnL(double v){ m_pnl_dia += v; }
   double GetPnLDiario()      { return m_pnl_dia; }

   bool TravaPerdaAtingida()  { return m_pnl_dia <= -m_perda_max; }
   bool TravaGanhoAtingida()  { return m_pnl_dia >= m_ganho_meta; }

   bool ValidarRisco(const string sym, double sl_dist_price)
   {
      if(sl_dist_price <= 0) return false;

      double tick_val  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
      double tick_size = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      if(tick_size <= 0 || tick_val <= 0) return false;

      // Risco financeiro de 1 contrato: distância do stop / tamanho do tick * valor do tick.
      double risk_1lot = (sl_dist_price / tick_size) * tick_val;
      if(risk_1lot <= 0) return false;

      double margem_livre = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      double margem_1lot  = 0;
      if(!OrderCalcMargin(ORDER_TYPE_BUY, sym, 1.0,
                          SymbolInfoDouble(sym, SYMBOL_ASK), margem_1lot))
         return false;

      if(margem_livre < margem_1lot * 1.5)
      {
         Print("RISCO: Margem insuficiente para ", sym);
         return false;
      }

      if(risk_1lot > m_risco_reais)
      {
         Print(StringFormat("RISCO: Risco 1 contrato (%.2f) > limite (%.2f) em %s",
               risk_1lot, m_risco_reais, sym));
         return false;
      }

      if(m_pnl_dia < 0 && MathAbs(m_pnl_dia) + risk_1lot > m_perda_max)
      {
         Print("RISCO: Nova operação ultrapassaria trava diária.");
         return false;
      }

      return true;
   }
};
