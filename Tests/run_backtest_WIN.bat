@echo off
REM ===========================================================
REM  run_backtest_WIN.bat
REM  DualTrendScalper v2.0 -- Backtest + Walk-Forward WINFUT
REM  Ultima revisao: 2026-07-24
REM ===========================================================
REM
REM  PRE-REQUISITOS:
REM   1. MT5 instalado (XP Investimentos)
REM   2. EA compilado (DualTrendScalper.mq5 sem erros no MetaEditor)
REM   3. Dados historicos WINFUT M5 baixados (Tools > History Center)
REM   4. Ajuste o caminho MT5_PATH abaixo se necessario
REM
REM  COMO USAR:
REM   1. Clique com botao direito > Executar como Administrador
REM   2. O MT5 abre, roda o backtest e fecha automaticamente
REM   3. Relatorio salvo em: MQL5\Reports\WINFUT_v2_Backtest.htm
REM ===========================================================

:: --- Ajuste o caminho do seu MT5 aqui ---
SET MT5_PATH=C:\Program Files\XP Investimentos MT5\terminal64.exe

:: --- Ajuste para o caminho da sua pasta de dados MT5 ---
SET MT5_DATA=C:\Users\%USERNAME%\AppData\Roaming\MetaQuotes\Terminal

:: --- Arquivo de config do backtest ---
SET CONFIG_FILE=%~dp0BacktestConfig_WINFUT.ini

echo.
echo ============================================================
echo  DUAL TREND SCALPER v2.0 -- BACKTEST WINFUT
echo  IS:  2023-01-02 a 2025-06-30
echo  OOS: 2025-07-01 a 2026-06-30
echo  Criterio: Sharpe * PF + Recovery * 0.1
echo ============================================================
echo.

:: Verifica se o MT5 existe no caminho configurado
IF NOT EXIST "%MT5_PATH%" (
    echo [ERRO] MT5 nao encontrado em: %MT5_PATH%
    echo Edite a variavel MT5_PATH neste arquivo .bat
    pause
    exit /b 1
)

:: Verifica se o config existe
IF NOT EXIST "%CONFIG_FILE%" (
    echo [ERRO] Config nao encontrado: %CONFIG_FILE%
    echo Execute este .bat a partir da pasta Tests\
    pause
    exit /b 1
)

echo [INFO] Iniciando MT5 com backtest WINFUT...
echo [INFO] Config: %CONFIG_FILE%
echo.

:: Roda o MT5 em modo tester com o config
"%MT5_PATH%" /config:"%CONFIG_FILE%"

echo.
echo [OK] Backtest WINFUT concluido.
echo Relatorio: MQL5\Reports\WINFUT_v2_Backtest.htm
echo.
pause
