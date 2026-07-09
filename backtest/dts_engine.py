"""Backtest Python do DualTrendScalper WIN/WDO.

Este modulo espelha o funcionamento do EA live `Experts/DualTrendScalper.mq5`:
- Timeframe M5, filtro de tendencia M15
- EMA 9/21, EMA 50 M15, MACD(12,26,9), ATR(14)
- Filtro de volatilidade: ATR atual >= 50% da media dos ultimos 20 ATRs
- SL por ATR, TP por RR, break-even, trailing, janelas 09:30-12:00 e 14:00-16:30
- Fechamento forçado 18:10, trava diaria R$150, DD max R$500 e max 3 trades/dia por ativo
- No modo dual, permite posicao simultanea em WIN e WDO, como o EA live faz por simbolo

Observacao de paridade: o EA usa CopyBuffer(handle, 1) do iMACD e chama isso de
"histograma". No MT5, o buffer 1 e a linha de sinal. Para reproduzir o live, este
backtest usa macd_signal > 0 para compra e macd_signal < 0 para venda.
"""
from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd


@dataclass
class DTSConfig:
    symbol: str = "WINFUT"
    ema_fast: int = 9
    ema_slow: int = 21
    ema_trend: int = 50
    macd_fast: int = 12
    macd_slow: int = 26
    macd_signal_period: int = 9
    atr_period: int = 14
    atr_mult_sl: float = 1.2
    rr_ratio: float = 2.0
    atr_min_ratio: float = 0.50
    risco_reais: float = 50.0
    perda_diaria: float = 150.0
    dd_max: float = 500.0
    be_trigger: float = 0.30
    trail_trigger: float = 0.50
    use_break_even: bool = True
    use_trailing: bool = True
    start_cash: float = 5000.0
    contracts: int = 1
    point_value: float = 0.20
    fee_round_trip: float = 0.50
    max_trades_per_day: int = 3
    session1_start: str = "09:30"
    session1_end: str = "12:00"
    session2_start: str = "14:00"
    session2_end: str = "16:30"
    force_close: str = "18:10"

    @classmethod
    def for_symbol(cls, symbol: str, **kwargs) -> "DTSConfig":
        s = symbol.upper()
        if s in {"WIN", "WINFUT", "WIN$", "WINQ26"}:
            return cls(symbol="WINFUT", point_value=0.20, fee_round_trip=0.50, atr_mult_sl=1.2, **kwargs)
        if s in {"WDO", "WDOFUT", "WDO$", "WDOQ26"}:
            return cls(symbol="WDOFUT", point_value=10.0, fee_round_trip=2.40, atr_mult_sl=1.2, **kwargs)
        return cls(symbol=s, **kwargs)

    def to_dict(self) -> dict:
        return asdict(self)


def _time_to_minutes(value: str) -> int:
    h, m = value.split(":")
    return int(h) * 60 + int(m)


def _normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    lower = {c.lower().strip(): c for c in df.columns}
    dt_col = lower.get("datetime") or lower.get("date") or lower.get("time") or lower.get("timestamp")
    if not dt_col:
        raise ValueError("CSV precisa ter coluna datetime/date/time/timestamp.")
    df = df.rename(columns={dt_col: "datetime"}).copy()
    df["datetime"] = pd.to_datetime(df["datetime"])
    mapping = {}
    for name in ["open", "high", "low", "close", "volume"]:
        if name in lower:
            mapping[lower[name]] = name
    df = df.rename(columns=mapping).set_index("datetime").sort_index()
    missing = {"open", "high", "low", "close"} - set(df.columns)
    if missing:
        raise ValueError(f"CSV sem colunas obrigatorias: {sorted(missing)}")
    return df[[c for c in ["open", "high", "low", "close", "volume"] if c in df.columns]].dropna()


def load_ohlcv(csv_path: str | Path) -> pd.DataFrame:
    return _normalize_columns(pd.read_csv(csv_path))


