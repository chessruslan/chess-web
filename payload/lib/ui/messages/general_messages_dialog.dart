// MAKECHESS_ADMIN_DELETE_MESSAGES_V8_3_20260808
  // MAKECHESS_ADMIN_CASE_REPLIES_V8_1_20260808
// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
// MAKECHESS_GENERAL_MESSAGES_LOCALIZED_V3_2_20260807
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../localization/makechess_localization.dart';

import '../../services/tournament_storage_service.dart';
import '../tournament/tournament_table_editor.dart';
import '../tournament/tournament_game_platform_dialog.dart';

const String kMakeChessMessagesStorageKey = 'makechess_general_messages_v1';
const String kMakeChessTournamentsStorageKey =
    'makechess_teacher_tournaments_v1';

// MAKECHESS_ADMIN_CASE_WORKFLOW_V8_4_20260808
final ValueNotifier<int> makechessAdminReplyUnreadCount =
    ValueNotifier<int>(0);

class AdminCaseNavigationRequest {
  const AdminCaseNavigationRequest({
    required this.targetKind,
    required this.targetId,
    required this.caseId,
  });

  final String targetKind;
  final String targetId;
  final String caseId;

  bool get isValid =>
      targetKind.trim().isNotEmpty &&
      targetId.trim().isNotEmpty &&
      caseId.trim().isNotEmpty;

  factory AdminCaseNavigationRequest.fromMessage(MakeChessMessage message) =>
      AdminCaseNavigationRequest(
        targetKind: '${message.metadata['targetKind'] ?? ''}'.trim(),
        targetId: '${message.metadata['targetId'] ?? ''}'.trim(),
        caseId: '${message.metadata['adminCaseId'] ?? ''}'.trim(),
      );
}

void publishMakeChessAdminReplyUnreadCount(
  List<MakeChessMessage> messages,
  String userId,
) {
  final cleanUserId = userId.trim();
  if (cleanUserId.isEmpty) {
    makechessAdminReplyUnreadCount.value = 0;
    return;
  }
  makechessAdminReplyUnreadCount.value = messages
      .where(
        (message) =>
            message.recipientId == cleanUserId &&
            message.category == 'admin_case_reply' &&
            message.status == 'unread',
      )
      .length;
}

Future<int> refreshMakeChessAdminReplyUnreadCount() async {
  final client = Supabase.instance.client;
  final userId = (client.auth.currentUser?.id ?? '').trim();
  if (userId.isEmpty) {
    makechessAdminReplyUnreadCount.value = 0;
    return 0;
  }
  try {
    final messages =
        await MakeChessMessageRealtimeService.instance.syncFromDatabase();
    publishMakeChessAdminReplyUnreadCount(messages, userId);
  } catch (_) {}
  return makechessAdminReplyUnreadCount.value;
}


