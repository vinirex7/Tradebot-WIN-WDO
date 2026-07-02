# 🤖 Tradebot WIN-WDO — DUAL TREND SCALPER

Bot de day trade automatizado para **WINFUT (Mini Índice)** e **WDOFUT (Mini Dólar)** na B3, via **MetaTrader 5**, vinculado à **XP Investimentos**.

## 📋 Estratégia: DUAL TREND SCALPER

- **Filosofia:** Tendência intradiária com filtro de momentum
- **Timeframe principal:** M5 | **Filtro de tendência:** M15
- **Indicadores:** EMA 9/21/50 · MACD(12,26,9) · ATR(14)
- **Gestão de risco:** Stop dinâmico por ATR · Break-even · Trailing stop
- **Horários operacionais:** 9h30–12h00 e 14h00–16h30 (horário de Brasília)
- **Capital mínimo recomendado:** R$ 3.000–R$ 5.000

## 📁 Estrutura do Repositório

```
├── Experts/
│   └── DualTrendScalper.mq5      # EA principal (MQL5)
├── Include/
│   └── RiskManager.mqh           # Funções de gestão de risco
├── Scripts/
│   ├── CloseAllPositions.mq5     # Fecha todas as posições (emergência)
│   └── DailyReport.mq5           # Relatório diário de P&L
├── Sets/
│   ├── DualTrendScalper_WIN.set  # Parâmetros otimizados WIN
│   └── DualTrendScalper_WDO.set  # Parâmetros otimizados WDO
├── Tests/
│   └── Walkforward_Config.md     # Configuração de walk-forward testing
├── backtest/                     # (branch infra-1) Backtest Python
│   ├── backtest.py
│   ├── walkforward.py
│   └── requirements.txt
└── docs/
    └── SETUP_XP_MT5.md           # Guia de configuração MT5 + XP
```

## 🚀 Início Rápido

### Live Trading (MT5 + XP)
1. Siga `docs/SETUP_XP_MT5.md` para instalar e configurar o MT5
2. Carregue `Experts/DualTrendScalper.mq5` com o set file correspondente
3. Ative o AutoTrading no MT5

### Backtest Python (branch `infra-1`)
```bash
git checkout infra-1
cd backtest
pip install -r requirements.txt
python backtest.py --symbol WINFUT --start 2024-01-01 --end 2026-06-30
```

## ⚙️ Parâmetros Principais

| Parâmetro       | Valor padrão | Descrição                     |
|-----------------|-------------|-------------------------------|
| ATR_Mult_SL     | 1.2         | Multiplicador do stop loss    |
| RR_Ratio        | 2.0         | Relação risco/retorno mínima  |
| Risco_Reais     | R$ 50       | Risco máximo por operação     |
| Perda_Diaria    | R$ 150      | Trava de perda diária         |
| DD_Max          | R$ 500      | Drawdown máximo (pausa 5d)    |
| MaxTradesWIN    | 3           | Máximo de trades/dia no WIN   |
| MaxTradesWDO    | 3           | Máximo de trades/dia no WDO   |

## ⚠️ Aviso Legal

Este projeto tem finalidade educacional e experimental. Operações em mercados futuros envolvem risco de perda total do capital. Valide sempre com backtest extensivo antes de operar com capital real. Consulte um analista certificado (CNPI) antes de qualquer decisão de investimento.
