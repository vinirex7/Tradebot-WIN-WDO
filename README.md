# Tradebot WIN-WDO — DUAL TREND SCALPER v2.0

Bot de day trade automatizado para **WINFUT (Mini Indice)** e **WDOFUT (Mini Dolar)** na B3, via **MetaTrader 5**, vinculado a **XP Investimentos**.

## Estrategia: DUAL TREND SCALPER v2.0

- **Filosofia:** Tendencia intradiaria com filtro de momentum e volatilidade
- **Timeframe principal:** M5 | **Filtro de tendencia:** M15
- **Indicadores:** EMA 9/21/50 · MACD (independente por ativo) · ATR(14) · RSI(14)
- **Gestao de risco:** Lote dinamico · Stop ATR · Break-even · Trailing stop · Gain Lock
- **Capital minimo recomendado:** R$ 3.000-R$ 5.000

## Changelog v2.0 (vs v1.10)

| # | Tipo | Descricao |
|---|------|-----------|
| FIX-1 | Critico | Handles criados uma vez em `OnInit()` — elimina overhead por tick |
| FIX-2 | Critico | Pausa drawdown **persistente** via `GlobalVariable` (sobrevive a restart) |
| FIX-3 | Critico | **Lote dinamico** pelo risco real em R$ por ativo (antes: fixo em 1 contrato) |
| NEW-1 | Estrategia | **Filtro RSI(14)**: RSI >= 40 compra, RSI <= 60 venda |
| NEW-2 | Estrategia | **MACD parametrizavel por simbolo** (WIN e WDO independentes) |
| NEW-3 | Estrategia | **Janelas de horario independentes** por ativo |
| NEW-4 | Estrategia | Filtro ATR elevado para **70% da media** (era 50%) |
| NEW-5 | Estrategia | MACD usa **histograma crescente** (mais robusto) |
| NEW-6 | Engenharia | **Log CSV estruturado** com todos os campos via `OnTradeTransaction` |
| NEW-7 | Engenharia | **Gain Lock** diario configuravel (`Ganho_Diario`) |

## Estrutura do Repositorio

```
Experts/
  DualTrendScalper.mq5      # EA principal v2.0
Include/
  RiskManager.mqh           # Risco v2: lote dinamico + persistencia DD
  SignalEngine.mqh          # Sinais v2: handles fixos + RSI + MACD/ativo
  TimeFilter.mqh            # Horario v2: janelas independentes por simbolo
  TradeLogger.mqh           # Logger CSV estruturado v2
Sets/
  DualTrendScalper_Default.set  # Params + faixas de otimizacao
  DualTrendScalper_WIN.set      # Set otimizado WIN
  DualTrendScalper_WDO.set      # Set otimizado WDO (MaxTradesWIN=0)
Tests/
  BacktestConfig_WINFUT.ini
  BacktestConfig_WDOFUT.ini
  Walkforward_Config.md
docs/
  SETUP_XP_MT5.md
```

## Inicio Rapido

1. Copie `Include/*.mqh` para `MQL5/Include/`
2. Compile `Experts/DualTrendScalper.mq5` no MetaEditor
3. Carregue com o set file correspondente no MT5
4. Ative o AutoTrading

## Parametros Principais

| Parametro | WIN | WDO | Descricao |
|-----------|-----|-----|----------|
| MACD_R | 12 | 8 | MACD rapida (independente por ativo) |
| MACD_L | 26 | 21 | MACD lenta |
| MACD_S | 9 | 5 | MACD sinal |
| ATR_Mult_SL | 1.2 | 1.5 | Multiplicador stop loss |
| ATR_Filtro_Pct | 0.70 | 0.70 | ATR minimo (% media 20 barras) |
| RSI_Min_Compra | 40 | 40 | RSI minimo para compra |
| RSI_Max_Venda | 60 | 60 | RSI maximo para venda |
| RR_Ratio | 2.0 | 2.0 | Relacao risco/retorno |
| Risco_Reais | R$ 50 | R$ 50 | Risco maximo por operacao |
| Perda_Diaria | R$ 150 | R$ 150 | Trava de perda diaria |
| Ganho_Diario | R$ 300 | R$ 300 | Gain Lock diario |
| DD_Max | R$ 500 | R$ 500 | Drawdown maximo (pausa 5d) |

## Aviso Legal

Este projeto tem finalidade educacional e experimental. Operacoes em mercados futuros envolvem risco de perda total do capital. Valide sempre com backtest extensivo antes de operar com capital real. Consulte um analista certificado (CNPI) antes de qualquer decisao de investimento.
