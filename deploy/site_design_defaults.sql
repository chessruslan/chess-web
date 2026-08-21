begin;

create table if not exists public.site_design_defaults (
  id smallint primary key default 1 check (id = 1),
  settings jsonb not null default '{}'::jsonb,
  background_base64 text,
  updated_at timestamptz not null default now()
);

alter table public.site_design_defaults enable row level security;

drop policy if exists "site design is publicly readable"
  on public.site_design_defaults;
create policy "site design is publicly readable"
  on public.site_design_defaults
  for select
  to anon, authenticated
  using (true);

insert into public.site_design_defaults (id, settings)
values (
  1,
  jsonb_build_object(
    'board_light', 4293383088,
    'board_dark', 4289626716,
    'pieces_theme', 'Классические',
    'buttons_theme', 'Графит и неон',
    'fields_theme', 'Тёмные',
    'borders_theme', 'Голубое свечение',
    'font_theme', 'Системный'
  )
)
on conflict (id) do nothing;

create or replace function public.admin_update_site_design(
  p_admin_password text,
  p_settings jsonb,
  p_background_base64 text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_admin_password is distinct from 'makechess-admin' then
    raise exception 'Неверный пароль администратора'
      using errcode = '42501';
  end if;

  insert into public.site_design_defaults (
    id,
    settings,
    background_base64,
    updated_at
  )
  values (1, coalesce(p_settings, '{}'::jsonb), p_background_base64, now())
  on conflict (id) do update
    set settings = excluded.settings,
        background_base64 = excluded.background_base64,
        updated_at = excluded.updated_at;
end;
$$;

revoke all on table public.site_design_defaults from public;
grant select on table public.site_design_defaults to anon, authenticated;

revoke all on function public.admin_update_site_design(text, jsonb, text)
  from public;
grant execute on function public.admin_update_site_design(text, jsonb, text)
  to anon, authenticated;

commit;
