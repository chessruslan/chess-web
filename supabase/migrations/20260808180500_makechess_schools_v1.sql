begin;

create table if not exists public.makechess_schools_v1 (
  id text primary key,
  school_name text not null,
  about text not null default '',
  teacher_login text not null default '',
  tariff text not null default 'trial',
  owner_user_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint makechess_schools_v1_id_not_empty
    check (length(trim(id)) > 0),

  constraint makechess_schools_v1_name_not_empty
    check (length(trim(school_name)) > 0)
);

create index if not exists makechess_schools_v1_name_lower_idx
  on public.makechess_schools_v1 (lower(school_name));

create index if not exists makechess_schools_v1_owner_idx
  on public.makechess_schools_v1 (owner_user_id);

create index if not exists makechess_schools_v1_teacher_login_lower_idx
  on public.makechess_schools_v1 (lower(teacher_login));

create or replace function public.makechess_schools_v1_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists makechess_schools_v1_touch_updated_at
  on public.makechess_schools_v1;

create trigger makechess_schools_v1_touch_updated_at
before update on public.makechess_schools_v1
for each row
execute function public.makechess_schools_v1_touch_updated_at();

alter table public.makechess_schools_v1 enable row level security;

drop policy if exists makechess_schools_v1_select_catalog
  on public.makechess_schools_v1;

create policy makechess_schools_v1_select_catalog
on public.makechess_schools_v1
for select
to anon, authenticated
using (true);

drop policy if exists makechess_schools_v1_insert_owner
  on public.makechess_schools_v1;

create policy makechess_schools_v1_insert_owner
on public.makechess_schools_v1
for insert
to authenticated
with check (auth.uid() = owner_user_id);

drop policy if exists makechess_schools_v1_update_owner
  on public.makechess_schools_v1;

create policy makechess_schools_v1_update_owner
on public.makechess_schools_v1
for update
to authenticated
using (auth.uid() = owner_user_id)
with check (auth.uid() = owner_user_id);

drop policy if exists makechess_schools_v1_delete_owner
  on public.makechess_schools_v1;

create policy makechess_schools_v1_delete_owner
on public.makechess_schools_v1
for delete
to authenticated
using (auth.uid() = owner_user_id);

grant select on public.makechess_schools_v1 to anon, authenticated;
grant insert, update, delete on public.makechess_schools_v1 to authenticated;

do $$
begin
  if to_regclass('supabase_migrations.schema_migrations') is not null then
    insert into supabase_migrations.schema_migrations(version, name, statements)
    values (
      '20260808180500',
      'makechess_schools_v1',
      array['create public.makechess_schools_v1 server school directory']
    )
    on conflict (version) do nothing;
  end if;
end
$$;

commit;
