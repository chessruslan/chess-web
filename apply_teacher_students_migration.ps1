$ErrorActionPreference = 'Stop'

$projectRoot = (Get-Location).Path
$migrationsDir = Join-Path $projectRoot 'supabase\migrations'
$migrationFile = Join-Path $migrationsDir '20260627135000_create_teacher_students.sql'

New-Item -ItemType Directory -Force -Path $migrationsDir | Out-Null

$sql = @'
create table if not exists public.teacher_students (
  teacher_id uuid not null,
  student_id uuid not null,
  student_nickname text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint teacher_students_pkey primary key (teacher_id, student_id),
  constraint teacher_students_not_self check (teacher_id <> student_id),
  constraint teacher_students_nickname_not_empty
    check (length(trim(student_nickname)) > 0)
);

create index if not exists teacher_students_student_id_idx
  on public.teacher_students (student_id);

alter table public.teacher_students enable row level security;

drop policy if exists teacher_students_select_own
  on public.teacher_students;
create policy teacher_students_select_own
  on public.teacher_students
  for select
  to authenticated
  using (auth.uid() = teacher_id);

drop policy if exists teacher_students_insert_own
  on public.teacher_students;
create policy teacher_students_insert_own
  on public.teacher_students
  for insert
  to authenticated
  with check (auth.uid() = teacher_id and student_id <> teacher_id);

drop policy if exists teacher_students_update_own
  on public.teacher_students;
create policy teacher_students_update_own
  on public.teacher_students
  for update
  to authenticated
  using (auth.uid() = teacher_id)
  with check (auth.uid() = teacher_id and student_id <> teacher_id);

drop policy if exists teacher_students_delete_own
  on public.teacher_students;
create policy teacher_students_delete_own
  on public.teacher_students
  for delete
  to authenticated
  using (auth.uid() = teacher_id);

grant select, insert, update, delete
  on public.teacher_students
  to authenticated;

comment on table public.teacher_students is
  'Постоянный список учеников, добавленных конкретным учителем.';
'@

Set-Content -Path $migrationFile -Value $sql -Encoding UTF8
Write-Host "Создана миграция: $migrationFile" -ForegroundColor Cyan
Write-Host "Применяю миграцию к связанному проекту Supabase..." -ForegroundColor Cyan

supabase db push
if ($LASTEXITCODE -ne 0) {
  throw "supabase db push завершился с кодом $LASTEXITCODE"
}

Write-Host "ГОТОВО: таблица teacher_students создана." -ForegroundColor Green
