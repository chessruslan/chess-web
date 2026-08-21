begin;

alter table public.makechess_tournament_games_v1
  add column if not exists white_ms bigint not null default 300000,
  add column if not exists black_ms bigint not null default 300000,
  add column if not exists increment_ms integer not null default 0,
  add column if not exists active_since timestamptz,
  add column if not exists draw_offered_by uuid references auth.users(id),
  add column if not exists finished_reason text not null default '';

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
  tournament_data jsonb;
  initial_ms bigint;
  increment_value integer;
begin
  select data into tournament_data
  from public.makechess_tournaments_v1
  where owner_id = auth.uid() and id = p_tournament_id;
  if not found then raise exception 'Tournament not found or access denied'; end if;

  initial_ms := greatest(coalesce((tournament_data ->> 'minutes')::integer, 5), 1) * 60000;
  increment_value := greatest(coalesce((tournament_data ->> 'increment')::integer, 0), 0) * 1000;

  for pairing in
    select value from jsonb_array_elements(coalesce(tournament_data -> 'pairings', '[]'::jsonb))
  loop
    if nullif(pairing ->> 'blackId', '') is not null then
      insert into public.makechess_tournament_games_v1 (
        owner_id, tournament_id, board, white_id, black_id, status,
        white_ms, black_ms, increment_ms, active_since
      ) values (
        auth.uid(), p_tournament_id,
        coalesce((pairing ->> 'board')::integer, 1),
        (pairing ->> 'whiteId')::uuid,
        (pairing ->> 'blackId')::uuid,
        'running', initial_ms, initial_ms, increment_value, now()
      )
      on conflict (owner_id, tournament_id, board) do update
      set status = case when makechess_tournament_games_v1.status = 'finished'
                        then 'finished' else 'running' end,
          active_since = case when makechess_tournament_games_v1.status = 'finished'
                              then makechess_tournament_games_v1.active_since else now() end,
          updated_at = now();
    end if;
  end loop;
end;
$$;

create or replace function public.move_makechess_tournament_game_v1(
  p_owner_id uuid, p_tournament_id text, p_board integer,
  p_from text, p_to text, p_promotion text, p_fen text,
  p_expected_version bigint
)
returns bigint
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  game public.makechess_tournament_games_v1%rowtype;
  elapsed_ms bigint;
  remaining_ms bigint;
  next_version bigint;
begin
  select * into game from public.makechess_tournament_games_v1
  where owner_id = p_owner_id and tournament_id = p_tournament_id and board = p_board
  for update;
  if not found or game.status <> 'running' then raise exception 'Game is not running'; end if;
  if game.version <> p_expected_version then raise exception 'Game position changed'; end if;
  if (game.turn = 'w' and auth.uid() <> game.white_id)
     or (game.turn = 'b' and auth.uid() <> game.black_id) then
    raise exception 'Not your turn';
  end if;

  elapsed_ms := greatest((extract(epoch from (now() - coalesce(game.active_since, now()))) * 1000)::bigint, 0);
  remaining_ms := (case game.turn when 'w' then game.white_ms else game.black_ms end) - elapsed_ms;
  if remaining_ms <= 0 then
    update public.makechess_tournament_games_v1
    set status='finished', result=case game.turn when 'w' then '0-1' else '1-0' end,
        finished_reason='time', active_since=null, updated_at=now()
    where owner_id=p_owner_id and tournament_id=p_tournament_id and board=p_board;
    raise exception 'Time expired';
  end if;

  next_version := game.version + 1;
  update public.makechess_tournament_games_v1
  set fen=p_fen,
      turn=case game.turn when 'w' then 'b' else 'w' end,
      white_ms=case game.turn when 'w' then remaining_ms + game.increment_ms else game.white_ms end,
      black_ms=case game.turn when 'b' then remaining_ms + game.increment_ms else game.black_ms end,
      moves=game.moves || jsonb_build_object(
        'from',p_from,'to',p_to,'promotion',p_promotion,'by',auth.uid()::text,'at',now()),
      version=next_version, active_since=now(), draw_offered_by=null, updated_at=now()
  where owner_id=p_owner_id and tournament_id=p_tournament_id and board=p_board;
  return next_version;
end;
$$;

create or replace function public.finish_makechess_tournament_game_v1(
  p_owner_id uuid, p_tournament_id text, p_board integer,
  p_result text, p_reason text
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare game public.makechess_tournament_games_v1%rowtype;
begin
  select * into game from public.makechess_tournament_games_v1
  where owner_id=p_owner_id and tournament_id=p_tournament_id and board=p_board for update;
  if not found or auth.uid() not in (game.owner_id,game.white_id,game.black_id) then
    raise exception 'Game not found or access denied';
  end if;
  if p_result not in ('1-0','0-1','1/2-1/2') then raise exception 'Invalid result'; end if;
  update public.makechess_tournament_games_v1
  set status='finished', result=p_result, finished_reason=p_reason,
      active_since=null, draw_offered_by=null, updated_at=now()
  where owner_id=p_owner_id and tournament_id=p_tournament_id and board=p_board;

  update public.makechess_tournaments_v1 t
  set data=jsonb_set(
        t.data, '{pairings}',
        coalesce((select jsonb_agg(
          case when coalesce((p->>'board')::integer,1)=p_board
               then p || jsonb_build_object('result',p_result,'resultReason',p_reason)
               else p end order by ord)
        from jsonb_array_elements(coalesce(t.data->'pairings','[]'::jsonb))
             with ordinality x(p,ord)), '[]'::jsonb), true),
      updated_at=now()
  where t.owner_id=p_owner_id and t.id=p_tournament_id;
end;
$$;

create or replace function public.offer_makechess_tournament_draw_v1(
  p_owner_id uuid, p_tournament_id text, p_board integer
)
returns text
language plpgsql
security definer
set search_path = public, auth
as $$
declare game public.makechess_tournament_games_v1%rowtype;
begin
  select * into game from public.makechess_tournament_games_v1
  where owner_id=p_owner_id and tournament_id=p_tournament_id and board=p_board for update;
  if not found or auth.uid() not in (game.white_id,game.black_id) then raise exception 'Access denied'; end if;
  if game.draw_offered_by is not null and game.draw_offered_by <> auth.uid() then
    perform public.finish_makechess_tournament_game_v1(
      p_owner_id,p_tournament_id,p_board,'1/2-1/2','draw_agreement');
    return 'accepted';
  end if;
  update public.makechess_tournament_games_v1 set draw_offered_by=auth.uid(),updated_at=now()
  where owner_id=p_owner_id and tournament_id=p_tournament_id and board=p_board;
  return 'offered';
end;
$$;

grant execute on function public.finish_makechess_tournament_game_v1(uuid,text,integer,text,text) to authenticated;
grant execute on function public.offer_makechess_tournament_draw_v1(uuid,text,integer) to authenticated;

commit;
