@echo off
setlocal EnableExtensions
title MakeChess - SCHOOL DB SCHEMA V4

set "SERVER=flexyops@111.88.227.25"
set "KEY=%USERPROFILE%\.ssh\makechess_selectel"
set "RESULT=%~dp0CHECK_MAKECHESS_SCHOOL_DB_SCHEMA_RESULT.txt"

echo.
echo ============================================================
echo   MAKECHESS SCHOOL DB SCHEMA V4
echo   READ ONLY - DATABASE WILL NOT BE CHANGED
echo ============================================================
echo.

if not exist "%KEY%" (
  echo ERROR: SSH key not found:
  echo %KEY%
  pause
  exit /b 1
)

echo Reading schema from PostgreSQL container supabase-db...
echo This should finish in a few seconds.
echo.

> "%RESULT%" echo MAKECHESS SCHOOL DB SCHEMA V4
>>"%RESULT%" echo ==========================================
>>"%RESULT%" echo.

ssh -i "%KEY%" -o BatchMode=yes -o ConnectTimeout=10 "%SERVER%" "echo '===== PUBLIC TABLES ====='; docker exec -i supabase-db psql -U postgres -d postgres -P pager=off -c \"select table_name from information_schema.tables where table_schema='public' and table_type='BASE TABLE' order by table_name;\"; echo; echo '===== SCHOOL / TEACHER / OWNER COLUMNS ====='; docker exec -i supabase-db psql -U postgres -d postgres -P pager=off -c \"select table_name, column_name, data_type from information_schema.columns where table_schema='public' and (lower(table_name) like '%%school%%' or lower(table_name) like '%%teacher%%' or lower(column_name) like '%%school%%' or lower(column_name) like '%%teacher%%' or lower(column_name) like '%%owner%%') order by table_name, ordinal_position;\"; echo; echo '===== PROFILES COLUMNS ====='; docker exec -i supabase-db psql -U postgres -d postgres -P pager=off -c \"select column_name, data_type from information_schema.columns where table_schema='public' and table_name='profiles' order by ordinal_position;\"; echo; echo '===== AUTH USER METADATA KEYS ====='; docker exec -i supabase-db psql -U postgres -d postgres -P pager=off -c \"select distinct key from auth.users u cross join lateral jsonb_object_keys(coalesce(u.raw_user_meta_data,'{}'::jsonb)) as key order by key;\"; echo; echo '===== COUNTS ====='; docker exec -i supabase-db psql -U postgres -d postgres -P pager=off -c \"select 'profiles' as source, count(*) as rows from public.profiles union all select 'teacher_students', count(*) from public.teacher_students;\"" >> "%RESULT%" 2>&1

if errorlevel 1 (
  echo.
  echo ERROR: Schema read failed.
  echo Result file:
  echo %RESULT%
  echo.
  echo Send that TXT file to ChatGPT.
  pause
  exit /b 1
)

echo.
echo DONE.
echo Database was NOT changed.
echo.
echo Result file:
echo %RESULT%
echo.
echo Send CHECK_MAKECHESS_SCHOOL_DB_SCHEMA_RESULT.txt to ChatGPT.
echo.
pause
