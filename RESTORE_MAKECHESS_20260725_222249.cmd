@echo off
setlocal EnableExtensions DisableDelayedExpansion
title MakeChess - restore exact working version

set "SERVER=flexyops@111.88.227.25"
set "KEY=%USERPROFILE%\.ssh\makechess_selectel"
set "REMOTE_SCRIPT=/home/flexyops/restore_makechess_20260725_222249.sh"
set "LOG=%~dp0RESTORE_MAKECHESS_20260725_222249_LOG.txt"

cd /d "%~dp0"

> "%LOG%" echo MakeChess exact restore log
>>"%LOG%" echo Started: %date% %time%
>>"%LOG%" echo User: flexyops
>>"%LOG%" echo Archive: /home/flexyops/makechess_backups/makechess_20260725_222249.tar.gz
>>"%LOG%" echo.

echo ============================================================
echo   MAKECHESS.COM - RESTORE EXACT WORKING VERSION
echo ============================================================
echo.
echo Restoring:
echo /home/flexyops/makechess_backups/makechess_20260725_222249.tar.gz
echo.
echo No compilation. No new publication.
echo Current broken site will be backed up first.
echo.

if not exist "%KEY%" (
    echo ERROR: SSH key not found:
    echo %KEY%
    pause
    exit /b 1
)

if not exist "restore_makechess_20260725_222249.sh" (
    echo ERROR: restore_makechess_20260725_222249.sh is missing.
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

echo [1/2] Uploading exact restore script...
scp -B -i "%KEY%" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -o ConnectionAttempts=1 "restore_makechess_20260725_222249.sh" "%SERVER%:%REMOTE_SCRIPT%" >>"%LOG%" 2>&1
if errorlevel 1 (
    echo ERROR: Could not upload restore script.
    echo Website was not changed.
    start "" notepad "%LOG%"
    pause
    exit /b 1
)

echo [2/2] Restoring exact archive...
ssh -n -i "%KEY%" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -o ConnectionAttempts=1 -o ServerAliveInterval=10 -o ServerAliveCountMax=3 "%SERVER%" "chmod 700 %REMOTE_SCRIPT% && %REMOTE_SCRIPT%" >>"%LOG%" 2>&1
if errorlevel 1 (
    echo.
    echo ERROR: Restore failed.
    echo The current site was kept or restored.
    start "" notepad "%LOG%"
    pause
    exit /b 1
)

echo.
echo ============================================================
echo   DONE: EXACT WORKING VERSION RESTORED
echo ============================================================
echo.
start "" "https://makechess.com/?restored=20260725_222249"
echo Opened makechess.com.
echo First check: use an Incognito window or press Ctrl+F5.
echo.
pause
exit /b 0
