"""
Motor de backtest do DUAL TREND SCALPER (replica a lógica do EA MQL5).

Replicação fiel das regras do EA (Experts/DualTrendScalper.mq5):
  - EMA rápida/lenta (base TF) + cruzamento
  - Filtro de tendência EMA (trend TF, ex. M15)
  - Confirmação MACD (histograma) na base TF
  - Filtro de volatilidade: ATR atual >= 50% da média de 20 ATRs
  - Janelas horárias 9h30-12h00 e 14h00-16h30
  - SL/TP dinâmicos por ATR (SL = ATR*mult, TP = SL*RR)
  - Break-even (30% do alvo) e trailing stop (após 50% do alvo, trail 1*ATR)
  - Fechamento antes do fim de pregão
  - Trava de perda diária, máx trades/dia, drawdown máximo (pausa)
  - Custos operacionais round-trip por contrato

Timeframe-agnostico: base_tf_min / trend_tf_min definem a granularidade.
Executa sobre dados-proxy (^BVSP para WIN, USDBRL para WDO).
"""
from dataclasses import dataclass, field, asdict
import numpy as np
import pandas as pd


# ---- especificação dos instrumentos (proxy) ----
# money_per_price: R$ por 1.0 de variação de PREÇO do proxy, por contrato.
#   WIN: preço = pontos Ibovespa; 1 ponto = R$0,20  -> 0.20
#   WDO: preço = USD/BRL; 1.0 de USDBRL = 1000 pontos * R$10 = R$10.000 -> 10000
INSTRUMENTS = {
    "WIN": dict(money_per_price=0.20, cost_roundtrip=0.50, min_tp_pts=0.0),
    "WDO": dict(money_per_price=10000.0, cost_roundtrip=2.40, min_tp_pts=0.0),
}


@dataclass
class Params:
    ema_fast: int = 9
    ema_slow: int = 21
    ema_trend: int = 50
    macd_fast: int = 12
    macd_slow: int = 26
    macd_signal: int = 9
    atr_period: int = 14
    atr_mult_sl: float = 1.2
    rr_ratio: float = 2.0
    vol_filter: float = 0.50          # ATR atual >= vol_filter * media(20)
    risco_reais: float = 50.0
    perda_diaria: float = 150.0
    dd_max: float = 500.0
    max_trades: int = 3               # por dia, por símbolo
    janela1: tuple = (9 * 60 + 30, 12 * 60)     # min do dia
    janela2: tuple = (14 * 60, 16 * 60 + 30)
    fechamento_min: int = 18 * 60 + 10
    use_trailing: bool = True
    use_breakeven: bool = True
    be_pct: float = 0.30
    trail_pct: float = 0.50
    trail_atr_mult: float = 1.0
    use_sizing: bool = False          # EA real usa 1 contrato fixo; sizing opcional
    # filtros adicionais (usados nas iterações; desligados por padrão)
    adx_period: int = 0               # 0 = desativado
    adx_min: float = 0.0
    allowed_weekdays: tuple = (0, 1, 2, 3, 4)  # seg..sex
    macd_gate: bool = True            # exigir confirmação MACD
    risk_check_mult: float = 1.5      # pula trade se risco 1-contrato > risco*mult


def ema(s, n):
    return s.ewm(span=n, adjust=False).mean()


def atr(df, n):
    h, l, c = df["High"], df["Low"], df["Close"]
    pc = c.shift(1)
    tr = pd.concat([(h - l), (h - pc).abs(), (l - pc).abs()], axis=1).max(axis=1)
    return tr.ewm(alpha=1 / n, adjust=False).mean()


def adx(df, n):
    h, l, c = df["High"], df["Low"], df["Close"]
    up = h.diff()
    dn = -l.diff()
    plus_dm = np.where((up > dn) & (up > 0), up, 0.0)
    minus_dm = np.where((dn > up) & (dn > 0), dn, 0.0)
    pc = c.shift(1)
    tr = pd.concat([(h - l), (h - pc).abs(), (l - pc).abs()], axis=1).max(axis=1)
    atr_ = tr.ewm(alpha=1 / n, adjust=False).mean()
    plus_di = 100 * pd.Series(plus_dm, index=df.index).ewm(alpha=1 / n, adjust=False).mean() / atr_
    minus_di = 100 * pd.Series(minus_dm, index=df.index).ewm(alpha=1 / n, adjust=False).mean() / atr_
    dx = 100 * (plus_di - minus_di).abs() / (plus_di + minus_di).replace(0, np.nan)
    return dx.ewm(alpha=1 / n, adjust=False).mean()


