import 'dart:async';

import 'package:realtime_client/realtime_client.dart' as rt;
import 'package:supabase_flutter/supabase_flutter.dart';

enum SignalType { join, offer, answer, candidate }

String _typeToString(SignalType t) {
  switch (t) {
    case SignalType.join:
      return 'join';
    case SignalType.offer:
      return 'offer';
    case SignalType.answer:
      return 'answer';
    case SignalType.candidate:
      return 'candidate';
  }
}

SignalType _parseType(String t) {
  switch (t) {
    case 'join':
      return SignalType.join;
    case 'offer':
      return SignalType.offer;
    case 'answer':
      return SignalType.answer;
    case 'candidate':
      return SignalType.candidate;
    default:
      return SignalType.join;
  }
}

class ClassroomSignal {
  ClassroomSignal({
    required this.id,
    required this.type,
    required this.classroomId,
    required this.senderId,
    this.receiverId,
    this.sdp,
    this.candidate,
    this.createdAt,
  });

  final String id;
  final SignalType type;
  final String classroomId;
  final String senderId;
  final String? receiverId;
  final String? sdp;
  final String? candidate;
  final DateTime? createdAt;

  factory ClassroomSignal.fromRow(Map<String, dynamic> row) {
    return ClassroomSignal(
      id: '${row['id'] ?? ''}',
      type: _parseType('${row['type'] ?? ''}'),
      classroomId: '${row['classroom_id'] ?? ''}',
      senderId: '${row['sender_id'] ?? ''}',
      receiverId: row['receiver_id'] as String?,
      sdp: row['sdp'] as String?,
      candidate: row['candidate'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse('${row['created_at']}')
          : null,
    );
  }
}

/// Тип сообщения внутри одного независимого соединения
/// «учитель ↔ конкретный ученик».
enum ClassroomPairEventType { ready, offer, answer, candidate, hangup }

class ClassroomPairEvent {
  const ClassroomPairEvent({
    required this.id,
    required this.type,
    required this.fromId,
    required this.toId,
    this.sdp,
    this.descriptionType,
    this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
  });

  final String id;
  final ClassroomPairEventType type;
  final String fromId;
  final String toId;
  final String? sdp;
  final String? descriptionType;
  final String? candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;
}

/// Отдельный Realtime-канал для одной пары «учитель ↔ ученик».
///
/// В отличие от старой общей таблицы classroom_signals, сообщения разных
/// учеников физически не смешиваются в одном канале. Это повторяет надёжную
/// схему рабочего звонка режима «Играть»: ready -> offer -> answer -> ICE.
class ClassroomPairSignaling {
  ClassroomPairSignaling({
    required SupabaseClient client,
    required this.classroomId,
    required this.teacherId,
    required this.studentId,
    required this.selfId,
  }) : _client = client;

  final SupabaseClient _client;
  final String classroomId;
  final String teacherId;
  final String studentId;
  final String selfId;

  final StreamController<ClassroomPairEvent> _events =
      StreamController<ClassroomPairEvent>.broadcast();
  final Set<String> _seenMessageIds = <String>{};

  rt.RealtimeChannel? _channel;
  Future<void>? _starting;
  int _messageCounter = 0;
  bool _disposed = false;

  Stream<ClassroomPairEvent> get events => _events.stream;

  String get peerId => selfId == teacherId ? studentId : teacherId;

  String get _channelName =>
      'makechess:classroom-pair:$classroomId:$teacherId:$studentId:v3';

  Map<String, dynamic> _unwrap(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final result = Map<String, dynamic>.from(raw);
    while (result['payload'] is Map) {
      final inner = Map<String, dynamic>.from(result['payload'] as Map);
      result
        ..remove('payload')
        ..addAll(inner);
    }
    return result;
  }

  Future<void> start() async {
    if (_disposed) {
      throw StateError('Канал видеокласса уже закрыт.');
    }
    if (_channel != null) return;
    final active = _starting;
    if (active != null) return active;

    final task = _startOnce();
    _starting = task;
    try {
      await task;
    } finally {
      if (identical(_starting, task)) _starting = null;
    }
  }

