@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CD%\19_INSTALL_LOCAL_STOCKFISH_SILENT_V1.ps1"

if errorlevel 1 (
  echo.
  echo ==========================================================
  echo LOCAL_STOCKFISH_SILENT_V1_ERROR
  echo ==========================================================
  echo Send this full window to ChatGPT.
  echo.
  pause
  exit /b 1
)

echo.
echo ==========================================================
echo LOCAL_STOCKFISH_SILENT_V1_OK
echo ==========================================================
echo No website publish is needed.
echo Return to makechess.com and use only the Local Stockfish switch.
echo.
pause
