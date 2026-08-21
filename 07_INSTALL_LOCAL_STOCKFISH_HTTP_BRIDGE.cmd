@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ==========================================================
echo MAKECHESS: LOCAL STOCKFISH HTTP BRIDGE V2
echo NO REGISTRY. NO ADMIN RIGHTS.
echo ==========================================================
echo.

where flutter >nul 2>nul
if errorlevel 1 (
  echo ERROR: flutter not found in PATH.
  pause
  exit /b 1
)

if not exist "stockfish\stockfish.exe" (
  echo ERROR: stockfish\stockfish.exe not found.
  echo Run the Stockfish setup first.
  pause
  exit /b 1
)

if not exist "lib\stockfish_test_app.dart" (
  echo ERROR: lib\stockfish_test_app.dart not found.
  pause
  exit /b 1
)

echo [1/7] Add window_manager...
call flutter pub add window_manager
if errorlevel 1 goto :fail

echo.
echo [2/7] Add two localization messages...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CD%\PATCH_LOCAL_STOCKFISH_HTTP_LOCALIZATION.ps1"
if errorlevel 1 goto :fail

echo.
echo [3/7] Build local Stockfish Windows app...
call flutter build windows --release -t lib\stockfish_test_app.dart
if errorlevel 1 goto :fail

echo.
echo [4/7] Find release EXE...
set "LOCAL_EXE="
for /f "usebackq delims=" %%A in (`powershell.exe -NoProfile -Command "$e=Get-ChildItem (Join-Path $PWD 'build\windows') -Recurse -File -Filter 'my_new_chess_app.exe' ^| Where-Object { $_.FullName -match '\\Release\\' } ^| Select-Object -First 1; if($e){$e.FullName}"`) do set "LOCAL_EXE=%%A"

if "%LOCAL_EXE%"=="" (
  echo ERROR: release EXE not found.
  goto :fail
)

echo LOCAL_EXE: %LOCAL_EXE%
> "LOCAL_STOCKFISH_EXE_PATH.txt" echo %LOCAL_EXE%

echo.
echo [5/7] Copy Stockfish next to local app...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$exe='%LOCAL_EXE%';" ^
  "$dst=Join-Path ([System.IO.Path]::GetDirectoryName($exe)) 'stockfish';" ^
  "New-Item -ItemType Directory -Force -Path $dst | Out-Null;" ^
  "Copy-Item (Join-Path $PWD 'stockfish\*') $dst -Recurse -Force;"
if errorlevel 1 goto :fail

echo.
echo [6/7] Create Startup shortcut, so bridge is always available...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$exe='%LOCAL_EXE%';" ^
  "$startup=[Environment]::GetFolderPath('Startup');" ^
  "$lnk=Join-Path $startup 'MakeChess Local Stockfish.lnk';" ^
  "$ws=New-Object -ComObject WScript.Shell;" ^
  "$s=$ws.CreateShortcut($lnk);" ^
  "$s.TargetPath=$exe;" ^
  "$s.Arguments='--bridge --minimized';" ^
  "$s.WorkingDirectory=[System.IO.Path]::GetDirectoryName($exe);" ^
  "$s.Description='MakeChess local Stockfish bridge';" ^
  "$s.Save();" ^
  "Write-Host ('STARTUP_SHORTCUT: ' + $lnk);"
if errorlevel 1 goto :fail

echo.
echo [7/7] Start bridge now and test 127.0.0.1:17891...
taskkill /IM my_new_chess_app.exe /F >nul 2>nul
start "" /MIN "%LOCAL_EXE%" --bridge --minimized

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$ok=$false;" ^
  "for($i=0;$i -lt 20;$i++){" ^
  "  Start-Sleep -Milliseconds 500;" ^
  "  try{" ^
  "    $r=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:17891/health' -TimeoutSec 2;" ^
  "    if($r.StatusCode -eq 200){Write-Host $r.Content; $ok=$true; break}" ^
  "  }catch{}" ^
  "};" ^
  "if(-not $ok){throw 'Local bridge did not answer on 127.0.0.1:17891'};"
if errorlevel 1 goto :fail

echo.
echo ==========================================================
echo LOCAL_STOCKFISH_HTTP_BRIDGE_OK
echo.
echo No registry protocol is used anymore.
echo The local module is running in the background.
echo It will start automatically when you log into Windows.
echo.
echo NEXT:
echo   .\PUBLISH_MAKECHESS.cmd
echo.
echo Then press "Local Stockfish" on makechess.com.
echo Chrome may ask for Local Network Access once.
echo Choose ALLOW.
echo ==========================================================
pause
exit /b 0

:fail
echo.
echo ==========================================================
echo LOCAL_STOCKFISH_HTTP_BRIDGE_ERROR
echo Send the last error lines to ChatGPT.
echo ==========================================================
pause
exit /b 1
