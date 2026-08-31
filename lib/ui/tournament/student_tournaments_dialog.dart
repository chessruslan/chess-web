// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
// MAKECHESS_STUDENT_TOURNAMENTS_LOCALIZED_V3_2_20260807
import 'package:flutter/material.dart';

import '../../localization/makechess_localization.dart';

import '../../services/tournament_storage_service.dart';
import '../messages/general_messages_dialog.dart';
import 'tournament_game_platform_dialog.dart';
import 'tournament_table_editor.dart';

enum _StudentTournamentSection {
  current,
  archive,
  statistics,
  settings,
  search
}

enum _CurrentTournamentFilter { all, mine, accepted }

enum _TournamentStartFilter { all, started, notStarted }

enum _FilterLogic { and, or }

Future<void> showStudentTournamentsDialog({
  required BuildContext context,
  required String studentId,
  required String studentName,
  String dialogTitle = 'Турниры ученика',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _StudentTournamentsDialog(
      studentId: studentId,
      studentName: studentName,
      dialogTitle: dialogTitle,
    ),
  );
}

/// The current-tournaments content without its own dialog, header or sidebar.
/// Used inside the tournament manager's right-hand content area.
class TournamentCurrentTournamentsPanel extends StatelessWidget {
  const TournamentCurrentTournamentsPanel({
    super.key,
    required this.userId,
    required this.userName,
  });

  final String userId;
  final String userName;

  @override
  Widget build(BuildContext context) => _StudentTournamentsDialog(
        studentId: userId,
        studentName: userName,
        dialogTitle: 'Текущие турниры',
        embedded: true,
      );
}

/// Tournament statistics rendered as a section of the tournament manager.
class TournamentStatisticsPanel extends StatelessWidget {
  const TournamentStatisticsPanel({
    super.key,
    required this.userId,
    required this.userName,
  });

  final String userId;
  final String userName;

  @override
  Widget build(BuildContext context) => _StudentTournamentsDialog(
        studentId: userId,
        studentName: userName,
        dialogTitle: 'Статистика',
        embedded: true,
        statisticsOnly: true,
      );
}

class _StudentTournamentsDialog extends StatefulWidget {
  const _StudentTournamentsDialog({
    required this.studentId,
    required this.studentName,
    required this.dialogTitle,
    this.embedded = false,
    this.statisticsOnly = false,
  });

  final String studentId;
  final String studentName;
  final String dialogTitle;
  final bool embedded;
  final bool statisticsOnly;

  @override
  State<_StudentTournamentsDialog> createState() =>
      _StudentTournamentsDialogState();
}

