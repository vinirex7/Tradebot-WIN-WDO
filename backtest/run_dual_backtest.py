from __future__ import annotations

import argparse
import json
from pathlib import Path

import pandas as pd

from dts_engine import DTSConfig, load_ohlcv, run_dual_backtest


def parse_args():
    p = argparse.ArgumentParser(description="Backtest dual WIN+WDO com a mesma logica por simbolo do EA live")
    p.add_argument("--win-csv", required=True, help="CSV M5 do WIN exportado do MT5")
    p.add_argument("--wdo-csv", required=True, help="CSV M5 do WDO exportado do MT5")
    p.add_argument("--start", default="2024-01-01")
    p.add_argument("--end", default="2026-06-30")
    p.add_argument("--output", default="results")
    p.add_argument("--cash", type=float, default=5000.0)
    p.add_argument("--risk", type=float, default=50.0)
    p.add_argument("--daily-loss", type=float, default=150.0)
    p.add_argument("--dd-max", type=float, default=500.0)
    p.add_argument("--max-trades-day", type=int, default=3)
    p.add_argument("--contracts", type=int, default=1)
    return p.parse_args()


def main():
    args = parse_args()
    win = load_ohlcv(args.win_csv)
    wdo = load_ohlcv(args.wdo_csv)
    start = pd.Timestamp(args.start)
    end = pd.Timestamp(args.end)
    win = win.loc[(win.index >= start) & (win.index <= end)].copy()
    wdo = wdo.loc[(wdo.index >= start) & (wdo.index <= end)].copy()
    if win.empty or wdo.empty:
        raise SystemExit("WIN ou WDO sem dados no periodo solicitado. Confira CSV/start/end.")

    common = {
        "start_cash": args.cash,
        "risco_reais": args.risk,
        "perda_diaria": args.daily_loss,
        "dd_max": args.dd_max,
        "contracts": args.contracts,
        "max_trades_per_day": args.max_trades_day,
    }
    win_cfg = DTSConfig.for_symbol("WIN", **common)
    wdo_cfg = DTSConfig.for_symbol("WDO", **common)
    trades, summary = run_dual_backtest(win, wdo, win_cfg, wdo_cfg)

    outdir = Path(args.output)
    outdir.mkdir(parents=True, exist_ok=True)
    prefix = f"DUAL_WIN_WDO_{args.start}_{args.end}"
    trades_path = outdir / f"{prefix}_trades.csv"
    summary_path = outdir / f"{prefix}_summary.json"
    trades.to_csv(trades_path, index=False)
    summary_path.write_text(json.dumps({
        "config": {"win": win_cfg.to_dict(), "wdo": wdo_cfg.to_dict(), "simultaneous_positions": True},
        "summary": summary,
    }, indent=2, ensure_ascii=False), encoding="utf-8")

    print(json.dumps(summary, indent=2, ensure_ascii=False))
    print(f"Trades: {trades_path}")
    print(f"Resumo: {summary_path}")


if __name__ == "__main__":
    main()
