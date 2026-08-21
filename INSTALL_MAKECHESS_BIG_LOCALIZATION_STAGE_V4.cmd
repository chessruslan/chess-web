@echo off
setlocal
cd /d C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL_MAKECHESS_BIG_LOCALIZATION_STAGE_V4.ps1" -ProjectRoot "C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
if errorlevel 1 (
  echo.
  echo ERROR. All 14 previous files were restored or nothing was changed.
  pause
  exit /b 1
)
echo.
pause
