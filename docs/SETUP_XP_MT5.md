# Configuração MT5 — XP Investimentos

## 1. Instalação e Login

1. Baixe o MT5 em: https://www.xpi.com.br/plataformas/metatrader5/
2. Servidor XP: `XPInvestimentos-MT5` (ou conforme informado pela corretora)
3. Login com suas credenciais da conta XP
4. Fuso horário do servidor XP: **UTC-3 (Brasília)** — confirme em Tools → Options → Server

## 2. Símbolos Corretos na XP

| Ativo | Código na XP MT5 |
|-------|------------------|
| Mini Índice (contínuo) | `WINFUT` |
| Mini Dólar (contínuo)  | `WDOFUT` |
| Mini Índice (vencimento específico) | `WINQ26`, `WINU26`, etc. |
| Mini Dólar (vencimento específico)  | `WDON26`, etc. |

> **Importante:** Use sempre o símbolo **contínuo** (`WINFUT`/`WDOFUT`) para o bot. O rollover é automático.

## 3. Instalação do EA

1. Copie `Experts/DualTrendScalper.mq5` para:
   ```
   C:\Users\<usuário>\AppData\Roaming\MetaQuotes\Terminal\<ID>\MQL5\Experts\
   ```
2. Copie `Include/RiskManager.mqh` para:
   ```
   ...\MQL5\Include\
   ```
3. No MT5: **Navigator** → Experts → botão direito → **Refresh**
4. Compile: clique duplo no EA → **Compile** (F7)

## 4. Carregando o Set File

1. Arraste o EA `DualTrendScalper` para o gráfico WINFUT M5
2. Na janela de parâmetros, clique em **Load** e selecione `Sets/DualTrendScalper_WIN.set`
3. Marque **Allow Algo Trading**
4. Confirme **OK**

## 5. Configurações obrigatórias no MT5

- **Tools → Options → Expert Advisors:**
  - ✅ Allow automated trading
  - ✅ Allow DLL imports
  - ✅ Allow modification of Signals settings
- **Gráfico:** timeframe **M5** para o símbolo que o EA está anexado
- **AutoTrading:** botão verde ativo na barra de ferramentas

## 6. Checklist Pré-Live

- [ ] Backtest realizado ≥ 12 meses com dados reais (`Every Tick Based on Real Ticks`)
- [ ] Conta demo operada ≥ 30 dias com resultados positivos
- [ ] Horário do servidor MT5 alinhado com horário de Brasília
- [ ] Margem day trade habilitada para WIN e WDO (verificar com XP)
- [ ] Trava de perda diária testada em simulação
- [ ] VPS configurada (recomendado) para evitar desconexão durante o pregão
- [ ] Script `CloseAllPositions.mq5` testado para emergência
- [ ] Planilha de controle de DARF aberta para apuração mensal de IR

## 7. VPS Recomendada

Para operação 24/7 sem depender do computador local:
- Latência com servidores B3: < 5ms (use VPS em São Paulo)
- Provedores sugeridos: Contabo SP, Kamatera São Paulo, AWS sa-east-1
- Configuração mínima: 2 vCPU, 4 GB RAM, Windows Server 2019
