"""Python backtest engine for DualTrendScalper.

This file mirrors the live MQL5 branch `infra-1` logic:
- M5 execution timeframe
- EMA 9/21 cross on the last closed M5 candle
- EMA 50 trend filter from M15
- MACD(12,26,9) confirmation
- ATR(14) dynamic stop, RR take profit
- break-even at 30% of target, trailing at 50% of target with 1 ATR
- trading windows 09:30-12:00 and 14:00-16:30
- forced flat at 18:10
- daily loss lock and daily profit lock

The simulator is intentionally conservative: the signal is evaluated on the
closed bar and the entry is made on the next bar open to avoid look-ahead bias.
"""
from __future__ import annotations

from dataclasses import dataclass, asdict
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
    macd_signal: int = 9
    atr_period: int = 14
    atr_mult_sl: float = 1.2
    rr_ratio: float = 2.0
    risco_reais: float = 50.0
    perda_diaria: float = 150.0
    ganho_diario: float = 300.0
    be_trigger: float = 0.30
    trail_trigger: float = 0.50
    use_break_even: bool = True
    use_trailing: bool = True
    start_cash: float = 5000.0
    contracts: int = 1
    tick_value: float = 1.0
    tick_size: float = 5.0
    point_value: float = 0.20
    fee_round_trip: float = 0.50
    session1_start: str = "09:30"
    session1_end: str = "12:00"
    session2_start: str = "14:00"
    session2_end: str = "16:30"
    force_close: str = "18:10"

    @classmethod
    def for_symbol(cls, symbol: str, **kwargs) -> "DTSConfig":
        s = symbol.upper()
        if s in {"WIN", "WINFUT"}:
            return cls(symbol="WINFUT", tick_value=1.0, tick_size=5.0, point_value=0.20, fee_round_trip=0.50, **kwargs)
        if s in {"WDO", "WDOFUT"}:
            return cls(symbol="WDOFUT", tick_value=5.0, tick_size=0.5, point_value=10.0, fee_round_trip=2.40, atr_mult_sl=1.5, **kwargs)
        return cls(symbol=s, **kwargs)

    def to_dict(self) -> dict:
        return asdict(self)


def _time_to_minutes(value: str) -> int:
    h, m = value.split(":")
    return int(h) * 60 + int(m)


def load_ohlcv(csv_path: str | Path) -> pd.DataFrame:
    df = pd.read_csv(csv_path)
    lower = {c.lower(): c for c in df.columns}
    dt_col = lower.get("datetime") or lower.get("date") or lower.get("time") or lower.get("timestamp")
    if not dt_col:
        raise ValueError("CSV precisa ter coluna datetime/date/time/timestamp.")
    df[dt_col] = pd.to_datetime(df[dt_col])
    df = df.rename(columns={dt_col: "datetime"})
    mapping = {}
    for name in ["open", "high", "low", "close", "volume"]:
        if name in lower:
            mapping[lower[name]] = name
    df = df.rename(columns=mapping).set_index("datetime").sort_index()
    required = {"open", "high", "low", "close"}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"CSV sem colunas obrigatorias: {sorted(missing)}")
    return df[[c for c in ["open", "high", "low", "close", "volume"] if c in df.columns]].dropna()


def load_yfinance(symbol: str, start: str, end: str, interval: str = "5m") -> pd.DataFrame:
    import yfinance as yf

    ticker_map = {
        "WIN": "WIN=F",
        "WINFUT": "WIN=F",
        "WDO": "BRL=X",
        "WDOFUT": "BRL=X",
    }
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
    sig_line = ema(macd_line, cfg.macd_signal)
    df["macd_line"] = macd_line
    df["macd_signal"] = sig_line
    df["atr"] = atr(df, cfg.atr_period)

    m15 = df.resample("15min", label="right", closed="right").agg({
        "open": "first", "high": "max", "low": "min", "close": "last"
    }).dropna()
    m15["ema_trend"] = ema(m15["close"], cfg.ema_trend)
    df["ema_trend_m15"] = m15["ema_trend"].reindex(df.index, method="ffill")
    return df


def in_session(ts: pd.Timestamp, cfg: DTSConfig) -> bool:
    minutes = ts.hour * 60 + ts.minute
    s1 = _time_to_minutes(cfg.session1_start) <= minutes < _time_to_minutes(cfg.session1_end)
    s2 = _time_to_minutes(cfg.session2_start) <= minutes < _time_to_minutes(cfg.session2_end)
    return bool(s1 or s2)


def should_force_close(ts: pd.Timestamp, cfg: DTSConfig) -> bool:
    return ts.hour * 60 + ts.minute >= _time_to_minutes(cfg.force_close)


def risk_is_valid(sl_dist_price: float, cfg: DTSConfig) -> bool:
    risk_1_contract = abs(sl_dist_price) * cfg.point_value * cfg.contracts
    return risk_1_contract <= cfg.risco_reais


