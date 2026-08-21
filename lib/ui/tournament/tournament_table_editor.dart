// MAKECHESS_REMAINING_UI_V6_20260807
// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
// MAKECHESS_BIG_LOCALIZATION_STAGE_V4_20260807
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/tournament_storage_service.dart';
import '../../services/tournament_presence_service.dart';
import 'tournament_pairing_control_dialog.dart';
import 'tournament_participant_picker_dialog.dart';
import '../../localization/makechess_localization.dart';

enum TournamentTableEditorResult {
  saved,
  published,
}

class TournamentTableEditorDialog extends StatefulWidget {
  const TournamentTableEditorDialog({
    super.key,
    required this.tournamentId,
    required this.initialName,
    required this.initialType,
    required this.initialStatus,
    required this.initialMinutes,
    required this.initialIncrement,
    required this.initialRounds,
    required this.initialParticipantNames,
    this.maxParticipants,
    this.previewMode = false,
    this.startInPreview = false,
    this.initialJudge,
    this.initialVenue,
    this.initialOrganizer,
    this.initialStart,
    this.initialEnd,
    this.initialAge,
    this.initialParticipantsData,
    this.initialResults,
    this.organizerMode = false,
    this.onCallTournament,
    this.onStartTournament,
    this.onPauseTournament,
    this.onFinishTournament,
    this.onParticipate,
    this.onAddParticipant,
  });

  final String tournamentId;
  final String initialName;
  final String initialType;
  final String initialStatus;
  final int initialMinutes;
  final int initialIncrement;
  final int initialRounds;
  final List<String> initialParticipantNames;
  final int? maxParticipants;
  final bool previewMode;
  final bool startInPreview;
  final String? initialJudge;
  final String? initialVenue;
  final String? initialOrganizer;
  final String? initialStart;
  final String? initialEnd;
  final String? initialAge;
  final List<Map<String, dynamic>>? initialParticipantsData;
  final Map<String, String>? initialResults;
  final bool organizerMode;
  final Future<void> Function()? onCallTournament;
  final Future<void> Function()? onStartTournament;
  final Future<void> Function()? onPauseTournament;
  final Future<void> Function()? onFinishTournament;
  final Future<void> Function()? onParticipate;
  final Future<Map<String, dynamic>?> Function(Set<String> excludedIds)?
      onAddParticipant;

  @override
  State<TournamentTableEditorDialog> createState() =>
      _TournamentTableEditorDialogState();
}

Future<TournamentTableEditorResult?> showTournamentTableEditor({
  required BuildContext context,
  required String tournamentId,
  required String initialName,
  required String initialType,
  required String initialStatus,
  required int initialMinutes,
  required int initialIncrement,
  required int initialRounds,
  required List<String> initialParticipantNames,
  int? maxParticipants,
  bool previewMode = false,
  bool startInPreview = false,
  String? initialJudge,
  String? initialVenue,
  String? initialOrganizer,
  String? initialStart,
  String? initialEnd,
  String? initialAge,
  List<Map<String, dynamic>>? initialParticipantsData,
  Map<String, String>? initialResults,
  bool organizerMode = false,
  Future<void> Function()? onCallTournament,
  Future<void> Function()? onStartTournament,
  Future<void> Function()? onPauseTournament,
  Future<void> Function()? onFinishTournament,
  Future<void> Function()? onParticipate,
  Future<Map<String, dynamic>?> Function(Set<String> excludedIds)?
      onAddParticipant,
}) {
  return showDialog<TournamentTableEditorResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => TournamentTableEditorDialog(
      tournamentId: tournamentId,
      initialName: initialName,
      initialType: initialType,
      initialStatus: initialStatus,
      initialMinutes: initialMinutes,
      initialIncrement: initialIncrement,
      initialRounds: initialRounds,
      initialParticipantNames: initialParticipantNames,
      maxParticipants: maxParticipants,
      previewMode: previewMode,
      startInPreview: startInPreview,
      initialJudge: initialJudge,
      initialVenue: initialVenue,
      initialOrganizer: initialOrganizer,
      initialStart: initialStart,
      initialEnd: initialEnd,
      initialAge: initialAge,
      initialParticipantsData: initialParticipantsData,
      initialResults: initialResults,
      organizerMode: organizerMode,
      onCallTournament: onCallTournament,
      onStartTournament: onStartTournament,
      onPauseTournament: onPauseTournament,
      onFinishTournament: onFinishTournament,
      onParticipate: onParticipate,
      onAddParticipant: onAddParticipant,
    ),
  );
}

class _EditableParticipant {
  _EditableParticipant({
    required this.id,
    required this.name,
    this.rating = 1200,
    this.school = '',
    this.flag = '🏳️',
    this.avatarUrl = '',
  });

  final String id;
  String name;
  int rating;
  String school;
  String flag;
  String avatarUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'rating': rating,
        'school': school,
        'flag': flag,
        'avatarUrl': avatarUrl,
      };

  factory _EditableParticipant.fromJson(Map<String, dynamic> json) {
    return _EditableParticipant(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? 'Участник'}',
      rating: (json['rating'] as num?)?.toInt() ?? 1200,
      school: '${json['school'] ?? ''}',
      flag: '${json['flag'] ?? '🏳️'}',
      avatarUrl: '${json['avatarUrl'] ?? ''}',
    );
  }
}