  Future<void> _startOnce() async {
    final channel = _client.channel(
      _channelName,
      opts: const rt.RealtimeChannelConfig(ack: true, self: false),
    );

    void listen(String eventName, ClassroomPairEventType type) {
      channel.onBroadcast(
        event: eventName,
        callback: (raw, [ref]) {
          if (_disposed) return;
          final payload = _unwrap(raw);
          final from = '${payload['from'] ?? ''}'.trim();
          final to = '${payload['to'] ?? ''}'.trim();
          if (from != peerId || to != selfId) return;

          final id = '${payload['id'] ?? ''}'.trim();
          if (id.isNotEmpty && !_seenMessageIds.add(id)) return;

          final rawLine = payload['sdpMLineIndex'];
          _events.add(
            ClassroomPairEvent(
              id: id,
              type: type,
              fromId: from,
              toId: to,
              sdp: payload['sdp'] as String?,
              descriptionType: payload['descriptionType'] as String?,
              candidate: payload['candidate'] as String?,
              sdpMid: payload['sdpMid'] as String?,
              sdpMLineIndex:
                  rawLine is num ? rawLine.toInt() : int.tryParse('$rawLine'),
            ),
          );
        },
      );
    }

    listen('ready', ClassroomPairEventType.ready);
    listen('offer', ClassroomPairEventType.offer);
    listen('answer', ClassroomPairEventType.answer);
    listen('ice', ClassroomPairEventType.candidate);
    listen('hangup', ClassroomPairEventType.hangup);

    final ready = Completer<void>();
    channel.subscribe((status, error) {
      if (status == rt.RealtimeSubscribeStatus.subscribed) {
        if (!ready.isCompleted) ready.complete();
        return;
      }
      if (status == rt.RealtimeSubscribeStatus.channelError ||
          status == rt.RealtimeSubscribeStatus.timedOut ||
          status == rt.RealtimeSubscribeStatus.closed) {
        if (!ready.isCompleted) {
          ready.completeError(
            error ?? Exception('Classroom pair channel: $status'),
          );
        }
      }
    });

    try {
      await ready.future.timeout(const Duration(seconds: 15));
      _channel = channel;
    } catch (_) {
      try {
        await channel.unsubscribe();
      } catch (_) {}
      try {
        await _client.removeChannel(channel);
      } catch (_) {}
      rethrow;
    }
  }

  String _nextMessageId() {
    _messageCounter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}:$selfId:$_messageCounter';
  }

  Future<void> _send(
    String event, {
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    await start();
    final channel = _channel;
    if (channel == null) {
      throw StateError('Канал видеокласса не подключён.');
    }
    await channel.sendBroadcastMessage(
      event: event,
      payload: <String, dynamic>{
        'id': _nextMessageId(),
        'from': selfId,
        'to': peerId,
        'sentAt': DateTime.now().toUtc().toIso8601String(),
        ...payload,
      },
    );
  }

  Future<void> sendReady() => _send('ready');

  Future<void> sendOffer({
    required String sdp,
    required String descriptionType,
  }) {
    return _send(
      'offer',
      payload: <String, dynamic>{
        'sdp': sdp,
        'descriptionType': descriptionType,
      },
    );
  }

  Future<void> sendAnswer({
    required String sdp,
    required String descriptionType,
  }) {
    return _send(
      'answer',
      payload: <String, dynamic>{
        'sdp': sdp,
        'descriptionType': descriptionType,
      },
    );
  }

  Future<void> sendCandidate({
    required String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  }) {
    return _send(
      'ice',
      payload: <String, dynamic>{
        'candidate': candidate,
        'sdpMid': sdpMid,
        'sdpMLineIndex': sdpMLineIndex,
      },
    );
  }

  Future<void> sendHangup() => _send('hangup');

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await channel.unsubscribe();
      } catch (_) {}
      try {
        await _client.removeChannel(channel);
      } catch (_) {}
    }

    await _events.close();
  }
}

