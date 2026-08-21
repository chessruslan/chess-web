begin;

drop policy if exists makechess_tournaments_v1_public_active_select
  on public.makechess_tournaments_v1;
create policy makechess_tournaments_v1_public_active_select
on public.makechess_tournaments_v1
for select to authenticated
using (
  coalesce((data ->> 'isTemplate')::boolean, false) = false
  and data ->> 'status' in ('ready', 'running', 'paused')
);

commit;
