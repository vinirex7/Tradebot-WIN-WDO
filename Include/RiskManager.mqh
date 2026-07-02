//+------------------------------------------------------------------+
//| RiskManager.mqh — Funções de gestão de risco reutilizáveis     |
//+------------------------------------------------------------------+
#ifndef RISK_MANAGER_MQH
#define RISK_MANAGER_MQH

// Calcula número de contratos pelo risco fixo em R$
double CalcContratos(double risco_reais, double sl_pontos, double tick_val, double tick_size)
  {
   if(sl_pontos <= 0 || tick_size <= 0) return(1);
   double valor_ponto = tick_val / tick_size;
   double contratos   = risco_reais / (sl_pontos * valor_ponto);
   return MathMax(1, MathFloor(contratos));
  }

// Verifica se o risco do trade está dentro do limite
bool RiscoViavel(double risco_reais, double sl_pontos, double tick_val, double tick_size, double tolerancia = 1.5)
  {
   if(tick_size <= 0) return(false);
   double valor_ponto = tick_val / tick_size;
   double risco_trade = sl_pontos * valor_ponto;
   return(risco_trade <= risco_reais * tolerancia);
  }

#endif
//+------------------------------------------------------------------+