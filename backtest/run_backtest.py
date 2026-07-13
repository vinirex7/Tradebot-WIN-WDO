"""
Runner do backtest DUAL TREND SCALPER.
Executa baseline, iteracoes de otimizacao e walk-forward sobre dados-proxy.
Gera PNGs de equity curve e um JSON consolidado de resultados.
"""
import os
import json
import itertools
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

import engine as E

HERE = os.path.dirname(__file__)
RES = os.path.join(HERE, "results")
os.makedirs(RES, exist_ok=True)
CAP0 = 5000.0

DATASETS = {
    "5m": dict(WIN=("data/WIN_5m.csv", 5, 15), WDO=("data/WDO_5m.csv", 5, 15)),
    "1h": dict(WIN=("data/WIN_1h.csv", 60, 240), WDO=("data/WDO_1h.csv", 60, 240)),
}
_CACHE = {}


def load(ds, sym):
    key = (ds, sym)
    if key not in _CACHE:
        path, tf, trend = DATASETS[ds][sym]
        _CACHE[key] = (E.load_proxy(os.path.join(HERE, path), tf), tf, trend)
    return _CACHE[key]


def run_portfolio(p: E.Params, ds="5m", symbols=("WIN", "WDO"),
                  date_range=None, capital0=CAP0):
    """Roda WIN+WDO e combina numa curva de patrimonio por tempo de saida."""
    all_trades = []
    per_sym = {}
    for sym in symbols:
        df, tf, trend = load(ds, sym)
        if date_range is not None:
            df = df.loc[(df.index >= date_range[0]) & (df.index < date_range[1])]
        tr, ec = E.backtest_symbol(df, sym, p, tf, trend, capital0=capital0)
        per_sym[sym] = E.metrics(tr, ec, capital0=capital0)
        all_trades.extend(tr)
    # ordena por saida e monta equity combinada
    all_trades.sort(key=lambda t: t.exit_time)
    pnls = np.array([t.pnl_reais for t in all_trades]) if all_trades else np.array([])
    times = [t.exit_time for t in all_trades]
    if len(pnls):
        ec = pd.Series(capital0 + np.cumsum(pnls), index=pd.DatetimeIndex(times))
    else:
        ec = pd.Series(dtype=float)
    m = E.metrics(all_trades, ec, capital0=capital0)
    return m, ec, all_trades, per_sym


def plot_equity(ec, title, path, extra=None):
    plt.figure(figsize=(11, 5))
    if len(ec):
        plt.plot(ec.index, ec.values, lw=1.4, color="#1f6feb", label="Patrimonio")
        peak = np.maximum.accumulate(ec.values)
        plt.plot(ec.index, peak, lw=0.8, color="#8b949e", ls="--", alpha=0.7, label="Pico")
    plt.axhline(CAP0, color="#d29922", ls=":", lw=1, label="Capital inicial")
    plt.title(title)
    plt.ylabel("Patrimonio (R$)")
    plt.grid(alpha=0.3)
    plt.legend(loc="best", fontsize=8)
    if extra:
        plt.gcf().text(0.13, 0.02, extra, fontsize=8, color="#444")
    plt.tight_layout()
    plt.savefig(path, dpi=110)
    plt.close()


def fmt(m):
    return (f"trades={m['n_trades']} PF={m['profit_factor']:.2f} "
            f"WR={m['win_rate']:.1f}% payoff={m['payoff']:.2f} "
            f"ret={m['retorno_pct']:.1f}% DD={m['dd_max_pct']:.1f}% "
            f"Sharpe={m['sharpe']:.2f} tpd={m['trades_dia']:.2f}")