class _TournamentTableEditorDialogState
    extends State<TournamentTableEditorDialog> {
  static const Color _background = Color(0xFF07111B);
  static const Color _panel = Color(0xFF0C1824);
  static const Color _panel2 = Color(0xFF101F2D);
  static const Color _gold = Color(0xFFD8A73D);
  static const Color _blue = Color(0xFF29A9FF);
  static const Color _line = Color(0xFF2D4355);

  late final String _storageKey;
  bool _loading = true;
  bool _showPreview = false;
  RealtimeChannel? _presenceChannel;
  Set<String> _onlineParticipantIds = <String>{};

  final TextEditingController _nameCtl = TextEditingController();
  final TextEditingController _judgeCtl = TextEditingController();
  final TextEditingController _venueCtl = TextEditingController();
  final TextEditingController _organizerCtl = TextEditingController();
  final TextEditingController _startCtl = TextEditingController();
  final TextEditingController _endCtl = TextEditingController();
  final TextEditingController _minutesCtl = TextEditingController();
  final TextEditingController _incrementCtl = TextEditingController();
  final TextEditingController _roundsCtl = TextEditingController();
  final TextEditingController _ageCtl = TextEditingController();

  String _type = 'Круговая система';
  String _status = 'Шаблон';
  final List<_EditableParticipant> _participants = <_EditableParticipant>[];
  final Map<String, String> _results = <String, String>{};
  List<Map<String, dynamic>> _pairings = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _pairingSchedule = <Map<String, dynamic>>[];
  String _logoDataUrl = '';
  TournamentPairingSettings _pairingSettings =
      const TournamentPairingSettings();

  @override
  void initState() {
    super.initState();
    _storageKey = 'makechess_tournament_table_${widget.tournamentId}';
    _showPreview = widget.startInPreview;
    _setDefaults();
    _load();
    // Готовность должна быть видна всем участникам, включая режим просмотра
    // таблицы поверх игровой платформы. Этот канал только читает Presence и
    // не выводит зрителя из уже открытой игровой платформы.
    if (widget.tournamentId.trim().isNotEmpty) {
      _presenceChannel = TournamentPresenceService.observe(
        tournamentId: widget.tournamentId,
        onChanged: (userIds) {
          if (mounted) setState(() => _onlineParticipantIds = userIds);
        },
      );
    }
  }

  void _setDefaults() {
    _nameCtl.text = widget.initialName;
    _judgeCtl.text = widget.initialJudge ?? '';
    _venueCtl.text = widget.initialVenue ?? 'Онлайн • MakeChess';
    _organizerCtl.text = widget.initialOrganizer ?? 'MakeChess';
    _startCtl.text = widget.initialStart ?? _dateText(DateTime.now());
    _endCtl.text = widget.initialEnd ?? _dateText(DateTime.now());
    _minutesCtl.text = '${widget.initialMinutes}';
    _incrementCtl.text = '${widget.initialIncrement}';
    _roundsCtl.text = '${widget.initialRounds}';
    _ageCtl.text = widget.initialAge ?? 'Открытая категория';
    _type =
        widget.initialType.isEmpty ? 'Круговая система' : widget.initialType;
    _status = widget.initialStatus.isEmpty ? 'Шаблон' : widget.initialStatus;
    _participants.clear();
    if (widget.initialParticipantsData != null &&
        widget.initialParticipantsData!.isNotEmpty) {
      _participants.addAll(
        widget.initialParticipantsData!.map(
          (e) => _EditableParticipant.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    } else {
      for (var i = 0; i < widget.initialParticipantNames.length; i++) {
        _participants.add(
          _EditableParticipant(
            id: 'linked_${i + 1}',
            name: widget.initialParticipantNames[i],
            rating: 1200,
          ),
        );
      }
    }
    _results
      ..clear()
      ..addAll(widget.initialResults ?? const <String, String>{});
    _ensureParticipantSlots();
  }

  Future<void> _openParticipantPicker() async {
    if (_registeredParticipantCount >= (widget.maxParticipants ?? 999)) {
      _message('Достигнут максимальный лимит участников');
      return;
    }
    final excluded = _participants.map((participant) => participant.id).toSet();
    final selected = widget.onAddParticipant != null
        ? await widget.onAddParticipant!(excluded)
        : await showTournamentParticipantPickerDialog(
            context: context,
            excludedIds: excluded,
          );
    if (selected == null || !mounted) return;
    final participant = _EditableParticipant.fromJson(selected);
    if (_participants.any((item) => item.id == participant.id)) return;
    setState(() {
      final emptyIndex = _participants.indexWhere(_isEmptySlot);
      if (emptyIndex >= 0) {
        _participants[emptyIndex] = participant;
      } else {
        _participants.add(participant);
      }
      _ensureParticipantSlots();
    });
    await _save();
    final realParticipants =
        _participants.where((item) => !_isEmptySlot(item)).toList();
    await TournamentStorageService.instance.updateOwnedTournamentFields(
      widget.tournamentId,
      <String, dynamic>{
        'participantIds': realParticipants.map((item) => item.id).toList(),
        'participantNames': <String, String>{
          for (final item in realParticipants) item.id: item.name,
        },
      },
    );
  }

  bool _isEmptySlot(_EditableParticipant participant) =>
      participant.id.startsWith('empty_slot_');

  int get _registeredParticipantCount =>
      _participants.where((participant) => !_isEmptySlot(participant)).length;

  void _ensureParticipantSlots() {
    final requested = widget.maxParticipants ?? _participants.length;
    final capacity = requested.clamp(_participants.length, 128);
    var slotNumber = 1;
    while (_participants.length < capacity) {
      _participants.add(
        _EditableParticipant(
          id: 'empty_slot_${widget.tournamentId}_${slotNumber++}',
          name: '',
          rating: 1200,
        ),
      );
    }
  }

  String _dateText(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year}';
  }

  Future<void> _load() async {
    if (widget.previewMode) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      Map<String, dynamic>? local;
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) local = Map<String, dynamic>.from(decoded);
      }
      Map<String, dynamic>? map = local;
      final userId =
          (Supabase.instance.client.auth.currentUser?.id ?? '').trim();
      if (userId.isNotEmpty) {
        final migrationKey =
            'makechess_tournament_table_db_migrated_${userId}_${widget.tournamentId}';
        final remote = await TournamentStorageService.instance
            .loadTournamentTable(widget.tournamentId);
        if (prefs.getBool(migrationKey) != true) {
          map = local ?? remote;
          if (map != null) {
            await TournamentStorageService.instance
                .saveTournamentTable(widget.tournamentId, map);
          }
          await prefs.setBool(migrationKey, true);
        } else {
          map = remote ?? local;
        }
      }
      if (map != null) {
        _nameCtl.text = '${map['name'] ?? _nameCtl.text}';
        _judgeCtl.text = '${map['judge'] ?? ''}';
        _venueCtl.text = '${map['venue'] ?? _venueCtl.text}';
        _organizerCtl.text = '${map['organizer'] ?? _organizerCtl.text}';
        _startCtl.text = '${map['start'] ?? _startCtl.text}';
        _endCtl.text = '${map['end'] ?? _endCtl.text}';
        _minutesCtl.text = '${map['minutes'] ?? _minutesCtl.text}';
        _incrementCtl.text = '${map['increment'] ?? _incrementCtl.text}';
        _roundsCtl.text = '${map['rounds'] ?? _roundsCtl.text}';
        _ageCtl.text = '${map['age'] ?? _ageCtl.text}';
        _type = '${map['type'] ?? _type}';
        _status = '${map['status'] ?? _status}';
        _logoDataUrl = '${map['logo'] ?? _logoDataUrl}';
        final people = map['participants'];
        if (people is List) {
          _participants
            ..clear()
            ..addAll(
              people.whereType<Map>().map(
                    (e) => _EditableParticipant.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  ),
            );
        }
        final results = map['results'];
        if (results is Map) {
          _results
            ..clear()
            ..addAll(
              results.map(
                (key, value) => MapEntry('$key', '$value'),
              ),
            );
        }
        final pairingSettings = map['pairingSettings'];
        if (pairingSettings is Map) {
          _pairingSettings = TournamentPairingSettings.fromJson(
            Map<String, dynamic>.from(pairingSettings),
          );
        }
        final pairings = map['pairings'];
        if (pairings is List) {
          _pairings = pairings
              .whereType<Map>()
              .map((pairing) => Map<String, dynamic>.from(pairing))
              .toList(growable: false);
        }
        final pairingSchedule = map['pairingSchedule'];
        if (pairingSchedule is List) {
          _pairingSchedule = pairingSchedule
              .whereType<Map>()
              .map((pairing) => Map<String, dynamic>.from(pairing))
              .toList(growable: false);
        }
      }
      _ensureParticipantSlots();
    } catch (_) {
      // Повреждённое локальное сохранение не блокирует редактор.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (widget.previewMode) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: MakeChessLocalizedText(
              'Это пример готовой таблицы. Сохранение отключено.'),
        ),
      );
      return;
    }
    final data = <String, dynamic>{
      'name': _nameCtl.text.trim(),
      'judge': _judgeCtl.text.trim(),
      'venue': _venueCtl.text.trim(),
      'organizer': _organizerCtl.text.trim(),
      'start': _startCtl.text.trim(),
      'end': _endCtl.text.trim(),
      'minutes': _minutesCtl.text.trim(),
      'increment': _incrementCtl.text.trim(),
      'rounds': _roundsCtl.text.trim(),
      'age': _ageCtl.text.trim(),
      'type': _type,
      'status': _status,
      'maxParticipants': widget.maxParticipants ?? _participants.length,
      'logo': _logoDataUrl,
      'participants': _participants
          .where((participant) => !_isEmptySlot(participant))
          .map((participant) => participant.toJson())
          .toList(),
      'results': _results,
      'pairingSettings': _pairingSettings.toJson(),
      'pairings': _pairings,
      'pairingSchedule': _pairingSchedule,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(data));
    await TournamentStorageService.instance
        .saveTournamentTable(widget.tournamentId, data);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: MakeChessLocalizedText('Таблица турнира сохранена')),
    );
  }

  Future<void> _saveAndClose(TournamentTableEditorResult result) async {
    await _save();
    if (!mounted) return;
    Navigator.pop(context, result);
  }

  Future<void> _openPairingControl() async {
    if (widget.previewMode && !widget.organizerMode) {
      _message('Управление жеребьёвкой доступно организатору турнира');
      return;
    }
    final result = await showTournamentPairingControlDialog(
      context: context,
      initialSettings: _pairingSettings,
      participantCount: _registeredParticipantCount,
      onSettingsChanged: (settings) {
        if (mounted) setState(() => _pairingSettings = settings);
      },
      onAction: _handlePairingAction,
    );
    if (result == null || !mounted) return;
    setState(() => _pairingSettings = result.settings);
    await _save();
    if (!mounted) return;
    _message('Режим жеребьёвки сохранён: ${result.settings.mode.label}');
  }

  Future<void> _handlePairingAction(
    TournamentPairingSettings settings,
    TournamentPairingAction action,
  ) async {
    if (!mounted) return;
    setState(() => _pairingSettings = settings);
    switch (action) {
      case TournamentPairingAction.save:
        await _save();
      case TournamentPairingAction.generateAutomatically:
        await _generateAutomaticPairings();
      case TournamentPairingAction.startRound:
        _message('Запрошен ручной старт тура');
      case TournamentPairingAction.finishRound:
        _message('Запрошено ручное завершение тура');
      case TournamentPairingAction.nextRound:
        _message('Запрошен переход к следующему туру');
      case TournamentPairingAction.editManually:
        _message('Открыт ручной режим составления пар');
    }
  }

  Future<void> _generateAutomaticPairings() async {
    final players = _participants
        .where((participant) =>
            !_isEmptySlot(participant) && participant.id.trim().isNotEmpty)
        .toList(growable: false);
    if (players.length < 2) {
      _message('Для жеребьёвки нужны минимум два участника');
      return;
    }

    final ordered = players.toList();
    if (_pairingSettings.useRating) {
      ordered.sort((a, b) => b.rating.compareTo(a.rating));
    } else {
      ordered.shuffle(math.Random());
    }

    final rotation = <_EditableParticipant?>[...ordered];
    if (rotation.length.isOdd) rotation.add(null);
    final roundsPerCycle = rotation.length - 1;
    final schedule = <Map<String, dynamic>>[];
    final colorBalance = <String, int>{
      for (final player in ordered) player.id: 0
    };

    for (var cycle = 0; cycle < _pairingSettings.cycles; cycle++) {
      final roundPlayers = rotation.toList();
      for (var round = 0; round < roundsPerCycle; round++) {
        final basePairs = <(_EditableParticipant?, _EditableParticipant?)>[];
        for (var board = 0; board < roundPlayers.length ~/ 2; board++) {
          basePairs.add((
            roundPlayers[board],
            roundPlayers[roundPlayers.length - 1 - board],
          ));
        }
        for (var game = 0; game < _pairingSettings.gamesPerOpponent; game++) {
          var boardNumber = 1;
          for (final pair in basePairs) {
            var first = pair.$1;
            var second = pair.$2;
            if (first == null && second == null) continue;
            first ??= second;
            second = pair.$1 == null ? null : second;

            var swap = false;
            if (second != null) {
              switch (_pairingSettings.colorOrder) {
                case TournamentColorOrder.alternateEveryGame:
                  swap = (game + cycle).isOdd;
                case TournamentColorOrder.reverseEveryCycle:
                  swap = cycle.isOdd;
                case TournamentColorOrder.automaticBalance:
                  final firstBalance = colorBalance[first!.id] ?? 0;
                  final secondBalance = colorBalance[second.id] ?? 0;
                  swap = firstBalance > secondBalance ||
                      (firstBalance == secondBalance &&
                          (round + boardNumber + game + cycle).isEven);
              }
            }
            final white = swap && second != null ? second : first!;
            final black = swap && second != null ? first : second;
            if (black != null) {
              colorBalance[white.id] = (colorBalance[white.id] ?? 0) + 1;
              colorBalance[black.id] = (colorBalance[black.id] ?? 0) - 1;
            }
            schedule.add(<String, dynamic>{
              'cycle': cycle + 1,
              'round': round + 1,
              'gameInMatch': game + 1,
              'board': boardNumber++,
              'whiteId': white.id,
              'blackId': black?.id,
              'result': black == null ? '1-0' : '*',
              'resultReason': black == null ? 'bye' : '',
              'status': black == null ? 'finished' : 'waiting',
            });
          }
        }
        final fixed = roundPlayers.first;
        final tail = roundPlayers.sublist(1);
        tail.insert(0, tail.removeLast());
        roundPlayers
          ..clear()
          ..add(fixed)
          ..addAll(tail);
      }
    }

    final generated = schedule
        .where((pairing) =>
            pairing['cycle'] == 1 &&
            pairing['round'] == 1 &&
            pairing['gameInMatch'] == 1)
        .map((pairing) => Map<String, dynamic>.from(pairing))
        .toList(growable: false);

    setState(() {
      _pairingSchedule = schedule;
      _pairings = generated;
    });
    await TournamentStorageService.instance.updateOwnedTournamentFields(
      widget.tournamentId,
      <String, dynamic>{
        'pairings': generated,
        'pairingSchedule': schedule,
        'currentRound': 1,
        'currentCycle': 1,
        'currentMatchGame': 1,
        'status': 'ready',
        'pairingSettings': _pairingSettings.toJson(),
      },
    );
    await _save();
    if (!mounted) return;
    _message(
      'Расписание создано: ${_pairingSettings.cycles} кругов, '
      '${_pairingSettings.gamesPerOpponent} партий с соперником',
    );
  }

  String _resultKey(int row, int column) => '$row:$column';

  double _pointsFor(int row) {
    var result = 0.0;
    for (var column = 0; column < _participants.length; column++) {
      if (row == column) continue;
      final value = _results[_resultKey(row, column)];
      if (value == '1') result += 1;
      if (value == '½') result += 0.5;
    }
    return result;
  }

  double _buchholzFor(int row) {
    var result = 0.0;
    for (var column = 0; column < _participants.length; column++) {
      if (row == column) continue;
      if (_results[_resultKey(row, column)] != null) {
        result += _pointsFor(column);
      }
    }
    return result;
  }

  double _bergerFor(int row) {
    var result = 0.0;
    for (var column = 0; column < _participants.length; column++) {
      if (row == column) continue;
      final value = _results[_resultKey(row, column)];
      if (value == '1') result += _pointsFor(column);
      if (value == '½') result += _pointsFor(column) / 2;
    }
    return result;
  }

  int _placeFor(int row) {
    final order = List<int>.generate(_participants.length, (i) => i)
      ..sort((a, b) {
        final points = _pointsFor(b).compareTo(_pointsFor(a));
        if (points != 0) return points;
        final buchholz = _buchholzFor(b).compareTo(_buchholzFor(a));
        if (buchholz != 0) return buchholz;
        final berger = _bergerFor(b).compareTo(_bergerFor(a));
        if (berger != 0) return berger;
        return _participants[b].rating.compareTo(_participants[a].rating);
      });
    return order.indexOf(row) + 1;
  }

  String _scoreText(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return '${value.floor()}½';
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected != null) setState(() => controller.text = _dateText(selected));
  }

  Future<void> _pickLogoFromFile() async {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();
    await input.onChange.first;
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) return;
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    await reader.onLoad.first;
    final result = reader.result;
    if (!mounted) return;
    setState(() {
      _logoDataUrl = result is String ? result : '';
    });
  }

  Widget _buildLogoBadge({double size = 196, bool editable = false}) {
    final hasLogo = _logoDataUrl.trim().isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF102235), Color(0xFF07111B)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 1),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: hasLogo
                  ? Image.network(_logoDataUrl, fit: BoxFit.cover)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.emoji_events, size: 76, color: _gold),
                        SizedBox(height: 10),
                        MakeChessLocalizedText(
                          'ЛЕЙБЛ ТУРНИРА',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (editable)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xCC0D5A91),
                  foregroundColor: Colors.white,
                ),
                onPressed: _pickLogoFromFile,
                icon: const Icon(Icons.folder_open),
                label: MakeChessLocalizedText(
                    hasLogo ? 'Сменить логотип' : 'Выбрать логотип'),
              ),
            ),
        ],
      ),
    );
  }

  void _addParticipant() {
    setState(() {
      _participants.add(
        _EditableParticipant(
          id: 'manual_${DateTime.now().microsecondsSinceEpoch}',
          name: 'Новый участник',
          rating: 1200,
        ),
      );
    });
  }

  void _removeParticipant(int index) {
    setState(() {
      _participants.removeAt(index);
      _results.clear();
    });
  }

  Future<void> _editParticipant(int index) async {
    final person = _participants[index];
    final name = TextEditingController(text: person.name);
    final rating = TextEditingController(text: '${person.rating}');
    final school = TextEditingController(text: person.school);
    final flag = TextEditingController(text: person.flag);
    final avatar = TextEditingController(text: person.avatarUrl);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel2,
        title: const MakeChessLocalizedText('Редактировать участника'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(name, 'Имя участника'),
                _dialogField(rating, 'Рейтинг', numeric: true),
                _dialogField(school, 'Школа / клуб'),
                _dialogField(flag, 'Флаг: символ или эмодзи'),
                _dialogField(avatar, 'Ссылка на фотографию'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const MakeChessLocalizedText('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const MakeChessLocalizedText('Применить'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      setState(() {
        person.name = name.text.trim().isEmpty ? 'Участник' : name.text.trim();
        person.rating = int.tryParse(rating.text.trim()) ?? 1200;
        person.school = school.text.trim();
        person.flag = flag.text.trim().isEmpty ? '🏳️' : flag.text.trim();
        person.avatarUrl = avatar.text.trim();
      });
    }
    name.dispose();
    rating.dispose();
    school.dispose();
    flag.dispose();
    avatar.dispose();
  }

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    bool numeric = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: Colors.white),
        decoration: _decoration(label),
      ),
    );
  }

  InputDecoration _decoration(String label, {Widget? suffix}) {
    return InputDecoration(
      labelText: MakeChessLocalization.phrase(label),
      labelStyle: const TextStyle(color: Colors.white60),
      filled: true,
      fillColor: const Color(0xFF0A1520),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: Color(0xFF6A5223)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: _gold, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.transparent,
      child: Container(
        width: mathMin(1540, size.width - 24),
        height: mathMin(930, size.height - 24),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _gold.withOpacity(0.6)),
          boxShadow: const [
            BoxShadow(color: Colors.black87, blurRadius: 32, spreadRadius: 4),
          ],
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: (widget.previewMode || _showPreview)
                          ? _buildPublicationPreview()
                          : Column(
                              children: [
                                _buildHeaderEditor(),
                                const SizedBox(height: 14),
                                _buildTable(),
                                const SizedBox(height: 14),
                                _buildActions(),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  double mathMin(num a, num b) => a < b ? a.toDouble() : b.toDouble();

  Widget _buildTopBar() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0A1520),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(bottom: BorderSide(color: Color(0xFF4A381B))),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: _gold),
          const SizedBox(width: 10),
          MakeChessLocalizedText(
            widget.previewMode
                ? 'Посмотреть пример таблицы'
                : _showPreview
                    ? 'Предпросмотр турнира'
                    : 'Открыть таблицу турнира',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          MakeChessLocalizedText(
            widget.previewMode
                ? 'Публикационный вид: красивый финальный дизайн'
                : _showPreview
                    ? 'Проверьте результат перед публикацией'
                    : 'Все поля доступны для редактирования',
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: MakeChessLocalization.phrase('Закрыть'),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderEditor() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withOpacity(0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogoBadge(size: 205, editable: true),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _field(_nameCtl, 'Название турнира')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dropdown(
                        'Тип турнира',
                        _type,
                        const [
                          'Круговая система',
                          'Швейцарская система',
                          'На выбывание',
                          'Командный турнир',
                          'Сеанс одновременной игры',
                          'Турнир 2×2 / 4×4',
                        ],
                        (value) => setState(() => _type = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dropdown(
                        'Статус',
                        _status,
                        const [
                          'Шаблон',
                          'Черновик',
                          'Регистрация открыта',
                          'Готов к запуску',
                          'Идёт',
                          'Приостановлен',
                          'Завершён',
                        ],
                        (value) => setState(() => _status = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _field(_judgeCtl, 'Судья')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dateField(_startCtl, 'Дата начала'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dateField(_endCtl, 'Дата окончания'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _field(_venueCtl, 'Место проведения')),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_organizerCtl, 'Организатор')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _field(_minutesCtl, 'Минут', numeric: true),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _field(
                        _incrementCtl,
                        'Добавление, сек.',
                        numeric: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child:
                          _field(_roundsCtl, 'Количество туров', numeric: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_ageCtl, 'Возрастная категория')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicationPreview() {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 1280;
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 28,
        compact ? 16 : 24,
        compact ? 16 : 28,
        20,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF06101A), Color(0xFF081522), Color(0xFF040A11)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withOpacity(0.72)),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 28, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          _buildPublicationHeader(compact: compact),
          const SizedBox(height: 20),
          if (_pairings.isNotEmpty) ...[
            _buildPairingsSummary(),
            const SizedBox(height: 14),
          ],
          _buildPublicationTable(),
          const SizedBox(height: 20),
          Row(
            children: [
              if (!widget.previewMode) ...[
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showPreview = false),
                  icon: const Icon(Icons.edit_outlined),
                  label: const MakeChessLocalizedText('Редактировать данные'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const MakeChessLocalizedText('Сохранить'),
                ),
                if (!widget.previewMode) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: widget.onCallTournament,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const MakeChessLocalizedText('Вызвать на турнир'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF167C4D),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: widget.onStartTournament,
                    icon: const Icon(Icons.play_arrow),
                    label: const MakeChessLocalizedText('Начать турнир'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: widget.onPauseTournament,
                    icon: const Icon(Icons.pause),
                    label: const MakeChessLocalizedText('Приостановить'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: widget.onFinishTournament,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const MakeChessLocalizedText('Закончить'),
                  ),
                ],
              ],
              if (widget.onParticipate != null) ...[
                FilledButton.icon(
                  onPressed: widget.onParticipate,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const MakeChessLocalizedText('Участвовать в турнире'),
                ),
                const SizedBox(width: 10),
              ],
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0B4F82),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side:
                        const BorderSide(color: Color(0xFF28A9FF), width: 1.5),
                  ),
                  elevation: 10,
                  shadowColor: const Color(0xFF28A9FF),
                ),
                onPressed: _openPairingControl,
                icon: const Icon(Icons.casino, size: 22),
                label: const MakeChessLocalizedText(
                  'ЖЕРЕБЬЁВКА',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (widget.organizerMode && !widget.previewMode) ...[
                FilledButton.icon(
                  onPressed: _openParticipantPicker,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const MakeChessLocalizedText('Добавить участника'),
                ),
                const SizedBox(width: 10),
              ],
              OutlinedButton.icon(
                onPressed: () => _message('Печать будет подключена отдельно'),
                icon: const Icon(Icons.print_outlined),
                label: const MakeChessLocalizedText('Печать'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPublicationHeader({required bool compact}) {
    final logo = _buildPublicationLogo(compact ? 188 : 224);
    final information = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 2),
          MakeChessLocalizedText(
            _nameCtl.text.trim().isEmpty
                ? 'НАЗВАНИЕ ТУРНИРА'
                : _nameCtl.text.trim().toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFFF4F3EF),
              fontFamily: 'Georgia',
              fontSize: compact ? 36 : 54,
              height: 0.95,
              fontWeight: FontWeight.w800,
              letterSpacing: compact ? 1.6 : 2.6,
              shadows: const [
                Shadow(
                    color: Colors.black, blurRadius: 12, offset: Offset(0, 3)),
                Shadow(color: Color(0xFF67562D), blurRadius: 2),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                  child: Divider(color: Color(0xFF87652A), height: 1)),
              const SizedBox(width: 12),
              const Icon(Icons.workspace_premium, color: _gold, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                  child: Divider(color: Color(0xFF87652A), height: 1)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _publicationLine(Icons.sync, 'Тип турнира', _type),
                    _publicationLine(
                      Icons.person,
                      'Судья',
                      _judgeCtl.text.trim().isEmpty
                          ? 'Не указан'
                          : _judgeCtl.text.trim(),
                    ),
                    _publicationLine(
                      Icons.place,
                      'Место проведения',
                      _venueCtl.text.trim().isEmpty
                          ? 'Не указано'
                          : _venueCtl.text.trim(),
                    ),
                    _publicationLine(
                      Icons.calendar_month,
                      'Начало',
                      _startCtl.text.trim(),
                    ),
                    _publicationLine(
                      Icons.event_available,
                      'Окончание',
                      _endCtl.text.trim(),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: compact ? 168 : 186,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                color: const Color(0xFF87652A),
              ),
              Expanded(
                child: Column(
                  children: [
                    _publicationLine(
                      Icons.schedule,
                      'Контроль времени',
                      '${_minutesCtl.text.trim()}+${_incrementCtl.text.trim()}',
                    ),
                    _publicationLine(
                      Icons.groups,
                      'Участников',
                      '$_registeredParticipantCount',
                    ),
                    _publicationLine(Icons.verified, 'Статус', _status),
                    const SizedBox(height: 7),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFF87652A)),
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MakeChessLocalizedText(
                            'КРИТЕРИИ ОПРЕДЕЛЕНИЯ МЕСТ',
                            style: TextStyle(
                              color: _gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(height: 5),
                          MakeChessLocalizedText(
                            '1. Очки   2. Бухгольц   3. Бергер   4. Личный результат',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (compact) {
      return Column(
        children: [
          logo,
          const SizedBox(height: 16),
          information,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        logo,
        const SizedBox(width: 28),
        information,
      ],
    );
  }

  Widget _buildPublicationLogo(double size) {
    final hasLogo = _logoDataUrl.trim().isNotEmpty;
    if (hasLogo) {
      return Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _gold, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black87, blurRadius: 22, spreadRadius: 2),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(_logoDataUrl, fit: BoxFit.cover),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipPath(
            clipper: _TournamentShieldClipper(),
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF4D27B), Color(0xFFA86C17)],
                ),
              ),
            ),
          ),
          ClipPath(
            clipper: _TournamentShieldClipper(),
            child: Container(
              width: size - 12,
              height: size - 12,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF132941), Color(0xFF07111B)],
                ),
              ),
            ),
          ),
          Positioned(
            top: size * 0.18,
            child: Icon(
              Icons.emoji_events,
              size: size * 0.38,
              color: const Color(0xFFE8B64E),
            ),
          ),
          Positioned(
            bottom: size * 0.24,
            left: size * 0.08,
            right: size * 0.08,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1A2A),
                border: Border.all(color: _gold, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black87, blurRadius: 8),
                ],
              ),
              child: MakeChessLocalizedText(
                _nameCtl.text.trim().isEmpty
                    ? 'ТУРНИР'
                    : _nameCtl.text.trim().toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Georgia',
                  fontSize: size * 0.075,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: size * 0.08,
            child: Icon(
              Icons.extension,
              size: size * 0.12,
              color: const Color(0xFFD9A23B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _publicationLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: _gold),
          const SizedBox(width: 10),
          SizedBox(
            width: 138,
            child: MakeChessLocalizedText(
              '$label:',
              style: const TextStyle(
                color: _gold,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: MakeChessLocalizedText(
              value.isEmpty ? '—' : value,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicationTable() {
    final count = _participants.length;
    final matrixWidth = count * 48.0;
    final totalWidth =
        50 + 210 + 78 + 170 + 72 + matrixWidth + 72 + 76 * 3 + 64;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCC07121D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF31506A), width: 1.2),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Column(
            children: [
              Container(
                height: 50,
                decoration: const BoxDecoration(
                  color: Color(0xFF0D1F30),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                  border: Border(bottom: BorderSide(color: _line)),
                ),
                child: Row(
                  children: [
                    _prettyHead('№', 50),
                    _prettyHead('Участник', 210),
                    _prettyHead('Рейтинг', 78),
                    _prettyHead('Готов', 72),
                    _prettyHead('Школа / клуб', 170),
                    for (var i = 0; i < count; i++) _prettyHead('${i + 1}', 48),
                    _prettyHead('Очки', 72),
                    _prettyHead('Бухг.', 76),
                    _prettyHead('Бергер', 76),
                    _prettyHead('Личн.', 76),
                    _prettyHead('Место', 64),
                  ],
                ),
              ),
              for (var row = 0; row < count; row++) _prettyParticipantRow(row),
            ],
          ),
        ),
      ),
    );
  }

  String _pairingParticipantName(String? id) {
    if (id == null || id.trim().isEmpty) return 'Свободен';
    for (final participant in _participants) {
      if (participant.id == id) {
        return participant.name.trim().isEmpty ? id : participant.name;
      }
    }
    return id;
  }

  Widget _buildPairingsSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xCC0D1F30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blue.withOpacity(.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shuffle, color: Colors.lightBlueAccent),
              const SizedBox(width: 8),
              MakeChessLocalizedText(
                'Результат жеребьёвки • ${_pairingSettings.mode.label}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: _pairings.map((pairing) {
              final board = pairing['board'] ?? '—';
              final white = _pairingParticipantName('${pairing['whiteId']}');
              final rawBlack = pairing['blackId'];
              final black = rawBlack == null
                  ? 'Свободен'
                  : _pairingParticipantName('$rawBlack');
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.045),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: MakeChessLocalizedText(
                  'Стол $board: $white — $black',
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _prettyHead(String text, double width) {
    return Container(
      width: width,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: _line)),
      ),
      child: MakeChessLocalizedText(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _prettyParticipantRow(int row) {
    final person = _participants[row];
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: row.isEven ? const Color(0xAA081520) : const Color(0xCC0A1926),
        border: const Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          _prettyCell(
            50,
            MakeChessLocalizedText(
              '${row + 1}',
              style: const TextStyle(
                color: _blue,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          _prettyCell(
            210,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _avatar(person),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MakeChessLocalizedText(
                      person.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _prettyCell(
            78,
            MakeChessLocalizedText(
              '${person.rating}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          _prettyCell(
            72,
            Icon(
              _onlineParticipantIds.contains(person.id)
                  ? Icons.check_circle
                  : Icons.cancel,
              color: _onlineParticipantIds.contains(person.id)
                  ? Colors.greenAccent
                  : Colors.redAccent,
              size: 23,
            ),
          ),
          _prettyCell(
            170,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: MakeChessLocalizedText(
                person.school.isEmpty ? '—' : person.school,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.15,
                ),
              ),
            ),
          ),
          for (var column = 0; column < _participants.length; column++)
            _prettyResultCell(row, column),
          _prettyCell(
            72,
            MakeChessLocalizedText(
              _scoreText(_pointsFor(row)),
              style: const TextStyle(
                color: _blue,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _prettyCell(
              76, MakeChessLocalizedText(_buchholzFor(row).toStringAsFixed(1))),
          _prettyCell(
              76, MakeChessLocalizedText(_bergerFor(row).toStringAsFixed(2))),
          _prettyCell(76, const MakeChessLocalizedText('—')),
          _prettyCell(
            64,
            MakeChessLocalizedText(
              '${_placeFor(row)}',
              style: const TextStyle(
                color: _blue,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _prettyResultCell(int row, int column) {
    if (row == column) {
      return _prettyCell(
        48,
        const MakeChessLocalizedText('×',
            style: TextStyle(color: Colors.white30, fontSize: 18)),
        background: const Color(0xFF1A2A38),
      );
    }
    final value = _results[_resultKey(row, column)] ?? '—';
    return _prettyCell(
      48,
      MakeChessLocalizedText(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _prettyCell(double width, Widget child, {Color? background}) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        border: const Border(right: BorderSide(color: _line)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white70, fontSize: 13),
        child: child,
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool numeric = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(label),
    );
  }

  Widget _dateField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickDate(controller),
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(
        label,
        suffix: IconButton(
          onPressed: () => _pickDate(controller),
          icon: const Icon(Icons.calendar_month, color: _gold),
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> onChanged,
  ) {
    final safeValue = values.contains(value) ? value : values.first;
    return DropdownButtonFormField<String>(
      value: safeValue,
      dropdownColor: _panel2,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(label),
      items: values
          .map((e) => DropdownMenuItem<String>(
              value: e, child: MakeChessLocalizedText(e)))
          .toList(),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  Widget _buildTable() {
    final count = _participants.length;
    final matrixWidth = count * 54.0;
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blue.withOpacity(0.45)),
      ),
      child: Column(
        children: [
          Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 84 + 260 + 92 + 230 + matrixWidth + 92 + 105 * 3 + 82,
                child: Column(
                  children: [
                    _tableHeader(count),
                    for (var row = 0; row < count; row++) _participantRow(row),
                  ],
                ),
              ),
            ),
          ),
          InkWell(
            onTap: _addParticipant,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _line)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_circle_outline, color: _gold),
                  SizedBox(width: 9),
                  MakeChessLocalizedText(
                    'Добавить участника',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 8),
                  MakeChessLocalizedText(
                    'ручной ввод',
                    style: TextStyle(color: Colors.white38),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(int count) {
    return Container(
      height: 54,
      decoration: const BoxDecoration(
        color: Color(0xFF122231),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          _head('№', 84),
          _head('Участник', 260),
          _head('Рейтинг', 92),
          _head('Школа / клуб', 230),
          for (var i = 0; i < count; i++) _head('${i + 1}', 54),
          _head('Очки', 92),
          _head('Бухг.', 105),
          _head('Бергер', 105),
          _head('Личн.', 105),
          _head('Место', 82),
        ],
      ),
    );
  }

  Widget _head(String text, double width) {
    return Container(
      width: width,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: _line)),
      ),
      child: MakeChessLocalizedText(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _participantRow(int row) {
    final person = _participants[row];
    return Container(
      height: 66,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          _cell(
            84,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MakeChessLocalizedText(
                  '${row + 1}',
                  style: const TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 3),
                PopupMenuButton<String>(
                  tooltip: MakeChessLocalization.phrase('Действия'),
                  color: _panel2,
                  icon: const Icon(Icons.more_vert,
                      size: 18, color: Colors.white38),
                  onSelected: (value) {
                    if (value == 'edit') _editParticipant(row);
                    if (value == 'delete') _removeParticipant(row);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'edit',
                        child: MakeChessLocalizedText('Редактировать')),
                    PopupMenuItem(
                        value: 'delete',
                        child: MakeChessLocalizedText('Удалить')),
                  ],
                ),
              ],
            ),
          ),
          _cell(
            260,
            InkWell(
              onTap: () => _editParticipant(row),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    _avatar(person),
                    const SizedBox(width: 9),
                    Expanded(
                      child: MakeChessLocalizedText(
                        person.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const Icon(Icons.edit, size: 15, color: Colors.white30),
                  ],
                ),
              ),
            ),
          ),
          _cell(
            92,
            TextFormField(
              initialValue: '${person.rating}',
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
              decoration: _tableInputDecoration(),
              onChanged: (value) {
                person.rating = int.tryParse(value) ?? person.rating;
                setState(() {});
              },
            ),
          ),
          _cell(
            230,
            TextFormField(
              initialValue: person.school,
              style: const TextStyle(color: Colors.white),
              decoration: _tableInputDecoration(hint: 'Школа или клуб'),
              onChanged: (value) => person.school = value,
            ),
          ),
          for (var column = 0; column < _participants.length; column++)
            _resultCell(row, column),
          _cell(
            92,
            MakeChessLocalizedText(
              _scoreText(_pointsFor(row)),
              style: const TextStyle(
                color: _blue,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _cell(105,
              MakeChessLocalizedText(_buchholzFor(row).toStringAsFixed(2))),
          _cell(
              105, MakeChessLocalizedText(_bergerFor(row).toStringAsFixed(2))),
          _cell(105, const MakeChessLocalizedText('—')),
          _cell(
            82,
            MakeChessLocalizedText(
              '${_placeFor(row)}',
              style: const TextStyle(
                color: _blue,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _tableInputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint == null ? null : MakeChessLocalization.phrase(hint),
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFF0A1520),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: Color(0xFF31485A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: _gold),
      ),
    );
  }

  Widget _avatar(_EditableParticipant person) {
    final initials = person.name.trim().isEmpty
        ? '?'
        : person.name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((e) => e[0])
            .join();
    return SizedBox(
      width: 47,
      height: 47,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: const Color(0xFF263B4C),
            backgroundImage: person.avatarUrl.trim().isEmpty
                ? null
                : NetworkImage(person.avatarUrl.trim()),
            child: person.avatarUrl.trim().isEmpty
                ? MakeChessLocalizedText(
                    initials.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _panel2,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70),
              ),
              child: MakeChessLocalizedText(person.flag,
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCell(int row, int column) {
    if (row == column) {
      return _cell(
        54,
        const MakeChessLocalizedText(
          '×',
          style: TextStyle(color: Colors.white30, fontSize: 20),
        ),
        background: const Color(0xFF1B2A38),
      );
    }
    final key = _resultKey(row, column);
    final value = _results[key];
    return _cell(
      54,
      DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isDense: true,
          dropdownColor: _panel2,
          hint: const MakeChessLocalizedText('—',
              style: TextStyle(color: Colors.white30)),
          icon: const Icon(Icons.arrow_drop_down,
              color: Colors.white38, size: 18),
          items: const [
            DropdownMenuItem<String?>(
                value: null, child: MakeChessLocalizedText('—')),
            DropdownMenuItem<String?>(
                value: '1', child: MakeChessLocalizedText('1')),
            DropdownMenuItem<String?>(
                value: '½', child: MakeChessLocalizedText('½')),
            DropdownMenuItem<String?>(
                value: '0', child: MakeChessLocalizedText('0')),
          ],
          onChanged: (next) {
            setState(() {
              if (next == null) {
                _results.remove(key);
              } else {
                _results[key] = next;
                final opposite = _resultKey(column, row);
                _results[opposite] = next == '1'
                    ? '0'
                    : next == '0'
                        ? '1'
                        : '½';
              }
            });
          },
        ),
      ),
    );
  }

  Widget _cell(
    double width,
    Widget child, {
    Color? background,
  }) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: background,
        border: const Border(right: BorderSide(color: _line)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white70),
        child: child,
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: () {
            if (!widget.previewMode && _showPreview) {
              setState(() => _showPreview = false);
              return;
            }
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back),
          label: MakeChessLocalizedText(!widget.previewMode && _showPreview
              ? 'Вернуться к заполнению'
              : 'Назад'),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF80601C),
            foregroundColor: Colors.white,
          ),
          onPressed: () => _saveAndClose(TournamentTableEditorResult.saved),
          icon: const Icon(Icons.save),
          label: const MakeChessLocalizedText('Сохранить'),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF167C4D),
            foregroundColor: Colors.white,
          ),
          onPressed: () => _saveAndClose(TournamentTableEditorResult.published),
          icon: const Icon(Icons.publish),
          label: const MakeChessLocalizedText('Опубликовать'),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () => setState(() => _showPreview = true),
          icon: const Icon(Icons.visibility_outlined),
          label: const MakeChessLocalizedText('Предпросмотр'),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () {
            _message('Копирование шаблона будет подключено отдельно');
          },
          icon: const Icon(Icons.copy_all),
          label: const MakeChessLocalizedText('Сохранить как'),
        ),
        if (widget.onParticipate != null) ...[
          FilledButton.icon(
            onPressed: widget.onParticipate,
            icon: const Icon(Icons.person_add_alt_1),
            label: const MakeChessLocalizedText('Участвовать в турнире'),
          ),
          const SizedBox(width: 10),
        ],
        const Spacer(),
        if (!widget.previewMode) ...[
          OutlinedButton.icon(
            onPressed: widget.onCallTournament,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const MakeChessLocalizedText('Вызвать на турнир'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF167C4D),
              foregroundColor: Colors.white,
            ),
            onPressed: widget.onStartTournament,
            icon: const Icon(Icons.play_arrow),
            label: const MakeChessLocalizedText('Начать турнир'),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: widget.onPauseTournament,
            icon: const Icon(Icons.pause),
            label: const MakeChessLocalizedText('Приостановить'),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: widget.onFinishTournament,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const MakeChessLocalizedText('Закончить'),
          ),
          const SizedBox(width: 10),
        ],
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0D5A91),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 17),
          ),
          onPressed: _openPairingControl,
          icon: const Icon(Icons.casino),
          label: const MakeChessLocalizedText(
            'ЖЕРЕБЬЁВКА',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () => _message('Печать будет подключена отдельно'),
          icon: const Icon(Icons.print),
          label: const MakeChessLocalizedText('Печать'),
        ),
      ],
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: MakeChessLocalizedText(text)));
  }

  @override
  void dispose() {
    TournamentPresenceService.leave(_presenceChannel);
    _nameCtl.dispose();
    _judgeCtl.dispose();
    _venueCtl.dispose();
    _organizerCtl.dispose();
    _startCtl.dispose();
    _endCtl.dispose();
    _minutesCtl.dispose();
    _incrementCtl.dispose();
    _roundsCtl.dispose();
    _ageCtl.dispose();
    super.dispose();
  }
}

class _TournamentShieldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.5, 0);
    path.lineTo(size.width * 0.92, size.height * 0.14);
    path.lineTo(size.width * 0.88, size.height * 0.62);
    path.quadraticBezierTo(
      size.width * 0.78,
      size.height * 0.88,
      size.width * 0.5,
      size.height,
    );
    path.quadraticBezierTo(
      size.width * 0.22,
      size.height * 0.88,
      size.width * 0.12,
      size.height * 0.62,
    );
    path.lineTo(size.width * 0.08, size.height * 0.14);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
