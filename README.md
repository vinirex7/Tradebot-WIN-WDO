# 🤖 Tradebot WIN-WDO — DUAL TREND SCALPER

Bot de day trade automatizado para **WINFUT (Mini Índice)** e **WDOFUT (Mini Dólar)** na B3, via **MetaTrader 5**, vinculado à **XP Investimentos**.

## 📋 Estratégia: DUAL TREND SCALPER

- **Filosofia:** tendência intradiária com filtro de momentum.
- **Timeframe principal:** M5 | **Filtro de tendência:** M15.
- **Indicadores:** EMA 9/21/50 · MACD(12,26,9) · ATR(14).
- **Filtro de volatilidade:** ATR atual >= 50% da média dos últimos 20 ATRs.
- **Gestão de risco:** stop dinâmico por ATR · break-even · trailing stop.
- **Stops:** WIN = 1.2 x ATR | WDO = 1.5 x ATR.
- **Horários operacionais:** 9h30-12h00 e 14h00-16h30, horário de Brasília/servidor.
- **Fechamento forçado:** 18h10.
- **Capital de referência:** R$ 5.000, operando 1 contrato.
- **Risco:** R$ 50 por operação, trava diária de R$ 150, máximo de 3 trades/dia por ativo.
- **Operação simultânea WIN + WDO:** bloqueada no backtest dual e deve permanecer bloqueada no live.

## 📁 Estrutura do Repositório

```text
Tradebot-WIN-WDO/
├── Experts/
│   └── DualTrendScalper.mq5        # EA principal (cole em MQL5/Experts/)
├── Include/
│   ├── SignalEngine.mqh            # Motor de sinais (EMA + MACD + ATR)
│   ├── RiskManager.mqh             # Gestão de risco e travas diárias
│   ├── TimeFilter.mqh              # Filtro de janelas horárias
│   └── TradeLogger.mqh             # Logger CSV automático
├── Scripts/
│   └── VerificarAmbiente.mq5       # Diagnóstico pré-live
├── Sets/
│   └── DualTrendScalper_Default.set
├── Tests/
│   ├── BacktestConfig_WINFUT.ini
│   └── BacktestConfig_WDOFUT.ini
└── backtest/
    ├── dts_engine.py               # Engine Python alinhada ao estudo/live
    ├── run_backtest.py             # Backtest individual WIN ou WDO
    ├── run_dual_backtest.py        # Backtest WIN+WDO sem simultaneidade
    ├── walkforward.py              # Walk-forward IS/OOS
    ├── requirements.txt
    └── README.md
```

## 🚀 Instalação no MetaTrader 5

```text
MT5 → Arquivo → Abrir pasta de dados → MQL5/
Experts/DualTrendScalper.mq5   → MQL5/Experts/
Include/*.mqh                  → MQL5/Include/
Scripts/VerificarAmbiente.mq5  → MQL5/Scripts/
```

Depois abra o MetaEditor, compile `DualTrendScalper.mq5` com F7 e valide em demo.

## 📊 Backtest no MT5 Strategy Tester

Configuração recomendada pelo estudo:

1. `MT5 → Exibir → Strategy Tester`.
2. Expert: `Experts/DualTrendScalper.mq5`.
3. Símbolo: `WINFUT` ou `WDOFUT` conforme a corretora.
4. Timeframe: M5.
5. Modelo: **Every Tick Based on Real Ticks**.
6. Período sugerido: **2024-01-01 até 2026-06-30**.
7. Otimização: `ATR_Mult_SL` entre 0.8 e 2.0; `EMA_Tendencia` entre 34 e 100.

Métricas mínimas:

| Métrica | Mínimo aceitável |
|---------|------------------|
| Profit Factor | >= 1.5 |
| Taxa de acerto | >= 45% |
| Drawdown máximo | <= 15% |
| Número de trades | >= 100 |

## 🐍 Backtest Python no Termius — branch `infra-1`

```bash
git clone https://github.com/vinirex7/Tradebot-WIN-WDO.git
cd Tradebot-WIN-WDO
git checkout infra-1
cd backtest
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Backtest individual com CSV M5 exportado do MT5:

```bash
python run_backtest.py --symbol WIN --csv data/WINFUT_M5.csv --start 2024-01-01 --end 2026-06-30
python run_backtest.py --symbol WDO --csv data/WDOFUT_M5.csv --start 2024-01-01 --end 2026-06-30
```

Backtest dual, mais parecido com o live porque bloqueia WIN+WDO simultâneo:

```bash
python run_dual_backtest.py --win-csv data/WINFUT_M5.csv --wdo-csv data/WDOFUT_M5.csv --start 2024-01-01 --end 2026-06-30
```

Walk-forward:

```bash
python walkforward.py --symbol WIN --csv data/WINFUT_M5.csv
python walkforward.py --symbol WDO --csv data/WDOFUT_M5.csv
```

## ⚠️ Aviso Legal

Este projeto tem finalidade educacional e experimental. Operações em mercados futuros envolvem risco de perda total do capital. Valide sempre com backtest extensivo e conta demo antes de operar com capital real. Consulte um profissional certificado antes de qualquer decisão de investimento.
