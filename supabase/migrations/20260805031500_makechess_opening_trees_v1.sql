begin;

create table if not exists public.makechess_opening_trees_v1 (
  id text primary key,
  name text not null,
  student_color text not null default 'white'
    check (student_color in ('white', 'black')),
  start_fen text not null default 'startpos',
  source_name text,
  source_license text,
  opening_json jsonb not null
    check (jsonb_typeof(opening_json) = 'object'),
  is_published boolean not null default false,
  sort_order integer not null default 0,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists makechess_opening_trees_v1_published_sort_idx
  on public.makechess_opening_trees_v1
  (is_published, sort_order, lower(name));

create or replace function public.touch_makechess_opening_trees_v1_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists makechess_opening_trees_v1_touch_updated_at
  on public.makechess_opening_trees_v1;

create trigger makechess_opening_trees_v1_touch_updated_at
before update on public.makechess_opening_trees_v1
for each row
execute function public.touch_makechess_opening_trees_v1_updated_at();

alter table public.makechess_opening_trees_v1 enable row level security;

drop policy if exists makechess_opening_trees_v1_read_published
  on public.makechess_opening_trees_v1;

create policy makechess_opening_trees_v1_read_published
on public.makechess_opening_trees_v1
for select
to anon, authenticated
using (
  is_published = true
  or created_by = auth.uid()
);

drop policy if exists makechess_opening_trees_v1_insert_own
  on public.makechess_opening_trees_v1;

create policy makechess_opening_trees_v1_insert_own
on public.makechess_opening_trees_v1
for insert
to authenticated
with check (created_by = auth.uid());

drop policy if exists makechess_opening_trees_v1_update_own
  on public.makechess_opening_trees_v1;

create policy makechess_opening_trees_v1_update_own
on public.makechess_opening_trees_v1
for update
to authenticated
using (created_by = auth.uid())
with check (created_by = auth.uid());

drop policy if exists makechess_opening_trees_v1_delete_own
  on public.makechess_opening_trees_v1;

create policy makechess_opening_trees_v1_delete_own
on public.makechess_opening_trees_v1
for delete
to authenticated
using (created_by = auth.uid());

grant select on public.makechess_opening_trees_v1 to anon, authenticated;
grant insert, update, delete on public.makechess_opening_trees_v1 to authenticated;

insert into public.makechess_opening_trees_v1 (
  id,
  name,
  student_color,
  start_fen,
  source_name,
  source_license,
  opening_json,
  is_published,
  sort_order
)
values (
  'demo_open_games_white',
  'Открытые дебюты — тестовое дерево',
  'white',
  'startpos',
  'Тестовый авторский файл',
  'CC0 / собственные линии',
  $opening_json$
{
  "id": "demo_open_games_white",
  "name": "Открытые дебюты — тестовое дерево",
  "studentColor": "white",
  "startFen": "startpos",
  "sourceName": "Тестовый авторский файл",
  "sourceLicense": "CC0 / собственные линии",
  "lines": [
    {
      "title": "Итальянская партия: основной вариант",
      "moves": [
        "e2e4",
        "e7e5",
        "g1f3",
        "b8c6",
        "f1c4",
        "g8f6",
        "d2d3",
        "f8c5",
        "c2c3",
        "d7d6"
      ]
    },
    {
      "title": "Итальянская партия: защита двух коней",
      "moves": [
        "e2e4",
        "e7e5",
        "g1f3",
        "b8c6",
        "f1c4",
        "g8f6",
        "f3g5",
        "d7d5",
        "e4d5",
        "c6a5"
      ]
    },
    {
      "title": "Испанская партия: Морфи",
      "moves": [
        "e2e4",
        "e7e5",
        "g1f3",
        "b8c6",
        "f1b5",
        "a7a6",
        "b5a4",
        "g8f6",
        "e1g1",
        "f8e7"
      ]
    },
    {
      "title": "Шотландская партия",
      "moves": [
        "e2e4",
        "e7e5",
        "g1f3",
        "b8c6",
        "d2d4",
        "e5d4",
        "f3d4",
        "g8f6",
        "b1c3",
        "f8b4"
      ]
    },
    {
      "title": "Защита Петрова",
      "moves": [
        "e2e4",
        "e7e5",
        "g1f3",
        "g8f6",
        "f3e5",
        "d7d6",
        "e5f3",
        "f6e4",
        "d2d4",
        "d6d5"
      ]
    }
  ]
}
$opening_json$::jsonb,
  true,
  10
)
on conflict (id) do update
set
  name = excluded.name,
  student_color = excluded.student_color,
  start_fen = excluded.start_fen,
  source_name = excluded.source_name,
  source_license = excluded.source_license,
  opening_json = excluded.opening_json,
  is_published = excluded.is_published,
  sort_order = excluded.sort_order,
  updated_at = now();

comment on table public.makechess_opening_trees_v1 is
  'Опубликованные JSON-деревья дебютного тренажёра MakeChess.';

commit;