def load_yfinance(symbol: str, start: str, end: str, interval: str = "5m") -> pd.DataFrame:
    import yfinance as yf

    ticker_map = {"WIN": "WIN=F", "WINFUT": "WIN=F", "WDO": "BRL=X", "WDOFUT": "BRL=X"}
    ticker = ticker_map.get(symbol.upper(), symbol)
    df = yf.download(ticker, start=start, end=end, interval=interval, auto_adjust=False, progress=False)
    if df.empty:
        raise RuntimeError(f"yfinance nao retornou dados para {ticker}. Use --csv com OHLCV M5 exportado do MT5.")
    if isinstance(df.columns, pd.MultiIndex):
        df.columns = [c[0] for c in df.columns]
    df = df.rename(columns={"Open": "open", "High": "high", "Low": "low", "Close": "close", "Volume": "volume"})
    return df[[c for c in ["open", "high", "low", "close", "volume"] if c in df.columns]].dropna()


def ema(s: pd.Series, period: int) -> pd.Series:
    return s.ewm(span=period, adjust=False).mean()


def atr(df: pd.DataFrame, period: int) -> pd.Series:
    prev_close = df["close"].shift(1)
    tr = pd.concat([
        df["high"] - df["low"],
        (df["high"] - prev_close).abs(),
        (df["low"] - prev_close).abs(),
    ], axis=1).max(axis=1)
    return tr.rolling(period).mean()


def add_indicators(df_m5: pd.DataFrame, cfg: DTSConfig) -> pd.DataFrame:
    df = df_m5.copy()
    df["ema_fast"] = ema(df["close"], cfg.ema_fast)
    df["ema_slow"] = ema(df["close"], cfg.ema_slow)
    macd_line = ema(df["close"], cfg.macd_fast) - ema(df["close"], cfg.macd_slow)
    df["macd_line"] = macd_line
    df["macd_signal"] = ema(macd_line, cfg.macd_signal_period)
    df["atr"] = atr(df, cfg.atr_period)
    df["atr_mean20"] = df["atr"].rolling(20).mean()
    m15 = df.resample("15min", label="right", closed="right").agg({
        "open": "first", "high": "max", "low": "min", "close": "last"
    }).dropna()
    m15["ema_trend"] = ema(m15["close"], cfg.ema_trend)
    df["ema_trend_m15"] = m15["ema_trend"].reindex(df.index, method="ffill")
    return df


def in_session(ts: pd.Timestamp, cfg: DTSConfig) -> bool:
    minutes = ts.hour * 60 + ts.minute
    return bool(
        _time_to_minutes(cfg.session1_start) <= minutes < _time_to_minutes(cfg.session1_end)
        or _time_to_minutes(cfg.session2_start) <= minutes < _time_to_minutes(cfg.session2_end)
    )


def should_force_close(ts: pd.Timestamp, cfg: DTSConfig) -> bool:
    return ts.hour * 60 + ts.minute >= _time_to_minutes(cfg.force_close)


def signal_on_bar(df: pd.DataFrame, i: int, cfg: DTSConfig) -> int:
    """Sinal calculado na barra atual, como o EA faz no novo tick da barra M5."""
    if i < 1:
        return 0
    cur = df.iloc[i]
    prev = df.iloc[i - 1]
    cols = ["ema_fast", "ema_slow", "ema_trend_m15", "macd_signal", "atr", "atr_mean20"]
    if pd.isna(cur[cols]).any() or cur["atr"] < cur["atr_mean20"] * cfg.atr_min_ratio:
        return 0

    cross_up = prev["ema_fast"] < prev["ema_slow"] and cur["ema_fast"] > cur["ema_slow"]
    cross_dn = prev["ema_fast"] > prev["ema_slow"] and cur["ema_fast"] < cur["ema_slow"]
    trend_up = cur["close"] > cur["ema_trend_m15"]
    trend_dn = cur["close"] < cur["ema_trend_m15"]
    macd_live_positive = cur["macd_signal"] > 0
    macd_live_negative = cur["macd_signal"] < 0

    if cross_up and trend_up and macd_live_positive:
        return 1
    if cross_dn and trend_dn and macd_live_negative:
        return -1
    return 0


