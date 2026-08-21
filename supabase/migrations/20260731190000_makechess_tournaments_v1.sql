begin;

create table if not exists public.makechess_tournaments_v1 (
  owner_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);

create index if not exists makechess_tournaments_v1_updated_idx
  on public.makechess_tournaments_v1 (owner_id, updated_at desc);

create table if not exists public.makechess_tournament_tables_v1 (
  owner_id uuid not null,
  tournament_id text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, tournament_id),
  foreign key (owner_id, tournament_id)
    references public.makechess_tournaments_v1(owner_id, id)
    on delete cascade
);

alter table public.makechess_tournaments_v1 enable row level security;
alter table public.makechess_tournament_tables_v1 enable row level security;

drop policy if exists makechess_tournaments_v1_owner_all
  on public.makechess_tournaments_v1;
create policy makechess_tournaments_v1_owner_all
on public.makechess_tournaments_v1
for all to authenticated
using (auth.uid() = owner_id)
with check (auth.uid() = owner_id);

drop policy if exists makechess_tournaments_v1_participant_select
  on public.makechess_tournaments_v1;
create policy makechess_tournaments_v1_participant_select
on public.makechess_tournaments_v1
for select to authenticated
using ((data -> 'participantIds') ? auth.uid()::text);

drop policy if exists makechess_tournament_tables_v1_owner_all
  on public.makechess_tournament_tables_v1;
create policy makechess_tournament_tables_v1_owner_all
on public.makechess_tournament_tables_v1
for all to authenticated
using (auth.uid() = owner_id)
with check (auth.uid() = owner_id);

drop policy if exists makechess_tournament_tables_v1_participant_select
  on public.makechess_tournament_tables_v1;
create policy makechess_tournament_tables_v1_participant_select
on public.makechess_tournament_tables_v1
for select to authenticated
using (
  exists (
    select 1
    from public.makechess_tournaments_v1 tournament
    where tournament.owner_id = makechess_tournament_tables_v1.owner_id
      and tournament.id = makechess_tournament_tables_v1.tournament_id
      and (tournament.data -> 'participantIds') ? auth.uid()::text
  )
);

grant select, insert, update, delete
on public.makechess_tournaments_v1, public.makechess_tournament_tables_v1
to authenticated;

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

  if not found then
    if not exists (
      select 1 from public.makechess_tournaments_v1
      where owner_id = invitation.sender_id
        and id = invitation.tournament_id
        and (data -> 'participantIds') ? auth.uid()::text
    ) then
      raise exception 'Tournament not found';
    end if;
  end if;

  update public.makechess_messages_v1
  set status = 'accepted',
      read_at = coalesce(read_at, now()),
      responded_at = now()
  where id = p_message_id;
end;
$$;

revoke all on function public.accept_makechess_tournament_invitation_v1(text)
from public;
grant execute on function public.accept_makechess_tournament_invitation_v1(text)
to authenticated;

commit;
