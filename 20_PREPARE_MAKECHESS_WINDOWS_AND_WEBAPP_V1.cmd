@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CD%\20_PREPARE_MAKECHESS_WINDOWS_AND_WEBAPP_V1.ps1"

if errorlevel 1 (
  echo.
  echo ==========================================================
  echo MAKECHESS_WINDOWS_WEBAPP_V1_ERROR
  echo ==========================================================
  echo No website was published.
  echo Send this entire window and MAKECHESS_WINDOWS_BUILD_V1.log to ChatGPT.
  echo.
  pause
  exit /b 1
)

echo.
echo ==========================================================
echo MAKECHESS_WINDOWS_WEBAPP_V1_OK
echo ==========================================================
echo First test the new MakeChess shortcut on Desktop.
echo Do NOT publish the website yet.
echo.
pause
