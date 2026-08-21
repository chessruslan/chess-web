@echo off
setlocal EnableExtensions DisableDelayedExpansion
title MakeChess Backup Check

set "SERVER=flexyops@111.88.227.25"
set "KEY=%USERPROFILE%\.ssh\makechess_selectel"
set "REMOTE_SCRIPT=/home/flexyops/check_makechess_backups.sh"
set "LOG=%~dp0CHECK_MAKECHESS_BACKUPS_LOG.txt"

cd /d "%~dp0"

echo ============================================================
echo   MAKECHESS.COM - SAFE BACKUP CHECK
echo ============================================================
echo.
echo This only reads server files. It changes nothing.
echo.

if not exist "%KEY%" (
    echo ERROR: SSH key not found:
    echo %KEY%
    pause
    exit /b 1
)

if not exist "check_makechess_backups.sh" (
    echo ERROR: check_makechess_backups.sh is missing.
    echo Put both files in the same folder.
    pause
    exit /b 1
)

echo [1/2] Uploading read-only check script...
scp -B -i "%KEY%" -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=15 -o ConnectionAttempts=1 "check_makechess_backups.sh" "%SERVER%:%REMOTE_SCRIPT%" >"%LOG%" 2>&1
if errorlevel 1 (
    echo ERROR: Could not upload the check script.
    start "" notepad "%LOG%"
    pause
    exit /b 1
)

echo [2/2] Reading backup information...
ssh -n -i "%KEY%" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=15 -o ConnectionAttempts=1 -o ServerAliveInterval=10 -o ServerAliveCountMax=3 "%SERVER%" "sh %REMOTE_SCRIPT%" >>"%LOG%" 2>&1
if errorlevel 1 (
    echo ERROR: Check failed.
    start "" notepad "%LOG%"
    pause
    exit /b 1
)

echo.
echo DONE. Opening the report...
start "" notepad "%LOG%"
echo.
echo Send me a screenshot of the opened report.
pause
exit /b 0
