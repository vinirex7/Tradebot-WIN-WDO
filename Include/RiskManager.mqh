//+------------------------------------------------------------------+
//|  RiskManager.mqh — Gestão de Risco DualTrendScalper             |
//|  Trava diária, meta diária, validação de margem                 |
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

   void ResetDiario()        { m_pnl_dia = 0.0; }
   void AtualizarPnL(double v){ m_pnl_dia += v; }
   double GetPnLDiario()     { return m_pnl_dia; }

   bool TravaPerdaAtingida() { return m_pnl_dia <= -m_perda_max; }
   bool TravaGanhoAtingida() { return m_pnl_dia >= m_ganho_meta; }

   bool ValidarRisco(const string sym, double sl_pts)
   {
      if(sl_pts <= 0) return false;

      double tick_val  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
      double tick_size = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      double point     = SymbolInfoDouble(sym, SYMBOL_POINT);
      if(tick_size <= 0 || point <= 0) return false;

      double risk_1lot = (sl_pts * point / tick_size) * tick_val;
      if(risk_1lot <= 0) return false;

      // Verifica margem disponível
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
         Print(StringFormat("RISCO: Risco 1 lote (%.2f) > limite (%.2f) em %s",
               risk_1lot, m_risco_reais, sym));
         return false;
      }

      double saldo_disp = m_ganho_meta - m_pnl_dia;
      if(m_pnl_dia < 0 && MathAbs(m_pnl_dia) + risk_1lot > m_perda_max)
      {
         Print("RISCO: Nova operação ultrapassaria trava diária.");
         return false;
      }

      return true;
   }
};
