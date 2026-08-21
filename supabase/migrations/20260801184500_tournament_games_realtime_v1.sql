begin;

do $$
begin
  alter publication supabase_realtime
    add table public.makechess_tournament_games_v1;
exception
  when duplicate_object then null;
end;
$$;

commit;
