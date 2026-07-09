# Backtest Python — DualTrendScalper

Backtest Python da branch `infra-1`, preparado para rodar no Termius/VPS e espelhar o funcionamento live do EA MQL5.

## O que ele replica do live

- Timeframe operacional M5.
- Sinal processado no fluxo da barra M5, como o EA faz ao detectar nova barra.
- Entrada no preco da propria barra processada, aproximando o uso de ASK/BID do EA com OHLCV historico.
- Cruzamento EMA 9/21.
- Filtro de tendencia com EMA 50 no M15.
- Confirmacao MACD(12,26,9) conforme o EA live: buffer 1 do iMACD, chamado no codigo de histograma.
- Filtro de volatilidade: ATR(14) atual >= 50% da media dos ultimos 20 ATRs.
- Stop Loss por ATR: ATR_Mult_SL padrao 1.2.
- Take Profit = Stop x 2.0.
- Break-even ao atingir 30% do alvo.
- Trailing stop ao atingir 50% do alvo, com distancia de 1 ATR.
- Janelas operacionais: 09:30-12:00 e 14:00-16:30.
- Fechamento forcado as 18:10.
- Trava de perda diaria de R$ 150.
- Drawdown maximo de R$ 500, pausando novas entradas no dia no backtest.
- Maximo de 3 operacoes por dia por ativo.
- Modo dual WIN+WDO permite posicao simultanea por simbolo, igual ao EA live, pois `TemPosicaoAberta(symbol)` verifica apenas o simbolo atual.

## Instalacao no Termius

```bash
git clone https://github.com/vinirex7/Tradebot-WIN-WDO.git
cd Tradebot-WIN-WDO
git checkout infra-1
cd backtest
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Formato do CSV M5 exportado do MT5

Use dados M5 exportados do MetaTrader 5/XP. O caminho com CSV e o mais confiavel para WIN/WDO.

```csv
datetime,open,high,low,close,volume
2025-01-02 09:00:00,130000,130500,129900,130300,1000
```

## Backtest individual

Periodo padrao alinhado ao estudo: 2024-01-01 ate 2026-06-30.

```bash
python backtest.py --symbol WIN --csv data/WINFUT_M5.csv --start 2024-01-01 --end 2026-06-30
python backtest.py --symbol WDO --csv data/WDOFUT_M5.csv --start 2024-01-01 --end 2026-06-30
```

Os wrappers antigos tambem funcionam:

```bash
python run_backtest.py --symbol WIN --csv data/WINFUT_M5.csv --start 2024-01-01 --end 2026-06-30
python run_backtest.py --symbol WDO --csv data/WDOFUT_M5.csv --start 2024-01-01 --end 2026-06-30
```

## Backtest dual WIN + WDO

Este modo processa WIN e WDO no mesmo backtest e permite posicoes simultaneas em ativos diferentes, igual ao EA live.

```bash
python backtest.py --symbol DUAL --win-csv data/WINFUT_M5.csv --wdo-csv data/WDOFUT_M5.csv --start 2024-01-01 --end 2026-06-30
```

Wrapper antigo:

```bash
python run_dual_backtest.py --win-csv data/WINFUT_M5.csv --wdo-csv data/WDOFUT_M5.csv --start 2024-01-01 --end 2026-06-30
```

## Walk-forward

```bash
python walkforward.py --symbol WIN --csv data/WINFUT_M5.csv
python walkforward.py --symbol WDO --csv data/WDOFUT_M5.csv
```

## Metricas minimas do estudo

- Profit Factor >= 1.5.
- Taxa de acerto >= 45%.
- Drawdown maximo <= 15% do capital.
- Numero de trades >= 100 no backtest completo.

## Saidas

Arquivos gerados em `backtest/results/`:

- `*_trades.csv`: lista de operacoes.
- `*_summary.json`: resumo do backtest.
- `*_walkforward.json`: rodadas IS/OOS, parametros vencedores e aprovacao OOS.

## Observacao importante

O `yfinance` fica disponivel como fallback, mas para minicontratos brasileiros ele nao substitui o backtest com dados reais M5 do MT5. Para validacao seria, use `--csv`.
