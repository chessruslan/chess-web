@echo off
setlocal
cd /d "%~dp0"

echo ==========================================================
echo MAKECHESS: FIX LOCAL STOCKFISH PROTOCOL
echo ==========================================================
echo.

if not exist "OPEN_LOCAL_STOCKFISH_PROTOCOL.ps1" (
  echo ERROR: OPEN_LOCAL_STOCKFISH_PROTOCOL.ps1 not found in project root.
  pause
  exit /b 1
)

if not exist "LOCAL_STOCKFISH_EXE_PATH.txt" (
  echo ERROR: LOCAL_STOCKFISH_EXE_PATH.txt not found.
  echo Run 04_INSTALL_LOCAL_STOCKFISH_BRIDGE.cmd once first.
  pause
  exit /b 1
)

for /f "usebackq delims=" %%A in ("LOCAL_STOCKFISH_EXE_PATH.txt") do set "LOCAL_EXE=%%A"

if not exist "%LOCAL_EXE%" (
  echo ERROR: Local Stockfish app EXE not found:
  echo %LOCAL_EXE%
  pause
  exit /b 1
)

set "HELPER=%CD%\OPEN_LOCAL_STOCKFISH_PROTOCOL.ps1"
set "KEY=HKCU\Software\Classes\makechess-stockfish"
set "CMD=powershell.exe -NoProfile -ExecutionPolicy Bypass -File ^"%HELPER%^" -Uri ^"%%1^" -ExePath ^"%LOCAL_EXE%^""

echo [1/4] Remove incomplete old protocol registration...
reg.exe delete "%KEY%" /f >nul 2>nul

echo.
echo [2/4] Register protocol through REG.EXE...
reg.exe add "%KEY%" /ve /t REG_SZ /d "URL:MakeChess Local Stockfish" /f
if errorlevel 1 goto :registry_fail

reg.exe add "%KEY%" /v "URL Protocol" /t REG_SZ /d "" /f
if errorlevel 1 goto :registry_fail

reg.exe add "%KEY%\DefaultIcon" /ve /t REG_SZ /d "\"%LOCAL_EXE%\",0" /f
if errorlevel 1 goto :registry_fail

reg.exe add "%KEY%\shell\open\command" /ve /t REG_SZ /d "%CMD%" /f
if errorlevel 1 goto :registry_fail

echo.
echo [3/4] Verify protocol...
reg.exe query "%KEY%" /v "URL Protocol"
if errorlevel 1 goto :registry_fail

reg.exe query "%KEY%\shell\open\command" /ve
if errorlevel 1 goto :registry_fail

echo.
echo [4/4] Done.
echo.
echo MAKECHESS_STOCKFISH_PROTOCOL_OK
echo LOCAL_STOCKFISH_BRIDGE_OK
echo.
echo Now run:
echo   .\PUBLISH_MAKECHESS.cmd
echo.
echo Then open MakeChess in Chrome and press:
echo   Local Stockfish
echo.
pause
exit /b 0

:registry_fail
echo.
echo ==========================================================
echo REGISTRY_ERROR
echo.
echo Windows did not allow writing the protocol registration.
echo Do NOT rebuild anything.
echo Send this window to ChatGPT.
echo ==========================================================
pause
exit /b 1
