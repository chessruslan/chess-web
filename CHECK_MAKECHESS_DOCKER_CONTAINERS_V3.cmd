@echo off
setlocal EnableExtensions
title MakeChess - DOCKER CONTAINERS CHECK V3

set "SERVER=flexyops@111.88.227.25"
set "KEY=%USERPROFILE%\.ssh\makechess_selectel"
set "RESULT=%~dp0CHECK_MAKECHESS_DOCKER_CONTAINERS_RESULT.txt"

echo.
echo ============================================================
echo   MAKECHESS DOCKER CONTAINERS CHECK V3
echo   READ ONLY
echo ============================================================
echo.

if not exist "%KEY%" (
  echo ERROR: SSH key not found:
  echo %KEY%
  pause
  exit /b 1
)

echo Connecting to Selectel and reading Docker container names...
ssh -i "%KEY%" -o BatchMode=yes -o ConnectTimeout=10 "%SERVER%" "docker ps --format '{{.Names}}|{{.Image}}'" > "%RESULT%" 2>&1

if errorlevel 1 (
  echo.
  echo ERROR. See result file:
  echo %RESULT%
  echo.
  pause
  exit /b 1
)

echo.
echo DONE.
echo Result file created:
echo %RESULT%
echo.
echo Send CHECK_MAKECHESS_DOCKER_CONTAINERS_RESULT.txt to ChatGPT.
echo.
pause
