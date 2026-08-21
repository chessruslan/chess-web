@echo off
setlocal
cd /d C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0COLLECT_MAKECHESS_REMAINING_UI_V6.ps1" -ProjectRoot "C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
if errorlevel 1 (
  echo.
  echo ERROR. Project source files were NOT changed.
  pause
  exit /b 1
)
echo.
pause
