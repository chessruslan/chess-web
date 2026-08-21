@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0\17_FIX_TOURNAMENT_OWNER_JOIN_V10.ps1"
if errorlevel 1 (
  echo.
  echo ==========================================================
  echo TOURNAMENT_OWNER_JOIN_V10_ERROR
  echo ==========================================================
  echo Nothing was published. Send this full window to ChatGPT.
  echo.
  pause
  exit /b 1
)
echo.
echo ==========================================================
echo TOURNAMENT_OWNER_JOIN_V10_OK
echo ==========================================================
echo Now run PUBLISH_MAKECHESS.cmd.
echo.
pause
