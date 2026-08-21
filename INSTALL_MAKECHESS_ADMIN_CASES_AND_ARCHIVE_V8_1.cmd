@echo off
setlocal EnableExtensions
title MakeChess Admin Cases + Archive V8.1
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL_MAKECHESS_ADMIN_CASES_AND_ARCHIVE_V8_1.ps1"
if errorlevel 1 (
  echo.
  echo ERROR. Previous files were restored or nothing was changed.
  pause
  exit /b 1
)
echo.
echo V8.1 INSTALLATION FINISHED.
pause
