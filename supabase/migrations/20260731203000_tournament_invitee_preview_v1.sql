begin;

drop policy if exists makechess_tournament_tables_v1_participant_select
  on public.makechess_tournament_tables_v1;
drop policy if exists makechess_tournament_tables_v1_participant_or_invitee_select
  on public.makechess_tournament_tables_v1;

create policy makechess_tournament_tables_v1_participant_or_invitee_select
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
  or exists (
    select 1
    from public.makechess_messages_v1 invitation
    where invitation.recipient_id = auth.uid()
      and invitation.sender_id = makechess_tournament_tables_v1.owner_id
      and invitation.tournament_id =
        makechess_tournament_tables_v1.tournament_id
      and invitation.category = 'tournament_invite'
      and invitation.status in ('unread', 'read', 'accepted')
  )
);

commit;
