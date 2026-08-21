// MAKECHESS_REMAINING_UI_V6_20260807
// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
// MAKECHESS_BIG_LOCALIZATION_STAGE_V4_20260807
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/tournament_storage_service.dart';
import '../../services/teacher_account_store.dart';
import '../app_style.dart';
import '../messages/general_messages_dialog.dart';
import 'tournament_game_platform_dialog.dart';
import 'student_tournaments_dialog.dart';
import 'tournament_table_editor.dart';
import '../../localization/makechess_localization.dart';

class TournamentStudent {
  const TournamentStudent({
    required this.id,
    required this.name,
    required this.online,
    this.isOwner = false,
    this.rating = 1200,
    this.country = '',
    this.gamesPlayed = 0,
  });

  final String id;
  final String name;
  final bool online;
  final bool isOwner;
  final int rating;
  final String country;
  final int gamesPlayed;
}

Future<void> showTournamentManagerDialog({
  required BuildContext context,
  required List<TournamentStudent> students,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => TournamentManagerDialog(students: students),
  );
}

class TournamentManagerDialog extends StatefulWidget {
  const TournamentManagerDialog({
    super.key,
    required this.students,
  });

  final List<TournamentStudent> students;

  @override
  State<TournamentManagerDialog> createState() =>
      _TournamentManagerDialogState();
}

enum _TournamentSection {
  create,
  open,
  current,
  participants,
  pairing,
  games,
  standings,
  settings,
  control,
  statistics,
  archive,
}

enum _OpenTournamentTab {
  current,
  newTournament,
}

enum _TournamentType {
  learning,
  open,
  interschool,
  simul,
  team,
  teamGrid,
}

enum _TournamentFormat {
  roundRobin,
  swiss,
  knockout,
}

enum _TournamentStatus {
  draft,
  ready,
  running,
  paused,
  finished,
}

extension on _TournamentType {
  String get label {
    switch (this) {
      case _TournamentType.learning:
        return 'Учебный турнир';
      case _TournamentType.open:
        return 'Открытый турнир (OPEN)';
      case _TournamentType.interschool:
        return 'Межшкольный турнир';
      case _TournamentType.simul:
        return 'Сеанс одновременной игры';
      case _TournamentType.team:
        return 'Командная игра';
      case _TournamentType.teamGrid:
        return 'Групповая игра';
    }
  }

  String get description {
    switch (this) {
      case _TournamentType.learning:
        return 'Турнир проводится внутри режима «Учиться».';
      case _TournamentType.open:
        return 'Открытый формат турнира OPEN.';
      case _TournamentType.interschool:
        return 'Турнир между учениками разных школ.';
      case _TournamentType.simul:
        return 'Один ведущий одновременно играет с несколькими участниками.';
      case _TournamentType.team:
        return 'Игроки одной команды могут обсуждать позицию и помогать друг другу.';
      case _TournamentType.teamGrid:
        return 'Игроки играют самостоятельно, а их результаты складываются в результат группы.';
    }
  }
}

extension on _TournamentFormat {
  String get label {
    switch (this) {
      case _TournamentFormat.roundRobin:
        return 'Круговая';
      case _TournamentFormat.swiss:
        return 'Швейцарская';
      case _TournamentFormat.knockout:
        return 'Олимпийская';
    }
  }
}

extension on _TournamentStatus {
  String get label {
    switch (this) {
      case _TournamentStatus.draft:
        return 'Черновик';
      case _TournamentStatus.ready:
        return 'Готов к запуску';
      case _TournamentStatus.running:
        return 'Идёт';
      case _TournamentStatus.paused:
        return 'Приостановлен';
      case _TournamentStatus.finished:
        return 'Завершён';
    }
  }

  Color get color {
    switch (this) {
      case _TournamentStatus.draft:
        return Colors.blueGrey;
      case _TournamentStatus.ready:
        return Colors.lightBlueAccent;
      case _TournamentStatus.running:
        return Colors.greenAccent;
      case _TournamentStatus.paused:
        return Colors.orangeAccent;
      case _TournamentStatus.finished:
        return Colors.purpleAccent;
    }
  }
}

class _TournamentPairing {
  const _TournamentPairing({
    required this.board,
    required this.whiteId,
    required this.blackId,
    this.result = '*',
    this.pgn = '',
    this.finalFen = '',
    this.resultReason = '',
    this.durationSeconds = 0,
  });

  final int board;
  final String whiteId;
  final String? blackId;
  final String result;
  final String pgn;
  final String finalFen;
  final String resultReason;
  final int durationSeconds;

