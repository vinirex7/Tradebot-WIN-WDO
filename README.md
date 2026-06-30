# 🤖 DualTrendScalper — Trading Bot WIN & WDO

> **Day trade automatizado** nos minicontratos de Índice (WINFUT) e Dólar (WDOFUT) da B3, operando via MetaTrader 5 conectado à **XP Investimentos**.

---

## 📁 Estrutura do Repositório

```
Tradebot-WIN-WDO/
├── Experts/
│   └── DualTrendScalper.mq5      ← EA principal (cole em MQL5/Experts/)
├── Include/
│   ├── SignalEngine.mqh            ← Motor de sinais (EMA + MACD + ATR)
│   ├── RiskManager.mqh             ← Gestão de risco e travas diárias
│   ├── TimeFilter.mqh              ← Filtro de janelas horárias
│   └── TradeLogger.mqh             ← Logger CSV automático
├── Scripts/
│   └── VerificarAmbiente.mq5      ← Diagnóstico pré-live
├── Sets/
│   └── DualTrendScalper_Default.set ← Parâmetros + faixas de otimização
├── Tests/
│   ├── BacktestConfig_WINFUT.ini   ← Config do Strategy Tester (WIN)
│   └── BacktestConfig_WDOFUT.ini   ← Config do Strategy Tester (WDO)
└── backtest/                        ← Backtest Python (branch infra-1)
```

---

## ⚙️ Estratégia

| Parâmetro | Valor |
|-----------|-------|
| Timeframe operacional | M5 |
| Filtro de tendência | EMA 50 no M15 |
| Entrada | Cruzamento EMA 9/21 confirmado pelo MACD |
| Stop Loss | 1.2 × ATR(14) |
| Take Profit | 2.0 × SL (RR 1:2) |
| Break-even | Ativado a 30% do alvo |
| Trailing stop | Ativado a 50% do alvo, passo = 1 ATR |
| Janelas | 9h30–12h e 14h–16h30 |
| Fechamento forçado | 18h10 |
| Trava de perda diária | R$ 150 |
| Meta de ganho diário | R$ 300 |

---

## 🚀 Instalação no MetaTrader 5

### 1. Abrir pasta de dados
```
MT5 → Arquivo → Abrir pasta de dados → MQL5/
```

### 2. Copiar arquivos
```
Experts/DualTrendScalper.mq5   → MQL5/Experts/
Include/*.mqh                   → MQL5/Include/
Scripts/VerificarAmbiente.mq5  → MQL5/Scripts/
```

### 3. Compilar
```
MetaEditor → Abrir DualTrendScalper.mq5 → F7
Resultado esperado: 0 erros, 0 avisos críticos
```

### 4. Conectar à XP Investimentos
```
Servidor : mt5.xpi.com.br:443
Login    : (seu número de conta)
Senha    : (sua senha MT5 XP)
```

### 5. Verificar ambiente (OBRIGATÓRIO)
```
MT5 → Navigator → Scripts → VerificarAmbiente → Executar
Verificar no log: Trading PERMITIDO, símbolos OK, latência < 150ms
```

---

## 📊 Backtest (MT5 Strategy Tester)

1. `MT5 → Exibir → Strategy Tester`
2. Carregar `Sets/DualTrendScalper_Default.set` na aba **Entradas**
3. Copiar conteúdo de `Tests/BacktestConfig_WINFUT.ini` nas configurações
4. Modelo: **Every Tick** | Período: M5 | 2023–2025
5. Executar e verificar métricas mínimas:

| Métrica | Mínimo aceitável |
|---------|------------------|
| Profit Factor | ≥ 1.4 |
| Drawdown máx. | ≤ 15% |
| Sharpe Ratio | ≥ 0.8 |
| Recovery Factor | ≥ 2.0 |
| Walk-Forward Efficiency | ≥ 0.50 |

---

## 🔄 Walk-Forward

| Período | Datas |
|---------|-------|
| In-Sample (IS) | 2023-01-02 → 2025-03-31 |
| Out-of-Sample (OOS) | 2025-04-01 → 2025-12-31 |
| WFE = Lucro_OOS / Lucro_IS | ≥ 0.50 |

---

## 🐍 Backtest Python (branch `infra-1`)

Simulação do bot em Python com dados reais via `yfinance`, executável no **Termius**:

```bash
git checkout infra-1
cd backtest
pip install -r requirements.txt
python run_backtest.py --symbol WIN --start 2023-01-02 --end 2025-12-31
python run_backtest.py --symbol WDO --start 2023-01-02 --end 2025-12-31
```

---

## ⚠️ Avisos Importantes

- **Teste em conta demo por no mínimo 30 dias** antes de conta real
- O bot **não garante lucro** — mercados são imprevisíveis
- Revise os parâmetros mensalmente
- Este projeto é **educacional** — não constitui recomendação de investimento
- Consulte um profissional certificado (CNPI) antes de operar

---

## 📄 Licença

MIT License — uso livre com atribuição.
