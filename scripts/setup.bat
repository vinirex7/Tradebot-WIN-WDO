@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
REM ============================================================
REM  setup.bat — DualTrendScalper v2.0
REM  Executa UMA VEZ apos o git clone
REM  Funcao: detecta MT5, cria estrutura portable, copia arquivos
REM ============================================================
REM  USO:
REM    1. git clone https://github.com/vinirex7/Tradebot-WIN-WDO
REM    2. cd Tradebot-WIN-WDO
REM    3. Clique direito em scripts\setup.bat > Executar como Administrador
REM ============================================================

echo.
echo ============================================================
echo   DUAL TREND SCALPER v2.0 -- SETUP INICIAL
echo ============================================================
echo.

SET "ROOT=%~dp0.."
SET "CONFIG_FILE=%~dp0config.bat"

REM --- 1. Detectar instalacao do MT5 ---
echo [1/5] Detectando instalacao do MetaTrader 5...

SET "MT5_PATH="

FOR %%P IN (
    "C:\Program Files\XP Investimentos MT5\terminal64.exe"
    "C:\Program Files\MetaTrader 5\terminal64.exe"
    "C:\Program Files (x86)\MetaTrader 5\terminal64.exe"
    "C:\MT5\terminal64.exe"
) DO (
    IF EXIST "%%~P" (
        IF NOT DEFINED MT5_PATH SET "MT5_PATH=%%~P"
    )
)

IF NOT DEFINED MT5_PATH (
    echo.
    echo [!] MT5 nao encontrado nos caminhos padrao.
    echo     Digite o caminho completo do terminal64.exe:
    echo     Ex: C:\Program Files\XP Investimentos MT5\terminal64.exe
    echo.
    SET /P MT5_PATH="Caminho: "
)

IF NOT EXIST "!MT5_PATH!" (
    echo.
    echo [ERRO] Arquivo nao encontrado: !MT5_PATH!
    echo        Instale o MT5: https://www.xpi.com.br/plataformas/metatrader5/
    pause
    exit /b 1
)

echo [OK] MT5 encontrado: !MT5_PATH!
FOR %%F IN ("!MT5_PATH!") DO SET "MT5_DIR=%%~dpF"
SET "MT5_EDITOR=!MT5_DIR!metaeditor64.exe"
echo [OK] Pasta MT5: !MT5_DIR!

REM --- 2. Detectar pasta de dados MQL5 ---
echo.
echo [2/5] Detectando pasta de dados MQL5...

SET "MQL5_DATA="
FOR /D %%D IN ("%APPDATA%\MetaQuotes\Terminal\*") DO (
    IF EXIST "%%D\MQL5\Experts" (
        IF NOT DEFINED MQL5_DATA SET "MQL5_DATA=%%D\MQL5"
    )
)

IF NOT DEFINED MQL5_DATA (
    echo.
    echo [!] Pasta MQL5 nao encontrada automaticamente.
    echo     Abra o MT5 ^> File ^> Open Data Folder ^> copie o caminho ^> adicione \MQL5
    echo.
    SET /P MQL5_DATA="Caminho MQL5: "
)

IF NOT EXIST "!MQL5_DATA!\Experts" (
    echo [ERRO] Pasta invalida: !MQL5_DATA!
    pause
    exit /b 1
)

echo [OK] MQL5 encontrado: !MQL5_DATA!

REM --- 3. Copiar arquivos do repo para o MT5 ---
echo.
echo [3/5] Copiando arquivos para o MT5...

COPY /Y "%ROOT%\Experts\DualTrendScalper.mq5" "!MQL5_DATA!\Experts\" >nul
echo  [OK] DualTrendScalper.mq5 -> Experts\

FOR %%F IN (RiskManager SignalEngine TimeFilter TradeLogger) DO (
    COPY /Y "%ROOT%\Include\%%F.mqh" "!MQL5_DATA!\Include\" >nul
    echo  [OK] %%F.mqh -> Include\
)

IF NOT EXIST "!MQL5_DATA!\Reports" MKDIR "!MQL5_DATA!\Reports"
IF NOT EXIST "!MQL5_DATA!\profiles\Tester" MKDIR "!MQL5_DATA!\profiles\Tester"
IF NOT EXIST "%ROOT%\logs" MKDIR "%ROOT%\logs"
IF NOT EXIST "%ROOT%\reports" MKDIR "%ROOT%\reports"
echo  [OK] Pastas auxiliares criadas

REM --- 4. Compilar o EA ---
echo.
echo [4/5] Compilando DualTrendScalper.mq5...

IF NOT EXIST "!MT5_EDITOR!" (
    echo [AVISO] metaeditor64.exe nao encontrado em !MT5_DIR!
    echo         Compile manualmente: abra o EA no MetaEditor e pressione F7
    goto SALVAR_CONFIG
)

"!MT5_EDITOR!" /compile:"!MQL5_DATA!\Experts\DualTrendScalper.mq5" /log:"%ROOT%\logs\compile.log"

FINDSTR /C:"0 error" "%ROOT%\logs\compile.log" >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    echo [OK] Compilado com sucesso -- 0 errors
) ELSE (
    echo [AVISO] Verifique: %ROOT%\logs\compile.log
)

:SALVAR_CONFIG
REM --- 5. Salvar config.bat ---
echo.
echo [5/5] Salvando scripts\config.bat...

(
echo @echo off
echo REM === CONFIG GERADA PELO SETUP.BAT -- NAO EDITAR MANUALMENTE ===
echo SET "MT5_EXE=!MT5_PATH!"
echo SET "MT5_DIR=!MT5_DIR!"
echo SET "MT5_EDITOR=!MT5_EDITOR!"
echo SET "MQL5_DATA=!MQL5_DATA!"
echo SET "ROOT=!ROOT!"
) > "!CONFIG_FILE!"

echo [OK] Config salva em scripts\config.bat

echo.
echo ============================================================
echo   SETUP CONCLUIDO COM SUCESSO!
echo.
echo   Proximos passos:
echo   1. Abra o MT5 e faca LOGIN na sua conta XP Investimentos
echo   2. Va em Tools ^> History Center e baixe:
echo      WINFUT M5, WINFUT M15, WDOFUT M5, WDOFUT M15
echo   3. Para rodar backtest:
echo      scripts\run_backtest_WIN.bat
echo      scripts\run_backtest_WDO.bat
echo ============================================================
echo.
pause