class MakeChessMessage {
  const MakeChessMessage({
    required this.id,
    required this.recipientId,
    required this.senderId,
    required this.senderName,
    required this.category,
    required this.title,
    required this.body,
    required this.createdAt,
    this.tournamentId,
    this.status = 'unread',
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String recipientId;
  final String senderId;
  final String senderName;
  final String category;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? tournamentId;
  final String status;
  final Map<String, dynamic> metadata;

  MakeChessMessage copyWith({String? status}) => MakeChessMessage(
        id: id,
        recipientId: recipientId,
        senderId: senderId,
        senderName: senderName,
        category: category,
        title: title,
        body: body,
        createdAt: createdAt,
        tournamentId: tournamentId,
        status: status ?? this.status,
        metadata: metadata,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'recipientId': recipientId,
        'senderId': senderId,
        'senderName': senderName,
        'category': category,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'tournamentId': tournamentId,
        'status': status,
        'metadata': metadata,
      };

  Map<String, dynamic> toDatabaseJson() => <String, dynamic>{
        'id': id,
        'recipient_id': recipientId,
        'sender_id': senderId,
        'sender_name': senderName,
        'category': category,
        'title': title,
        'body': body,
        'created_at': createdAt.toUtc().toIso8601String(),
        'tournament_id': tournamentId,
        'status': status,
        'payload': metadata,
      };

  factory MakeChessMessage.fromJson(Map<String, dynamic> json) {
    return MakeChessMessage(
      id: '${json['id'] ?? ''}',
      recipientId: '${json['recipientId'] ?? ''}',
      senderId: '${json['senderId'] ?? ''}',
      senderName: '${json['senderName'] ?? 'MakeChess'}',
      category: '${json['category'] ?? 'system'}',
      title: '${json['title'] ?? MakeChessLocalization.phrase('Сообщение')}',
      body: '${json['body'] ?? ''}',
      createdAt:
          DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
      tournamentId:
          json['tournamentId'] == null ? null : '${json['tournamentId']}',
      status: '${json['status'] ?? 'unread'}',
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const <String, dynamic>{},
    );
  }

  factory MakeChessMessage.fromDatabaseJson(Map<String, dynamic> json) {
    return MakeChessMessage(
      id: '${json['id'] ?? ''}',
      recipientId: '${json['recipient_id'] ?? ''}',
      senderId: '${json['sender_id'] ?? ''}',
      senderName: '${json['sender_name'] ?? 'MakeChess'}',
      category: '${json['category'] ?? 'system'}',
      title: '${json['title'] ?? MakeChessLocalization.phrase('Сообщение')}',
      body: '${json['body'] ?? ''}',
      createdAt:
          DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.now(),
      tournamentId:
          json['tournament_id'] == null ? null : '${json['tournament_id']}',
      status: '${json['status'] ?? 'unread'}',
      metadata: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const <String, dynamic>{},
    );
  }
}

Future<List<MakeChessMessage>> loadMakeChessMessages() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kMakeChessMessagesStorageKey);
  if (raw == null || raw.trim().isEmpty) return <MakeChessMessage>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <MakeChessMessage>[];
    return decoded
        .whereType<Map>()
        .map((e) => MakeChessMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } catch (_) {
    return <MakeChessMessage>[];
  }
}

Future<void> saveMakeChessMessages(List<MakeChessMessage> messages) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    kMakeChessMessagesStorageKey,
    jsonEncode(messages.map((e) => e.toJson()).toList()),
  );
}

Future<void> addMakeChessMessage(MakeChessMessage message) async {
  final messages = await loadMakeChessMessages();
  messages.insert(0, message);
  await saveMakeChessMessages(messages);
}

class MakeChessMessageRealtimeService {
  MakeChessMessageRealtimeService._();

  static final MakeChessMessageRealtimeService instance =
      MakeChessMessageRealtimeService._();

  final StreamController<MakeChessMessage> _incomingController =
      StreamController<MakeChessMessage>.broadcast();

  Stream<MakeChessMessage> get incoming => _incomingController.stream;

  SupabaseClient? _client;
  RealtimeChannel? _channel;
  String _boundUserId = '';
  Future<void>? _starting;

  String _channelName(String userId) =>
      'makechess:general-messages:user:${userId.trim()}:v1';

  Future<void> start(SupabaseClient client) async {
    final userId = (client.auth.currentUser?.id ?? '').trim();
    if (userId.isEmpty) {
      await stop();
      return;
    }
    if (_channel != null &&
        identical(_client, client) &&
        _boundUserId == userId) {
      return;
    }
    final active = _starting;
    if (active != null) {
      await active;
      return;
    }
    final task = _startInternal(client, userId);
    _starting = task;
    try {
      await task;
    } finally {
      if (identical(_starting, task)) _starting = null;
    }
  }

