import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'tournament_disk_mirror.dart';

enum TournamentCloudState { unknown, online, offline }

class TournamentCloudRequiredException implements Exception {
  const TournamentCloudRequiredException([this.message = 'База MakeChess недоступна']);

  final String message;

  @override
  String toString() => message;
}

/// Offline-first storage for MakeChess tournaments.
///
/// Rules:
/// 1. Every tournament/table change is written locally first.
/// 2. Supabase is a synchronization target, not a prerequisite for work.
/// 3. Failed cloud writes remain marked as pending and can be synchronized later.
class TournamentStorageService extends ChangeNotifier {
  TournamentStorageService._();

  static final TournamentStorageService instance = TournamentStorageService._();

  static const String _localOwnerId = 'local_offline_owner';
  static const String _tournamentRowsKey = 'makechess_offline_tournament_rows_v1';
  static const String _tableRowsKey = 'makechess_offline_tournament_table_rows_v1';

  SupabaseClient get _client => Supabase.instance.client;

  String get _authenticatedUserId => (_client.auth.currentUser?.id ?? '').trim();

  String get currentUserId =>
      _authenticatedUserId.isNotEmpty ? _authenticatedUserId : _localOwnerId;

  TournamentCloudState _cloudState = TournamentCloudState.unknown;
  TournamentCloudState get cloudState => _cloudState;

  String _lastCloudError = '';
  String get lastCloudError => _lastCloudError;

  bool _hasPendingChanges = false;
  bool get hasPendingChanges => _hasPendingChanges;

  bool get cloudAvailable => _cloudState == TournamentCloudState.online;
  bool get localOnly => _authenticatedUserId.isEmpty || !cloudAvailable;

  Future<void> initialize() async {
    await _migrateLocalOwnerToAuthenticatedUser();
    await _refreshPendingState();
    if (_authenticatedUserId.isEmpty) {
      _setCloudOffline('Пользователь не авторизован. Используется локальный режим.');
      return;
    }
    await probeCloud();
    if (cloudAvailable) {
      await syncPendingChanges();
    }
  }

