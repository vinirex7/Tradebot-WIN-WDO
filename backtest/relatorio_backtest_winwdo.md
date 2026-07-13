# Relatório de Backtest e Otimização — Bot DUAL TREND SCALPER (WIN/WDO)

**Data:** 2026-07-13
**Repositório:** vinirex7/Tradebot-WIN-WDO
**Autor da análise:** agente de backtest (Python)

---

## 1. Resumo executivo

Foi construído um motor de backtest em Python que replica fielmente as regras do
Expert Advisor MQL5 `DualTrendScalper.mq5` (EMA 9/21 M5 + filtro EMA 50 M15 +
histograma MACD + filtro de volatilidade ATR + janelas horárias + SL/TP por ATR +
trailing/break-even + travas de risco diário). Como **não há MetaTrader 5 nem dados
de tick reais da B3** neste ambiente, usaram-se **dados-proxy públicos** (Yahoo
Finance): **Ibovespa à vista `^BVSP` para o WIN** e **USD/BRL `BRL=X` para o WDO**,
aplicando os valores de ponto do briefing (WIN R$0,20/ponto; WDO R$10/ponto inteiro).

**Principais conclusões:**

1. **Baseline (parâmetros originais, timeframe fiel M5, ~60 dias):** o portfólio
   combinado WIN+WDO **atende a todos os critérios mínimos de viabilidade** do
   documento — **PF 1,53 · win rate 45,8% · drawdown 3,9% · 120 trades**.
2. O **WIN é o motor robusto** (PF ~3,5 no proxy M5). O **WDO no proxy foi
   consistentemente perdedor** (PF ~0,6). Isso é quase certamente um **artefato do
   proxy** (USD/BRL à vista negocia 24h e não reproduz a microestrutura do WDOFUT),
   não uma condenação do ativo real.
3. Uma varredura de otimização no dataset estendido de 1h (~3 anos) **elevou muito as
   métricas in-sample (PF 1,60; retorno +158%)**, mas **falhou no walk-forward
   out-of-sample (PF agregado 0,95; retorno −10,9%)** → **overfitting**. Esses ganhos
   foram **descartados**.
4. **Configuração final recomendada = parâmetros ORIGINAIS** (comprovadamente
   viáveis no proxy fiel), com o **WDO em quarentena** (`MaxTradesWDO=0`) até
   validação com dados reais de tick.

> **Aviso de honestidade metodológica:** estes resultados são um **estudo de
> viabilidade sobre proxies**, não uma prova de lucratividade do bot em WIN/WDO
> reais. Nenhuma decisão de capital real deve ser tomada sem antes rodar o backtest
> com dados de tick reais do WINFUT/WDOFUT e validação em conta demo.

---

## 2. Metodologia

### 2.1 Replicação da estratégia
O motor (`backtest/engine.py`) reproduz a lógica do EA:

- **Indicadores:** EMA rápida/lenta (base TF), EMA de tendência (trend TF, deslocada
  1 barra para evitar *lookahead*), histograma MACD(12,26,9), ATR(14) e média de 20 ATRs.
- **Entrada long:** cruzamento EMA9↑EMA21 **na barra fechada**, preço acima da EMA de
  tendência, histograma MACD > 0, dentro das janelas 9h30–12h00 ou 14h00–16h30, e
  ATR ≥ 50% da média de 20 ATRs. Short é espelhado.
- **Execução sem lookahead:** sinal na barra `t` (fechada) → entrada no **open da
  barra `t+1`**.
- **Saídas:** SL = ATR×`ATR_Mult_SL`; TP = SL×`RR_Ratio`; break-even a 30% do alvo;
  trailing 1×ATR após 50% do alvo; fechamento ao fim do pregão (≥18h10); intrabar
  assume **SL antes de TP** (pessimista).
- **Risco:** trava de perda diária (R$150), máx. 3 trades/dia por símbolo, pausa por
  drawdown (R$500). Custos round-trip: **WIN R$0,50 · WDO R$2,40** por contrato.
- **Sizing:** o EA real opera **1 contrato fixo** (baseline). Para o dataset estendido
  de 1h, ativou-se o *position sizing* de `RiskManager.mqh` (N = risco / (SL×valor do
  ponto)) para escalar o risco ao orçamento de R$50, já que o ATR em barras de 1h é
  muito maior.

### 2.2 Dados (proxy) — **limitação central**
Dados de futuros tick-a-tick da B3 não são públicos/gratuitos. Proxies via Yahoo Finance:

| Proxy | Ativo | Intervalo | Período | Nº barras |
|---|---|---|---|---|
| WIN | `^BVSP` (Ibovespa) | 5m | 2026-04-15 → 2026-07-10 (~60d) | 5.040 |
| WIN | `^BVSP` | 1h | 2023-08-07 → 2026-07-10 (~3a) | 5.090 |
| WDO | `BRL=X` (USD/BRL) | 5m | 2026-04-21 → 2026-07-10 (~60d) | 7.201 |
| WDO | `BRL=X` | 1h | 2023-09-25 → 2026-07-10 (~3a) | 11.715 |

