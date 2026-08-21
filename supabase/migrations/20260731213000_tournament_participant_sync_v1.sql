begin;

create or replace function public.sync_makechess_tournament_participants_v1()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  synchronized_participants jsonb;
begin
  if not (
    new.data -> 'participantIds' is distinct from
      coalesce(old.data -> 'participantIds', '[]'::jsonb)
    or new.data -> 'participantNames' is distinct from
      coalesce(old.data -> 'participantNames', '{}'::jsonb)
  ) then
    return new;
  end if;

  select coalesce(jsonb_agg(
    coalesce(
      (
        select existing_participant
        from jsonb_array_elements(
          coalesce(table_row.data -> 'participants', '[]'::jsonb)
        ) existing_participant
        where existing_participant ->> 'id' = participant_id
        limit 1
      ),
      jsonb_build_object(
        'id', participant_id,
        'name', coalesce(
          new.data -> 'participantNames' ->> participant_id,
          (
            select nullif(profile.nickname, '')
            from public.profiles profile
            where profile.id::text = participant_id
          ),
          'Участник'
        ),
        'rating', coalesce(
          (
            select profile.rating
            from public.profiles profile
            where profile.id::text = participant_id
          ),
          1200
        ),
        'school', '',
        'flag', '🏳️',
        'avatarUrl', ''
      )
    ) order by participant_order
  ), '[]'::jsonb)
  into synchronized_participants
  from public.makechess_tournament_tables_v1 table_row
  cross join lateral jsonb_array_elements_text(
    coalesce(new.data -> 'participantIds', '[]'::jsonb)
  ) with ordinality participant(participant_id, participant_order)
  where table_row.owner_id = new.owner_id
    and table_row.tournament_id = new.id;

  update public.makechess_tournament_tables_v1
  set data = jsonb_set(
        data,
        '{participants}',
        coalesce(synchronized_participants, '[]'::jsonb),
        true
      ),
      updated_at = now()
  where owner_id = new.owner_id
    and tournament_id = new.id;

  return new;
end;
$$;

drop trigger if exists makechess_tournament_participants_sync_v1
on public.makechess_tournaments_v1;
create trigger makechess_tournament_participants_sync_v1
after update of data on public.makechess_tournaments_v1
for each row
execute function public.sync_makechess_tournament_participants_v1();

create or replace function public.accept_makechess_tournament_invitation_v1(
  p_message_id text
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  invitation public.makechess_messages_v1%rowtype;
  participant_name text;
  participant_count integer;
  participant_limit integer;
begin
  select * into invitation
  from public.makechess_messages_v1
  where id = p_message_id
    and recipient_id = auth.uid()
    and category = 'tournament_invite'
    and status in ('unread', 'read')
  for update;

  if not found then
    raise exception 'Tournament invitation not found or already answered';
  end if;

  select
    jsonb_array_length(coalesce(data -> 'participantIds', '[]'::jsonb)),
    coalesce((data ->> 'maxParticipants')::integer, 128)
  into participant_count, participant_limit
  from public.makechess_tournaments_v1
  where owner_id = invitation.sender_id
    and id = invitation.tournament_id
  for update;

  if not found then
    raise exception 'Tournament not found';
  end if;
  if participant_count >= participant_limit then
    raise exception 'Tournament is full';
  end if;

  select coalesce(nullif(nickname, ''), 'Участник')
  into participant_name
  from public.profiles
  where id = auth.uid();
  participant_name := coalesce(participant_name, 'Участник');

  update public.makechess_tournaments_v1
  set data = jsonb_set(
        jsonb_set(
          data,
          '{participantIds}',
          coalesce(data -> 'participantIds', '[]'::jsonb) ||
            to_jsonb(auth.uid()::text),
          true
        ),
        '{participantNames}',
        coalesce(data -> 'participantNames', '{}'::jsonb) ||
          jsonb_build_object(auth.uid()::text, participant_name),
        true
      ),
      updated_at = now()
  where owner_id = invitation.sender_id
    and id = invitation.tournament_id
    and not ((data -> 'participantIds') ? auth.uid()::text);

  update public.makechess_messages_v1
  set status = 'accepted',
      read_at = coalesce(read_at, now()),
      responded_at = now()
  where id = p_message_id;
end;
$$;

commit;
