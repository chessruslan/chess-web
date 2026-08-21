@echo off
setlocal EnableExtensions
title MakeChess Messages DB - Selectel

set "PROJECT=C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
set "SQL=%PROJECT%\supabase\migrations\20260731134500_makechess_messages_v1.sql"
set "SERVER=flexyops@111.88.227.25"
set "KEY=%USERPROFILE%\.ssh\makechess_selectel"
set "REMOTE_SQL=/tmp/20260731134500_makechess_messages_v1.sql"

echo.
echo ============================================================
echo   MAKECHESS: SOZDANIE TABLITSY SOOBSHENII NA SELECTEL
echo ============================================================
echo.

if not exist "%KEY%" (
  echo OSHIBKA: ne naiden SSH-kluch:
  echo %KEY%
  echo.
  pause
  exit /b 1
)

if not exist "%SQL%" (
  echo OSHIBKA: ne naiden SQL-fail:
  echo %SQL%
  echo.
  pause
  exit /b 1
)

echo [1/4] Proveryayu podklyuchenie k Selectel...
ssh -i "%KEY%" -o BatchMode=yes -o ConnectTimeout=10 "%SERVER%" "exit"
if errorlevel 1 (
  echo.
  echo OSHIBKA: net podklyucheniya k Selectel.
  echo Baza i sait ne izmeneny.
  echo.
  pause
  exit /b 1
)

echo.
echo [2/4] Peredayu migratsiyu na Selectel...
scp -i "%KEY%" -o BatchMode=yes "%SQL%" "%SERVER%:%REMOTE_SQL%"
if errorlevel 1 (
  echo.
  echo OSHIBKA PEREDACHI SQL. Baza ne izmenena.
  echo.
  pause
  exit /b 1
)

echo.
echo [3/4] Primenyayu migratsiyu v lokalnoi baze Selectel...
ssh -i "%KEY%" -o BatchMode=yes "%SERVER%" "set -eu; DB_CONTAINER=$(docker ps --format '{.Names} {.Image}' | awk 'tolower($0) ~ /supabase-db|supabase.*postgres|postgres.*supabase/ {print $1; exit}'); if [ -z \"$DB_CONTAINER\" ]; then DB_CONTAINER=$(docker ps --format '{.Names} {.Image}' | awk 'tolower($0) ~ /postgres/ {print $1; exit}'); fi; if [ -z \"$DB_CONTAINER\" ]; then echo DB_CONTAINER_NOT_FOUND; exit 21; fi; echo DB_CONTAINER=$DB_CONTAINER; docker exec -i \"$DB_CONTAINER\" psql -U postgres -d postgres -v ON_ERROR_STOP=1 < %REMOTE_SQL%; rm -f %REMOTE_SQL%"
if errorlevel 1 (
  echo.
  echo OSHIBKA: migratsiya ne primenena polnostyu.
  echo Pokazhite etot ekran ChatGPT.
  echo.
  pause
  exit /b 1
)

echo.
echo [4/4] Proveryayu rezultat...
ssh -i "%KEY%" -o BatchMode=yes "%SERVER%" "set -eu; DB_CONTAINER=$(docker ps --format '{.Names} {.Image}' | awk 'tolower($0) ~ /supabase-db|supabase.*postgres|postgres.*supabase/ {print $1; exit}'); if [ -z \"$DB_CONTAINER\" ]; then DB_CONTAINER=$(docker ps --format '{.Names} {.Image}' | awk 'tolower($0) ~ /postgres/ {print $1; exit}'); fi; docker exec \"$DB_CONTAINER\" psql -U postgres -d postgres -Atc \"select case when to_regclass('public.makechess_messages_v1') is not null then 'MAKECHESS_MESSAGES_DB_OK' else 'MAKECHESS_MESSAGES_DB_MISSING' end;\""
if errorlevel 1 (
  echo.
  echo OSHIBKA PROVERKI.
  echo.
  pause
  exit /b 1
)

echo.
echo ============================================================
echo   GOTOVO: MAKECHESS_MESSAGES_DB_OK
echo ============================================================
echo.
echo Sait ne publikovalsya.
echo PUBLISH_MAKECHESS.cmd ne izmenyalsya.
echo.
pause
exit /b 0
