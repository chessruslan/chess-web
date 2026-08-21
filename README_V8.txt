MAKECHESS TOURNAMENT OWNER JOIN V8

This package is built from the exact files supplied by the user on 2026-08-17.

It changes only:
- lib/ui/tournaments/student_tournaments_dialog.dart
- lib/ui/tournaments/tournament_manager_dialog.dart
- lib/services/tournament_storage_service.dart

Main behavior:
1. Tournament creator is not automatically a participant.
2. If creator is not a participant, the tournament card shows:
   [Open tournament] [Join]
3. Pressing Join as creator does NOT send a message/invitation to self.
4. Creator is added directly to participantIds/participantNames and visual table.
5. maxParticipants is checked.
6. If the tournament data already contains a min/max rating restriction
   (minRating/minimumRating/ratingMin/min_rating/rating_min or max equivalents),
   the creator is checked against the current profile rating.
7. Non-owner behavior remains on the existing RPC.
8. Automatic organizer invitation after tournament publication is disabled.

Safety:
Installer checks SHA256 of all three live files before changing anything.
If any file differs from the supplied version, installation stops before backup/copy.
