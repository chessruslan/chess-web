import 'package:supabase_flutter/supabase_flutter.dart';

class TournamentStorageService {
  TournamentStorageService._();

  static final TournamentStorageService instance = TournamentStorageService._();

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId => (_client.auth.currentUser?.id ?? '').trim();

  String get currentUserId => _userId;

  Future<List<Map<String, dynamic>>> loadVisibleTournaments() async {
    if (_userId.isEmpty) return <Map<String, dynamic>>[];
    final rows = await _client
        .from('makechess_tournaments_v1')
        .select('owner_id,data')
        .order('updated_at', ascending: false);
    return (rows as List)
        .whereType<Map>()
        .map((row) {
          final raw = row['data'];
          if (raw is! Map) return null;
          return <String, dynamic>{
            ...Map<String, dynamic>.from(raw),
            '_ownerId': '${row['owner_id'] ?? ''}',
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> loadTournaments() async {
    final userId = _userId;
    if (userId.isEmpty) return <Map<String, dynamic>>[];
    final rows = await _client
        .from('makechess_tournaments_v1')
        .select('data')
        .eq('owner_id', userId)
        .order('updated_at', ascending: false);
    return (rows as List)
        .whereType<Map>()
        .map((row) => row['data'])
        .whereType<Map>()
        .map((data) => Map<String, dynamic>.from(data))
        .toList(growable: false);
  }

  Future<void> saveTournaments(
    Iterable<Map<String, dynamic>> tournaments,
  ) async {
    final userId = _userId;
    if (userId.isEmpty) return;
    final rows = tournaments
        .where((data) => '${data['id'] ?? ''}'.trim().isNotEmpty)
        .map((data) => <String, dynamic>{
              'owner_id': userId,
              'id': '${data['id']}',
              'data': data,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
        .toList(growable: false);
    if (rows.isEmpty) return;
    await _client
        .from('makechess_tournaments_v1')
        .upsert(rows, onConflict: 'owner_id,id');
  }

  Future<void> deleteTournament(String tournamentId) async {
    final userId = _userId;
    if (userId.isEmpty || tournamentId.trim().isEmpty) return;
    await _client
        .from('makechess_tournaments_v1')
        .delete()
        .eq('owner_id', userId)
        .eq('id', tournamentId);
  }

  Future<void> updateOwnedTournamentFields(
    String tournamentId,
    Map<String, dynamic> fields,
  ) async {
    final userId = _userId;
    if (userId.isEmpty || tournamentId.trim().isEmpty) return;
    final row = await _client
        .from('makechess_tournaments_v1')
        .select('data')
        .eq('owner_id', userId)
        .eq('id', tournamentId)
        .maybeSingle();
    final raw = row?['data'];
    if (raw is! Map) throw StateError('Турнир не найден');
    final data = Map<String, dynamic>.from(raw)..addAll(fields);
    await _client
        .from('makechess_tournaments_v1')
        .update(<String, dynamic>{
          'data': data,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('owner_id', userId)
        .eq('id', tournamentId);
  }

  Future<Map<String, dynamic>?> loadTournamentTable(
    String tournamentId,
  ) async {
    final userId = _userId;
    if (userId.isEmpty || tournamentId.trim().isEmpty) return null;
    final row = await _client
        .from('makechess_tournament_tables_v1')
        .select('data')
        .eq('owner_id', userId)
        .eq('tournament_id', tournamentId)
        .maybeSingle();
    final data = row?['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<Map<String, dynamic>?> loadInvitedTournamentTable({
    required String ownerId,
    required String tournamentId,
  }) async {
    if (_userId.isEmpty ||
        ownerId.trim().isEmpty ||
        tournamentId.trim().isEmpty) {
      return null;
    }
    final row = await _client
        .from('makechess_tournament_tables_v1')
        .select('data')
        .eq('owner_id', ownerId)
        .eq('tournament_id', tournamentId)
        .maybeSingle();
    final data = row?['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
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
    final userId = _userId;
    if (userId.isEmpty || tournamentId.trim().isEmpty) return;
    await _client.from('makechess_tournament_tables_v1').upsert(
      <String, dynamic>{
        'owner_id': userId,
        'tournament_id': tournamentId,
        'data': data,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'owner_id,tournament_id',
    );
  }

  Future<void> acceptInvitation(String messageId) async {
    if (_userId.isEmpty) return;
    await _client.rpc(
      'accept_makechess_tournament_invitation_v1',
      params: <String, dynamic>{'p_message_id': messageId},
    );
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
    if (_userId.isEmpty) return <String, dynamic>{};
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', _userId)
          .maybeSingle();
      return row is Map ? Map<String, dynamic>.from(row) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
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
    final userId = _userId;
    if (userId.isEmpty) return 'not_authenticated';

    final row = await _client
        .from('makechess_tournaments_v1')
        .select('data')
        .eq('owner_id', userId)
        .eq('id', tournamentId)
        .maybeSingle();
    final raw = row?['data'];
    if (raw is! Map) return 'owner_not_found';

    final data = Map<String, dynamic>.from(raw);
    final idsRaw = data['participantIds'];
    final participantIds = idsRaw is List
        ? idsRaw.map((value) => '$value').where((id) => id.isNotEmpty).toList()
        : <String>[];

    if (participantIds.contains(userId)) return 'already_joined';

    final maxParticipants = _intValue(data['maxParticipants']) ?? 8;
    if (participantIds.length >= maxParticipants) return 'owner_full';

    Map<String, dynamic> tableData = <String, dynamic>{};
    try {
      final tableRow = await _client
          .from('makechess_tournament_tables_v1')
          .select('data')
          .eq('owner_id', userId)
          .eq('tournament_id', tournamentId)
          .maybeSingle();
      final tableRaw = tableRow?['data'];
      if (tableRaw is Map) {
        tableData = Map<String, dynamic>.from(tableRaw);
      }
    } catch (_) {
      // The tournament record remains the source of truth if the visual
      // tournament table has not been created yet.
    }

    final profile = await _currentProfile();
    final rating = _intValue(profile['rating']) ?? 1200;

    final minRating = _restrictionInt(
          data,
          const <String>[
            'minRating',
            'minimumRating',
            'ratingMin',
            'min_rating',
            'rating_min',
          ],
        ) ??
        _restrictionInt(
          tableData,
          const <String>[
            'minRating',
            'minimumRating',
            'ratingMin',
            'min_rating',
            'rating_min',
          ],
        );
    if (minRating != null && rating < minRating) {
      return 'owner_rating_low|$rating|$minRating';
    }

    final maxRating = _restrictionInt(
          data,
          const <String>[
            'maxRating',
            'maximumRating',
            'ratingMax',
            'max_rating',
            'rating_max',
          ],
        ) ??
        _restrictionInt(
          tableData,
          const <String>[
            'maxRating',
            'maximumRating',
            'ratingMax',
            'max_rating',
            'rating_max',
          ],
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

    data['participantIds'] = participantIds;
    data['participantNames'] = participantNames;
    if ('${data['status'] ?? ''}' == 'draft' && participantIds.length >= 2) {
      data['status'] = 'ready';
    }

    await _client
        .from('makechess_tournaments_v1')
        .update(<String, dynamic>{
          'data': data,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('owner_id', userId)
        .eq('id', tournamentId);

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
        'avatarUrl':
            '${profile['avatar_url'] ?? profile['avatarUrl'] ?? ''}',
      });
    }

    if (tableData.isEmpty) {
      tableData = <String, dynamic>{
        'name': '${data['name'] ?? 'Турнир'}',
        'type': '${data['format'] ?? data['type'] ?? ''}',
        'status': '${data['status'] ?? ''}',
        'minutes': data['minutes'] ?? 5,
        'increment': data['increment'] ?? 0,
        'rounds': data['rounds'] ?? 1,
        'maxParticipants': maxParticipants,
        'organizer': participantName,
        'results': const <String, String>{},
      };
    }
    tableData['participants'] = participants;

    await _client.from('makechess_tournament_tables_v1').upsert(
      <String, dynamic>{
        'owner_id': userId,
        'tournament_id': tournamentId,
        'data': tableData,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'owner_id,tournament_id',
    );

    return 'owner_joined';
  }

  Future<String> requestParticipation({
    required String ownerId,
    required String tournamentId,
  }) async {
    final userId = _userId;
    if (userId.isEmpty) return 'not_authenticated';

    final normalizedOwnerId = ownerId.trim();
    final normalizedTournamentId = tournamentId.trim();
    if (normalizedTournamentId.isEmpty) return 'owner_not_found';

    // A tournament creator is not automatically a participant. When the
    // creator explicitly presses "Join", they are added directly without
    // sending an invitation/message to themselves.
    if (normalizedOwnerId == userId) {
      return _joinOwnerDirectly(normalizedTournamentId);
    }

    final result = await _client.rpc(
      'request_makechess_tournament_participation_v1',
      params: <String, dynamic>{
        'p_owner_id': normalizedOwnerId,
        'p_tournament_id': normalizedTournamentId,
      },
    );
    return '$result';
  }

  Future<void> respondParticipationRequest({
    required String messageId,
    required bool accept,
  }) async {
    await _client.rpc(
      'respond_makechess_tournament_join_request_v1',
      params: <String, dynamic>{
        'p_message_id': messageId,
        'p_accept': accept,
      },
    );
  }

  Future<void> startTournamentGames(String tournamentId) async {
    if (_userId.isEmpty || tournamentId.trim().isEmpty) return;
    await _client.rpc(
      'start_makechess_tournament_games_v1',
      params: <String, dynamic>{'p_tournament_id': tournamentId},
    );
  }

  Future<void> controlTournamentGames(
    String tournamentId,
    String status,
  ) async {
    if (_userId.isEmpty || tournamentId.trim().isEmpty) return;
    await _client.rpc(
      'control_makechess_tournament_games_v1',
      params: <String, dynamic>{
        'p_tournament_id': tournamentId,
        'p_status': status,
      },
    );
  }
}
