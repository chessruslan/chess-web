begin;
create or replace function public.respond_makechess_tournament_join_request_v1(
  p_message_id text,
  p_accept boolean
) returns void
language plpgsql security definer set search_path = public, auth
as $$
declare request_row public.makechess_messages_v1%rowtype;
declare applicant_name text;
begin
  select * into request_row from public.makechess_messages_v1
  where id = p_message_id and recipient_id = auth.uid()
    and category = 'tournament_join_request' and status in ('unread','read')
  for update;
  if not found then raise exception 'Request not found or already answered'; end if;
  if p_accept then
    applicant_name := coalesce(nullif(request_row.sender_name, ''), 'Участник');
    update public.makechess_tournaments_v1
    set data = jsonb_set(
      jsonb_set(data, '{participantIds}',
        coalesce(data -> 'participantIds','[]'::jsonb) || to_jsonb(request_row.sender_id::text), true),
      '{participantNames}', coalesce(data -> 'participantNames','{}'::jsonb) ||
        jsonb_build_object(request_row.sender_id::text, applicant_name), true),
      updated_at = now()
    where owner_id = auth.uid() and id = request_row.tournament_id
      and not (coalesce(data -> 'participantIds','[]'::jsonb) ? request_row.sender_id::text);
  end if;
  update public.makechess_messages_v1
  set status = case when p_accept then 'accepted' else 'declined' end,
      read_at = coalesce(read_at, now()), responded_at = now()
  where id = p_message_id;
end;
$$;
revoke all on function public.respond_makechess_tournament_join_request_v1(text, boolean) from public;
grant execute on function public.respond_makechess_tournament_join_request_v1(text, boolean) to authenticated;
commit;
