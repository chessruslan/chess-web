begin;

create table if not exists public.makechess_tournament_games_v1 (
  owner_id uuid not null references auth.users(id) on delete cascade,
  tournament_id text not null,
  board integer not null,
  white_id uuid not null references auth.users(id) on delete cascade,
  black_id uuid not null references auth.users(id) on delete cascade,
  fen text not null default 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  turn text not null default 'w' check (turn in ('w', 'b')),
  moves jsonb not null default '[]'::jsonb,
  status text not null default 'running'
    check (status in ('waiting', 'running', 'paused', 'finished')),
  result text not null default '*',
  version bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, tournament_id, board),
  foreign key (owner_id, tournament_id)
    references public.makechess_tournaments_v1(owner_id, id) on delete cascade
);

alter table public.makechess_tournament_games_v1 enable row level security;

drop policy if exists makechess_tournament_games_v1_select
  on public.makechess_tournament_games_v1;
create policy makechess_tournament_games_v1_select
on public.makechess_tournament_games_v1
for select to authenticated
using (auth.uid() in (owner_id, white_id, black_id));

grant select on public.makechess_tournament_games_v1 to authenticated;

create or replace function public.start_makechess_tournament_games_v1(
  p_tournament_id text
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  pairing jsonb;
begin
  if not exists (
    select 1 from public.makechess_tournaments_v1
    where owner_id = auth.uid() and id = p_tournament_id
  ) then
    raise exception 'Tournament not found or access denied';
  end if;

  for pairing in
    select value from jsonb_array_elements(coalesce((
      select data -> 'pairings' from public.makechess_tournaments_v1
      where owner_id = auth.uid() and id = p_tournament_id
    ), '[]'::jsonb))
  loop
    if nullif(pairing ->> 'blackId', '') is not null then
      insert into public.makechess_tournament_games_v1 (
        owner_id, tournament_id, board, white_id, black_id, status
      ) values (
        auth.uid(), p_tournament_id,
        coalesce((pairing ->> 'board')::integer, 1),
        (pairing ->> 'whiteId')::uuid,
        (pairing ->> 'blackId')::uuid,
        'running'
      )
      on conflict (owner_id, tournament_id, board) do update
      set status = case
            when makechess_tournament_games_v1.status = 'finished'
              then makechess_tournament_games_v1.status
            else 'running'
          end,
          updated_at = now();
    end if;
  end loop;
end;
$$;

create or replace function public.move_makechess_tournament_game_v1(
  p_owner_id uuid,
  p_tournament_id text,
  p_board integer,
  p_from text,
  p_to text,
  p_promotion text,
  p_fen text,
  p_expected_version bigint
)
returns bigint
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  game public.makechess_tournament_games_v1%rowtype;
  next_version bigint;
begin
  select * into game
  from public.makechess_tournament_games_v1
  where owner_id = p_owner_id
    and tournament_id = p_tournament_id
    and board = p_board
  for update;

  if not found or game.status <> 'running' then
    raise exception 'Game is not running';
  end if;
  if game.version <> p_expected_version then
    raise exception 'Game position changed';
  end if;
  if (game.turn = 'w' and auth.uid() <> game.white_id)
     or (game.turn = 'b' and auth.uid() <> game.black_id) then
    raise exception 'Not your turn';
  end if;

  next_version := game.version + 1;
  update public.makechess_tournament_games_v1
  set fen = p_fen,
      turn = case game.turn when 'w' then 'b' else 'w' end,
      moves = game.moves || jsonb_build_object(
        'from', p_from, 'to', p_to, 'promotion', p_promotion,
        'by', auth.uid()::text, 'at', now()
      ),
      version = next_version,
      updated_at = now()
  where owner_id = p_owner_id
    and tournament_id = p_tournament_id
    and board = p_board;
  return next_version;
end;
$$;

revoke all on function public.start_makechess_tournament_games_v1(text)
from public;
grant execute on function public.start_makechess_tournament_games_v1(text)
to authenticated;
revoke all on function public.move_makechess_tournament_game_v1(
  uuid, text, integer, text, text, text, text, bigint
) from public;
grant execute on function public.move_makechess_tournament_game_v1(
  uuid, text, integer, text, text, text, text, bigint
) to authenticated;

commit;
