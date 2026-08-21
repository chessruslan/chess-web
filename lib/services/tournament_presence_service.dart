import 'package:supabase_flutter/supabase_flutter.dart';

class TournamentPresenceService {
  TournamentPresenceService._();

  static String _channelName(String tournamentId) =>
      'makechess:tournament:$tournamentId:ready:v1';

  static RealtimeChannel observe({
    required String tournamentId,
    required void Function(Set<String> userIds) onChanged,
  }) {
    final client = Supabase.instance.client;
    late final RealtimeChannel channel;
    void emit() => onChanged(
          channel.presenceState().map((state) => state.key).toSet(),
        );
    channel = client.channel(_channelName(tournamentId));
    channel.onPresenceSync((_) => emit());
    channel.onPresenceJoin((_) => emit());
    channel.onPresenceLeave((_) => emit());
    channel.subscribe();
    return channel;
  }

  static RealtimeChannel? join(
    String tournamentId, {
    void Function(Set<String> userIds)? onChanged,
  }) {
    final client = Supabase.instance.client;
    final userId = (client.auth.currentUser?.id ?? '').trim();
    if (userId.isEmpty || tournamentId.trim().isEmpty) return null;
    final channel = client.channel(
      _channelName(tournamentId),
      opts: RealtimeChannelConfig(key: userId),
    );
    void emit() => onChanged?.call(
          channel.presenceState().map((state) => state.key).toSet(),
        );
    channel.onPresenceSync((_) => emit());
    channel.onPresenceJoin((_) => emit());
    channel.onPresenceLeave((_) => emit());
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        channel.track(<String, dynamic>{
          'user_id': userId,
          'ready': true,
          'online_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    });
    return channel;
  }

  static Future<void> leave(RealtimeChannel? channel) async {
    if (channel == null) return;
    try {
      await channel.untrack();
    } catch (_) {}
    await Supabase.instance.client.removeChannel(channel);
  }
}
