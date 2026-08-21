@echo off
setlocal
cd /d C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL_MAKECHESS_REMAINING_UI_LOCALIZATION_V6.ps1" -ProjectRoot "C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
if errorlevel 1 (
  echo.
  echo ERROR. All previous V6 target files were restored or nothing was changed.
  pause
  exit /b 1
)
echo.
pause
