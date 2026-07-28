// lib/features/call/supabase_signaling.dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:realtime_client/realtime_client.dart' as rt;

/// Управление сигналингом (обмен SDP/ICE между участниками через Supabase)
class SupabaseSignaling {
  SupabaseSignaling._();
  static final instance = SupabaseSignaling._();

  final supa.SupabaseClient _sb = supa.Supabase.instance.client;
  final Map<String, rt.RealtimeChannel> _channels = {};

  // Потоки для classroom-режима (мультизвонки)
  final Map<String, StreamController<Map<String, dynamic>>> _msgCtrls = {};

  // =======================================================================
  // БАЗОВЫЕ (1:1) МЕТОДЫ — ты их уже использовал, оставляем без изменений
  // =======================================================================

  rt.RealtimeChannel _ensure(String roomId) {
    final key = roomId.trim();
    final existed = _channels[key];
    if (existed != null) return existed;

    final ch = _sb.channel('room:$key');
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

  // ---------- Подписки (1:1) ----------
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
  }

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

  // =======================================================================
  // ДОПОЛНЕНИЕ: МУЛЬТИЗВОНКИ (Classroom)
  // =======================================================================

  /// Подписка на широковещательные classroom-сообщения ("msg").
  /// Каждый вызов возвращает Stream<Map<String,dynamic>>.
  Stream<Map<String, dynamic>> onMessage(String roomId) {
    final key = roomId.trim();
    final ch = _ensure(key);
    final ctrl = _msgCtrls.putIfAbsent(
        key, () => StreamController<Map<String, dynamic>>.broadcast());

    ch.onBroadcast(event: 'msg', callback: (payload, [ref]) {
      Map<String, dynamic> data = {};
      if (payload is Map && payload['payload'] is Map) {
        data = (payload['payload'] as Map).cast<String, dynamic>();
      } else if (payload is Map) {
        data = payload.cast<String, dynamic>();
      }
      if (data.isNotEmpty) ctrl.add(data);
    });

    return ctrl.stream;
  }

  /// Отправка classroom-сообщения
  Future<void> sendMessage(String roomId, Map<String, dynamic> msg) async {
    final ch = _ensure(roomId);
    await ch.sendBroadcastMessage(event: 'msg', payload: msg);
  }
}