def load_proxy(path, base_tf_min, session=(9 * 60, 18 * 60 + 25)):
    """Carrega CSV, converte p/ America/Sao_Paulo, filtra sessão e reamostra p/ base_tf."""
    df = pd.read_csv(path, index_col=0)
    idx = pd.to_datetime(df.index, utc=True, errors="coerce")
    df.index = idx
    df = df[~df.index.isna()]
    df.index = df.index.tz_convert("America/Sao_Paulo")
    df = df[["Open", "High", "Low", "Close"]].dropna()
    df = df[~df.index.duplicated(keep="first")].sort_index()
    # reamostra para a base TF (ex.: 5min, 60min)
    rule = f"{base_tf_min}min"
    agg = {"Open": "first", "High": "max", "Low": "min", "Close": "last"}
    df = df.resample(rule).agg(agg).dropna()
    # filtra janela de pregão
    mins = df.index.hour * 60 + df.index.minute
    df = df[(mins >= session[0]) & (mins <= session[1])]
    df = df[df.index.dayofweek < 5]
    return df


def build_indicators(df, p: Params, base_tf_min, trend_tf_min):
    out = df.copy()
    out["ema_fast"] = ema(out["Close"], p.ema_fast)
    out["ema_slow"] = ema(out["Close"], p.ema_slow)
    out["atr"] = atr(out, p.atr_period)
    out["atr_ma"] = out["atr"].rolling(20).mean()
    # MACD histograma
    macd_line = ema(out["Close"], p.macd_fast) - ema(out["Close"], p.macd_slow)
    macd_sig = ema(macd_line, p.macd_signal)
    out["macd_hist"] = macd_line - macd_sig
    # EMA de tendência no trend TF, alinhada por asof
    trend = df.resample(f"{trend_tf_min}min").agg(
        {"Open": "first", "High": "max", "Low": "min", "Close": "last"}).dropna()
    trend_ema = ema(trend["Close"], p.ema_trend)
    # a barra de tendência só está "fechada" no fim do período -> desloca 1
    trend_ema_closed = trend_ema.shift(1)
    out["ema_trend"] = trend_ema_closed.reindex(out.index, method="ffill")
    if p.adx_period > 0:
        out["adx"] = adx(out, p.adx_period)
    else:
        out["adx"] = np.nan
    return out


@dataclass
class Trade:
    symbol: str
    side: int
    entry_time: pd.Timestamp
    entry: float
    exit_time: pd.Timestamp = None
    exit: float = None
    contracts: int = 1
    pnl_pts: float = 0.0
    pnl_reais: float = 0.0
    reason: str = ""