  Future<bool> probeCloud() async {
    final userId = _authenticatedUserId;
    if (userId.isEmpty) {
      _setCloudOffline('Нет активной сессии MakeChess.');
      return false;
    }
    try {
      await _client
          .from('makechess_tournaments_v1')
          .select('id')
          .eq('owner_id', userId)
          .limit(1);
      _setCloudOnline();
      return true;
    } catch (error) {
      _setCloudOffline('$error');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> loadVisibleTournaments() async {
    await _migrateLocalOwnerToAuthenticatedUser();
    var localRows = await _readRows(_tournamentRowsKey);

    final userId = _authenticatedUserId;
    if (userId.isNotEmpty) {
      try {
        final rows = await _client
            .from('makechess_tournaments_v1')
            .select('owner_id,id,data,updated_at')
            .order('updated_at', ascending: false);
        _setCloudOnline();
        localRows = await _mergeRemoteTournamentRows(
          localRows,
          (rows as List).whereType<Map>().toList(growable: false),
        );
        await syncPendingChanges();
        localRows = await _readRows(_tournamentRowsKey);
      } catch (error) {
        _setCloudOffline('$error');
      }
    } else {
      _setCloudOffline('Нет активной сессии MakeChess.');
    }

    final visible = localRows
        .where((row) => row['deleted'] != true)
        .map((row) {
          final raw = row['data'];
          if (raw is! Map) return null;
          return <String, dynamic>{
            ...Map<String, dynamic>.from(raw),
            '_ownerId': '${row['ownerId'] ?? ''}',
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    visible.sort((a, b) {
      final ad = DateTime.tryParse('${a['createdAt'] ?? ''}');
      final bd = DateTime.tryParse('${b['createdAt'] ?? ''}');
      if (ad == null || bd == null) return 0;
      return bd.compareTo(ad);
    });
    return visible;
  }

  Future<List<Map<String, dynamic>>> loadTournaments() async {
    await _migrateLocalOwnerToAuthenticatedUser();
    final ownerId = currentUserId;
    var localRows = await _readRows(_tournamentRowsKey);

    final userId = _authenticatedUserId;
    if (userId.isNotEmpty) {
      try {
        final rows = await _client
            .from('makechess_tournaments_v1')
            .select('owner_id,id,data,updated_at')
            .eq('owner_id', userId)
            .order('updated_at', ascending: false);
        _setCloudOnline();
        localRows = await _mergeRemoteTournamentRows(
          localRows,
          (rows as List).whereType<Map>().toList(growable: false),
        );
        await syncPendingChanges();
        localRows = await _readRows(_tournamentRowsKey);
      } catch (error) {
        _setCloudOffline('$error');
      }
    } else {
      _setCloudOffline('Нет активной сессии MakeChess.');
    }

    return localRows
        .where((row) =>
            '${row['ownerId'] ?? ''}' == ownerId && row['deleted'] != true)
        .map((row) => row['data'])
        .whereType<Map>()
        .map((data) => Map<String, dynamic>.from(data))
        .toList(growable: false);
  }

  Future<void> saveTournaments(
    Iterable<Map<String, dynamic>> tournaments,
  ) async {
    await _migrateLocalOwnerToAuthenticatedUser();
    final ownerId = currentUserId;
    final normalized = tournaments
        .where((data) => '${data['id'] ?? ''}'.trim().isNotEmpty)
        .map((data) => Map<String, dynamic>.from(data))
        .toList(growable: false);
    if (normalized.isEmpty) return;

    var rows = await _readRows(_tournamentRowsKey);
    final now = DateTime.now().toUtc().toIso8601String();
    for (final data in normalized) {
      final id = '${data['id']}'.trim();
      final localData = Map<String, dynamic>.from(data)
        ..['ownerId'] = ownerId;
      rows = _upsertRow(
        rows,
        ownerId: ownerId,
        id: id,
        data: localData,
        updatedAt: now,
        pending: true,
        deleted: false,
      );
    }
    await _writeRows(_tournamentRowsKey, rows);
    await _refreshPendingState();

    final userId = _authenticatedUserId;
    if (userId.isEmpty || ownerId != userId) {
      _setCloudOffline('Изменения сохранены только локально.');
      return;
    }

    try {
      final remoteRows = normalized
          .map((data) => <String, dynamic>{
                'owner_id': userId,
                'id': '${data['id']}',
                'data': <String, dynamic>{
                  ...data,
                  'ownerId': userId,
                },
                'updated_at': now,
              })
          .toList(growable: false);
      await _client
          .from('makechess_tournaments_v1')
          .upsert(remoteRows, onConflict: 'owner_id,id');
      await _markRowsSynced(
        _tournamentRowsKey,
        ownerId: userId,
        ids: normalized.map((e) => '${e['id']}'),
      );
      _setCloudOnline();
    } catch (error) {
      _setCloudOffline('$error');
    }
    await _refreshPendingState();
  }

  Future<void> deleteTournament(
    String tournamentId, {
    String? ownerId,
  }) async {
    final id = tournamentId.trim();
    if (id.isEmpty) return;
    await _migrateLocalOwnerToAuthenticatedUser();
    final targetOwnerId = (ownerId ?? currentUserId).trim();
    if (targetOwnerId.isEmpty) return;

    await _markDeleted(_tournamentRowsKey, targetOwnerId, id);
    await _markDeleted(_tableRowsKey, targetOwnerId, id);
    await _refreshPendingState();

    final userId = _authenticatedUserId;
    if (userId.isEmpty || targetOwnerId != userId) {
      _setCloudOffline('Турнир удалён локально. Облачное удаление ожидает синхронизации.');
      return;
    }

    try {
      await _deleteRemoteTournament(userId, id);
      await _removeRow(_tournamentRowsKey, userId, id);
      await _removeRow(_tableRowsKey, userId, id);
      _setCloudOnline();
    } catch (error) {
      _setCloudOffline('$error');
    }
    await _refreshPendingState();
  }

  Future<void> updateOwnedTournamentFields(
    String tournamentId,
    Map<String, dynamic> fields,
  ) async {
    final id = tournamentId.trim();
    if (id.isEmpty) return;
    await _migrateLocalOwnerToAuthenticatedUser();
    final ownerId = currentUserId;

    final rows = await _readRows(_tournamentRowsKey);
    Map<String, dynamic>? data;
    for (final row in rows) {
      if ('${row['ownerId'] ?? ''}' == ownerId &&
          '${row['id'] ?? ''}' == id &&
          row['deleted'] != true &&
          row['data'] is Map) {
        data = Map<String, dynamic>.from(row['data'] as Map);
        break;
      }
    }

    if (data == null && _authenticatedUserId.isNotEmpty) {
      try {
        final remote = await _client
            .from('makechess_tournaments_v1')
            .select('data')
            .eq('owner_id', _authenticatedUserId)
            .eq('id', id)
            .maybeSingle();
        if (remote?['data'] is Map) {
          data = Map<String, dynamic>.from(remote!['data'] as Map);
        }
        _setCloudOnline();
      } catch (error) {
        _setCloudOffline('$error');
      }
    }

    data ??= <String, dynamic>{'id': id};
    data.addAll(fields);
    data['id'] = id;
    data['ownerId'] = ownerId;
    await _saveSingleTournamentLocal(ownerId, data, pending: true);

    final userId = _authenticatedUserId;
    if (userId.isEmpty || ownerId != userId) {
      await _refreshPendingState();
      return;
    }

    try {
      await _client.from('makechess_tournaments_v1').upsert(
        <String, dynamic>{
          'owner_id': userId,
          'id': id,
          'data': data,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'owner_id,id',
      );
      await _markRowsSynced(
        _tournamentRowsKey,
        ownerId: userId,
        ids: <String>[id],
      );
      _setCloudOnline();
    } catch (error) {
      _setCloudOffline('$error');
    }
    await _refreshPendingState();
  }

  Future<Map<String, dynamic>?> loadTournamentTable(
    String tournamentId,
  ) async {
    final id = tournamentId.trim();
    if (id.isEmpty) return null;
    await _migrateLocalOwnerToAuthenticatedUser();
    final ownerId = currentUserId;
    final rows = await _readRows(_tableRowsKey);
    final local = _findRow(rows, ownerId, id);

    if (local != null && local['deleted'] != true && local['pending'] == true) {
      final raw = local['data'];
      return raw is Map ? Map<String, dynamic>.from(raw) : null;
    }

    final userId = _authenticatedUserId;
    if (userId.isNotEmpty && ownerId == userId) {
      try {
        final row = await _client
            .from('makechess_tournament_tables_v1')
            .select('data,updated_at')
            .eq('owner_id', userId)
            .eq('tournament_id', id)
            .maybeSingle();
        if (row != null && row['data'] is Map) {
          final data = Map<String, dynamic>.from(row['data'] as Map);
          await _saveSingleTableLocal(userId, id, data, pending: false);
          _setCloudOnline();
          return data;
        }
        _setCloudOnline();
      } catch (error) {
        _setCloudOffline('$error');
      }
    }

    final raw = local?['data'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  Future<Map<String, dynamic>?> loadInvitedTournamentTable({
    required String ownerId,
    required String tournamentId,
  }) async {
    final normalizedOwnerId = ownerId.trim();
    final id = tournamentId.trim();
    if (normalizedOwnerId.isEmpty || id.isEmpty) return null;

    final rows = await _readRows(_tableRowsKey);
    final local = _findRow(rows, normalizedOwnerId, id);
    if (local != null && local['deleted'] != true) {
      final raw = local['data'];
      if (raw is Map) return Map<String, dynamic>.from(raw);
    }

    if (_authenticatedUserId.isEmpty) {
      _setCloudOffline('Для загрузки удалённого турнира нужна база MakeChess.');
      return null;
    }

    try {
      final row = await _client
          .from('makechess_tournament_tables_v1')
          .select('data')
          .eq('owner_id', normalizedOwnerId)
          .eq('tournament_id', id)
          .maybeSingle();
      final raw = row?['data'];
      if (raw is Map) {
        final data = Map<String, dynamic>.from(raw);
        await _saveSingleTableLocal(
          normalizedOwnerId,
          id,
          data,
          pending: false,
        );
        _setCloudOnline();
        return data;
      }
      _setCloudOnline();
    } catch (error) {
      _setCloudOffline('$error');
    }
    return null;
  }

  Future<Set<String>> loadOwnedTournamentParticipantIds(
    String tournamentId, {
    Iterable<String> fallback = const <String>[],
  }) async {
    final result =
        fallback.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    final table = await loadTournamentTable(tournamentId);
    final participants = table?['participants'];
    if (participants is List) {
      for (final participant in participants.whereType<Map>()) {
        final id = '${participant['id'] ?? ''}'.trim();
        if (id.isNotEmpty &&
            !id.startsWith('empty_') &&
            !id.startsWith('linked_')) {
          result.add(id);
        }
      }
    }
    return result;
  }

  Future<void> saveTournamentTable(
    String tournamentId,
    Map<String, dynamic> data,
  ) async {
    final id = tournamentId.trim();
    if (id.isEmpty) return;
    await _migrateLocalOwnerToAuthenticatedUser();
    final ownerId = currentUserId;
    await _saveSingleTableLocal(ownerId, id, data, pending: true);
    await _refreshPendingState();

    final userId = _authenticatedUserId;
    if (userId.isEmpty || ownerId != userId) {
      _setCloudOffline('Таблица турнира сохранена локально.');
      return;
    }

    try {
      await _client.from('makechess_tournament_tables_v1').upsert(
        <String, dynamic>{
          'owner_id': userId,
          'tournament_id': id,
          'data': data,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'owner_id,tournament_id',
      );
      await _markRowsSynced(
        _tableRowsKey,
        ownerId: userId,
        ids: <String>[id],
      );
      _setCloudOnline();
    } catch (error) {
      _setCloudOffline('$error');
    }
    await _refreshPendingState();
  }

  Future<void> acceptInvitation(String messageId) async {
    if (_authenticatedUserId.isEmpty) {
      throw const TournamentCloudRequiredException(
        'Для подтверждения интернет-приглашения нужна база MakeChess.',
      );
    }
    try {
      await _client.rpc(
        'accept_makechess_tournament_invitation_v1',
        params: <String, dynamic>{'p_message_id': messageId},
      );
      _setCloudOnline();
    } catch (error) {
      _setCloudOffline('$error');
      throw const TournamentCloudRequiredException(
        'База MakeChess недоступна. Интернет-приглашение сейчас подтвердить нельзя.',
      );
    }
  }

  int? _intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim());
  }

  int? _restrictionInt(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = _intValue(data[key]);
      if (value != null) return value;
    }
    for (final containerKey in const <String>[
      'restrictions',
      'eligibility',
      'limits',
      'participationRules',
    ]) {
      final raw = data[containerKey];
      if (raw is! Map) continue;
      final nested = Map<String, dynamic>.from(raw);
      for (final key in keys) {
        final value = _intValue(nested[key]);
        if (value != null) return value;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _currentProfile() async {
    final user = _client.auth.currentUser;
    final fallback = <String, dynamic>{
      'nickname': '${user?.userMetadata?['nickname'] ?? user?.userMetadata?['name'] ?? user?.email ?? 'Организатор'}',
      'rating': 1200,
    };
    if (_authenticatedUserId.isEmpty) return fallback;
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', _authenticatedUserId)
          .maybeSingle();
      if (row == null) return fallback;
      _setCloudOnline();
      return <String, dynamic>{...fallback, ...Map<String, dynamic>.from(row)};
    } catch (error) {
      _setCloudOffline('$error');
      return fallback;
    }
  }

  String _profileName(Map<String, dynamic> profile) {
    final user = _client.auth.currentUser;
    for (final value in <Object?>[
      profile['nickname'],
      profile['name'],
      profile['display_name'],
      profile['full_name'],
      user?.userMetadata?['nickname'],
      user?.userMetadata?['name'],
      user?.email,
    ]) {
      final text = '${value ?? ''}'.trim();
      if (text.isNotEmpty) return text;
    }
    return 'Организатор';
  }

  Future<String> _joinOwnerDirectly(String tournamentId) async {
    final userId = currentUserId;
    final tournaments = await loadTournaments();
    Map<String, dynamic>? data;
    for (final tournament in tournaments) {
      if ('${tournament['id'] ?? ''}' == tournamentId) {
        data = Map<String, dynamic>.from(tournament);
        break;
      }
    }
    if (data == null) return 'owner_not_found';

    final idsRaw = data['participantIds'];
    final participantIds = idsRaw is List
        ? idsRaw.map((value) => '$value').where((id) => id.isNotEmpty).toList()
        : <String>[];
    if (participantIds.contains(userId)) return 'already_joined';

    final maxParticipants = _intValue(data['maxParticipants']) ?? 8;
    if (participantIds.length >= maxParticipants) return 'owner_full';

    final tableData = await loadTournamentTable(tournamentId) ?? <String, dynamic>{};
    final profile = await _currentProfile();
    final rating = _intValue(profile['rating']) ?? 1200;

    final minRating = _restrictionInt(
          data,
          const <String>['minRating', 'minimumRating', 'ratingMin', 'min_rating', 'rating_min'],
        ) ??
        _restrictionInt(
          tableData,
          const <String>['minRating', 'minimumRating', 'ratingMin', 'min_rating', 'rating_min'],
        );
    if (minRating != null && rating < minRating) {
      return 'owner_rating_low|$rating|$minRating';
    }

    final maxRating = _restrictionInt(
          data,
          const <String>['maxRating', 'maximumRating', 'ratingMax', 'max_rating', 'rating_max'],
        ) ??
        _restrictionInt(
          tableData,
          const <String>['maxRating', 'maximumRating', 'ratingMax', 'max_rating', 'rating_max'],
        );
    if (maxRating != null && rating > maxRating) {
      return 'owner_rating_high|$rating|$maxRating';
    }

    final participantName = _profileName(profile);
    participantIds.add(userId);
    final participantNamesRaw = data['participantNames'];
    final participantNames = participantNamesRaw is Map
        ? Map<String, dynamic>.from(participantNamesRaw)
        : <String, dynamic>{};
    participantNames[userId] = participantName;

    await updateOwnedTournamentFields(
      tournamentId,
      <String, dynamic>{
        'participantIds': participantIds,
        'participantNames': participantNames,
        if ('${data['status'] ?? ''}' == 'draft' && participantIds.length >= 2)
          'status': 'ready',
      },
    );

    final participantsRaw = tableData['participants'];
    final participants = participantsRaw is List
        ? participantsRaw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    if (!participants.any((item) => '${item['id'] ?? ''}' == userId)) {
      participants.add(<String, dynamic>{
        'id': userId,
        'name': participantName,
        'rating': rating,
        'school': '${profile['school'] ?? profile['club'] ?? ''}',
        'flag': '${profile['country'] ?? profile['flag'] ?? ''}',
        'avatarUrl': '${profile['avatar_url'] ?? profile['avatarUrl'] ?? ''}',
      });
    }
    final mergedTable = <String, dynamic>{
      if (tableData.isEmpty) ...<String, dynamic>{
        'name': '${data['name'] ?? 'Турнир'}',
        'type': '${data['format'] ?? data['type'] ?? ''}',
        'status': '${data['status'] ?? ''}',
        'minutes': data['minutes'] ?? 5,
        'increment': data['increment'] ?? 0,
        'rounds': data['rounds'] ?? 1,
        'maxParticipants': maxParticipants,
        'organizer': participantName,
        'results': const <String, String>{},
      },
      ...tableData,
      'participants': participants,
    };
    await saveTournamentTable(tournamentId, mergedTable);
    return 'owner_joined';
  }

  Future<String> requestParticipation({
    required String ownerId,
    required String tournamentId,
  }) async {
    final normalizedOwnerId = ownerId.trim();
    final normalizedTournamentId = tournamentId.trim();
    if (normalizedTournamentId.isEmpty) return 'owner_not_found';

    if (normalizedOwnerId == currentUserId ||
        (normalizedOwnerId.isEmpty && currentUserId == _localOwnerId)) {
      return _joinOwnerDirectly(normalizedTournamentId);
    }

    if (_authenticatedUserId.isEmpty) return 'cloud_unavailable';
    try {
      final result = await _client.rpc(
        'request_makechess_tournament_participation_v1',
        params: <String, dynamic>{
          'p_owner_id': normalizedOwnerId,
          'p_tournament_id': normalizedTournamentId,
        },
      );
      _setCloudOnline();
      return '$result';
    } catch (error) {
      _setCloudOffline('$error');
      return 'cloud_unavailable';
    }
  }

  Future<void> respondParticipationRequest({
    required String messageId,
    required bool accept,
  }) async {
    if (_authenticatedUserId.isEmpty) {
      throw const TournamentCloudRequiredException(
        'Для ответа на интернет-заявку нужна база MakeChess.',
      );
    }
    try {
      await _client.rpc(
        'respond_makechess_tournament_join_request_v1',
        params: <String, dynamic>{
          'p_message_id': messageId,
          'p_accept': accept,
        },
      );
      _setCloudOnline();
    } catch (error) {
      _setCloudOffline('$error');
      throw const TournamentCloudRequiredException(
        'База MakeChess недоступна. Ответ на интернет-заявку не отправлен.',
      );
    }
  }

  Future<void> startTournamentGames(String tournamentId) async {
    final id = tournamentId.trim();
    if (id.isEmpty || _authenticatedUserId.isEmpty) return;
    try {
      await _client.rpc(
        'start_makechess_tournament_games_v1',
        params: <String, dynamic>{'p_tournament_id': id},
      );
      _setCloudOnline();
    } catch (error) {
      // Local tournament management must continue even when game rows cannot
      // be created in the cloud.
      _setCloudOffline('$error');
    }
  }

  Future<void> controlTournamentGames(
    String tournamentId,
    String status,
  ) async {
    final id = tournamentId.trim();
    if (id.isEmpty || _authenticatedUserId.isEmpty) return;
    try {
      await _client.rpc(
        'control_makechess_tournament_games_v1',
        params: <String, dynamic>{
          'p_tournament_id': id,
          'p_status': status,
        },
      );
      _setCloudOnline();
    } catch (error) {
      _setCloudOffline('$error');
    }
  }

  Future<bool> syncPendingChanges() async {
    final userId = _authenticatedUserId;
    if (userId.isEmpty) {
      _setCloudOffline('Для синхронизации нужна авторизация MakeChess.');
      return false;
    }

    await _migrateLocalOwnerToAuthenticatedUser();
    var tournamentRows = await _readRows(_tournamentRowsKey);
    var tableRows = await _readRows(_tableRowsKey);

    try {
      for (final row in tournamentRows.where((row) =>
          '${row['ownerId'] ?? ''}' == userId && row['pending'] == true)) {
        final id = '${row['id'] ?? ''}'.trim();
        if (id.isEmpty) continue;
        if (row['deleted'] == true) {
          await _deleteRemoteTournament(userId, id);
        } else if (row['data'] is Map) {
          await _client.from('makechess_tournaments_v1').upsert(
            <String, dynamic>{
              'owner_id': userId,
              'id': id,
              'data': Map<String, dynamic>.from(row['data'] as Map),
              'updated_at': '${row['updatedAt'] ?? DateTime.now().toUtc().toIso8601String()}',
            },
            onConflict: 'owner_id,id',
          );
        }
      }

      for (final row in tableRows.where((row) =>
          '${row['ownerId'] ?? ''}' == userId && row['pending'] == true)) {
        final id = '${row['id'] ?? ''}'.trim();
        if (id.isEmpty) continue;
        if (row['deleted'] == true) {
          await _client
              .from('makechess_tournament_tables_v1')
              .delete()
              .eq('owner_id', userId)
              .eq('tournament_id', id);
        } else if (row['data'] is Map) {
          await _client.from('makechess_tournament_tables_v1').upsert(
            <String, dynamic>{
              'owner_id': userId,
              'tournament_id': id,
              'data': Map<String, dynamic>.from(row['data'] as Map),
              'updated_at': '${row['updatedAt'] ?? DateTime.now().toUtc().toIso8601String()}',
            },
            onConflict: 'owner_id,tournament_id',
          );
        }
      }

      tournamentRows = tournamentRows
          .where((row) => !(('${row['ownerId'] ?? ''}' == userId) &&
              row['pending'] == true &&
              row['deleted'] == true))
          .map((row) {
            if ('${row['ownerId'] ?? ''}' == userId && row['pending'] == true) {
              return <String, dynamic>{...row, 'pending': false};
            }
            return row;
          })
          .toList(growable: false);
      tableRows = tableRows
          .where((row) => !(('${row['ownerId'] ?? ''}' == userId) &&
              row['pending'] == true &&
              row['deleted'] == true))
          .map((row) {
            if ('${row['ownerId'] ?? ''}' == userId && row['pending'] == true) {
              return <String, dynamic>{...row, 'pending': false};
            }
            return row;
          })
          .toList(growable: false);
      await _writeRows(_tournamentRowsKey, tournamentRows);
      await _writeRows(_tableRowsKey, tableRows);
      _setCloudOnline();
      await _refreshPendingState();
      return true;
    } catch (error) {
      _setCloudOffline('$error');
      await _refreshPendingState();
      return false;
    }
  }

  /// Creates one portable JSON backup containing local tournaments and tables.
  Future<String> exportLocalBundle() async {
    final ownerId = currentUserId;
    final tournamentRows = (await _readRows(_tournamentRowsKey))
        .where((row) => '${row['ownerId'] ?? ''}' == ownerId)
        .toList(growable: false);
    final tableRows = (await _readRows(_tableRowsKey))
        .where((row) => '${row['ownerId'] ?? ''}' == ownerId)
        .toList(growable: false);
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'format': 'makechess-tournament-bundle',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tournaments': tournamentRows,
      'tables': tableRows,
    });
  }

  /// Imports a portable backup and keeps every imported row local-first.
  Future<int> importLocalBundle(String text) async {
    final decoded = jsonDecode(text);
    if (decoded is! Map || decoded['format'] != 'makechess-tournament-bundle') {
      throw const FormatException('Это не файл турниров MakeChess');
    }
    final importedTournaments = (decoded['tournaments'] is List)
        ? (decoded['tournaments'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    final importedTables = (decoded['tables'] is List)
        ? (decoded['tables'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    var tournamentRows = await _readRows(_tournamentRowsKey);
    for (final row in importedTournaments) {
      final ownerId = currentUserId;
      final id = '${row['id'] ?? ''}'.trim();
      if (id.isEmpty || row['data'] is! Map) continue;
      final importedData = Map<String, dynamic>.from(row['data'] as Map)
        ..['ownerId'] = ownerId;
      tournamentRows = _upsertRow(
        tournamentRows,
        ownerId: ownerId,
        id: id,
        data: importedData,
        updatedAt: '${row['updatedAt'] ?? DateTime.now().toUtc().toIso8601String()}',
        pending: true,
        deleted: row['deleted'] == true,
      );
    }

    var tableRows = await _readRows(_tableRowsKey);
    for (final row in importedTables) {
      final ownerId = currentUserId;
      final id = '${row['id'] ?? ''}'.trim();
      if (id.isEmpty || row['data'] is! Map) continue;
      tableRows = _upsertRow(
        tableRows,
        ownerId: ownerId,
        id: id,
        data: Map<String, dynamic>.from(row['data'] as Map),
        updatedAt: '${row['updatedAt'] ?? DateTime.now().toUtc().toIso8601String()}',
        pending: true,
        deleted: row['deleted'] == true,
      );
    }
    await _writeRows(_tournamentRowsKey, tournamentRows);
    await _writeRows(_tableRowsKey, tableRows);
    await _migrateLocalOwnerToAuthenticatedUser();
    await _refreshPendingState();
    return importedTournaments.length;
  }

  Future<void> _deleteRemoteTournament(String ownerId, String tournamentId) async {
    await _client
        .from('makechess_tournament_tables_v1')
        .delete()
        .eq('owner_id', ownerId)
        .eq('tournament_id', tournamentId);
    await _client
        .from('makechess_tournaments_v1')
        .delete()
        .eq('owner_id', ownerId)
        .eq('id', tournamentId);
  }

  Future<List<Map<String, dynamic>>> _mergeRemoteTournamentRows(
    List<Map<String, dynamic>> localRows,
    List<Map> remoteRows,
  ) async {
    var merged = List<Map<String, dynamic>>.from(localRows);
    for (final remote in remoteRows) {
      final ownerId = '${remote['owner_id'] ?? ''}'.trim();
      final id = '${remote['id'] ?? ''}'.trim();
      final raw = remote['data'];
      if (ownerId.isEmpty || id.isEmpty || raw is! Map) continue;
      final existing = _findRow(merged, ownerId, id);
      if (existing != null && existing['pending'] == true) continue;
      merged = _upsertRow(
        merged,
        ownerId: ownerId,
        id: id,
        data: Map<String, dynamic>.from(raw),
        updatedAt: '${remote['updated_at'] ?? DateTime.now().toUtc().toIso8601String()}',
        pending: false,
        deleted: false,
      );
    }
    await _writeRows(_tournamentRowsKey, merged);
    return merged;
  }

  Future<void> _saveSingleTournamentLocal(
    String ownerId,
    Map<String, dynamic> data, {
    required bool pending,
  }) async {
    final id = '${data['id'] ?? ''}'.trim();
    if (id.isEmpty) return;
    final rows = await _readRows(_tournamentRowsKey);
    final merged = _upsertRow(
      rows,
      ownerId: ownerId,
      id: id,
      data: data,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      pending: pending,
      deleted: false,
    );
    await _writeRows(_tournamentRowsKey, merged);
  }

  Future<void> _saveSingleTableLocal(
    String ownerId,
    String tournamentId,
    Map<String, dynamic> data, {
    required bool pending,
  }) async {
    final rows = await _readRows(_tableRowsKey);
    final merged = _upsertRow(
      rows,
      ownerId: ownerId,
      id: tournamentId,
      data: data,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      pending: pending,
      deleted: false,
    );
    await _writeRows(_tableRowsKey, merged);
  }

  List<Map<String, dynamic>> _upsertRow(
    List<Map<String, dynamic>> rows, {
    required String ownerId,
    required String id,
    required Map<String, dynamic> data,
    required String updatedAt,
    required bool pending,
    required bool deleted,
  }) {
    final result = List<Map<String, dynamic>>.from(rows);
    final index = result.indexWhere((row) =>
        '${row['ownerId'] ?? ''}' == ownerId && '${row['id'] ?? ''}' == id);
    final record = <String, dynamic>{
      'ownerId': ownerId,
      'id': id,
      'data': data,
      'updatedAt': updatedAt,
      'pending': pending,
      'deleted': deleted,
    };
    if (index >= 0) {
      result[index] = record;
    } else {
      result.add(record);
    }
    return result;
  }

  Map<String, dynamic>? _findRow(
    List<Map<String, dynamic>> rows,
    String ownerId,
    String id,
  ) {
    for (final row in rows) {
      if ('${row['ownerId'] ?? ''}' == ownerId && '${row['id'] ?? ''}' == id) {
        return row;
      }
    }
    return null;
  }

  Future<void> _markDeleted(String key, String ownerId, String id) async {
    var rows = await _readRows(key);
    final existing = _findRow(rows, ownerId, id);
    final data = existing?['data'] is Map
        ? Map<String, dynamic>.from(existing!['data'] as Map)
        : <String, dynamic>{'id': id};
    rows = _upsertRow(
      rows,
      ownerId: ownerId,
      id: id,
      data: data,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      pending: true,
      deleted: true,
    );
    await _writeRows(key, rows);
  }

  Future<void> _markRowsSynced(
    String key, {
    required String ownerId,
    required Iterable<String> ids,
  }) async {
    final idSet = ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final rows = await _readRows(key);
    final updated = rows.map((row) {
      if ('${row['ownerId'] ?? ''}' == ownerId &&
          idSet.contains('${row['id'] ?? ''}')) {
        return <String, dynamic>{...row, 'pending': false};
      }
      return row;
    }).toList(growable: false);
    await _writeRows(key, updated);
  }

  Future<void> _removeRow(String key, String ownerId, String id) async {
    final rows = await _readRows(key);
    await _writeRows(
      key,
      rows
          .where((row) => !('${row['ownerId'] ?? ''}' == ownerId &&
              '${row['id'] ?? ''}' == id))
          .toList(growable: false),
    );
  }

  Future<void> _migrateLocalOwnerToAuthenticatedUser() async {
    final userId = _authenticatedUserId;
    if (userId.isEmpty) return;

    for (final key in <String>[_tournamentRowsKey, _tableRowsKey]) {
      final rows = await _readRows(key);
      var changed = false;
      final migrated = rows.map((row) {
        if ('${row['ownerId'] ?? ''}' != _localOwnerId) return row;
        changed = true;
        final data = row['data'] is Map
            ? Map<String, dynamic>.from(row['data'] as Map)
            : <String, dynamic>{};
        if (key == _tournamentRowsKey) data['ownerId'] = userId;
        return <String, dynamic>{
          ...row,
          'ownerId': userId,
          'data': data,
          'pending': true,
        };
      }).toList(growable: false);
      if (changed) await _writeRows(key, migrated);
    }
  }

  Future<List<Map<String, dynamic>>> _readRows(String key) async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(key);

    // Desktop fallback: if SharedPreferences is empty, recover from the
    // visible local mirror in Documents\\MakeChess\\Tournaments.
    if (raw == null || raw.trim().isEmpty) {
      raw = await TournamentDiskMirror.read(key);
      if (raw != null && raw.trim().isNotEmpty) {
        await prefs.setString(key, raw);
      }
    }

    if (raw == null || raw.trim().isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    } catch (_) {
      final mirror = await TournamentDiskMirror.read(key);
      if (mirror == null || mirror.trim().isEmpty || mirror == raw) {
        return <Map<String, dynamic>>[];
      }
      try {
        final decoded = jsonDecode(mirror);
        if (decoded is! List) return <Map<String, dynamic>>[];
        await prefs.setString(key, mirror);
        return decoded
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }
  }

  Future<void> _writeRows(
    String key,
    List<Map<String, dynamic>> rows,
  ) async {
    final encoded = jsonEncode(rows);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, encoded);

    try {
      await TournamentDiskMirror.write(key, encoded);
    } catch (_) {
      // The primary local save already succeeded; mirror failures never stop play.
    }
  }

  Future<String?> get localFolderPath => TournamentDiskMirror.folderPath();

  Future<void> _refreshPendingState() async {
    final tournaments = await _readRows(_tournamentRowsKey);
    final tables = await _readRows(_tableRowsKey);
    final next = tournaments.any((row) => row['pending'] == true) ||
        tables.any((row) => row['pending'] == true);
    if (_hasPendingChanges != next) {
      _hasPendingChanges = next;
      notifyListeners();
    }
  }

  void _setCloudOnline() {
    final changed = _cloudState != TournamentCloudState.online ||
        _lastCloudError.isNotEmpty;
    _cloudState = TournamentCloudState.online;
    _lastCloudError = '';
    if (changed) notifyListeners();
  }

  void _setCloudOffline(String error) {
    final changed = _cloudState != TournamentCloudState.offline ||
        _lastCloudError != error;
    _cloudState = TournamentCloudState.offline;
    _lastCloudError = error;
    if (changed) notifyListeners();
  }
}