class ClassroomSignaling {
  ClassroomSignaling(this._client);
  final SupabaseClient _client;

  Future<String> ensureActiveClassroom({
    required String schoolId,
    required String teacherId,
  }) async {
    final existing = await _client
        .from('classrooms')
        .select('id')
        .eq('school_id', schoolId)
        .eq('teacher_id', teacherId)
        .maybeSingle();

    String classId;
    if (existing != null) {
      classId = existing['id'] as String;
    } else {
      final inserted = await _client
          .from('classrooms')
          .insert({'school_id': schoolId, 'teacher_id': teacherId})
          .select('id')
          .single();
      classId = inserted['id'] as String;
    }

    await _client.from('active_classrooms').upsert({
      'school_id': schoolId,
      'classroom_id': classId,
      'teacher_id': teacherId,
      'updated_at': DateTime.now().toIso8601String(),
    });

    return classId;
  }

  /// Новый рабочий путь видеокласса: отдельный канал на каждую пару.
  ClassroomPairSignaling openPair({
    required String classroomId,
    required String teacherId,
    required String studentId,
    required String selfId,
  }) {
    return ClassroomPairSignaling(
      client: _client,
      classroomId: classroomId,
      teacherId: teacherId,
      studentId: studentId,
      selfId: selfId,
    );
  }

  // Старые табличные методы оставлены для совместимости со старыми экранами.
  Future<void> sendJoin({
    required String classroomId,
    required String senderId,
  }) async {
    await _client.from('classroom_signals').insert({
      'classroom_id': classroomId,
      'sender_id': senderId,
      'type': 'join',
    });
  }

  Future<void> sendOffer({
    required String classroomId,
    required String senderId,
    required String receiverId,
    required String sdp,
  }) async {
    await _client.from('classroom_signals').insert({
      'classroom_id': classroomId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'type': 'offer',
      'sdp': sdp,
    });
  }

  Future<void> sendAnswer({
    required String classroomId,
    required String senderId,
    required String receiverId,
    required String sdp,
  }) async {
    await _client.from('classroom_signals').insert({
      'classroom_id': classroomId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'type': 'answer',
      'sdp': sdp,
    });
  }

  Future<void> sendCandidate({
    required String classroomId,
    required String senderId,
    required String receiverId,
    required String candidate,
  }) async {
    await _client.from('classroom_signals').insert({
      'classroom_id': classroomId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'type': 'candidate',
      'candidate': candidate,
    });
  }

  Stream<ClassroomSignal> watchSignals(String classroomId) {
    final seenIds = <String>{};
    return _client
        .from('classroom_signals')
        .stream(primaryKey: ['id'])
        .eq('classroom_id', classroomId)
        .order('created_at')
        .map((rows) sync* {
          for (final row in rows) {
            final signal = ClassroomSignal.fromRow(row);
            if (signal.id.isEmpty || !seenIds.add(signal.id)) continue;
            yield signal;
          }
        })
        .asyncExpand(Stream<ClassroomSignal>.fromIterable);
  }

  Stream<ClassroomSignal> watch(String classroomId) =>
      watchSignals(classroomId);

  Future<List<ClassroomSignal>> fetchRecentJoins({
    required String classroomId,
    Duration lookback = const Duration(seconds: 20),
  }) async {
    final since = DateTime.now().subtract(lookback).toUtc().toIso8601String();
    final rows = await _client
        .from('classroom_signals')
        .select()
        .eq('classroom_id', classroomId)
        .eq('type', _typeToString(SignalType.join))
        .gte('created_at', since)
        .order('created_at');
    return (rows as List)
        .map((e) => ClassroomSignal.fromRow(e as Map<String, dynamic>))
        .toList();
  }
}

// ============================================================================
// ПРИГЛАШЕНИЯ НА УРОК
// Отдельный глобальный Realtime-канал. Он работает на любой странице сайта,
// потому что запускается из AppShell, а не только из панели «Учиться».
// ============================================================================