  _TournamentPairing copyWith({
    String? result,
    String? pgn,
    String? finalFen,
    String? resultReason,
    int? durationSeconds,
  }) {
    return _TournamentPairing(
      board: board,
      whiteId: whiteId,
      blackId: blackId,
      result: result ?? this.result,
      pgn: pgn ?? this.pgn,
      finalFen: finalFen ?? this.finalFen,
      resultReason: resultReason ?? this.resultReason,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'board': board,
        'whiteId': whiteId,
        'blackId': blackId,
        'result': result,
        'pgn': pgn,
        'finalFen': finalFen,
        'resultReason': resultReason,
        'durationSeconds': durationSeconds,
      };

  factory _TournamentPairing.fromJson(Map<String, dynamic> json) {
    return _TournamentPairing(
      board: (json['board'] as num?)?.toInt() ?? 1,
      whiteId: '${json['whiteId'] ?? ''}',
      blackId: json['blackId'] == null ? null : '${json['blackId']}',
      result: '${json['result'] ?? '*'}',
      pgn: '${json['pgn'] ?? ''}',
      finalFen: '${json['finalFen'] ?? ''}',
      resultReason: '${json['resultReason'] ?? ''}',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class _TournamentRoundSnapshot {
  const _TournamentRoundSnapshot({
    required this.roundNumber,
    required this.pairings,
    required this.savedAt,
  });

  final int roundNumber;
  final List<_TournamentPairing> pairings;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'roundNumber': roundNumber,
        'pairings': pairings.map((e) => e.toJson()).toList(),
        'savedAt': savedAt.toIso8601String(),
      };

  factory _TournamentRoundSnapshot.fromJson(Map<String, dynamic> json) {
    final pairingsRaw = json['pairings'];
    return _TournamentRoundSnapshot(
      roundNumber: (json['roundNumber'] as num?)?.toInt() ?? 1,
      pairings: pairingsRaw is List
          ? pairingsRaw
              .whereType<Map>()
              .map((e) => _TournamentPairing.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : <_TournamentPairing>[],
      savedAt: DateTime.tryParse('${json['savedAt'] ?? ''}') ?? DateTime.now(),
    );
  }
}

class _TournamentData {
  const _TournamentData({
    required this.id,
    required this.name,
    required this.type,
    required this.format,
    required this.maxParticipants,
    required this.minutes,
    required this.increment,
    required this.rounds,
    required this.rated,
    required this.videoEnabled,
    required this.saveGames,
    required this.status,
    required this.createdAt,
    this.isTemplate = false,
    this.participantIds = const <String>[],
    this.participantNames = const <String, String>{},
    this.currentRound = 0,
    this.pairings = const <_TournamentPairing>[],
    this.roundHistory = const <_TournamentRoundSnapshot>[],
    this.finishedAt,
  });

  final String id;
  final String name;
  final _TournamentType type;
  final _TournamentFormat format;
  final int maxParticipants;
  final int minutes;
  final int increment;
  final int rounds;
  final bool rated;
  bool get learning => type == _TournamentType.learning;
  final bool videoEnabled;
  final bool saveGames;
  final _TournamentStatus status;
  final DateTime createdAt;
  final bool isTemplate;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final int currentRound;
  final List<_TournamentPairing> pairings;
  final List<_TournamentRoundSnapshot> roundHistory;
  final DateTime? finishedAt;

  _TournamentData copyWith({
    String? name,
    _TournamentType? type,
    _TournamentFormat? format,
    int? maxParticipants,
    int? minutes,
    int? increment,
    int? rounds,
    bool? rated,
    bool? videoEnabled,
    bool? saveGames,
    _TournamentStatus? status,
    List<String>? participantIds,
    Map<String, String>? participantNames,
    int? currentRound,
    List<_TournamentPairing>? pairings,
    List<_TournamentRoundSnapshot>? roundHistory,
    DateTime? finishedAt,
    bool? isTemplate,
  }) {
    return _TournamentData(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      format: format ?? this.format,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      minutes: minutes ?? this.minutes,
      increment: increment ?? this.increment,
      rounds: rounds ?? this.rounds,
      rated: rated ?? this.rated,
      videoEnabled: videoEnabled ?? this.videoEnabled,
      saveGames: saveGames ?? this.saveGames,
      status: status ?? this.status,
      createdAt: createdAt,
      isTemplate: isTemplate ?? this.isTemplate,
      participantIds: participantIds ?? this.participantIds,
      participantNames: participantNames ?? this.participantNames,
      currentRound: currentRound ?? this.currentRound,
      pairings: pairings ?? this.pairings,
      roundHistory: roundHistory ?? this.roundHistory,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'type': type.name,
        'format': format.name,
        'maxParticipants': maxParticipants,
        'minutes': minutes,
        'increment': increment,
        'rounds': rounds,
        'rated': rated,
        'learning': learning,
        'videoEnabled': videoEnabled,
        'saveGames': saveGames,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'isTemplate': isTemplate,
        'participantIds': participantIds,
        'participantNames': participantNames,
        'currentRound': currentRound,
        'pairings': pairings.map((e) => e.toJson()).toList(),
        'roundHistory': roundHistory.map((e) => e.toJson()).toList(),
        'finishedAt': finishedAt?.toIso8601String(),
      };

  factory _TournamentData.fromJson(Map<String, dynamic> json) {
    _TournamentType parseType(String raw, bool legacyLearning) {
      if (raw.trim().isNotEmpty) {
        return _TournamentType.values.firstWhere(
          (e) => e.name == raw,
          orElse: () =>
              legacyLearning ? _TournamentType.learning : _TournamentType.open,
        );
      }
      return legacyLearning ? _TournamentType.learning : _TournamentType.open;
    }

    _TournamentFormat parseFormat(String raw) {
      return _TournamentFormat.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => _TournamentFormat.roundRobin,
      );
    }

    _TournamentStatus parseStatus(String raw) {
      return _TournamentStatus.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => _TournamentStatus.draft,
      );
    }

    final idsRaw = json['participantIds'];
    final pairingsRaw = json['pairings'];
    final historyRaw = json['roundHistory'];
    final namesRaw = json['participantNames'];
    return _TournamentData(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? 'Турнир'}',
      type: parseType(
        '${json['type'] ?? ''}',
        json['learning'] != false,
      ),
      format: parseFormat('${json['format'] ?? ''}'),
      maxParticipants: (json['maxParticipants'] as num?)?.toInt() ?? 8,
      minutes: (json['minutes'] as num?)?.toInt() ?? 5,
      increment: (json['increment'] as num?)?.toInt() ?? 0,
      rounds: (json['rounds'] as num?)?.toInt() ?? 3,
      rated: json['rated'] == true,
      videoEnabled: json['videoEnabled'] != false,
      saveGames: json['saveGames'] != false,
      status: parseStatus('${json['status'] ?? ''}'),
      createdAt:
          DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
      isTemplate: json['isTemplate'] == true ||
          '${json['id'] ?? ''}'.contains('template'),
      participantIds: idsRaw is List
          ? idsRaw.map((e) => '$e').where((e) => e.isNotEmpty).toList()
          : <String>[],
      participantNames: namesRaw is Map
          ? Map<String, String>.fromEntries(
              namesRaw.entries.map(
                (e) => MapEntry('${e.key}', '${e.value}'),
              ),
            )
          : const <String, String>{},
      currentRound: (json['currentRound'] as num?)?.toInt() ?? 0,
      pairings: pairingsRaw is List
          ? pairingsRaw
              .whereType<Map>()
              .map((e) => _TournamentPairing.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : <_TournamentPairing>[],
      roundHistory: historyRaw is List
          ? historyRaw
              .whereType<Map>()
              .map((e) => _TournamentRoundSnapshot.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : <_TournamentRoundSnapshot>[],
      finishedAt: DateTime.tryParse('${json['finishedAt'] ?? ''}'),
    );
  }
}

enum _StudentSecondaryActionState { disabled, enabled, sent, participating }

enum _ParticipantDirectoryTab { mySchool, otherSchool, all }

enum _ParticipantSort { name, rating, recentTournaments }

enum _InvitationTournamentTab { current, mine }

class _VisibleInvitationTournament {
  const _VisibleInvitationTournament({
    required this.tournament,
    required this.ownerId,
  });

  final _TournamentData tournament;
  final String ownerId;
}

class _TournamentManagerDialogState extends State<TournamentManagerDialog> {
  static const String _storageKey = 'makechess_teacher_tournaments_v1';
  static const String _systemRoundRobinTemplateId =
      'autumn_cup_round_robin_template_v1';
  static const String _systemRoundRobinTemplateName = 'Круговая система №1';
  static const String _sentInvitationsStorageKey =
      'makechess_sent_tournament_invitations_v1';

  final TextEditingController _nameCtl = TextEditingController();
  final TextEditingController _maxCtl = TextEditingController(text: '8');
  final TextEditingController _minutesCtl = TextEditingController(text: '5');
  final TextEditingController _incrementCtl = TextEditingController(text: '0');
  final TextEditingController _roundsCtl = TextEditingController(text: '3');
  final TextEditingController _participantSearchCtl = TextEditingController();
  final TextEditingController _tournamentSearchCtl = TextEditingController();
  final TextEditingController _schoolSearchCtl = TextEditingController();

  _TournamentSection _section = _TournamentSection.create;
  _OpenTournamentTab _openTab = _OpenTournamentTab.current;
  _TournamentType _type = _TournamentType.learning;
  _TournamentFormat _format = _TournamentFormat.roundRobin;
  bool _rated = false;
  bool _videoEnabled = true;
  bool _saveGames = true;
  bool _loading = true;

  final List<_TournamentData> _tournaments = <_TournamentData>[];
  String? _activeTournamentId;
  final Set<String> _draftParticipantIds = <String>{};
  String? _openedArchiveTournamentId;
  bool _archiveShowGames = false;
  String? _invitationTournamentId;
  final Set<String> _sentInvitationKeys = <String>{};
  TournamentStudent? _ownerStudent;
  final List<TournamentStudent> _directoryStudents = <TournamentStudent>[];
  final List<TeacherAccount> _registeredSchools = <TeacherAccount>[];
  String? _selectedSchoolId;
  bool _schoolPickerExpanded = false;
  final Set<String> _expandedSchoolIds = <String>{};
  final Set<String> _loadingSchoolIds = <String>{};
  final Map<String, List<TournamentStudent>> _schoolMembers =
      <String, List<TournamentStudent>>{};
  _ParticipantDirectoryTab _participantDirectoryTab =
      _ParticipantDirectoryTab.mySchool;
  _ParticipantSort _participantSort = _ParticipantSort.name;
  _InvitationTournamentTab _invitationTournamentTab =
      _InvitationTournamentTab.current;
  final List<_VisibleInvitationTournament> _visibleInvitationTournaments =
      <_VisibleInvitationTournament>[];

  _TournamentData? get _activeTournament {
    final id = _activeTournamentId;
    if (id == null) return null;
    for (final tournament in _tournaments) {
      if (tournament.id == id) return tournament;
    }
    return null;
  }

  _TournamentData? get _invitationTournament {
    final id = _invitationTournamentId;
    if (id == null) return null;
    for (final tournament in _workingTournaments) {
      if (tournament.id == id) return tournament;
    }
    return null;
  }

  String _invitationKey(String tournamentId, String studentId) =>
      '$tournamentId::$studentId';

  _TournamentData? get _openedArchiveTournament {
    final id = _openedArchiveTournamentId;
    if (id == null) return null;
    for (final tournament in _tournaments) {
      if (tournament.id == id &&
          tournament.status == _TournamentStatus.finished) {
        return tournament;
      }
    }
    return null;
  }

  List<_TournamentData> get _workingTournaments => _tournaments
      .where((e) => e.status != _TournamentStatus.finished && !e.isTemplate)
      .toList(growable: false);

  List<_TournamentData> get _tournamentTemplates => _tournaments
      .where((e) => e.status != _TournamentStatus.finished && e.isTemplate)
      .toList(growable: false);

  List<_TournamentData> get _archivedTournaments => _tournaments
      .where((e) => e.status == _TournamentStatus.finished)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _loadOwnerStudent();
    _loadParticipantDirectory();
    _loadRegisteredSchools();
    _load();
  }

  Future<void> _loadRegisteredSchools() async {
    final accounts = await TeacherAccountStore.instance.loadAccounts();
    if (!mounted) return;
    setState(() {
      _registeredSchools
        ..clear()
        ..addAll(accounts);
    });
  }

  Future<void> _loadParticipantDirectory() async {
    try {
      final rows = await Supabase.instance.client.from('profiles').select();
      final loaded = rows
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .map(
            (row) => TournamentStudent(
              id: '${row['id'] ?? ''}'.trim(),
              name: '${row['nickname'] ?? row['name'] ?? ''}'.trim(),
              online: false,
              rating: (row['rating'] as num?)?.toInt() ??
                  int.tryParse('${row['rating'] ?? ''}') ??
                  1200,
              country: '${row['country'] ?? ''}'.trim(),
              gamesPlayed: (row['games_played'] as num?)?.toInt() ??
                  int.tryParse('${row['games_played'] ?? ''}') ??
                  0,
            ),
          )
          .where((student) => student.id.isNotEmpty && student.name.isNotEmpty)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _directoryStudents
          ..clear()
          ..addAll(loaded);
      });
    } catch (_) {
      // The teacher's own school list remains available when the public
      // profile directory is restricted by database permissions.
    }
  }

  Future<void> _loadOwnerStudent() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    var name =
        '${metadata['nickname'] ?? metadata['name'] ?? user.email ?? 'Организатор'}';
    var rating = 1200;
    var country = '';
    var gamesPlayed = 0;
    try {
      final profile = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      final profileName = '${profile?['nickname'] ?? ''}'.trim();
      if (profileName.isNotEmpty) name = profileName;
      rating = (profile?['rating'] as num?)?.toInt() ??
          int.tryParse('${profile?['rating'] ?? ''}') ??
          1200;
      country = '${profile?['country'] ?? ''}'.trim();
      gamesPlayed = (profile?['games_played'] as num?)?.toInt() ??
          int.tryParse('${profile?['games_played'] ?? ''}') ??
          0;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _ownerStudent = TournamentStudent(
        id: user.id,
        name: name,
        online: true,
        isOwner: true,
        rating: rating,
        country: country,
        gamesPlayed: gamesPlayed,
      );
    });
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _maxCtl.dispose();
    _minutesCtl.dispose();
    _incrementCtl.dispose();
    _roundsCtl.dispose();
    _participantSearchCtl.dispose();
    _tournamentSearchCtl.dispose();
    _schoolSearchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      final sentRaw = prefs.getStringList(_sentInvitationsStorageKey);
      _sentInvitationKeys
        ..clear()
        ..addAll(sentRaw ?? const <String>[]);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _tournaments
            ..clear()
            ..addAll(
              decoded.whereType<Map>().map(
                    (e) => _TournamentData.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  ),
            );
        }
      }
      final userId =
          (Supabase.instance.client.auth.currentUser?.id ?? '').trim();
      if (userId.isNotEmpty) {
        final migrationKey = 'makechess_tournaments_db_migrated_$userId';
        final remote =
            await TournamentStorageService.instance.loadTournaments();
        if (prefs.getBool(migrationKey) != true) {
          final merged = <String, _TournamentData>{
            for (final tournament in remote)
              '${tournament['id'] ?? ''}': _TournamentData.fromJson(tournament),
            for (final tournament in _tournaments) tournament.id: tournament,
          }.values.toList();
          _tournaments
            ..clear()
            ..addAll(merged);
          if (_tournaments.isNotEmpty) {
            await TournamentStorageService.instance.saveTournaments(
              _tournaments.map((e) => e.toJson()),
            );
          }
          await prefs.setBool(migrationKey, true);
        } else {
          _tournaments
            ..clear()
            ..addAll(remote.map(_TournamentData.fromJson));
        }

        final visibleRemote =
            await TournamentStorageService.instance.loadVisibleTournaments();
        _visibleInvitationTournaments
          ..clear()
          ..addAll(
            visibleRemote.map(
              (raw) => _VisibleInvitationTournament(
                tournament: _TournamentData.fromJson(raw),
                ownerId: '${raw['_ownerId'] ?? ''}'.trim(),
              ),
            ),
          );
      }
      var systemTemplateRenamed = false;
      for (var i = 0; i < _tournaments.length; i++) {
        final tournament = _tournaments[i];
        if (tournament.id == _systemRoundRobinTemplateId &&
            tournament.name != _systemRoundRobinTemplateName) {
          _tournaments[i] = tournament.copyWith(
            name: _systemRoundRobinTemplateName,
          );
          systemTemplateRenamed = true;
        }
      }
      var tournamentNamesRestored = false;
      if (userId.isNotEmpty) {
        for (var i = 0; i < _tournaments.length; i++) {
          final tournament = _tournaments[i];
          if (tournament.isTemplate) continue;
          final table = await TournamentStorageService.instance
              .loadTournamentTable(tournament.id);
          final tableName = '${table?['name'] ?? ''}'.trim();
          if (tableName.isNotEmpty && tableName != tournament.name) {
            _tournaments[i] = tournament.copyWith(name: tableName);
            tournamentNamesRestored = true;
          }
        }
      }
      if (_tournaments.isEmpty) {
        final template = _TournamentData(
          id: _systemRoundRobinTemplateId,
          name: _systemRoundRobinTemplateName,
          type: _TournamentType.open,
          format: _TournamentFormat.roundRobin,
          maxParticipants: 8,
          minutes: 10,
          increment: 5,
          rounds: 7,
          rated: false,
          videoEnabled: true,
          saveGames: true,
          status: _TournamentStatus.draft,
          createdAt: DateTime.now(),
          isTemplate: true,
          participantIds: const <String>[
            'autumn_player_1',
            'autumn_player_2',
            'autumn_player_3',
            'autumn_player_4',
            'autumn_player_5',
            'autumn_player_6',
            'autumn_player_7',
            'autumn_player_8',
          ],
          participantNames: const <String, String>{
            'autumn_player_1': 'Участник 1',
            'autumn_player_2': 'Участник 2',
            'autumn_player_3': 'Участник 3',
            'autumn_player_4': 'Участник 4',
            'autumn_player_5': 'Участник 5',
            'autumn_player_6': 'Участник 6',
            'autumn_player_7': 'Участник 7',
            'autumn_player_8': 'Участник 8',
          },
        );
        _tournaments.add(template);
        await _save();
      } else if (systemTemplateRenamed || tournamentNamesRestored) {
        await _save();
      }

      final working = _tournaments.where(
        (e) => e.status != _TournamentStatus.finished && !e.isTemplate,
      );
      if (working.isNotEmpty) {
        final first = working.first;
        _activeTournamentId = first.id;
        _fillForm(first);
      } else {
        _activeTournamentId = null;
      }
    } catch (_) {
      // Повреждённое локальное сохранение не должно блокировать окно.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _tournaments.map((e) => e.toJson()).toList();
    await prefs.setString(
      _storageKey,
      jsonEncode(data),
    );
    await TournamentStorageService.instance.saveTournaments(data);
    final userId = (Supabase.instance.client.auth.currentUser?.id ?? '').trim();
    if (userId.isNotEmpty) {
      _visibleInvitationTournaments
        ..removeWhere((entry) => entry.ownerId == userId)
        ..addAll(
          _tournaments.map(
            (tournament) => _VisibleInvitationTournament(
              tournament: tournament,
              ownerId: userId,
            ),
          ),
        );
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: MakeChessLocalizedText(text)),
    );
  }

  int _positiveInt(TextEditingController ctl, int fallback) {
    final parsed = int.tryParse(ctl.text.trim());
    return parsed == null || parsed < 0 ? fallback : parsed;
  }

  void _setActive(_TournamentData tournament) {
    setState(() {
      _activeTournamentId = tournament.id;
      _draftParticipantIds
        ..clear()
        ..addAll(tournament.participantIds);
      _fillForm(tournament);
    });
  }

  void _fillForm(_TournamentData tournament) {
    _nameCtl.text = tournament.name;
    _maxCtl.text = '${tournament.maxParticipants}';
    _minutesCtl.text = '${tournament.minutes}';
    _incrementCtl.text = '${tournament.increment}';
    _roundsCtl.text = '${tournament.rounds}';
    _type = tournament.type;
    _format = tournament.format;
    _rated = tournament.rated;
    _videoEnabled = tournament.videoEnabled;
    _saveGames = tournament.saveGames;
  }

  Future<void> _createTournament() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      _message('Введите название турнира');
      return;
    }

    final maxParticipants = _positiveInt(_maxCtl, 8).clamp(2, 128).toInt();
    final minutes = _positiveInt(_minutesCtl, 5).clamp(1, 180).toInt();
    final increment = _positiveInt(_incrementCtl, 0).clamp(0, 60).toInt();
    final rounds = _positiveInt(_roundsCtl, 3).clamp(1, 50).toInt();
    final participantIds =
        _draftParticipantIds.take(maxParticipants).toList(growable: false);
    final participantNames = <String, String>{
      for (final id in participantIds) id: _studentName(id),
    };
    final tournament = _TournamentData(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      type: _type,
      format: _format,
      maxParticipants: maxParticipants,
      minutes: minutes,
      increment: increment,
      rounds: rounds,
      rated: _rated,
      videoEnabled: _videoEnabled,
      saveGames: _saveGames,
      status: _TournamentStatus.draft,
      createdAt: DateTime.now(),
      isTemplate: true,
      participantIds: participantIds,
      participantNames: participantNames,
    );

    setState(() {
      _tournaments.insert(0, tournament);
      _activeTournamentId = null;
      _openTab = _OpenTournamentTab.newTournament;
      _section = _TournamentSection.open;
    });
    await _save();
    _message('Шаблон турнира «$name» создан');
  }

  Future<void> _updateActive(_TournamentData updated) async {
    final index = _tournaments.indexWhere((e) => e.id == updated.id);
    if (index < 0) return;
    setState(() => _tournaments[index] = updated);
    await _save();
  }

  Future<void> _saveSettings() async {
    final active = _activeTournament;
    if (active == null) {
      _message('Сначала создайте или откройте турнир');
      return;
    }
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      _message('Название не может быть пустым');
      return;
    }
    final updated = active.copyWith(
      name: name,
      type: _type,
      format: _format,
      maxParticipants:
          _positiveInt(_maxCtl, active.maxParticipants).clamp(2, 128).toInt(),
      minutes: _positiveInt(_minutesCtl, active.minutes).clamp(1, 180).toInt(),
      increment:
          _positiveInt(_incrementCtl, active.increment).clamp(0, 60).toInt(),
      rounds: _positiveInt(_roundsCtl, active.rounds).clamp(1, 50).toInt(),
      rated: _rated,
      videoEnabled: _videoEnabled,
      saveGames: _saveGames,
    );
    await _updateActive(updated);
    _message('Настройки сохранены');
  }

  Future<void> _deleteTournament(_TournamentData tournament) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const MakeChessLocalizedText('Удалить турнир?'),
        content: MakeChessLocalizedText(
            '«${tournament.name}» будет удалён из этого браузера.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const MakeChessLocalizedText('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const MakeChessLocalizedText('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _tournaments.removeWhere((e) => e.id == tournament.id);
      if (_openedArchiveTournamentId == tournament.id) {
        _openedArchiveTournamentId = null;
        _archiveShowGames = false;
      }
      if (_activeTournamentId == tournament.id) {
        final working = _tournaments.where(
          (e) => e.status != _TournamentStatus.finished,
        );
        _activeTournamentId = working.isEmpty ? null : working.first.id;
      }
    });
    await _save();
    await TournamentStorageService.instance.deleteTournament(tournament.id);
  }

  Future<void> _toggleParticipant(String studentId, bool add) async {
    final active = _activeTournament;
    if (active == null) {
      _message('Сначала создайте или откройте турнир');
      return;
    }
    final ids = active.participantIds.toList();
    final names = Map<String, String>.from(active.participantNames);
    if (add) {
      if (ids.contains(studentId)) return;
      if (ids.length >= active.maxParticipants) {
        _message('Достигнут лимит: ${active.maxParticipants} участников');
        return;
      }
      ids.add(studentId);
      names[studentId] = _studentName(studentId);
    } else {
      ids.remove(studentId);
      names.remove(studentId);
    }
    await _updateActive(active.copyWith(
      participantIds: ids,
      participantNames: names,
      status:
          ids.length >= 2 ? _TournamentStatus.ready : _TournamentStatus.draft,
      pairings: const <_TournamentPairing>[],
      currentRound: 0,
    ));
  }

  Future<void> _generatePairings() async {
    final active = _activeTournament;
    if (active == null) {
      _message('Сначала создайте или откройте турнир');
      return;
    }
    if (active.participantIds.length < 2) {
      _message('Для жеребьёвки нужно минимум два участника');
      return;
    }

    final ids = active.participantIds.toList()..shuffle(math.Random());
    final pairings = <_TournamentPairing>[];
    var board = 1;
    for (var i = 0; i < ids.length; i += 2) {
      final white = ids[i];
      final black = i + 1 < ids.length ? ids[i + 1] : null;
      pairings.add(
        _TournamentPairing(
          board: board++,
          whiteId: white,
          blackId: black,
          result: black == null ? '1-0' : '*',
        ),
      );
    }
    await _updateActive(active.copyWith(
      currentRound: math.max(1, active.currentRound),
      pairings: pairings,
      status: _TournamentStatus.ready,
    ));
    _message('Жеребьёвка сформирована');
  }

  Future<void> _setPairingResult(
    _TournamentPairing pairing,
    String result,
  ) async {
    final active = _activeTournament;
    if (active == null) return;
    final updated = active.pairings
        .map((e) => e.board == pairing.board ? e.copyWith(result: result) : e)
        .toList();
    await _updateActive(active.copyWith(pairings: updated));
  }

  Future<void> _setStatus(_TournamentStatus status) async {
    final active = _activeTournament;
    if (active == null) {
      _message('Сначала создайте или откройте турнир');
      return;
    }
    if (status == _TournamentStatus.running &&
        active.participantIds.length < 2) {
      _message('Нельзя запустить турнир без участников');
      return;
    }
    await _updateActive(active.copyWith(status: status));
  }

  _TournamentData _withCurrentRoundSnapshot(_TournamentData tournament) {
    if (tournament.pairings.isEmpty) return tournament;

    final roundNumber = math.max(1, tournament.currentRound);
    final history = tournament.roundHistory
        .where((e) => e.roundNumber != roundNumber)
        .toList();
    history.add(
      _TournamentRoundSnapshot(
        roundNumber: roundNumber,
        pairings: List<_TournamentPairing>.from(tournament.pairings),
        savedAt: DateTime.now(),
      ),
    );
    history.sort((a, b) => a.roundNumber.compareTo(b.roundNumber));
    return tournament.copyWith(roundHistory: history);
  }

  Future<void> _goToNextRound() async {
    final active = _activeTournament;
    if (active == null) {
      _message('Сначала создайте или откройте турнир');
      return;
    }
    final saved = _withCurrentRoundSnapshot(active);
    await _updateActive(
      saved.copyWith(
        currentRound: math.max(1, active.currentRound) + 1,
        pairings: const <_TournamentPairing>[],
        status: _TournamentStatus.ready,
      ),
    );
    if (mounted) setState(() => _section = _TournamentSection.pairing);
  }

  Future<void> _finishActiveTournament() async {
    final active = _activeTournament;
    if (active == null) {
      _message('Сначала создайте или откройте турнир');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const MakeChessLocalizedText('Завершить турнир?'),
        content: MakeChessLocalizedText(
          'Турнир «${active.name}» будет зафиксирован и перенесён в архив. '
          'Результаты останутся доступными только для просмотра.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const MakeChessLocalizedText('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const MakeChessLocalizedText('Завершить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final archived = _withCurrentRoundSnapshot(active).copyWith(
      status: _TournamentStatus.finished,
      finishedAt: DateTime.now(),
    );
    await _updateActive(archived);
    if (!mounted) return;
    setState(() {
      final working = _tournaments.where(
        (e) => e.status != _TournamentStatus.finished,
      );
      _activeTournamentId = working.isEmpty ? null : working.first.id;
      if (working.isNotEmpty) _fillForm(working.first);
      _openedArchiveTournamentId = archived.id;
      _archiveShowGames = false;
      _section = _TournamentSection.archive;
    });
    _message('Турнир «${archived.name}» перенесён в архив');
  }

  Future<void> _copyArchiveAsTemplate(_TournamentData source) async {
    final copy = _TournamentData(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: '${source.name} — копия',
      type: source.type,
      format: source.format,
      maxParticipants: source.maxParticipants,
      minutes: source.minutes,
      increment: source.increment,
      rounds: source.rounds,
      rated: source.rated,
      videoEnabled: source.videoEnabled,
      saveGames: source.saveGames,
      status: _TournamentStatus.draft,
      createdAt: DateTime.now(),
      participantIds: List<String>.from(source.participantIds),
      participantNames: Map<String, String>.from(source.participantNames),
    );
    setState(() {
      _tournaments.insert(0, copy);
      _activeTournamentId = copy.id;
      _openedArchiveTournamentId = null;
      _archiveShowGames = false;
      _fillForm(copy);
      _section = _TournamentSection.settings;
    });
    await _save();
    _message('Создан новый шаблон «${copy.name}»');
  }

  String _studentName(String? id) {
    if (id == null) return 'Свободен';
    for (final student in widget.students) {
      if (student.id == id) return student.name;
    }
    return id;
  }

  String _tournamentStudentName(_TournamentData tournament, String? id) {
    if (id == null) return 'Свободен';
    final saved = tournament.participantNames[id]?.trim();
    if (saved != null && saved.isNotEmpty) return saved;
    return _studentName(id);
  }

  bool _isOnline(String id) {
    for (final student in widget.students) {
      if (student.id == id) return student.online;
    }
    return false;
  }

  List<_TournamentPairing> _allPairings(_TournamentData tournament) {
    final result = <_TournamentPairing>[];
    final history = tournament.roundHistory.toList()
      ..sort((a, b) => a.roundNumber.compareTo(b.roundNumber));
    for (final round in history) {
      result.addAll(round.pairings);
    }

    final currentRound = math.max(1, tournament.currentRound);
    final currentAlreadySaved =
        history.any((round) => round.roundNumber == currentRound);
    if (!currentAlreadySaved) result.addAll(tournament.pairings);
    return result;
  }

  Map<String, double> _standings(_TournamentData tournament) {
    final scores = <String, double>{
      for (final id in tournament.participantIds) id: 0,
    };
    for (final pairing in _allPairings(tournament)) {
      final black = pairing.blackId;
      switch (pairing.result) {
        case '1-0':
          scores[pairing.whiteId] = (scores[pairing.whiteId] ?? 0) + 1;
          break;
        case '0-1':
          if (black != null) scores[black] = (scores[black] ?? 0) + 1;
          break;
        case '½-½':
          scores[pairing.whiteId] = (scores[pairing.whiteId] ?? 0) + 0.5;
          if (black != null) scores[black] = (scores[black] ?? 0) + 0.5;
          break;
      }
    }
    return scores;
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return 'Не записано';
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  Future<void> _showArchivedGameDetails({
    required _TournamentData tournament,
    required int roundNumber,
    required _TournamentPairing pairing,
  }) {
    final reason = pairing.resultReason.trim().isEmpty
        ? (pairing.result == '*'
            ? 'Партия не завершена'
            : 'Результат зафиксирован учителем')
        : pairing.resultReason.trim();
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252C35),
        title: MakeChessLocalizedText(
          'Тур $roundNumber • Стол ${pairing.board}',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _archiveInfoLine(
                  'Партия',
                  '${_tournamentStudentName(tournament, pairing.whiteId)} — '
                      '${_tournamentStudentName(tournament, pairing.blackId)}',
                ),
                _archiveInfoLine('Результат', pairing.result),
                _archiveInfoLine('Причина', reason),
                _archiveInfoLine(
                  'Продолжительность',
                  _formatDuration(pairing.durationSeconds),
                ),
                const SizedBox(height: 14),
                const MakeChessLocalizedText(
                  'Запись ходов',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 74),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.22),
                    borderRadius: AppRadius.r8,
                    border: Border.all(color: Colors.white10),
                  ),
                  child: SelectableText(
                    pairing.pgn.trim().isEmpty
                        ? 'Запись ходов для этой партии пока не получена.'
                        : pairing.pgn,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),
                const MakeChessLocalizedText(
                  'Итоговая позиция',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.22),
                    borderRadius: AppRadius.r8,
                    border: Border.all(color: Colors.white10),
                  ),
                  child: SelectableText(
                    pairing.finalFen.trim().isEmpty
                        ? 'Итоговая позиция пока не записана.'
                        : pairing.finalFen,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const MakeChessLocalizedText('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _archiveInfoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: MakeChessLocalizedText(label,
                style: const TextStyle(color: Colors.white54)),
          ),
          Expanded(
            child: MakeChessLocalizedText(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final width = math.min(1180.0, math.max(760.0, media.width - 40));
    final height = math.min(780.0, math.max(560.0, media.height - 40));

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.transparent,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF171C22),
          borderRadius: AppRadius.r12,
          border: Border.all(color: AppColors.borderBright, width: 1.2),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black54,
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        SizedBox(width: 220, child: _buildNavigation()),
                        const VerticalDivider(width: 1, thickness: 1),
                        Expanded(child: _buildSection()),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final active = _section == _TournamentSection.archive
        ? (_openedArchiveTournament ?? _activeTournament)
        : _activeTournament;
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xFF252C35),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Colors.amberAccent),
          const SizedBox(width: 10),
          const MakeChessLocalizedText(
            'Управление турниром',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 16),
          if (active != null)
            Flexible(
              child: MakeChessLocalizedText(
                active.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          const Spacer(),
          if (active != null) _statusChip(active.status),
          const SizedBox(width: 8),
          IconButton(
            tooltip: MakeChessLocalization.phrase('Закрыть'),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(_TournamentStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withOpacity(0.7)),
      ),
      child: MakeChessLocalizedText(
        status.label,
        style: TextStyle(color: status.color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildNavigation() {
    Widget item(
      _TournamentSection section,
      IconData icon,
      String text,
    ) {
      final active = _section == section;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: InkWell(
          borderRadius: AppRadius.r8,
          onTap: () => setState(() => _section = section),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.accentGlowSoft
                  : Colors.white.withOpacity(0.025),
              borderRadius: AppRadius.r8,
              border: Border.all(
                color: active ? AppColors.borderBright : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 19,
                    color: active ? Colors.cyanAccent : Colors.white60),
                const SizedBox(width: 10),
                Expanded(
                  child: MakeChessLocalizedText(
                    text,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white70,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFF20262E),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          item(_TournamentSection.create, Icons.add_circle_outline,
              'Создать шаблон турнира'),
          item(_TournamentSection.open, Icons.add_box_outlined,
              'Создать турнир'),
          item(_TournamentSection.current, Icons.public, 'Текущие турниры'),
          item(_TournamentSection.participants, Icons.groups, 'Участники'),
          item(_TournamentSection.pairing, Icons.shuffle, 'Жеребьёвка'),
          item(_TournamentSection.games, Icons.view_list, 'Туры и партии'),
          item(_TournamentSection.standings, Icons.leaderboard,
              'Таблица результатов'),
          item(_TournamentSection.settings, Icons.tune, 'Настройка'),
          item(_TournamentSection.control, Icons.play_circle_outline,
              'Управление'),
          item(_TournamentSection.statistics, Icons.bar_chart, 'Статистика'),
          item(_TournamentSection.archive, Icons.inventory_2_outlined, 'Архив'),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => showTournamentGamePlatform(
              context: context,
              tournamentName: _activeTournament?.name ?? 'Турнир',
            ),
            icon: const Icon(Icons.sports_esports),
            label: const MakeChessLocalizedText('Игровая платформа'),
          ),
          const SizedBox(height: 10),
          MakeChessLocalizedText(
            'Турниры сохраняются в базе MakeChess.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.42),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection() {
    switch (_section) {
      case _TournamentSection.create:
        return _buildCreate();
      case _TournamentSection.open:
        return _buildOpen();
      case _TournamentSection.current:
        return TournamentCurrentTournamentsPanel(
          userId: Supabase.instance.client.auth.currentUser?.id ?? '',
          userName: _currentUserDisplayName,
        );
      case _TournamentSection.participants:
        return _buildParticipants();
      case _TournamentSection.pairing:
        return _buildPairing();
      case _TournamentSection.games:
        return _buildGames();
      case _TournamentSection.standings:
        return _buildStandings();
      case _TournamentSection.settings:
        return _buildSettings();
      case _TournamentSection.control:
        return _buildControl();
      case _TournamentSection.statistics:
        return TournamentStatisticsPanel(
          userId: Supabase.instance.client.auth.currentUser?.id ?? '',
          userName: _currentUserDisplayName,
        );
      case _TournamentSection.archive:
        return _buildArchive();
    }
  }

  String get _currentUserDisplayName {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    return '${metadata['nickname'] ?? metadata['name'] ?? user?.email ?? 'Учитель'}';
  }

  Widget _page({
    required String title,
    required String subtitle,
    required Widget child,
    bool localizeTitle = true,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (localizeTitle)
            MakeChessLocalizedText(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            MakeChessLocalizedText(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 4),
          MakeChessLocalizedText(
            subtitle,
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 18),
          Expanded(child: child),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: MakeChessLocalization.phrase(label),
      labelStyle: const TextStyle(color: Colors.white60),
      filled: true,
      fillColor: Colors.black.withOpacity(0.2),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.r8,
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.r8,
        borderSide: const BorderSide(color: Colors.cyanAccent),
      ),
    );
  }

  Widget _buildCreate() {
    return _page(
      title: 'Создать шаблон турнира',
      subtitle:
          'Создайте повторно используемый шаблон правил будущего турнира.',
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _nameCtl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Название турнира'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<_TournamentFormat>(
                    value: _format,
                    dropdownColor: const Color(0xFF252C35),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Система проведения'),
                    items: _TournamentFormat.values
                        .map(
                          (e) => DropdownMenuItem<_TournamentFormat>(
                            value: e,
                            child: MakeChessLocalizedText(e.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _format = value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxCtl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Максимум участников'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minutesCtl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Минут на партию'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _incrementCtl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Добавление, секунд'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _roundsCtl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Количество туров'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<_TournamentType>(
              value: _type,
              dropdownColor: const Color(0xFF252C35),
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Тип турнира'),
              items: _TournamentType.values
                  .map(
                    (type) => DropdownMenuItem<_TournamentType>(
                      value: type,
                      child: MakeChessLocalizedText(type.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: MakeChessLocalizedText(
                _type.description,
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 14),
            _switchTile(
              title: 'Рейтинговый турнир',
              subtitle: 'Результаты можно будет учитывать в рейтинге.',
              value: _rated,
              onChanged: (value) => setState(() => _rated = value),
            ),
            _switchTile(
              title: 'Видеосвязь',
              subtitle: 'Сохранять возможность видеосвязи во время партий.',
              value: _videoEnabled,
              onChanged: (value) => setState(() => _videoEnabled = value),
            ),
            _switchTile(
              title: 'Сохранять партии',
              subtitle: 'Партии будут доступны для последующего анализа.',
              value: _saveGames,
              onChanged: (value) => setState(() => _saveGames = value),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _createTournament,
                icon: const Icon(Icons.add),
                label: const MakeChessLocalizedText('Сохранить шаблон'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.025),
        borderRadius: AppRadius.r8,
        border: Border.all(color: Colors.white10),
      ),
      child: SwitchListTile(
        title: MakeChessLocalizedText(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: MakeChessLocalizedText(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _createCurrentTournamentFromTemplate(
    _TournamentData template,
  ) async {
    final createdId = DateTime.now().microsecondsSinceEpoch.toString();
    const participantIds = <String>[];
    const participantNames = <String, String>{};

    // Родительская запись должна существовать в базе до сохранения связанной
    // визуальной таблицы турнира.
    final draftTournament = _TournamentData(
      id: createdId,
      name: template.name,
      type: template.type,
      format: template.format,
      maxParticipants: template.maxParticipants,
      minutes: template.minutes,
      increment: template.increment,
      rounds: template.rounds,
      rated: template.rated,
      videoEnabled: template.videoEnabled,
      saveGames: template.saveGames,
      status: _TournamentStatus.draft,
      createdAt: DateTime.now(),
      isTemplate: false,
      participantIds: participantIds,
      participantNames: participantNames,
    );
    try {
      await TournamentStorageService.instance
          .saveTournaments(<Map<String, dynamic>>[draftTournament.toJson()]);
    } catch (error) {
      if (mounted) _message('Не удалось создать турнир в базе: $error');
      return;
    }
    if (!mounted) return;

    final result = await showTournamentTableEditor(
      context: context,
      tournamentId: createdId,
      initialName: template.name,
      initialType: template.format.label,
      initialStatus: _TournamentStatus.draft.label,
      initialMinutes: template.minutes,
      initialIncrement: template.increment,
      initialRounds: template.rounds,
      initialParticipantNames: const <String>[],
      maxParticipants: template.maxParticipants,
    );

    if (!mounted) return;
    if (result == null) {
      await TournamentStorageService.instance.deleteTournament(createdId);
      return;
    }

    final savedTable =
        await TournamentStorageService.instance.loadTournamentTable(createdId);
    if (!mounted) return;
    final savedName = '${savedTable?['name'] ?? ''}'.trim();
    final tournament = draftTournament.copyWith(
      name: savedName.isEmpty ? draftTournament.name : savedName,
      status: result == TournamentTableEditorResult.published
          ? _TournamentStatus.ready
          : _TournamentStatus.draft,
    );

    setState(() {
      _tournaments.insert(0, tournament);
      _activeTournamentId = tournament.id;
      _openTab = _OpenTournamentTab.current;
    });
    await _save();
    if (result == TournamentTableEditorResult.published) {
      await _inviteOrganizerToTournament(tournament);
    }
  }

  Widget _openTabButton({
    required _OpenTournamentTab tab,
    required String label,
    required IconData icon,
  }) {
    final selected = _openTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _openTab = tab),
        borderRadius: AppRadius.r8,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accentGlowSoft
                : Colors.white.withOpacity(0.025),
            borderRadius: AppRadius.r8,
            border: Border.all(
              color: selected
                  ? AppColors.borderBright
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.cyanAccent : Colors.white60),
              const SizedBox(width: 8),
              MakeChessLocalizedText(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _templateSynopsisItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: MakeChessLocalizedText(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: MakeChessLocalizedText(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _editorTournamentTypeFor(_TournamentData template) {
    switch (template.format) {
      case _TournamentFormat.roundRobin:
        return 'Круговая система';
      case _TournamentFormat.swiss:
        return 'Швейцарская система';
      case _TournamentFormat.knockout:
        return 'На выбывание';
    }
  }

  List<Map<String, dynamic>> _previewParticipantsFor(_TournamentData template) {
    return <Map<String, dynamic>>[
      {
        'id': 'preview_1',
        'name': 'Иван Петров',
        'rating': 1642,
        'school': 'Школа №12',
        'flag': '🇷🇺',
        'avatarUrl': '',
      },
      {
        'id': 'preview_2',
        'name': 'Anna Müller',
        'rating': 1598,
        'school': 'Berlin Chess School',
        'flag': '🇩🇪',
        'avatarUrl': '',
      },
      {
        'id': 'preview_3',
        'name': 'Arman Sargsyan',
        'rating': 1710,
        'school': 'Yerevan Juniors',
        'flag': '🇦🇲',
        'avatarUrl': '',
      },
      {
        'id': 'preview_4',
        'name': 'Sophie Martin',
        'rating': 1525,
        'school': 'Lyon Échecs',
        'flag': '🇫🇷',
        'avatarUrl': '',
      },
      {
        'id': 'preview_5',
        'name': 'Nikita Orlov',
        'rating': 1675,
        'school': 'ШК Олимп',
        'flag': '🇷🇺',
        'avatarUrl': '',
      },
      {
        'id': 'preview_6',
        'name': 'Mateo Rossi',
        'rating': 1490,
        'school': 'Roma Chess Club',
        'flag': '🇮🇹',
        'avatarUrl': '',
      },
      {
        'id': 'preview_7',
        'name': 'Aruzhan Bek',
        'rating': 1554,
        'school': 'Astana School',
        'flag': '🇰🇿',
        'avatarUrl': '',
      },
      {
        'id': 'preview_8',
        'name': 'John Lee',
        'rating': 1618,
        'school': 'London Academy',
        'flag': '🇬🇧',
        'avatarUrl': '',
      },
    ];
  }

  Map<String, String> _previewResultsMatrix() {
    final matrix = <List<String?>>[
      [null, '1', '½', '1', '½', '1', '1', '0'],
      ['0', null, '0', '½', '1', '½', '0', '1'],
      ['½', '1', null, '1', '½', '0', '½', '1'],
      ['0', '½', '0', null, '1', '½', '1', '0'],
      ['½', '0', '½', '0', null, '1', '½', '1'],
      ['0', '½', '1', '½', '0', null, '0', '½'],
      ['0', '1', '½', '0', '½', '1', null, '1'],
      ['1', '0', '0', '1', '0', '½', '0', null],
    ];
    final result = <String, String>{};
    for (var row = 0; row < matrix.length; row++) {
      for (var column = 0; column < matrix[row].length; column++) {
        final value = matrix[row][column];
        if (value != null) result['$row:$column'] = value;
      }
    }
    return result;
  }

  void _showTemplatePreview(_TournamentData template) {
    final participants = _previewParticipantsFor(template);
    showTournamentTableEditor(
      context: context,
      tournamentId: 'preview_${template.id}',
      initialName: template.name,
      initialType: _editorTournamentTypeFor(template),
      initialStatus: 'Завершён',
      initialMinutes: template.minutes,
      initialIncrement: template.increment,
      initialRounds: template.rounds,
      initialParticipantNames: participants
          .map((e) => '${e['name'] ?? 'Участник'}')
          .toList(growable: false),
      maxParticipants: template.maxParticipants,
      previewMode: true,
      initialJudge: 'Ирина Волкова',
      initialVenue: 'Москва • Шахматный центр MakeChess',
      initialOrganizer: 'MakeChess',
      initialStart: '10.10.2026',
      initialEnd: '12.10.2026',
      initialAge: 'Юноши и девушки до 14 лет',
      initialParticipantsData: participants,
      initialResults: _previewResultsMatrix(),
    );
  }

  Widget _buildTemplateCard(_TournamentData template) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.028),
        borderRadius: AppRadius.r8,
        border: Border.all(color: Colors.amberAccent.withOpacity(0.38)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withOpacity(0.08),
                  borderRadius: AppRadius.r8,
                  border: Border.all(
                    color: Colors.amberAccent.withOpacity(0.35),
                  ),
                ),
                child:
                    const Icon(Icons.emoji_events, color: Colors.amberAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MakeChessLocalizedText(
                      template.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const MakeChessLocalizedText(
                      'Краткое описание шаблона',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: MakeChessLocalization.phrase('Удалить шаблон'),
                onPressed: () => _deleteTournament(template),
                icon: const Icon(Icons.delete_outline, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _templateSynopsisItem('Система', template.format.label),
                    _templateSynopsisItem('Тип', template.type.label),
                    _templateSynopsisItem(
                        'Участники', 'до ${template.maxParticipants}'),
                    _templateSynopsisItem('Туры', '${template.rounds}'),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _templateSynopsisItem('Судья', 'заполняется'),
                    _templateSynopsisItem('Организатор', 'заполняется'),
                    _templateSynopsisItem('Рейтинг',
                        template.rated ? 'учитывается' : 'не учитывается'),
                    _templateSynopsisItem('Контроль',
                        '${template.minutes}+${template.increment}'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showTemplatePreview(template),
                icon: const Icon(Icons.visibility_outlined),
                label: const MakeChessLocalizedText('Посмотреть пример'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _createCurrentTournamentFromTemplate(template),
                icon: const Icon(Icons.add_task),
                label:
                    const MakeChessLocalizedText('Создать турнир по шаблону'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _callTournamentParticipants(
    _TournamentData tournament,
  ) async {
    final controller = TextEditingController(text: '10');
    final minutes = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const MakeChessLocalizedText('Вызвать участников'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: MakeChessLocalization.phrase(
                'Через сколько минут начнётся турнир'),
            suffixText: MakeChessLocalization.phrase('мин.'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const MakeChessLocalizedText('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              int.tryParse(controller.text.trim()),
            ),
            child: const MakeChessLocalizedText('Отправить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (minutes == null || minutes < 1) return;

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final senderId = user?.id ?? '';
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final senderName =
        '${metadata['nickname'] ?? metadata['name'] ?? user?.email ?? 'Организатор'}';
    await TournamentStorageService.instance.updateOwnedTournamentFields(
      tournament.id,
      <String, dynamic>{
        'callMinutes': minutes,
        'scheduledStartAt': DateTime.now()
            .toUtc()
            .add(Duration(minutes: minutes))
            .toIso8601String(),
      },
    );
    final recipientIds = await TournamentStorageService.instance
        .loadOwnedTournamentParticipantIds(
      tournament.id,
      fallback: tournament.participantIds,
    );
    for (final recipientId in recipientIds) {
      await MakeChessMessageRealtimeService.instance.send(
        MakeChessMessage(
          id: 'tournament_call_${DateTime.now().microsecondsSinceEpoch}_$recipientId',
          recipientId: recipientId,
          senderId: senderId,
          senderName: senderName,
          category: 'tournament_call',
          title: 'Скоро начнётся турнир «${tournament.name}»',
          body:
              'Турнир начнётся через $minutes мин. Откройте игровую платформу и приготовьтесь к игре.',
          createdAt: DateTime.now(),
          tournamentId: tournament.id,
        ),
      );
    }
    if (!mounted) return;
    _message('Участники вызваны. Начало через $minutes мин.');
  }

  Future<void> _startTournamentFromTable(
    _TournamentData tournament,
  ) async {
    if (tournament.participantIds.length < 2) {
      _message('Для начала турнира нужны минимум два участника');
      return;
    }
    if (tournament.pairings.isEmpty) {
      _message('Сначала выполните жеребьёвку турнира');
      return;
    }
    _setActive(tournament);
    await _updateActive(tournament.copyWith(
      status: _TournamentStatus.running,
    ));
    await TournamentStorageService.instance.updateOwnedTournamentFields(
      tournament.id,
      <String, dynamic>{
        'status': 'running',
        'startedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
    await TournamentStorageService.instance.startTournamentGames(tournament.id);
    if (!mounted) return;
    _message('Турнир начат. Игровые доски участников активированы.');
  }

  Future<void> _setTournamentStatusFromTable(
    _TournamentData tournament,
    _TournamentStatus status,
  ) async {
    _setActive(tournament);
    final updated = tournament.copyWith(
      status: status,
      finishedAt: status == _TournamentStatus.finished ? DateTime.now() : null,
    );
    await _updateActive(updated);
    await TournamentStorageService.instance.updateOwnedTournamentFields(
      tournament.id,
      <String, dynamic>{
        'status': status.name,
        if (status == _TournamentStatus.finished)
          'finishedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
    await TournamentStorageService.instance.controlTournamentGames(
      tournament.id,
      status.name,
    );
    if (!mounted) return;
    _message(status == _TournamentStatus.paused
        ? 'Турнир приостановлен'
        : 'Турнир завершён');
  }

  Widget _buildOpen() {
    final tournaments = _workingTournaments;
    final templates = _tournamentTemplates;
    final showingCurrent = _openTab == _OpenTournamentTab.current;

    return _page(
      title: 'Создать турнир',
      subtitle: showingCurrent
          ? 'Созданные и уже готовые к работе турниры.'
          : 'Выберите сохранённый шаблон и создайте на его основе новый турнир.',
      child: Column(
        children: [
          Row(
            children: [
              _openTabButton(
                tab: _OpenTournamentTab.current,
                label: 'Текущие турниры',
                icon: Icons.play_circle_outline,
              ),
              const SizedBox(width: 10),
              _openTabButton(
                tab: _OpenTournamentTab.newTournament,
                label: 'Новый турнир',
                icon: Icons.add_box_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: showingCurrent
                ? (tournaments.isEmpty
                    ? _empty('Пока нет заполненных текущих турниров')
                    : ListView.separated(
                        itemCount: tournaments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 9),
                        itemBuilder: (_, index) {
                          final tournament = tournaments[index];
                          final active = tournament.id == _activeTournamentId;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.accentGlowSoft
                                  : Colors.white.withOpacity(0.025),
                              borderRadius: AppRadius.r8,
                              border: Border.all(
                                color: active
                                    ? AppColors.borderBright
                                    : Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.emoji_events,
                                    color: Colors.amberAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      MakeChessLocalizedText(
                                        tournament.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      MakeChessLocalizedText(
                                        '${tournament.type.label} • ${tournament.format.label} • '
                                        '${tournament.participantIds.length}/${tournament.maxParticipants} участников • '
                                        '${tournament.minutes}+${tournament.increment} • '
                                        'создан ${_formatDateTime(tournament.createdAt)}',
                                        style: const TextStyle(
                                            color: Colors.white54),
                                      ),
                                    ],
                                  ),
                                ),
                                _statusChip(tournament.status),
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  onPressed: () async {
                                    _setActive(tournament);
                                    final result =
                                        await showTournamentTableEditor(
                                      context: context,
                                      tournamentId: tournament.id,
                                      initialName: tournament.name,
                                      initialType: tournament.format.label,
                                      initialStatus: tournament.status.label,
                                      initialMinutes: tournament.minutes,
                                      initialIncrement: tournament.increment,
                                      initialRounds: tournament.rounds,
                                      initialParticipantNames: tournament
                                          .participantIds
                                          .map((id) => _tournamentStudentName(
                                              tournament, id))
                                          .toList(growable: false),
                                      maxParticipants:
                                          tournament.maxParticipants,
                                      startInPreview: true,
                                      organizerMode: true,
                                      onCallTournament: () =>
                                          _callTournamentParticipants(
                                              tournament),
                                      onStartTournament: () =>
                                          _startTournamentFromTable(tournament),
                                      onPauseTournament: () =>
                                          _setTournamentStatusFromTable(
                                        tournament,
                                        _TournamentStatus.paused,
                                      ),
                                      onFinishTournament: () =>
                                          _setTournamentStatusFromTable(
                                        tournament,
                                        _TournamentStatus.finished,
                                      ),
                                    );
                                    if (result != null) {
                                      final savedTable =
                                          await TournamentStorageService
                                              .instance
                                              .loadTournamentTable(
                                                  tournament.id);
                                      if (!mounted) return;
                                      final savedName =
                                          '${savedTable?['name'] ?? ''}'.trim();
                                      final updated = tournament.copyWith(
                                        name: savedName.isEmpty
                                            ? tournament.name
                                            : savedName,
                                        status: result ==
                                                TournamentTableEditorResult
                                                    .published
                                            ? _TournamentStatus.ready
                                            : tournament.status,
                                      );
                                      await _updateActive(updated);
                                      if (result ==
                                          TournamentTableEditorResult
                                              .published) {
                                        await _inviteOrganizerToTournament(
                                            updated);
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.visibility_outlined),
                                  label: const MakeChessLocalizedText(
                                      'Открыть турнир'),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton(
                                  onPressed: () {
                                    _setActive(tournament);
                                    setState(() =>
                                        _section = _TournamentSection.control);
                                  },
                                  child: const MakeChessLocalizedText(
                                      'Управление'),
                                ),
                                IconButton(
                                  tooltip:
                                      MakeChessLocalization.phrase('Удалить'),
                                  onPressed: () =>
                                      _deleteTournament(tournament),
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.white54),
                                ),
                              ],
                            ),
                          );
                        },
                      ))
                : (templates.isEmpty
                    ? _empty(
                        'Нет шаблонов. Создайте первый в разделе «Создать шаблон турнира»')
                    : ListView.separated(
                        itemCount: templates.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) =>
                            _buildTemplateCard(templates[index]),
                      )),
          ),
        ],
      ),
    );
  }

  Future<void> _inviteStudentToTournament(
    TournamentStudent student,
  ) async {
    final tournament = _invitationTournament;
    if (tournament == null) {
      _message('Сначала выберите турнир справа');
      return;
    }
    final key = _invitationKey(tournament.id, student.id);
    if (_sentInvitationKeys.contains(key)) return;

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final senderName =
        '${metadata['nickname'] ?? metadata['name'] ?? user?.email ?? 'Организатор'}';
    final message = MakeChessMessage(
      id: 'tournament_invite_${DateTime.now().microsecondsSinceEpoch}',
      recipientId: student.id,
      senderId: user?.id ?? 'local_organizer',
      senderName: senderName,
      category: 'tournament_invite',
      title: 'Приглашение на турнир «${tournament.name}»',
      body: '${tournament.type.label} • ${tournament.format.label} • '
          '${tournament.minutes}+${tournament.increment} • '
          '${tournament.rounds} туров. Откройте сообщение и подтвердите участие.',
      createdAt: DateTime.now(),
      tournamentId: tournament.id,
    );

    try {
      await MakeChessMessageRealtimeService.instance.start(client);
      await MakeChessMessageRealtimeService.instance.send(message);
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _sentInvitationKeys.add(key));
      await prefs.setStringList(
        _sentInvitationsStorageKey,
        _sentInvitationKeys.toList(growable: false),
      );
      _message('Приглашение отправлено ученику ${student.name}');
    } catch (error) {
      if (!mounted) return;
      _message('Не удалось отправить приглашение: $error');
    }
  }

  Future<void> _inviteOrganizerToTournament(
    _TournamentData tournament,
  ) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final organizerId = (user?.id ?? '').trim();
    if (organizerId.isEmpty ||
        tournament.participantIds.contains(organizerId)) {
      return;
    }
    if (tournament.participantIds.length >= tournament.maxParticipants) {
      _message('В турнире нет свободного места для организатора');
      return;
    }
    final key = _invitationKey(tournament.id, organizerId);
    if (_sentInvitationKeys.contains(key)) return;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final organizerName =
        '${metadata['nickname'] ?? metadata['name'] ?? user?.email ?? 'Организатор'}';
    final message = MakeChessMessage(
      id: 'tournament_invite_${DateTime.now().microsecondsSinceEpoch}',
      recipientId: organizerId,
      senderId: organizerId,
      senderName: organizerName,
      category: 'tournament_invite',
      title: 'Приглашение на турнир «${tournament.name}»',
      body: '${tournament.type.label} • ${tournament.format.label} • '
          '${tournament.minutes}+${tournament.increment} • '
          '${tournament.rounds} туров. Вы создали этот турнир и можете '
          'участвовать в нём как игрок. Откройте сообщение и подтвердите участие.',
      createdAt: DateTime.now(),
      tournamentId: tournament.id,
    );
    try {
      await MakeChessMessageRealtimeService.instance.start(client);
      await MakeChessMessageRealtimeService.instance.send(message);
      final prefs = await SharedPreferences.getInstance();
      _sentInvitationKeys.add(key);
      await prefs.setStringList(
        _sentInvitationsStorageKey,
        _sentInvitationKeys.toList(growable: false),
      );
      if (mounted) {
        setState(() {});
        _message('Приглашение участвовать отправлено организатору');
      }
    } catch (error) {
      if (mounted) {
        _message('Не удалось отправить приглашение организатору: $error');
      }
    }
  }

  void _selectInvitationTournament(_TournamentData tournament) {
    setState(() => _invitationTournamentId = tournament.id);
  }

  TournamentStudent _enrichedStudent(TournamentStudent source) {
    for (final profile in _directoryStudents) {
      if (profile.id != source.id) continue;
      return TournamentStudent(
        id: source.id,
        name: source.name.trim().isEmpty ? profile.name : source.name,
        online: source.online,
        isOwner: source.isOwner,
        rating: profile.rating,
        country: profile.country,
        gamesPlayed: profile.gamesPlayed,
      );
    }
    return source;
  }

  int _recentTournamentCount(String studentId) => _tournaments
      .where((tournament) => tournament.participantIds.contains(studentId))
      .length;

  List<TournamentStudent> _filteredParticipantDirectory({
    required Set<String> selectedParticipantIds,
  }) {
    final owner = _ownerStudent;
    final schoolIds = widget.students.map((student) => student.id).toSet();
    final byId = <String, TournamentStudent>{};

    void add(TournamentStudent student) {
      if (student.id.isEmpty) return;
      byId[student.id] = _enrichedStudent(student);
    }

    if (owner != null) add(owner);
    switch (_participantDirectoryTab) {
      case _ParticipantDirectoryTab.mySchool:
        for (final student in widget.students) {
          add(student);
        }
      case _ParticipantDirectoryTab.otherSchool:
        for (final student in _directoryStudents) {
          if (!schoolIds.contains(student.id) && student.id != owner?.id) {
            add(student);
          }
        }
      case _ParticipantDirectoryTab.all:
        for (final student in widget.students) {
          add(student);
        }
        for (final student in _directoryStudents) {
          add(student);
        }
    }

    final query = _participantSearchCtl.text.trim().toLowerCase();
    final result = byId.values
        .where(
          (student) =>
              student.isOwner || !selectedParticipantIds.contains(student.id),
        )
        .where(
          (student) =>
              query.isEmpty ||
              student.name.toLowerCase().contains(query) ||
              student.country.toLowerCase().contains(query),
        )
        .toList(growable: true);

    result.sort((a, b) {
      if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
      switch (_participantSort) {
        case _ParticipantSort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _ParticipantSort.rating:
          final rating = b.rating.compareTo(a.rating);
          return rating != 0 ? rating : a.name.compareTo(b.name);
        case _ParticipantSort.recentTournaments:
          final activity = _recentTournamentCount(b.id)
              .compareTo(_recentTournamentCount(a.id));
          if (activity != 0) return activity;
          final games = b.gamesPlayed.compareTo(a.gamesPlayed);
          return games != 0 ? games : a.name.compareTo(b.name);
      }
    });
    return result;
  }

  Widget _directoryTabButton({
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        foregroundColor: selected ? Colors.cyanAccent : Colors.white70,
        backgroundColor:
            selected ? Colors.cyanAccent.withOpacity(0.11) : Colors.transparent,
        side: BorderSide(
          color: selected ? Colors.cyanAccent : Colors.white24,
        ),
      ),
      child: MakeChessLocalizedText(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildParticipantDirectoryControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      color: Colors.white.withOpacity(0.018),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _directoryTabButton(
                  label: 'Моя школа',
                  selected: _participantDirectoryTab ==
                      _ParticipantDirectoryTab.mySchool,
                  onPressed: () => setState(() {
                    _participantDirectoryTab =
                        _ParticipantDirectoryTab.mySchool;
                  }),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _directoryTabButton(
                  label: 'Другая школа',
                  selected: _participantDirectoryTab ==
                      _ParticipantDirectoryTab.otherSchool,
                  onPressed: () => setState(() {
                    _participantDirectoryTab =
                        _ParticipantDirectoryTab.otherSchool;
                  }),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _directoryTabButton(
                  label: 'Все участники',
                  selected:
                      _participantDirectoryTab == _ParticipantDirectoryTab.all,
                  onPressed: () => setState(() {
                    _participantDirectoryTab = _ParticipantDirectoryTab.all;
                  }),
                ),
              ),
            ],
          ),
          if (_participantDirectoryTab !=
              _ParticipantDirectoryTab.otherSchool) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _participantSearchCtl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search, size: 19),
                      hintText: MakeChessLocalization.phrase('Поиск участника'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 154,
                  child: DropdownButtonFormField<_ParticipantSort>(
                    value: _participantSort,
                    isDense: true,
                    decoration: InputDecoration(isDense: true),
                    items: const [
                      DropdownMenuItem(
                        value: _ParticipantSort.name,
                        child: MakeChessLocalizedText('По имени'),
                      ),
                      DropdownMenuItem(
                        value: _ParticipantSort.rating,
                        child: MakeChessLocalizedText('По рейтингу'),
                      ),
                      DropdownMenuItem(
                        value: _ParticipantSort.recentTournaments,
                        child: MakeChessLocalizedText('По турнирам'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _participantSort = value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Kept temporarily for compatibility with the earlier compact picker state.
  // ignore: unused_element
  Widget _buildSchoolPicker() {
    final query = _schoolSearchCtl.text.trim().toLowerCase();
    final schools = _registeredSchools
        .where(
          (school) =>
              query.isEmpty ||
              school.schoolName.toLowerCase().contains(query) ||
              school.login.toLowerCase().contains(query),
        )
        .toList(growable: false);
    TeacherAccount? selected;
    for (final school in _registeredSchools) {
      if (school.id == _selectedSchoolId) selected = school;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF17222E),
        borderRadius: AppRadius.r8,
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _schoolPickerExpanded = !_schoolPickerExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  const Icon(Icons.school_outlined,
                      size: 18, color: Colors.cyanAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MakeChessLocalizedText(
                      selected?.schoolName ?? 'Выберите школу или учителя',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(_schoolPickerExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down),
                ],
              ),
            ),
          ),
          if (_schoolPickerExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _schoolSearchCtl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText:
                      MakeChessLocalization.phrase('Поиск школы или учителя'),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: schools.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: MakeChessLocalizedText(
                        'Зарегистрированных школ пока нет',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: schools.length,
                      itemBuilder: (_, index) {
                        final school = schools[index];
                        final active = school.id == _selectedSchoolId;
                        return ListTile(
                          dense: true,
                          selected: active,
                          leading: Icon(
                            active ? Icons.check_circle : Icons.school,
                            color: active ? Colors.cyanAccent : Colors.white54,
                          ),
                          title: MakeChessLocalizedText(school.schoolName),
                          subtitle: school.about.trim().isEmpty
                              ? MakeChessLocalizedText(
                                  'Учитель: ${school.login}')
                              : MakeChessLocalizedText(
                                  school.about,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onTap: () => setState(() {
                            _selectedSchoolId = school.id;
                            _schoolPickerExpanded = false;
                          }),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleSchoolCard(TeacherAccount school) async {
    if (_expandedSchoolIds.contains(school.id)) {
      setState(() => _expandedSchoolIds.remove(school.id));
      return;
    }
    setState(() => _expandedSchoolIds.add(school.id));
    if (_schoolMembers.containsKey(school.id) ||
        _loadingSchoolIds.contains(school.id)) {
      return;
    }
    final teacherId = school.ownerUserId.trim();
    if (teacherId.isEmpty) {
      setState(() => _schoolMembers[school.id] = <TournamentStudent>[]);
      return;
    }
    setState(() => _loadingSchoolIds.add(school.id));
    try {
      final rows = await Supabase.instance.client
          .from('teacher_students')
          .select('student_id, student_nickname, created_at')
          .eq('teacher_id', teacherId)
          .order('created_at', ascending: true);
      final members = rows
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .map(
            (row) => _enrichedStudent(
              TournamentStudent(
                id: '${row['student_id'] ?? ''}'.trim(),
                name: '${row['student_nickname'] ?? ''}'.trim(),
                online: false,
              ),
            ),
          )
          .where((student) => student.id.isNotEmpty && student.name.isNotEmpty)
          .toList(growable: false);
      if (!mounted) return;
      setState(() => _schoolMembers[school.id] = members);
    } catch (error) {
      if (mounted) _message('Не удалось загрузить состав школы: $error');
    } finally {
      if (mounted) setState(() => _loadingSchoolIds.remove(school.id));
    }
  }

  Future<void> _inviteSchool(TeacherAccount school) async {
    final tournament = _invitationTournament;
    if (tournament == null) {
      _message('Сначала выберите турнир справа');
      return;
    }
    final recipientId = school.ownerUserId.trim();
    if (recipientId.isEmpty) {
      _message('У этой школы пока нет связанного аккаунта учителя');
      return;
    }
    final key = _invitationKey(tournament.id, 'school:${school.id}');
    if (_sentInvitationKeys.contains(key)) return;
    final user = Supabase.instance.client.auth.currentUser;
    final senderName = _currentUserDisplayName;
    final freePlaces = math.max(
        0, tournament.maxParticipants - tournament.participantIds.length);
    final message = MakeChessMessage(
      id: 'tournament_school_invite_${DateTime.now().microsecondsSinceEpoch}',
      recipientId: recipientId,
      senderId: user?.id ?? 'local_organizer',
      senderName: senderName,
      category: 'tournament_school_invite',
      title: 'Приглашение школы на турнир «${tournament.name}»',
      body: 'Школа «${school.schoolName}» приглашена на турнир. '
          'Свободных мест: $freePlaces. Выберите учеников, которые будут '
          'представлять школу, и подтвердите их участие.',
      createdAt: DateTime.now(),
      tournamentId: tournament.id,
    );
    try {
      await MakeChessMessageRealtimeService.instance
          .start(Supabase.instance.client);
      await MakeChessMessageRealtimeService.instance.send(message);
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _sentInvitationKeys.add(key));
      await prefs.setStringList(
        _sentInvitationsStorageKey,
        _sentInvitationKeys.toList(growable: false),
      );
      _message('Приглашение отправлено учителю школы «${school.schoolName}»');
    } catch (error) {
      if (mounted) _message('Не удалось пригласить школу: $error');
    }
  }

  Widget _buildOtherSchoolsDirectory({
    required _TournamentData? tournament,
    required Set<String> selectedParticipantIds,
  }) {
    final query = _schoolSearchCtl.text.trim().toLowerCase();
    final schools = _registeredSchools
        .where(
          (school) =>
              query.isEmpty ||
              school.schoolName.toLowerCase().contains(query) ||
              school.login.toLowerCase().contains(query) ||
              school.about.toLowerCase().contains(query),
        )
        .toList(growable: false);
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.14),
        borderRadius: AppRadius.r8,
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          _buildParticipantDirectoryControls(),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: TextField(
              controller: _schoolSearchCtl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                hintText:
                    MakeChessLocalization.phrase('Поиск школы или учителя'),
              ),
            ),
          ),
          Expanded(
            child: schools.isEmpty
                ? _empty('Зарегистрированных школ пока нет')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    itemCount: schools.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) => _buildSchoolCard(
                      school: schools[index],
                      tournament: tournament,
                      selectedParticipantIds: selectedParticipantIds,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolCard({
    required TeacherAccount school,
    required _TournamentData? tournament,
    required Set<String> selectedParticipantIds,
  }) {
    final expanded = _expandedSchoolIds.contains(school.id);
    final loading = _loadingSchoolIds.contains(school.id);
    final members = _schoolMembers[school.id] ?? const <TournamentStudent>[];
    final schoolInviteKey = tournament == null
        ? ''
        : _invitationKey(tournament.id, 'school:${school.id}');
    final invited = _sentInvitationKeys.contains(schoolInviteKey);
    final memberQuery = _participantSearchCtl.text.trim().toLowerCase();
    final visibleMembers = members
        .where((member) =>
            memberQuery.isEmpty ||
            member.name.toLowerCase().contains(memberQuery) ||
            member.country.toLowerCase().contains(memberQuery))
        .toList(growable: false);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: const Color(0xFF111C27),
        borderRadius: AppRadius.r8,
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.school_outlined,
                    color: Colors.cyanAccent, size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MakeChessLocalizedText(school.schoolName,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      MakeChessLocalizedText(
                        '${members.length} учеников${school.about.isEmpty ? '' : ' • ${school.about}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: invited
                      ? 'Приглашение школе отправлено'
                      : 'Пригласить всю школу',
                  onPressed: tournament == null || invited
                      ? null
                      : () => _inviteSchool(school),
                  icon: Icon(
                    invited
                        ? Icons.mark_email_read_outlined
                        : Icons.mail_outline,
                    color: invited ? Colors.greenAccent : Colors.amberAccent,
                  ),
                ),
                IconButton(
                  tooltip: expanded
                      ? MakeChessLocalization.phrase('Скрыть состав')
                      : MakeChessLocalization.phrase('Показать состав'),
                  onPressed: () => _toggleSchoolCard(school),
                  icon: Icon(expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _participantSearchCtl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 18),
                    hintText: MakeChessLocalization.phrase(
                        'Поиск ученика или сотрудника'),
                  ),
                ),
              ),
              for (final member in visibleMembers)
                _buildSchoolMemberRow(
                  member: member,
                  role: 'Ученик',
                  tournament: tournament,
                  participating: selectedParticipantIds.contains(member.id),
                ),
              _buildSchoolRepresentativeRow(school, tournament),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSchoolMemberRow({
    required TournamentStudent member,
    required String role,
    required _TournamentData? tournament,
    required bool participating,
  }) {
    final sent = tournament != null &&
        _sentInvitationKeys.contains(_invitationKey(tournament.id, member.id));
    return ListTile(
      dense: true,
      leading: Icon(Icons.circle,
          size: 9, color: member.online ? Colors.greenAccent : Colors.white24),
      title: MakeChessLocalizedText(member.name),
      subtitle: MakeChessLocalizedText([
        role,
        'Рейтинг: ${member.rating}',
        if (member.country.isNotEmpty) member.country,
      ].join(' • ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: MakeChessLocalization.phrase(
              participating
                  ? 'Уже участвует'
                  : sent
                      ? 'Приглашение отправлено'
                      : 'Пригласить лично',
            ),
            onPressed:
                tournament == null || member.id.isEmpty || participating || sent
                    ? null
                    : () => _inviteStudentToTournament(member),
            icon: Icon(
              participating
                  ? Icons.verified_outlined
                  : sent
                      ? Icons.mark_email_read_outlined
                      : Icons.mail_outline,
              color: participating || sent
                  ? Colors.greenAccent
                  : Colors.amberAccent,
            ),
          ),
          IconButton(
            tooltip: MakeChessLocalization.phrase('Добавить вручную'),
            onPressed: tournament == null || member.id.isEmpty || participating
                ? null
                : () {
                    _activeTournamentId = tournament.id;
                    _toggleParticipant(member.id, true);
                  },
            icon:
                const Icon(Icons.add_circle_outline, color: Colors.cyanAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolRepresentativeRow(
      TeacherAccount school, _TournamentData? tournament) {
    final representative = TournamentStudent(
      id: school.ownerUserId,
      name: school.login,
      online: false,
    );
    return _buildSchoolMemberRow(
      member: representative,
      role: 'Учитель / представитель школы',
      tournament: tournament,
      participating:
          tournament?.participantIds.contains(representative.id) ?? false,
    );
  }

  Widget _buildInvitationTournamentList() {
    final selected = _invitationTournament;
    final query = _tournamentSearchCtl.text.trim().toLowerCase();
    final currentUserId =
        (Supabase.instance.client.auth.currentUser?.id ?? '').trim();
    final source = _visibleInvitationTournaments.isNotEmpty
        ? _visibleInvitationTournaments
        : _workingTournaments
            .map(
              (tournament) => _VisibleInvitationTournament(
                tournament: tournament,
                ownerId: currentUserId,
              ),
            )
            .toList(growable: false);
    final visible = source.where((entry) {
      final tournament = entry.tournament;
      if (tournament.status == _TournamentStatus.finished ||
          tournament.isTemplate) {
        return false;
      }
      if (_invitationTournamentTab == _InvitationTournamentTab.mine &&
          entry.ownerId != currentUserId) {
        return false;
      }
      return query.isEmpty || tournament.name.toLowerCase().contains(query);
    }).toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.14),
        borderRadius: AppRadius.r8,
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            decoration: const BoxDecoration(
              color: Color(0xFF252C35),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _directoryTabButton(
                        label: 'Текущие турниры',
                        selected: _invitationTournamentTab ==
                            _InvitationTournamentTab.current,
                        onPressed: () => setState(() {
                          _invitationTournamentTab =
                              _InvitationTournamentTab.current;
                        }),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _directoryTabButton(
                        label: 'Мои турниры',
                        selected: _invitationTournamentTab ==
                            _InvitationTournamentTab.mine,
                        onPressed: () => setState(() {
                          _invitationTournamentTab =
                              _InvitationTournamentTab.mine;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tournamentSearchCtl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 19),
                    hintText: MakeChessLocalization.phrase('Поиск турнира'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? _empty('Нет активных турниров')
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final entry = visible[index];
                      final tournament = entry.tournament;
                      final mine = entry.ownerId == currentUserId;
                      final active =
                          mine && tournament.id == _invitationTournamentId;
                      return InkWell(
                        onTap: () {
                          if (!mine) {
                            _message(
                              'Приглашать участников можно только в свой турнир',
                            );
                            return;
                          }
                          _TournamentData? owned;
                          for (final candidate in _workingTournaments) {
                            if (candidate.id == tournament.id) {
                              owned = candidate;
                              break;
                            }
                          }
                          if (owned != null) {
                            _selectInvitationTournament(owned);
                          }
                        },
                        borderRadius: BorderRadius.circular(9),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.cyanAccent.withOpacity(0.12)
                                : Colors.white.withOpacity(0.035),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color:
                                  active ? Colors.cyanAccent : Colors.white12,
                              width: active ? 1.4 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                active
                                    ? Icons.check_circle
                                    : mine
                                        ? Icons.emoji_events_outlined
                                        : Icons.public,
                                color: active
                                    ? Colors.cyanAccent
                                    : Colors.amberAccent,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    MakeChessLocalizedText(
                                      tournament.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    MakeChessLocalizedText(
                                      '${tournament.type.label} • '
                                      '${tournament.format.label} • '
                                      '${tournament.participantIds.length}/'
                                      '${tournament.maxParticipants} участников'
                                      '${mine ? ' • Мой турнир' : ''}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (selected == null && visible.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: MakeChessLocalizedText(
                'Сначала выберите турнир, затем приглашайте учеников.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParticipants() {
    final tournament = _invitationTournament;
    final selectedParticipantIds =
        tournament?.participantIds.toSet() ?? const <String>{};
    final available = _filteredParticipantDirectory(
      selectedParticipantIds: selectedParticipantIds,
    );

    return _page(
      title: 'Участники',
      subtitle: tournament == null
          ? 'Выберите справа активный турнир, затем отправляйте приглашения.'
          : 'Выбран турнир «${tournament.name}». '
              '${tournament.participantIds.length}/${tournament.maxParticipants} участников.',
      child: Row(
        children: [
          Expanded(
            child:
                _participantDirectoryTab == _ParticipantDirectoryTab.otherSchool
                    ? _buildOtherSchoolsDirectory(
                        tournament: tournament,
                        selectedParticipantIds: selectedParticipantIds,
                      )
                    : _studentList(
                        title: tournament == null
                            ? 'Ученики школы — выберите турнир'
                            : 'Ученики школы — ${tournament.name}',
                        students: available,
                        controls: _buildParticipantDirectoryControls(),
                        actionIcon: Icons.add_circle_outline,
                        actionTooltip: 'Добавить вручную',
                        onAction: tournament == null
                            ? (_) => _message('Сначала выберите турнир справа')
                            : (student) {
                                _activeTournamentId = tournament.id;
                                _toggleParticipant(student.id, true);
                              },
                        primaryActionEnabled: (student) => !student.isOwner,
                        secondaryActionIcon: Icons.mail_outline,
                        secondaryActionTooltip: 'Пригласить на турнир',
                        onSecondaryAction: _inviteStudentToTournament,
                        secondaryActionState: (student) {
                          if (tournament == null) {
                            return _StudentSecondaryActionState.disabled;
                          }
                          if (selectedParticipantIds.contains(student.id)) {
                            return _StudentSecondaryActionState.participating;
                          }
                          final sent = _sentInvitationKeys.contains(
                            _invitationKey(tournament.id, student.id),
                          );
                          return sent
                              ? _StudentSecondaryActionState.sent
                              : _StudentSecondaryActionState.enabled;
                        },
                      ),
          ),
          const SizedBox(width: 14),
          Expanded(child: _buildInvitationTournamentList()),
        ],
      ),
    );
  }

  Widget _studentList({
    required String title,
    required List<TournamentStudent> students,
    required IconData actionIcon,
    required String actionTooltip,
    required ValueChanged<TournamentStudent> onAction,
    IconData? secondaryActionIcon,
    String? secondaryActionTooltip,
    ValueChanged<TournamentStudent>? onSecondaryAction,
    _StudentSecondaryActionState Function(TournamentStudent)?
        secondaryActionState,
    bool Function(TournamentStudent)? primaryActionEnabled,
    Widget? controls,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.14),
        borderRadius: AppRadius.r8,
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              color: Color(0xFF252C35),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: MakeChessLocalizedText(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (controls != null) controls,
          Expanded(
            child: students.isEmpty
                ? _empty('Список пуст')
                : ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (_, index) {
                      final student = students[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.circle,
                          size: 10,
                          color: student.online
                              ? Colors.greenAccent
                              : Colors.white24,
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: MakeChessLocalizedText(
                                student.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            if (student.isOwner) ...[
                              const SizedBox(width: 8),
                              const Chip(
                                visualDensity: VisualDensity.compact,
                                label: MakeChessLocalizedText('Создатель • Вы'),
                              ),
                            ],
                          ],
                        ),
                        subtitle: MakeChessLocalizedText(
                          [
                            'Рейтинг: ${student.rating}',
                            if (student.country.trim().isNotEmpty)
                              student.country.trim(),
                            student.online ? 'онлайн' : 'не в сети',
                          ].join(' • '),
                          style: const TextStyle(color: Colors.white38),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (secondaryActionIcon != null &&
                                onSecondaryAction != null)
                              Builder(
                                builder: (_) {
                                  final state =
                                      secondaryActionState?.call(student) ??
                                          _StudentSecondaryActionState.enabled;
                                  final sent = state ==
                                      _StudentSecondaryActionState.sent;
                                  final participating = state ==
                                      _StudentSecondaryActionState
                                          .participating;
                                  final enabled = state ==
                                      _StudentSecondaryActionState.enabled;
                                  return IconButton(
                                    tooltip: MakeChessLocalization.phrase(
                                      participating
                                          ? 'Участвует в турнире'
                                          : sent
                                              ? 'Приглашение отправлено'
                                              : (secondaryActionTooltip ??
                                                  'Пригласить на турнир'),
                                    ),
                                    onPressed: enabled
                                        ? () => onSecondaryAction(student)
                                        : null,
                                    icon: Icon(
                                      participating
                                          ? Icons.verified_outlined
                                          : sent
                                              ? Icons.mark_email_read_outlined
                                              : secondaryActionIcon,
                                      color: sent || participating
                                          ? Colors.greenAccent
                                          : (enabled
                                              ? Colors.amberAccent
                                              : Colors.white24),
                                    ),
                                  );
                                },
                              ),
                            IconButton(
                              tooltip: actionTooltip,
                              onPressed:
                                  primaryActionEnabled?.call(student) == false
                                      ? null
                                      : () => onAction(student),
                              icon: Icon(actionIcon, color: Colors.cyanAccent),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairing() {
    final active = _activeTournament;
    return _page(
      title: 'Жеребьёвка',
      subtitle: active == null
          ? 'Сначала выберите турнир.'
          : 'Тур ${math.max(1, active.currentRound)}. Пары можно сформировать заново до запуска.',
      child: active == null
          ? _empty('Сначала создайте или откройте турнир')
          : Column(
              children: [
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _generatePairings,
                      icon: const Icon(Icons.shuffle),
                      label: MakeChessLocalizedText(active.pairings.isEmpty
                          ? 'Сформировать пары'
                          : 'Пережеребить'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: active.pairings.isEmpty
                          ? null
                          : () => _setStatus(_TournamentStatus.ready),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const MakeChessLocalizedText('Утвердить'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: active.pairings.isEmpty
                      ? _empty('Пары ещё не сформированы')
                      : ListView.separated(
                          itemCount: active.pairings.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 7),
                          itemBuilder: (_, index) {
                            final pairing = active.pairings[index];
                            return _pairingTile(pairing, editable: false);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _pairingTile(_TournamentPairing pairing, {required bool editable}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: AppRadius.r8,
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: MakeChessLocalizedText(
              'Стол ${pairing.board}',
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _onlineDot(pairing.whiteId),
          const SizedBox(width: 6),
          Expanded(
            child: MakeChessLocalizedText(
              _studentName(pairing.whiteId),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const MakeChessLocalizedText('—',
              style: TextStyle(color: Colors.white38)),
          const SizedBox(width: 10),
          if (pairing.blackId != null) _onlineDot(pairing.blackId!),
          if (pairing.blackId != null) const SizedBox(width: 6),
          Expanded(
            child: MakeChessLocalizedText(
              pairing.blackId == null
                  ? 'Свободен — техническая победа'
                  : _studentName(pairing.blackId),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (editable)
            DropdownButton<String>(
              value: pairing.result,
              dropdownColor: const Color(0xFF252C35),
              style: const TextStyle(color: Colors.white),
              items: const <String>['*', '1-0', '0-1', '½-½']
                  .map((value) => DropdownMenuItem<String>(
                        value: value,
                        child: MakeChessLocalizedText(value),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) _setPairingResult(pairing, value);
              },
            )
          else
            MakeChessLocalizedText(
              pairing.result,
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _onlineDot(String id) {
    return Icon(
      Icons.circle,
      size: 9,
      color: _isOnline(id) ? Colors.greenAccent : Colors.white24,
    );
  }

  Widget _buildGames() {
    final active = _activeTournament;
    return _page(
      title: 'Туры и партии',
      subtitle: active == null
          ? 'Сначала выберите турнир.'
          : 'Результаты текущего тура можно установить вручную.',
      child: active == null
          ? _empty('Сначала создайте или откройте турнир')
          : active.pairings.isEmpty
              ? _empty('Сначала выполните жеребьёвку')
              : ListView.separated(
                  itemCount: active.pairings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 7),
                  itemBuilder: (_, index) =>
                      _pairingTile(active.pairings[index], editable: true),
                ),
    );
  }

  Widget _buildStandings() {
    final active = _activeTournament;
    if (active == null) {
      return _page(
        title: 'Таблица результатов',
        subtitle: 'Промежуточные и итоговые результаты.',
        child: _empty('Сначала создайте или откройте турнир'),
      );
    }
    final scores = _standings(active);
    final ids = active.participantIds.toList()
      ..sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));

    return _page(
      title: 'Таблица результатов',
      subtitle: 'Очки обновляются после установки результатов партий.',
      child: ids.isEmpty
          ? _empty('Участники ещё не добавлены')
          : ListView.separated(
              itemCount: ids.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final id = ids[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    child: MakeChessLocalizedText('${index + 1}'),
                  ),
                  title: MakeChessLocalizedText(_studentName(id),
                      style: const TextStyle(color: Colors.white)),
                  subtitle: MakeChessLocalizedText(
                    _isOnline(id) ? 'онлайн' : 'не в школе',
                    style: const TextStyle(color: Colors.white38),
                  ),
                  trailing: MakeChessLocalizedText(
                    '${scores[id] ?? 0} очк.',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSettings() {
    final active = _activeTournament;
    if (active == null) {
      return _page(
        title: 'Настройка',
        subtitle: 'Изменение параметров выбранного турнира.',
        child: _empty('Сначала создайте или откройте турнир'),
      );
    }

    return _page(
      title: 'Настройка',
      subtitle: 'Изменяйте параметры до запуска турнира.',
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _nameCtl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Название турнира'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<_TournamentType>(
              value: _type,
              dropdownColor: const Color(0xFF252C35),
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Тип турнира'),
              items: _TournamentType.values
                  .map(
                    (type) => DropdownMenuItem<_TournamentType>(
                      value: type,
                      child: MakeChessLocalizedText(type.label),
                    ),
                  )
                  .toList(),
              onChanged: active.status == _TournamentStatus.running
                  ? null
                  : (value) {
                      if (value != null) setState(() => _type = value);
                    },
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: MakeChessLocalizedText(
                _type.description,
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<_TournamentFormat>(
                    value: _format,
                    dropdownColor: const Color(0xFF252C35),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Система'),
                    items: _TournamentFormat.values
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: MakeChessLocalizedText(e.label),
                            ))
                        .toList(),
                    onChanged: active.status == _TournamentStatus.running
                        ? null
                        : (value) {
                            if (value != null) setState(() => _format = value);
                          },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _roundsCtl,
                    enabled: active.status != _TournamentStatus.running,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Туры'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minutesCtl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Минуты'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _incrementCtl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Добавление'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxCtl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Участники'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _switchTile(
              title: 'Рейтинговый',
              subtitle: 'Учитывать результаты в рейтинге.',
              value: _rated,
              onChanged: (value) => setState(() => _rated = value),
            ),
            _switchTile(
              title: 'Видеосвязь',
              subtitle: 'Разрешить видео во время партий.',
              value: _videoEnabled,
              onChanged: (value) => setState(() => _videoEnabled = value),
            ),
            _switchTile(
              title: 'Сохранять партии',
              subtitle: 'Хранить партии для анализа.',
              value: _saveGames,
              onChanged: (value) => setState(() => _saveGames = value),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const MakeChessLocalizedText('Сохранить настройки'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControl() {
    final active = _activeTournament;
    if (active == null) {
      return _page(
        title: 'Управление',
        subtitle: 'Запуск, пауза и завершение турнира.',
        child: _empty('Сначала создайте или откройте турнир'),
      );
    }

    Widget command({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback? onPressed,
      Color? color,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.025),
          borderRadius: AppRadius.r8,
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color ?? Colors.cyanAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MakeChessLocalizedText(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  MakeChessLocalizedText(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: onPressed,
              child: const MakeChessLocalizedText('Выполнить'),
            ),
          ],
        ),
      );
    }

    return _page(
      title: 'Управление',
      subtitle:
          '${active.name} • ${active.participantIds.length} участников • ${active.status.label}',
      child: ListView(
        children: [
          command(
            icon: Icons.play_arrow,
            title: 'Запустить турнир',
            subtitle: 'Перевести турнир в состояние «Идёт».',
            onPressed: active.status == _TournamentStatus.running ||
                    active.status == _TournamentStatus.finished
                ? null
                : () => _setStatus(_TournamentStatus.running),
          ),
          command(
            icon: Icons.pause,
            title: 'Приостановить',
            subtitle: 'Временно остановить управление турами.',
            onPressed: active.status == _TournamentStatus.running
                ? () => _setStatus(_TournamentStatus.paused)
                : null,
            color: Colors.orangeAccent,
          ),
          command(
            icon: Icons.skip_next,
            title: 'Следующий тур',
            subtitle:
                'Сохранить партии текущего тура и перейти к новой жеребьёвке.',
            onPressed: active.status == _TournamentStatus.finished
                ? null
                : _goToNextRound,
          ),
          command(
            icon: Icons.stop_circle_outlined,
            title: 'Завершить турнир',
            subtitle:
                'Зафиксировать результаты и автоматически перенести турнир в архив.',
            onPressed: active.status == _TournamentStatus.finished
                ? null
                : _finishActiveTournament,
            color: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildArchive() {
    final opened = _openedArchiveTournament;
    if (opened != null) return _buildArchiveDetails(opened);

    final tournaments = _archivedTournaments.toList()
      ..sort((a, b) {
        final ad = a.finishedAt ?? a.createdAt;
        final bd = b.finishedAt ?? b.createdAt;
        return bd.compareTo(ad);
      });

    return _page(
      title: 'Архив',
      subtitle:
          'Завершённые турниры. Результаты и партии доступны только для просмотра.',
      child: tournaments.isEmpty
          ? _empty('В архиве пока нет завершённых турниров')
          : ListView.separated(
              itemCount: tournaments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final tournament = tournaments[index];
                final scores = _standings(tournament);
                final leaders = tournament.participantIds.toList()
                  ..sort(
                    (a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0),
                  );
                final winner = leaders.isEmpty
                    ? 'Нет участников'
                    : _tournamentStudentName(tournament, leaders.first);
                return Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.025),
                    borderRadius: AppRadius.r8,
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withOpacity(0.1),
                          borderRadius: AppRadius.r8,
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.amberAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MakeChessLocalizedText(
                              tournament.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            MakeChessLocalizedText(
                              '${tournament.type.label} • ${tournament.format.label} • '
                              '${tournament.participantIds.length} участников • '
                              '${_archiveRounds(tournament).length} туров • '
                              'завершён ${_formatDateTime(tournament.finishedAt)}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            const SizedBox(height: 3),
                            MakeChessLocalizedText(
                              'Победитель: $winner',
                              style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _openedArchiveTournamentId = tournament.id;
                            _archiveShowGames = false;
                          });
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const MakeChessLocalizedText('Открыть'),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: MakeChessLocalization.phrase(
                            'Скопировать как новый шаблон'),
                        onPressed: () => _copyArchiveAsTemplate(tournament),
                        icon: const Icon(
                          Icons.copy_all_outlined,
                          color: Colors.cyanAccent,
                        ),
                      ),
                      IconButton(
                        tooltip:
                            MakeChessLocalization.phrase('Удалить из архива'),
                        onPressed: () => _deleteTournament(tournament),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildArchiveDetails(_TournamentData tournament) {
    return _page(
      title: tournament.name,
      localizeTitle: false,
      subtitle:
          'Архивный турнир. Изменение результатов и настроек заблокировано.',
      child: Column(
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _openedArchiveTournamentId = null;
                    _archiveShowGames = false;
                  });
                },
                icon: const Icon(Icons.arrow_back),
                label: const MakeChessLocalizedText('К архиву'),
              ),
              const SizedBox(width: 10),
              _archiveModeButton(
                selected: !_archiveShowGames,
                icon: Icons.leaderboard,
                label: 'Итоговые результаты',
                onPressed: () => setState(() => _archiveShowGames = false),
              ),
              const SizedBox(width: 8),
              _archiveModeButton(
                selected: _archiveShowGames,
                icon: Icons.sports_esports_outlined,
                label: 'Партии',
                onPressed: () => setState(() => _archiveShowGames = true),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _copyArchiveAsTemplate(tournament),
                icon: const Icon(Icons.copy_all_outlined),
                label: const MakeChessLocalizedText('Скопировать как шаблон'),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: MakeChessLocalization.phrase('Удалить из архива'),
                onPressed: () => _deleteTournament(tournament),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.025),
              borderRadius: AppRadius.r8,
              border: Border.all(color: Colors.white10),
            ),
            child: Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _archiveMetric('Тип', tournament.type.label),
                _archiveMetric('Система', tournament.format.label),
                _archiveMetric(
                  'Контроль',
                  '${tournament.minutes}+${tournament.increment}',
                ),
                _archiveMetric(
                  'Участники',
                  '${tournament.participantIds.length}',
                ),
                _archiveMetric(
                  'Туры',
                  '${_archiveRounds(tournament).length}',
                ),
                _archiveMetric(
                  'Создан',
                  _formatDateTime(tournament.createdAt),
                ),
                _archiveMetric(
                  'Завершён',
                  _formatDateTime(tournament.finishedAt),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _archiveShowGames
                ? _buildArchivedGames(tournament)
                : _buildArchivedStandings(tournament),
          ),
        ],
      ),
    );
  }

  Widget _archiveModeButton({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return selected
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: MakeChessLocalizedText(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: MakeChessLocalizedText(label),
          );
  }

  Widget _archiveMetric(String label, String value) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MakeChessLocalizedText(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 2),
          MakeChessLocalizedText(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedStandings(_TournamentData tournament) {
    final scores = _standings(tournament);
    final ids = tournament.participantIds.toList()
      ..sort((a, b) {
        final byScore = (scores[b] ?? 0).compareTo(scores[a] ?? 0);
        if (byScore != 0) return byScore;
        return _tournamentStudentName(tournament, a)
            .compareTo(_tournamentStudentName(tournament, b));
      });

    if (ids.isEmpty) return _empty('В турнире нет участников');
    return ListView.separated(
      itemCount: ids.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final id = ids[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 17,
            backgroundColor: index == 0
                ? Colors.amberAccent
                : Colors.white.withOpacity(0.08),
            foregroundColor: index == 0 ? Colors.black : Colors.white,
            child: MakeChessLocalizedText('${index + 1}'),
          ),
          title: MakeChessLocalizedText(
            _tournamentStudentName(tournament, id),
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: MakeChessLocalizedText(
            'ID: $id',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          trailing: MakeChessLocalizedText(
            '${scores[id] ?? 0} очк.',
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }

  List<_TournamentRoundSnapshot> _archiveRounds(
    _TournamentData tournament,
  ) {
    if (tournament.roundHistory.isNotEmpty) {
      final rounds = tournament.roundHistory.toList()
        ..sort((a, b) => a.roundNumber.compareTo(b.roundNumber));
      return rounds;
    }
    if (tournament.pairings.isEmpty) return <_TournamentRoundSnapshot>[];
    return <_TournamentRoundSnapshot>[
      _TournamentRoundSnapshot(
        roundNumber: math.max(1, tournament.currentRound),
        pairings: tournament.pairings,
        savedAt: tournament.finishedAt ?? tournament.createdAt,
      ),
    ];
  }

  Widget _buildArchivedGames(_TournamentData tournament) {
    final rounds = _archiveRounds(tournament);
    if (rounds.isEmpty) return _empty('В архиве нет записанных партий');

    return ListView.separated(
      itemCount: rounds.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, roundIndex) {
        final round = rounds[roundIndex];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.025),
            borderRadius: AppRadius.r8,
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF252C35),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    MakeChessLocalizedText(
                      'Тур ${round.roundNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    MakeChessLocalizedText(
                      '${round.pairings.length} партий • '
                      '${_formatDateTime(round.savedAt)}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < round.pairings.length; i++) ...[
                _archivedGameTile(
                  tournament: tournament,
                  roundNumber: round.roundNumber,
                  pairing: round.pairings[i],
                ),
                if (i + 1 < round.pairings.length) const Divider(height: 1),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _archivedGameTile({
    required _TournamentData tournament,
    required int roundNumber,
    required _TournamentPairing pairing,
  }) {
    return ListTile(
      dense: true,
      leading: SizedBox(
        width: 58,
        child: MakeChessLocalizedText(
          'Стол ${pairing.board}',
          style: const TextStyle(color: Colors.white54),
        ),
      ),
      title: MakeChessLocalizedText(
        '${_tournamentStudentName(tournament, pairing.whiteId)} — '
        '${_tournamentStudentName(tournament, pairing.blackId)}',
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: MakeChessLocalizedText(
        pairing.resultReason.trim().isEmpty
            ? 'Результат зафиксирован в архиве'
            : pairing.resultReason,
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withOpacity(0.08),
              borderRadius: AppRadius.r8,
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.35)),
            ),
            child: MakeChessLocalizedText(
              pairing.result,
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _showArchivedGameDetails(
              tournament: tournament,
              roundNumber: roundNumber,
              pairing: pairing,
            ),
            child: const MakeChessLocalizedText('Подробнее'),
          ),
        ],
      ),
      onTap: () => _showArchivedGameDetails(
        tournament: tournament,
        roundNumber: roundNumber,
        pairing: pairing,
      ),
    );
  }

  Widget _empty(String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, color: Colors.white24, size: 44),
          const SizedBox(height: 10),
          MakeChessLocalizedText(text,
              style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}