class _StudentTournamentsDialogState extends State<_StudentTournamentsDialog> {
  _StudentTournamentSection _section = _StudentTournamentSection.current;
  bool _loading = true;
  String? _loadError;
  _CurrentTournamentFilter _currentFilter = _CurrentTournamentFilter.all;
  _TournamentStartFilter _startFilter = _TournamentStartFilter.all;
  _FilterLogic _filterLogic = _FilterLogic.and;
  bool _filtersExpanded = false;
  final Set<String> _enabledFilters = <String>{};
  String? _selectedTournamentKey;
  List<Map<String, dynamic>> _tournaments = <Map<String, dynamic>>[];
  final TextEditingController _searchCtl = TextEditingController();
  final Map<String, TextEditingController> _filterControllers = {
    for (final key in const <String>[
      'name',
      'dateFrom',
      'dateTo',
      'ratingFrom',
      'ratingTo',
      'rounds',
      'participants',
      'title',
      'group',
      'age',
      'geography',
      'finance',
      'rated',
      'prize',
      'grandmaster',
      'master',
      'candidateMaster',
    ])
      key: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    if (widget.statisticsOnly) {
      _section = _StudentTournamentSection.statistics;
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final list =
          await TournamentStorageService.instance.loadVisibleTournaments();
      if (!mounted) return;
      setState(() {
        _tournaments = list;
        _loadError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = '$error';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _current => _tournaments.where((e) {
        final status = '${e['status'] ?? ''}'.toLowerCase();
        return e['isTemplate'] != true &&
            (status == 'ready' || status == 'running' || status == 'paused');
      }).toList();

  List<Map<String, dynamic>> get _baseFilteredCurrent =>
      switch (_currentFilter) {
        _CurrentTournamentFilter.all => _current,
        _CurrentTournamentFilter.mine => _current
            .where((e) =>
                '${e['_ownerId'] ?? ''}' ==
                TournamentStorageService.instance.currentUserId)
            .toList(),
        _CurrentTournamentFilter.accepted =>
          _current.where(_isParticipant).toList(),
      };

  List<Map<String, dynamic>> get _filteredCurrent => _baseFilteredCurrent
      .where(_matchesStartFilter)
      .where(_matchesAdvancedFilters)
      .toList(growable: false);

  bool _matchesStartFilter(Map<String, dynamic> tournament) {
    final status = '${tournament['status'] ?? ''}'.toLowerCase();
    final started = status == 'running' || status == 'paused';
    return switch (_startFilter) {
      _TournamentStartFilter.all => true,
      _TournamentStartFilter.started => started,
      _TournamentStartFilter.notStarted => !started,
    };
  }

  String _filterValue(String key) =>
      _filterControllers[key]?.text.trim().toLowerCase() ?? '';

  String _searchableTournament(Map<String, dynamic> tournament) =>
      tournament.entries
          .map((e) => '${e.key} ${e.value}')
          .join(' ')
          .toLowerCase();

  bool _matchesAdvancedFilters(Map<String, dynamic> tournament) {
    if (_enabledFilters.isEmpty) return true;
    final searchable = _searchableTournament(tournament);
    final checks = <bool>[];
    for (final key in _enabledFilters) {
      final value = _filterValue(key);
      bool match;
      switch (key) {
        case 'name':
          match = '${tournament['name'] ?? ''}'.toLowerCase().contains(value);
          break;
        case 'rounds':
          match = '${tournament['rounds'] ?? ''}' == value;
          break;
        case 'participants':
          final count = tournament['participantIds'] is List
              ? (tournament['participantIds'] as List).length
              : 0;
          match = '$count' == value;
          break;
        case 'ratingFrom':
          final minimum = int.tryParse(value);
          final rating = int.tryParse(
              '${tournament['minRating'] ?? tournament['ratingFrom'] ?? ''}');
          match = minimum != null && rating != null && rating >= minimum;
          break;
        case 'ratingTo':
          final maximum = int.tryParse(value);
          final rating = int.tryParse(
              '${tournament['maxRating'] ?? tournament['ratingTo'] ?? ''}');
          match = maximum != null && rating != null && rating <= maximum;
          break;
        case 'dateFrom':
          final from = DateTime.tryParse(value);
          final date = DateTime.tryParse(
              '${tournament['createdAt'] ?? tournament['start'] ?? ''}');
          match = from != null && date != null && !date.isBefore(from);
          break;
        case 'dateTo':
          final to = DateTime.tryParse(value);
          final date = DateTime.tryParse(
              '${tournament['createdAt'] ?? tournament['start'] ?? ''}');
          match = to != null && date != null && !date.isAfter(to);
          break;
        default:
          match = value.isNotEmpty && searchable.contains(value);
          break;
      }
      checks.add(match);
    }
    return _filterLogic == _FilterLogic.and
        ? checks.every((value) => value)
        : checks.any((value) => value);
  }

  List<Map<String, dynamic>> get _archive => _tournaments
      .where((e) =>
          e['isTemplate'] != true && '${e['status'] ?? ''}' == 'finished')
      .toList();

  bool _isParticipant(Map<String, dynamic> tournament) {
    final ids = tournament['participantIds'];
    final authId = TournamentStorageService.instance.currentUserId;
    return ids is List &&
        ids
            .map((e) => '$e')
            .any((id) => id == authId || id == widget.studentId);
  }

  bool _isOwner(Map<String, dynamic> tournament) =>
      '${tournament['_ownerId'] ?? ''}' ==
      TournamentStorageService.instance.currentUserId;

  Future<void> _callTournament(Map<String, dynamic> tournament) async {
    final controller = TextEditingController(text: '10');
    final minutes = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: MakeChessLocalizedText(
            MakeChessLocalization.phrase('Вызвать участников')),
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
            child:
                MakeChessLocalizedText(MakeChessLocalization.phrase('Отмена')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              int.tryParse(controller.text.trim()),
            ),
            child: MakeChessLocalizedText(
                MakeChessLocalization.phrase('Отправить')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (minutes == null || minutes < 1) return;

    final clientUser = TournamentStorageService.instance.currentUserId;
    final startAt = DateTime.now().toUtc().add(Duration(minutes: minutes));
    await TournamentStorageService.instance.updateOwnedTournamentFields(
      '${tournament['id'] ?? ''}',
      <String, dynamic>{
        'callMinutes': minutes,
        'scheduledStartAt': startAt.toIso8601String(),
      },
    );
    final fallbackParticipantIds = tournament['participantIds'] is List
        ? (tournament['participantIds'] as List).map((e) => '$e').toSet()
        : <String>{};
    final participantIds = await TournamentStorageService.instance
        .loadOwnedTournamentParticipantIds(
      '${tournament['id'] ?? ''}',
      fallback: fallbackParticipantIds,
    );
    final senderName = widget.studentName.trim().isEmpty
        ? MakeChessLocalization.phrase('Организатор')
        : widget.studentName.trim();
    for (final recipientId in participantIds) {
      await MakeChessMessageRealtimeService.instance.send(
        MakeChessMessage(
          id: 'tournament_call_${DateTime.now().microsecondsSinceEpoch}_$recipientId',
          recipientId: recipientId,
          senderId: clientUser,
          senderName: senderName,
          category: 'tournament_call',
          title: 'Скоро начнётся турнир «${tournament['name'] ?? 'Турнир'}»',
          body:
              'Турнир начнётся через $minutes мин. Откройте игровую платформу и приготовьтесь к игре.',
          createdAt: DateTime.now(),
          tournamentId: '${tournament['id'] ?? ''}',
        ),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: MakeChessLocalizedText(
        MakeChessLocalization.phrase(
          'Уведомление отправлено: начало через {minutes} мин.',
          params: <String, Object?>{'minutes': minutes},
        ),
      )),
    );
    await _load();
  }

  Future<void> _startTournament(Map<String, dynamic> tournament) async {
    final participantIds = tournament['participantIds'] is List
        ? (tournament['participantIds'] as List).map((e) => '$e').toList()
        : <String>[];
    if (participantIds.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: MakeChessLocalizedText(
              MakeChessLocalization.phrase(
                  'Для начала турнира нужны минимум два участника'),
            ),
          ),
        );
      }
      return;
    }
    final pairings = tournament['pairings'];
    if (pairings is! List || pairings.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: MakeChessLocalizedText(
              MakeChessLocalization.phrase(
                  'Сначала выполните жеребьёвку турнира'),
            ),
          ),
        );
      }
      return;
    }
    await TournamentStorageService.instance.updateOwnedTournamentFields(
      '${tournament['id'] ?? ''}',
      <String, dynamic>{
        'status': 'running',
        'startedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
    await TournamentStorageService.instance
        .startTournamentGames('${tournament['id'] ?? ''}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: MakeChessLocalizedText(
          MakeChessLocalization.phrase(
              'Турнир начат. Игровые доски активируются.'),
        ),
      ),
    );
    await _load();
  }

  Future<void> _setTournamentStatus(
    Map<String, dynamic> tournament,
    String status,
  ) async {
    await TournamentStorageService.instance.updateOwnedTournamentFields(
      '${tournament['id'] ?? ''}',
      <String, dynamic>{
        'status': status,
        if (status == 'finished')
          'finishedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
    await TournamentStorageService.instance.controlTournamentGames(
      '${tournament['id'] ?? ''}',
      status,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: MakeChessLocalizedText(status == 'paused'
            ? MakeChessLocalization.phrase('Турнир приостановлен')
            : MakeChessLocalization.phrase('Турнир завершён')),
      ),
    );
    await _load();
  }

  Future<void> _openTournament(Map<String, dynamic> tournament) async {
    final tournamentId = '${tournament['id'] ?? ''}';
    final owner = _isOwner(tournament);
    Map<String, dynamic>? storedData;
    try {
      storedData = owner
          ? await TournamentStorageService.instance
              .loadTournamentTable(tournamentId)
          : await TournamentStorageService.instance.loadInvitedTournamentTable(
              ownerId: '${tournament['_ownerId'] ?? ''}',
              tournamentId: tournamentId,
            );
    } catch (_) {
      // The tournament itself is still usable when its optional visual table
      // has not been created yet. Rebuild the view from the main record.
    }
    if (!mounted) return;
    final participantIds = tournament['participantIds'] is List
        ? (tournament['participantIds'] as List).map((e) => '$e').toList()
        : <String>[];
    final participantNames = tournament['participantNames'] is Map
        ? Map<String, dynamic>.from(tournament['participantNames'] as Map)
        : <String, dynamic>{};
    final fallbackParticipants = participantIds
        .map((id) => <String, dynamic>{
              'id': id,
              'name': '${participantNames[id] ?? id}',
              'rating': 1200,
              'school': '',
              'flag': '',
              'avatarUrl': '',
            })
        .toList(growable: false);
    final data = storedData ??
        <String, dynamic>{
          'name': '${tournament['name'] ?? 'Турнир'}',
          'type': '${tournament['format'] ?? ''}',
          'status': '${tournament['status'] ?? ''}',
          'minutes': tournament['minutes'] ?? 5,
          'increment': tournament['increment'] ?? 0,
          'rounds': tournament['rounds'] ?? 1,
          'maxParticipants': tournament['maxParticipants'] ?? 8,
          'organizer': widget.studentName,
          'participants': fallbackParticipants,
          'results': const <String, String>{},
        };
    final participants = data['participants'] is List
        ? (data['participants'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    final results = data['results'] is Map
        ? Map<String, String>.fromEntries((data['results'] as Map)
            .entries
            .map((e) => MapEntry('${e.key}', '${e.value}')))
        : <String, String>{};
    int number(String key, int fallback) =>
        int.tryParse('${data[key] ?? ''}') ?? fallback;
    await showTournamentTableEditor(
      context: context,
      tournamentId: tournamentId,
      initialName: '${data['name'] ?? tournament['name'] ?? 'Турнир'}',
      initialType: '${data['type'] ?? tournament['format'] ?? ''}',
      initialStatus: '${tournament['status'] ?? data['status'] ?? ''}',
      initialMinutes: number('minutes', 5),
      initialIncrement: number('increment', 0),
      initialRounds: number('rounds', 1),
      initialParticipantNames:
          participants.map((e) => '${e['name'] ?? 'Участник'}').toList(),
      maxParticipants: number('maxParticipants',
          int.tryParse('${tournament['maxParticipants'] ?? ''}') ?? 8),
      startInPreview: true,
      previewMode: !owner,
      organizerMode: owner,
      onCallTournament: owner ? () => _callTournament(tournament) : null,
      onStartTournament: owner ? () => _startTournament(tournament) : null,
      onPauseTournament:
          owner ? () => _setTournamentStatus(tournament, 'paused') : null,
      onFinishTournament:
          owner ? () => _setTournamentStatus(tournament, 'finished') : null,
      onParticipate: !_isParticipant(tournament)
          ? () => _requestParticipation(tournament)
          : null,
      initialJudge: '${data['judge'] ?? ''}',
      initialVenue: '${data['venue'] ?? ''}',
      initialOrganizer: '${data['organizer'] ?? widget.studentName}',
      initialStart: '${data['start'] ?? ''}',
      initialEnd: '${data['end'] ?? ''}',
      initialAge: '${data['age'] ?? ''}',
      initialParticipantsData: participants,
      initialResults: results,
    );
  }

  Future<void> _openGamePlatform() async {
    final userId = TournamentStorageService.instance.currentUserId;
    final visible =
        await TournamentStorageService.instance.loadVisibleTournaments();
    Map<String, dynamic>? running;
    for (final tournament in visible) {
      final ids = tournament['participantIds'];
      if ('${tournament['status'] ?? ''}' == 'running' &&
          ids is List &&
          ids.map((e) => '$e').contains(userId)) {
        running = tournament;
        break;
      }
    }
    var playAsBlack = false;
    var opponentName = MakeChessLocalization.phrase('Соперник');
    if (running != null && running['pairings'] is List) {
      for (final raw in running['pairings'] as List) {
        if (raw is! Map) continue;
        final whiteId = '${raw['whiteId'] ?? ''}';
        final blackId = '${raw['blackId'] ?? ''}';
        if (whiteId == userId || blackId == userId) {
          playAsBlack = blackId == userId;
          final opponentId = playAsBlack ? whiteId : blackId;
          final names = running['participantNames'];
          if (names is Map) opponentName = '${names[opponentId] ?? opponentId}';
          break;
        }
      }
    }
    if (!mounted) return;
    await showTournamentGamePlatform(
      context: context,
      tournamentName:
          '${running?['name'] ?? MakeChessLocalization.phrase('Турнир')}',
      gameActive: running != null,
      playAsBlack: playAsBlack,
      opponentName: opponentName,
      tournamentId: '${running?['id'] ?? ''}',
      ownerId: '${running?['_ownerId'] ?? ''}',
    );
  }

  Future<void> _requestParticipation(Map<String, dynamic> tournament) async {
    if (_isParticipant(tournament)) return;
    final tournamentId = '${tournament['id'] ?? ''}';
    final result = await TournamentStorageService.instance.requestParticipation(
      ownerId: '${tournament['_ownerId'] ?? ''}',
      tournamentId: tournamentId,
    );
    if (!mounted) return;

    String message;
    if (result == 'joined' ||
        result == 'owner_joined' ||
        result == 'already_joined') {
      message = MakeChessLocalization.phrase(
        'Вы добавлены в турнирную таблицу',
      );
    } else if (result == 'owner_full') {
      message = MakeChessLocalization.phrase(
        'В турнире нет свободных мест',
      );
    } else if (result.startsWith('owner_rating_low|')) {
      final parts = result.split('|');
      final actual = parts.length > 1 ? parts[1] : '?';
      final required = parts.length > 2 ? parts[2] : '?';
      message =
          'Ваш рейтинг $actual ниже минимального рейтинга турнира $required. '
          'Чтобы участвовать, поднимите свой рейтинг либо снизьте '
          'ограничение по рейтингу турнира.';
    } else if (result.startsWith('owner_rating_high|')) {
      final parts = result.split('|');
      final actual = parts.length > 1 ? parts[1] : '?';
      final required = parts.length > 2 ? parts[2] : '?';
      message =
          'Ваш рейтинг $actual выше максимального рейтинга турнира $required. '
          'Чтобы участвовать, измените ограничение по рейтингу турнира.';
    } else if (result == 'owner_not_found') {
      message = MakeChessLocalization.phrase('Турнир не найден');
    } else if (result == 'not_authenticated') {
      message = 'Сначала войдите в аккаунт.';
    } else {
      message = MakeChessLocalization.phrase(
        'Заявка на участие отправлена организатору',
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: MakeChessLocalizedText(message)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _body();
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 1120,
        height: 760,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1721),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.cyanAccent.withOpacity(.5)),
        ),
        child: Column(
          children: [
            _header(),
            Expanded(
              child: Row(
                children: [
                  _navigation(),
                  Expanded(child: _body()),
                ],
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
            const Icon(Icons.emoji_events, color: Colors.amberAccent),
            const SizedBox(width: 10),
            MakeChessLocalizedText(
                MakeChessLocalization.phrase(widget.dialogTitle),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );

  Widget _navigation() {
    Widget item(_StudentTournamentSection section, IconData icon, String text) {
      final active = _section == section;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          selected: active,
          selectedTileColor: Colors.cyanAccent.withOpacity(.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading:
              Icon(icon, color: active ? Colors.cyanAccent : Colors.white54),
          title: MakeChessLocalizedText(text),
          onTap: () => setState(() => _section = section),
        ),
      );
    }

    return Container(
      width: 230,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF131E29),
        border: Border(right: BorderSide(color: Color(0xFF31404E))),
      ),
      child: Column(
        children: [
          item(_StudentTournamentSection.current, Icons.play_circle_outline,
              MakeChessLocalization.phrase('Текущие турниры')),
          item(_StudentTournamentSection.archive, Icons.archive_outlined,
              MakeChessLocalization.phrase('Архив')),
          item(_StudentTournamentSection.statistics, Icons.bar_chart,
              MakeChessLocalization.phrase('Статистика')),
          item(_StudentTournamentSection.settings, Icons.settings_outlined,
              MakeChessLocalization.phrase('Настройки')),
          item(_StudentTournamentSection.search, Icons.search,
              MakeChessLocalization.phrase('Поиск')),
          const Spacer(),
          FilledButton.icon(
            onPressed: _openGamePlatform,
            icon: const Icon(Icons.sports_esports),
            label: MakeChessLocalizedText(
                MakeChessLocalization.phrase('Игровая платформа')),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MakeChessLocalizedText(MakeChessLocalization.phrase(
                'Не удалось загрузить турниры из базы данных')),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                setState(() => _loading = true);
                _load();
              },
              icon: const Icon(Icons.refresh),
              label: MakeChessLocalizedText(
                  MakeChessLocalization.phrase('Повторить')),
            ),
          ],
        ),
      );
    }
    switch (_section) {
      case _StudentTournamentSection.current:
        return _currentPage();
      case _StudentTournamentSection.archive:
        return _tournamentList(_archive, current: false);
      case _StudentTournamentSection.statistics:
        final played = _archive.where(_isParticipant).length;
        final active = _current.where(_isParticipant).length;
        return _simplePage(
          MakeChessLocalization.phrase('Статистика'),
          MakeChessLocalization.phrase(
            'Текущих турниров: {active}\nЗавершённых турниров: {played}',
            params: <String, Object?>{'active': active, 'played': played},
          ),
        );
      case _StudentTournamentSection.settings:
        return _simplePage(
          MakeChessLocalization.phrase('Настройки'),
          MakeChessLocalization.phrase(
            'Уведомления о приглашениях и начале туров будут настраиваться здесь.',
          ),
        );
      case _StudentTournamentSection.search:
        final query = _searchCtl.text.trim().toLowerCase();
        final found = _current
            .where((e) => '${e['name'] ?? ''}'.toLowerCase().contains(query))
            .toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchCtl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  labelText: MakeChessLocalization.phrase('Поиск турнира'),
                ),
              ),
            ),
            Expanded(
                child: _tournamentList(found, current: true, withTitle: false)),
          ],
        );
    }
  }

  Widget _currentPage() {
    Widget filterButton(_CurrentTournamentFilter value, String label) {
      final selected = _currentFilter == value;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: OutlinedButton(
            onPressed: () => setState(() => _currentFilter = value),
            style: OutlinedButton.styleFrom(
              backgroundColor:
                  selected ? Colors.cyanAccent.withOpacity(.14) : null,
              foregroundColor: selected ? Colors.cyanAccent : Colors.white70,
              side: BorderSide(
                color: selected ? Colors.cyanAccent : Colors.white24,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: MakeChessLocalizedText(label, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 10, 4),
          child: Row(
            children: [
              filterButton(_CurrentTournamentFilter.all,
                  MakeChessLocalization.phrase('Все текущие турниры')),
              filterButton(_CurrentTournamentFilter.mine,
                  MakeChessLocalization.phrase('Мои турниры')),
              filterButton(_CurrentTournamentFilter.accepted,
                  MakeChessLocalization.phrase('Принятые турниры')),
              if (!widget.embedded)
                IconButton(
                  tooltip: MakeChessLocalization.phrase('Обновить'),
                  onPressed: () {
                    setState(() => _loading = true);
                    _load();
                  },
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _startFilter =
                        _startFilter == _TournamentStartFilter.started
                            ? _TournamentStartFilter.all
                            : _TournamentStartFilter.started;
                  }),
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        _startFilter == _TournamentStartFilter.started
                            ? Colors.cyanAccent.withOpacity(.14)
                            : null,
                  ),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Начатые турниры'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _startFilter =
                        _startFilter == _TournamentStartFilter.notStarted
                            ? _TournamentStartFilter.all
                            : _TournamentStartFilter.notStarted;
                  }),
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        _startFilter == _TournamentStartFilter.notStarted
                            ? Colors.cyanAccent.withOpacity(.14)
                            : null,
                  ),
                  icon: const Icon(Icons.hourglass_empty),
                  label: const Text('Не начатые турниры'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _filtersExpanded = !_filtersExpanded),
                icon: Icon(_filtersExpanded
                    ? Icons.filter_alt_off_outlined
                    : Icons.filter_alt_outlined),
                label: Text(
                    'Фильтры${_enabledFilters.isEmpty ? '' : ' (${_enabledFilters.length})'}'),
              ),
            ],
          ),
        ),
        if (_filtersExpanded) _advancedFilterPanel(),
        Expanded(
          child: _tournamentList(
            _filteredCurrent,
            current: true,
            withTitle: false,
          ),
        ),
      ],
    );
  }

  Widget _advancedFilterPanel() {
    const definitions = <(String, String, String)>[
      ('name', 'Название', 'Текст названия'),
      ('dateFrom', 'Дата от', '2026-09-01'),
      ('dateTo', 'Дата до', '2026-09-30'),
      ('ratingFrom', 'Рейтинг от', '1200'),
      ('ratingTo', 'Рейтинг до', '2400'),
      ('rounds', 'Число туров', '5'),
      ('participants', 'Число участников', '12'),
      ('title', 'Звание участников', 'Гроссмейстер, мастер, КМС'),
      ('group', 'Группа / школа / клуб', 'Название группы'),
      ('age', 'Возрастной критерий', 'Например: до 14 лет'),
      ('geography', 'География', 'Страна, регион, город'),
      ('finance', 'Участие', 'Платный / бесплатный'),
      ('rated', 'Расчёт рейтинга', 'С расчётом / без расчёта'),
      ('prize', 'Призовой фонд', 'Есть / нет'),
      ('grandmaster', 'Участие гроссмейстеров', 'Есть / нет'),
      ('master', 'Участие мастеров', 'Есть / нет'),
      ('candidateMaster', 'Участие КМС', 'Есть / нет'),
    ];
    return Container(
      height: 320,
      margin: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Логика поиска:',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('И — совпадают все'),
                selected: _filterLogic == _FilterLogic.and,
                onSelected: (_) =>
                    setState(() => _filterLogic = _FilterLogic.and),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('ИЛИ — совпадает любой'),
                selected: _filterLogic == _FilterLogic.or,
                onSelected: (_) =>
                    setState(() => _filterLogic = _FilterLogic.or),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _enabledFilters.clear();
                  for (final controller in _filterControllers.values) {
                    controller.clear();
                  }
                }),
                child: const Text('Сбросить'),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView.separated(
              itemCount: definitions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, index) {
                final definition = definitions[index];
                final enabled = _enabledFilters.contains(definition.$1);
                return Row(
                  children: [
                    Checkbox(
                      value: enabled,
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          _enabledFilters.add(definition.$1);
                        } else {
                          _enabledFilters.remove(definition.$1);
                        }
                      }),
                    ),
                    SizedBox(width: 235, child: Text(definition.$2)),
                    Expanded(
                      child: TextField(
                        controller: _filterControllers[definition.$1],
                        enabled: enabled,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: definition.$3,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _simplePage(String title, String text) => Padding(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MakeChessLocalizedText(title,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              MakeChessLocalizedText(text,
                  style: const TextStyle(color: Colors.white70, height: 1.7)),
            ],
          ),
        ),
      );

  Widget _tournamentList(List<Map<String, dynamic>> items,
      {required bool current, bool withTitle = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (withTitle)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: MakeChessLocalizedText(
              current
                  ? MakeChessLocalization.phrase('Все текущие турниры')
                  : MakeChessLocalization.phrase('Архив турниров'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: MakeChessLocalizedText(
                    MakeChessLocalization.phrase('Турниров пока нет'),
                    style: const TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final t = items[index];
                    final tournamentKey =
                        '${t['_ownerId'] ?? ''}::${t['id'] ?? ''}';
                    final selected = tournamentKey == _selectedTournamentKey;
                    final joined = _isParticipant(t);
                    final owned = _isOwner(t);
                    final count = (t['participantIds'] is List)
                        ? (t['participantIds'] as List).length
                        : 0;
                    return InkWell(
                      onTap: () => setState(
                          () => _selectedTournamentKey = tournamentKey),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.cyanAccent.withOpacity(.10)
                              : Colors.white.withOpacity(.03),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? Colors.cyanAccent
                                : Colors.white.withOpacity(.09),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.emoji_events,
                                color: Colors.amberAccent, size: 34),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MakeChessLocalizedText(
                                      '${t['name'] ?? MakeChessLocalization.phrase('Турнир')}',
                                      style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 5),
                                  MakeChessLocalizedText(
                                    '${_type('${t['type'] ?? ''}')} • ${_format('${t['format'] ?? ''}')} • '
                                    '${t['minutes'] ?? 0}+${t['increment'] ?? 0} • '
                                    '${MakeChessLocalization.phrase(
                                      '{count}/{max} участников',
                                      params: <String, Object?>{
                                        'count': count,
                                        'max': t['maxParticipants'] ?? 0,
                                      },
                                    )}',
                                    style:
                                        const TextStyle(color: Colors.white54),
                                  ),
                                ],
                              ),
                            ),
                            // MAKECHESS_TOURNAMENT_TWO_BUTTONS_V7_20260817
                            // Просмотр турнира всегда доступен. Заявка на участие —
                            // отдельное действие для пользователя, который ещё не участвует.
                            if (current)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _openTournament(t),
                                    icon: const Icon(Icons.visibility_outlined),
                                    label: MakeChessLocalizedText(
                                      MakeChessLocalization.phrase(
                                        'Открыть турнир',
                                      ),
                                    ),
                                  ),
                                  if (!joined) ...[
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      onPressed: () => _requestParticipation(t),
                                      icon: const Icon(Icons.how_to_reg),
                                      label: MakeChessLocalizedText(
                                        MakeChessLocalization.phrase(
                                          'Принять участие',
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _type(String raw) => MakeChessLocalization.phrase(
        switch (raw) {
          'learning' => 'Учебный турнир',
          'open' => 'Открытый турнир OPEN',
          'interschool' => 'Межшкольный турнир',
          'simul' => 'Сеанс одновременной игры',
          'team' => 'Командная игра',
          'teamGrid' => 'Групповая игра',
          _ => 'Турнир',
        },
      );

  String _format(String raw) {
    final russian = switch (raw) {
      'roundRobin' => 'Круговая система',
      'swiss' => 'Швейцарская система',
      'knockout' => 'На выбывание',
      _ => raw,
    };
    return MakeChessLocalization.phrase(russian);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    for (final controller in _filterControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
