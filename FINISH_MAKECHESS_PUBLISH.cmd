@echo off
setlocal EnableExtensions DisableDelayedExpansion
title MakeChess - finish publication

set "SERVER=flexyops@111.88.227.25"
set "KEY=%USERPROFILE%\.ssh\makechess_selectel"
set "REMOTE_SCRIPT=/home/flexyops/finish_makechess_publish.sh"
set "LOG=%~dp0FINISH_MAKECHESS_PUBLISH_LOG.txt"

cd /d "%~dp0"

> "%LOG%" echo MakeChess finish publication log
>>"%LOG%" echo Started: %date% %time%
>>"%LOG%" echo.

echo ============================================================
echo   MAKECHESS.COM - FINISH CURRENT PUBLICATION
echo ============================================================
echo.
echo The Flutter build has already succeeded and was uploaded.
echo This command only installs that uploaded build on the server.
echo No compilation.
echo.

if not exist "%KEY%" (
  echo ERROR: SSH key not found:
  echo %KEY%
  pause
  exit /b 1
)

if not exist "finish_makechess_publish.sh" (
  echo ERROR: finish_makechess_publish.sh is missing.
  echo Keep both files in the same folder.
  pause
  exit /b 1
)

where ssh >nul 2>&1 || (
  echo ERROR: Windows SSH was not found.
  pause
  exit /b 1
)

where scp >nul 2>&1 || (
  echo ERROR: Windows SCP was not found.
  pause
  exit /b 1
)

echo [1/2] Uploading corrected server script...
scp -B -i "%KEY%" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -o ConnectionAttempts=1 "finish_makechess_publish.sh" "%SERVER%:%REMOTE_SCRIPT%" >>"%LOG%" 2>&1
if errorlevel 1 (
  echo ERROR: Could not upload the server script.
  echo The website was not changed.
  start "" notepad "%LOG%"
  pause
  exit /b 1
)

echo [2/2] Installing the already checked build...
ssh -n -i "%KEY%" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -o ConnectionAttempts=1 -o ServerAliveInterval=10 -o ServerAliveCountMax=3 "%SERVER%" "chmod 700 %REMOTE_SCRIPT% && %REMOTE_SCRIPT%" >>"%LOG%" 2>&1
if errorlevel 1 (
  echo ERROR: Publication failed.
  echo The previous website was kept or restored.
  start "" notepad "%LOG%"
  pause
  exit /b 1
)

echo.
echo ============================================================
echo   DONE: WEBSITE PUBLISHED
echo ============================================================
echo.
start "" "https://makechess.com/?published=1"
echo Press Ctrl+F5 once in the browser.
echo.
pause
exit /b 0
