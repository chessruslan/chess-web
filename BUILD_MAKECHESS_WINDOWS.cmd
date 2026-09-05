@echo off
setlocal
cd /d "%~dp0"

echo ============================================================
echo   MAKECHESS WINDOWS - SBORKA PRILOZHENIYA
echo ============================================================

rem Windows uses the same Selectel backend as the website.
rem PUBLISH_MAKECHESS.cmd is not called and is not modified.
set "SUPABASE_URL=https://api.111-88-227-25.sslip.io"
if exist "%~dp0MAKECHESS_WINDOWS_LOCAL_ENV.cmd" call "%~dp0MAKECHESS_WINDOWS_LOCAL_ENV.cmd"
if not defined SUPABASE_ANON_KEY (
  echo ERROR: local SUPABASE_ANON_KEY is missing.
  echo Expected: MAKECHESS_WINDOWS_LOCAL_ENV.cmd next to this script.
  exit /b 1
)
where flutter >nul 2>nul
if errorlevel 1 (
  echo OSHIBKA: Flutter ne nayden v PATH.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PREPARE_WINDOWS_APP.ps1"
if errorlevel 1 goto :fail

call flutter pub get
if errorlevel 1 goto :fail

call flutter build windows --release --dart-define="SUPABASE_URL=%SUPABASE_URL%" --dart-define="SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%"
if errorlevel 1 goto :fail

echo.
echo GOTOVO.
echo EXE: build\windows\x64\runner\Release\MakeChess.exe
echo.
if /I not "%~1"=="nopause" pause
exit /b 0

:fail
echo.
echo SBORKA OSTANOVLENA IZ-ZA OSHIBKI.
if /I not "%~1"=="nopause" pause
exit /b 1