class LessonInvitation {
  const LessonInvitation({
    required this.lessonId,
    required this.teacherId,
    required this.teacherName,
    required this.studentId,
    required this.studentName,
    required this.createdAt,
    this.kind = 'lesson',
    this.classroomId,
  });

  final String lessonId;
  final String teacherId;
  final String teacherName;
  final String studentId;
  final String studentName;
  final DateTime createdAt;
  final String kind;
  final String? classroomId;

  bool get isVideo => kind == 'video';

  factory LessonInvitation.fromPayload(Map<String, dynamic> payload) {
    return LessonInvitation(
      lessonId: '${payload['lessonId'] ?? ''}',
      teacherId: '${payload['teacherId'] ?? ''}',
      teacherName: '${payload['teacherName'] ?? 'Учитель'}',
      studentId: '${payload['studentId'] ?? ''}',
      studentName: '${payload['studentName'] ?? 'Ученик'}',
      createdAt:
          DateTime.tryParse('${payload['createdAt'] ?? ''}') ?? DateTime.now(),
      kind: '${payload['kind'] ?? 'lesson'}',
      classroomId: '${payload['classroomId'] ?? ''}'.trim().isEmpty
          ? null
          : '${payload['classroomId']}',
    );
  }

  Map<String, dynamic> toPayload() => <String, dynamic>{
        'lessonId': lessonId,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'studentId': studentId,
        'studentName': studentName,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'kind': kind,
        if (classroomId != null) 'classroomId': classroomId,
      };
}

class LessonInvitationResponse {
  const LessonInvitationResponse({
    required this.lessonId,
    required this.teacherId,
    required this.studentId,
    required this.studentName,
    required this.accepted,
    required this.createdAt,
  });

  final String lessonId;
  final String teacherId;
  final String studentId;
  final String studentName;
  final bool accepted;
  final DateTime createdAt;

