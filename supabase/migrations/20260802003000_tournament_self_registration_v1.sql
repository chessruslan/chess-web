begin;

create or replace function public.request_makechess_tournament_participation_v1(
  p_owner_id uuid,
  p_tournament_id text
)
returns text
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  tournament_row public.makechess_tournaments_v1%rowtype;
  participant_name text;
  participant_count integer;
  participant_limit integer;
  restricted boolean;
  request_id text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if auth.uid() = p_owner_id then return 'owner'; end if;

  select * into tournament_row
  from public.makechess_tournaments_v1
  where owner_id = p_owner_id and id = p_tournament_id
  for update;
  if not found then raise exception 'Tournament not found'; end if;

  if coalesce(tournament_row.data -> 'participantIds', '[]'::jsonb) ? auth.uid()::text then
    return 'joined';
  end if;
  participant_count := jsonb_array_length(coalesce(tournament_row.data -> 'participantIds', '[]'::jsonb));
  participant_limit := coalesce((tournament_row.data ->> 'maxParticipants')::integer, 128);
  if participant_count >= participant_limit then raise exception 'Tournament is full'; end if;

  restricted := coalesce((tournament_row.data ->> 'requiresApproval')::boolean, false)
    or coalesce((tournament_row.data ->> 'participationFilterEnabled')::boolean, false)
    or (jsonb_typeof(tournament_row.data -> 'participationFilters') = 'object'
        and tournament_row.data -> 'participationFilters' <> '{}'::jsonb)
    or exists (
      select 1 from public.makechess_tournament_tables_v1 table_row
      where table_row.owner_id = p_owner_id
        and table_row.tournament_id = p_tournament_id
        and (
          (jsonb_typeof(table_row.data -> 'participationFilters') = 'object'
            and table_row.data -> 'participationFilters' <> '{}'::jsonb)
          or nullif(table_row.data ->> 'minRating', '') is not null
          or nullif(table_row.data ->> 'maxRating', '') is not null
          or coalesce(nullif(table_row.data ->> 'age', ''), 'Открытая категория')
             <> 'Открытая категория'
        )
    );

  select coalesce(nullif(nickname, ''), auth.uid()::text)
    into participant_name from public.profiles where id = auth.uid();
  participant_name := coalesce(participant_name, auth.uid()::text);

  if not restricted then
    update public.makechess_tournaments_v1
    set data = jsonb_set(
          jsonb_set(data, '{participantIds}',
            coalesce(data -> 'participantIds', '[]'::jsonb) || to_jsonb(auth.uid()::text), true),
          '{participantNames}',
          coalesce(data -> 'participantNames', '{}'::jsonb) ||
            jsonb_build_object(auth.uid()::text, participant_name), true),
        updated_at = now()
    where owner_id = p_owner_id and id = p_tournament_id;
    return 'joined';
  end if;

  request_id := 'tournament_request_' || p_tournament_id || '_' || auth.uid()::text;
  insert into public.makechess_messages_v1(
    id, recipient_id, sender_id, sender_name, category, title, body,
    tournament_id, status, payload, created_at
  ) values (
    request_id, p_owner_id, auth.uid(), participant_name,
    'tournament_join_request',
    'Запрос на участие в турнире «' || coalesce(tournament_row.data ->> 'name', 'Турнир') || '»',
    participant_name || ' просит допустить его к участию в турнире.',
    p_tournament_id, 'unread',
    jsonb_build_object('applicantId', auth.uid()::text, 'ownerId', p_owner_id::text), now()
  ) on conflict (id) do update set status = 'unread', created_at = now(), read_at = null;
  return 'requested';
end;
$$;

revoke all on function public.request_makechess_tournament_participation_v1(uuid, text) from public;
grant execute on function public.request_makechess_tournament_participation_v1(uuid, text) to authenticated;

commit;
