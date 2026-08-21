@echo off
setlocal
cd /d "%~dp0"

if not exist "LOCAL_STOCKFISH_EXE_PATH.txt" (
  echo ERROR: LOCAL_STOCKFISH_EXE_PATH.txt not found.
  echo Run 07_INSTALL_LOCAL_STOCKFISH_HTTP_BRIDGE.cmd first.
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

start "" /MIN "%LOCAL_EXE%" --bridge --minimized
timeout /t 2 /nobreak >nul

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "try{$r=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:17891/health' -TimeoutSec 3; Write-Host $r.Content}catch{Write-Host $_; exit 1}"

if errorlevel 1 (
  echo BRIDGE_START_ERROR
) else (
  echo BRIDGE_READY
)

pause
