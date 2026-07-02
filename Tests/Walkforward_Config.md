# Walk-Forward Testing — DUAL TREND SCALPER

## Metodologia

O walk-forward divide o período histórico em janelas **IS (In-Sample)** para otimização e **OOS (Out-of-Sample)** para validação.

### Parâmetros otimizados

| Parâmetro      | Min   | Max   | Step |
|----------------|-------|-------|------|
| ATR_Mult_SL    | 0.8   | 2.0   | 0.2  |
| RR_Ratio       | 1.5   | 3.0   | 0.5  |
| EMA_Tendencia  | 34    | 100   | 8    |
| EMA_Lenta      | 15    | 30    | 3    |

### Janelas sugeridas (WINFUT — M5)

| Rodada | IS (Otimização)         | OOS (Validação)         |
|--------|-------------------------|-------------------------|
| 1      | Jan/2024 – Jun/2024     | Jul/2024 – Set/2024     |
| 2      | Jan/2024 – Set/2024     | Out/2024 – Dez/2024     |
| 3      | Jan/2024 – Dez/2024     | Jan/2025 – Mar/2025     |
| 4      | Jan/2024 – Mar/2025     | Abr/2025 – Jun/2025     |
| 5      | Jan/2024 – Jun/2025     | Jul/2025 – Dez/2025     |
| 6      | Jan/2024 – Dez/2025     | Jan/2026 – Jun/2026     |

### Critérios de aprovação (OOS)

- Profit Factor ≥ 1.5
- Taxa de acerto ≥ 45%
- Drawdown máximo ≤ 15%
- Mínimo 30 trades no período OOS
- Fator de eficiência OOS/IS ≥ 0.7

### Como executar no MT5

1. Abrir **Strategy Tester** (Ctrl+R)
2. Selecionar EA: `DualTrendScalper`
3. Modelo: **Every Tick Based on Real Ticks**
4. Ativar **Optimization → Walk Forward**
5. Configurar janelas IS/OOS conforme tabela acima
6. Exportar resultado para `Tests/results/`

## Métricas de referência (backtest completo Jan/2024–Jun/2026)

Executar o backtest Python em `backtest/` para obter as métricas base antes de iniciar o walk-forward.
