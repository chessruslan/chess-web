import 'dart:async';
import '../platform/web_compat.dart';

import 'package:flutter/foundation.dart';
import 'package:realtime_client/realtime_client.dart' as rt;
import 'package:supabase_flutter/supabase_flutter.dart';

class LobbyService {
  LobbyService(
    this.supa, {
    required this.username,
    required this.userId,
    required this.myRating,
  });

  final SupabaseClient supa;
  final String username;
  final String userId;
  int myRating;

  rt.RealtimeChannel? _chan;

  void Function()? onOnlineChanged;
  void Function(
    String roomId,
    String fromId,
    String fromName,
    String color,
    int m,
    int inc,
    bool rated,
  )? onInvite;

  void Function(
    String roomId,
    String fromId,
    String fromName,
    String color,
  )? onAccept;

  final Map<String, _Peer> _peers = {};

  List<Map<String, String>> get online => _peers.values
      .map((p) => {
            'id': p.id,
            'username': p.name,
            'rating': '${p.rating}',
          })
      .toList(growable: false);

  static const Duration _beat = Duration(seconds: 12);
  Timer? _heartbeat;

  void sendPresenceNow() {
    final ch = _chan;
    if (ch != null) _sendPing(ch);
  }

  void updateMyRating(int r) {
    myRating = r;
    _touch(userId, username, myRating);
    onOnlineChanged?.call();

    final ch = _chan;
    if (ch != null) {
      _sendHello(ch);
      _sendPing(ch);
    }
  }

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

  void _touch(String id, String name, int rating) {
    if (id.isEmpty) return;
    final safeName = name.isEmpty ? 'player' : name;
    final p = _peers[id];
    if (p == null) {
      _peers[id] = _Peer(
        id: id,
        name: safeName,
        rating: rating,
        lastSeen: DateTime.now(),
      );
    } else {
      p.name = safeName;
      p.rating = rating;
      p.lastSeen = DateTime.now();
    }
    onOnlineChanged?.call();
  }

  Future<void> connect() async {
    if (_chan != null) return;

    final chan =
        supa.channel('lobby', opts: const rt.RealtimeChannelConfig(self: true));

    chan.onBroadcast(
      event: 'whois',
      callback: (payload, [ref]) => _sendHello(chan),
    );

    chan.onBroadcast(
      event: 'invite',
      callback: (payload, [ref]) {
        final p = _parsePayload(payload);
        final String to =
            (p['to'] is String) ? (p['to'] as String) : '${p['to'] ?? ''}';
        if (to.isEmpty) {
          debugPrint('[INVITE RECV] Пропуск: to пустой. payload=$p');
          return;
        }

        debugPrint('[INVITE RECV] to=$to, me=$userId, payload=$p');

        if (to == userId) {
          onInvite?.call(
            '${p['roomId'] ?? ''}',
            '${p['from'] ?? ''}',
            '${p['fromName'] ?? 'player'}',
            '${p['color'] ?? 'white'}',
            (p['m'] as num?)?.toInt() ?? 5,
            (p['inc'] as num?)?.toInt() ?? 3,
            (p['rated'] is bool) ? (p['rated'] as bool) : true,
          );
        }
      },
    );

    chan.onBroadcast(
      event: 'ping',
      callback: (payload, [ref]) {
        final p = _parsePayload(payload);
        _touch(
          '${p['id'] ?? ''}',
          '${p['name'] ?? 'player'}',
          (p['rating'] is num)
              ? (p['rating'] as num).toInt()
              : int.tryParse('${p['rating'] ?? '1200'}') ?? 1200,
        );
      },
    );

    chan.onBroadcast(
      event: 'accept',
      callback: (payload, [ref]) {
        final p = _parsePayload(payload);
        if ('${p['to']}' == userId) {
          onAccept?.call(
            '${p['roomId']}',
            '${p['from']}',
            '${p['fromName']}',
            '${p['color'] ?? 'white'}',
          );
        }
      },
    );

    chan.onBroadcast(
      event: 'bye',
      callback: (payload, [ref]) {
        final p = _parsePayload(payload);
        final id = '${p['id'] ?? ''}';
        if (id.isEmpty) return;
        _peers.remove(id);
        onOnlineChanged?.call();
      },
    );

    chan.subscribe();

    await Future.delayed(const Duration(milliseconds: 120));
    _sendHello(chan);
    _sendPing(chan);
    chan.sendBroadcastMessage(event: 'whois', payload: {'from': userId});

    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_beat, (_) => _sendPing(chan));

    _touch(userId, username, myRating);

    registerBeforeUnload(() {
      chan.sendBroadcastMessage(event: 'bye', payload: {'id': userId});
    });

    _chan = chan;
  }

  void _sendHello(rt.RealtimeChannel ch) => ch.sendBroadcastMessage(
        event: 'hello',
        payload: {'id': userId, 'name': username, 'rating': myRating},
      );

  void _sendPing(rt.RealtimeChannel ch) => ch.sendBroadcastMessage(
        event: 'ping',
        payload: {'id': userId, 'name': username, 'rating': myRating},
      );

  Future<void> disconnect() async {
    _heartbeat?.cancel();
    final ch = _chan;
    if (ch != null) {
      await ch.sendBroadcastMessage(event: 'bye', payload: {'id': userId});
      await ch.unsubscribe();
    }
    _chan = null;
  }

  Future<void> sendInvite({
    required String toUserId,
    required String toName,
    required String roomId,
    required String color,
    required int minutes,
    required int increment,
    required bool rated,
  }) async {
    _chan?.sendBroadcastMessage(event: 'invite', payload: {
      'roomId': roomId,
      'from': userId,
      'fromName': username,
      'to': toUserId,
      'toName': toName,
      'color': color,
      'm': minutes,
      'inc': increment,
      'rated': rated,
    });
  }

  Future<void> sendAccept({
    required String toUserId,
    required String toName,
    required String roomId,
    required String color,
  }) async {
    _chan?.sendBroadcastMessage(event: 'accept', payload: {
      'roomId': roomId,
      'from': userId,
      'fromName': username,
      'to': toUserId,
      'toName': toName,
      'color': color,
    });
  }
}

class _Peer {
  _Peer({
    required this.id,
    required this.name,
    required this.rating,
    required this.lastSeen,
  });

  final String id;
  String name;
  int rating;
  DateTime lastSeen;
}
