//+------------------------------------------------------------------+
//|  RiskManager.mqh — Gestão de risco DualTrendScalper             |
//|  Capital: R$5.000 | Risco/trade: 1% | Trava diária: 3%        |
//+------------------------------------------------------------------+
#pragma once

class CRiskManager
{
private:
   double m_risco_por_trade;
   double m_trava_perda_diaria;
   double m_meta_ganho_diario;
   long   m_magic;
   double m_pnl_diario;
   int    m_trades_hoje;

public:
   bool Init(double riscoPorTrade, double travaDiaria, double metaDiaria, long magic)
   {
      m_risco_por_trade    = riscoPorTrade;
      m_trava_perda_diaria = travaDiaria;
      m_meta_ganho_diario  = metaDiaria;
      m_magic              = magic;
      m_pnl_diario         = 0.0;
      m_trades_hoje        = 0;
      Print(StringFormat("RiskManager | Risco/trade: R$%.2f | Trava: R$%.2f | Meta: R$%.2f",
            m_risco_por_trade, m_trava_perda_diaria, m_meta_ganho_diario));
      return true;
   }

   void ResetDiario()      { m_pnl_diario = 0.0; m_trades_hoje = 0; }
   void AtualizarPnL(double profit) { m_pnl_diario += profit; }
   double GetPnLDiario()   const { return m_pnl_diario; }
   int    GetTradesToday() const { return m_trades_hoje; }

   bool TravaPerdaAtingida() const { return m_pnl_diario <= -MathAbs(m_trava_perda_diaria); }
   bool TravaGanhoAtingida() const { return m_pnl_diario >= m_meta_ganho_diario; }

   bool ValidarRisco(const string sym, double slDistPts)
   {
      double tickVal  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      double pt       = SymbolInfoDouble(sym, SYMBOL_POINT);

      if(tickSize == 0 || tickVal == 0) { Print("AVISO: Tick inválido para ", sym); return false; }

      double riscoReais = (slDistPts * pt / tickSize) * tickVal;
      if(riscoReais > m_risco_por_trade * 1.5)
      {
         Print(StringFormat("REJEITADO [%s]: risco R$%.2f > limite R$%.2f", sym, riscoReais, m_risco_por_trade * 1.5));
         return false;
      }
      m_trades_hoje++;
      return true;
   }
};