def backtest_symbol(df, symbol, p: Params, base_tf_min, trend_tf_min,
                    capital0=5000.0):
    spec = INSTRUMENTS[symbol]
    mpp = spec["money_per_price"]
    cost = spec["cost_roundtrip"]

    d = build_indicators(df, p, base_tf_min, trend_tf_min)
    d = d.dropna(subset=["ema_fast", "ema_slow", "ema_trend", "atr", "atr_ma", "macd_hist"])
    idx = d.index
    n = len(d)
    if n < 30:
        return [], pd.Series(dtype=float)

    O = d["Open"].values
    H = d["High"].values
    L = d["Low"].values
    C = d["Close"].values
    ef = d["ema_fast"].values
    es = d["ema_slow"].values
    et = d["ema_trend"].values
    at = d["atr"].values
    ama = d["atr_ma"].values
    mh = d["macd_hist"].values
    ax = d["adx"].values
    mins = (idx.hour * 60 + idx.minute).values
    days = idx.normalize()
    dow = idx.dayofweek.values

    def in_window(m):
        return (p.janela1[0] <= m < p.janela1[1]) or (p.janela2[0] <= m < p.janela2[1])

    trades = []
    pos = None            # dict do trade aberto
    cur_day = None
    trades_day = 0
    loss_day = 0.0
    paused_until = None
    equity = capital0
    equity_curve = np.full(n, np.nan)

    for i in range(1, n):
        day = days[i]
        if day != cur_day:
            cur_day = day
            trades_day = 0
            loss_day = 0.0

        # pausa por drawdown (5 dias úteis)
        paused = paused_until is not None and day <= paused_until

        # --- gestão de posição aberta ---
        if pos is not None:
            side = pos["side"]
            entry = pos["entry"]
            sl = pos["sl"]
            tp = pos["tp"]
            alvo = abs(tp - entry)
            hi, lo = H[i], L[i]
            exit_price = None
            reason = ""
            # excursão favorável até o fim desta barra (para BE/trailing)
            if side == 1:
                # checa SL/TP intrabar (pessimista: SL primeiro)
                if lo <= sl:
                    exit_price, reason = sl, "SL"
                elif hi >= tp:
                    exit_price, reason = tp, "TP"
            else:
                if hi >= sl:
                    exit_price, reason = sl, "SL"
                elif lo <= tp:
                    exit_price, reason = tp, "TP"

            # fechamento por fim de pregão
            if exit_price is None and mins[i] >= p.fechamento_min:
                exit_price, reason = C[i], "EOD"

            if exit_price is not None:
                ctr = pos["contracts"]
                pnl_pts = (exit_price - entry) * side
                pnl_reais = pnl_pts * mpp * ctr - cost * ctr
                equity += pnl_reais
                if pnl_reais < 0:
                    loss_day += -pnl_reais
                t = pos["trade"]
                t.exit_time = idx[i]
                t.exit = exit_price
                t.pnl_pts = pnl_pts
                t.pnl_reais = pnl_reais
                t.reason = reason
                trades.append(t)
                pos = None
                # trava de drawdown
                if loss_day >= p.dd_max:
                    paused_until = day + pd.tseries.offsets.BDay(5)
            else:
                # break-even e trailing usando o preço de fechamento da barra
                price = C[i]
                dist = (price - entry) * side
                if p.use_breakeven and dist >= alvo * p.be_pct:
                    if side == 1 and pos["sl"] < entry:
                        pos["sl"] = entry
                    elif side == -1 and pos["sl"] > entry:
                        pos["sl"] = entry
                if p.use_trailing and dist >= alvo * p.trail_pct:
                    trail = at[i] * p.trail_atr_mult
                    if side == 1:
                        pos["sl"] = max(pos["sl"], price - trail)
                    else:
                        pos["sl"] = min(pos["sl"], price + trail)

        equity_curve[i] = equity

        # --- geração de novo sinal (só se sem posição) ---
        if pos is not None:
            continue
        if paused:
            continue
        if trades_day >= p.max_trades:
            continue
        if loss_day >= p.perda_diaria:
            continue
        if not in_window(mins[i]):
            continue
        if dow[i] not in p.allowed_weekdays:
            continue
        if at[i] < ama[i] * p.vol_filter:
            continue
        if p.adx_period > 0 and not (ax[i] >= p.adx_min):
            continue

        cross_up = ef[i - 1] <= es[i - 1] and ef[i] > es[i]
        cross_dn = ef[i - 1] >= es[i - 1] and ef[i] < es[i]
        trend_up = C[i] > et[i]
        trend_dn = C[i] < et[i]
        macd_ok_up = (mh[i] > 0) if p.macd_gate else True
        macd_ok_dn = (mh[i] < 0) if p.macd_gate else True

        sig = 0
        if cross_up and trend_up and macd_ok_up:
            sig = 1
        elif cross_dn and trend_dn and macd_ok_dn:
            sig = -1
        if sig == 0:
            continue
        if i + 1 >= n:
            continue

        # entrada no OPEN da próxima barra (sem lookahead)
        entry = O[i + 1]
        sl_dist = at[i] * p.atr_mult_sl
        tp_dist = sl_dist * p.rr_ratio
        if sl_dist <= 0:
            continue
        # risco por contrato
        risco_1 = sl_dist * mpp
        if risco_1 > p.risco_reais * p.risk_check_mult:
            continue
        contracts = 1
        if p.use_sizing:
            contracts = max(1, int(p.risco_reais // risco_1)) if risco_1 > 0 else 1

        if sig == 1:
            sl = entry - sl_dist
            tp = entry + tp_dist
        else:
            sl = entry + sl_dist
            tp = entry - tp_dist

        tr = Trade(symbol=symbol, side=sig, entry_time=idx[i + 1], entry=entry,
                   contracts=contracts)
        pos = dict(side=sig, entry=entry, sl=sl, tp=tp, contracts=contracts, trade=tr)
        trades_day += 1

    ec = pd.Series(equity_curve, index=idx).ffill().fillna(capital0)
    return trades, ec


def metrics(trades, equity_curve, capital0=5000.0, periods_per_year=None):
    res = {}
    n = len(trades)
    res["n_trades"] = n
    if n == 0:
        return dict(n_trades=0, retorno_reais=0, retorno_pct=0, profit_factor=0,
                    win_rate=0, payoff=0, dd_max_pct=0, sharpe=0, trades_dia=0,
                    gross_win=0, gross_loss=0)
    pnls = np.array([t.pnl_reais for t in trades])
    wins = pnls[pnls > 0]
    losses = pnls[pnls < 0]
    gross_win = wins.sum()
    gross_loss = -losses.sum()
    res["retorno_reais"] = float(pnls.sum())
    res["retorno_pct"] = float(pnls.sum() / capital0 * 100)
    res["profit_factor"] = float(gross_win / gross_loss) if gross_loss > 0 else float("inf")
    res["win_rate"] = float(len(wins) / n * 100)
    res["payoff"] = float((wins.mean() if len(wins) else 0) /
                          (-losses.mean() if len(losses) else 1)) if len(losses) else float("inf")
    res["gross_win"] = float(gross_win)
    res["gross_loss"] = float(gross_loss)
    # drawdown sobre a equity curve
    ec = equity_curve.values if hasattr(equity_curve, "values") else np.array(equity_curve)
    peak = np.maximum.accumulate(ec)
    dd = (ec - peak) / peak
    res["dd_max_pct"] = float(-dd.min() * 100)
    # retornos por trade para sharpe (aprox anualizado por nº de trades/dia)
    days = len(set(t.entry_time.normalize() for t in trades))
    res["trades_dia"] = float(n / days) if days else 0
    # sharpe simples baseado em pnl por trade
    if pnls.std() > 0:
        # anualiza assumindo ~252 dias e trades_dia por dia
        tpd = res["trades_dia"] if res["trades_dia"] > 0 else 1
        res["sharpe"] = float(pnls.mean() / pnls.std() * np.sqrt(252 * tpd))
    else:
        res["sharpe"] = 0.0
    return res
