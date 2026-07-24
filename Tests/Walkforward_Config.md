# Walk-Forward Testing — DualTrendScalper v2.0

## Configuracao Recomendada

| Parametro | Valor |
|-----------|-------|
| In-Sample | 18 meses |
| Out-of-Sample | 6 meses |
| Passes | >= 1000 (genetico) |
| Criterio | Sharpe Ratio |
| Minimos aceitaveis | PF >= 1.4 \| DD <= 15% \| Sharpe >= 0.8 \| WFE >= 0.50 |

## Parametros a Otimizar

### WINFUT
- EMA_Rapida: 5-15 (step 1)
- EMA_Lenta: 15-30 (step 1)
- MACD_R_WIN: 8-16 (step 2)
- MACD_L_WIN: 20-34 (step 2)
- ATR_Mult_SL: 0.8-2.0 (step 0.2)
- ATR_Filtro_Pct: 0.50-0.90 (step 0.10)
- RSI_Min_Compra: 30-50 (step 5)

### WDOFUT
- MACD_R_WDO: 5-14 (step 1)
- MACD_L_WDO: 15-30 (step 2)
- MACD_S_WDO: 3-9 (step 1)
- ATR_Mult_SL: 1.0-2.5 (step 0.2)
- RSI_Max_Venda: 50-70 (step 5)

## Periodo de Dados

- **Backtest total:** 2023-01-02 a 2026-06-30
- **In-sample:** 2023-01-02 a 2025-06-30
- **Out-of-sample:** 2025-07-01 a 2026-06-30

## Metricas de Avaliacao

1. Profit Factor >= 1.4
2. Max Drawdown <= 15% do capital
3. Sharpe Ratio >= 0.8
4. Win Rate >= 45% (com RR 2:1 lucrativo a partir de 34%)
5. Walk-Forward Efficiency (WFE) >= 0.50

## Como Executar no MT5

```
1. Abrir Strategy Tester (Ctrl+R)
2. Expert: Experts/DualTrendScalper.mq5
3. Deposito: BRL 50.000
4. Modo: Every Tick (dados reais)
5. Carregar BacktestConfig_WINFUT.ini ou BacktestConfig_WDOFUT.ini
6. Optimization: Genetic algorithm
7. Forward: Custom (ver datas acima)
```
