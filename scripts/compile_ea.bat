@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
REM ============================================================
REM  compile_ea.bat — Recompila o EA via linha de comando
REM  Requer que setup.bat tenha sido executado antes
REM ============================================================

SET "ROOT=%~dp0.."

IF NOT EXIST "%~dp0config.bat" (
    echo [ERRO] config.bat nao encontrado.
    echo        Execute scripts\setup.bat primeiro.
    pause & exit /b 1
)
CALL "%~dp0config.bat"

echo.
echo [INFO] Compilando DualTrendScalper.mq5...
echo.

IF NOT EXIST "!MT5_EDITOR!" (
    echo [ERRO] MetaEditor nao encontrado: !MT5_EDITOR!
    pause & exit /b 1
)

"!MT5_EDITOR!" /compile:"!MQL5_DATA!\Experts\DualTrendScalper.mq5" /log:"%ROOT%\logs\compile.log"

echo.
echo === LOG DE COMPILACAO ===
TYPE "%ROOT%\logs\compile.log" 2>nul
echo =========================
echo.
echo Log salvo em: %ROOT%\logs\compile.log
pause
