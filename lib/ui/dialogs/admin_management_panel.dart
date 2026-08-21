// MAKECHESS_ADMIN_CASE_WORKFLOW_V8_4_20260808
// MAKECHESS_ADMIN_DELETE_V8_3_20260808
// MAKECHESS_ADMIN_CASES_V8_1_20260808
//
// Administrative moderation workspace.
// Core rule: no block or restriction exists without a visible message explaining why.
// Warning timers only remind the administrator; they NEVER block automatically.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../localization/makechess_localization.dart';
import '../../services/teacher_account_store.dart';
import '../../services/tournament_storage_service.dart';
import '../app_style.dart';
import '../messages/general_messages_dialog.dart';
import '../tournament/tournament_table_editor.dart';

enum AdminEntityKind { player, school, teacher, tournament }

extension AdminEntityKindUi on AdminEntityKind {
  String get label => switch (this) {
        AdminEntityKind.player => 'Игроки',
        AdminEntityKind.school => 'Школы',
        AdminEntityKind.teacher => 'Учителя',
        AdminEntityKind.tournament => 'Турниры',
      };

  IconData get icon => switch (this) {
        AdminEntityKind.player => Icons.people_outline,
        AdminEntityKind.school => Icons.school_outlined,
        AdminEntityKind.teacher => Icons.co_present_outlined,
        AdminEntityKind.tournament => Icons.emoji_events_outlined,
      };
}

class AdminTarget {
  const AdminTarget({
    required this.id,
    required this.name,
    required this.recipientId,
    required this.kind,
    this.subtitle = '',
    this.raw = const <String, dynamic>{},
  });

  final String id;
  final String name;
  final String recipientId;
  final AdminEntityKind kind;
  final String subtitle;
  final Map<String, dynamic> raw;
}

class AdminCaseEvent {
  const AdminCaseEvent({
    required this.id,
    required this.createdAt,
    required this.actor,
    required this.type,
    required this.text,
  });

  final String id;
  final DateTime createdAt;
  final String actor;
  final String type;
  final String text;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'actor': actor,
        'type': type,
        'text': text,
      };

  factory AdminCaseEvent.fromJson(Map<String, dynamic> json) => AdminCaseEvent(
        id: '${json['id'] ?? ''}',
        createdAt:
            DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
        actor: '${json['actor'] ?? 'admin'}',
        type: '${json['type'] ?? 'info'}',
        text: '${json['text'] ?? ''}',
      );
}

class AdminCaseRecord {
  const AdminCaseRecord({
    required this.id,
    required this.targetId,
    required this.targetName,
    required this.targetKind,
    required this.recipientId,
    required this.createdAt,
    required this.updatedAt,
    required this.action,
    required this.status,
    required this.message,
    required this.blocked,
    required this.restrictions,
    required this.events,
    this.dueAt,
  });

  final String id;
  final String targetId;
  final String targetName;
  final String targetKind;
  final String recipientId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String action;
  final String status;
  final String message;
  final bool blocked;
  final Map<String, bool> restrictions;
  final List<AdminCaseEvent> events;
  final DateTime? dueAt;

  AdminCaseRecord copyWith({
    DateTime? updatedAt,
    String? action,
    String? status,
    String? message,
    bool? blocked,
    Map<String, bool>? restrictions,
    List<AdminCaseEvent>? events,
    DateTime? dueAt,
    bool clearDueAt = false,
  }) =>
      AdminCaseRecord(
        id: id,
        targetId: targetId,
        targetName: targetName,
        targetKind: targetKind,
        recipientId: recipientId,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        action: action ?? this.action,
        status: status ?? this.status,
        message: message ?? this.message,
        blocked: blocked ?? this.blocked,
        restrictions: restrictions ?? this.restrictions,
        events: events ?? this.events,
        dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'targetId': targetId,
        'targetName': targetName,
        'targetKind': targetKind,
        'recipientId': recipientId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'action': action,
        'status': status,
        'message': message,
        'blocked': blocked,
        'restrictions': restrictions,
        'events': events.map((item) => item.toJson()).toList(),
        'dueAt': dueAt?.toIso8601String(),
      };

  factory AdminCaseRecord.fromJson(Map<String, dynamic> json) {
    final rawRestrictions = json['restrictions'];
    final rawEvents = json['events'];
    return AdminCaseRecord(
      id: '${json['id'] ?? ''}',
      targetId: '${json['targetId'] ?? ''}',
      targetName: '${json['targetName'] ?? ''}',
      targetKind: '${json['targetKind'] ?? ''}',
      recipientId: '${json['recipientId'] ?? ''}',
      createdAt:
          DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse('${json['updatedAt'] ?? ''}') ?? DateTime.now(),
      action: '${json['action'] ?? 'info'}',
      status: '${json['status'] ?? 'open'}',
      message: '${json['message'] ?? ''}',
      blocked: json['blocked'] == true,
      restrictions: rawRestrictions is Map
          ? rawRestrictions.map(
              (key, value) => MapEntry('$key', value == true),
            )
          : const <String, bool>{},
      events: rawEvents is List
          ? rawEvents
              .whereType<Map>()
              .map(
                (item) => AdminCaseEvent.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const <AdminCaseEvent>[],
      dueAt: DateTime.tryParse('${json['dueAt'] ?? ''}'),
    );
  }
}

class AdminModerationStore {
  AdminModerationStore._();

  static final AdminModerationStore instance = AdminModerationStore._();

  static const String _casesKey = 'makechess_admin_cases_v1';
  static const String _archiveSettingsKey =
      'makechess_admin_archive_settings_v1';
  static const String _deletedTargetsKey = 'makechess_admin_deleted_targets_v1';

  Future<List<AdminCaseRecord>> loadCases() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_casesKey);
    if (raw == null || raw.trim().isEmpty) return <AdminCaseRecord>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <AdminCaseRecord>[];
      final result = decoded
          .whereType<Map>()
          .map(
            (item) => AdminCaseRecord.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
      result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return result;
    } catch (_) {
      return <AdminCaseRecord>[];
    }
  }

  Future<void> saveCases(List<AdminCaseRecord> cases) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _casesKey,
      jsonEncode(cases.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> upsertCase(AdminCaseRecord value) async {
    final cases = await loadCases();
    final index = cases.indexWhere((item) => item.id == value.id);
    if (index >= 0) {
      cases[index] = value;
    } else {
      cases.insert(0, value);
    }
    await saveCases(cases);
  }

  Future<Map<String, bool>> loadArchiveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_archiveSettingsKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, bool>{
        'users': true,
        'games': true,
        'tournaments': true,
        'schoolsTeachers': true,
      };
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return <String, bool>{
          'users': decoded['users'] != false,
          'games': decoded['games'] != false,
          'tournaments': decoded['tournaments'] != false,
          'schoolsTeachers': decoded['schoolsTeachers'] != false,
        };
      }
    } catch (_) {}
    return <String, bool>{
      'users': true,
      'games': true,
      'tournaments': true,
      'schoolsTeachers': true,
    };
  }

  Future<void> saveArchiveSettings(Map<String, bool> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_archiveSettingsKey, jsonEncode(settings));
  }

  Future<Set<String>> loadDeletedTargets() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_deletedTargetsKey) ?? const <String>[])
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  Future<void> markTargetDeleted(AdminTarget target) async {
    final prefs = await SharedPreferences.getInstance();
    final deleted = await loadDeletedTargets();
    deleted.add('${target.kind.name}:${target.id}');
    await prefs.setStringList(
      _deletedTargetsKey,
      deleted.toList()..sort(),
    );
  }

  Future<void> restoreTarget(AdminTarget target) async {
    final prefs = await SharedPreferences.getInstance();
    final deleted = await loadDeletedTargets();
    deleted.remove('${target.kind.name}:${target.id}');
    await prefs.setStringList(
      _deletedTargetsKey,
      deleted.toList()..sort(),
    );
  }

  Future<void> deleteCase(String caseId) async {
    final cases = await loadCases();
    cases.removeWhere((item) => item.id == caseId);
    await saveCases(cases);
  }
}

