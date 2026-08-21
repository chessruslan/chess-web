@echo off
setlocal EnableExtensions
title MakeChess - SCHOOL DB CHECK V2

set "SERVER=flexyops@111.88.227.25"
set "KEY=%USERPROFILE%\.ssh\makechess_selectel"
set "RESULT=%~dp0CHECK_MAKECHESS_SCHOOL_DB_RESULT.txt"

> "%RESULT%" echo MAKECHESS SCHOOL DB CHECK V2
>>"%RESULT%" echo ==========================================
>>"%RESULT%" echo.

echo.
echo ============================================================
echo   MAKECHESS SCHOOL DB CHECK V2
echo   READ ONLY - DATABASE WILL NOT BE CHANGED
echo ============================================================
echo.
echo Result will be saved to:
echo %RESULT%
echo.

if not exist "%KEY%" (
  echo ERROR: SSH key not found.
  >>"%RESULT%" echo ERROR: SSH key not found: %KEY%
  pause
  exit /b 1
)

echo [1/2] Checking Selectel connection...
ssh -i "%KEY%" -o BatchMode=yes -o ConnectTimeout=10 "%SERVER%" "exit" >>"%RESULT%" 2>&1
if errorlevel 1 (
  echo ERROR: Cannot connect to Selectel.
  >>"%RESULT%" echo ERROR: Cannot connect to Selectel.
  pause
  exit /b 1
)

echo [2/2] Reading PostgreSQL schema...
echo This can take a few seconds.

ssh -i "%KEY%" -o BatchMode=yes "%SERVER%" "DB_CONTAINER=''; for c in \$(docker ps --format '{{.Names}}'); do if docker exec \"\$c\" psql --version >/dev/null 2>&1; then DB_CONTAINER=\"\$c\"; break; fi; done; if [ -z \"\$DB_CONTAINER\" ]; then echo 'DB_CONTAINER_WITH_PSQL_NOT_FOUND'; echo '===== RUNNING CONTAINERS ====='; docker ps --format 'table {{.Names}}\t{{.Image}}'; exit 21; fi; echo DB_CONTAINER=\$DB_CONTAINER; echo; echo '===== PUBLIC TABLES ====='; docker exec -i \"\$DB_CONTAINER\" psql -U postgres -d postgres -P pager=off -c \"select table_name from information_schema.tables where table_schema='public' and table_type='BASE TABLE' order by table_name;\"; echo; echo '===== SCHOOL / TEACHER / OWNER COLUMNS ====='; docker exec -i \"\$DB_CONTAINER\" psql -U postgres -d postgres -P pager=off -c \"select table_name, column_name, data_type from information_schema.columns where table_schema='public' and (lower(table_name) like '%%school%%' or lower(table_name) like '%%teacher%%' or lower(column_name) like '%%school%%' or lower(column_name) like '%%teacher%%' or lower(column_name) like '%%owner%%') order by table_name, ordinal_position;\"; echo; echo '===== PROFILES COLUMNS ====='; docker exec -i \"\$DB_CONTAINER\" psql -U postgres -d postgres -P pager=off -c \"select column_name, data_type from information_schema.columns where table_schema='public' and table_name='profiles' order by ordinal_position;\"; echo; echo '===== AUTH USER METADATA KEYS ====='; docker exec -i \"\$DB_CONTAINER\" psql -U postgres -d postgres -P pager=off -c \"select distinct key from auth.users u cross join lateral jsonb_object_keys(coalesce(u.raw_user_meta_data,'{}'::jsonb)) as key order by key;\"" >>"%RESULT%" 2>&1

if errorlevel 1 (
  echo.
  echo CHECK FINISHED WITH AN ERROR.
  echo The details were saved to:
  echo %RESULT%
  echo.
  echo SEND THAT TXT FILE TO CHATGPT.
  pause
  exit /b 1
)

echo.
echo ============================================================
echo   DONE. DATABASE WAS NOT CHANGED.
echo ============================================================
echo.
echo Result saved to:
echo %RESULT%
echo.
echo SEND FILE CHECK_MAKECHESS_SCHOOL_DB_RESULT.txt TO CHATGPT.
echo.
pause