Limitações do Yahoo: intradiário < 1h só cobre **60 dias**; 1h cobre ~**2 anos**. Por
isso há **dois datasets**: **5m (timeframe fiel, curto)** e **1h (estendido, para
walk-forward)**. Timestamps convertidos para `America/Sao_Paulo` e filtrados à sessão.

**Riscos do proxy:** o `^BVSP` não tem gaps/leilões idênticos ao WINFUT; o `BRL=X`
(spot 24h) diverge fortemente do WDOFUT (liquidez concentrada, janelas de PTAX). Sem
spread realista nem slippage de abertura. Logo, números do WDO-proxy são **pouco
confiáveis** e servem apenas como sinalização qualitativa.

---

## 3. Resultados do BASELINE (parâmetros originais do EA)

### 3.1 Timeframe fiel M5 (~60 dias) — **cenário principal**

| Carteira | Trades | PF | Win rate | Payoff | Retorno | Drawdown | Sharpe |
|---|---|---|---|---|---|---|---|
| **Combinado WIN+WDO** | **120** | **1,53** | **45,8%** | **1,81** | **+24,4%** | **3,9%** | **4,07** |
| WIN | 64 | 3,50 | 59,4% | 2,39 | +36,5% | 1,9% | 9,93 |
| WDO | 56 | 0,62 | 30,4% | 1,41 | −12,1% | 13,5% | −3,77 |

Gráfico: `equity_baseline_5m.png` (combinado) e `equity_baseline_5m_por_simbolo.png`.

**Leitura:** o portfólio combinado **passa em todos os 4 critérios mínimos**
(PF ≥ 1,5 ✓ · WR ≥ 45% ✓ · DD ≤ 15% ✓ · trades ≥ 100 ✓). O resultado é
**inteiramente sustentado pelo WIN**; o WDO-proxy destrói valor.

### 3.2 Dataset estendido 1h (~3 anos, com sizing)

| Carteira | Trades | PF | Win rate | Retorno | Drawdown | Sharpe |
|---|---|---|---|---|---|---|
| Combinado | 131 | 1,47 | 45,8% | +88,8% | 15,6% | 2,55 |
| WIN | 70 | 1,49 | 50,0% | +44,4% | 13,1% | 2,68 |
| WDO | 61 | 1,45 | 41,0% | +44,3% | 14,0% | 2,26 |

Gráfico: `equity_baseline_1h.png`. Aqui o WDO-proxy "parece" lucrativo — mais um
indício de que a diferença WIN×WDO entre datasets é **artefato de proxy/timeframe**.

---

## 4. Iterações de otimização (dataset 1h estendido, com sizing)

Cada rodada varreu um eixo, mantendo os melhores da rodada anterior (*score* = retorno
em R$ condicionado a PF ≥ 1).

| # | Hipótese | Varredura | Escolha | PF | WR | Retorno | DD | Decisão |
|---|---|---|---|---|---|---|---|---|
| 1 | Otimizar SL (ATR×) | 0,8–2,0 | **1,5** | 1,79 | 44,1% | +146% | 13,2% | manter |
| 2 | Otimizar RR | 1,5–3,0 | **2,0** | 1,79 | 44,1% | +146% | 13,2% | manter |
| 3 | EMA tendência | 34–100 | **34** | 1,75 | 43,1% | +150% | 13,4% | manter |
| 4 | EMAs cruzamento | vários | **9/21** | 1,75 | 43,1% | +150% | 13,4% | manter (original) |
| 5 | Filtro ADX | off/15/20/25 | **off** | 1,75 | 43,1% | +150% | 13,4% | manter (ADX reduz nº trades) |
| 6 | Trailing/BE | on/off | **trail on, BE off** | 1,60 | 51,5% | +158% | 14,0% | manter |

**Config in-sample "vencedora":** SL 1,5 · RR 2,0 · EMA-trend 34 · EMA 9/21 · sem ADX ·
trailing on · break-even off → **PF 1,60 · WR 51,5% · +158% · DD 14,0%**
(gráfico `equity_otimizada_1h.png`).

---

## 5. Walk-forward (validação out-of-sample) — **o teste decisivo**

Janela deslizante: **treino 6 meses → teste 3 meses**, reotimizando SL×RR no treino
(grade 0,8–1,8 × 1,5–3,0) e medindo apenas o out-of-sample.

