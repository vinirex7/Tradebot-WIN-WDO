# Backtest Python — DualTrendScalper

Backtest Python da branch `infra-1`, preparado para rodar no Termius/VPS e espelhar o funcionamento live do EA MQL5.

## O que ele replica do live

- Timeframe operacional M5.
- Sinal calculado na última barra M5 fechada.
- Entrada na abertura da barra seguinte, reduzindo look-ahead bias.
- Cruzamento EMA 9/21.
- Filtro de tendência com EMA 50 no M15.
- Confirmação MACD(12,26,9).
- Filtro de volatilidade: ATR(14) atual >= 50% da média dos últimos 20 ATRs.
- Stop Loss por ATR: WIN = 1.2 x ATR; WDO = 1.5 x ATR.
- Take Profit = Stop x 2.0.
- Break-even ao atingir 30% do alvo.
- Trailing stop ao atingir 50% do alvo, com distância de 1 ATR.
- Janelas operacionais: 09:30-12:00 e 14:00-16:30.
- Fechamento forçado às 18:10.
- Trava de perda diária de R$ 150.
- Máximo de 3 operações por dia por ativo.
- Modo dual WIN+WDO bloqueia posições simultâneas, igual ao EA live.

## Instalação no Termius

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

Use dados M5 exportados do MetaTrader 5/XP. O caminho com CSV é o mais confiável para WIN/WDO.

```csv
datetime,open,high,low,close,volume
2025-01-02 09:00:00,130000,130500,129900,130300,1000
```

## Backtest individual

Período padrão alinhado ao estudo: 2024-01-01 até 2026-06-30.

```bash
python run_backtest.py --symbol WIN --csv data/WINFUT_M5.csv --start 2024-01-01 --end 2026-06-30
python run_backtest.py --symbol WDO --csv data/WDOFUT_M5.csv --start 2024-01-01 --end 2026-06-30
```

## Backtest dual WIN + WDO

Este modo é o mais parecido com o live quando o EA está no gráfico processando os dois símbolos. Ele processa WIN primeiro e WDO depois, bloqueando posição simultânea.

```bash
python run_dual_backtest.py --win-csv data/WINFUT_M5.csv --wdo-csv data/WDOFUT_M5.csv --start 2024-01-01 --end 2026-06-30
```

## Walk-forward

```bash
python walkforward.py --symbol WIN --csv data/WINFUT_M5.csv
python walkforward.py --symbol WDO --csv data/WDOFUT_M5.csv
```

## Métricas mínimas do estudo

- Profit Factor >= 1.5.
- Taxa de acerto >= 45%.
- Drawdown máximo <= 15% do capital.
- Número de trades >= 100 no backtest completo.

## Saídas

Arquivos gerados em `backtest/results/`:

- `*_trades.csv`: lista de operações.
- `*_summary.json`: resumo do backtest.
- `*_walkforward.json`: rodadas IS/OOS, parâmetros vencedores e aprovação OOS.

## Observação importante

O `yfinance` fica disponível como fallback, mas para minicontratos brasileiros ele não substitui o backtest com dados reais M5 do MT5. Para validação séria, use `--csv`.
