@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================================
echo   MAKECHESS - BUILD INSTALLER 1.0.0
echo ============================================================
echo.

set "RELEASE_DIR=%~dp0build\windows\x64\runner\Release"
set "APP_EXE=%RELEASE_DIR%\MakeChess.exe"
set "ISS=%~dp0installer\MakeChess.iss"
set "OUT=%~dp0dist\MakeChess_Setup_1.0.0.exe"

if not exist "%APP_EXE%" (
  echo MakeChess.exe not found. Building Windows release first...
  echo.
  call "%~dp0BUILD_MAKECHESS_WINDOWS.cmd"
  if errorlevel 1 goto :fail
)

if not exist "%RELEASE_DIR%\flutter_windows.dll" (
  echo ERROR: flutter_windows.dll not found in Release folder.
  goto :fail
)

if not exist "%RELEASE_DIR%\data" (
  echo ERROR: Flutter data folder not found in Release folder.
  goto :fail
)

if not exist "%ISS%" (
  echo ERROR: installer\MakeChess.iss not found.
  goto :fail
)

if not exist "%~dp0installer\MakeChess.ico" (
  echo ERROR: installer\MakeChess.ico not found.
  goto :fail
)

set "ISCC="

where ISCC.exe >nul 2>nul
if not errorlevel 1 set "ISCC=ISCC.exe"

if not defined ISCC if exist "%ProgramFiles%\Inno Setup 7\ISCC.exe" set "ISCC=%ProgramFiles%\Inno Setup 7\ISCC.exe"
if not defined ISCC if exist "%ProgramFiles(x86)%\Inno Setup 7\ISCC.exe" set "ISCC=%ProgramFiles(x86)%\Inno Setup 7\ISCC.exe"
if not defined ISCC if exist "%LocalAppData%\Programs\Inno Setup 7\ISCC.exe" set "ISCC=%LocalAppData%\Programs\Inno Setup 7\ISCC.exe"
if not defined ISCC if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
if not defined ISCC if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not defined ISCC if exist "%LocalAppData%\Programs\Inno Setup 6\ISCC.exe" set "ISCC=%LocalAppData%\Programs\Inno Setup 6\ISCC.exe"

if not defined ISCC (
  echo.
  echo INNO SETUP NOT FOUND.
  echo.
  echo Install it once with:
  echo   winget install --id JRSoftware.InnoSetup.7 -e -s winget -i
  echo.
  echo Then run BUILD_MAKECHESS_INSTALLER.cmd again.
  goto :fail
)

if exist "%OUT%" del /q "%OUT%"

echo Inno Setup compiler:
echo %ISCC%
echo.
echo Building installer...
"%ISCC%" "%ISS%"
if errorlevel 1 goto :fail

if not exist "%OUT%" (
  echo ERROR: installer build finished but output file was not found.
  goto :fail
)

echo.
echo ============================================================
echo   INSTALLER READY
echo ============================================================
echo   %OUT%
echo ============================================================
echo.
for %%F in ("%OUT%") do echo Size: %%~zF bytes
echo.
explorer /select,"%OUT%"
pause
exit /b 0

:fail
echo.
echo ============================================================
echo   INSTALLER BUILD STOPPED
echo ============================================================
echo.
pause
exit /b 1