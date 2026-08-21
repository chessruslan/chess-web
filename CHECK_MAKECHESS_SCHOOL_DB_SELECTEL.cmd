@echo off
setlocal EnableExtensions
title MakeChess - CHECK SCHOOL DB ON SELECTEL

set "SERVER=flexyops@111.88.227.25"
set "KEY=%USERPROFILE%\.ssh\makechess_selectel"

echo.
echo ============================================================
echo   MAKECHESS: PROVERKA REALNOI BAZY SHKOL NA SELECTEL
echo   TOLKO CHTENIE - BAZA NE IZMENYAETSYA
echo ============================================================
echo.

if not exist "%KEY%" (
  echo OSHIBKA: ne naiden SSH-kluch:
  echo %KEY%
  echo.
  pause
  exit /b 1
)

echo [1/2] Proveryayu podklyuchenie k Selectel...
ssh -i "%KEY%" -o BatchMode=yes -o ConnectTimeout=10 "%SERVER%" "exit"
if errorlevel 1 (
  echo.
  echo OSHIBKA: net podklyucheniya k Selectel.
  echo Baza NE izmenena.
  echo.
  pause
  exit /b 1
)

echo.
echo [2/2] Chitayu skhemu PostgreSQL...
echo.

ssh -i "%KEY%" -o BatchMode=yes "%SERVER%" "set -eu; DB_CONTAINER=$(docker ps --format '{{.Names}} {{.Image}}' | awk 'tolower($0) ~ /supabase-db|supabase.*postgres|postgres.*supabase/ {print $1; exit}'); if [ -z \"$DB_CONTAINER\" ]; then DB_CONTAINER=$(docker ps --format '{{.Names}} {{.Image}}' | awk 'tolower($0) ~ /postgres/ {print $1; exit}'); fi; if [ -z \"$DB_CONTAINER\" ]; then echo DB_CONTAINER_NOT_FOUND; exit 21; fi; echo DB_CONTAINER=$DB_CONTAINER; echo; echo '===== PUBLIC TABLES ====='; docker exec -i \"$DB_CONTAINER\" psql -U postgres -d postgres -P pager=off -c \"select table_name from information_schema.tables where table_schema='public' and table_type='BASE TABLE' order by table_name;\"; echo; echo '===== SCHOOL / TEACHER COLUMNS ====='; docker exec -i \"$DB_CONTAINER\" psql -U postgres -d postgres -P pager=off -c \"select table_name, column_name, data_type from information_schema.columns where table_schema='public' and (lower(table_name) like '%%school%%' or lower(table_name) like '%%teacher%%' or lower(column_name) like '%%school%%' or lower(column_name) like '%%teacher%%' or lower(column_name) like '%%owner%%') order by table_name, ordinal_position;\"; echo; echo '===== PROFILES COLUMNS ====='; docker exec -i \"$DB_CONTAINER\" psql -U postgres -d postgres -P pager=off -c \"select column_name, data_type from information_schema.columns where table_schema='public' and table_name='profiles' order by ordinal_position;\"; echo; echo '===== AUTH USER METADATA KEYS ====='; docker exec -i \"$DB_CONTAINER\" psql -U postgres -d postgres -P pager=off -c \"select distinct key from auth.users u cross join lateral jsonb_object_keys(coalesce(u.raw_user_meta_data,'{}'::jsonb)) as key order by key;\""

echo.
echo ============================================================
echo   GOTOVO. NICHEGO V BAZE NE MENYALOS.
echo   SKOPIRUITE VES VYVOD I PRISHLITE EGO CHATGPT.
echo ============================================================
echo.
pause
