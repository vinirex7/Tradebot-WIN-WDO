@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
REM ============================================================
REM  run_backtest_WDO.bat — Backtest WDOFUT + Walk-Forward
REM  IS:  2023-01-02 a 2025-06-30  (30 meses)
REM  OOS: 2025-07-01 a 2026-06-30  (12 meses)
REM  MACD WDO: (8,21,5) | ATR_Mult=1.5
REM ============================================================

SET "ROOT=%~dp0.."

IF NOT EXIST "%~dp0config.bat" (
    echo [ERRO] Execute scripts\setup.bat primeiro.
    pause & exit /b 1
)
CALL "%~dp0config.bat"

echo.
echo ============================================================
echo  BACKTEST WDOFUT -- DualTrendScalper v2.0
echo  IS:  2023-01-02 a 2025-06-30
echo  OOS: 2025-07-01 a 2026-06-30
echo  MACD WDO: (8,21,5) | ATR_Mult=1.5
echo ============================================================
echo.

SET "INI_OUT=%ROOT%\Tests\_backtest_WDO_resolved.ini"
(
echo [Tester]
echo Expert=Experts\DualTrendScalper.mq5
echo Symbol=WDOFUT
echo Period=M5
echo ModelingMode=EveryTick
echo FromDate=2023.01.02
echo ToDate=2025.06.30
echo ForwardMode=Custom
echo ForwardDate=2025.07.01
echo ForwardToDate=2026.06.30
echo Deposit=50000
echo Currency=BRL
echo Leverage=1:1
echo Optimization=1
echo OptimizationCriterion=6
echo Report=!ROOT!\reports\WDOFUT_v2_Backtest
echo ReplaceReport=1
echo ShutdownTerminal=0
echo VisualMode=0
echo ExecutionDelay=5
echo Spread=3
echo Inputs=!ROOT!\Sets\DualTrendScalper_WDO.set
) > "!INI_OUT!"

echo [INFO] Iniciando MT5 Strategy Tester para WDOFUT...
"!MT5_EXE!" /config:"!INI_OUT!"

echo.
echo [OK] Backtest WDOFUT concluido.
echo Relatorio: %ROOT%\reports\WDOFUT_v2_Backtest.htm
echo.
pause
