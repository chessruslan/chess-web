@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp016_INSTALL_TOURNAMENT_OWNER_JOIN_V9.ps1"
if errorlevel 1 (
  echo.
  echo ==========================================================
  echo TOURNAMENT_OWNER_JOIN_V9_ERROR
  echo ==========================================================
  echo Nothing should be published. Send this full window to ChatGPT.
  echo.
  pause
  exit /b 1
)
echo.
echo ==========================================================
echo TOURNAMENT_OWNER_JOIN_V9_OK
 echo ==========================================================
echo Do not publish yet. Send this full window to ChatGPT.
echo.
pause
