@echo off
setlocal
cd /d "%~dp0"

echo ==========================================================
echo MAKECHESS: BUILD WINDOWS RELEASE
echo ==========================================================
echo.

if not exist "stockfish\stockfish.exe" (
  echo ERROR: stockfish\stockfish.exe not found.
  echo First run 01_SETUP_WINDOWS_AND_STOCKFISH.cmd
  pause
  exit /b 1
)

call flutter build windows --release
if errorlevel 1 goto :fail

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$exe=Get-ChildItem (Join-Path $PWD 'build\windows') -Recurse -File -Filter 'my_new_chess_app.exe' | Where-Object { $_.FullName -match '\\Release\\' } | Select-Object -First 1;" ^
  "if(-not $exe){throw 'Release EXE not found'};" ^
  "$release=$exe.Directory.FullName;" ^
  "$dst=Join-Path $release 'stockfish';" ^
  "New-Item -ItemType Directory -Force -Path $dst | Out-Null;" ^
  "Copy-Item (Join-Path $PWD 'stockfish\*') $dst -Recurse -Force;" ^
  "Write-Host '';" ^
  "Write-Host 'WINDOWS_RELEASE_OK';" ^
  "Write-Host ('EXE: ' + $exe.FullName);" ^
  "Write-Host ('Stockfish: ' + (Join-Path $dst 'stockfish.exe'));"
if errorlevel 1 goto :fail

echo.
echo BUILD_OK
pause
exit /b 0

:fail
echo.
echo BUILD_ERROR
pause
exit /b 1
