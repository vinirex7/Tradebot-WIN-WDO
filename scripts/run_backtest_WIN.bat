@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
REM ============================================================
REM  run_backtest_WIN.bat — Backtest WINFUT + Walk-Forward
REM  IS:  2023-01-02 a 2025-06-30  (30 meses)
REM  OOS: 2025-07-01 a 2026-06-30  (12 meses)
REM ============================================================

SET "ROOT=%~dp0.."

IF NOT EXIST "%~dp0config.bat" (
    echo [ERRO] Execute scripts\setup.bat primeiro.
    pause & exit /b 1
)
CALL "%~dp0config.bat"

echo.
echo ============================================================
echo  BACKTEST WINFUT -- DualTrendScalper v2.0
echo  IS:  2023-01-02 a 2025-06-30
echo  OOS: 2025-07-01 a 2026-06-30
echo ============================================================
echo.

SET "INI_OUT=%ROOT%\Tests\_backtest_WIN_resolved.ini"
(
echo [Tester]
echo Expert=Experts\DualTrendScalper.mq5
echo Symbol=WINFUT
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
echo Report=!ROOT!\reports\WINFUT_v2_Backtest
echo ReplaceReport=1
echo ShutdownTerminal=0
echo VisualMode=0
echo ExecutionDelay=5
echo Spread=5
echo Inputs=!ROOT!\Sets\DualTrendScalper_Default.set
) > "!INI_OUT!"

echo [INFO] Iniciando MT5 Strategy Tester para WINFUT...
"!MT5_EXE!" /config:"!INI_OUT!"

echo.
echo [OK] Backtest WINFUT concluido.
echo Relatorio: %ROOT%\reports\WINFUT_v2_Backtest.htm
echo.
pause
