@echo off
setlocal
cd /d "%~dp0"

echo ==========================================================
echo MAKECHESS: RUN LOCAL WINDOWS STOCKFISH TEST APP
echo ==========================================================
echo.

if not exist "stockfish\stockfish.exe" (
  echo ERROR: stockfish\stockfish.exe not found.
  echo First run 01_SETUP_WINDOWS_AND_STOCKFISH.cmd
  pause
  exit /b 1
)

call flutter run -d windows -t lib\stockfish_test_app.dart

echo.
echo Flutter process finished.
pause
