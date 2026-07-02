# Backtest Python — DualTrendScalper

Este backtest replica a lógica do EA live da branch `infra-1`:

- Timeframe M5.
- Sinal calculado na última barra M5 fechada.
- Entrada na abertura da barra seguinte, evitando look-ahead bias.
- Cruzamento EMA 9/21.
- Filtro de tendência com EMA 50 no M15.
- Confirmação MACD(12,26,9).
- Stop Loss = ATR(14) × `ATR_Mult_SL`.
- Take Profit = Stop × `RR_Ratio`.
- Break-even ao atingir 30% do alvo.
- Trailing stop ao atingir 50% do alvo, com distância de 1 ATR.
- Janelas operacionais: 09:30–12:00 e 14:00–16:30.
- Fechamento forçado às 18:10.
- Trava de perda diária de R$ 150.
- Meta de ganho diário de R$ 300.

## Instalação

```bash
cd backtest
python -m venv .venv
source .venv/bin/activate  # Linux/Termius
pip install -r requirements.txt
```

## Backtest com CSV exportado do MT5

Formato esperado:

```csv
datetime,open,high,low,close,volume
2025-01-02 09:00:00,130000,130500,129900,130300,1000
```

Execução:

```bash
python run_backtest.py --symbol WIN --csv data/WINFUT_M5.csv --start 2023-01-02 --end 2025-12-31
python run_backtest.py --symbol WDO --csv data/WDOFUT_M5.csv --start 2023-01-02 --end 2025-12-31
```

## Backtest tentando baixar dados via yfinance

```bash
python run_backtest.py --symbol WIN --start 2023-01-02 --end 2025-12-31
python run_backtest.py --symbol WDO --start 2023-01-02 --end 2025-12-31
```

Observação: para WIN/WDO brasileiros, o caminho mais confiável é exportar o OHLCV M5 do MetaTrader 5 da XP e usar `--csv`.

## Walk-forward

```bash
python walkforward.py --symbol WIN --csv data/WINFUT_M5.csv
python walkforward.py --symbol WDO --csv data/WDOFUT_M5.csv
```

Saídas geradas em `backtest/results/`:

- `*_trades.csv`: lista de operações.
- `*_summary.json`: resumo do backtest.
- `*_walkforward.json`: rodadas IS/OOS, parâmetros vencedores e aprovação OOS.
