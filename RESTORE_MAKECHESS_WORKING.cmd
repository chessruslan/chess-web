@echo off
setlocal EnableExtensions DisableDelayedExpansion
title MakeChess Restore Working Version

set "SERVER=flexyops@111.88.227.25"
set "KEY=%USERPROFILE%\.ssh\makechess_selectel"
set "REMOTE_SCRIPT=/home/flexyops/restore_makechess_working.sh"

cd /d "%~dp0"

echo ============================================================
echo   MAKECHESS.COM - RESTORE LAST WORKING DATABASE VERSION
echo ============================================================
echo.
echo This does NOT compile or publish a new build.
echo It restores the newest server backup that contains
echo the known working Supabase anon key.
echo.

if not exist "%KEY%" (
    echo ERROR: SSH key not found:
    echo %KEY%
    pause
    exit /b 1
)

if not exist "restore_makechess_working.sh" (
    echo ERROR: restore_makechess_working.sh is missing.
    echo Put both files in the same folder.
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

echo [1/2] Uploading safe restore script...
scp -B -i "%KEY%" -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=15 -o ConnectionAttempts=1 "restore_makechess_working.sh" "%SERVER%:%REMOTE_SCRIPT%"
if errorlevel 1 (
    echo ERROR: Could not upload restore script. Website was not changed.
    pause
    exit /b 1
)

echo [2/2] Restoring working server backup...
ssh -n -i "%KEY%" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=15 -o ConnectionAttempts=1 -o ServerAliveInterval=10 -o ServerAliveCountMax=3 "%SERVER%" "chmod 700 %REMOTE_SCRIPT% && %REMOTE_SCRIPT%"
if errorlevel 1 (
    echo.
    echo ERROR: Restore failed. The script kept or restored the current site.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo   DONE: WORKING DATABASE VERSION RESTORED
echo ============================================================
echo.
echo The temporary SMOKE button may return because this is
echo the last known fully working site version.
echo.
start "" "https://makechess.com/?restore=1"
echo Open the site in an Incognito window for the first check.
echo.
pause
exit /b 0
