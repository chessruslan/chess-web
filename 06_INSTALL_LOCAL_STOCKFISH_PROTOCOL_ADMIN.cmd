@echo off
setlocal EnableExtensions
cd /d "%~dp0"

:: Self-elevate
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo Requesting Administrator rights...
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

echo ==========================================================
echo MAKECHESS: INSTALL LOCAL STOCKFISH PROTOCOL AS ADMIN
echo ==========================================================
echo.

if not exist "OPEN_LOCAL_STOCKFISH_PROTOCOL.ps1" (
  echo ERROR: OPEN_LOCAL_STOCKFISH_PROTOCOL.ps1 not found.
  echo Put this CMD in:
  echo C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka
  pause
  exit /b 1
)

if not exist "LOCAL_STOCKFISH_EXE_PATH.txt" (
  echo ERROR: LOCAL_STOCKFISH_EXE_PATH.txt not found.
  echo The Windows Stockfish app was not recorded.
  pause
  exit /b 1
)

for /f "usebackq delims=" %%A in ("LOCAL_STOCKFISH_EXE_PATH.txt") do set "LOCAL_EXE=%%A"

if not exist "%LOCAL_EXE%" (
  echo ERROR: EXE not found:
  echo %LOCAL_EXE%
  pause
  exit /b 1
)

set "HELPER=%CD%\OPEN_LOCAL_STOCKFISH_PROTOCOL.ps1"
set "HKCU_KEY=HKCU\Software\Classes\makechess-stockfish"
set "HKLM_KEY=HKLM\Software\Classes\makechess-stockfish"

echo [1/5] Remove incomplete per-user registration...
reg.exe delete "%HKCU_KEY%" /f >nul 2>&1

echo.
echo [2/5] Remove old machine registration if any...
reg.exe delete "%HKLM_KEY%" /f >nul 2>&1

echo.
echo [3/5] Create machine-wide protocol registration...
reg.exe add "%HKLM_KEY%" /ve /t REG_SZ /d "URL:MakeChess Local Stockfish" /f
if errorlevel 1 goto :fail

reg.exe add "%HKLM_KEY%" /v "URL Protocol" /t REG_SZ /d "" /f
if errorlevel 1 goto :fail

reg.exe add "%HKLM_KEY%\DefaultIcon" /ve /t REG_SZ /d "\"%LOCAL_EXE%\",0" /f
if errorlevel 1 goto :fail

set "OPEN_CMD=powershell.exe -NoProfile -ExecutionPolicy Bypass -File ^"%HELPER%^" -Uri ^"%%1^" -ExePath ^"%LOCAL_EXE%^""
reg.exe add "%HKLM_KEY%\shell\open\command" /ve /t REG_SZ /d "%OPEN_CMD%" /f
if errorlevel 1 goto :fail

echo.
echo [4/5] Verify registry...
reg.exe query "%HKLM_KEY%" /v "URL Protocol"
if errorlevel 1 goto :fail
reg.exe query "%HKLM_KEY%\shell\open\command" /ve
if errorlevel 1 goto :fail

echo.
echo [5/5] Test protocol launch...
start "" "makechess-stockfish://analyze?fen=rnbqkbnr%%2Fpppppppp%%2F8%%2F8%%2F8%%2F8%%2FPPPPPPPP%%2FRNBQKBNR%%20w%%20KQkq%%20-%%200%%201"

echo.
echo ==========================================================
echo MAKECHESS_STOCKFISH_PROTOCOL_OK
echo LOCAL_STOCKFISH_BRIDGE_OK
echo.
echo A local Stockfish window should open automatically now.
echo If it opened, close it and run:
echo   .\PUBLISH_MAKECHESS.cmd
echo ==========================================================
pause
exit /b 0

:fail
echo.
echo ==========================================================
echo ADMIN_PROTOCOL_ERROR
echo Registration still failed even with Administrator rights.
echo Send the last lines of this window to ChatGPT.
echo ==========================================================
pause
exit /b 1
