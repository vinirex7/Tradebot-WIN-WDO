@echo off
REM ===========================================================
REM  run_backtest_WDO.bat
REM  DualTrendScalper v2.0 -- Backtest + Walk-Forward WDOFUT
REM  Ultima revisao: 2026-07-24
REM ===========================================================
REM
REM  PRE-REQUISITOS:
REM   1. MT5 instalado (XP Investimentos)
REM   2. EA compilado sem erros
REM   3. Dados historicos WDOFUT M5 baixados (Tools > History Center)
REM   4. Ajuste o caminho MT5_PATH abaixo se necessario
REM
REM  OBSERVACAO WDO:
REM   - Usa DualTrendScalper_WDO.set (MaxTradesWIN=0)
REM   - MACD independente: (8,21,5) em vez de (12,26,9)
REM   - Janelas: 10h-12h e 14h-15:30h (abertura EUA)
REM ===========================================================

SET MT5_PATH=C:\Program Files\XP Investimentos MT5\terminal64.exe
SET CONFIG_FILE=%~dp0BacktestConfig_WDOFUT.ini

echo.
echo ============================================================
echo  DUAL TREND SCALPER v2.0 -- BACKTEST WDOFUT
echo  IS:  2023-01-02 a 2025-06-30
echo  OOS: 2025-07-01 a 2026-06-30
echo  MACD WDO: (8,21,5) | ATR_Mult=1.5
echo ============================================================
echo.

IF NOT EXIST "%MT5_PATH%" (
    echo [ERRO] MT5 nao encontrado em: %MT5_PATH%
    echo Edite a variavel MT5_PATH neste arquivo .bat
    pause
    exit /b 1
)

IF NOT EXIST "%CONFIG_FILE%" (
    echo [ERRO] Config nao encontrado: %CONFIG_FILE%
    pause
    exit /b 1
)

echo [INFO] Iniciando MT5 com backtest WDOFUT...
echo [INFO] Config: %CONFIG_FILE%
echo.

"%MT5_PATH%" /config:"%CONFIG_FILE%"

echo.
echo [OK] Backtest WDOFUT concluido.
echo Relatorio: MQL5\Reports\WDOFUT_v2_Backtest.htm
echo.
pause
