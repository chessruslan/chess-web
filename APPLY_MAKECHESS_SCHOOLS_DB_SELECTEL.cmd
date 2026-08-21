@echo off
setlocal EnableExtensions
title MakeChess - APPLY SCHOOLS DB TO SELECTEL

set "PROJECT=C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
set "SQL=%PROJECT%\supabase\migrations\20260808180500_makechess_schools_v1.sql"
set "SERVER=flexyops@111.88.227.25"
set "KEY=%USERPROFILE%\.ssh\makechess_selectel"
set "REMOTE_SQL=/tmp/20260808180500_makechess_schools_v1.sql"
set "RESULT=%PROJECT%\APPLY_MAKECHESS_SCHOOLS_DB_SELECTEL_RESULT.txt"

> "%RESULT%" echo MAKECHESS SCHOOLS DB APPLY
>>"%RESULT%" echo ==========================================
>>"%RESULT%" echo.

echo.
echo ============================================================
echo   MAKECHESS: CREATE SERVER SCHOOL DIRECTORY ON SELECTEL
echo ============================================================
echo.

if not exist "%KEY%" (
  echo ERROR: SSH key not found:
  echo %KEY%
  >>"%RESULT%" echo ERROR: SSH key not found: %KEY%
  pause
  exit /b 1
)

if not exist "%SQL%" (
  echo ERROR: SQL migration not found:
  echo %SQL%
  >>"%RESULT%" echo ERROR: SQL migration not found: %SQL%
  pause
  exit /b 1
)

echo [1/4] Checking Selectel connection...
ssh -i "%KEY%" -o BatchMode=yes -o ConnectTimeout=10 "%SERVER%" "exit" >>"%RESULT%" 2>&1
if errorlevel 1 (
  echo ERROR: Cannot connect to Selectel.
  >>"%RESULT%" echo ERROR: Cannot connect to Selectel.
  pause
  exit /b 1
)

echo [2/4] Uploading SQL migration...
scp -i "%KEY%" -o BatchMode=yes "%SQL%" "%SERVER%:%REMOTE_SQL%" >>"%RESULT%" 2>&1
if errorlevel 1 (
  echo ERROR: Cannot upload SQL migration.
  >>"%RESULT%" echo ERROR: Cannot upload SQL migration.
  pause
  exit /b 1
)

echo [3/4] Applying migration to PostgreSQL...
ssh -i "%KEY%" -o BatchMode=yes "%SERVER%" "set -e; docker exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 < %REMOTE_SQL%; rm -f %REMOTE_SQL%" >>"%RESULT%" 2>&1
if errorlevel 1 (
  echo.
  echo ERROR: Migration failed.
  echo Existing data was not intentionally deleted.
  echo Send this file to ChatGPT:
  echo %RESULT%
  echo.
  pause
  exit /b 1
)

echo [4/4] Verifying table and policies...
ssh -i "%KEY%" -o BatchMode=yes "%SERVER%" "echo '===== TABLE ====='; docker exec -i supabase-db psql -U postgres -d postgres -P pager=off -c \"select column_name, data_type, is_nullable from information_schema.columns where table_schema='public' and table_name='makechess_schools_v1' order by ordinal_position;\"; echo '===== POLICIES ====='; docker exec -i supabase-db psql -U postgres -d postgres -P pager=off -c \"select policyname, cmd, roles from pg_policies where schemaname='public' and tablename='makechess_schools_v1' order by policyname;\"; echo '===== ROW COUNT ====='; docker exec -i supabase-db psql -U postgres -d postgres -P pager=off -c \"select count(*) as school_rows from public.makechess_schools_v1;\"" >>"%RESULT%" 2>&1
if errorlevel 1 (
  echo.
  echo WARNING: Migration applied, but verification failed.
  echo Send this file to ChatGPT:
  echo %RESULT%
  echo.
  pause
  exit /b 1
)

echo.
echo ============================================================
echo   DONE. SERVER SCHOOL TABLE WAS CREATED / VERIFIED.
echo ============================================================
echo.
echo Result file:
echo %RESULT%
echo.
echo Send APPLY_MAKECHESS_SCHOOLS_DB_SELECTEL_RESULT.txt to ChatGPT.
echo.
pause
