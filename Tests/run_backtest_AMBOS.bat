@echo off
REM ===========================================================
REM  run_backtest_AMBOS.bat
REM  Roda backtest WIN primeiro, depois WDO em sequencia
REM  DualTrendScalper v2.0 | 2026-07-24
REM ===========================================================

SET MT5_PATH=C:\Program Files\XP Investimentos MT5\terminal64.exe
SET DIR=%~dp0

echo.
echo ============================================================
echo  DUAL TREND SCALPER v2.0 -- BACKTEST COMPLETO (WIN + WDO)
echo ============================================================
echo.
echo PASSO 1/2: Backtest WINFUT...
echo.

"%MT5_PATH%" /config:"%DIR%BacktestConfig_WINFUT.ini"

echo.
echo [OK] WINFUT concluido. Iniciando WDOFUT em 5 segundos...
timeout /t 5 /nobreak
echo.
echo PASSO 2/2: Backtest WDOFUT...
echo.

"%MT5_PATH%" /config:"%DIR%BacktestConfig_WDOFUT.ini"

echo.
echo ============================================================
echo  BACKTEST COMPLETO FINALIZADO!
echo  Relatorios em: MQL5\Reports\
echo    - WINFUT_v2_Backtest.htm
echo    - WDOFUT_v2_Backtest.htm
echo ============================================================
echo.
pause
