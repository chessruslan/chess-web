@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"

echo ============================================================
echo   MAKECHESS WINDOWS - SBORKA INSTALLERA
ECHO ============================================================

call BUILD_MAKECHESS_WINDOWS.cmd nopause
if errorlevel 1 exit /b 1

for /f "tokens=2 delims=: " %%A in ('findstr /b /c:"version:" pubspec.yaml') do set APP_VERSION=%%A
for /f "tokens=1 delims=+" %%A in ("!APP_VERSION!") do set APP_VERSION=%%A

set ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe
if not exist "!ISCC!" set ISCC=C:\Program Files\Inno Setup 6\ISCC.exe
if not exist "!ISCC!" (
  echo.
  echo Inno Setup 6 ne nayden.
  echo Ustanovite Inno Setup 6 i zapustite etot fail eshe raz.
  pause
  exit /b 2
)

"!ISCC!" /DMyAppVersion=!APP_VERSION! installer\MakeChess.iss
if errorlevel 1 goto :fail

echo.
echo INSTALLER GOTOV:
echo build\installer\MakeChessSetup-!APP_VERSION!.exe
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0MAKE_UPDATE_JSON.ps1" -Version !APP_VERSION!

echo.
echo update.json sozdany v desktop\update.json
pause
exit /b 0

:fail
echo OSHIBKA SBORKI INSTALLERA.
pause
exit /b 1
