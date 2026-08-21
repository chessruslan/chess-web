@echo off
setlocal
cd /d "%~dp0"

echo ==========================================================
echo MAKECHESS: WINDOWS + LOCAL STOCKFISH SETUP V2
echo ==========================================================
echo.

where flutter >nul 2>nul
if errorlevel 1 (
  echo ERROR: flutter not found in PATH.
  pause
  exit /b 1
)

echo [1/7] Enable Windows desktop...
call flutter config --enable-windows-desktop
if errorlevel 1 goto :fail

echo.
echo [2/7] Check Windows project files...
if not exist "windows\CMakeLists.txt" (
  echo Windows folder not found. Creating it...
  call flutter create --platforms=windows .
  if errorlevel 1 goto :fail
) else (
  echo Windows platform already exists. Skip.
)

echo.
echo [3/7] flutter pub get...
call flutter pub get
if errorlevel 1 goto :fail

echo.
echo [4/7] Download compatible official Stockfish Windows x86-64...
echo We intentionally use generic x86-64 for the first test, not AVX2.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$url='https://github.com/official-stockfish/Stockfish/releases/latest/download/stockfish-windows-x86-64.zip';" ^
  "$zip=Join-Path $PWD 'stockfish_download.zip';" ^
  "$tmp=Join-Path $PWD 'stockfish_extract_tmp';" ^
  "$dst=Join-Path $PWD 'stockfish';" ^
  "if(Test-Path $zip){Remove-Item $zip -Force};" ^
  "if(Test-Path $tmp){Remove-Item $tmp -Recurse -Force};" ^
  "if(Test-Path $dst){Remove-Item $dst -Recurse -Force};" ^
  "New-Item -ItemType Directory -Force -Path $dst | Out-Null;" ^
  "Invoke-WebRequest -Uri $url -OutFile $zip;" ^
  "Expand-Archive -Path $zip -DestinationPath $tmp -Force;" ^
  "$exe=Get-ChildItem $tmp -Recurse -File -Filter 'stockfish*.exe' | Select-Object -First 1;" ^
  "if(-not $exe){throw 'stockfish.exe not found in archive'};" ^
  "Copy-Item $exe.FullName (Join-Path $dst 'stockfish.exe') -Force;" ^
  "$copying=Get-ChildItem $tmp -Recurse -File | Where-Object { $_.Name -match '^(COPYING|Copying|LICENSE)(\.txt)?$' } | Select-Object -First 1;" ^
  "if($copying){Copy-Item $copying.FullName (Join-Path $dst $copying.Name) -Force};" ^
  "Remove-Item $zip -Force;" ^
  "Remove-Item $tmp -Recurse -Force;" ^
  "Write-Host ('Stockfish: ' + (Join-Path $dst 'stockfish.exe'));"
if errorlevel 1 goto :fail

echo.
echo [5/7] Direct UCI test without Dart...
(
  echo uci
  echo quit
) | stockfish\stockfish.exe > stockfish_uci_test.txt 2>&1

findstr /C:"uciok" stockfish_uci_test.txt >nul
if errorlevel 1 (
  echo ERROR: Stockfish EXE itself did not return uciok.
  echo.
  echo ----- stockfish_uci_test.txt -----
  type stockfish_uci_test.txt
  echo ----------------------------------
  goto :fail
)

echo DIRECT_UCI_OK

echo.
echo [6/7] Check Flutter Windows device...
call flutter devices
if errorlevel 1 goto :fail

echo.
echo [7/7] Dart Stockfish smoke test...
call dart run tool\stockfish_smoke_test.dart
if errorlevel 1 goto :fail

echo.
echo ==========================================================
echo SETUP_OK
echo Stockfish EXE: OK
echo Dart UCI connection: OK
echo Now run: 02_RUN_WINDOWS_STOCKFISH_TEST.cmd
echo ==========================================================
pause
exit /b 0

:fail
echo.
echo ==========================================================
echo SETUP_ERROR
echo Copy the last error lines and send them to ChatGPT.
echo ==========================================================
pause
exit /b 1