def main():
    log = {"baseline": {}, "iterations": [], "walkforward": {}, "final": {}}

    # ===================== BASELINE =====================
    base = E.Params()  # parametros originais do EA (1 contrato fixo)
    print("== BASELINE (5m faithful, 1 contrato) ==")
    m5, ec5, tr5, ps5 = run_portfolio(base, ds="5m")
    print("  combinado:", fmt(m5))
    for s, mm in ps5.items():
        print(f"    {s}: {fmt(mm)}")
    plot_equity(ec5, "Baseline 5m (proxy) — WIN+WDO combinado",
                os.path.join(RES, "equity_baseline_5m.png"), fmt(m5))
    log["baseline"]["5m"] = dict(combinado=m5, por_simbolo=ps5)

    # baseline no dataset estendido 1h (com sizing p/ escalar risco)
    base_ext = E.Params(use_sizing=True, risk_check_mult=1e9)
    print("== BASELINE (1h estendido ~3 anos, com sizing) ==")
    m1, ec1, tr1, ps1 = run_portfolio(base_ext, ds="1h")
    print("  combinado:", fmt(m1))
    plot_equity(ec1, "Baseline 1h estendido (proxy) — WIN+WDO",
                os.path.join(RES, "equity_baseline_1h.png"), fmt(m1))
    log["baseline"]["1h"] = dict(combinado=m1, por_simbolo=ps1)

    # ===================== ITERACOES =====================
    # Otimizamos no dataset 1h estendido (mais dados p/ robustez), com sizing.
    def ev(**kw):
        p = E.Params(use_sizing=True, risk_check_mult=1e9, **kw)
        m, ec, tr, ps = run_portfolio(p, ds="1h")
        return p, m, ec, ps

    def record(nome, hipotese, kw, m, decisao):
        row = dict(iteracao=nome, hipotese=hipotese, params=kw, metrics=m,
                   decisao=decisao)
        log["iterations"].append(row)
        print(f"[{nome}] {decisao} :: {fmt(m)}")

    cfg = dict()  # config acumulada das melhorias aceitas

    # ---- Iter 1: ATR_Mult_SL ----
    print("\n== ITER 1: varredura ATR_Mult_SL ==")
    best = (None, -1e9, None)
    for v in [0.8, 1.0, 1.2, 1.5, 1.8, 2.0]:
        _, m, _, _ = ev(atr_mult_sl=v)
        print(f"  ATR_Mult_SL={v}: {fmt(m)}")
        score = m["retorno_reais"] if m["profit_factor"] >= 1 else -1e9 + m["retorno_reais"]
        if score > best[1]:
            best = (v, score, m)
    cfg["atr_mult_sl"] = best[0]
    record("Iter1-ATR_SL", "Otimizar multiplicador de SL (ATR)",
           {"atr_mult_sl": best[0]}, best[2], f"MANTER atr_mult_sl={best[0]}")

    # ---- Iter 2: RR_Ratio ----
    print("\n== ITER 2: varredura RR_Ratio ==")
    best = (None, -1e9, None)
    for v in [1.5, 2.0, 2.5, 3.0]:
        _, m, _, _ = ev(rr_ratio=v, **cfg)
        print(f"  RR={v}: {fmt(m)}")
        score = m["retorno_reais"] if m["profit_factor"] >= 1 else -1e9 + m["retorno_reais"]
        if score > best[1]:
            best = (v, score, m)
    cfg["rr_ratio"] = best[0]
    record("Iter2-RR", "Otimizar relacao risco/retorno",
           {"rr_ratio": best[0]}, best[2], f"MANTER rr_ratio={best[0]}")

    # ---- Iter 3: EMA_Tendencia ----
    print("\n== ITER 3: varredura EMA_Tendencia ==")
    best = (None, -1e9, None)
    for v in [34, 50, 72, 100]:
        _, m, _, _ = ev(ema_trend=v, **cfg)
        print(f"  EMA_trend={v}: {fmt(m)}")
        score = m["retorno_reais"] if m["profit_factor"] >= 1 else -1e9 + m["retorno_reais"]
        if score > best[1]:
            best = (v, score, m)
    cfg["ema_trend"] = best[0]
    record("Iter3-EMAtrend", "Otimizar EMA de tendencia (filtro)",
           {"ema_trend": best[0]}, best[2], f"MANTER ema_trend={best[0]}")

    # ---- Iter 4: EMAs rapida/lenta ----
    print("\n== ITER 4: varredura EMA rapida/lenta ==")
    best = (None, -1e9, None)
    for fast, slow in [(9, 21), (5, 20), (8, 34), (13, 34)]:
        _, m, _, _ = ev(ema_fast=fast, ema_slow=slow, **cfg)
        print(f"  EMA {fast}/{slow}: {fmt(m)}")
        score = m["retorno_reais"] if m["profit_factor"] >= 1 else -1e9 + m["retorno_reais"]
        if score > best[1]:
            best = ((fast, slow), score, m)
    cfg["ema_fast"], cfg["ema_slow"] = best[0]
    record("Iter4-EMAcross", "Otimizar EMAs de cruzamento",
           {"ema_fast": best[0][0], "ema_slow": best[0][1]}, best[2],
           f"MANTER ema {best[0][0]}/{best[0][1]}")

    # ---- Iter 5: filtro ADX ----
    print("\n== ITER 5: filtro de tendencia ADX ==")
    best = (dict(adx_period=0, adx_min=0.0), -1e9, None)
    for per, mn in [(0, 0.0), (14, 15.0), (14, 20.0), (14, 25.0)]:
        _, m, _, _ = ev(adx_period=per, adx_min=mn, **cfg)
        print(f"  ADX per={per} min={mn}: {fmt(m)}")
        score = m["retorno_reais"] if m["profit_factor"] >= 1 else -1e9 + m["retorno_reais"]
        if score > best[1]:
            best = (dict(adx_period=per, adx_min=mn), score, m)
    cfg.update(best[0])
    record("Iter5-ADX", "Adicionar filtro ADX p/ evitar mercado lateral",
           best[0], best[2], f"MANTER {best[0]}")

    # ---- Iter 6: gestao de risco / sizing e trailing ----
    print("\n== ITER 6: trailing/breakeven on-off ==")
    best = (None, -1e9, None)
    for ut, ube in [(True, True), (False, True), (True, False), (False, False)]:
        _, m, _, _ = ev(use_trailing=ut, use_breakeven=ube, **cfg)
        print(f"  trailing={ut} be={ube}: {fmt(m)}")
        score = m["retorno_reais"] if m["profit_factor"] >= 1 else -1e9 + m["retorno_reais"]
        if score > best[1]:
            best = ((ut, ube), score, m)
    cfg["use_trailing"], cfg["use_breakeven"] = best[0]
    record("Iter6-Trail", "Avaliar impacto de trailing/break-even",
           {"use_trailing": best[0][0], "use_breakeven": best[0][1]}, best[2],
           f"MANTER trailing={best[0][0]} be={best[0][1]}")

    print("\n== CONFIG OTIMIZADA ACUMULADA ==")
    print(json.dumps(cfg, indent=2))
    log["config_otimizada"] = cfg

    # config final otimizada aplicada
    p_final = E.Params(use_sizing=True, risk_check_mult=1e9, **cfg)
    m_opt, ec_opt, tr_opt, ps_opt = run_portfolio(p_final, ds="1h")
    plot_equity(ec_opt, "Config otimizada (1h estendido) — WIN+WDO",
                os.path.join(RES, "equity_otimizada_1h.png"), fmt(m_opt))
    log["otimizada_full"] = dict(combinado=m_opt, por_simbolo=ps_opt)
    print("Otimizada (full sample):", fmt(m_opt))

    # ===================== WALK-FORWARD =====================
    print("\n== WALK-FORWARD (1h) ==")
    wf = walk_forward(cfg)
    log["walkforward"] = wf

    # equity OOS concatenada do walk-forward
    if wf["oos_equity_points"]:
        pts = wf["oos_equity_points"]
        ec_oos = pd.Series([v for _, v in pts],
                           index=pd.DatetimeIndex([pd.Timestamp(t) for t, _ in pts]))
        plot_equity(ec_oos, "Walk-forward — patrimonio out-of-sample concatenado",
                    os.path.join(RES, "equity_walkforward_oos.png"),
                    f"OOS agregado: {fmt(wf['oos_aggregate'])}")

    # config final = otimizada; valida criterios
    log["final"] = dict(config=cfg, full=m_opt, oos=wf.get("oos_aggregate"),
                        baseline_5m=m5, baseline_1h=m1)

    with open(os.path.join(RES, "results.json"), "w") as f:
        json.dump(_clean(log), f, indent=2, default=str)
    print("\nResultados salvos em results/results.json")
    return log