  Future<void> _startInternal(SupabaseClient client, String userId) async {
    await stop();
    _client = client;
    _boundUserId = userId;
    final channel = client.channel(_channelName(userId));
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'makechess_messages_v1',
      callback: (payload) async {
        final currentId = (client.auth.currentUser?.id ?? '').trim();
        if (currentId != userId || _boundUserId != userId) return;
        await syncFromDatabase(client: client);
        final record = payload.newRecord;
        if (record.isNotEmpty) {
          final message = MakeChessMessage.fromDatabaseJson(record);
          if (message.recipientId == userId) {
            _incomingController.add(message);
          }
        }
      },
    );
    channel.subscribe();
    _channel = channel;
    await syncFromDatabase(client: client);
  }

  Future<List<MakeChessMessage>> syncFromDatabase(
      {SupabaseClient? client}) async {
    final activeClient = client ?? _client ?? Supabase.instance.client;
    final userId = (activeClient.auth.currentUser?.id ?? '').trim();
    if (userId.isEmpty) return loadMakeChessMessages();

    final rows = await activeClient
        .from('makechess_messages_v1')
        .select()
        .eq('recipient_id', userId)
        .order('created_at', ascending: false);
    final remote = (rows as List)
        .whereType<Map>()
        .map((row) => MakeChessMessage.fromDatabaseJson(
              Map<String, dynamic>.from(row),
            ))
        .toList(growable: false);
    final local = await loadMakeChessMessages();
    final merged = <String, MakeChessMessage>{
      for (final message in local) message.id: message,
      for (final message in remote) message.id: message,
    }.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await saveMakeChessMessages(merged);
    publishMakeChessAdminReplyUnreadCount(merged, userId);
    return merged;
  }

  Future<void> send(MakeChessMessage message) async {
    final client = _client ?? Supabase.instance.client;
    final senderId = (client.auth.currentUser?.id ?? '').trim();
    if (senderId.isEmpty) {
      throw StateError(MakeChessLocalization.phrase(
          'Для отправки сообщения требуется вход в аккаунт.'));
    }
    await start(client);
    final recipientId = message.recipientId.trim();
    if (recipientId.isEmpty) {
      throw StateError(
          MakeChessLocalization.phrase('Получатель сообщения не определён.'));
    }
    if (message.senderId != senderId) {
      throw StateError(MakeChessLocalization.phrase(
          'Отправитель сообщения не совпадает с аккаунтом.'));
    }
    await client.from('makechess_messages_v1').insert(message.toDatabaseJson());
  }

  Future<void> updateStatus(String messageId, String status) async {
    final client = _client ?? Supabase.instance.client;
    final values = <String, dynamic>{'status': status};
    if (status == 'read') {
      values['read_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (status == 'accepted' || status == 'declined') {
      values['responded_at'] = DateTime.now().toUtc().toIso8601String();
    }
    await client
        .from('makechess_messages_v1')
        .update(values)
        .eq('id', messageId);
    await syncFromDatabase(client: client);
  }

  Future<void> stop() async {
    final channel = _channel;
    final client = _client;
    _channel = null;
    _client = null;
    _boundUserId = '';
    if (channel != null) {
      try {
        await channel.unsubscribe();
      } catch (_) {}
      if (client != null) {
        try {
          await client.removeChannel(channel);
        } catch (_) {}
      }
    }
  }
}

Future<AdminCaseNavigationRequest?> showGeneralMessagesDialog({
  required BuildContext context,
  required String currentUserId,
  required String currentUserName,
}) {
  return showDialog<AdminCaseNavigationRequest>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _GeneralMessagesDialog(
      currentUserId: currentUserId,
      currentUserName: currentUserName,
    ),
  );
}

class _GeneralMessagesDialog extends StatefulWidget {
  const _GeneralMessagesDialog({
    required this.currentUserId,
    required this.currentUserName,
  });

  final String currentUserId;
  final String currentUserName;

  @override
  State<_GeneralMessagesDialog> createState() => _GeneralMessagesDialogState();
}

String _makeChessLocalizedMessageTitle(MakeChessMessage message) {
  final raw = message.title.trim();

  final schoolInvite =
      RegExp(r'^Приглашение школы на турнир «(.+)»$').firstMatch(raw);
  if (schoolInvite != null) {
    return MakeChessLocalization.phrase(
      'Приглашение школы на турнир «{name}»',
      params: <String, Object?>{'name': schoolInvite.group(1) ?? ''},
    );
  }

  final invite = RegExp(r'^Приглашение на турнир «(.+)»$').firstMatch(raw);
  if (invite != null) {
    return MakeChessLocalization.phrase(
      'Приглашение на турнир «{name}»',
      params: <String, Object?>{'name': invite.group(1) ?? ''},
    );
  }

  final call = RegExp(r'^Скоро начнётся турнир «(.+)»$').firstMatch(raw);
  if (call != null) {
    return MakeChessLocalization.phrase(
      'Скоро начнётся турнир «{name}»',
      params: <String, Object?>{'name': call.group(1) ?? ''},
    );
  }

  return MakeChessLocalization.phrase(raw);
}

