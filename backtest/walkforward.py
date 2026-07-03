from __future__ import annotations

import argparse
import itertools
import json
from pathlib import Path

import pandas as pd

from dts_engine import DTSConfig, load_ohlcv, load_yfinance, run_backtest


DEFAULT_WINDOWS = [
    ("2024-01-01", "2024-06-30", "2024-07-01", "2024-09-30"),
    ("2024-01-01", "2024-09-30", "2024-10-01", "2024-12-31"),
    ("2024-01-01", "2024-12-31", "2025-01-01", "2025-03-31"),
    ("2024-01-01", "2025-03-31", "2025-04-01", "2025-06-30"),
    ("2024-01-01", "2025-06-30", "2025-07-01", "2025-12-31"),
    ("2024-01-01", "2025-12-31", "2026-01-01", "2026-06-30"),
]


def parse_args():
    p = argparse.ArgumentParser(description="Walk-forward Python do DualTrendScalper")
    p.add_argument("--symbol", default="WIN")
    p.add_argument("--csv", help="CSV OHLCV M5 exportado do MT5")
    p.add_argument("--start", default="2024-01-01")
    p.add_argument("--end", default="2026-06-30")
    p.add_argument("--output", default="results")
    p.add_argument("--atr-grid", default="0.8,1.0,1.2,1.5,1.8,2.0")
    p.add_argument("--rr-grid", default="1.5,2.0,2.5,3.0")
    p.add_argument("--ema-trend-grid", default="34,50,70,100")
    return p.parse_args()


def slice_df(df: pd.DataFrame, start: str, end: str) -> pd.DataFrame:
    return df.loc[(df.index >= pd.Timestamp(start)) & (df.index <= pd.Timestamp(end))].copy()


def approved(summary: dict, min_trades: int = 30) -> bool:
    return bool(
        summary["trades"] >= min_trades
        and summary["net_profit"] > 0
        and summary["profit_factor"] >= 1.5
        and summary["win_rate"] >= 0.45
        and summary["max_drawdown_pct"] <= 0.15
    )


def score(summary: dict) -> float:
    if not approved(summary, min_trades=30):
        return -1e9
    return summary["profit_factor"] * summary["net_profit"] / max(1.0, abs(summary["max_drawdown_reais"]))


def main():
    args = parse_args()
    if args.csv:
        data = load_ohlcv(args.csv)
    else:
        data = load_yfinance(args.symbol, args.start, args.end, interval="5m")

    atr_grid = [float(x) for x in args.atr_grid.split(",") if x]
    rr_grid = [float(x) for x in args.rr_grid.split(",") if x]
    ema_grid = [int(x) for x in args.ema_trend_grid.split(",") if x]

    results = []
    for idx, (is_start, is_end, oos_start, oos_end) in enumerate(DEFAULT_WINDOWS, start=1):
        is_df = slice_df(data, is_start, is_end)
        oos_df = slice_df(data, oos_start, oos_end)
        if is_df.empty or oos_df.empty:
            continue

        best = None
        for atr_mult, rr, ema_trend in itertools.product(atr_grid, rr_grid, ema_grid):
            cfg = DTSConfig.for_symbol(args.symbol, atr_mult_sl=atr_mult, rr_ratio=rr, ema_trend=ema_trend)
            _, s = run_backtest(is_df, cfg)
            item = {"cfg": cfg, "summary": s, "score": score(s)}
            if best is None or item["score"] > best["score"]:
                best = item

        if best is None or best["score"] <= -1e8:
            continue
        cfg = best["cfg"]
        _, oos = run_backtest(oos_df, cfg)
        is_profit = best["summary"]["net_profit"]
        oos_profit = oos["net_profit"]
        wfe = (oos_profit / is_profit) if is_profit else 0.0
        results.append({
            "round": idx,
            "is_start": is_start,
            "is_end": is_end,
            "oos_start": oos_start,
            "oos_end": oos_end,
            "params": {
                "atr_mult_sl": cfg.atr_mult_sl,
                "rr_ratio": cfg.rr_ratio,
                "ema_trend": cfg.ema_trend,
            },
            "is_summary": best["summary"],
            "oos_summary": oos,
            "wfe": wfe,
            "approved": bool(approved(oos, min_trades=30) and wfe >= 0.50),
        })

    outdir = Path(args.output)
    outdir.mkdir(parents=True, exist_ok=True)
    out = outdir / f"{args.symbol.upper()}_walkforward.json"
    out.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(results, indent=2, ensure_ascii=False))
    print(f"Resultado: {out}")


if __name__ == "__main__":
    main()