class AdminManagementPanel extends StatefulWidget {
  const AdminManagementPanel({
    super.key,
    required this.kind,
    this.initialTargetId,
    this.initialCaseId,
  });

  final AdminEntityKind kind;
  final String? initialTargetId;
  final String? initialCaseId;

  @override
  State<AdminManagementPanel> createState() => _AdminManagementPanelState();
}

class _AdminManagementPanelState extends State<AdminManagementPanel> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _actionText = TextEditingController();
  final TextEditingController _warningDays = TextEditingController(text: '10');

  List<AdminTarget> _targets = <AdminTarget>[];
  List<AdminCaseRecord> _cases = <AdminCaseRecord>[];
  List<MakeChessMessage> _caseReplies = <MakeChessMessage>[];

  AdminTarget? _selected;
  String? _selectedCaseId;
  bool _loading = true;
  bool _sending = false;
  bool _reminderEnabled = false;
  bool _showRestrictions = true;
  String? _deleteConfirmTargetId;
  Timer? _timer;

  final Map<String, bool> _restrictionDraft = <String, bool>{
    'messages': false,
    'tournamentParticipation': false,
    'tournamentCreation': false,
    'video': false,
    'assignments': false,
    'students': false,
    'publishing': false,
    'registration': false,
    'tournamentStop': false,
  };

  String _t(
    String source, {
    Map<String, Object?> params = const <String, Object?>{},
  }) =>
      MakeChessLocalization.phrase(source, params: params);

  @override
  void initState() {
    super.initState();
    _actionText.addListener(_refreshButtons);
    _search.addListener(_refreshButtons);
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void didUpdateWidget(covariant AdminManagementPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind ||
        oldWidget.initialTargetId != widget.initialTargetId ||
        oldWidget.initialCaseId != widget.initialCaseId) {
      _selected = null;
      _selectedCaseId = widget.initialCaseId;
      _targets = <AdminTarget>[];
      _actionText.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    _actionText.dispose();
    _warningDays.dispose();
    super.dispose();
  }

  void _refreshButtons() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final loadedCases = await AdminModerationStore.instance.loadCases();
    List<AdminTarget> targets;
    try {
      targets = await _loadTargets();
    } catch (error) {
      targets = <AdminTarget>[];
      if (mounted) {
        _snack(
          _t(
            'Не удалось загрузить данные: {error}',
            params: <String, Object?>{'error': '$error'},
          ),
        );
      }
    }

    final deletedTargets =
        await AdminModerationStore.instance.loadDeletedTargets();
    final requestedTargetId = (widget.initialTargetId ?? '').trim();
    targets = targets
        .where(
          (item) =>
              !deletedTargets.contains('${item.kind.name}:${item.id}') ||
              (requestedTargetId.isNotEmpty && item.id == requestedTargetId),
        )
        .toList(growable: false);

    if (!mounted) return;
    setState(() {
      _cases = loadedCases;
      _targets = targets;
      _selectedCaseId = widget.initialCaseId ?? _selectedCaseId;

      if (requestedTargetId.isNotEmpty) {
        final requested =
            targets.where((item) => item.id == requestedTargetId).toList();
        if (requested.isNotEmpty) {
          _selected = requested.first;
        }
      }

      if (_selected == null && targets.isNotEmpty) {
        _selected = targets.first;
      } else if (_selected != null) {
        final selectedId = _selected!.id;
        final matches = targets.where((item) => item.id == selectedId).toList();
        _selected = matches.isEmpty
            ? (targets.isEmpty ? null : targets.first)
            : matches.first;
      }
      _loading = false;
    });
    await _refreshReplies();
  }

  Future<List<AdminTarget>> _loadTargets() async {
    switch (widget.kind) {
      case AdminEntityKind.player:
        return _loadPlayers();
      case AdminEntityKind.school:
      case AdminEntityKind.teacher:
        return _loadSchoolsAndTeachers(widget.kind);
      case AdminEntityKind.tournament:
        return _loadTournaments();
    }
  }

  Future<List<AdminTarget>> _loadPlayers() async {
    final raw = await Supabase.instance.client.from('profiles').select();
    final rows = raw is List ? raw : const <dynamic>[];
    final result = <AdminTarget>[];
    for (final item in rows.whereType<Map>()) {
      final row = Map<String, dynamic>.from(item);
      final id = '${row['id'] ?? ''}'.trim();
      if (id.isEmpty) continue;
      final name =
          '${row['nickname'] ?? row['name'] ?? row['email'] ?? id}'.trim();
      final rating = '${row['rating'] ?? ''}'.trim();
      final country = '${row['country'] ?? ''}'.trim();
      final subtitleParts = <String>[
        if (rating.isNotEmpty) '${_t('Рейтинг')}: $rating',
        if (country.isNotEmpty) country,
      ];
      result.add(
        AdminTarget(
          id: id,
          name: name.isEmpty ? id : name,
          recipientId: id,
          kind: AdminEntityKind.player,
          subtitle: subtitleParts.join(' • '),
          raw: row,
        ),
      );
    }
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  Future<List<AdminTarget>> _loadSchoolsAndTeachers(
    AdminEntityKind kind,
  ) async {
    final accounts = await TeacherAccountStore.instance.loadAccounts();
    final result = <AdminTarget>[];
    for (final dynamic account in accounts) {
      final id = '${account.id}'.trim();
      final schoolName = '${account.schoolName}'.trim();
      final login = '${account.login}'.trim();
      final ownerUserId = '${account.ownerUserId}'.trim();
      final about = '${account.about}'.trim();
      if (id.isEmpty) continue;
      final isSchool = kind == AdminEntityKind.school;
      result.add(
        AdminTarget(
          id: isSchool ? id : (ownerUserId.isEmpty ? id : ownerUserId),
          name: isSchool
              ? (schoolName.isEmpty ? login : schoolName)
              : (login.isEmpty ? schoolName : login),
          recipientId: ownerUserId,
          kind: kind,
          subtitle: isSchool
              ? '${_t('Учитель')}: ${login.isEmpty ? '—' : login}'
              : '${_t('Школа')}: ${schoolName.isEmpty ? '—' : schoolName}',
          raw: <String, dynamic>{
            'accountId': id,
            'schoolName': schoolName,
            'login': login,
            'ownerUserId': ownerUserId,
            'about': about,
          },
        ),
      );
    }
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  Future<List<AdminTarget>> _loadTournaments() async {
    final rows =
        await TournamentStorageService.instance.loadVisibleTournaments();
    final result = <AdminTarget>[];
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw);
      final id = '${row['id'] ?? ''}'.trim();
      if (id.isEmpty) continue;
      final name = '${row['name'] ?? 'Турнир'}'.trim();
      final ownerId = '${row['_ownerId'] ?? row['ownerId'] ?? ''}'.trim();
      final status = '${row['status'] ?? ''}'.trim();
      final count = row['participantIds'] is List
          ? (row['participantIds'] as List).length
          : 0;
      result.add(
        AdminTarget(
          id: id,
          name: name.isEmpty ? _t('Турнир') : name,
          recipientId: ownerId,
          kind: AdminEntityKind.tournament,
          subtitle:
              '${status.isEmpty ? _t('Статус не указан') : _t(status)} • ${_t('{count} участников', params: <String, Object?>{
                'count': count
              })}',
          raw: row,
        ),
      );
    }
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  List<AdminTarget> get _visibleTargets {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _targets;
    return _targets
        .where(
          (item) =>
              item.name.toLowerCase().contains(query) ||
              item.subtitle.toLowerCase().contains(query) ||
              item.id.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  List<AdminCaseRecord> get _selectedCases {
    final target = _selected;
    if (target == null) return const <AdminCaseRecord>[];
    final result = _cases
        .where((item) => item.targetId == target.id)
        .toList(growable: false);
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  AdminCaseRecord? get _latestSelectedCase =>
      _selectedCases.isEmpty ? null : _selectedCases.first;

  AdminCaseRecord? get _currentSelectedCase {
    final caseId = (_selectedCaseId ?? '').trim();
    if (caseId.isNotEmpty) {
      for (final item in _selectedCases) {
        if (item.id == caseId) return item;
      }
    }
    return _latestSelectedCase;
  }

  int get _warningDayCount {
    final parsed = int.tryParse(_warningDays.text.trim()) ?? 10;
    return parsed.clamp(1, 365).toInt();
  }

  DateTime? get _draftDueAt => _reminderEnabled
      ? DateTime.now().add(Duration(days: _warningDayCount))
      : null;

  Future<void> _refreshReplies() async {
    final selected = _selected;
    if (selected == null) {
      if (mounted) setState(() => _caseReplies = <MakeChessMessage>[]);
      return;
    }
    try {
      final all =
          await MakeChessMessageRealtimeService.instance.syncFromDatabase();
      final caseIds = _selectedCases.map((item) => item.id).toSet();
      final replies = all
          .where(
            (message) =>
                message.category == 'admin_case_reply' &&
                caseIds.contains('${message.metadata['adminCaseId'] ?? ''}'),
          )
          .toList();
      replies.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;

      var changedCases = false;
      final fixedCaseIds = replies
          .where((message) =>
              '${message.metadata['replyStatus'] ?? ''}' == 'fixed')
          .map((message) => '${message.metadata['adminCaseId'] ?? ''}')
          .toSet();

      if (fixedCaseIds.isNotEmpty) {
        _cases = _cases.map((item) {
          if (fixedCaseIds.contains(item.id) &&
              item.status != 'closed' &&
              item.status != 'blocked') {
            changedCases = true;
            return item.copyWith(
              status: 'fixed_reported',
              updatedAt: DateTime.now(),
            );
          }
          return item;
        }).toList();
      }

      setState(() => _caseReplies = replies);
      if (changedCases) {
        await AdminModerationStore.instance.saveCases(_cases);
      }
    } catch (_) {
      // The local case history remains usable if network sync is temporarily unavailable.
    }
  }

  Future<void> _selectTarget(AdminTarget target) async {
    setState(() {
      _selected = target;
      _selectedCaseId = null;
      _actionText.clear();
      _caseReplies = <MakeChessMessage>[];
      _deleteConfirmTargetId = null;
      for (final key in _restrictionDraft.keys.toList()) {
        _restrictionDraft[key] = false;
      }
      final latest = _cases.where((item) => item.targetId == target.id).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (latest.isNotEmpty) {
        for (final entry in latest.first.restrictions.entries) {
          if (_restrictionDraft.containsKey(entry.key)) {
            _restrictionDraft[entry.key] = entry.value;
          }
        }
      }
    });
    await _refreshReplies();
  }

  Future<bool> _performAction({
    required String action,
    required String text,
    DateTime? warningDueAt,
  }) async {
    final target = _selected;
    final cleanText = text.trim();

    if (target == null) {
      _snack(_t('Выберите объект слева'));
      return false;
    }
    if (cleanText.isEmpty) {
      _snack(_t('Сообщение обязательно для любого административного действия'));
      return false;
    }
    if (target.recipientId.trim().isEmpty) {
      _snack(_t('У объекта нет связанного получателя'));
      return false;
    }
    if (_sending) return false;

    setState(() => _sending = true);
    try {
      final now = DateTime.now();
      final existing = _currentSelectedCase ?? _latestSelectedCase;
      final caseId = existing?.id ??
          'admin_case_${now.microsecondsSinceEpoch}_${target.kind.name}_${target.id}';

      final dueAt = action == 'warning'
          ? warningDueAt
          : (action == 'lift_restrictions' ||
                  action == 'unblock' ||
                  action == 'restore')
              ? null
              : existing?.dueAt;

      final nextRestrictions = Map<String, bool>.from(_restrictionDraft);
      if (action == 'lift_restrictions' || action == 'restore') {
        for (final key in nextRestrictions.keys.toList()) {
          nextRestrictions[key] = false;
        }
      }

      final blocked = switch (action) {
        'block' || 'keep_blocked' => true,
        'unblock' || 'restore' => false,
        _ => existing?.blocked ?? false,
      };

      final status = switch (action) {
        'warning' => dueAt == null ? 'warning' : 'awaiting_fix',
        'block' || 'keep_blocked' => 'blocked',
        'restriction' || 'keep_restrictions' => 'restricted',
        'lift_restrictions' || 'unblock' || 'restore' => 'open',
        'delete' || 'keep_deleted' => 'deleted',
        _ => existing?.status ?? 'open',
      };

      await _sendMessageToTarget(
        target: target,
        caseId: caseId,
        action: action,
        text: cleanText,
        dueAt: dueAt,
        restrictions: nextRestrictions,
      );

      final event = AdminCaseEvent(
        id: 'event_${now.microsecondsSinceEpoch}',
        createdAt: now,
        actor: 'admin',
        type: action,
        text: cleanText,
      );

      final record = existing == null
          ? AdminCaseRecord(
              id: caseId,
              targetId: target.id,
              targetName: target.name,
              targetKind: target.kind.name,
              recipientId: target.recipientId,
              createdAt: now,
              updatedAt: now,
              action: action,
              status: status,
              message: cleanText,
              blocked: blocked,
              restrictions: nextRestrictions,
              events: <AdminCaseEvent>[event],
              dueAt: dueAt,
            )
          : existing.copyWith(
              updatedAt: now,
              action: action,
              status: status,
              message: cleanText,
              blocked: blocked,
              restrictions: nextRestrictions,
              events: <AdminCaseEvent>[event, ...existing.events],
              dueAt: dueAt,
              clearDueAt: dueAt == null,
            );

      await AdminModerationStore.instance.upsertCase(record);

      if (action == 'delete') {
        if (target.kind == AdminEntityKind.tournament) {
          await TournamentStorageService.instance.deleteTournament(target.id);
        }
        await AdminModerationStore.instance.markTargetDeleted(target);
      } else if (action == 'restore') {
        await AdminModerationStore.instance.restoreTarget(target);
      }

      final loaded = await AdminModerationStore.instance.loadCases();
      if (!mounted) return true;
      setState(() {
        _cases = loaded;
        _selectedCaseId = caseId;
      });
      await _refreshReplies();

      _snack(
        switch (action) {
          'warning' => _t('Предупреждение отправлено'),
          'block' => _t('Блокировка зафиксирована и причина отправлена'),
          'restriction' =>
            _t('Ограничения зафиксированы и объяснение отправлено'),
          'delete' => _t('Объект удалён. Причина отправлена и сохранена.'),
          'lift_restrictions' => _t('Ограничения сняты'),
          'keep_restrictions' => _t('Ограничения сохранены'),
          'unblock' => _t('Блокировка снята'),
          'keep_blocked' => _t('Блокировка сохранена'),
          'restore' => _t('Пользователь восстановлен'),
          'keep_deleted' => _t('Статус удаления сохранён'),
          _ => _t('Сообщение отправлено'),
        },
      );

      if (action == 'delete') {
        setState(() => _selected = null);
        await _load();
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      _snack(
        _t(
          'Не удалось выполнить административное действие: {error}',
          params: <String, Object?>{'error': '$error'},
        ),
      );
      return false;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendMessageToTarget({
    required AdminTarget target,
    required String caseId,
    required String action,
    required String text,
    required DateTime? dueAt,
    required Map<String, bool> restrictions,
  }) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError(
          _t('Для административного сообщения требуется вход в аккаунт'));
    }
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final senderName =
        '${metadata['nickname'] ?? metadata['name'] ?? user.email ?? 'MakeChess'}';

    await MakeChessMessageRealtimeService.instance.start(client);
    await MakeChessMessageRealtimeService.instance.send(
      MakeChessMessage(
        id: 'admin_message_${DateTime.now().microsecondsSinceEpoch}',
        recipientId: target.recipientId,
        senderId: user.id,
        senderName: senderName,
        category: switch (action) {
          'warning' => 'admin_warning',
          'block' || 'unblock' || 'keep_blocked' => 'admin_block',
          'restriction' ||
          'lift_restrictions' ||
          'keep_restrictions' =>
            'admin_restriction',
          'delete' || 'restore' || 'keep_deleted' => 'admin_delete',
          _ => 'admin_info',
        },
        // Store canonical Russian system titles. The recipient UI localizes them.
        title: switch (action) {
          'warning' => 'Административное предупреждение',
          'block' || 'unblock' || 'keep_blocked' => 'Административное решение',
          'restriction' ||
          'lift_restrictions' ||
          'keep_restrictions' =>
            'Изменение доступных функций',
          'delete' ||
          'restore' ||
          'keep_deleted' =>
            'Административное удаление',
          _ => 'Административное сообщение',
        },
        body: text,
        createdAt: DateTime.now(),
        tournamentId:
            target.kind == AdminEntityKind.tournament ? target.id : null,
        metadata: <String, dynamic>{
          'adminCaseId': caseId,
          'adminAction': action,
          'targetKind': target.kind.name,
          'targetId': target.id,
          'targetName': target.name,
          'recipientName': target.name,
          if (dueAt != null) 'dueAt': dueAt.toIso8601String(),
          'restrictions': restrictions,
          'transparencyPolicy': 'reason_required',
        },
      ),
    );
  }

  String _actionDialogTitle(String action) => switch (action) {
        'info' => _t('Отправить сообщение'),
        'warning' => _t('Отправить предупреждение'),
        'restriction' => _t('Применить ограничения'),
        'block' => _t('Заблокировать'),
        'delete' => _t('Удалить'),
        'lift_restrictions' => _t('Снять ограничения'),
        'keep_restrictions' => _t('Сохранить ограничения'),
        'unblock' => _t('Разблокировать'),
        'keep_blocked' => _t('Оставить блокировку'),
        'restore' => _t('Восстановить'),
        'keep_deleted' => _t('Оставить удалённым'),
        _ => _t('Административное действие'),
      };

  String _actionReasonLabel(String action) => switch (action) {
        'info' => _t('Текст сообщения'),
        'warning' => _t('Текст предупреждения'),
        'restriction' => _t('Причина ограничения'),
        'block' => _t('Причина блокировки'),
        'delete' => _t('Причина удаления'),
        'lift_restrictions' => _t('Причина снятия ограничений'),
        'keep_restrictions' => _t('Почему ограничения сохраняются'),
        'unblock' => _t('Причина снятия блокировки'),
        'keep_blocked' => _t('Почему блокировка сохраняется'),
        'restore' => _t('Причина восстановления'),
        'keep_deleted' => _t('Почему статус удаления сохраняется'),
        _ => _t('Сообщение пользователю'),
      };

  Future<void> _openActionDialog(String action) async {
    final target = _selected;
    if (target == null || _sending) {
      if (target == null) _snack(_t('Выберите объект слева'));
      return;
    }

    final controller = TextEditingController();
    final daysController = TextEditingController(text: '10');
    var reminderEnabled = false;

    try {
      final result = await showDialog<({String text, DateTime? dueAt})>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final text = controller.text.trim();
            final canConfirm = text.isNotEmpty;
            final days = (int.tryParse(daysController.text.trim()) ?? 10)
                .clamp(1, 365)
                .toInt();
            final dueAt = action == 'warning' && reminderEnabled
                ? DateTime.now().add(Duration(days: days))
                : null;

            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text(_actionDialogTitle(action)),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(target.name, style: AppTextStyles.panelTitle),
                      const SizedBox(height: 5),
                      Text(
                        _t('Решение невозможно отправить без объяснения причины'),
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        minLines: 5,
                        maxLines: 10,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          labelText: _actionReasonLabel(action),
                          hintText: _t('Это сообщение увидит пользователь'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      if (action == 'warning') ...[
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: reminderEnabled,
                          onChanged: (value) =>
                              setDialogState(() => reminderEnabled = value),
                          title: Text(_t('Напомнить мне проверить ситуацию')),
                          subtitle: Text(
                            _t(
                              'Таймер только напоминает администратору и ничего не блокирует автоматически',
                            ),
                          ),
                        ),
                        if (reminderEnabled)
                          Row(
                            children: [
                              SizedBox(
                                width: 130,
                                child: TextField(
                                  controller: daysController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setDialogState(() {}),
                                  decoration: InputDecoration(
                                    labelText: _t('Срок'),
                                    suffixText: _t('дней'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${_t('Проверить до')}: ${_formatDateTime(dueAt!)}',
                                  style: AppTextStyles.bodyDim,
                                ),
                              ),
                            ],
                          ),
                      ],
                      if (action == 'restriction' ||
                          action == 'keep_restrictions') ...[
                        const SizedBox(height: 12),
                        Text(
                          _t('Выбранные ограничения'),
                          style: AppTextStyles.buttonCompact,
                        ),
                        const SizedBox(height: 5),
                        Text(_restrictionSummary(),
                            style: AppTextStyles.bodyDim),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(_t('Отмена')),
                ),
                FilledButton(
                  onPressed: canConfirm
                      ? () => Navigator.pop(
                            dialogContext,
                            (text: text, dueAt: dueAt),
                          )
                      : null,
                  child: Text(_actionDialogTitle(action)),
                ),
              ],
            );
          },
        ),
      );

      if (result == null) return;
      await _performAction(
        action: action,
        text: result.text,
        warningDueAt: result.dueAt,
      );
    } finally {
      controller.dispose();
      daysController.dispose();
    }
  }

  String _restrictionSummary() {
    final labels = <String, String>{
      'messages': 'Запретить сообщения',
      'tournamentParticipation': 'Запретить участие в турнирах',
      'tournamentCreation': 'Запретить создание турниров',
      'video': 'Запретить видеосвязь',
      'assignments': 'Запретить создание заданий',
      'students': 'Запретить приём учеников',
      'publishing': 'Запретить публикации',
      'registration': 'Запретить регистрацию в турнир',
      'tournamentStop': 'Остановить турнир',
    };
    final selected = _restrictionDraft.entries
        .where((entry) => entry.value)
        .map((entry) => _t(labels[entry.key] ?? entry.key))
        .toList(growable: false);
    return selected.isEmpty
        ? _t('Ограничения не выбраны')
        : selected.join(' • ');
  }

  Widget _reviewDecisionButtons(AdminCaseRecord record) {
    final replies = _caseReplies
        .where(
          (message) => '${message.metadata['adminCaseId'] ?? ''}' == record.id,
        )
        .toList(growable: false);
    if (replies.isEmpty) return const SizedBox.shrink();

    final actions = <(String, String, IconData)>[];
    if (record.status == 'deleted') {
      actions.add(('restore', 'Восстановить', Icons.restore));
      actions.add(
        ('keep_deleted', 'Оставить удалённым', Icons.archive_outlined),
      );
    } else if (record.blocked || record.status == 'blocked') {
      actions.add(('unblock', 'Разблокировать', Icons.lock_open_outlined));
      actions.add(('keep_blocked', 'Оставить блокировку', Icons.block));
    } else if (record.status == 'restricted' ||
        record.restrictions.values.any((value) => value)) {
      actions.add(
        ('lift_restrictions', 'Снять ограничения', Icons.check_circle_outline),
      );
      actions.add(('keep_restrictions', 'Сохранить ограничения', Icons.tune));
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.neoButton(active: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _t('Ответ получен — требуется решение администратора'),
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final action in actions)
                OutlinedButton.icon(
                  onPressed:
                      _sending ? null : () => _openActionDialog(action.$1),
                  icon: Icon(action.$3),
                  label: Text(_t(action.$2)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _markCaseClosed() async {
    final record = _currentSelectedCase;
    if (record == null) return;
    final now = DateTime.now();
    final event = AdminCaseEvent(
      id: 'event_${now.microsecondsSinceEpoch}',
      createdAt: now,
      actor: 'admin',
      type: 'closed',
      text: _t('Исправлено подтверждено администратором'),
    );
    await AdminModerationStore.instance.upsertCase(
      record.copyWith(
        updatedAt: now,
        status: 'closed',
        blocked: false,
        events: <AdminCaseEvent>[event, ...record.events],
        clearDueAt: true,
      ),
    );
    final loaded = await AdminModerationStore.instance.loadCases();
    if (!mounted) return;
    setState(() => _cases = loaded);
    _snack(_t('Ситуация закрыта'));
  }

  Future<void> _extendWarning() async {
    final record = _latestSelectedCase;
    if (record == null) return;
    final days = _warningDayCount;
    final dueAt = DateTime.now().add(Duration(days: days));
    final now = DateTime.now();
    final event = AdminCaseEvent(
      id: 'event_${now.microsecondsSinceEpoch}',
      createdAt: now,
      actor: 'admin',
      type: 'extended',
      text: _t(
        'Срок продлён на {days} дней',
        params: <String, Object?>{'days': days},
      ),
    );
    await AdminModerationStore.instance.upsertCase(
      record.copyWith(
        updatedAt: now,
        status: 'awaiting_fix',
        dueAt: dueAt,
        events: <AdminCaseEvent>[event, ...record.events],
      ),
    );
    final loaded = await AdminModerationStore.instance.loadCases();
    if (!mounted) return;
    setState(() => _cases = loaded);
  }

  Future<void> _openTournament(AdminTarget target) async {
    final row = target.raw;
    List<String> participantNames = <String>[];
    final rawNames = row['participantNames'];
    if (rawNames is Map) {
      participantNames = rawNames.values.map((value) => '$value').toList();
    } else if (rawNames is List) {
      participantNames = rawNames.map((value) => '$value').toList();
    } else if (row['participantIds'] is List) {
      participantNames =
          (row['participantIds'] as List).map((value) => '$value').toList();
    }

    int intValue(String key, int fallback) {
      final raw = row[key];
      return raw is num ? raw.toInt() : int.tryParse('$raw') ?? fallback;
    }

    await showTournamentTableEditor(
      context: context,
      tournamentId: target.id,
      initialName: target.name,
      initialType: '${row['format'] ?? row['type'] ?? 'Круговая система'}',
      initialStatus: '${row['status'] ?? 'Черновик'}',
      initialMinutes: intValue('minutes', 10),
      initialIncrement: intValue('increment', 0),
      initialRounds: intValue('rounds', 1),
      initialParticipantNames: participantNames,
      maxParticipants: intValue('maxParticipants', 8),
      startInPreview: true,
      organizerMode: false,
    );
  }

  String _statusText(AdminCaseRecord? record) {
    if (record == null) return _t('Активен');
    if (record.status == 'deleted') return _t('Удалён');
    if (record.blocked || record.status == 'blocked') return _t('Заблокирован');
    if (record.status == 'fixed_reported') {
      return _t('Пользователь сообщил: исправлено');
    }
    if (record.status == 'closed') return _t('Исправлено');
    if (record.status == 'restricted') return _t('Ограничено');
    if (record.status == 'awaiting_fix') {
      final dueAt = record.dueAt;
      if (dueAt != null && dueAt.isBefore(DateTime.now())) {
        return _t('Срок истёк — требуется решение администратора');
      }
      return _t('Ожидается исправление');
    }
    if (record.status == 'warning') return _t('Предупреждение отправлено');
    return _t('Открыто');
  }

  Color _statusColor(AdminCaseRecord? record) {
    if (record == null || record.status == 'closed') return AppColors.success;
    if (record.status == 'deleted') return AppColors.danger;
    if (record.blocked || record.status == 'blocked') return AppColors.danger;
    if (record.status == 'fixed_reported') return AppColors.accent;
    if (record.status == 'awaiting_fix' &&
        record.dueAt != null &&
        record.dueAt!.isBefore(DateTime.now())) {
      return AppColors.danger;
    }
    return AppColors.warning;
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _remainingText(DateTime dueAt) {
    final diff = dueAt.difference(DateTime.now());
    if (diff.isNegative) return _t('Срок истёк');
    final days = diff.inDays;
    final hours = diff.inHours.remainder(24);
    final minutes = diff.inMinutes.remainder(60);
    return _t(
      '{days} дн. {hours} ч. {minutes} мин.',
      params: <String, Object?>{
        'days': days,
        'hours': hours,
        'minutes': minutes,
      },
    );
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(widget.kind.icon, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _t(widget.kind.label),
                style: AppTextStyles.sectionTitle,
              ),
            ),
            IconButton(
              tooltip: _t('Обновить'),
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _t('Выберите объект и управляйте им без скрытых административных действий'),
          style: AppTextStyles.bodyDim,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 300, child: _directory()),
              const SizedBox(width: 14),
              Expanded(
                  child: _selected == null ? _emptySelection() : _workspace()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _directory() {
    final items = _visibleTargets;
    return Container(
      decoration: AppDecorations.card(),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              hintText: _t('Поиск'),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(_t('Нет данных'), style: AppTextStyles.bodyDim),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      final active = item.id == _selected?.id;
                      final latest = _cases
                          .where((record) => record.targetId == item.id)
                          .toList()
                        ..sort(
                          (a, b) => b.updatedAt.compareTo(a.updatedAt),
                        );
                      final record = latest.isEmpty ? null : latest.first;
                      return InkWell(
                        onTap: () => _selectTarget(item),
                        borderRadius: AppRadius.r10,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: AppDecorations.neoButton(active: active),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 17,
                                backgroundColor: AppColors.appBgSoft,
                                child: Icon(
                                  item.kind.icon,
                                  size: 18,
                                  color: active
                                      ? AppColors.accent
                                      : AppColors.textDim,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.body,
                                    ),
                                    if (item.subtitle.isNotEmpty)
                                      Text(
                                        item.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.caption,
                                      ),
                                  ],
                                ),
                              ),
                              if (record != null)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _statusColor(record),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptySelection() => Center(
        child: Text(
          _t('Выберите объект слева'),
          style: AppTextStyles.bodyDim,
        ),
      );

  Widget _workspace() {
    final target = _selected!;
    final latest = _currentSelectedCase;
    return ListView(
      children: [
        _targetHeader(target, latest),
        const SizedBox(height: 12),
        _zone(
          title: _t('Административное действие'),
          icon: Icons.admin_panel_settings_outlined,
          child: Text(
            _t(
              'Выберите действие. Причина или текст сообщения вводятся после выбора действия.',
            ),
            style: AppTextStyles.bodyDim,
          ),
        ),
        const SizedBox(height: 12),
        _zone(
          title: _t('Предупреждение и напоминание'),
          icon: Icons.alarm_outlined,
          child: _warningZone(latest),
        ),
        const SizedBox(height: 12),
        _zone(
          title: _t('Ограничения'),
          icon: Icons.tune,
          child: _restrictionsZone(),
        ),
        const SizedBox(height: 12),
        _zone(
          title: _t('Действия'),
          icon: Icons.rule_folder_outlined,
          child: _actionButtons(),
        ),
        const SizedBox(height: 12),
        _zone(
          title: _t('История и ответ пользователя'),
          icon: Icons.forum_outlined,
          child: _historyZone(),
        ),
      ],
    );
  }

  Widget _targetHeader(AdminTarget target, AdminCaseRecord? latest) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: AppDecorations.card(highlighted: true),
        child: Row(
          children: [
            CircleAvatar(
              child: Icon(target.kind.icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(target.name, style: AppTextStyles.panelTitle),
                  if (target.subtitle.isNotEmpty)
                    Text(target.subtitle, style: AppTextStyles.caption),
                  const SizedBox(height: 4),
                  Text(
                    '${_t('Статус')}: ${_statusText(latest)}',
                    style: TextStyle(
                      color: _statusColor(latest),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (target.kind == AdminEntityKind.tournament)
              FilledButton.icon(
                onPressed: () => _openTournament(target),
                icon: const Icon(Icons.open_in_new),
                label: Text(_t('Открыть турнир')),
              ),
          ],
        ),
      );

  Widget _messageZone() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _t('MakeChess уважает ваше право знать причину'),
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _t('Без сообщения административное действие невозможно'),
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _actionText,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: _t('Сообщение пользователю'),
              hintText:
                  _t('Объясните причину или напишите информационное сообщение'),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      );

  Widget _warningZone(AdminCaseRecord? latest) {
    final dueAt = latest?.dueAt;
    if (dueAt == null) {
      return Text(
        _t(
          'Таймер настраивается внутри окна «Отправить предупреждение» и включается только по решению администратора.',
        ),
        style: AppTextStyles.bodyDim,
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: AppDecorations.neoButton(
        active: dueAt.isBefore(DateTime.now()),
      ),
      child: Row(
        children: [
          Icon(
            dueAt.isBefore(DateTime.now())
                ? Icons.notification_important
                : Icons.timer_outlined,
            color: dueAt.isBefore(DateTime.now())
                ? AppColors.danger
                : AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              dueAt.isBefore(DateTime.now())
                  ? _t('Срок истёк — требуется решение администратора')
                  : '${_t('До проверки')}: ${_remainingText(dueAt)}',
            ),
          ),
          TextButton(
            onPressed: _extendWarning,
            child: Text(_t('Продлить срок')),
          ),
        ],
      ),
    );
  }

  Widget _restrictionsZone() {
    final rows = <(String, String)>[
      ('messages', 'Запретить сообщения'),
      ('tournamentParticipation', 'Запретить участие в турнирах'),
      if (widget.kind == AdminEntityKind.teacher ||
          widget.kind == AdminEntityKind.school)
        ('tournamentCreation', 'Запретить создание турниров'),
      ('video', 'Запретить видеосвязь'),
      if (widget.kind == AdminEntityKind.teacher)
        ('assignments', 'Запретить создание заданий'),
      if (widget.kind == AdminEntityKind.teacher ||
          widget.kind == AdminEntityKind.school)
        ('students', 'Запретить приём учеников'),
      if (widget.kind == AdminEntityKind.school)
        ('publishing', 'Запретить публикацию материалов'),
      if (widget.kind == AdminEntityKind.tournament)
        ('registration', 'Запретить регистрацию в турнир'),
      if (widget.kind == AdminEntityKind.tournament)
        ('tournamentStop', 'Остановить турнир'),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _t('Можно ограничить только нужные функции, не блокируя всё'),
                style: AppTextStyles.caption,
              ),
            ),
            IconButton(
              tooltip: _t(_showRestrictions ? 'Свернуть' : 'Развернуть'),
              onPressed: () =>
                  setState(() => _showRestrictions = !_showRestrictions),
              icon: Icon(
                _showRestrictions ? Icons.expand_less : Icons.expand_more,
              ),
            ),
          ],
        ),
        if (_showRestrictions)
          for (final row in rows)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _restrictionDraft[row.$1] ?? false,
              onChanged: (value) => setState(
                () => _restrictionDraft[row.$1] = value == true,
              ),
              title: Text(_t(row.$2)),
            ),
      ],
    );
  }

  Widget _actionButtons() {
    final disabled = _selected == null || _sending;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: disabled ? null : () => _openActionDialog('info'),
          icon: const Icon(Icons.send_outlined),
          label: Text(_t('Отправить сообщение')),
        ),
        FilledButton.icon(
          onPressed: disabled ? null : () => _openActionDialog('warning'),
          icon: const Icon(Icons.warning_amber_outlined),
          label: Text(_t('Отправить предупреждение')),
        ),
        OutlinedButton.icon(
          onPressed: disabled ? null : () => _openActionDialog('restriction'),
          icon: const Icon(Icons.tune),
          label: Text(_t('Применить ограничения')),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
          ),
          onPressed: disabled ? null : () => _openActionDialog('block'),
          icon: const Icon(Icons.block),
          label: Text(_t('Заблокировать')),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
          ),
          onPressed: disabled ? null : () => _openActionDialog('delete'),
          icon: const Icon(Icons.delete_forever_outlined),
          label: Text(_t('Удалить')),
        ),
      ],
    );
  }

  Widget _historyZone() {
    final record = _currentSelectedCase;
    if (record == null) {
      return Text(
        _t('Нет административных действий'),
        style: AppTextStyles.bodyDim,
      );
    }

    final replies = _caseReplies
        .where(
          (message) => '${message.metadata['adminCaseId'] ?? ''}' == record.id,
        )
        .toList(growable: false);

    final adminEvents = record.events.toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final first = adminEvents.isEmpty ? null : adminEvents.first;

    final timeline =
        <({DateTime time, String actor, String type, String text})>[];
    for (final event in adminEvents.skip(first == null ? 0 : 1)) {
      timeline.add((
        time: event.createdAt,
        actor: 'admin',
        type: event.type,
        text: event.text,
      ));
    }
    for (final reply in replies) {
      final fixed = '${reply.metadata['replyStatus'] ?? ''}' == 'fixed';
      timeline.add((
        time: reply.createdAt,
        actor: 'user',
        type: fixed ? 'fixed' : 'reply',
        text: reply.body,
      ));
    }
    timeline.sort((a, b) => a.time.compareTo(b.time));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (first != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(.07),
              borderRadius: AppRadius.r10,
              border: Border.all(
                color: AppColors.accent.withOpacity(.75),
                width: 1.3,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.push_pin_outlined,
                      color: AppColors.accent,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _t('ПЕРВОНАЧАЛЬНАЯ ПРИЧИНА'),
                        style: AppTextStyles.buttonCompact.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    Text(
                      _formatDateTime(first.createdAt),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(first.text, style: AppTextStyles.body),
                const SizedBox(height: 7),
                Text(
                  _t('Первоначальное сообщение хранится без редактирования'),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        _reviewDecisionButtons(record),
        if (record.status == 'fixed_reported')
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: AppDecorations.neoButton(active: true),
            child: Row(
              children: [
                const Icon(Icons.task_alt, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _t('Пользователь сообщил: исправлено'),
                    style: AppTextStyles.body,
                  ),
                ),
                FilledButton(
                  onPressed: _markCaseClosed,
                  child: Text(_t('Подтвердить, что исправлено')),
                ),
              ],
            ),
          ),
        for (final event in timeline)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: AppDecorations.card(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  event.actor == 'user'
                      ? Icons.person_outline
                      : Icons.admin_panel_settings_outlined,
                  size: 18,
                  color: event.actor == 'user'
                      ? AppColors.success
                      : AppColors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.actor == 'user'
                            ? _t('Ответ пользователя')
                            : _t('Администратор'),
                        style: AppTextStyles.buttonCompact,
                      ),
                      const SizedBox(height: 3),
                      Text(event.text, style: AppTextStyles.body),
                    ],
                  ),
                ),
                Text(
                  _formatDateTime(event.time),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _zone({
    required String title,
    required IconData icon,
    required Widget child,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(title, style: AppTextStyles.panelTitle),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class AdminRepliesInbox extends StatefulWidget {
  const AdminRepliesInbox({
    super.key,
    required this.onOpen,
    this.footer,
  });

  final ValueChanged<AdminCaseNavigationRequest> onOpen;
  final Widget? footer;

  @override
  State<AdminRepliesInbox> createState() => _AdminRepliesInboxState();
}

class _AdminRepliesInboxState extends State<AdminRepliesInbox> {
  bool _loading = true;
  List<MakeChessMessage> _messages = <MakeChessMessage>[];
  StreamSubscription<MakeChessMessage>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription =
        MakeChessMessageRealtimeService.instance.incoming.listen((_) {
      _reload();
    });
    _reload();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final messages =
          await MakeChessMessageRealtimeService.instance.syncFromDatabase();
      final userId =
          (Supabase.instance.client.auth.currentUser?.id ?? '').trim();
      final replies = messages
          .where(
            (message) =>
                message.recipientId == userId &&
                message.category == 'admin_case_reply',
          )
          .toList(growable: false)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      publishMakeChessAdminReplyUnreadCount(messages, userId);
      if (!mounted) return;
      setState(() {
        _messages = replies;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(MakeChessMessage message) async {
    final request = AdminCaseNavigationRequest.fromMessage(message);
    if (!request.isValid) return;
    if (message.status == 'unread') {
      try {
        await MakeChessMessageRealtimeService.instance
            .updateStatus(message.id, 'read');
      } catch (_) {}
    }
    await _reload();
    if (!mounted) return;
    widget.onOpen(request);
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = MakeChessLocalization.phrase;
    return ListView(
      children: [
        Text(
          t('Ответы на административные решения'),
          style: AppTextStyles.sectionTitle,
        ),
        const SizedBox(height: 4),
        Text(
          t(
            'Нажмите сообщение, чтобы открыть карточку и всё административное дело.',
          ),
          style: AppTextStyles.bodyDim,
        ),
        const SizedBox(height: 14),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_messages.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppDecorations.card(),
            child: Text(
              t('Новых ответов пользователей пока нет'),
              style: AppTextStyles.bodyDim,
            ),
          )
        else
          for (final message in _messages)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: AppDecorations.card(
                highlighted: message.status == 'unread',
              ),
              child: ListTile(
                onTap: () => _open(message),
                leading: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.forum_outlined,
                      color: AppColors.accent,
                    ),
                    if (message.status == 'unread')
                      const Positioned(
                        right: -5,
                        top: -5,
                        child: CircleAvatar(
                          radius: 5,
                          backgroundColor: AppColors.danger,
                        ),
                      ),
                  ],
                ),
                title: Text(
                  message.senderName,
                  style: AppTextStyles.body,
                ),
                subtitle: Text(
                  message.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
                trailing: Text(
                  _date(message.createdAt),
                  style: AppTextStyles.caption,
                ),
              ),
            ),
        if (widget.footer != null) ...[
          const SizedBox(height: 18),
          const Divider(color: AppColors.borderSoft),
          const SizedBox(height: 14),
          widget.footer!,
        ],
      ],
    );
  }
}

class AdminReminderBar extends StatefulWidget {
  const AdminReminderBar({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  State<AdminReminderBar> createState() => _AdminReminderBarState();
}

class _AdminReminderBarState extends State<AdminReminderBar> {
  Timer? _timer;
  int _overdueCount = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final cases = await AdminModerationStore.instance.loadCases();
    final now = DateTime.now();
    final count = cases.where((item) {
      final dueAt = item.dueAt;
      if (dueAt == null || !dueAt.isBefore(now)) return false;
      return item.status != 'closed' && item.status != 'blocked';
    }).length;
    if (mounted && count != _overdueCount) {
      setState(() => _overdueCount = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_overdueCount == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(.08),
        borderRadius: AppRadius.r10,
        border: Border.all(color: AppColors.danger.withOpacity(.55)),
      ),
      child: Row(
        children: [
          const Icon(Icons.alarm_on, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              MakeChessLocalization.phrase(
                'Есть просроченные предупреждения: {count}',
                params: <String, Object?>{'count': _overdueCount},
              ),
              style: AppTextStyles.body,
            ),
          ),
          TextButton(
            onPressed: widget.onOpen,
            child: Text(MakeChessLocalization.phrase('Открыть')),
          ),
        ],
      ),
    );
  }
}

class AdminArchivePanel extends StatefulWidget {
  const AdminArchivePanel({super.key});

  @override
  State<AdminArchivePanel> createState() => _AdminArchivePanelState();
}

class _AdminArchivePanelState extends State<AdminArchivePanel> {
  int _tab = 0;
  bool _showSettings = false;
  bool _loading = true;
  Map<String, bool> _settings = <String, bool>{};
  List<AdminCaseRecord> _cases = <AdminCaseRecord>[];
  String? _archiveDeleteConfirmId;

  String _t(String source) => MakeChessLocalization.phrase(source);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      AdminModerationStore.instance.loadArchiveSettings(),
      AdminModerationStore.instance.loadCases(),
    ]);
    if (!mounted) return;
    setState(() {
      _settings = Map<String, bool>.from(results[0] as Map);
      _cases = List<AdminCaseRecord>.from(results[1] as List);
      _loading = false;
    });
  }

  Future<void> _setSetting(String key, bool value) async {
    setState(() => _settings[key] = value);
    await AdminModerationStore.instance.saveArchiveSettings(_settings);
  }

  Future<void> _deleteArchiveCase(AdminCaseRecord item) async {
    await AdminModerationStore.instance.deleteCase(item.id);
    if (!mounted) return;
    setState(() {
      _cases.removeWhere((record) => record.id == item.id);
      _archiveDeleteConfirmId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('Запись удалена из архива'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final tabs = <(String, IconData)>[
      ('Пользователи', Icons.people_outline),
      ('Партии', Icons.sports_esports_outlined),
      ('Турниры', Icons.emoji_events_outlined),
      ('Школы / Учителя', Icons.school_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.archive_outlined, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_t('Архив'), style: AppTextStyles.sectionTitle),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _showSettings = !_showSettings),
              icon: const Icon(Icons.tune),
              label: Text(_t('Что сохранять')),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _t('Архив хранит историческую информацию отдельно от блокировок'),
          style: AppTextStyles.bodyDim,
        ),
        if (_showSettings) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: AppDecorations.card(highlighted: true),
            child: Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _archiveSwitch('users', 'Сохранять пользователей'),
                _archiveSwitch('games', 'Сохранять партии'),
                _archiveSwitch('tournaments', 'Сохранять турниры'),
                _archiveSwitch('schoolsTeachers', 'Сохранять школы и учителей'),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < tabs.length; i++)
              ChoiceChip(
                selected: _tab == i,
                onSelected: (_) => setState(() => _tab = i),
                avatar: Icon(tabs[i].$2, size: 17),
                label: Text(_t(tabs[i].$1)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(child: _archiveBody()),
      ],
    );
  }

  Widget _archiveSwitch(String key, String label) => SizedBox(
        width: 240,
        child: SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: _settings[key] ?? true,
          onChanged: (value) => _setSetting(key, value),
          title: Text(_t(label)),
        ),
      );

  Widget _archiveBody() {
    if (_tab == 1) {
      return Center(
        child: Text(
          _t('Архив партий подключён к настройкам хранения; импорт исторических партий будет отдельным этапом'),
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyDim,
        ),
      );
    }

    final allowedKinds = switch (_tab) {
      0 => <String>{'player'},
      2 => <String>{'tournament'},
      3 => <String>{'school', 'teacher'},
      _ => <String>{},
    };
    final rows =
        _cases.where((item) => allowedKinds.contains(item.targetKind)).toList();

    if (rows.isEmpty) {
      return Center(
        child: Text(_t('Архив пока пуст'), style: AppTextStyles.bodyDim),
      );
    }

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final item = rows[index];
        final confirming = _archiveDeleteConfirmId == item.id;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: AppDecorations.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.targetName, style: AppTextStyles.body),
                        Text(item.message, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  Text(
                    item.updatedAt.toLocal().toString().substring(0, 16),
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: _t('Удалить запись из архива'),
                    onPressed: () => setState(
                      () =>
                          _archiveDeleteConfirmId = confirming ? null : item.id,
                    ),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
              if (confirming) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(.07),
                    borderRadius: AppRadius.r8,
                    border: Border.all(
                      color: AppColors.danger.withOpacity(.55),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _t('Удалить эту запись из архива?'),
                          style: AppTextStyles.body,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(
                          () => _archiveDeleteConfirmId = null,
                        ),
                        child: Text(_t('Отмена')),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        onPressed: () => _deleteArchiveCase(item),
                        child: Text(_t('Удалить')),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
