//+------------------------------------------------------------------+
//| OnTester_Criterio.mq5                                            |
//| Funcao OnTester() para colar dentro do EA principal              |
//| Criterio: Sharpe * ProfitFactor + RecoveryFactor * 0.1           |
//| Minimos: PF>=1.4 | DD<=15% | Sharpe>=0.8 | WinRate>=45%         |
//+------------------------------------------------------------------+
// INSTRUCOES:
// Copie a funcao abaixo para dentro de DualTrendScalper.mq5
// O MT5 a chama automaticamente ao final de cada pass de otimizacao.

double OnTester()
  {
   double sharpe      = TesterStatistics(STAT_SHARPE_RATIO);
   double pf          = TesterStatistics(STAT_PROFIT_FACTOR);
   double recovery    = TesterStatistics(STAT_RECOVERY_FACTOR);
   double dd_pct      = TesterStatistics(STAT_EQUITY_DD_RELATIVE);
   double winrate     = TesterStatistics(STAT_TRADES) > 0
                        ? TesterStatistics(STAT_PROFIT_TRADES) / TesterStatistics(STAT_TRADES)
                        : 0;

   // Penalidade para resultados abaixo dos minimos aceitaveis
   if(pf      < 1.4)   return -1.0;  // PF insuficiente
   if(dd_pct  > 15.0)  return -1.0;  // Drawdown excessivo
   if(sharpe  < 0.8)   return -1.0;  // Sharpe insuficiente
   if(winrate < 0.45)  return -1.0;  // Win rate insuficiente
   if(TesterStatistics(STAT_TRADES) < 30) return -1.0; // Poucos trades (sem significancia)

   // Criterio principal: maximizar Sharpe * PF, com bonus de Recovery
   return (sharpe * pf) + (recovery * 0.1);
  }
//+------------------------------------------------------------------+
