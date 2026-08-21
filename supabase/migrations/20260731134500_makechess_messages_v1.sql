begin;

create table if not exists public.makechess_messages_v1 (
  id text primary key,
  recipient_id uuid not null,
  sender_id uuid not null,
  sender_name text not null default 'MakeChess',
  category text not null default 'system',
  title text not null,
  body text not null default '',
  tournament_id text,
  status text not null default 'unread'
    check (status in (
      'unread',
      'read',
      'accepted',
      'declined',
      'cancelled'
    )),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  responded_at timestamptz
);

create index if not exists makechess_messages_v1_recipient_created_idx
  on public.makechess_messages_v1 (recipient_id, created_at desc);

create index if not exists makechess_messages_v1_sender_created_idx
  on public.makechess_messages_v1 (sender_id, created_at desc);

create index if not exists makechess_messages_v1_tournament_idx
  on public.makechess_messages_v1 (tournament_id)
  where tournament_id is not null;

alter table public.makechess_messages_v1 enable row level security;

drop policy if exists makechess_messages_v1_select_own on public.makechess_messages_v1;
create policy makechess_messages_v1_select_own
on public.makechess_messages_v1
for select
to authenticated
using (
  auth.uid() = recipient_id
  or auth.uid() = sender_id
);

drop policy if exists makechess_messages_v1_insert_sender on public.makechess_messages_v1;
create policy makechess_messages_v1_insert_sender
on public.makechess_messages_v1
for insert
to authenticated
with check (
  auth.uid() = sender_id
);

drop policy if exists makechess_messages_v1_update_recipient on public.makechess_messages_v1;
create policy makechess_messages_v1_update_recipient
on public.makechess_messages_v1
for update
to authenticated
using (
  auth.uid() = recipient_id
  or auth.uid() = sender_id
)
with check (
  auth.uid() = recipient_id
  or auth.uid() = sender_id
);

drop policy if exists makechess_messages_v1_delete_own on public.makechess_messages_v1;
create policy makechess_messages_v1_delete_own
on public.makechess_messages_v1
for delete
to authenticated
using (
  auth.uid() = recipient_id
  or auth.uid() = sender_id
);

grant select, insert, update, delete
on public.makechess_messages_v1
to authenticated;

do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'makechess_messages_v1'
  ) then
    alter publication supabase_realtime
      add table public.makechess_messages_v1;
  end if;
end
$$;

commit;