def signal_on_closed_bar(df: pd.DataFrame, i: int) -> int:
    """Signal using the last closed candle at i-1 and previous candle at i-2."""
    if i < 2:
        return 0
    cur = df.iloc[i - 1]
    prev = df.iloc[i - 2]
    if pd.isna(cur[["ema_fast", "ema_slow", "ema_trend_m15", "macd_line", "macd_signal", "atr"]]).any():
        return 0
    cross_up = prev.ema_fast <= prev.ema_slow and cur.ema_fast > cur.ema_slow
    cross_dn = prev.ema_fast >= prev.ema_slow and cur.ema_fast < cur.ema_slow
    trend_up = cur.close > cur.ema_trend_m15
    trend_dn = cur.close < cur.ema_trend_m15
    macd_bull = cur.macd_line > cur.macd_signal and cur.macd_line > 0
    macd_bear = cur.macd_line < cur.macd_signal and cur.macd_line < 0
    if cross_up and trend_up and macd_bull:
        return 1
    if cross_dn and trend_dn and macd_bear:
        return -1
    return 0


def run_backtest(df_m5: pd.DataFrame, cfg: DTSConfig) -> tuple[pd.DataFrame, dict]:
    df = add_indicators(df_m5, cfg).dropna().copy()
    trades = []
    cash = cfg.start_cash
    pnl_day = 0.0
    current_day = None
    pos: Optional[dict] = None

    for i in range(2, len(df)):
        ts = df.index[i]
        row = df.iloc[i]
        day = ts.date()
        if current_day != day:
            current_day = day
            pnl_day = 0.0

        if pos is not None:
            direction = pos["direction"]
            exit_price = None
            reason = None
            high, low = row.high, row.low

            if direction == 1:
                if low <= pos["sl"]:
                    exit_price, reason = pos["sl"], "SL"
                elif high >= pos["tp"]:
                    exit_price, reason = pos["tp"], "TP"
            else:
                if high >= pos["sl"]:
                    exit_price, reason = pos["sl"], "SL"
                elif low <= pos["tp"]:
                    exit_price, reason = pos["tp"], "TP"

            if exit_price is None:
                dist = abs(row.close - pos["entry"])
                target_dist = abs(pos["tp"] - pos["entry"])
                if cfg.use_break_even and target_dist > 0 and dist >= target_dist * cfg.be_trigger:
                    if direction == 1 and pos["sl"] < pos["entry"]:
                        pos["sl"] = pos["entry"]
                    elif direction == -1 and pos["sl"] > pos["entry"]:
                        pos["sl"] = pos["entry"]
                if cfg.use_trailing and target_dist > 0 and dist >= target_dist * cfg.trail_trigger:
                    if direction == 1:
                        pos["sl"] = max(pos["sl"], row.close - row.atr)
                    else:
                        pos["sl"] = min(pos["sl"], row.close + row.atr)
                if should_force_close(ts, cfg):
                    exit_price, reason = row.close, "FORCE_CLOSE"

            if exit_price is not None:
                gross = (exit_price - pos["entry"]) * cfg.point_value * cfg.contracts * direction
                pnl = gross - cfg.fee_round_trip
                cash += pnl
                pnl_day += pnl
                trades.append({**pos, "exit_time": ts, "exit": exit_price, "reason": reason, "gross": gross, "pnl": pnl, "equity": cash})
                pos = None

        if pos is not None:
            continue
        if pnl_day <= -cfg.perda_diaria or pnl_day >= cfg.ganho_diario:
            continue
        if not in_session(ts, cfg) or should_force_close(ts, cfg):
            continue

        sig = signal_on_closed_bar(df, i)
        if sig == 0:
            continue
        signal_bar = df.iloc[i - 1]
        entry = row.open
        sl_dist = signal_bar.atr * cfg.atr_mult_sl
        if not risk_is_valid(sl_dist, cfg):
            continue
        tp_dist = sl_dist * cfg.rr_ratio
        if sig == 1:
            sl, tp = entry - sl_dist, entry + tp_dist
        else:
            sl, tp = entry + sl_dist, entry - tp_dist
        pos = {"entry_time": ts, "symbol": cfg.symbol, "direction": sig, "entry": float(entry), "sl": float(sl), "tp": float(tp), "atr": float(signal_bar.atr)}

    trades_df = pd.DataFrame(trades)
    if not trades_df.empty:
        trades_df["cum_pnl"] = trades_df["pnl"].cumsum()
        eq = cfg.start_cash + trades_df["cum_pnl"]
        dd = eq - eq.cummax()
        wins = trades_df[trades_df.pnl > 0]
        losses = trades_df[trades_df.pnl < 0]
        pf = wins.pnl.sum() / abs(losses.pnl.sum()) if not losses.empty else np.inf
        summary = {
            "symbol": cfg.symbol,
            "trades": int(len(trades_df)),
            "net_profit": float(trades_df.pnl.sum()),
            "final_equity": float(cfg.start_cash + trades_df.pnl.sum()),
            "win_rate": float((trades_df.pnl > 0).mean()),
            "profit_factor": float(pf),
            "max_drawdown_reais": float(dd.min()),
            "avg_pnl": float(trades_df.pnl.mean()),
        }
    else:
        summary = {"symbol": cfg.symbol, "trades": 0, "net_profit": 0.0, "final_equity": cfg.start_cash, "win_rate": 0.0, "profit_factor": 0.0, "max_drawdown_reais": 0.0, "avg_pnl": 0.0}
    return trades_df, summary
