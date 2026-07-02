from __future__ import annotations

import argparse
import json

import pandas as pd
from pathlib import Path

from dts_engine import DTSConfig, load_ohlcv, load_yfinance, run_backtest


def parse_args():
    p = argparse.ArgumentParser(description="Backtest Python do DualTrendScalper WIN/WDO")
    p.add_argument("--symbol", default="WIN", help="WIN, WDO, WINFUT, WDOFUT ou ticker customizado")
    p.add_argument("--start", default="2023-01-02")
    p.add_argument("--end", default="2025-12-31")
    p.add_argument("--csv", help="CSV OHLCV M5 exportado do MT5. Colunas: datetime,open,high,low,close[,volume]")
    p.add_argument("--output", default="results", help="Diretorio de saida")
    p.add_argument("--atr-mult-sl", type=float, default=None)
    p.add_argument("--rr-ratio", type=float, default=None)
    p.add_argument("--ema-fast", type=int, default=None)
    p.add_argument("--ema-slow", type=int, default=None)
    p.add_argument("--ema-trend", type=int, default=None)
    p.add_argument("--risk", type=float, default=50.0)
    p.add_argument("--daily-loss", type=float, default=150.0)
    p.add_argument("--daily-gain", type=float, default=300.0)
    p.add_argument("--cash", type=float, default=5000.0)
    return p.parse_args()


def main():
    args = parse_args()
    overrides = {
        "risco_reais": args.risk,
        "perda_diaria": args.daily_loss,
        "ganho_diario": args.daily_gain,
        "start_cash": args.cash,
    }
    if args.atr_mult_sl is not None:
        overrides["atr_mult_sl"] = args.atr_mult_sl
    if args.rr_ratio is not None:
        overrides["rr_ratio"] = args.rr_ratio
    if args.ema_fast is not None:
        overrides["ema_fast"] = args.ema_fast
    if args.ema_slow is not None:
        overrides["ema_slow"] = args.ema_slow
    if args.ema_trend is not None:
        overrides["ema_trend"] = args.ema_trend

    cfg = DTSConfig.for_symbol(args.symbol, **overrides)
    if args.csv:
        data = load_ohlcv(args.csv)
    else:
        data = load_yfinance(args.symbol, args.start, args.end, interval="5m")
    data = data.loc[(data.index >= pd.Timestamp(args.start)) & (data.index <= pd.Timestamp(args.end))].copy()

    trades, summary = run_backtest(data, cfg)
    outdir = Path(args.output)
    outdir.mkdir(parents=True, exist_ok=True)
    prefix = f"{cfg.symbol}_{args.start}_{args.end}".replace(":", "-")
    trades_path = outdir / f"{prefix}_trades.csv"
    summary_path = outdir / f"{prefix}_summary.json"
    trades.to_csv(trades_path, index=False)
    summary_path.write_text(json.dumps({"config": cfg.to_dict(), "summary": summary}, indent=2, ensure_ascii=False), encoding="utf-8")

    print(json.dumps(summary, indent=2, ensure_ascii=False))
    print(f"Trades: {trades_path}")
    print(f"Resumo: {summary_path}")


if __name__ == "__main__":
    main()