def walk_forward(base_cfg):
    """Divide o periodo 1h em folds; otimiza atr_mult_sl+rr em treino, valida OOS."""
    df_win, tf, trend = load("1h", "WIN")
    start, end = df_win.index.min(), df_win.index.max()
    # folds trimestrais deslizantes: treino 6 meses -> teste 3 meses
    folds = []
    cur = start
    train_len = pd.DateOffset(months=6)
    test_len = pd.DateOffset(months=3)
    while cur + train_len + test_len <= end:
        tr0, tr1 = cur, cur + train_len
        te0, te1 = tr1, tr1 + test_len
        folds.append((tr0, tr1, te0, te1))
        cur = cur + test_len
    grid_sl = [0.8, 1.0, 1.2, 1.5, 1.8]
    grid_rr = [1.5, 2.0, 2.5, 3.0]

    fold_rows = []
    oos_trades = []
    oos_points = []
    for k, (tr0, tr1, te0, te1) in enumerate(folds):
        best = (None, -1e9)
        for sl, rr in itertools.product(grid_sl, grid_rr):
            cfg = dict(base_cfg)
            cfg.update(atr_mult_sl=sl, rr_ratio=rr)
            p = E.Params(use_sizing=True, risk_check_mult=1e9, **cfg)
            m, _, _, _ = run_portfolio(p, ds="1h", date_range=(tr0, tr1))
            score = m["retorno_reais"] if m["profit_factor"] >= 1 else -1e9
            if score > best[1]:
                best = ((sl, rr), score)
        (sl, rr), _ = best
        cfg = dict(base_cfg); cfg.update(atr_mult_sl=sl, rr_ratio=rr)
        p = E.Params(use_sizing=True, risk_check_mult=1e9, **cfg)
        m_te, ec_te, tr_te, _ = run_portfolio(p, ds="1h", date_range=(te0, te1))
        fold_rows.append(dict(fold=k + 1,
                              treino=f"{tr0.date()}..{tr1.date()}",
                              teste=f"{te0.date()}..{te1.date()}",
                              best_sl=sl, best_rr=rr, oos=m_te))
        oos_trades.extend(tr_te)
        print(f"  Fold{k+1} treino[{tr0.date()}..{tr1.date()}] "
              f"best(SL={sl},RR={rr}) OOS: {fmt(m_te)}")

    oos_trades.sort(key=lambda t: t.exit_time)
    pnls = np.array([t.pnl_reais for t in oos_trades]) if oos_trades else np.array([])
    if len(pnls):
        ec = pd.Series(CAP0 + np.cumsum(pnls),
                       index=pd.DatetimeIndex([t.exit_time for t in oos_trades]))
        oos_points = [(str(t), float(v)) for t, v in zip(ec.index, ec.values)]
    else:
        ec = pd.Series(dtype=float)
    agg = E.metrics(oos_trades, ec)
    print("  OOS agregado:", fmt(agg))
    return dict(folds=fold_rows, oos_aggregate=agg, oos_equity_points=oos_points)


def _clean(o):
    if isinstance(o, dict):
        return {k: _clean(v) for k, v in o.items()}
    if isinstance(o, list):
        return [_clean(v) for v in o]
    if isinstance(o, (np.floating,)):
        return float(o)
    if isinstance(o, (np.integer,)):
        return int(o)
    return o


if __name__ == "__main__":
    main()
