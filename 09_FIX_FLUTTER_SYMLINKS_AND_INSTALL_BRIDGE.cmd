@echo off
setlocal EnableExtensions
cd /d "%~dp0"

:: Self-elevate: symlink creation on Windows normally requires either
:: Developer Mode or an elevated process.
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo Requesting Administrator rights for Flutter plugin symlinks...
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

echo ==========================================================
echo MAKECHESS: FIX FLUTTER WINDOWS SYMLINKS + HTTP BRIDGE
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
  pause
  exit /b 1
)

if not exist "lib\stockfish_test_app.dart" (
  echo ERROR: lib\stockfish_test_app.dart not found.
  pause
  exit /b 1
)

if not exist "PATCH_LOCAL_STOCKFISH_HTTP_LOCALIZATION.ps1" (
  echo ERROR: PATCH_LOCAL_STOCKFISH_HTTP_LOCALIZATION.ps1 not found.
  pause
  exit /b 1
)

echo [1/8] Test whether this elevated process can create directory symlinks...
set "SYMLINK_TEST_TARGET=%TEMP%\makechess_symlink_target"
set "SYMLINK_TEST_LINK=%TEMP%\makechess_symlink_link"
rmdir /s /q "%SYMLINK_TEST_TARGET%" >nul 2>nul
rmdir "%SYMLINK_TEST_LINK%" >nul 2>nul
mkdir "%SYMLINK_TEST_TARGET%" >nul 2>nul

cmd /c mklink /D "%SYMLINK_TEST_LINK%" "%SYMLINK_TEST_TARGET%" >nul 2>nul
if errorlevel 1 (
  echo.
  echo SYMLINK_PERMISSION_ERROR
  echo Windows still blocks symbolic-link creation even in an elevated process.
  echo.
  echo Enable Windows Developer Mode:
  echo   Settings ^> System ^> Advanced ^> For developers ^> Developer Mode
  echo.
  echo On older Windows 11 versions:
  echo   Settings ^> Privacy ^& security ^> For developers ^> Developer Mode
  echo.
  echo Then RESTART Windows and run this file again.
  echo.
  rmdir /s /q "%SYMLINK_TEST_TARGET%" >nul 2>nul
  pause
  exit /b 1
)

rmdir "%SYMLINK_TEST_LINK%" >nul 2>nul
rmdir /s /q "%SYMLINK_TEST_TARGET%" >nul 2>nul
echo SYMLINK_TEST_OK

echo.
echo [2/8] Remove stale Flutter Windows plugin links...
if exist "windows\flutter\ephemeral\.plugin_symlinks" (
  rmdir /s /q "windows\flutter\ephemeral\.plugin_symlinks"
)
if exist "windows\flutter\ephemeral\.plugin_symlinks" (
  echo ERROR: could not remove old plugin symlink folder.
  pause
  exit /b 1
)

echo.
echo [3/8] Refresh Flutter packages...
call flutter pub get
if errorlevel 1 goto :fail

echo.
echo [4/8] Add HTTP bridge localization messages...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CD%\PATCH_LOCAL_STOCKFISH_HTTP_LOCALIZATION.ps1"
if errorlevel 1 goto :fail

echo.
echo [5/8] Build local Stockfish Windows app...
call flutter build windows --release -t lib\stockfish_test_app.dart
if errorlevel 1 goto :fail

echo.
echo [6/8] Find EXE and copy Stockfish...
set "LOCAL_EXE="
for /f "usebackq delims=" %%A in (`powershell.exe -NoProfile -Command "$e=Get-ChildItem (Join-Path $PWD 'build\windows') -Recurse -File -Filter 'my_new_chess_app.exe' ^| Where-Object { $_.FullName -match '\\Release\\' } ^| Select-Object -First 1; if($e){$e.FullName}"`) do set "LOCAL_EXE=%%A"

if "%LOCAL_EXE%"=="" (
  echo ERROR: release EXE not found.
  goto :fail
)

echo LOCAL_EXE: %LOCAL_EXE%
> "LOCAL_STOCKFISH_EXE_PATH.txt" echo %LOCAL_EXE%

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$exe='%LOCAL_EXE%';" ^
  "$dst=Join-Path ([System.IO.Path]::GetDirectoryName($exe)) 'stockfish';" ^
  "New-Item -ItemType Directory -Force -Path $dst | Out-Null;" ^
  "Copy-Item (Join-Path $PWD 'stockfish\*') $dst -Recurse -Force;"
if errorlevel 1 goto :fail

echo.
echo [7/8] Create Startup shortcut...
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
echo [8/8] Start bridge and test localhost...
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
if errorlevel 1 goto :fail

echo.
echo ==========================================================
echo LOCAL_STOCKFISH_HTTP_BRIDGE_OK
echo.
echo NEXT:
echo   close this window
echo   run .\PUBLISH_MAKECHESS.cmd
echo   open makechess.com
echo   press Local Stockfish
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