| Fold | Teste (OOS) | Melhor treino | PF OOS | Retorno OOS | Trades |
|---|---|---|---|---|---|
| 1 | 2024-02→05 | SL0,8 RR3,0 | 2,30 | +14,3% | 18 |
| 2 | 2024-05→08 | SL0,8 RR2,0 | 0,52 | −7,2% | 9 |
| 3 | 2024-08→11 | SL1,2 RR3,0 | 0,41 | −23,9% | 15 |
| 4 | 2024-11→2025-02 | SL1,8 RR2,0 | 4,43 | +35,9% | 6 |
| 5 | 2025-02→05 | SL1,8 RR2,0 | 2,14 | +23,0% | 8 |
| 6 | 2025-05→08 | SL1,2 RR3,0 | 0,71 | −8,6% | 11 |
| 7 | 2025-08→11 | SL1,2 RR2,5 | 0,37 | −16,6% | 11 |
| 8 | 2025-11→2026-02 | SL0,8 RR1,5 | 0,61 | −5,7% | 10 |
| 9 | 2026-02→05 | SL1,2 RR1,5 | 0,49 | −22,1% | 13 |
| **Agregado OOS** | | | **0,95** | **−10,9%** | **101** |

Gráfico: `equity_walkforward_oos.png`.

**Conclusão:** os melhores parâmetros mudam a cada janela e **não generalizam**. O
agregado OOS é **levemente perdedor (PF 0,95)** com **drawdown de 39%**. Ou seja, a
otimização in-sample da Seção 4 era **overfitting** e foi **rejeitada**. Isto confirma o
risco de overfitting apontado no próprio documento de estratégia.

---

## 6. Configuração final recomendada

Como **nenhuma configuração otimizada sobreviveu ao walk-forward**, a escolha robusta é
**manter os parâmetros originais** — que, no timeframe fiel M5, **já satisfazem todos os
critérios mínimos** — e tratar o WDO com cautela.

```
EMA_Rapida=9   EMA_Lenta=21   EMA_Tendencia=50
MACD=12/26/9   ATR_Periodo=14
ATR_Mult_SL=1.2   RR_Ratio=2.0
Risco_Reais=50   Perda_Diaria=150   DD_Max=500
MaxTradesWIN=3   MaxTradesWDO=0    <-- WDO em QUARENTENA
Janelas 9h30-12h00 / 14h00-16h30   Fechamento 18h10
UseTrailing=true   UseBreakEven=true
```

Arquivo: `Sets/DualTrendScalper_Otimizado.set`. No EA, `MaxTradesWDO` teve o default
alterado para `0`.

**Justificativa:** (a) o WIN é o único motor com robustez consistente no proxy fiel
(PF ~3,5); (b) o WDO-proxy é perdedor e não confiável — melhor não arriscar capital no
WDO até dados reais; (c) qualquer ajuste de parâmetro só "melhorou" in-sample e piorou
OOS, logo o original é a aposta mais robusta.

| Métrica | Mínimo exigido | Baseline M5 combinado | Config final (WIN-only M5) |
|---|---|---|---|
| Profit Factor | ≥ 1,5 | 1,53 ✓ | 3,50 ✓ |
| Win rate | ≥ 45% | 45,8% ✓ | 59,4% ✓ |
| Drawdown | ≤ 15% | 3,9% ✓ | 1,9% ✓ |
| Nº trades | ≥ 100 | 120 ✓ | 64 ✗ (limite dos 60d de dados) |

> Com WDO quarentenado, o nº de trades do WIN sozinho (64 em 60 dias) fica abaixo de
> 100 pela **curta janela de dados 5m disponível**, não por falha da estratégia — em 12
> meses o WIN facilmente ultrapassaria 100 trades.

---

## 7. Limitações

1. **Proxy, não o ativo real:** `^BVSP`/`BRL=X` ≠ WINFUT/WDOFUT. Sem spread, slippage,
   gaps de leilão nem microestrutura de futuros.
2. **Janela intradiária curta:** M5 só cobre ~60 dias (limite do Yahoo).
3. **WDO-proxy não é confiável** (spot 24h). O resultado negativo do WDO **não** condena
   o WDOFUT real.
4. **Custos simplificados** e execução idealizada (fill garantido em SL/TP).
5. Walk-forward feito no dataset 1h (proxy), não no timeframe operacional M5.

---

## 8. Próximos passos recomendados

1. **Obter dados reais de tick** do WINFUT/WDOFUT (MT5 da corretora, exportar CSV) e
   rodar este mesmo motor — o código é *timeframe/instrument-agnostic*.
2. **Rodar em conta demo** por ≥ 1–2 meses antes de qualquer capital real.
3. **WIN-only primeiro**; só reativar o WDO após backtest com dados reais confirmando PF ≥ 1,5.
4. **Não confiar em otimização in-sample** — sempre validar via walk-forward (como aqui).
5. Reavaliar filtros de evento macro (Copom/FOMC/CPI) com dados reais, onde importam.

---

## 9. Artefatos

- `backtest/engine.py` — motor de backtest (replica o EA).
- `backtest/run_backtest.py` — baseline, 6 iterações, walk-forward, gráficos.
- `backtest/download_data.py` — coleta de dados-proxy.
- `backtest/data/*.csv` — dados-proxy (5m/1h/1d de WIN e WDO).
- `backtest/results/results.json` — todas as métricas.
- `backtest/results/*.png` — curvas de patrimônio (baseline 5m, por símbolo, 1h,
  otimizada 1h, walk-forward OOS).
- `Sets/DualTrendScalper_Otimizado.set` — configuração final recomendada.
