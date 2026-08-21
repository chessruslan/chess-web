-- Isolated OAuth storage for the Lichess Board API.
-- Existing MakeChess tables are intentionally not modified.
create table if not exists public.lichess_connections (
  user_id uuid primary key references auth.users(id) on delete cascade,
  lichess_user_id text not null,
  lichess_username text not null,
  access_token text not null,
  scopes text not null default 'board:play',
  connected_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.lichess_oauth_states (
  state text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  code_verifier text not null,
  return_url text not null,
  created_at timestamptz not null default now()
);

alter table public.lichess_connections enable row level security;
alter table public.lichess_oauth_states enable row level security;

-- Tokens are server-only. The Edge Function uses the service-role key.
revoke all on public.lichess_connections from anon, authenticated;
revoke all on public.lichess_oauth_states from anon, authenticated;

create index if not exists lichess_oauth_states_created_at_idx
  on public.lichess_oauth_states (created_at);

