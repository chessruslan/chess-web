@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================================
echo  MAKECHESS - ONE COMMAND FULL RELEASE
echo ============================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RELEASE_MAKECHESS_ALL.ps1"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
    echo ============================================================
    echo  RELEASE FINISHED SUCCESSFULLY
    echo ============================================================
) else (
    echo ============================================================
    echo  RELEASE FAILED - CODE %RC%
    echo ============================================================
)

echo.
pause
exit /b %RC%
