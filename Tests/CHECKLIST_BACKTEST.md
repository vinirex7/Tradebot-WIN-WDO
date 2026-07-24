# Checklist de Backtest/Walk-Forward — DualTrendScalper v2.0

## Antes de Rodar

- [ ] EA compilado sem erros ou warnings no MetaEditor (F7)
- [ ] Funcao `OnTester()` colada no `DualTrendScalper.mq5` (ver `OnTester_Criterio.mq5`)
- [ ] Dados historicos baixados:
  - [ ] WINFUT M5 — Tools > History Center > WINFUT > M5 > Download
  - [ ] WDOFUT M5 — Tools > History Center > WDOFUT > M5 > Download
  - [ ] WINFUT M15 (filtro de tendencia EMA50) — baixar tambem
  - [ ] WDOFUT M15 — baixar tambem
- [ ] Caminho `MT5_PATH` correto no .bat
- [ ] Conta conectada ao servidor XP (dados reais, nao demo para historico)

## Rodando o Backtest

### Opcao A — Via .bat (recomendado)
```
Tests\run_backtest_WIN.bat   # so WIN
Tests\run_backtest_WDO.bat   # so WDO
Tests\run_backtest_AMBOS.bat # WIN + WDO em sequencia
```

### Opcao B — Manual no MT5
```
1. Ctrl+R -> Strategy Tester
2. Expert: Experts\DualTrendScalper.mq5
3. File > Load Settings -> Tests\BacktestConfig_WINFUT.ini
4. Inputs > Load -> Sets\DualTrendScalper_Default.set
5. Optimization: Genetic algorithm
6. Start
```

### Opcao C — Linha de comando pura (PowerShell)
```powershell
# WIN
& "C:\Program Files\XP Investimentos MT5\terminal64.exe" /config:"Tests\BacktestConfig_WINFUT.ini"

# WDO
& "C:\Program Files\XP Investimentos MT5\terminal64.exe" /config:"Tests\BacktestConfig_WDOFUT.ini"
```

## Avaliando os Resultados

| Metrica | Minimo aceitavel | Ideal |
|---------|-----------------|-------|
| Profit Factor | >= 1.4 | >= 1.8 |
| Max Drawdown | <= 15% | <= 10% |
| Sharpe Ratio | >= 0.8 | >= 1.2 |
| Win Rate | >= 45% | >= 55% |
| WFE (OOS/IS) | >= 0.50 | >= 0.65 |
| Total Trades | >= 30 | >= 100 |

## Walk-Forward: Interpretando o WFE

```
WFE = Lucro_OOS / Lucro_IS

WFE >= 0.65  -> Otimo: estrategia robustan e generalizavel
WFE >= 0.50  -> Aceitavel: pode ir para demo
WFE 0.30-0.49 -> Fraco: overfitting provavel, revisar parametros
WFE < 0.30   -> Reprovado: nao operar, curva otimizada demais
```

## Apos Aprovacao no Backtest

1. Rodar em conta **DEMO** por >= 30 dias corridos
2. Conferir que os trades no demo batem com os do backtest OOS (logica e horarios)
3. Monitorar P&L diario vs drawdown esperado
4. Apenas entao migrar para conta **REAL** com lote minimo (1 contrato)
