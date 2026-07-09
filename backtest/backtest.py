from __future__ import annotations

import argparse
import json
from pathlib import Path

from dts_engine import DTSConfig, load_ohlcv, load_yfinance, run_backtest, run_dual_backtest


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Backtest Python do DualTrendScalper com parametros espelhados do EA live."
    )
    p.add_argument("--symbol", default="WINFUT", help="WINFUT, WDOFUT ou DUAL")
    p.add_argument("--csv", help="CSV OHLCV M5 para backtest simples")
    p.add_argument("--win-csv", help="CSV OHLCV M5 do WIN para --symbol DUAL")
    p.add_argument("--wdo-csv", help="CSV OHLCV M5 do WDO para --symbol DUAL")
    p.add_argument("--start", default="2024-01-01")
    p.add_argument("--end", default="2026-06-30")
    p.add_argument("--output", default="results")
    p.add_argument("--capital", type=float, default=5000.0)
    p.add_argument("--contracts", type=int, default=1)
    p.add_argument("--atr-mult", type=float, default=None)
    p.add_argument("--rr", type=float, default=2.0)
    p.add_argument("--no-yfinance", action="store_true", help="Exige CSV e nao tenta baixar dados")
    return p.parse_args()


def cfg_for(symbol: str, args: argparse.Namespace) -> DTSConfig:
    kwargs = {
        "start_cash": args.capital,
        "contracts": args.contracts,
        "rr_ratio": args.rr,
    }
    if args.atr_mult is not None:
        kwargs["atr_mult_sl"] = args.atr_mult
    return DTSConfig.for_symbol(symbol, **kwargs)


def load_data(symbol: str, csv_path: str | None, args: argparse.Namespace):
    if csv_path:
        return load_ohlcv(csv_path)
    if args.no_yfinance:
        raise SystemExit(f"Informe --csv para {symbol} ou remova --no-yfinance.")
    return load_yfinance(symbol, args.start, args.end, interval="5m")


def save_outputs(trades, summary: dict, cfg: dict | list[dict], output: str, name: str) -> None:
    outdir = Path(output)
    outdir.mkdir(parents=True, exist_ok=True)
    trades_path = outdir / f"{name}_trades.csv"
    summary_path = outdir / f"{name}_summary.json"
    if not trades.empty:
        trades.to_csv(trades_path, index=False)
    else:
        trades_path.write_text("", encoding="utf-8")
    payload = {"config": cfg, "summary": summary}
    summary_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    print(f"Trades:  {trades_path}")
    print(f"Resumo:  {summary_path}")


def main() -> None:
    args = parse_args()
    symbol = args.symbol.upper()

    if symbol == "DUAL":
        win_cfg = cfg_for("WINFUT", args)
        wdo_cfg = cfg_for("WDOFUT", args)
        win_df = load_data("WINFUT", args.win_csv, args)
        wdo_df = load_data("WDOFUT", args.wdo_csv, args)
        trades, summary = run_dual_backtest(win_df, wdo_df, win_cfg, wdo_cfg)
        save_outputs(trades, summary, [win_cfg.to_dict(), wdo_cfg.to_dict()], args.output, "DUAL_WIN_WDO")
        return

    cfg = cfg_for(symbol, args)
    df = load_data(symbol, args.csv, args)
    trades, summary = run_backtest(df, cfg)
    save_outputs(trades, summary, cfg.to_dict(), args.output, cfg.symbol)


if __name__ == "__main__":
    main()