def summarize_trades(trades_df: pd.DataFrame, start_cash: float, symbol: str) -> dict:
    if trades_df.empty:
        return {
            "symbol": symbol,
            "trades": 0,
            "net_profit": 0.0,
            "final_equity": start_cash,
            "win_rate": 0.0,
            "profit_factor": 0.0,
            "max_drawdown_reais": 0.0,
            "max_drawdown_pct": 0.0,
            "avg_pnl": 0.0,
            "approved_by_study": False,
        }
    trades_df = trades_df.copy()
    trades_df["cum_pnl"] = trades_df["pnl"].cumsum()
    eq = start_cash + trades_df["cum_pnl"]
    dd = eq - eq.cummax()
    wins = trades_df[trades_df["pnl"] > 0]
    losses = trades_df[trades_df["pnl"] < 0]
    pf = wins["pnl"].sum() / abs(losses["pnl"].sum()) if not losses.empty else np.inf
    max_dd = float(dd.min())
    max_dd_pct = abs(max_dd) / start_cash if start_cash else 0.0
    summary = {
        "symbol": symbol,
        "trades": int(len(trades_df)),
        "net_profit": float(trades_df["pnl"].sum()),
        "final_equity": float(start_cash + trades_df["pnl"].sum()),
        "win_rate": float((trades_df["pnl"] > 0).mean()),
        "profit_factor": float(pf),
        "max_drawdown_reais": max_dd,
        "max_drawdown_pct": float(max_dd_pct),
        "avg_pnl": float(trades_df["pnl"].mean()),
    }
    summary["approved_by_study"] = bool(summary["profit_factor"] >= 1.5 and summary["win_rate"] >= 0.45 and summary["max_drawdown_pct"] <= 0.15 and summary["trades"] >= 100)
    return summary


def _manage_position(pos: dict, row: pd.Series, ts: pd.Timestamp, cfg: DTSConfig) -> tuple[Optional[float], Optional[str], dict]:
    direction = pos["direction"]
    exit_price = None
    reason = None

    if direction == 1:
        if row["low"] <= pos["sl"]:
            exit_price, reason = pos["sl"], "SL"
        elif row["high"] >= pos["tp"]:
            exit_price, reason = pos["tp"], "TP"
    else:
        if row["high"] >= pos["sl"]:
            exit_price, reason = pos["sl"], "SL"
        elif row["low"] <= pos["tp"]:
            exit_price, reason = pos["tp"], "TP"

    if exit_price is None:
        dist = abs(row["close"] - pos["entry"])
        target_dist = abs(pos["tp"] - pos["entry"])
        if cfg.use_break_even and target_dist > 0 and dist >= target_dist * cfg.be_trigger:
            if direction == 1 and pos["sl"] < pos["entry"]:
                pos["sl"] = pos["entry"]
            elif direction == -1 and pos["sl"] > pos["entry"]:
                pos["sl"] = pos["entry"]
        if cfg.use_trailing and target_dist > 0 and dist >= target_dist * cfg.trail_trigger:
            if direction == 1:
                pos["sl"] = max(pos["sl"], row["close"] - row["atr"])
            else:
                pos["sl"] = min(pos["sl"], row["close"] + row["atr"])
        if should_force_close(ts, cfg):
            exit_price, reason = row["close"], "FORCE_CLOSE"

    return exit_price, reason, pos


def _open_position(df: pd.DataFrame, i: int, cfg: DTSConfig) -> Optional[dict]:
    sig = signal_on_bar(df, i, cfg)
    if sig == 0:
        return None

    row = df.iloc[i]
    entry = row["close"]
    sl_dist = row["atr"] * cfg.atr_mult_sl
    tp_dist = sl_dist * cfg.rr_ratio

    # Paridade com EA live: filtro de risco extra existe apenas no bloco de compra.
    if sig == 1:
        risk_reais = sl_dist * cfg.point_value * cfg.contracts
        if risk_reais > cfg.risco_reais * 1.5:
            return None

    sl, tp = (entry - sl_dist, entry + tp_dist) if sig == 1 else (entry + sl_dist, entry - tp_dist)
    return {
        "entry_time": df.index[i],
        "symbol": cfg.symbol,
        "direction": sig,
        "side": "BUY" if sig == 1 else "SELL",
        "entry": float(entry),
        "sl": float(sl),
        "tp": float(tp),
        "atr": float(row["atr"]),
        "atr_mult_sl": cfg.atr_mult_sl,
    }


def _close_position(pos: dict, exit_price: float, reason: str, ts: pd.Timestamp, cfg: DTSConfig, cash: float) -> tuple[dict, float, float]:
    gross = (exit_price - pos["entry"]) * cfg.point_value * cfg.contracts * pos["direction"]
    pnl = gross - cfg.fee_round_trip
    cash += pnl
    trade = {**pos, "exit_time": ts, "exit": float(exit_price), "reason": reason, "gross": float(gross), "pnl": float(pnl), "equity": float(cash)}
    return trade, pnl, cash


