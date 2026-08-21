@echo off
setlocal
cd /d "%~dp0"

echo ==========================================================
echo MAKECHESS: INSTALL LOCAL STOCKFISH BRIDGE V1
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
  echo First run 01_SETUP_WINDOWS_AND_STOCKFISH.cmd
  pause
  exit /b 1
)

if not exist "lib\stockfish_test_app.dart" (
  echo ERROR: lib\stockfish_test_app.dart not found.
  pause
  exit /b 1
)

if not exist "OPEN_LOCAL_STOCKFISH_PROTOCOL.ps1" (
  echo ERROR: OPEN_LOCAL_STOCKFISH_PROTOCOL.ps1 not found.
  pause
  exit /b 1
)

if not exist "PATCH_LOCAL_STOCKFISH_LOCALIZATION.ps1" (
  echo ERROR: PATCH_LOCAL_STOCKFISH_LOCALIZATION.ps1 not found.
  pause
  exit /b 1
)

echo [1/6] Add url_launcher dependency...
call flutter pub add url_launcher
if errorlevel 1 goto :fail

echo.
echo [2/6] Add Local Stockfish text to all 11 MakeChess languages...
powershell -NoProfile -ExecutionPolicy Bypass -File "%CD%\PATCH_LOCAL_STOCKFISH_LOCALIZATION.ps1"
if errorlevel 1 goto :fail

echo.
echo [3/6] Build local Stockfish Windows application...
call flutter build windows --release -t lib\stockfish_test_app.dart
if errorlevel 1 goto :fail

echo.
echo [4/6] Find release EXE and copy Stockfish next to it...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$exe=Get-ChildItem (Join-Path $PWD 'build\windows') -Recurse -File -Filter 'my_new_chess_app.exe' | Where-Object { $_.FullName -match '\\Release\\' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1;" ^
  "if(-not $exe){throw 'Release EXE not found'};" ^
  "$release=$exe.Directory.FullName;" ^
  "$dst=Join-Path $release 'stockfish';" ^
  "New-Item -ItemType Directory -Force -Path $dst | Out-Null;" ^
  "Copy-Item (Join-Path $PWD 'stockfish\*') $dst -Recurse -Force;" ^
  "[System.IO.File]::WriteAllText((Join-Path $PWD 'LOCAL_STOCKFISH_EXE_PATH.txt'), $exe.FullName, (New-Object System.Text.UTF8Encoding($false)));" ^
  "Write-Host ('LOCAL_EXE: ' + $exe.FullName);"
if errorlevel 1 goto :fail

echo.
echo [5/6] Register makechess-stockfish:// protocol for current Windows user...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$helper=(Join-Path $PWD 'OPEN_LOCAL_STOCKFISH_PROTOCOL.ps1');" ^
  "$exe=[System.IO.File]::ReadAllText((Join-Path $PWD 'LOCAL_STOCKFISH_EXE_PATH.txt'), [System.Text.Encoding]::UTF8).Trim();" ^
  "$root='HKCU:\Software\Classes\makechess-stockfish';" ^
  "$cmdKey=Join-Path $root 'shell\open\command';" ^
  "New-Item -Path $cmdKey -Force | Out-Null;" ^
  "Set-Item -Path $root -Value 'URL:MakeChess Local Stockfish';" ^
  "New-ItemProperty -Path $root -Name 'URL Protocol' -Value '' -PropertyType String -Force | Out-Null;" ^
  "$command='powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""' + $helper + '"" -Uri ""%1"" -ExePath ""' + $exe + '""';" ^
  "Set-Item -Path $cmdKey -Value $command;" ^
  "Write-Host ('PROTOCOL_COMMAND: ' + $command);"
if errorlevel 1 goto :fail

echo.
echo [6/6] Verify registration...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$v=(Get-Item 'HKCU:\Software\Classes\makechess-stockfish\shell\open\command').GetValue('');" ^
  "if([string]::IsNullOrWhiteSpace($v)){exit 1};" ^
  "Write-Host 'MAKECHESS_STOCKFISH_PROTOCOL_OK';" ^
  "Write-Host $v;"
if errorlevel 1 goto :fail

echo.
echo ==========================================================
echo LOCAL_STOCKFISH_BRIDGE_OK
echo.
echo Now publish the WEB version normally:
echo   .\PUBLISH_MAKECHESS.cmd
echo.
echo Then open MakeChess in Chrome and press:
echo   Local Stockfish
echo ==========================================================
pause
exit /b 0

:fail
echo.
echo ==========================================================
echo LOCAL_STOCKFISH_BRIDGE_ERROR
echo Copy the last error lines and send them to ChatGPT.
echo ==========================================================
pause
exit /b 1
