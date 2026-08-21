begin;

create or replace function public.control_makechess_tournament_games_v1(
  p_tournament_id text,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if p_status not in ('running', 'paused', 'finished') then
    raise exception 'Invalid tournament game status';
  end if;
  if not exists (
    select 1 from public.makechess_tournaments_v1
    where owner_id = auth.uid() and id = p_tournament_id
  ) then
    raise exception 'Tournament not found or access denied';
  end if;
  update public.makechess_tournament_games_v1
  set status = p_status, updated_at = now()
  where owner_id = auth.uid()
    and tournament_id = p_tournament_id
    and status <> 'finished';
end;
$$;

revoke all on function public.control_makechess_tournament_games_v1(text, text)
from public;
grant execute on function public.control_makechess_tournament_games_v1(text, text)
to authenticated;

commit;