def run_backtest(df_m5: pd.DataFrame, cfg: DTSConfig) -> tuple[pd.DataFrame, dict]:
    df = add_indicators(df_m5, cfg).dropna().copy()
    trades: list[dict] = []
    cash = cfg.start_cash
    pnl_day = 0.0
    trades_day = 0
    current_day = None
    bot_paused = False
    pos: Optional[dict] = None

    for i in range(1, len(df)):
        ts = df.index[i]
        row = df.iloc[i]
        if current_day != ts.date():
            current_day = ts.date()
            pnl_day = 0.0
            trades_day = 0
            bot_paused = False

        if pos is not None:
            exit_price, reason, pos = _manage_position(pos, row, ts, cfg)
            if exit_price is not None:
                trade, pnl, cash = _close_position(pos, exit_price, reason or "EXIT", ts, cfg, cash)
                trades.append(trade)
                pnl_day += pnl
                pos = None
                if abs(min(pnl_day, 0.0)) >= cfg.dd_max:
                    bot_paused = True

        if pos is not None or bot_paused:
            continue
        if abs(min(pnl_day, 0.0)) >= cfg.perda_diaria or trades_day >= cfg.max_trades_per_day:
            continue
        if not in_session(ts, cfg) or should_force_close(ts, cfg):
            continue

        pos = _open_position(df, i, cfg)
        if pos is not None:
            trades_day += 1

    trades_df = pd.DataFrame(trades)
    return trades_df, summarize_trades(trades_df, cfg.start_cash, cfg.symbol)


def run_dual_backtest(win_df: pd.DataFrame, wdo_df: pd.DataFrame, win_cfg: DTSConfig, wdo_cfg: DTSConfig) -> tuple[pd.DataFrame, dict]:
    frames = {
        win_cfg.symbol: add_indicators(win_df, win_cfg).dropna().copy(),
        wdo_cfg.symbol: add_indicators(wdo_df, wdo_cfg).dropna().copy(),
    }
    cfgs = {win_cfg.symbol: win_cfg, wdo_cfg.symbol: wdo_cfg}
    index = sorted(set(frames[win_cfg.symbol].index).union(frames[wdo_cfg.symbol].index))
    positions: dict[str, Optional[dict]] = {win_cfg.symbol: None, wdo_cfg.symbol: None}
    cash = win_cfg.start_cash
    pnl_day = 0.0
    trades_day = {win_cfg.symbol: 0, wdo_cfg.symbol: 0}
    current_day = None
    bot_paused = False
    trades: list[dict] = []

    for ts in index:
        if current_day != ts.date():
            current_day = ts.date()
            pnl_day = 0.0
            trades_day = {win_cfg.symbol: 0, wdo_cfg.symbol: 0}
            bot_paused = False

        for symbol, pos in list(positions.items()):
            if pos is None or ts not in frames[symbol].index:
                continue
            cfg = cfgs[symbol]
            row = frames[symbol].loc[ts]
            exit_price, reason, pos = _manage_position(pos, row, ts, cfg)
            if exit_price is not None:
                trade, pnl, cash = _close_position(pos, exit_price, reason or "EXIT", ts, cfg, cash)
                trades.append(trade)
                pnl_day += pnl
                positions[symbol] = None
                if abs(min(pnl_day, 0.0)) >= cfg.dd_max:
                    bot_paused = True
            else:
                positions[symbol] = pos

        if bot_paused or abs(min(pnl_day, 0.0)) >= win_cfg.perda_diaria:
            continue

        for symbol in [win_cfg.symbol, wdo_cfg.symbol]:
            if positions[symbol] is not None:
                continue
            df = frames[symbol]
            cfg = cfgs[symbol]
            if ts not in df.index or trades_day[symbol] >= cfg.max_trades_per_day or not in_session(ts, cfg) or should_force_close(ts, cfg):
                continue
            loc = df.index.get_loc(ts)
            if isinstance(loc, slice) or int(loc) < 1:
                continue
            new_pos = _open_position(df, int(loc), cfg)
            if new_pos is not None:
                positions[symbol] = new_pos
                trades_day[symbol] += 1

    trades_df = pd.DataFrame(trades).sort_values("entry_time") if trades else pd.DataFrame(trades)
    return trades_df, summarize_trades(trades_df, win_cfg.start_cash, "DUAL_WIN_WDO")
