@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"

echo ==========================================================
echo MAKECHESS - LOCAL STOCKFISH BRIDGE CHECK
echo No source files will be changed.
echo ==========================================================
echo Project: %CD%
echo.

call :health
if "%HEALTH_OK%"=="1" goto READY

echo [1/3] Local bridge is NOT responding on 127.0.0.1:17891.

tasklist /FI "IMAGENAME eq my_new_chess_app.exe" 2>nul | find /I "my_new_chess_app.exe" >nul
if not errorlevel 1 goto PROCESS_EXISTS

set "BRIDGE_EXE=%CD%\build\windows\x64\runner\Release\my_new_chess_app.exe"
set "STOCKFISH_EXE=%CD%\stockfish\stockfish.exe"

if not exist "%STOCKFISH_EXE%" goto NO_STOCKFISH
if not exist "%BRIDGE_EXE%" goto NO_BRIDGE_EXE

echo [2/3] Background bridge process is not running. Starting it now...
start "MakeChess Local Stockfish" /D "%CD%" /MIN "%BRIDGE_EXE%" --bridge --minimized

timeout /t 3 /nobreak >nul
call :health
if "%HEALTH_OK%"=="1" goto RESTARTED

echo [3/3] Bridge was started, but health check still fails.
echo RESULT: BRIDGE_START_FAILED
pause
exit /b 3

:PROCESS_EXISTS
echo [2/3] my_new_chess_app.exe is already running, but /health does not answer.
echo RESULT: PROCESS_EXISTS_BUT_HEALTH_FAILED
echo Do NOT kill anything yet. Send this window to ChatGPT.
pause
exit /b 2

:NO_STOCKFISH
echo RESULT: STOCKFISH_EXE_NOT_FOUND
echo Expected: %CD%\stockfish\stockfish.exe
pause
exit /b 4

:NO_BRIDGE_EXE
echo RESULT: BRIDGE_EXE_NOT_FOUND
echo Expected: %CD%\build\windows\x64\runner\Release\my_new_chess_app.exe
pause
exit /b 5

:READY
echo RESULT: LOCAL_BRIDGE_HEALTH_OK
echo The local bridge is already running and Stockfish is ready.
echo Now return to Chrome and press the Local Stockfish button once.
echo If it still stays OFF, send this window to ChatGPT.
pause
exit /b 0

:RESTARTED
echo [3/3] Health check passed after restart.
echo RESULT: LOCAL_BRIDGE_RESTARTED_OK
echo Return to Chrome and press the Local Stockfish button once.
pause
exit /b 0

:health
set "HEALTH_OK=0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { $r=Invoke-RestMethod -Uri 'http://127.0.0.1:17891/health' -TimeoutSec 3; if (($r.ok -eq $true) -and ($r.stockfish -eq $true)) { Write-Host ('HEALTH_JSON: ' + ($r | ConvertTo-Json -Compress)); exit 0 } else { Write-Host ('HEALTH_BAD: ' + ($r | ConvertTo-Json -Compress)); exit 1 } } catch { Write-Host ('HEALTH_ERROR: ' + $_.Exception.Message); exit 1 }"
if not errorlevel 1 set "HEALTH_OK=1"
exit /b 0
