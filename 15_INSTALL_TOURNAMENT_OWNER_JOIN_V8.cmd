@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0\15_INSTALL_TOURNAMENT_OWNER_JOIN_V8.ps1"
if errorlevel 1 (
  echo.
  echo ==========================================================
  echo TOURNAMENT_OWNER_JOIN_V8_ERROR
  echo ==========================================================
  echo Nothing should be published. Send this full window to ChatGPT.
  echo.
  pause
  exit /b 1
)
echo.
pause