String _makeChessLocalizedMessageBody(MakeChessMessage message) {
  final raw = message.body.trim();
  if (message.category.startsWith('admin_')) return raw;

  final call = RegExp(
    r'^Турнир начнётся через ([0-9]+) мин\. Откройте игровую платформу и приготовьтесь к игре\.$',
  ).firstMatch(raw);
  if (call != null) {
    return MakeChessLocalization.phrase(
      'Турнир начнётся через {minutes} мин. Откройте игровую платформу и приготовьтесь к игре.',
      params: <String, Object?>{'minutes': call.group(1) ?? ''},
    );
  }

  final schoolInvite = RegExp(
    r'^Школа «(.+?)» приглашена на турнир\. Свободных мест: ([0-9]+)\.(.*)$',
  ).firstMatch(raw);
  if (schoolInvite != null) {
    var result = MakeChessLocalization.phrase(
      'Школа «{school}» приглашена на турнир. Свободных мест: {count}.',
      params: <String, Object?>{
        'school': schoolInvite.group(1) ?? '',
        'count': schoolInvite.group(2) ?? '',
      },
    );
    var tail = (schoolInvite.group(3) ?? '').trim();
    const russianPrefix = 'Выберите учеников, которые будут представлять школу';
    if (tail.startsWith(russianPrefix)) {
      tail =
          '${MakeChessLocalization.phrase(russianPrefix)}${tail.substring(russianPrefix.length)}';
    }
    if (tail.isNotEmpty) result = '$result $tail';
    return result;
  }

  final standardInvite = RegExp(
    r'^(.+?) • (.+?) • (.+?) • ([0-9]+) туров\. Откройте сообщение и подтвердите участие\.$',
  ).firstMatch(raw);
  if (standardInvite != null) {
    final type = MakeChessLocalization.phrase(standardInvite.group(1) ?? '');
    final format = MakeChessLocalization.phrase(standardInvite.group(2) ?? '');
    final control = standardInvite.group(3) ?? '';
    final ending = MakeChessLocalization.phrase(
      '{rounds} туров. Откройте сообщение и подтвердите участие.',
      params: <String, Object?>{'rounds': standardInvite.group(4) ?? ''},
    );
    return '$type • $format • $control • $ending';
  }

  return MakeChessLocalization.phrase(raw);
}

class _GeneralMessagesDialogState extends State<_GeneralMessagesDialog> {
  bool _loading = true;
  String _filter = 'all';
  List<MakeChessMessage> _messages = <MakeChessMessage>[];
  StreamSubscription<MakeChessMessage>? _incomingSub;

  bool _isTournamentCall(MakeChessMessage message) =>
      message.tournamentId != null &&
      (message.category == 'tournament_call' ||
          (message.category == 'system' &&
              message.title.toLowerCase().contains('турнир')));

  @override
  void initState() {
    super.initState();
    _incomingSub =
        MakeChessMessageRealtimeService.instance.incoming.listen((_) {
      _reload();
    });
    _reload();
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    List<MakeChessMessage> all;
    try {
      all = await MakeChessMessageRealtimeService.instance.syncFromDatabase();
    } catch (_) {
      all = await loadMakeChessMessages();
    }
    if (!mounted) return;
    setState(() {
      _messages = all
          .where((e) =>
              e.recipientId == widget.currentUserId || e.recipientId == '*')
          .toList();
      _loading = false;
    });
  }

  Iterable<MakeChessMessage> get _visible {
    if (_filter == 'all') return _messages;
    if (_filter == 'unread')
      return _messages.where((e) => e.status == 'unread');
    if (_filter == 'tournament_invite') {
      return _messages.where((e) => e.category.startsWith('tournament'));
    }
    return _messages.where((e) => e.category == _filter);
  }

