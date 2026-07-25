@echo off
chcp 65001 >nul
REM ============================================================
REM  run_backtest_AMBOS.bat — WIN + WDO em sequencia
REM ============================================================

SET "SCRIPTS=%~dp0"

echo.
echo ============================================================
echo  BACKTEST COMPLETO -- WIN + WDO em sequencia
echo ============================================================
echo.
echo PASSO 1/2: WINFUT...
CALL "%SCRIPTS%run_backtest_WIN.bat"

echo PASSO 2/2: WDOFUT...
CALL "%SCRIPTS%run_backtest_WDO.bat"

echo.
echo ============================================================
echo  AMBOS OS BACKTESTS CONCLUIDOS!
echo  Relatorios em: reports\
echo    WINFUT_v2_Backtest.htm
echo    WDOFUT_v2_Backtest.htm
echo ============================================================
echo.
pause