  factory LessonInvitationResponse.fromPayload(Map<String, dynamic> payload) {
    return LessonInvitationResponse(
      lessonId: '${payload['lessonId'] ?? ''}',
      teacherId: '${payload['teacherId'] ?? ''}',
      studentId: '${payload['studentId'] ?? ''}',
      studentName: '${payload['studentName'] ?? 'Ученик'}',
      accepted: payload['accepted'] == true,
      createdAt:
          DateTime.tryParse('${payload['createdAt'] ?? ''}') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toPayload() => <String, dynamic>{
        'lessonId': lessonId,
        'teacherId': teacherId,
        'studentId': studentId,
        'studentName': studentName,
        'accepted': accepted,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}

class LessonInvitationService {
  LessonInvitationService._();

  static final LessonInvitationService instance = LessonInvitationService._();

  final StreamController<LessonInvitation> _incomingController =
      StreamController<LessonInvitation>.broadcast();
  final StreamController<LessonInvitationResponse> _responseController =
      StreamController<LessonInvitationResponse>.broadcast();

  Stream<LessonInvitation> get incoming => _incomingController.stream;
  Stream<LessonInvitationResponse> get responses => _responseController.stream;

  SupabaseClient? _client;
  rt.RealtimeChannel? _channel;
  Future<void>? _starting;
  String _boundUserId = '';
  int _generation = 0;

  String _userChannelName(String userId) =>
      'makechess:lesson-invitations:user:$userId:v2';

  Map<String, dynamic> _unwrap(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final result = Map<String, dynamic>.from(raw);
    while (result['payload'] is Map) {
      final inner = Map<String, dynamic>.from(result['payload'] as Map);
      result
        ..remove('payload')
        ..addAll(inner);
    }
    return result;
  }

  Future<void> start(SupabaseClient client) async {
    final requestedUserId = (client.auth.currentUser?.id ?? '').trim();
    if (requestedUserId.isEmpty) {
      await stop();
      throw StateError('Для приёма приглашений требуется авторизация.');
    }

    if (_channel != null &&
        identical(_client, client) &&
        _boundUserId == requestedUserId) {
      return;
    }

    final active = _starting;
    if (active != null) {
      await active;
      final currentUserId = (client.auth.currentUser?.id ?? '').trim();
      if (_channel != null &&
          identical(_client, client) &&
          _boundUserId == currentUserId &&
          currentUserId == requestedUserId) {
        return;
      }
      return start(client);
    }

    final generation = ++_generation;
    final task = _startForUser(client, requestedUserId, generation);
    _starting = task;
    try {
      await task;
    } finally {
      if (identical(_starting, task)) _starting = null;
    }
  }

  Future<void> _startForUser(
    SupabaseClient client,
    String userId,
    int generation,
  ) async {
    await _closeCurrentChannel();

    if (generation != _generation ||
        (client.auth.currentUser?.id ?? '').trim() != userId) {
      throw StateError('Авторизация изменилась во время подключения.');
    }

    _client = client;
    _boundUserId = userId;

    final channel = client.channel(
      _userChannelName(userId),
      opts: const rt.RealtimeChannelConfig(ack: true, self: false),
    );

    bool isStillThisUser() {
      return generation == _generation &&
          _boundUserId == userId &&
          (client.auth.currentUser?.id ?? '').trim() == userId;
    }

    channel.onBroadcast(
      event: 'lesson_invite',
      callback: (raw, [ref]) {
        if (!isStillThisUser()) return;
        final invitation = LessonInvitation.fromPayload(_unwrap(raw));
        if (invitation.studentId != userId) return;
        if (invitation.lessonId.isEmpty || invitation.teacherId.isEmpty) {
          return;
        }
        _incomingController.add(invitation);
      },
    );

    channel.onBroadcast(
      event: 'lesson_response',
      callback: (raw, [ref]) {
        if (!isStillThisUser()) return;
        final response = LessonInvitationResponse.fromPayload(_unwrap(raw));
        if (response.teacherId != userId) return;
        if (response.lessonId.isEmpty || response.studentId.isEmpty) return;
        _responseController.add(response);
      },
    );

    try {
      await channel.subscribe();
      if (!isStillThisUser()) {
        throw StateError('Авторизация изменилась во время подключения.');
      }
      _channel = channel;
    } catch (_) {
      try {
        await channel.unsubscribe();
      } catch (_) {}
      try {
        await client.removeChannel(channel);
      } catch (_) {}
      if (generation == _generation) {
        _client = null;
        _boundUserId = '';
      }
      rethrow;
    }
  }

  Future<void> _closeCurrentChannel() async {
    final channel = _channel;
    final client = _client;
    _channel = null;
    if (channel != null) {
      try {
        await channel.unsubscribe();
      } catch (_) {}
      try {
        if (client != null) {
          await client.removeChannel(channel);
        }
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    ++_generation;
    await _closeCurrentChannel();
    _client = null;
    _boundUserId = '';
  }

  Future<void> sendInvitation(LessonInvitation invitation) async {
    final client = _client;
    if (client == null) {
      throw StateError('Сервис приглашений на урок не запущен.');
    }
    await start(client);
    await _sendToUser(
      userId: invitation.studentId,
      event: 'lesson_invite',
      payload: invitation.toPayload(),
    );
  }

  Future<void> sendResponse(LessonInvitationResponse response) async {
    final client = _client;
    if (client == null) {
      throw StateError('Сервис приглашений на урок не запущен.');
    }
    await start(client);
    await _sendToUser(
      userId: response.teacherId,
      event: 'lesson_response',
      payload: response.toPayload(),
    );
  }

  Future<void> _sendToUser({
    required String userId,
    required String event,
    required Map<String, dynamic> payload,
  }) async {
    final client = _client;
    if (client == null || userId.trim().isEmpty) {
      throw StateError('Адресат приглашения не определён.');
    }

    final channel = client.channel(
      _userChannelName(userId.trim()),
      opts: const rt.RealtimeChannelConfig(ack: true, self: false),
    );
    try {
      await channel.subscribe();
      await channel.sendBroadcastMessage(event: event, payload: payload);
    } finally {
      try {
        await channel.unsubscribe();
      } catch (_) {}
      try {
        await client.removeChannel(channel);
      } catch (_) {}
    }
  }
}
