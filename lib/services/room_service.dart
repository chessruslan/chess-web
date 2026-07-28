import 'dart:async';

import 'package:realtime_client/realtime_client.dart' as rt;
import 'package:supabase_flutter/supabase_flutter.dart';

class RoomService {
  RoomService(this.supa, {required this.roomId});

  final SupabaseClient supa;
  final String roomId;

  rt.RealtimeChannel? _chan;
  final Completer<void> _ready = Completer<void>();

  void Function(Map<String, dynamic> msg)? onChat;
  void Function(Map<String, dynamic> move)? onMove;
  void Function(Map<String, dynamic> evt)? onCtrl;
  void Function(Map<String, dynamic> evt)? onDrawOffer;
  void Function(Map<String, dynamic> evt)? onDrawAnswer;
  void Function(Map<String, dynamic> evt)? onResign;

  Map<String, dynamic> _parsePayload(dynamic raw) {
    Map<String, dynamic> unwrap(dynamic v) {
      if (v is Map) {
        final m = Map<String, dynamic>.from(v);
        while (m['payload'] is Map) {
          final inner = Map<String, dynamic>.from(m['payload']);
          m
            ..remove('payload')
            ..addAll(inner);
        }
        return m;
      }
      return <String, dynamic>{};
    }

    return unwrap(raw);
  }

  Future<void> connect() async {
    if (_chan != null) return;

    _chan = supa.channel(
      'room:$roomId',
      opts: const rt.RealtimeChannelConfig(self: true),
    );

    _chan!.onBroadcast(
      event: 'move',
      callback: (payload, [ref]) {
        onMove?.call(_parsePayload(payload));
      },
    );

    _chan!.onBroadcast(
      event: 'ctrl',
      callback: (payload, [ref]) {
        onCtrl?.call(_parsePayload(payload));
      },
    );

    _chan!.onBroadcast(
      event: 'draw_offer',
      callback: (payload, [ref]) {
        onDrawOffer?.call(_parsePayload(payload));
      },
    );

    _chan!.onBroadcast(
      event: 'draw_answer',
      callback: (payload, [ref]) {
        onDrawAnswer?.call(_parsePayload(payload));
      },
    );

    _chan!.onBroadcast(
      event: 'resign',
      callback: (payload, [ref]) {
        onResign?.call(_parsePayload(payload));
      },
    );

    _chan!.onBroadcast(
      event: 'chat',
      callback: (payload, [ref]) {
        onChat?.call(_parsePayload(payload));
      },
    );

    await _chan!.subscribe();
    if (!_ready.isCompleted) _ready.complete();
  }

  Future<void> disconnect() async {
    await _chan?.unsubscribe();
    _chan = null;
    if (!_ready.isCompleted) {
      _ready.completeError(StateError('disconnected'));
    }
  }

  Future<void> sendChat({
    required String text,
    required String fromName,
    required String from,
  }) async {
    await _ready.future;
    _chan?.sendBroadcastMessage(event: 'chat', payload: {
      'roomId': roomId,
      'type': 'chat',
      'msg': text,
      'fromName': fromName,
      'from': from,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> sendMove({
    required String from,
    required String to,
    String? promotion,
  }) async {
    await _ready.future;
    _chan?.sendBroadcastMessage(event: 'move', payload: {
      'roomId': roomId,
      'from': from,
      'to': to,
      if (promotion != null) 'promotion': promotion,
      'ts': DateTime.now().toIso8601String(),
    });
  }

  Future<void> sendCtrl(Map<String, dynamic> data) async {
    await _ready.future;
    final payload = Map<String, dynamic>.from(data);
    payload['roomId'] = roomId;
    _chan?.sendBroadcastMessage(event: 'ctrl', payload: payload);
  }

  Future<void> sendDrawOffer({
    required String fromUserId,
    required String fromName,
  }) async {
    await _ready.future;
    _chan?.sendBroadcastMessage(event: 'draw_offer', payload: {
      'roomId': roomId,
      'from': fromUserId,
      'fromName': fromName,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> sendDrawAnswer({
    required String fromUserId,
    required String fromName,
    required bool accepted,
  }) async {
    await _ready.future;
    _chan?.sendBroadcastMessage(event: 'draw_answer', payload: {
      'roomId': roomId,
      'from': fromUserId,
      'fromName': fromName,
      'accepted': accepted,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> sendResign({
    required String fromUserId,
    required String fromName,
  }) async {
    await _ready.future;
    _chan?.sendBroadcastMessage(event: 'resign', payload: {
      'roomId': roomId,
      'from': fromUserId,
      'fromName': fromName,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
