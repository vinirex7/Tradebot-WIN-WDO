"""
Baixa dados-proxy para backtest do bot DUAL TREND SCALPER.

LIMITAÇÃO: dados de futuros tick-a-tick da B3 (WIN/WDO) não são gratuitos.
Usamos proxies públicos via Yahoo Finance:
  - WIN  -> ^BVSP  (Ibovespa à vista)     | valor do ponto: R$0,20
  - WDO  -> BRL=X / USDBRL=X (USD/BRL)     | ponto = USDBRL*1000, valor R$10/ponto

Restrições do Yahoo:
  - intervalos < 1h: no máximo 60 dias
  - intervalo 1h  : até 730 dias (~2 anos)
  - intervalo 1d  : histórico longo

Salva CSVs em backtest/data/.
"""
import os
import time
import sys
import pandas as pd
import yfinance as yf

OUT = os.path.join(os.path.dirname(__file__), "data")
os.makedirs(OUT, exist_ok=True)

# proxy -> ativo
JOBS = [
    ("WIN", "^BVSP"),
    ("WDO", "BRL=X"),
]

INTERVALS = [
    ("5m", "60d"),
    ("1h", "730d"),
    ("1d", "max"),
]


def fetch(ticker, interval, period, tries=6):
    for k in range(tries):
        try:
            df = yf.download(
                ticker, interval=interval, period=period,
                auto_adjust=False, progress=False, prepost=False, threads=False,
            )
            if df is not None and len(df) > 0:
                return df
            print(f"  vazio (tentativa {k+1})")
        except Exception as e:
            print(f"  erro (tentativa {k+1}): {e}")
        time.sleep(8 * (k + 1))
    return None


def flatten(df):
    if isinstance(df.columns, pd.MultiIndex):
        df.columns = df.columns.get_level_values(0)
    df = df.rename(columns=str.title)
    keep = [c for c in ["Open", "High", "Low", "Close", "Volume"] if c in df.columns]
    return df[keep]


def main():
    for proxy, ticker in JOBS:
        for interval, period in INTERVALS:
            path = os.path.join(OUT, f"{proxy}_{interval}.csv")
            if os.path.exists(path) and os.path.getsize(path) > 500:
                print(f"[skip] {path} já existe")
                continue
            print(f"[baixando] {proxy} <- {ticker} {interval}/{period}")
            df = fetch(ticker, interval, period)
            if df is None:
                print(f"  FALHOU {proxy} {interval}")
                continue
            df = flatten(df)
            df.index.name = "Datetime"
            df.to_csv(path)
            print(f"  ok: {len(df)} linhas -> {path}  ({df.index.min()} .. {df.index.max()})")
            time.sleep(10)


if __name__ == "__main__":
    main()
