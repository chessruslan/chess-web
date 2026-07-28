-- Clean MakeChess bootstrap for the self-hosted Supabase stack on Selectel.
-- This intentionally creates a new empty application database: the expired
-- hosted Supabase project is not required.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null unique,
  rating integer not null default 1200,
  games_played integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_nickname_not_empty check (length(trim(nickname)) > 0),
  constraint profiles_games_played_nonnegative check (games_played >= 0)
);

create index if not exists profiles_nickname_lower_idx
  on public.profiles (lower(nickname));

create table if not exists public.games (
  id uuid primary key default gen_random_uuid(),
  white_id uuid references auth.users(id) on delete set null,
  black_id uuid references auth.users(id) on delete set null,
  pgn text not null default '',
  result text not null,
  rated boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists games_white_id_idx on public.games (white_id);
create index if not exists games_black_id_idx on public.games (black_id);
create index if not exists games_created_at_idx on public.games (created_at desc);

create table if not exists public.classrooms (
  id uuid primary key default gen_random_uuid(),
  school_id text not null,
  teacher_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (school_id, teacher_id)
);

create table if not exists public.active_classrooms (
  school_id text primary key,
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  teacher_id uuid not null references auth.users(id) on delete cascade,
  updated_at timestamptz not null default now()
);

create table if not exists public.classroom_signals (
  id uuid primary key default gen_random_uuid(),
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  receiver_id uuid references auth.users(id) on delete cascade,
  type text not null check (type in ('join', 'leave', 'offer', 'answer', 'candidate')),
  sdp text,
  candidate jsonb,
  created_at timestamptz not null default now()
);

create index if not exists classroom_signals_classroom_created_idx
  on public.classroom_signals (classroom_id, created_at);
create index if not exists classroom_signals_receiver_idx
  on public.classroom_signals (receiver_id, created_at);

create table if not exists public.teacher_students (
  teacher_id uuid not null references auth.users(id) on delete cascade,
  student_id uuid not null references auth.users(id) on delete cascade,
  student_nickname text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (teacher_id, student_id),
  constraint teacher_students_not_self check (teacher_id <> student_id),
  constraint teacher_students_nickname_not_empty
    check (length(trim(student_nickname)) > 0)
);

create index if not exists teacher_students_student_id_idx
  on public.teacher_students (student_id);

alter table public.profiles enable row level security;
alter table public.games enable row level security;
alter table public.classrooms enable row level security;
alter table public.active_classrooms enable row level security;
alter table public.classroom_signals enable row level security;
alter table public.teacher_students enable row level security;

drop policy if exists profiles_public_read on public.profiles;
create policy profiles_public_read on public.profiles for select
  to anon, authenticated using (true);
drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles for insert
  to authenticated with check (auth.uid() = id);
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update
  to authenticated using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists games_read_participant on public.games;
create policy games_read_participant on public.games for select
  to authenticated using (auth.uid() = white_id or auth.uid() = black_id);
drop policy if exists games_insert_participant on public.games;
create policy games_insert_participant on public.games for insert
  to authenticated with check (auth.uid() = white_id or auth.uid() = black_id);

drop policy if exists classrooms_read_authenticated on public.classrooms;
create policy classrooms_read_authenticated on public.classrooms for select
  to authenticated using (true);
drop policy if exists classrooms_insert_teacher on public.classrooms;
create policy classrooms_insert_teacher on public.classrooms for insert
  to authenticated with check (auth.uid() = teacher_id);
drop policy if exists classrooms_update_teacher on public.classrooms;
create policy classrooms_update_teacher on public.classrooms for update
  to authenticated using (auth.uid() = teacher_id) with check (auth.uid() = teacher_id);
drop policy if exists classrooms_delete_teacher on public.classrooms;
create policy classrooms_delete_teacher on public.classrooms for delete
  to authenticated using (auth.uid() = teacher_id);

drop policy if exists active_classrooms_read_authenticated on public.active_classrooms;
create policy active_classrooms_read_authenticated on public.active_classrooms for select
  to authenticated using (true);
drop policy if exists active_classrooms_write_teacher on public.active_classrooms;
create policy active_classrooms_write_teacher on public.active_classrooms for insert
  to authenticated with check (auth.uid() = teacher_id);
drop policy if exists active_classrooms_update_teacher on public.active_classrooms;
create policy active_classrooms_update_teacher on public.active_classrooms for update
  to authenticated using (auth.uid() = teacher_id) with check (auth.uid() = teacher_id);
drop policy if exists active_classrooms_delete_teacher on public.active_classrooms;
create policy active_classrooms_delete_teacher on public.active_classrooms for delete
  to authenticated using (auth.uid() = teacher_id);

drop policy if exists classroom_signals_read_participant on public.classroom_signals;
create policy classroom_signals_read_participant on public.classroom_signals for select
  to authenticated using (
    auth.uid() = sender_id or auth.uid() = receiver_id or receiver_id is null
  );
drop policy if exists classroom_signals_insert_sender on public.classroom_signals;
create policy classroom_signals_insert_sender on public.classroom_signals for insert
  to authenticated with check (auth.uid() = sender_id);
drop policy if exists classroom_signals_delete_sender on public.classroom_signals;
create policy classroom_signals_delete_sender on public.classroom_signals for delete
  to authenticated using (auth.uid() = sender_id);

drop policy if exists teacher_students_select_own on public.teacher_students;
create policy teacher_students_select_own on public.teacher_students for select
  to authenticated using (auth.uid() = teacher_id);
drop policy if exists teacher_students_insert_own on public.teacher_students;
create policy teacher_students_insert_own on public.teacher_students for insert
  to authenticated with check (auth.uid() = teacher_id);
drop policy if exists teacher_students_update_own on public.teacher_students;
create policy teacher_students_update_own on public.teacher_students for update
  to authenticated using (auth.uid() = teacher_id) with check (auth.uid() = teacher_id);
drop policy if exists teacher_students_delete_own on public.teacher_students;
create policy teacher_students_delete_own on public.teacher_students for delete
  to authenticated using (auth.uid() = teacher_id);

grant select on public.profiles to anon, authenticated;
grant insert, update on public.profiles to authenticated;
grant select, insert on public.games to authenticated;
grant select, insert, update, delete on public.classrooms to authenticated;
grant select, insert, update, delete on public.active_classrooms to authenticated;
grant select, insert, delete on public.classroom_signals to authenticated;
grant select, insert, update, delete on public.teacher_students to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'classroom_signals'
  ) then
    alter publication supabase_realtime add table public.classroom_signals;
  end if;
end
$$;

notify pgrst, 'reload schema';
