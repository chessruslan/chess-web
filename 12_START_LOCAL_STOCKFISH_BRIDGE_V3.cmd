@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "LOCAL_EXE=%CD%\build\windows\x64\runner\Release\my_new_chess_app.exe"
if not exist "%LOCAL_EXE%" (
  echo Local bridge EXE not found.
  echo First run 11_INSTALL_LOCAL_STOCKFISH_SWITCH_V3.cmd
  pause
  exit /b 1
)
taskkill /IM my_new_chess_app.exe /F >nul 2>nul
start "" /MIN "%LOCAL_EXE%" --bridge --minimized
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ok=$false; for($i=0;$i -lt 30;$i++){ Start-Sleep -Milliseconds 400; try{$h=Invoke-RestMethod 'http://127.0.0.1:17891/health' -TimeoutSec 2; if($h.ok -and $h.stockfish -and $h.mode -eq 'global-switch-v3'){$ok=$true;break}}catch{} }; if(-not $ok){exit 1}; Write-Host 'LOCAL_STOCKFISH_BRIDGE_V3_READY' -ForegroundColor Green"
if errorlevel 1 (
  echo ERROR: bridge did not start.
  pause
  exit /b 1
)
echo Ready. You can close this window.
pause
