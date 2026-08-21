@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ==========================================================
echo MAKECHESS: FINISH LOCAL STOCKFISH HTTP BRIDGE
echo NO REBUILD
echo ==========================================================
echo.

set "LOCAL_EXE=%CD%\build\windows\x64\runner\Release\my_new_chess_app.exe"

echo [1/4] Check already-built Windows EXE...
if not exist "%LOCAL_EXE%" (
  echo ERROR: EXE not found:
  echo %LOCAL_EXE%
  echo.
  echo Send this window to ChatGPT.
  pause
  exit /b 1
)
echo LOCAL_EXE: %LOCAL_EXE%
> "LOCAL_STOCKFISH_EXE_PATH.txt" echo %LOCAL_EXE%

echo.
echo [2/4] Copy Stockfish next to Windows app...
if not exist "stockfish\stockfish.exe" (
  echo ERROR: stockfish\stockfish.exe not found in project root.
  pause
  exit /b 1
)

set "RELEASE_DIR=%CD%\build\windows\x64\runner\Release"
if not exist "%RELEASE_DIR%\stockfish" mkdir "%RELEASE_DIR%\stockfish"

xcopy /E /I /Y "stockfish\*" "%RELEASE_DIR%\stockfish\" >nul
if errorlevel 1 (
  echo ERROR: Stockfish copy failed.
  pause
  exit /b 1
)
echo STOCKFISH_COPY_OK

echo.
echo [3/4] Create Startup shortcut...
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
if errorlevel 1 (
  echo ERROR: Startup shortcut creation failed.
  pause
  exit /b 1
)

echo.
echo [4/4] Start local bridge and test 127.0.0.1:17891...
taskkill /IM my_new_chess_app.exe /F >nul 2>nul
start "" /MIN "%LOCAL_EXE%" --bridge --minimized

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$ok=$false;" ^
  "for($i=0;$i -lt 30;$i++){" ^
  "  Start-Sleep -Milliseconds 500;" ^
  "  try{" ^
  "    $r=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:17891/health' -TimeoutSec 2;" ^
  "    if($r.StatusCode -eq 200){Write-Host $r.Content; $ok=$true; break}" ^
  "  }catch{}" ^
  "};" ^
  "if(-not $ok){throw 'Local bridge did not answer on 127.0.0.1:17891'};"
if errorlevel 1 (
  echo.
  echo LOCAL_BRIDGE_TEST_ERROR
  echo Send the last error lines to ChatGPT.
  pause
  exit /b 1
)

echo.
echo ==========================================================
echo LOCAL_STOCKFISH_HTTP_BRIDGE_OK
echo.
echo The local module is running in the background.
echo NEXT:
echo   .\PUBLISH_MAKECHESS.cmd
echo ==========================================================
pause
exit /b 0
