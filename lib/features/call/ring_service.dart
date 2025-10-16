// lib/features/call/ring_service.dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Пейлоад входящего звонка
class IncomingCall {
  final String roomId;
  final String fromId;
  final String fromName; // ник звонящего
  final String toId;
  final String toName; // ник адресата
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

/// Сервис инвайтов через один общий канал Realtime: "calls".
/// Все клиенты подписаны на "calls"; нужный адресат фильтруется в AppShell.
class RingService {
  RingService._();
  static final instance = RingService._();

  final _incomingCtrl = StreamController<IncomingCall>.broadcast();
  Stream<IncomingCall> get onIncoming => _incomingCtrl.stream;

  RealtimeChannel? _ch;
  bool _connected = false;

  Future<void> ensureConnected() async {
    if (_connected) return;

    final client = Supabase.instance.client;
    // На всякий — закрываем старый
    try {
      await _ch?.unsubscribe();
    } catch (_) {}

    final ch = client.channel(
      'calls',
      opts: const RealtimeChannelConfig(ack: true, self: false),
    );

    ch.onBroadcast(
        event: 'invite',
        callback: (payload) {
          try {
            final map = Map<String, dynamic>.from(payload);
            final call = IncomingCall.fromMap(map);
            // Логи для отладки:
            // ignore: avoid_print
            print(
                '📩 [RingService] incoming invite -> ${call.toName} from ${call.fromName}, room=${call.roomId}');
            _incomingCtrl.add(call);
          } catch (e) {
            // ignore: avoid_print
            print('⚠️ [RingService] bad payload: $e');
          }
        });

    await ch.subscribe();
    _ch = ch;
    _connected = true;

    // ignore: avoid_print
    print('✅ [RingService] subscribed to "calls"');
  }

  /// Отправка инвайта — публикуем в общий канал "calls"
  Future<void> sendRing({
    required String fromId,
    required String fromName, // ник звонящего
    required String toId,
    required String toName, // ник адресата
    required String roomId,
    required bool audioOnly,
  }) async {
    // Подстрахуемся: убедимся, что подключены к "calls"
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

    await _ch!.sendBroadcastMessage(event: 'invite', payload: payload);

    // ignore: avoid_print
    print('📤 [RingService] invite sent -> $toName, room=$roomId');
  }

  /// Локальный тест без Realtime
  void debugEmitIncoming(IncomingCall call) {
    _incomingCtrl.add(call);
  }
}
