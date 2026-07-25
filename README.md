# 🤖 Tradebot WIN-WDO — DUAL TREND SCALPER v2.0

Bot de day trade automatizado para **WINFUT (Mini Índice)** e **WDOFUT (Mini Dólar)** na B3,
via **MetaTrader 5** vinculado à **XP Investimentos**.

---

## ⚡ Início Rápido — Clone and Run

### Único pré-requisito
Ter o **MetaTrader 5 da XP** instalado: https://www.xpi.com.br/plataformas/metatrader5/

### 3 passos

```bash
# 1. Clonar o repositorio
git clone https://github.com/vinirex7/Tradebot-WIN-WDO
cd Tradebot-WIN-WDO
```

```
# 2. Setup (executar UMA VEZ — clique direito > Executar como Administrador)
scripts\setup.bat
```

```
# 3. Rodar backtest
scripts\run_backtest_WIN.bat      <- Backtest WINFUT
scripts\run_backtest_WDO.bat      <- Backtest WDOFUT
scripts\run_backtest_AMBOS.bat    <- WIN + WDO em sequencia
```

### O que o setup.bat faz automaticamente
- ✅ Detecta onde o MT5 está instalado
- ✅ Copia `DualTrendScalper.mq5` para `MQL5\Experts\`
- ✅ Copia os 4 arquivos `.mqh` para `MQL5\Include\`
- ✅ Compila o EA via `metaeditor64.exe /compile`
- ✅ Cria as pastas `reports\` e `logs\`
- ✅ Salva `scripts\config.bat` com os caminhos do seu PC (não vai para o git)

### Única ação manual necessária (feita uma vez após o setup)
Abrir o MT5, fazer login na conta XP e baixar o histórico:
```
Tools > History Center > WINFUT > M5  > Download
Tools > History Center > WINFUT > M15 > Download
Tools > History Center > WDOFUT > M5  > Download
Tools > History Center > WDOFUT > M15 > Download
```

---

## 📁 Estrutura do Repositório

```
Tradebot-WIN-WDO/
├── Experts/
│   └── DualTrendScalper.mq5        # EA principal v2.0
├── Include/
│   ├── RiskManager.mqh             # Lote dinâmico + pausa DD persistente
│   ├── SignalEngine.mqh            # EMA + MACD/ativo + RSI + ATR (handles fixos)
│   ├── TimeFilter.mqh              # Janelas independentes WIN vs WDO
│   └── TradeLogger.mqh             # Log CSV estruturado por operação
├── Sets/
│   ├── DualTrendScalper_Default.set
│   ├── DualTrendScalper_WIN.set
│   └── DualTrendScalper_WDO.set
├── Tests/
│   ├── BacktestConfig_WINFUT.ini
│   ├── BacktestConfig_WDOFUT.ini
│   ├── OnTester_Criterio.mq5
│   ├── Walkforward_Config.md
│   └── CHECKLIST_BACKTEST.md
├── scripts/                        # <- PASTA PRINCIPAL DE AUTOMACAO
│   ├── setup.bat                   # <- EXECUTAR PRIMEIRO (uma vez)
│   ├── compile_ea.bat              # Recompila o EA
│   ├── run_backtest_WIN.bat        # Backtest WINFUT
│   ├── run_backtest_WDO.bat        # Backtest WDOFUT
│   ├── run_backtest_AMBOS.bat      # WIN + WDO em sequencia
│   └── config.bat                  # gerado pelo setup (nao vai pro git)
├── docs/
│   └── SETUP_XP_MT5.md
├── reports/                        # gerado localmente (nao vai pro git)
└── logs/                           # gerado localmente (nao vai pro git)
```

---

## ⚙️ Estratégia v2.0

| Parâmetro | WIN | WDO |
|-----------|-----|-----|
| Timeframe | M5 + filtro M15 | M5 + filtro M15 |
| EMA rápida/lenta/tendência | 9 / 21 / 50 | 9 / 21 / 50 |
| MACD | (12, 26, 9) | **(8, 21, 5)** |
| ATR Mult SL | 1.2x | **1.5x** |
| ATR Filtro | 70% média 20b | 70% média 20b |
| RSI compra/venda | ≥40 / ≤60 | ≥40 / ≤60 |
| RR Ratio | 2.0 | 2.0 |
| Janela 1 | 09:30–11:00 | **10:00–12:00** |
| Janela 2 | 14:00–16:30 | **14:00–15:30** |
| Risco/trade | R$ 50 (dinâmico) | R$ 50 (dinâmico) |
| Perda diária | R$ 150 | R$ 150 |
| Gain Lock | R$ 300 | R$ 300 |

---

## 🎯 Critérios de Aprovação no Backtest

| Métrica | Mínimo | Ideal |
|---------|--------|-------|
| Profit Factor | ≥ 1.4 | ≥ 1.8 |
| Max Drawdown | ≤ 15% | ≤ 10% |
| Sharpe Ratio | ≥ 0.8 | ≥ 1.2 |
| Win Rate | ≥ 45% | ≥ 55% |
| WFE (OOS/IS) | ≥ 0.50 | ≥ 0.65 |
| Total Trades | ≥ 30 | ≥ 100 |

---

## ⚠️ Aviso Legal

Este projeto tem finalidade educacional e experimental. Operações em mercados futuros envolvem risco de perda total do capital. Valide com backtest extensivo antes de operar com capital real. Consulte um analista certificado (CNPI) antes de qualquer decisão de investimento.
