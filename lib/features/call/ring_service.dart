import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class IncomingCall {
  final String roomId;
  final String fromId;
  final String fromName;
  final String toId;
  final String toName;
  final bool audioOnly;

  IncomingCall({
    required this.roomId,
    required this.fromId,
    required this.fromName,
    required this.toId,
    required this.toName,
    required this.audioOnly,
  });

  factory IncomingCall.fromMap(Map<String, dynamic> p) => IncomingCall(
        roomId: (p['roomId'] ?? '') as String,
        fromId: (p['fromId'] ?? '') as String,
        fromName: (p['fromName'] ?? '') as String,
        toId: (p['toId'] ?? '') as String,
        toName: (p['toName'] ?? '') as String,
        audioOnly: (p['audioOnly'] ?? true) as bool,
      );

  Map<String, dynamic> toMap() => {
        'roomId': roomId,
        'fromId': fromId,
        'fromName': fromName,
        'toId': toId,
        'toName': toName,
        'audioOnly': audioOnly,
      };
}

class RingService {
  RingService._();
  static final instance = RingService._();

  final _incomingCtrl = StreamController<IncomingCall>.broadcast();
  Stream<IncomingCall> get onIncoming => _incomingCtrl.stream;

  RealtimeChannel? _channel;
  bool _connected = false;
  Future<void>? _connecting;
  Timer? _reconnectTimer;

  Future<void> ensureConnected() async {
    if (_connected && _channel != null) return;
    final active = _connecting;
    if (active != null) return active;

    final attempt = _connect();
    _connecting = attempt;
    try {
      await attempt;
    } finally {
      if (identical(_connecting, attempt)) _connecting = null;
    }
  }

  Future<void> _connect() async {
    _connected = false;
    try {
      await _channel?.unsubscribe();
    } catch (_) {}

    final channel = Supabase.instance.client.channel(
      'calls',
      opts: const RealtimeChannelConfig(ack: true, self: false),
    );
    _channel = channel;

    channel.onBroadcast(
      event: 'invite',
      callback: (payload) {
        try {
          _incomingCtrl.add(
            IncomingCall.fromMap(Map<String, dynamic>.from(payload)),
          );
        } catch (error) {
          // ignore: avoid_print
          print('[RingService] Invalid invite: $error');
        }
      },
    );

    final ready = Completer<void>();
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _connected = true;
        _reconnectTimer?.cancel();
        if (!ready.isCompleted) ready.complete();
        return;
      }
      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut ||
          status == RealtimeSubscribeStatus.closed) {
        _connected = false;
        if (!ready.isCompleted) {
          ready.completeError(error ?? Exception('Calls channel: $status'));
        }
        _scheduleReconnect();
      }
    });

    await ready.future.timeout(const Duration(seconds: 15));
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      ensureConnected().catchError((Object _) => _scheduleReconnect());
    });
  }

  Future<void> sendRing({
    required String fromId,
    required String fromName,
    required String toId,
    required String toName,
    required String roomId,
    required bool audioOnly,
  }) async {
    await ensureConnected();
    final payload = {
      'roomId': roomId,
      'fromId': fromId,
      'fromName': fromName,
      'toId': toId,
      'toName': toName,
      'audioOnly': audioOnly,
      'ts': DateTime.now().toIso8601String(),
    };

    // Broadcast messages are not stored. Repeating protects the invitation
    // while the receiver is restoring its websocket after sleep/network loss.
    for (var attempt = 0; attempt < 3; attempt++) {
      await _channel!.sendBroadcastMessage(event: 'invite', payload: payload);
      if (attempt < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    }
  }

  void debugEmitIncoming(IncomingCall call) => _incomingCtrl.add(call);
}
