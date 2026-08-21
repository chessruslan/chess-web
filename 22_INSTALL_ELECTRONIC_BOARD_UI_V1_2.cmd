@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CD%\22_INSTALL_ELECTRONIC_BOARD_UI_V1_2.ps1"

if errorlevel 1 (
  echo.
  echo ==========================================================
  echo MAKECHESS_ELECTRONIC_BOARD_UI_V1_2_ERROR
  echo ==========================================================
  echo Send this entire window to ChatGPT.
  echo No website was published.
  echo.
  pause
  exit /b 1
)

echo.
echo ==========================================================
echo MAKECHESS_ELECTRONIC_BOARD_UI_V1_2_OK
echo ==========================================================
echo Build passed. Website was NOT published.
echo Send this window to ChatGPT before publishing.
echo.
pause
