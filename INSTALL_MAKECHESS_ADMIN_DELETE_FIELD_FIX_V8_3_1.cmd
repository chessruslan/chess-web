@echo off
setlocal
cd /d C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL_MAKECHESS_ADMIN_DELETE_FIELD_FIX_V8_3_1.ps1" -ProjectRoot "C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
if errorlevel 1 (
  echo.
  echo ERROR. The original file was restored or nothing was changed.
  pause
  exit /b 1
)
echo.
pause
