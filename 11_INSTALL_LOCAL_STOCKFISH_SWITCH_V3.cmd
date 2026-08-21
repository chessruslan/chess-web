@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "PROJECT_ROOT=%CD%"
set "PATCH_PS1=%CD%\PATCH_LOCAL_STOCKFISH_SWITCH_V3.ps1"
set "LOCAL_EXE=%CD%\build\windows\x64\runner\Release\my_new_chess_app.exe"
set "RELEASE_DIR=%CD%\build\windows\x64\runner\Release"
set "HEALTH_URL=http://127.0.0.1:17891/health"

echo ==========================================================
echo MAKECHESS - LOCAL STOCKFISH GLOBAL SWITCH V3
echo ==========================================================
echo Project: %PROJECT_ROOT%
echo.

if not exist "pubspec.yaml" goto :wrong_folder
if not exist "lib\main.dart" goto :wrong_folder
if not exist "lib\ui\panels\right_sidebar_panel.dart" goto :wrong_folder
if not exist "stockfish\stockfish.exe" (
  echo ERROR: stockfish\stockfish.exe was not found.
  goto :fail
)
if not exist "%PATCH_PS1%" (
  echo ERROR: PATCH_LOCAL_STOCKFISH_SWITCH_V3.ps1 was not found.
  goto :fail
)

where flutter >nul 2>nul
if errorlevel 1 (
  echo ERROR: Flutter was not found in PATH.
  goto :fail
)

echo [1/8] Stop the old local Stockfish module...
taskkill /IM my_new_chess_app.exe /F >nul 2>nul

echo [2/8] Backup and patch MakeChess source...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PATCH_PS1%" -ProjectRoot "%PROJECT_ROOT%"
if errorlevel 1 goto :fail

echo [3/8] Check window_manager dependency...
findstr /R /C:"^[ ][ ]*window_manager:" pubspec.yaml >nul 2>nul
if errorlevel 1 (
  echo window_manager is missing - adding it...
  call flutter pub add window_manager
  if errorlevel 1 goto :fail
)

echo [4/8] Flutter packages...
call flutter pub get
if errorlevel 1 goto :fail

echo [5/8] Build the background Windows Stockfish bridge...
call flutter build windows --release -t lib\stockfish_test_app.dart
if errorlevel 1 goto :fail

if not exist "%LOCAL_EXE%" (
  echo ERROR: Windows EXE was not created:
  echo %LOCAL_EXE%
  goto :fail
)

echo [6/8] Put Stockfish next to the Windows bridge...
if not exist "%RELEASE_DIR%\stockfish" mkdir "%RELEASE_DIR%\stockfish"
xcopy /E /I /Y "stockfish\*" "%RELEASE_DIR%\stockfish\" >nul
if errorlevel 1 goto :fail
> "LOCAL_STOCKFISH_EXE_PATH.txt" echo %LOCAL_EXE%

echo [7/8] Create/update automatic background startup...
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
  "$s.Description='MakeChess local Stockfish global bridge V3';" ^
  "$s.Save();" ^
  "Write-Host ('STARTUP_SHORTCUT: ' + $lnk);"
if errorlevel 1 goto :fail

echo [8/8] Start bridge in background and run a real-position test...
start "" /MIN "%LOCAL_EXE%" --bridge --minimized

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$health='%HEALTH_URL%';" ^
  "$ok=$false;" ^
  "for($i=0;$i -lt 50;$i++){" ^
  "  Start-Sleep -Milliseconds 400;" ^
  "  try{" ^
  "    $h=Invoke-RestMethod -Method Get -Uri $health -TimeoutSec 2;" ^
  "    if($h.ok -eq $true -and $h.stockfish -eq $true -and $h.mode -eq 'global-switch-v3'){ $ok=$true; break }" ^
  "  }catch{}" ^
  "};" ^
  "if(-not $ok){throw 'V3 local bridge did not become ready on 127.0.0.1:17891'};" ^
  "$fen='rnbqkbnr/ppp1p1pp/5p2/3pP3/8/5N2/PPP1PPPP/RNBQKB1R w KQkq d6 0 4';" ^
  "$q=[uri]::EscapeDataString($fen);" ^
  "$uri='http://127.0.0.1:17891/analyze?fen='+$q+'&depth=12&variants=3&maxThinkingTime=1500';" ^
  "$r=Invoke-RestMethod -Method Get -Uri $uri -TimeoutSec 30;" ^
  "if($r.source -ne 'local'){throw 'Analyze response is not local'};" ^
  "if($r.turn -ne 'w'){throw ('Wrong side to move returned: '+$r.turn)};" ^
  "if([string]::IsNullOrWhiteSpace([string]$r.move)){throw 'Local Stockfish returned no move'};" ^
  "if($r.fen -ne $fen){throw ('FEN changed inside local bridge. Returned: '+$r.fen)};" ^
  "Write-Host '';" ^
  "Write-Host 'LOCAL_TEST_OK' -ForegroundColor Green;" ^
  "Write-Host ('TURN: ' + $r.turn);" ^
  "Write-Host ('MOVE: ' + $r.move);" ^
  "Write-Host ('FEN : ' + $r.fen);"
if errorlevel 1 goto :fail

echo.
echo ==========================================================
echo LOCAL_STOCKFISH_GLOBAL_SWITCH_V3_OK
echo ==========================================================
echo.
echo Local Stockfish now works as a GLOBAL engine backend switch.
echo The bridge keeps working while its window is minimized/background.
echo.
echo NEXT: run your existing PUBLISH_MAKECHESS.cmd to publish the web changes.
echo Then Ctrl+F5 on makechess.com.
echo.
pause
exit /b 0

:wrong_folder
echo ERROR: This file must be placed and run in the MakeChess project root:
echo C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka
echo The same folder must contain pubspec.yaml and lib\main.dart.
goto :fail

:fail
echo.
echo ==========================================================
echo LOCAL_STOCKFISH_GLOBAL_SWITCH_V3_ERROR
echo ==========================================================
echo Do not publish yet. Send me a screenshot of this window.
echo.
pause
exit /b 1
