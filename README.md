# 🤖 Tradebot WIN-WDO — DualTrendScalper

Bot de Day Trade automatizado para os minicontratos **WINFUT (Mini Índice)** e **WDOFUT (Mini Dólar)** na B3, operando via **MetaTrader 5** conectado à **XP Investimentos**.

---

## 📁 Estrutura do Repositório

```
Tradebot-WIN-WDO/
├── Experts/
│   └── DualTrendScalper.mq5          ← EA principal (copiar para MQL5/Experts/)
├── Include/
│   ├── SignalEngine.mqh              ← Motor de sinais (EMA + MACD + ATR)
│   ├── RiskManager.mqh              ← Gestão de risco e travas diárias
│   ├── TimeFilter.mqh               ← Filtros de janela horária B3
│   └── TradeLogger.mqh              ← Log CSV de todas as operações
├── Scripts/
│   └── VerificarAmbiente.mq5        ← Diagnóstico pré-live (execute primeiro!)
├── Sets/
│   └── DualTrendScalper_Default.set ← Parâmetros + faixas de otimização
├── Tests/
│   ├── BacktestConfig_WINFUT.ini    ← Configuração Strategy Tester (WIN)
│   └── BacktestConfig_WDOFUT.ini    ← Configuração Strategy Tester (WDO)
└── README.md
```

---

## 🚀 Instalação Rápida

### 1. Pré-requisitos

- MetaTrader 5 instalado via portal XP Investimentos
- Conta habilitada: **Minha Conta → Ferramentas e Serviços → MetaTrader 5**
- Servidores disponíveis:
  - **Demo:** `demo.mt5.xpi.com.br:443`
  - **Real:** `mt5.xpi.com.br:443`

### 2. Instalar arquivos no MT5

Localize a pasta de dados do MT5:
**Arquivo → Abrir pasta de dados** → navegue até `MQL5/`

```
MQL5/
├── Experts/   ← copie DualTrendScalper.mq5
└── Include/   ← copie os 4 arquivos .mqh
```

Depois, no MetaEditor (F4):
1. Abra `DualTrendScalper.mq5`
2. Pressione **F7** (Compilar)
3. Verifique: **0 erros** no painel inferior

### 3. Conectar à XP no MT5

1. **Arquivo → Abrir uma conta**
2. Pesquise `XP` na lista de corretoras
3. Selecione **XP Investimentos** → Avançar
4. Escolha **"Conectar a uma conta existente"**
5. Informe seu **login** e **senha** enviados por e-mail pela XP
6. Servidor real: `mt5.xpi.com.br:443`

### 4. Adicionar WINFUT e WDOFUT

1. **Ctrl+U** → Janela de Símbolos
2. Expanda `Futuros Minicontratos` (ou pesquise `WIN`, `WDO`)
3. Duplo clique para adicionar à Observação do Mercado

> ⚠️ Use sempre o contrato com maior volume aberto (liquidez). Verifique o vencimento ativo.

---

## ⚙️ Ativação do EA no Gráfico (Live)

1. Abra gráfico **WINFUT M5**
2. Habilite: botão **AutoTrading** na barra de ferramentas
3. Verifique: **Ferramentas → Opções → Expert Advisors** → ✅ Permitir trading automatizado
4. Arraste `DualTrendScalper` do Navegador para o gráfico
5. Clique **Carregar** → selecione `Sets/DualTrendScalper_Default.set`
6. Confirme: **`:)`** no canto superior direito do gráfico

> O EA opera tanto WIN quanto WDO a partir de **um único gráfico**.

---

## 🔬 Backtest e Walk-Forward

### Backtest básico

1. **Ctrl+R** → Strategy Tester
2. Configure:
   - Expert: `DualTrendScalper`
   - Símbolo: `WINFUT` (depois repita para WDOFUT)
   - Período: `M5` | Modelagem: `Every tick (ticks reais)`
   - Datas: `2023.01.02` → `2025.12.31`
   - Depósito: `5000 BRL`
3. Clique **Iniciar**

### Walk-Forward (validação de robustez)

1. Ative **Otimização** → clique **Avançar**
2. Data forward: `2025.07.01` (75% in-sample / 25% out-of-sample)
3. Critério: **Critério personalizado** (score = Sharpe × Profit Factor)
4. **WFE (Walk-Forward Efficiency) ≥ 0.50 = estratégia robusta**

### Parâmetros otimizáveis

| Parâmetro | Padrão | Min | Max | Passo |
|-----------|--------|-----|-----|-------|
| EMA Rápida | 9 | 5 | 15 | 3 |
| EMA Lenta | 21 | 15 | 30 | 3 |
| ATR Mult SL | 1.2 | 0.8 | 2.0 | 0.2 |

---

## 📊 Estratégia: Dual Trend Scalper

### Lógica de Entrada

```
COMPRA:
  ✅ EMA 9 cruza acima da EMA 21 (M5)
  ✅ Preço > EMA 50 (M15) — tendência de alta
  ✅ Histograma MACD (12,26,9) > 0
  ✅ ATR atual ≥ 50% da média ATR 20 — volatilidade ok
  ✅ Dentro da janela horária (9h30–12h ou 14h–16h30)

VENDA: condições inversas
```

### Gestão

| Feature | Configuração |
|---------|--------------|
| Stop Loss | 1.2 × ATR(14) |
| Take Profit | SL × 2.0 (R:R = 1:2) |
| Break-even | Ativa em 30% do alvo → SL para entrada |
| Trailing stop | Ativa em 50% do alvo → SL segue 1×ATR |
| Fechamento forçado | Após 18h10 |

### Risco (Capital R$ 5.000)

| Parâmetro | Valor |
|-----------|-------|
| Risco/trade | R$ 50 (1%) |
| Trava de perda diária | R$ 150 (3%) |
| Meta de ganho diário | R$ 300 (6%) |

---

## 🔌 Servidores XP Investimentos

| Ambiente | Servidor |
|----------|----------|
| Demo | `demo.mt5.xpi.com.br:443` |
| Real | `mt5.xpi.com.br:443` |

---

## 📋 Checklist Pré-Live

- [ ] Compilou sem erros (0 errors no MetaEditor)
- [ ] Script `VerificarAmbiente` mostra ✅ em todos os itens
- [ ] Backtest com `Every tick` por ≥ 1 ano
- [ ] Walk-Forward Efficiency ≥ 0.50
- [ ] Testado em conta **DEMO** por mínimo 30 dias
- [ ] AutoTrading habilitado no terminal
- [ ] EA ativo no gráfico (`:)` visível)

---

## ⚠️ Aviso de Risco

Trading automatizado envolve risco de perda total do capital. Este projeto é para fins **educacionais**. Sempre teste em demo antes de conta real.

---

*DualTrendScalper v1.00 | [github.com/vinirex7/Tradebot-WIN-WDO](https://github.com/vinirex7/Tradebot-WIN-WDO)*
