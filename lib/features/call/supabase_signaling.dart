// ... импорт как у тебя:
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:realtime_client/realtime_client.dart' as rt;

class SupabaseSignaling {
  SupabaseSignaling._();
  static final instance = SupabaseSignaling._();

  final supa.SupabaseClient _sb = supa.Supabase.instance.client;

  final Map<String, rt.RealtimeChannel> _channels = {};

  rt.RealtimeChannel _ensure(String roomId) {
    final key = roomId.trim();
    final existed = _channels[key];
    if (existed != null) return existed;

    final ch = _sb.channel('room:$key'); // возвращает rt.RealtimeChannel
    ch.subscribe();
    _channels[key] = ch;
    return ch;
  }

  Future<void> leaveRoom(String roomId) async {
    final ch = _channels.remove(roomId.trim());
    if (ch != null) {
      try {
        await ch.unsubscribe();
      } catch (_) {}
    }
  }

  // ---------- OUT ----------
  Future<void> sendOffer({required String roomId, required String sdp}) async {
    final ch = _ensure(roomId);
    await ch.sendBroadcastMessage(event: 'offer', payload: {'sdp': sdp});
  }

  Future<void> sendAnswer({required String roomId, required String sdp}) async {
    final ch = _ensure(roomId);
    await ch.sendBroadcastMessage(event: 'answer', payload: {'sdp': sdp});
  }

  Future<void> sendIce({
    required String roomId,
    required Map<String, dynamic> candidate,
  }) async {
    final ch = _ensure(roomId);
    await ch.sendBroadcastMessage(event: 'ice', payload: candidate);
  }

  Future<void> sendReady({required String roomId}) async {
    final ch = _ensure(roomId);
    await ch.sendBroadcastMessage(
      event: 'ready',
      payload: {'t': DateTime.now().toIso8601String()},
    );
  }

  // ---------- ON (только onBroadcast) ----------
  // Возвращаю РЕАЛЬНЫЙ канал — храни его поле и при завершении делай ch.unsubscribe()

  /// Кто-то присоединился и просит переслать offer
  rt.RealtimeChannel onReady(
    String roomId,
    Future<void> Function() handler,
  ) {
    final ch = _ensure(roomId);
    ch.onBroadcast(
      event: 'ready',
      callback: (payload, [ref]) async => await handler(),
    );
    return ch;
    // Отписка потом: await ch.unsubscribe();
  }

  /// Слушаем offer (обычно join-сторона)
  rt.RealtimeChannel onOffer(
    String roomId,
    Future<void> Function(String sdp) handler,
  ) {
    final ch = _ensure(roomId);
    ch.onBroadcast(
      event: 'offer',
      callback: (payload, [ref]) async {
        final sdp = _extractSdp(payload);
        if (sdp.isNotEmpty) await handler(sdp);
      },
    );
    return ch;
  }

  /// Слушаем answer (обычно create-сторона)
  rt.RealtimeChannel onAnswer(
    String roomId,
    Future<void> Function(String sdp) handler,
  ) {
    final ch = _ensure(roomId);
    ch.onBroadcast(
      event: 'answer',
      callback: (payload, [ref]) async {
        final sdp = _extractSdp(payload);
        if (sdp.isNotEmpty) await handler(sdp);
      },
    );
    return ch;
  }

  /// Удалённые ICE-кандидаты (обе стороны)
  rt.RealtimeChannel onRemoteIce(
    String roomId,
    Future<void> Function(Map<String, dynamic> cand) handler,
  ) {
    final ch = _ensure(roomId);
    ch.onBroadcast(
      event: 'ice',
      callback: (payload, [ref]) async {
        Map<String, dynamic> data = {};
        if (payload is Map && payload['payload'] is Map) {
          data = (payload['payload'] as Map).cast<String, dynamic>();
        } else if (payload is Map) {
          data = payload.cast<String, dynamic>();
        }
        await handler(data);
      },
    );
    return ch;
  }

  // Вспомогательное
  String _extractSdp(dynamic payload) {
    if (payload is Map && payload['sdp'] != null) {
      return payload['sdp'].toString();
    }
    if (payload is Map &&
        payload['payload'] is Map &&
        (payload['payload'] as Map)['sdp'] != null) {
      return (payload['payload'] as Map)['sdp'].toString();
    }
    return '';
  }
}