  Future<void> _openTournamentPlatform(MakeChessMessage message) async {
    final tournamentId = message.tournamentId?.trim() ?? '';
    if (tournamentId.isEmpty) return;
    try {
      if (message.status == 'unread') {
        await MakeChessMessageRealtimeService.instance
            .updateStatus(message.id, 'read');
      }
      final visible =
          await TournamentStorageService.instance.loadVisibleTournaments();
      Map<String, dynamic>? tournament;
      for (final item in visible) {
        if ('${item['id'] ?? ''}' == tournamentId &&
            '${item['_ownerId'] ?? ''}' == message.senderId) {
          tournament = item;
          break;
        }
      }
      if (tournament == null) {
        throw StateError(MakeChessLocalization.phrase('Турнир не найден'));
      }
      final userId = widget.currentUserId;
      var playAsBlack = false;
      var opponentName = MakeChessLocalization.phrase('Соперник');
      final pairings = tournament['pairings'];
      if (pairings is List) {
        for (final raw in pairings) {
          if (raw is! Map) continue;
          final whiteId = '${raw['whiteId'] ?? ''}';
          final blackId = '${raw['blackId'] ?? ''}';
          if (whiteId != userId && blackId != userId) continue;
          playAsBlack = blackId == userId;
          final opponentId = playAsBlack ? whiteId : blackId;
          final names = tournament['participantNames'];
          if (names is Map) {
            opponentName = '${names[opponentId] ?? opponentId}';
          }
          break;
        }
      }
      if (!mounted) return;
      await showTournamentGamePlatform(
        context: context,
        tournamentName:
            '${tournament['name'] ?? MakeChessLocalization.phrase('Турнир')}',
        gameActive: '${tournament['status'] ?? ''}' == 'running',
        playAsBlack: playAsBlack,
        opponentName: opponentName,
        tournamentId: tournamentId,
        ownerId: message.senderId,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: MakeChessLocalizedText(
            MakeChessLocalization.phrase(
              'Не удалось открыть игровую платформу: {error}',
              params: <String, Object?>{'error': error},
            ),
          ),
        ),
      );
    }
  }

  Future<void> _openMessage(MakeChessMessage message) async {
    final messages = await loadMakeChessMessages();
    final index = messages.indexWhere((e) => e.id == message.id);
    if (index >= 0 && messages[index].status == 'unread') {
      messages[index] = messages[index].copyWith(status: 'read');
      await saveMakeChessMessages(messages);
      try {
        await MakeChessMessageRealtimeService.instance
            .updateStatus(message.id, 'read');
      } catch (_) {}
    }
    if (!mounted) return;

    if (message.category == 'admin_case_reply') {
      final request = AdminCaseNavigationRequest.fromMessage(message);
      if (request.isValid) {
        Navigator.of(context).pop(request);
        return;
      }
    }

    if (_isAdminCaseMessage(message)) {
      await _openAdminCaseMessage(message);
      await _reload();
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111C27),
        title: MakeChessLocalizedText(_makeChessLocalizedMessageTitle(message)),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MakeChessLocalizedText(
                  MakeChessLocalization.phrase(
                    'Отправитель: {name}',
                    params: <String, Object?>{'name': message.senderName},
                  ),
                  style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 12),
              MakeChessLocalizedText(_makeChessLocalizedMessageBody(message)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                MakeChessLocalizedText(MakeChessLocalization.phrase('Закрыть')),
          ),
          if (message.category == 'tournament_invite' &&
              message.tournamentId != null)
            OutlinedButton.icon(
              onPressed: () async {
                await _previewTournament(message);
              },
              icon: const Icon(Icons.visibility_outlined),
              label: MakeChessLocalizedText(
                  MakeChessLocalization.phrase('Посмотреть турнир')),
            ),
          if (message.category == 'tournament_invite' &&
              message.status != 'accepted')
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: MakeChessLocalizedText(
                  MakeChessLocalization.phrase('Принять приглашение')),
            ),
          if (_isTournamentCall(message))
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx, false);
                _openTournamentPlatform(message);
              },
              icon: const Icon(Icons.sports_esports),
              label: MakeChessLocalizedText(
                  MakeChessLocalization.phrase('Перейти на игровую платформу')),
            ),
        ],
      ),
    );
    if (accepted == true && message.tournamentId != null) {
      await _acceptTournamentInvitation(message);
    }
    await _reload();
  }

  Future<void> _previewTournament(MakeChessMessage message) async {
    final tournamentId = message.tournamentId?.trim() ?? '';
    if (tournamentId.isEmpty) return;
    try {
      final data =
          await TournamentStorageService.instance.loadInvitedTournamentTable(
        ownerId: message.senderId,
        tournamentId: tournamentId,
      );
      if (!mounted) return;
      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: MakeChessLocalizedText(
              MakeChessLocalization.phrase(
                  'Организатор ещё не создал таблицу турнира'),
            ),
          ),
        );
        return;
      }
      final participants = data['participants'] is List
          ? (data['participants'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : <Map<String, dynamic>>[];
      final results = data['results'] is Map
          ? Map<String, String>.fromEntries(
              (data['results'] as Map).entries.map(
                    (entry) => MapEntry('${entry.key}', '${entry.value}'),
                  ),
            )
          : <String, String>{};
      int number(String key, int fallback) =>
          int.tryParse('${data[key] ?? ''}') ?? fallback;
      await showTournamentTableEditor(
        context: context,
        tournamentId: tournamentId,
        initialName: '${data['name'] ?? message.title}',
        initialType: '${data['type'] ?? ''}',
        initialStatus: '${data['status'] ?? ''}',
        initialMinutes: number('minutes', 5),
        initialIncrement: number('increment', 0),
        initialRounds: number('rounds', 1),
        initialParticipantNames: participants
            .map((item) =>
                '${item['name'] ?? MakeChessLocalization.phrase('Участник')}')
            .toList(growable: false),
        maxParticipants: number(
          'maxParticipants',
          participants.isEmpty ? 8 : participants.length,
        ),
        previewMode: true,
        initialJudge: '${data['judge'] ?? ''}',
        initialVenue: '${data['venue'] ?? ''}',
        initialOrganizer: '${data['organizer'] ?? message.senderName}',
        initialStart: '${data['start'] ?? ''}',
        onParticipate: message.status == 'accepted'
            ? null
            : () async {
                final result = await TournamentStorageService.instance
                    .requestParticipation(
                  ownerId: message.senderId,
                  tournamentId: tournamentId,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: MakeChessLocalizedText(result == 'joined'
                        ? MakeChessLocalization.phrase(
                            'Вы добавлены в турнирную таблицу')
                        : MakeChessLocalization.phrase(
                            'Заявка отправлена организатору')),
                  ),
                );
              },
        initialEnd: '${data['end'] ?? ''}',
        initialAge: '${data['age'] ?? ''}',
        initialParticipantsData: participants,
        initialResults: results,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: MakeChessLocalizedText(
            MakeChessLocalization.phrase(
              'Не удалось открыть турнир: {error}',
              params: <String, Object?>{'error': error},
            ),
          ),
        ),
      );
    }
  }


  // MAKECHESS_ADMIN_CASE_REPLIES_V8_1_20260808
  bool _isAdminCaseMessage(MakeChessMessage message) =>
      message.category == 'admin_info' ||
      message.category == 'admin_warning' ||
      message.category == 'admin_block' ||
      message.category == 'admin_restriction' ||
      message.category == 'admin_delete';

  String _formatAdminCaseDate(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _openAdminCaseMessage(MakeChessMessage message) async {
    final replyController = TextEditingController();
    var replyMode = false;
    var busy = false;
    final rawDueAt = '${message.metadata['dueAt'] ?? ''}';
    final dueAt = DateTime.tryParse(rawDueAt);

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final canReply = replyController.text.trim().isNotEmpty && !busy;
            return AlertDialog(
              backgroundColor: const Color(0xFF111C27),
              title: Text(
                MakeChessLocalization.phrase(message.title),
              ),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withOpacity(.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.cyanAccent.withOpacity(.3)),
                        ),
                        child: Text(
                          MakeChessLocalization.phrase(
                            'MakeChess уважает ваше право знать причину',
                          ),
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        MakeChessLocalization.phrase(
                          'Отправитель: {name}',
                          params: <String, Object?>{'name': message.senderName},
                        ),
                        style: const TextStyle(color: Colors.white54),
                      ),
                      if (dueAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          MakeChessLocalization.phrase(
                            'Срок: {date}',
                            params: <String, Object?>{
                              'date': _formatAdminCaseDate(dueAt),
                            },
                          ),
                          style: const TextStyle(color: Colors.amberAccent),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SelectableText(message.body),
                      if (replyMode) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: replyController,
                          autofocus: true,
                          minLines: 3,
                          maxLines: 7,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            labelText:
                                MakeChessLocalization.phrase('Напишите ответ'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(MakeChessLocalization.phrase('Закрыть')),
                ),
                if (!replyMode)
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => setDialogState(() => replyMode = true),
                    icon: const Icon(Icons.reply_outlined),
                    label: Text(MakeChessLocalization.phrase('Ответить')),
                  ),
                if (!replyMode)
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            setDialogState(() => busy = true);
                            try {
                              await _sendAdminCaseReply(
                                source: message,
                                fixed: true,
                                text: '',
                              );
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    MakeChessLocalization.phrase(
                                      'Вы сообщили администратору, что проблема исправлена',
                                    ),
                                  ),
                                ),
                              );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                            } catch (error) {
                              if (dialogContext.mounted) {
                                setDialogState(() => busy = false);
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$error')),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.task_alt),
                    label: Text(
                      MakeChessLocalization.phrase(
                        'Сообщить, что исправлено',
                      ),
                    ),
                  ),
                if (replyMode)
                  FilledButton.icon(
                    onPressed: canReply
                        ? () async {
                            setDialogState(() => busy = true);
                            try {
                              await _sendAdminCaseReply(
                                source: message,
                                fixed: false,
                                text: replyController.text.trim(),
                              );
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    MakeChessLocalization.phrase(
                                      'Ваш ответ отправлен администратору',
                                    ),
                                  ),
                                ),
                              );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                            } catch (error) {
                              if (dialogContext.mounted) {
                                setDialogState(() => busy = false);
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$error')),
                                );
                              }
                            }
                          }
                        : null,
                    icon: const Icon(Icons.send_outlined),
                    label: Text(
                      MakeChessLocalization.phrase('Отправить ответ'),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    } finally {
      replyController.dispose();
    }
  }

  Future<void> _sendAdminCaseReply({
    required MakeChessMessage source,
    required bool fixed,
    required String text,
  }) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError(
        MakeChessLocalization.phrase(
          'Для административного сообщения требуется вход в аккаунт',
        ),
      );
    }
    final recipientId = source.senderId.trim();
    if (recipientId.isEmpty) {
      throw StateError(
        MakeChessLocalization.phrase('У объекта нет связанного получателя'),
      );
    }
    final userMetadata = user.userMetadata ?? const <String, dynamic>{};
    final senderName =
        '${userMetadata['nickname'] ?? userMetadata['name'] ?? user.email ?? widget.currentUserName}';
    final caseId = '${source.metadata['adminCaseId'] ?? source.id}';

    await MakeChessMessageRealtimeService.instance.start(client);
    await MakeChessMessageRealtimeService.instance.send(
      MakeChessMessage(
        id: 'admin_case_reply_${DateTime.now().microsecondsSinceEpoch}',
        recipientId: recipientId,
        senderId: user.id,
        senderName: senderName,
        category: 'admin_case_reply',
        title: fixed
            ? 'Пользователь сообщил: исправлено'
            : 'Ответ на административное сообщение',
        body: fixed
            ? (text.trim().isEmpty ? 'Исправлено' : text.trim())
            : text.trim(),
        createdAt: DateTime.now(),
        tournamentId: source.tournamentId,
        metadata: <String, dynamic>{
          'adminCaseId': caseId,
          'replyStatus': fixed ? 'fixed' : 'reply',
          'targetId': '${source.metadata['targetId'] ?? widget.currentUserId}',
          'targetKind': '${source.metadata['targetKind'] ?? 'player'}',
          'sourceMessageId': source.id,
          'recipientName': source.senderName,
        },
      ),
    );
  }


  Future<void> _acceptTournamentInvitation(MakeChessMessage message) async {
    try {
      await TournamentStorageService.instance.acceptInvitation(message.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: MakeChessLocalizedText(
              MakeChessLocalization.phrase('Не удалось принять приглашение')),
        ),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kMakeChessTournamentsStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: MakeChessLocalizedText(
              MakeChessLocalization.phrase('Приглашение принято')),
        ),
      );
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final tournaments = decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final index = tournaments
          .indexWhere((e) => '${e['id'] ?? ''}' == message.tournamentId);
      if (index < 0) return;
      final tournament = tournaments[index];
      final ids = (tournament['participantIds'] is List)
          ? List<String>.from(
              (tournament['participantIds'] as List).map((e) => '$e'))
          : <String>[];
      final names = (tournament['participantNames'] is Map)
          ? Map<String, String>.fromEntries(
              (tournament['participantNames'] as Map).entries.map(
                    (e) => MapEntry('${e.key}', '${e.value}'),
                  ),
            )
          : <String, String>{};
      if (!ids.contains(widget.currentUserId)) ids.add(widget.currentUserId);
      names[widget.currentUserId] = widget.currentUserName;
      tournament['participantIds'] = ids;
      tournament['participantNames'] = names;
      tournaments[index] = tournament;
      await prefs.setString(
          kMakeChessTournamentsStorageKey, jsonEncode(tournaments));

      final allMessages = await loadMakeChessMessages();
      final messageIndex = allMessages.indexWhere((e) => e.id == message.id);
      if (messageIndex >= 0) {
        allMessages[messageIndex] =
            allMessages[messageIndex].copyWith(status: 'accepted');
        await saveMakeChessMessages(allMessages);
      }
      await MakeChessMessageRealtimeService.instance.syncFromDatabase();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: MakeChessLocalizedText(
            MakeChessLocalization.phrase(
                'Приглашение принято. Вы добавлены в турнир.'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: MakeChessLocalizedText(
              MakeChessLocalization.phrase('Не удалось принять приглашение')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible.toList();
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 980,
        height: 690,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1721),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.cyanAccent.withOpacity(.55)),
        ),
        child: Column(
          children: [
            _header(),
            _filters(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty
                      ? Center(
                          child: MakeChessLocalizedText(
                            MakeChessLocalization.phrase('Сообщений пока нет'),
                            style: const TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final message = visible[index];
                            return ListTile(
                              tileColor: message.status == 'unread'
                                  ? Colors.cyanAccent.withOpacity(.08)
                                  : Colors.white.withOpacity(.025),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: message.status == 'unread'
                                      ? Colors.cyanAccent.withOpacity(.45)
                                      : Colors.white.withOpacity(.08),
                                ),
                              ),
                              leading: Icon(
                                message.category.startsWith('tournament')
                                    ? Icons.emoji_events
                                    : Icons.notifications,
                                color: message.status == 'unread'
                                    ? Colors.cyanAccent
                                    : Colors.white54,
                              ),
                              title: MakeChessLocalizedText(
                                  _makeChessLocalizedMessageTitle(message)),
                              subtitle: MakeChessLocalizedText(
                                '${message.senderName} • ${_date(message.createdAt)}\n'
                                '${_makeChessLocalizedMessageBody(message)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: message.category ==
                                          'tournament_join_request' &&
                                      message.status != 'accepted' &&
                                      message.status != 'declined'
                                  ? ActionChip(
                                      avatar: const Icon(Icons.person_add,
                                          size: 16),
                                      label: MakeChessLocalizedText(
                                          MakeChessLocalization.phrase(
                                              'Принять участника')),
                                      onPressed: () async {
                                        await TournamentStorageService.instance
                                            .respondParticipationRequest(
                                          messageId: message.id,
                                          accept: true,
                                        );
                                        await MakeChessMessageRealtimeService
                                            .instance
                                            .syncFromDatabase();
                                      },
                                    )
                                  : _isTournamentCall(message)
                                      ? ActionChip(
                                          avatar: const Icon(
                                            Icons.sports_esports,
                                            size: 16,
                                          ),
                                          label: MakeChessLocalizedText(
                                              MakeChessLocalization.phrase(
                                                  'Перейти на игровую платформу')),
                                          onPressed: () =>
                                              _openTournamentPlatform(message),
                                        )
                                      : message.status == 'accepted'
                                          ? message.category ==
                                                      'tournament_invite' &&
                                                  message.tournamentId != null
                                              ? ActionChip(
                                                  avatar: const Icon(
                                                    Icons.visibility_outlined,
                                                    size: 16,
                                                  ),
                                                  label: MakeChessLocalizedText(
                                                      MakeChessLocalization.phrase(
                                                          'Принято / Посмотреть')),
                                                  onPressed: () =>
                                                      _previewTournament(
                                                          message),
                                                )
                                              : Chip(
                                                  label: MakeChessLocalizedText(
                                                      MakeChessLocalization
                                                          .phrase('Принято')))
                                          : message.status == 'unread'
                                              ? const Icon(Icons.circle,
                                                  size: 10,
                                                  color: Colors.cyanAccent)
                                              : null,
                              onTap: () => _openMessage(message),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: Color(0xFF17222E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: Row(
          children: [
            const Icon(Icons.mail_outline, color: Colors.cyanAccent),
            const SizedBox(width: 10),
            MakeChessLocalizedText(
              MakeChessLocalization.phrase('Сообщения'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );

  Widget _filters() {
    final filters = <String, String>{
      'all': MakeChessLocalization.phrase('Все'),
      'unread': MakeChessLocalization.phrase('Непрочитанные'),
      'tournament_invite': MakeChessLocalization.phrase('Турниры'),
      'learning': MakeChessLocalization.phrase('Обучение'),
      'game': MakeChessLocalization.phrase('Игры'),
      'system': MakeChessLocalization.phrase('Системные'),
    };
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        children: filters.entries
            .map(
              (e) => ChoiceChip(
                selected: _filter == e.key,
                label: MakeChessLocalizedText(e.value),
                onSelected: (_) => setState(() => _filter = e.key),
              ),
            )
            .toList(),
      ),
    );
  }

  String _date(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year} ${two(value.hour)}:${two(value.minute)}';
  }
}
