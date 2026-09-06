// MAKECHESS_REMAINING_UI_V6_20260807
// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
// MAKECHESS_BIG_LOCALIZATION_STAGE_V4_20260807
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../dialogs/temporary_round_access_dialog.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/tournament_storage_service.dart';
import '../../platform/local_file_service.dart';
import '../../services/tournament_presence_service.dart';
import 'tournament_pairing_control_dialog.dart';
import 'tournament_participant_picker_dialog.dart';
import 'tournament_template_schema.dart';
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
    this.initialRated = false,
    this.initialParticipantsData,
    this.initialResults,
    this.organizerMode = false,
    this.onCallTournament,
    this.onStartTournament,
    this.onPauseTournament,
    this.onFinishTournament,
    this.onParticipate,
    this.onAddParticipant,
    this.templateSchema,
    this.templateValues = const <String, String>{},
    this.lockTournamentType = false,
    this.creatingNewTournament = false,
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
  final bool initialRated;
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
  final TournamentTemplateSchema? templateSchema;
  final Map<String, String> templateValues;
  final bool lockTournamentType;
  final bool creatingNewTournament;

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
  bool initialRated = false,
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
  TournamentTemplateSchema? templateSchema,
  Map<String, String> templateValues = const <String, String>{},
  bool lockTournamentType = false,
  bool creatingNewTournament = false,
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
      initialRated: initialRated,
      initialParticipantsData: initialParticipantsData,
      initialResults: initialResults,
      organizerMode: organizerMode,
      onCallTournament: onCallTournament,
      onStartTournament: onStartTournament,
      onPauseTournament: onPauseTournament,
      onFinishTournament: onFinishTournament,
      onParticipate: onParticipate,
      onAddParticipant: onAddParticipant,
      templateSchema: templateSchema,
      templateValues: templateValues,
      lockTournamentType: lockTournamentType,
      creatingNewTournament: creatingNewTournament,
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
    this.source = 'makechess',
    this.externalProfile = '',
    this.age,
    this.birthYear,
    this.title = '',
  });

  String id;
  String name;
  int rating;
  String school;
  String flag;
  String avatarUrl;
  String source;
  String externalProfile;
  int? age;
  int? birthYear;
  String title;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'rating': rating,
        'school': school,
        'flag': flag,
        'avatarUrl': avatarUrl,
        'source': source,
        'externalProfile': externalProfile,
        if (age != null) 'age': age,
        if (birthYear != null) 'birthYear': birthYear,
        'title': title,
      };

  factory _EditableParticipant.fromJson(Map<String, dynamic> json) {
    return _EditableParticipant(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? 'Участник'}',
      rating: (json['rating'] as num?)?.toInt() ?? 1200,
      school: '${json['school'] ?? ''}',
      flag: '${json['flag'] ?? '🏳️'}',
      avatarUrl: '${json['avatarUrl'] ?? ''}',
      source: '${json['source'] ?? 'makechess'}',
      externalProfile: '${json['externalProfile'] ?? ''}',
      age: (json['age'] as num?)?.toInt(),
      birthYear: (json['birthYear'] as num?)?.toInt(),
      title: '${json['title'] ?? json['chessTitle'] ?? ''}',
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
  final TextEditingController _minRatingCtl = TextEditingController();
  final TextEditingController _maxRatingCtl = TextEditingController();
  final TextEditingController _minAgeCtl = TextEditingController();
  final TextEditingController _maxAgeCtl = TextEditingController();
  final TextEditingController _birthYearFromCtl = TextEditingController();
  final TextEditingController _birthYearToCtl = TextEditingController();
  final Set<String> _allowedTitles = <String>{};
  static const List<String> _chessTitles = <String>[
    'Без звания',
    '3 разряд',
    '2 разряд',
    '1 разряд',
    'КМС',
    'МС',
    'ЖМ',
    'ММ',
    'ЖГМ',
    'ГМ',
  ];

  String _type = 'Круговая система';
  String _status = 'Шаблон';
  final List<_EditableParticipant> _participants = <_EditableParticipant>[];
  final Map<String, String> _results = <String, String>{};
  final List<String> _customColumns = <String>[];
  final Map<String, String> _customColumnValues = <String, String>{};
  final Map<String, String> _templateValues = <String, String>{};
  List<Map<String, dynamic>> _pairings = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _pairingSchedule = <Map<String, dynamic>>[];
  String _logoDataUrl = '';
  bool _rated = false;
  bool _offlineMode = false;
  TournamentPairingSettings _pairingSettings =
      const TournamentPairingSettings();
  bool _testMode = false;
  bool _pairingControlOpen = false;
  int _testRound = 0;
  String? _testOriginalStatus;
  List<_EditableParticipant>? _testOriginalParticipants;
  Map<String, String>? _testOriginalResults;
  List<Map<String, dynamic>>? _testOriginalPairings;
  List<Map<String, dynamic>>? _testOriginalSchedule;

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
    _templateValues
      ..clear()
      ..addAll(widget.templateValues);
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
    _minRatingCtl.clear();
    _maxRatingCtl.clear();
    _minAgeCtl.clear();
    _maxAgeCtl.clear();
    _birthYearFromCtl.clear();
    _birthYearToCtl.clear();
    _allowedTitles.clear();
    _rated = widget.initialRated;
    _offlineMode = false;
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
    final expandable = widget.templateSchema?.expandableRows == true;
    if (!expandable &&
        _registeredParticipantCount >= (widget.maxParticipants ?? 999)) {
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
    final restrictionError = _participantRestrictionError(participant);
    if (restrictionError != null) {
      await _showParticipantRestrictionWarning(restrictionError);
      return;
    }
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

  String? _participantRestrictionError(_EditableParticipant participant) {
    final minRating = int.tryParse(_minRatingCtl.text.trim());
    final maxRating = int.tryParse(_maxRatingCtl.text.trim());
    final minAge = int.tryParse(_minAgeCtl.text.trim());
    final maxAge = int.tryParse(_maxAgeCtl.text.trim());
    final birthYearFrom = int.tryParse(_birthYearFromCtl.text.trim());
    final birthYearTo = int.tryParse(_birthYearToCtl.text.trim());
    final errors = <String>[];

    if (minRating != null && participant.rating < minRating) {
      errors.add(
        '• Рейтинг: у участника ${participant.rating}, требуется не ниже $minRating',
      );
    }
    if (maxRating != null && participant.rating > maxRating) {
      errors.add(
        '• Рейтинг: у участника ${participant.rating}, требуется не выше $maxRating',
      );
    }

    if (minAge != null || maxAge != null) {
      final age = participant.age;
      if (age == null) {
        final requirement = minAge != null && maxAge != null
            ? '$minAge–$maxAge лет'
            : minAge != null
                ? 'не меньше $minAge лет'
                : 'не больше $maxAge лет';
        errors.add(
          '• Возраст: у участника не указан. Требование турнира: $requirement',
        );
      } else {
        if (minAge != null && age < minAge) {
          errors.add(
            '• Возраст: у участника $age, требуется не меньше $minAge лет',
          );
        }
        if (maxAge != null && age > maxAge) {
          errors.add(
            '• Возраст: у участника $age, требуется не больше $maxAge лет',
          );
        }
      }
    }

    if (birthYearFrom != null || birthYearTo != null) {
      final birthYear = participant.birthYear;
      if (birthYear == null) {
        final requirement = birthYearFrom != null && birthYearTo != null
            ? '$birthYearFrom–$birthYearTo'
            : birthYearFrom != null
                ? 'не раньше $birthYearFrom'
                : 'не позже $birthYearTo';
        errors.add(
          '• Год рождения: у участника не указан. Требование турнира: $requirement',
        );
      } else {
        if (birthYearFrom != null && birthYear < birthYearFrom) {
          errors.add(
            '• Год рождения: у участника $birthYear, требуется не раньше $birthYearFrom',
          );
        }
        if (birthYearTo != null && birthYear > birthYearTo) {
          errors.add(
            '• Год рождения: у участника $birthYear, требуется не позже $birthYearTo',
          );
        }
      }
    }

    final allowedTitles =
        _allowedTitles.map((value) => value.toLowerCase()).toSet();
    final participantTitle = participant.title.trim();
    if (allowedTitles.isNotEmpty &&
        !allowedTitles.contains(participantTitle.toLowerCase())) {
      final actualTitle =
          participantTitle.isEmpty ? 'не указано' : participantTitle;
      errors.add(
        '• Шахматное звание: у участника $actualTitle. '
        'Допускаются: ${_allowedTitles.join(', ')}',
      );
    }

    if (errors.isEmpty) return null;
    return 'Не выполнены следующие условия участия:\n\n${errors.join('\n')}';
  }

  Future<void> _showParticipantRestrictionWarning(String reason) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel2,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amberAccent),
            SizedBox(width: 10),
            MakeChessLocalizedText('Участник не подходит'),
          ],
        ),
        content: MakeChessLocalizedText(reason),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const MakeChessLocalizedText('Понятно'),
          ),
        ],
      ),
    );
  }

  void _ensureParticipantSlots() {
    final requested = widget.templateSchema?.rowCount ??
        widget.maxParticipants ??
        _participants.length;
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
      final userId = TournamentStorageService.instance.currentUserId;
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
        _minRatingCtl.text = '${map['minRating'] ?? ''}';
        _maxRatingCtl.text = '${map['maxRating'] ?? ''}';
        _minAgeCtl.text = '${map['minAge'] ?? ''}';
        _maxAgeCtl.text = '${map['maxAge'] ?? ''}';
        _birthYearFromCtl.text = '${map['birthYearFrom'] ?? ''}';
        _birthYearToCtl.text = '${map['birthYearTo'] ?? ''}';
        final savedTitles = map['allowedTitles'];
        _allowedTitles
          ..clear()
          ..addAll(savedTitles is List
              ? savedTitles.map((value) => '$value')
              : '$savedTitles'
                  .split(RegExp(r'[,;]'))
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty));
        _type = '${map['type'] ?? _type}';
        _status = '${map['status'] ?? _status}';
        _rated = map['rated'] == true;
        _offlineMode = '${map['playMode'] ?? 'online'}' == 'offline';
        final customColumns = map['customColumns'];
        if (customColumns is List) {
          _customColumns
            ..clear()
            ..addAll(customColumns.map((item) => '$item'));
        }
        final customValues = map['customColumnValues'];
        if (customValues is Map) {
          _customColumnValues
            ..clear()
            ..addAll(customValues.map(
              (key, value) => MapEntry('$key', '$value'),
            ));
        }
        final savedTemplateValues = map['templateValues'];
        if (savedTemplateValues is Map) {
          _templateValues
            ..clear()
            ..addAll(savedTemplateValues.map(
              (key, value) => MapEntry('$key', '$value'),
            ));
        }
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
    if (_testMode) {
      _message('Тестовые данные не сохраняются в настоящий турнир');
      return;
    }
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
    final exactMaxParticipants = (widget.templateSchema?.rowCount ??
            widget.maxParticipants ??
            _participants.length)
        .clamp(2, 128)
        .toInt();
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
      'minRating': _minRatingCtl.text.trim(),
      'maxRating': _maxRatingCtl.text.trim(),
      'minAge': _minAgeCtl.text.trim(),
      'maxAge': _maxAgeCtl.text.trim(),
      'birthYearFrom': _birthYearFromCtl.text.trim(),
      'birthYearTo': _birthYearToCtl.text.trim(),
      'allowedTitles': _allowedTitles.toList(growable: false),
      'type': _type,
      'status': _status,
      'rated': _rated,
      'playMode': _offlineMode ? 'offline' : 'online',
      'customColumns': _customColumns,
      'customColumnValues': _customColumnValues,
      'maxParticipants': exactMaxParticipants,
      'logo': _logoDataUrl,
      'participants': _participants
          .where((participant) => !_isEmptySlot(participant))
          .map((participant) => participant.toJson())
          .toList(),
      'results': _results,
      'pairingSettings': _pairingSettings.toJson(),
      'pairings': _pairings,
      'pairingSchedule': _pairingSchedule,
      if (widget.templateSchema != null)
        'templateSchema': widget.templateSchema!.toJson(),
      'templateValues': _templateValues,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(data));
    await TournamentStorageService.instance
        .saveTournamentTable(widget.tournamentId, data);
    if (widget.organizerMode) {
      await TournamentStorageService.instance.updateOwnedTournamentFields(
        widget.tournamentId,
        <String, dynamic>{
          'playMode': _offlineMode ? 'offline' : 'online',
          'minRating': _minRatingCtl.text.trim(),
          'maxRating': _maxRatingCtl.text.trim(),
          'minAge': _minAgeCtl.text.trim(),
          'maxAge': _maxAgeCtl.text.trim(),
          'birthYearFrom': _birthYearFromCtl.text.trim(),
          'birthYearTo': _birthYearToCtl.text.trim(),
          'allowedTitles': _allowedTitles.toList(growable: false),
          'name': _nameCtl.text.trim(),
          'maxParticipants': exactMaxParticipants,
          'participationFilterEnabled': _minRatingCtl.text.trim().isNotEmpty ||
              _maxRatingCtl.text.trim().isNotEmpty ||
              _minAgeCtl.text.trim().isNotEmpty ||
              _maxAgeCtl.text.trim().isNotEmpty ||
              _birthYearFromCtl.text.trim().isNotEmpty ||
              _birthYearToCtl.text.trim().isNotEmpty ||
              _allowedTitles.isNotEmpty,
          'participantIds': _participants
              .where((participant) => !_isEmptySlot(participant))
              .map((participant) => participant.id)
              .toList(growable: false),
          'participantNames': <String, String>{
            for (final participant
                in _participants.where((item) => !_isEmptySlot(item)))
              participant.id: participant.name,
          },
        },
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: MakeChessLocalizedText('Таблица турнира сохранена')),
    );
  }

  Future<void> _saveAndClose(TournamentTableEditorResult result) async {
    // MAKECHESS_APP_ONLY_10_TOURNAMENTS_V3
    // Website: no limit. Windows/native application: 10 created tournaments.
    if (!kIsWeb && widget.creatingNewTournament) {
      final allowed = await ensureTemporaryTournamentAccess(context);
      if (!allowed) return;
    }
    await _save();
    if (!mounted) return;
    Navigator.pop(context, result);
  }

  Future<void> _openTestSetup() async {
    final countController = TextEditingController(
      text: '${math.min(widget.maxParticipants ?? 8, 8)}',
    );
    final count = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel2,
        title: const MakeChessLocalizedText('Количество участников'),
        content: TextField(
          controller: countController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: _decoration('Количество участников'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const MakeChessLocalizedText('Отмена'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(
              ctx,
              int.tryParse(countController.text.trim()),
            ),
            icon: const Icon(Icons.science_outlined),
            label: const MakeChessLocalizedText('Начать тест'),
          ),
        ],
      ),
    );
    countController.dispose();
    if (count == null || count < 2 || count > 128 || !mounted) {
      if (count != null) _message('Введите число участников от 2 до 128');
      return;
    }
    _enterTestMode(count);
  }

  void _enterTestMode(int count) {
    _testOriginalStatus = _status;
    _testOriginalParticipants = _participants
        .map((person) => _EditableParticipant.fromJson(person.toJson()))
        .toList(growable: false);
    _testOriginalResults = Map<String, String>.from(_results);
    _testOriginalPairings = _pairings
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    _testOriginalSchedule = _pairingSchedule
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);

    const firstNames = <String>[
      'Александр',
      'Михаил',
      'София',
      'Анна',
      'Дмитрий',
      'Мария',
      'Артём',
      'Елена',
      'Максим',
      'Виктория',
      'Иван',
      'Полина',
    ];
    const lastNames = <String>[
      'Иванов',
      'Петров',
      'Смирнов',
      'Орлов',
      'Волков',
      'Соколов',
      'Морозов',
      'Лебедев',
      'Козлов',
      'Новиков',
      'Попов',
      'Фёдоров',
    ];
    final random = math.Random();
    final minRating = int.tryParse(_minRatingCtl.text.trim()) ?? 1000;
    final maxRating = math.max(
      minRating,
      int.tryParse(_maxRatingCtl.text.trim()) ?? 2400,
    );
    final minAge = int.tryParse(_minAgeCtl.text.trim()) ?? 7;
    final maxAge = math.max(
      minAge,
      int.tryParse(_maxAgeCtl.text.trim()) ?? 70,
    );
    final currentYear = DateTime.now().year;
    final minBirth = int.tryParse(_birthYearFromCtl.text.trim());
    final maxBirth = int.tryParse(_birthYearToCtl.text.trim());
    final titles =
        _allowedTitles.isEmpty ? _chessTitles : _allowedTitles.toList();
    final generated = <_EditableParticipant>[];
    for (var index = 0; index < count; index++) {
      var age = minAge + random.nextInt(maxAge - minAge + 1);
      int birthYear;
      if (minBirth != null || maxBirth != null) {
        final from = minBirth ?? (maxBirth! - 70);
        final to = math.max(from, maxBirth ?? currentYear - minAge);
        birthYear = from + random.nextInt(to - from + 1);
        age = currentYear - birthYear;
      } else {
        birthYear = currentYear - age;
      }
      generated.add(_EditableParticipant(
        id: 'test_${index + 1}',
        name:
            '${firstNames[random.nextInt(firstNames.length)]} ${lastNames[random.nextInt(lastNames.length)]}',
        rating: minRating + random.nextInt(maxRating - minRating + 1),
        school: 'Тестовый клуб ${index % 4 + 1}',
        source: 'test',
        age: age,
        birthYear: birthYear,
        title: titles[random.nextInt(titles.length)],
      ));
    }
    setState(() {
      _testMode = true;
      _testRound = 0;
      _status = 'Готов к запуску';
      _participants
        ..clear()
        ..addAll(generated);
      _results.clear();
      _pairings = <Map<String, dynamic>>[];
      _pairingSchedule = <Map<String, dynamic>>[];
      _showPreview = true;
    });
  }

  void _exitTestMode() {
    setState(() {
      _testMode = false;
      _testRound = 0;
      _status = _testOriginalStatus ?? _status;
      _participants
        ..clear()
        ..addAll(_testOriginalParticipants ?? const <_EditableParticipant>[]);
      _results
        ..clear()
        ..addAll(_testOriginalResults ?? const <String, String>{});
      _pairings = _testOriginalPairings ?? <Map<String, dynamic>>[];
      _pairingSchedule = _testOriginalSchedule ?? <Map<String, dynamic>>[];
    });
  }

  void _startTestTournament() {
    setState(() => _status = 'Турнир идёт');
    _message('Тестовый турнир начат. Выполните жеребьёвку первого тура.');
  }

  void _generateTestRoundPairings() {
    if (_status != 'Турнир идёт') {
      _message('Сначала нажмите «Начать турнир»');
      return;
    }
    final totalRounds = int.tryParse(_roundsCtl.text.trim()) ?? 1;
    if (_testRound >= totalRounds) {
      _message('Все $totalRounds туров уже сыграны');
      return;
    }
    if (_testRound > 0 && _pairings.any((item) => '${item['result']}' == '*')) {
      _message('Сначала сформируйте результаты текущего тура');
      return;
    }
    final nextRound = _testRound + 1;
    final order = List<int>.generate(_participants.length, (index) => index)
      ..sort((a, b) {
        final points = _pointsFor(b).compareTo(_pointsFor(a));
        return points != 0 ? points : math.Random().nextInt(3) - 1;
      });
    final pairings = <Map<String, dynamic>>[];
    for (var index = 0; index < order.length; index += 2) {
      final whiteIndex = order[index];
      final blackIndex = index + 1 < order.length ? order[index + 1] : null;
      pairings.add(<String, dynamic>{
        'round': nextRound,
        'board': pairings.length + 1,
        'whiteId': _participants[whiteIndex].id,
        'blackId': blackIndex == null ? null : _participants[blackIndex].id,
        'result': blackIndex == null ? '1-0' : '*',
        'status': blackIndex == null ? 'finished' : 'waiting',
      });
      if (blackIndex == null) {
        _results[_resultKey(whiteIndex, nextRound - 1)] = '1';
      }
    }
    setState(() {
      _testRound = nextRound;
      _pairings = pairings;
      _pairingSchedule.addAll(pairings);
    });
    _message('Жеребьёвка $nextRound тура выполнена');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openRoundPairings(nextRound);
    });
  }

  void _generateTestRoundResults() {
    if (_testRound == 0 || _pairings.isEmpty) {
      _message('Сначала выполните жеребьёвку тура');
      return;
    }
    final random = math.Random();
    setState(() {
      for (final pairing in _pairings) {
        final whiteId = '${pairing['whiteId'] ?? ''}';
        final blackId = '${pairing['blackId'] ?? ''}';
        if (blackId.isEmpty) continue;
        final whiteIndex =
            _participants.indexWhere((person) => person.id == whiteId);
        final blackIndex =
            _participants.indexWhere((person) => person.id == blackId);
        if (whiteIndex < 0 || blackIndex < 0) continue;
        final outcome = random.nextInt(3);
        final whiteResult = outcome == 0
            ? '1'
            : outcome == 1
                ? '½'
                : '0';
        final blackResult = outcome == 0
            ? '0'
            : outcome == 1
                ? '½'
                : '1';
        _results[_resultKey(whiteIndex, _testRound - 1)] = whiteResult;
        _results[_resultKey(blackIndex, _testRound - 1)] = blackResult;
        pairing['result'] = outcome == 0
            ? '1-0'
            : outcome == 1
                ? '1/2-1/2'
                : '0-1';
        pairing['status'] = 'finished';
      }
    });
    _message('Случайные результаты $_testRound тура сформированы');
  }

  Future<void> _finishTestTournament() async {
    if (_testRound == 0) {
      _message('В турнире ещё не сыграно ни одного тура');
      return;
    }
    if (_pairings.any((item) => '${item['result']}' == '*')) {
      _message('Сначала сформируйте результаты текущего тура');
      return;
    }
    final order = List<int>.generate(_participants.length, (index) => index)
      ..sort((a, b) => _pointsFor(b).compareTo(_pointsFor(a)));
    final winner = _participants[order.first];
    setState(() => _status = 'Завершён');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel2,
        title: const MakeChessLocalizedText('Тестовый турнир завершён'),
        content: MakeChessLocalizedText(
          'Победитель: ${winner.name}\nРезультат: ${_scoreText(_pointsFor(order.first))} очков',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const MakeChessLocalizedText('Готово'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPairingControl() async {
    if (widget.previewMode && !widget.organizerMode) {
      _message('Управление жеребьёвкой доступно организатору турнира');
      return;
    }
    _pairingControlOpen = true;
    final result = await showTournamentPairingControlDialog(
      context: context,
      initialSettings: _pairingSettings,
      participantCount: _registeredParticipantCount,
      onSettingsChanged: (settings) {
        if (mounted) setState(() => _pairingSettings = settings);
      },
      onAction: _handlePairingAction,
    );
    _pairingControlOpen = false;
    if (result == null || !mounted) return;
    setState(() => _pairingSettings = result.settings);
    await _save();
    if (!mounted) return;
    _message('Режим жеребьёвки сохранён: ${result.settings.mode.label}');
  }

  Future<void> _openPairingSettings() async {
    final settings = await showTournamentPairingSettingsDialog(
      context: context,
      initialSettings: _pairingSettings,
    );
    if (settings == null || !mounted) return;
    setState(() => _pairingSettings = settings);
    await _save();
    if (mounted) _message('Настройки жеребьёвки сохранены');
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
        await _openPairingVariants(manual: true);
      case TournamentPairingAction.showVariants:
        await _openPairingVariants(manual: false);
    }
  }

  List<List<_EditableParticipant?>> _pairingVariants() {
    final players = _participants
        .where((player) => !_isEmptySlot(player) && player.id.trim().isNotEmpty)
        .toList(growable: false);
    if (players.length < 2) return const [];
    final random = math.Random();
    final weakest = players.toList()
      ..sort((a, b) {
        final ai = _participants.indexOf(a);
        final bi = _participants.indexOf(b);
        final points = _pointsFor(ai).compareTo(_pointsFor(bi));
        if (points != 0) return points;
        final buchholz = _buchholzFor(ai).compareTo(_buchholzFor(bi));
        if (buchholz != 0) return buchholz;
        return a.rating.compareTo(b.rating);
      });
    final bye = players.length.isOdd ? weakest.first : null;
    final active = players.where((player) => player != bye).toList();
    final previousPairs = <String>{};
    final colorBalance = <String, int>{};
    for (final pairing in _pairingSchedule) {
      final white = '${pairing['whiteId'] ?? ''}';
      final black = '${pairing['blackId'] ?? ''}';
      if (white.isNotEmpty && black.isNotEmpty) {
        final ids = <String>[white, black]..sort();
        previousPairs.add(ids.join('|'));
        colorBalance[white] = (colorBalance[white] ?? 0) + 1;
        colorBalance[black] = (colorBalance[black] ?? 0) - 1;
      }
    }

    double quality(List<_EditableParticipant> order) {
      var result = 0.0;
      for (var index = 0; index < order.length; index += 2) {
        final a = order[index];
        final b = order[index + 1];
        final ai = _participants.indexOf(a);
        final bi = _participants.indexOf(b);
        if (_pairingSettings.pairByCurrentScore) {
          result += (_pointsFor(ai) - _pointsFor(bi)).abs() * 100000;
        }
        if (_pairingSettings.useRating) {
          result += (a.rating - b.rating).abs() * 10;
        }
        if (a.age != null && b.age != null) {
          result += (a.age! - b.age!).abs() * 100;
        }
        result += (_buchholzFor(ai) - _buchholzFor(bi)).abs() * 1000;
        result += (_bergerFor(ai) - _bergerFor(bi)).abs() * 1000;
        if (_pairingSettings.balanceColors) {
          result +=
              ((colorBalance[a.id] ?? 0) - (colorBalance[b.id] ?? 0)).abs() *
                  500;
        }
        final ids = <String>[a.id, b.id]..sort();
        final key = ids.join('|');
        if (_pairingSettings.avoidRematches && previousPairs.contains(key)) {
          result += 10000000;
        }
      }
      return result;
    }

    final candidates =
        <({double score, double tie, List<_EditableParticipant?> order})>[];
    final keys = <String>{};
    for (var attempt = 0; attempt < 240; attempt++) {
      final order = active.toList();
      if (attempt == 0) {
        order.sort((a, b) {
          final points = _pointsFor(_participants.indexOf(b))
              .compareTo(_pointsFor(_participants.indexOf(a)));
          if (points != 0) return points;
          return b.rating.compareTo(a.rating);
        });
      } else {
        order.shuffle(random);
      }
      final key = order.map((player) => player.id).join('|');
      if (!keys.add(key)) continue;
      candidates.add((
        score: quality(order),
        tie: random.nextDouble(),
        order: <_EditableParticipant?>[
          ...order,
          if (bye != null) bye,
          if (bye != null) null,
        ],
      ));
    }
    candidates.sort((a, b) {
      final score = a.score.compareTo(b.score);
      return score != 0 ? score : a.tie.compareTo(b.tie);
    });
    return candidates.take(5).map((candidate) => candidate.order).toList();
  }

  Future<void> _applyPairingOrder(
    List<_EditableParticipant?> order, {
    int? replaceRound,
    bool reopen = true,
  }) async {
    final existingRounds = _pairingSchedule
        .map((pairing) => (pairing['round'] as num?)?.toInt() ?? 0)
        .where((round) => round > 0);
    final round = replaceRound ??
        (existingRounds.isEmpty ? 1 : existingRounds.reduce(math.max) + 1);
    final generated = <Map<String, dynamic>>[];
    final colorBalance = <String, int>{};
    for (final pairing in _pairingSchedule) {
      final white = '${pairing['whiteId'] ?? ''}';
      final black = '${pairing['blackId'] ?? ''}';
      if (white.isNotEmpty && black.isNotEmpty) {
        colorBalance[white] = (colorBalance[white] ?? 0) + 1;
        colorBalance[black] = (colorBalance[black] ?? 0) - 1;
      }
    }
    for (var index = 0; index < order.length; index += 2) {
      var first = order[index];
      var second = index + 1 < order.length ? order[index + 1] : null;
      if (first == null) continue;
      if (second != null &&
          _pairingSettings.balanceColors &&
          (colorBalance[first.id] ?? 0) > (colorBalance[second.id] ?? 0)) {
        final swap = first;
        first = second;
        second = swap;
      }
      final gameCount = second != null &&
              _pairingSettings.repeatTiming ==
                  TournamentRepeatTiming.consecutive
          ? _pairingSettings.gamesPerOpponent
          : 1;
      for (var game = 0; game < gameCount; game++) {
        final reverse = game.isOdd;
        final white = reverse && second != null ? second : first;
        final black = reverse && second != null ? first : second;
        generated.add(<String, dynamic>{
          'cycle': 1,
          'round': round,
          'gameInMatch': game + 1,
          'board': index ~/ 2 + 1,
          'whiteId': white.id,
          'blackId': black?.id,
          'result': black == null ? '1-0' : '*',
          'resultReason': black == null ? 'bye' : '',
          'status': black == null ? 'finished' : 'waiting',
        });
      }
    }
    setState(() {
      _pairings = generated;
      _pairingSchedule = <Map<String, dynamic>>[
        ..._pairingSchedule.where(
            (pairing) => ((pairing['round'] as num?)?.toInt() ?? 0) != round),
        ...generated,
      ];
    });
    await _save();
    if (mounted && reopen) await _openRoundPairings(round);
  }

  Future<void> _generateAutomaticPairings() async {
    if (_pairings.any((pairing) => '${pairing['result'] ?? '*'}' == '*')) {
      _message(
        'Новая жеребьёвка невозможна: сначала завершите все партии текущего тура',
      );
      return;
    }
    final variants = _pairingVariants();
    if (variants.isEmpty) {
      _message('Для жеребьёвки нужны минимум два участника');
      return;
    }
    await _applyPairingOrder(variants.first);
  }

  Future<void> _openPairingVariants({required bool manual}) async {
    final variants = _pairingVariants();
    if (manual && _pairings.isNotEmpty) {
      final byId = <String, _EditableParticipant>{
        for (final player in _participants) player.id: player,
      };
      final current = <_EditableParticipant?>[];
      for (final pairing in _pairings.where(
          (pairing) => ((pairing['gameInMatch'] as num?)?.toInt() ?? 1) == 1)) {
        final white = byId['${pairing['whiteId'] ?? ''}'];
        if (white == null) continue;
        current
          ..add(white)
          ..add(byId['${pairing['blackId'] ?? ''}']);
      }
      if (current.length >= 2) {
        variants.insert(0, current);
        if (variants.length > 5) variants.removeLast();
      }
    }
    if (variants.isEmpty) {
      _message('Для жеребьёвки нужны минимум два участника');
      return;
    }
    final selected = await showDialog<List<_EditableParticipant?>>(
      context: context,
      builder: (dialogContext) => _PairingVariantsDialog(
        variants: variants,
        manual: manual,
      ),
    );
    if (selected != null && mounted) {
      final currentRound = _pairings.isEmpty
          ? null
          : (_pairings.first['round'] as num?)?.toInt();
      await _applyPairingOrder(
        selected,
        replaceRound: manual ? currentRound : null,
      );
    }
  }

  Future<void> _generateLegacyAutomaticPairings() async {
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
    await _openRoundPairings(1);
  }

  String _resultKey(int row, int column) => '$row:$column';

  bool get _isSwissTournament => _type.toLowerCase().contains('швейцар');

  int get _resultColumnCount {
    if (!_isSwissTournament) return _participants.length;
    final configuredRounds = int.tryParse(_roundsCtl.text.trim()) ?? 0;
    return configuredRounds > 0 ? configuredRounds : 1;
  }

  double _pointsFor(int row) {
    var result = 0.0;
    for (var column = 0; column < _resultColumnCount; column++) {
      if (!_isSwissTournament && row == column) continue;
      final value = _results[_resultKey(row, column)];
      if (value == '1') result += _pairingSettings.scoringSystem.winPoints;
      if (value == '½') result += _pairingSettings.scoringSystem.drawPoints;
    }
    return result;
  }

  double _pointsBeforeRound(int row, int round) {
    if (row < 0 || row >= _participants.length || round <= 1) return 0;
    if (_isSwissTournament) {
      var points = 0.0;
      for (var column = 0;
          column < round - 1 && column < _resultColumnCount;
          column++) {
        final value = _results[_resultKey(row, column)];
        if (value == '1') {
          points += _pairingSettings.scoringSystem.winPoints;
        } else if (value == '½') {
          points += _pairingSettings.scoringSystem.drawPoints;
        }
      }
      return points;
    }
    final participantId = _participants[row].id;
    final source = _pairingSchedule.isNotEmpty ? _pairingSchedule : _pairings;
    var points = 0.0;
    for (final pairing in source) {
      final pairingRound = (pairing['round'] as num?)?.toInt() ?? 1;
      if (pairingRound >= round) continue;
      final whiteId = '${pairing['whiteId'] ?? ''}';
      final blackId = '${pairing['blackId'] ?? ''}';
      final isWhite = whiteId == participantId;
      final isBlack = blackId == participantId;
      if (!isWhite && !isBlack) continue;
      final result = '${pairing['result'] ?? '*'}'
          .trim()
          .replaceAll(' ', '')
          .replaceAll('½', '1/2');
      if (result == '1/2-1/2') {
        points += _pairingSettings.scoringSystem.drawPoints;
      } else if ((isWhite && result == '1-0') || (isBlack && result == '0-1')) {
        points += _pairingSettings.scoringSystem.winPoints;
      }
    }
    return points;
  }

  Map<String, dynamic>? _swissPairingFor(int row, int roundColumn) {
    if (!_isSwissTournament || row < 0 || row >= _participants.length) {
      return null;
    }
    final participantId = _participants[row].id;
    final round = roundColumn + 1;
    final source = _pairingSchedule.isNotEmpty ? _pairingSchedule : _pairings;
    for (final pairing in source) {
      final pairingRound = (pairing['round'] as num?)?.toInt() ?? 1;
      if (pairingRound != round) continue;
      if ('${pairing['whiteId'] ?? ''}' == participantId ||
          '${pairing['blackId'] ?? ''}' == participantId) {
        return pairing;
      }
    }
    return null;
  }

  String _swissCellText(int row, int column, String result) {
    final pairing = _swissPairingFor(row, column);
    if (pairing == null) return '—\n—\n$result';
    final participantId = _participants[row].id;
    final isWhite = '${pairing['whiteId'] ?? ''}' == participantId;
    final opponentId = '${pairing[isWhite ? 'blackId' : 'whiteId'] ?? ''}';
    if (opponentId.isEmpty) return '—\nБ\n$result';
    final opponentIndex =
        _participants.indexWhere((participant) => participant.id == opponentId);
    return '${opponentIndex < 0 ? '—' : opponentIndex + 1}\n${isWhite ? 'Б' : 'Ч'}\n$result';
  }

  void _setSwissPairingResult(int row, int column, String? value) {
    final pairing = _swissPairingFor(row, column);
    if (pairing == null) return;
    final participantId = _participants[row].id;
    final isWhite = '${pairing['whiteId'] ?? ''}' == participantId;
    final gameResult = value == null
        ? '*'
        : value == '½'
            ? '1/2-1/2'
            : (value == '1') == isWhite
                ? '1-0'
                : '0-1';
    pairing['result'] = gameResult;
    final opponentId = '${pairing[isWhite ? 'blackId' : 'whiteId'] ?? ''}';
    final opponentRow =
        _participants.indexWhere((participant) => participant.id == opponentId);
    if (opponentRow >= 0) {
      final opponentKey = _resultKey(opponentRow, column);
      if (value == null) {
        _results.remove(opponentKey);
      } else {
        _results[opponentKey] = value == '1'
            ? '0'
            : value == '0'
                ? '1'
                : '½';
      }
    }
  }

  Future<bool> _confirmPairingCorrection() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const MakeChessLocalizedText('Изменение жеребьёвки'),
            content: const MakeChessLocalizedText(
              'Вы уверены, что хотите поменять результат жеребьёвки?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const MakeChessLocalizedText('Нет'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const MakeChessLocalizedText('Да'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _editSwissOpponent(int row, int column) async {
    final pairing = _swissPairingFor(row, column);
    if (pairing == null || !await _confirmPairingCorrection() || !mounted) {
      return;
    }
    final participant = _participants[row];
    final isWhite = '${pairing['whiteId'] ?? ''}' == participant.id;
    final selected = await showDialog<_EditableParticipant>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const MakeChessLocalizedText('Выберите нового соперника'),
        children: [
          for (var index = 0; index < _participants.length; index++)
            if (_participants[index].id != participant.id &&
                !_isEmptySlot(_participants[index]))
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.pop(dialogContext, _participants[index]),
                child: MakeChessLocalizedText(
                  '${index + 1}. ${_participants[index].name}',
                ),
              ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      pairing[isWhite ? 'blackId' : 'whiteId'] = selected.id;
      pairing['result'] = '*';
      _results.remove(_resultKey(row, column));
    });
    await _save();
  }

  Future<void> _editSwissColor(int row, int column) async {
    final pairing = _swissPairingFor(row, column);
    if (pairing == null || !await _confirmPairingCorrection() || !mounted) {
      return;
    }
    setState(() {
      final white = pairing['whiteId'];
      pairing['whiteId'] = pairing['blackId'];
      pairing['blackId'] = white;
      pairing['result'] = '*';
      _results.remove(_resultKey(row, column));
    });
    await _save();
  }

  Future<void> _editSwissResult(int row, int column) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const MakeChessLocalizedText('Результат игры'),
        children: [
          for (final value in const <String>['0', '½', '1', '—'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, value),
              child: MakeChessLocalizedText(value),
            ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    final value = selected == '—' ? null : selected;
    setState(() {
      final key = _resultKey(row, column);
      if (value == null) {
        _results.remove(key);
      } else {
        _results[key] = value;
      }
      _setSwissPairingResult(row, column, value);
    });
    await _save();
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
    final picked = await LocalFileService.pickFile(
      extensions: const <String>['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'],
    );
    if (picked == null || !mounted) return;
    final encoded = base64Encode(picked.bytes);
    setState(() {
      _logoDataUrl = 'data:${picked.mimeType};base64,$encoded';
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

  Future<void> _openAddPlayer() async {
    if (!_offlineMode) {
      await _openParticipantPicker();
      return;
    }
    final source = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel2,
        title: const MakeChessLocalizedText('Добавить игрока'),
        content: const MakeChessLocalizedText(
          'Выберите, откуда добавить участника офлайн-турнира.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const MakeChessLocalizedText('Отмена'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'makechess'),
            icon: const Icon(Icons.public),
            label: const MakeChessLocalizedText('Из MakeChess'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, 'manual'),
            icon: const Icon(Icons.edit_note),
            label: const MakeChessLocalizedText('Ввести вручную'),
          ),
        ],
      ),
    );
    if (source == 'makechess') {
      await _openParticipantPicker();
    } else if (source == 'manual') {
      await _addOfflineParticipantManually();
    }
  }

  Future<void> _addOfflineParticipantManually() async {
    final name = TextEditingController();
    final rating = TextEditingController(text: '1200');
    final school = TextEditingController();
    final externalProfile = TextEditingController();
    final age = TextEditingController();
    final birthYear = TextEditingController();
    final title = TextEditingController();
    String source = 'guest';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _panel2,
          title: const MakeChessLocalizedText('Новый офлайн-игрок'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: source,
                    decoration: _decoration('Источник игрока'),
                    items: const [
                      DropdownMenuItem(
                        value: 'guest',
                        child: MakeChessLocalizedText(
                            'Незарегистрированный игрок'),
                      ),
                      DropdownMenuItem(
                        value: 'external',
                        child: MakeChessLocalizedText(
                            'Игрок с другого шахматного сайта'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => source = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _dialogField(name, 'Имя и фамилия'),
                  _dialogField(rating, 'Рейтинг', numeric: true),
                  _dialogField(school, 'Школа / клуб'),
                  _dialogField(age, 'Возраст', numeric: true),
                  _dialogField(birthYear, 'Год рождения', numeric: true),
                  _participantTitleDropdown(title),
                  _dialogField(
                    externalProfile,
                    source == 'external'
                        ? 'Сайт, логин или ссылка на профиль'
                        : 'Контакт или примечание (необязательно)',
                  ),
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
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const MakeChessLocalizedText('Добавить игрока'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && mounted) {
      final participant = _EditableParticipant(
        id: '${source}_${DateTime.now().microsecondsSinceEpoch}',
        name: name.text.trim(),
        rating: int.tryParse(rating.text.trim()) ?? 1200,
        school: school.text.trim(),
        source: source,
        externalProfile: externalProfile.text.trim(),
        age: int.tryParse(age.text.trim()),
        birthYear: int.tryParse(birthYear.text.trim()),
        title: title.text.trim(),
      );
      final restrictionError = _participantRestrictionError(participant);
      if (restrictionError != null) {
        await _showParticipantRestrictionWarning(restrictionError);
        name.dispose();
        rating.dispose();
        school.dispose();
        externalProfile.dispose();
        age.dispose();
        birthYear.dispose();
        title.dispose();
        return;
      }
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
    }
    name.dispose();
    rating.dispose();
    school.dispose();
    externalProfile.dispose();
    age.dispose();
    birthYear.dispose();
    title.dispose();
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
    final age = TextEditingController(text: person.age?.toString() ?? '');
    final birthYear =
        TextEditingController(text: person.birthYear?.toString() ?? '');
    final title = TextEditingController(text: person.title);
    _EditableParticipant candidateFromFields() => _EditableParticipant(
          id: person.id,
          name: name.text.trim().isEmpty ? 'Участник' : name.text.trim(),
          rating: int.tryParse(rating.text.trim()) ?? 1200,
          school: school.text.trim(),
          flag: flag.text.trim().isEmpty ? '🏳️' : flag.text.trim(),
          avatarUrl: avatar.text.trim(),
          source: _isEmptySlot(person) ? 'guest' : person.source,
          externalProfile: person.externalProfile,
          age: int.tryParse(age.text.trim()),
          birthYear: int.tryParse(birthYear.text.trim()),
          title: title.text.trim(),
        );
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
                _dialogField(age, 'Возраст', numeric: true),
                _dialogField(birthYear, 'Год рождения', numeric: true),
                _participantTitleDropdown(title),
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
            onPressed: () async {
              final restrictionError =
                  _participantRestrictionError(candidateFromFields());
              if (restrictionError != null) {
                await _showParticipantRestrictionWarning(restrictionError);
                return;
              }
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const MakeChessLocalizedText('Применить'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      final candidate = candidateFromFields();
      final restrictionError = _participantRestrictionError(candidate);
      if (restrictionError != null) {
        await _showParticipantRestrictionWarning(restrictionError);
        name.dispose();
        rating.dispose();
        school.dispose();
        flag.dispose();
        avatar.dispose();
        age.dispose();
        birthYear.dispose();
        title.dispose();
        return;
      }
      setState(() {
        if (_isEmptySlot(person)) {
          person.id = 'manual_${DateTime.now().microsecondsSinceEpoch}';
          person.source = 'guest';
        }
        person.name = name.text.trim().isEmpty ? 'Участник' : name.text.trim();
        person.rating = int.tryParse(rating.text.trim()) ?? 1200;
        person.school = school.text.trim();
        person.flag = flag.text.trim().isEmpty ? '🏳️' : flag.text.trim();
        person.avatarUrl = avatar.text.trim();
        person.age = candidate.age;
        person.birthYear = candidate.birthYear;
        person.title = candidate.title;
      });
      await _save();
    }
    name.dispose();
    rating.dispose();
    school.dispose();
    flag.dispose();
    avatar.dispose();
    age.dispose();
    birthYear.dispose();
    title.dispose();
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

  Widget _participantTitleDropdown(TextEditingController controller) {
    final current =
        controller.text.trim().isEmpty ? 'Без звания' : controller.text.trim();
    final titles = <String>[
      ..._chessTitles,
      if (!_chessTitles.contains(current)) current,
    ];
    controller.text = current;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: current,
        dropdownColor: _panel2,
        isExpanded: true,
        style: const TextStyle(color: Colors.white),
        decoration: _decoration('Шахматное звание'),
        items: titles
            .map((value) => DropdownMenuItem<String>(
                  value: value,
                  child: MakeChessLocalizedText(value),
                ))
            .toList(growable: false),
        onChanged: (value) => controller.text = value ?? 'Без звания',
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
    final publicationMode = _showPreview && !widget.previewMode;
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.transparent,
      child: Container(
        width: mathMin(1540, size.width - 24),
        height: mathMin(930, size.height - 24),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _testMode ? Colors.redAccent : _gold.withOpacity(0.6),
            width: _testMode ? 4 : 1,
          ),
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
                      // Просмотр шаблона и турнир по шаблону обязаны
                      // рисоваться одним и тем же компонентом. Публикационный
                      // вид включается только внутри реального турнира.
                      child: (_showPreview && !widget.previewMode)
                          ? _buildPublicationPreview()
                          : Column(
                              children: [
                                _buildHeaderEditor(),
                                if (widget.templateSchema != null) ...[
                                  const SizedBox(height: 14),
                                  _buildTemplateFieldsSummary(),
                                ],
                                const SizedBox(height: 14),
                                _buildTableConstructor(),
                                const SizedBox(height: 10),
                                _buildTable(),
                              ],
                            ),
                    ),
                  ),
                  if (!publicationMode)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0A1520),
                        border: Border(top: BorderSide(color: _line)),
                      ),
                      child: _buildActions(),
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
          if (_testMode) ...[
            const MakeChessLocalizedText(
              'РЕЖИМ ТЕСТА',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _exitTestMode,
              icon: const Icon(Icons.exit_to_app),
              label: const MakeChessLocalizedText('Выход из теста'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
              ),
            ),
          ] else if (widget.organizerMode && !widget.previewMode) ...[
            FilledButton.icon(
              onPressed: _openTestSetup,
              icon: const Icon(Icons.science_outlined),
              label: const MakeChessLocalizedText('Тест'),
            ),
          ],
          const SizedBox(width: 12),
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
                      child: widget.lockTournamentType
                          ? _readonlyValue('Тип турнира', _type)
                          : _dropdown(
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _line),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sports_esports_outlined, color: _gold),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MakeChessLocalizedText(
                              'Режим проведения',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            MakeChessLocalizedText(
                              'Онлайн через MakeChess или игра за реальной доской',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            icon: Icon(Icons.language),
                            label: MakeChessLocalizedText('Онлайн'),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: Icon(Icons.table_restaurant_outlined),
                            label: MakeChessLocalizedText('Офлайн'),
                          ),
                        ],
                        selected: <bool>{_offlineMode},
                        onSelectionChanged: widget.previewMode
                            ? null
                            : (selection) {
                                setState(
                                  () => _offlineMode = selection.first,
                                );
                                _save();
                              },
                      ),
                    ],
                  ),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.rule, color: _gold),
                          SizedBox(width: 8),
                          MakeChessLocalizedText(
                            'Ограничения участия',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _field(_minRatingCtl, 'Рейтинг от',
                                numeric: true),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _field(_maxRatingCtl, 'Рейтинг до',
                                numeric: true),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child:
                                _field(_minAgeCtl, 'Возраст от', numeric: true),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child:
                                _field(_maxAgeCtl, 'Возраст до', numeric: true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _field(_birthYearFromCtl, 'Год рождения от',
                                numeric: true),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _field(_birthYearToCtl, 'Год рождения до',
                                numeric: true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _titleRestrictionsField(),
                    ],
                  ),
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
                      child: _field(
                        _roundsCtl,
                        'Количество туров',
                        numeric: true,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_ageCtl, 'Возрастная категория')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<TournamentScoringSystem>(
                        value: _pairingSettings.scoringSystem,
                        decoration: _decoration('Система начисления очков'),
                        items: TournamentScoringSystem.values
                            .map((system) => DropdownMenuItem(
                                  value: system,
                                  child: MakeChessLocalizedText(system.label),
                                ))
                            .toList(growable: false),
                        onChanged: widget.previewMode
                            ? null
                            : (system) {
                                if (system == null) return;
                                setState(() => _pairingSettings =
                                        _pairingSettings.copyWith(
                                      scoringSystem: system,
                                    ));
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _line),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up, color: _gold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const MakeChessLocalizedText(
                              'Рейтинговый турнир',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            MakeChessLocalizedText(
                              _rated
                                  ? 'Результаты учитываются в рейтинге'
                                  : 'Без расчёта рейтинга',
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _rated,
                        onChanged: widget.previewMode
                            ? null
                            : (value) => setState(() => _rated = value),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateFieldsSummary() {
    final schema = widget.templateSchema;
    if (schema == null) return const SizedBox.shrink();
    final fields = schema.fields
        .where((item) => !_isBuiltInTemplateField(item))
        .toList(growable: false);
    if (fields.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              for (final field in fields)
                SizedBox(
                  width: 280,
                  child: field.kind == TournamentTemplateFieldKind.staticText ||
                          widget.previewMode
                      ? Text(
                          '${field.label}: ${_templateValues[field.id]?.trim().isNotEmpty == true ? _templateValues[field.id] : field.value.isEmpty ? '—' : field.value}',
                          style: const TextStyle(color: Colors.white70),
                        )
                      : TextFormField(
                          initialValue: _templateValues[field.id] ?? '',
                          maxLines: field.lines,
                          decoration: InputDecoration(
                            labelText: field.label,
                            hintText: field.prompt,
                          ),
                          onChanged: (value) =>
                              _templateValues[field.id] = value,
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinateTemplateLayout(TournamentTemplateSchema schema) {
    TournamentTemplatePosition? position(String id) {
      for (final item in schema.positions) {
        if (item.elementId == id) return item;
      }
      return null;
    }

    return Container(
      width: double.infinity,
      height: 430,
      decoration: BoxDecoration(
        color: _panel2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gold.withOpacity(.45)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          Positioned placed({
            required String id,
            required int fallbackIndex,
            required double width,
            required Widget child,
          }) {
            final saved = position(id);
            final x = saved?.xPercent ?? 2;
            final y = saved?.yPercent ?? (4 + fallbackIndex * 9);
            return Positioned(
              left: x / 100 * math.max(0, constraints.maxWidth - width),
              top: y / 100 * math.max(0, constraints.maxHeight - 40),
              width: width,
              child: child,
            );
          }

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (var index = 0; index < schema.fields.length; index++)
                if (!_isBuiltInTemplateField(schema.fields[index]))
                  placed(
                    id: schema.fields[index].id,
                    fallbackIndex: index,
                    width: 290,
                    child: Text(
                      '${schema.fields[index].label}: '
                      '${_templateValues[schema.fields[index].id]?.trim().isNotEmpty == true ? _templateValues[schema.fields[index].id] : '—'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
              placed(
                id: 'table',
                fallbackIndex: schema.fields.length + 1,
                width: math.min(700, constraints.maxWidth * .62),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: _line),
                    color: _background,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 42,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final column in schema.columns.take(6))
                                Expanded(
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      border: Border(
                                          right: BorderSide(color: _line)),
                                    ),
                                    child: Text(column.label,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: _gold,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text('Турнирная таблица',
                              style: TextStyle(color: Colors.white38)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (var index = 0; index < schema.buttons.length; index++)
                placed(
                  id: schema.buttons[index].id,
                  fallbackIndex: schema.fields.length + 5 + index,
                  width: 165,
                  child: OutlinedButton(
                    onPressed: widget.previewMode ||
                            !schema.buttons[index].enabled
                        ? null
                        : () =>
                            _runTemplateAction(schema.buttons[index].action),
                    child: Text(schema.buttons[index].label,
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  bool _isBuiltInTemplateField(TournamentTemplateField field) {
    final label = field.label.trim().toLowerCase();
    return label == 'главный судья' ||
        label == 'судья' ||
        label == 'организатор' ||
        label == 'место' ||
        label == 'место проведения';
  }

  void _runTemplateAction(TournamentTemplateAction action) {
    switch (action) {
      case TournamentTemplateAction.editData:
        setState(() => _showPreview = false);
        return;
      case TournamentTemplateAction.save:
        _save();
        return;
      case TournamentTemplateAction.callTournament:
        widget.onCallTournament?.call();
        return;
      case TournamentTemplateAction.participate:
        widget.onParticipate?.call();
        return;
      case TournamentTemplateAction.addParticipant:
        _openParticipantPicker();
        return;
      case TournamentTemplateAction.removeParticipant:
        final index =
            _participants.lastIndexWhere((item) => !_isEmptySlot(item));
        if (index < 0) {
          _message('В таблице нет участников для удаления');
        } else {
          setState(() => _participants.removeAt(index));
        }
        return;
      case TournamentTemplateAction.createPairing:
        if (_testMode) {
          _generateTestRoundPairings();
        } else {
          _openPairingControl();
        }
        return;
      case TournamentTemplateAction.enterResult:
        _message('Выберите результат в ячейке таблицы');
        return;
      case TournamentTemplateAction.startTournament:
        if (_testMode) {
          _startTestTournament();
        } else {
          widget.onStartTournament?.call();
        }
        return;
      case TournamentTemplateAction.pauseTournament:
        widget.onPauseTournament?.call();
        return;
      case TournamentTemplateAction.finishTournament:
        if (_testMode) {
          _finishTestTournament();
        } else {
          widget.onFinishTournament?.call();
        }
        return;
      case TournamentTemplateAction.startRound:
        widget.onStartTournament?.call();
        return;
      case TournamentTemplateAction.finishRound:
        widget.onFinishTournament?.call();
        return;
      case TournamentTemplateAction.recalculate:
        setState(() {});
        _message('Таблица пересчитана');
        return;
      case TournamentTemplateAction.publish:
        _saveAndClose(TournamentTableEditorResult.published);
        return;
      case TournamentTemplateAction.printTable:
        _message('Печать будет подключена отдельно');
        return;
    }
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
          if (widget.templateSchema != null) ...[
            const SizedBox(height: 14),
            _buildTemplateFieldsSummary(),
          ],
          if (_hasParticipationRestrictions) ...[
            const SizedBox(height: 14),
            _buildParticipationRestrictionsSummary(),
          ],
          const SizedBox(height: 20),
          if (_pairings.isNotEmpty) ...[
            _buildPairingsSummary(),
            const SizedBox(height: 14),
          ],
          if (_pairedRounds.isNotEmpty) ...[
            _buildRoundPairingButtons(),
            const SizedBox(height: 10),
          ],
          _buildPublicationTable(),
          if (widget.organizerMode || widget.onParticipate != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (widget.organizerMode)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.previewMode ? null : _openAddPlayer,
                      icon: const Icon(Icons.person_add_alt),
                      label: const MakeChessLocalizedText('Добавить игрока'),
                    ),
                  ),
                if (widget.organizerMode) const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onParticipate,
                    icon: const Icon(Icons.how_to_reg),
                    label: const MakeChessLocalizedText(
                      'Записаться на турнир',
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
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
                      onPressed: _testMode
                          ? _startTestTournament
                          : widget.onStartTournament,
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
                      onPressed: _testMode
                          ? _finishTestTournament
                          : widget.onFinishTournament,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const MakeChessLocalizedText('Закончить'),
                    ),
                  ],
                ],
                const SizedBox(width: 10),
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
                      side: const BorderSide(
                          color: Color(0xFF28A9FF), width: 1.5),
                    ),
                    elevation: 10,
                    shadowColor: const Color(0xFF28A9FF),
                  ),
                  onPressed: _testMode
                      ? _generateTestRoundPairings
                      : _openPairingControl,
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
                if (_testMode) ...[
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _generateTestRoundResults,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF9B1C1C),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.casino_outlined),
                    label: const MakeChessLocalizedText(
                      'Результат тестового тура',
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _message('Печать будет подключена отдельно'),
                  icon: const Icon(Icons.print_outlined),
                  label: const MakeChessLocalizedText('Печать'),
                ),
              ],
            ),
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
                      'Режим проведения',
                      _offlineMode
                          ? 'Офлайн • ${_venueCtl.text.trim().isEmpty ? 'Реальная доска' : _venueCtl.text.trim()}'
                          : 'Онлайн • MakeChess',
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

  bool get _hasParticipationRestrictions =>
      _minRatingCtl.text.trim().isNotEmpty ||
      _maxRatingCtl.text.trim().isNotEmpty ||
      _minAgeCtl.text.trim().isNotEmpty ||
      _maxAgeCtl.text.trim().isNotEmpty ||
      _birthYearFromCtl.text.trim().isNotEmpty ||
      _birthYearToCtl.text.trim().isNotEmpty ||
      _allowedTitles.isNotEmpty;

  Widget _buildParticipationRestrictionsSummary() {
    String range(String from, String to) {
      if (from.isEmpty && to.isEmpty) return 'без ограничений';
      if (from.isEmpty) return 'до $to';
      if (to.isEmpty) return 'от $from';
      return '$from–$to';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF31506A)),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        children: [
          Text(
            'Рейтинг: ${range(_minRatingCtl.text.trim(), _maxRatingCtl.text.trim())}',
          ),
          Text(
            'Возраст: ${range(_minAgeCtl.text.trim(), _maxAgeCtl.text.trim())}',
          ),
          Text(
            'Год рождения: ${range(_birthYearFromCtl.text.trim(), _birthYearToCtl.text.trim())}',
          ),
          Text(
            'Звания: ${_allowedTitles.isEmpty ? 'без ограничений' : _allowedTitles.join(', ')}',
          ),
        ],
      ),
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
    final resultColumnCount = _resultColumnCount;
    final resultCellWidth = _isSwissTournament ? 66.0 : 48.0;
    final matrixWidth = resultColumnCount * resultCellWidth;
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
                    for (var i = 0; i < resultColumnCount; i++)
                      _prettyHead('${i + 1}', resultCellWidth,
                          onTap: () => _openRoundPairings(i + 1)),
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

  _EditableParticipant? _pairingParticipant(String? id) {
    final normalized = (id ?? '').trim();
    if (normalized.isEmpty) return null;
    for (final participant in _participants) {
      if (participant.id == normalized) return participant;
    }
    return null;
  }

  List<Map<String, dynamic>> _pairingsForRound(int round) {
    final source = _pairingSchedule.isNotEmpty ? _pairingSchedule : _pairings;
    return source
        .where((pairing) =>
            ((pairing['round'] as num?)?.toInt() ?? 1) == round &&
            ((pairing['gameInMatch'] as num?)?.toInt() ?? 1) == 1)
        .map((pairing) => Map<String, dynamic>.from(pairing))
        .toList(growable: false)
      ..sort((a, b) => ((a['board'] as num?)?.toInt() ?? 0)
          .compareTo((b['board'] as num?)?.toInt() ?? 0));
  }

  String _roundPairingsText(
    int round,
    List<Map<String, dynamic>> pairings, {
    required bool detailed,
  }) {
    final buffer = StringBuffer()
      ..writeln(_nameCtl.text.trim())
      ..writeln('${MakeChessLocalization.phrase('Тур')} $round')
      ..writeln(
          '$_type • ${_minutesCtl.text.trim()}+${_incrementCtl.text.trim()} • $_status')
      ..writeln();
    for (final pairing in pairings) {
      final white = _pairingParticipant('${pairing['whiteId'] ?? ''}');
      final black = _pairingParticipant('${pairing['blackId'] ?? ''}');
      String player(_EditableParticipant? person) {
        if (person == null) return MakeChessLocalization.phrase('Свободен');
        final index = _participants.indexOf(person);
        final details = detailed
            ? ' • ${MakeChessLocalization.phrase('Рейтинг')}: ${person.rating}'
                ' • ${MakeChessLocalization.phrase('Звание')}: ${person.title.isEmpty ? '—' : person.title}'
                ' • ${MakeChessLocalization.phrase('Возраст')}: ${person.age?.toString() ?? '—'}'
            : '';
        return '${person.name}$details • ${MakeChessLocalization.phrase('Очки')}: ${_scoreText(_pointsBeforeRound(index, round))}';
      }

      final result = '${pairing['result'] ?? '*'}';
      buffer.writeln(
          '${MakeChessLocalization.phrase('Стол')} ${pairing['board'] ?? '—'}: ${player(white)} — ${player(black)}${result == '*' ? '' : '  $result'}');
    }
    return buffer.toString();
  }

  Future<void> _openRoundPairings(int round) async {
    final pairings = _pairingsForRound(round);
    if (pairings.isEmpty) {
      _message('Для этого тура жеребьёвка ещё не проведена');
      return;
    }
    var detailed = false;
    var collapsed = false;
    final finishedRound = pairings.every(
      (pairing) => '${pairing['result'] ?? '*'}' != '*',
    );
    var mode = 'view';
    var selectedVariant = 0;
    var variants = <List<_EditableParticipant?>>[];
    var displayed = <_EditableParticipant?>[
      for (final pairing in pairings) ...[
        _pairingParticipant('${pairing['whiteId'] ?? ''}'),
        _pairingParticipant('${pairing['blackId'] ?? ''}'),
      ],
    ];
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Widget playerCard(
              _EditableParticipant? person, bool white, int slot) {
            final index = person == null ? -1 : _participants.indexOf(person);
            final card = Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: white
                    ? Colors.white.withOpacity(.06)
                    : Colors.black.withOpacity(.22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MakeChessLocalizedText(
                    person?.name ?? 'Свободен',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  MakeChessLocalizedText(
                    '${MakeChessLocalization.phrase('Очки')}: ${index < 0 ? '—' : _scoreText(_pointsBeforeRound(index, round))}',
                    style: const TextStyle(color: Colors.cyanAccent),
                  ),
                  if (detailed && person != null) ...[
                    const SizedBox(height: 4),
                    MakeChessLocalizedText(
                      '${MakeChessLocalization.phrase('Рейтинг')}: ${person.rating} • '
                      '${MakeChessLocalization.phrase('Звание')}: ${person.title.isEmpty ? '—' : person.title} • '
                      '${MakeChessLocalization.phrase('Возраст')}: ${person.age?.toString() ?? '—'}',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ],
              ),
            );
            return Expanded(
              child: mode == 'edit' && person != null
                  ? DragTarget<int>(
                      onAcceptWithDetails: (details) {
                        setDialogState(() {
                          final moved = displayed[details.data];
                          displayed[details.data] = displayed[slot];
                          displayed[slot] = moved;
                        });
                      },
                      builder: (_, __, ___) => Draggable<int>(
                        data: slot,
                        feedback: Material(
                          color: Colors.transparent,
                          child: SizedBox(width: 350, child: card),
                        ),
                        childWhenDragging: Opacity(opacity: .35, child: card),
                        child: card,
                      ),
                    )
                  : card,
            );
          }

          return Dialog(
            backgroundColor: _panel,
            insetPadding: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: _blue),
            ),
            child: SizedBox(
              width: 1120,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.only(left: 16, right: 4),
                    height: 58,
                    decoration: const BoxDecoration(
                      color: _panel2,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(14)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shuffle, color: Colors.cyanAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MakeChessLocalizedText(
                            '${MakeChessLocalization.phrase('Жеребьёвка')} • ${MakeChessLocalization.phrase('Тур')} $round',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              setDialogState(() => detailed = !detailed),
                          icon: Icon(detailed
                              ? Icons.visibility_off
                              : Icons.info_outline),
                          label: const MakeChessLocalizedText('Подробно'),
                        ),
                        IconButton(
                          tooltip: MakeChessLocalization.phrase(
                              collapsed ? 'Развернуть' : 'Свернуть'),
                          onPressed: () =>
                              setDialogState(() => collapsed = !collapsed),
                          icon: Icon(
                              collapsed ? Icons.expand_more : Icons.minimize,
                              color: Colors.white70),
                        ),
                        IconButton(
                          tooltip: MakeChessLocalization.phrase('Закрыть'),
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  if (!collapsed) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: MakeChessLocalizedText(
                          '${_nameCtl.text.trim()} • $_type • '
                          '${_minutesCtl.text.trim()}+${_incrementCtl.text.trim()} • '
                          '${MakeChessLocalization.phrase('Участники')}: $_registeredParticipantCount • $_status',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                    if (mode == 'variants')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Row(
                          children: [
                            for (var index = 0;
                                index < variants.length;
                                index++) ...[
                              ChoiceChip(
                                selected: selectedVariant == index,
                                label: MakeChessLocalizedText(index == 0
                                    ? '1 • лучший'
                                    : '${index + 1} • хуже или равный'),
                                onSelected: (_) => setDialogState(() {
                                  selectedVariant = index;
                                  displayed = variants[index].toList();
                                }),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    if (mode == 'edit')
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: MakeChessLocalizedText(
                            'Перетащите игрока на другого, чтобы поменять их местами',
                            style: TextStyle(color: Colors.white60),
                          ),
                        ),
                      ),
                    if (finishedRound)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(82, 0, 40, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Center(
                                child: MakeChessLocalizedText(
                                  'Белые',
                                  style: TextStyle(
                                    color: Color(0xFFFFFF66),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 150),
                            Expanded(
                              child: Center(
                                child: MakeChessLocalizedText(
                                  'Чёрные',
                                  style: TextStyle(
                                    color: Color(0xFFFFFF66),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        itemCount: displayed.length ~/ 2,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final pairing = index < pairings.length
                              ? pairings[index]
                              : const <String, dynamic>{};
                          final result = '${pairing['result'] ?? '*'}';
                          return Row(
                            children: [
                              SizedBox(
                                width: 66,
                                child: MakeChessLocalizedText(
                                  '${MakeChessLocalization.phrase('Стол')} ${pairing['board'] ?? index + 1}',
                                  style: const TextStyle(color: Colors.white54),
                                ),
                              ),
                              playerCard(displayed[index * 2], true, index * 2),
                              SizedBox(
                                width: finishedRound ? 150 : 42,
                                child: Center(
                                  child: MakeChessLocalizedText(
                                    result == '*'
                                        ? '—'
                                        : result == '1/2-1/2'
                                            ? '½ - ½'
                                            : result.replaceAll('-', ' - '),
                                    style: TextStyle(
                                      color: finishedRound
                                          ? const Color(0xFFFFFF66)
                                          : Colors.white54,
                                      fontSize: finishedRound ? 26 : 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              playerCard(displayed[index * 2 + 1], false,
                                  index * 2 + 1),
                            ],
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!finishedRound &&
                              widget.organizerMode &&
                              !widget.previewMode) ...[
                            OutlinedButton.icon(
                              onPressed: () => setDialogState(() {
                                mode = 'edit';
                                displayed = <_EditableParticipant?>[
                                  for (final pairing in pairings) ...[
                                    _pairingParticipant(
                                        '${pairing['whiteId'] ?? ''}'),
                                    _pairingParticipant(
                                        '${pairing['blackId'] ?? ''}'),
                                  ],
                                ];
                              }),
                              icon: const Icon(Icons.edit_note),
                              label: const MakeChessLocalizedText(
                                'Настройка жеребьёвки',
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => setDialogState(() {
                                variants = _pairingVariants();
                                selectedVariant = 0;
                                mode = 'variants';
                                if (variants.isNotEmpty) {
                                  displayed = variants.first.toList();
                                }
                              }),
                              icon: const Icon(Icons.view_carousel_outlined),
                              label: const MakeChessLocalizedText(
                                'Варианты жеребьёвки',
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          OutlinedButton.icon(
                            onPressed: () async {
                              final text = _roundPairingsText(
                                round,
                                pairings,
                                detailed: detailed,
                              );
                              final ok = await LocalFileService.printText(
                                text,
                                fileName: 'pairings_round_$round.txt',
                              );
                              if (!ok && mounted) {
                                _message('Печать недоступна на этой платформе');
                              }
                            },
                            icon: const Icon(Icons.print_outlined),
                            label: const MakeChessLocalizedText('Печать'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(
                                  text: _roundPairingsText(round, pairings,
                                      detailed: detailed)));
                              _message('Жеребьёвка скопирована');
                            },
                            icon: const Icon(Icons.copy_outlined),
                            label: const MakeChessLocalizedText('Копировать'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () async {
                              final text = _roundPairingsText(
                                round,
                                pairings,
                                detailed: detailed,
                              );
                              await LocalFileService.saveText(
                                suggestedName: 'pairings_round_$round.txt',
                                text: text,
                                initialDirectory: await TournamentStorageService
                                    .instance.localFolderPath,
                              );
                            },
                            icon: const Icon(Icons.save_alt),
                            label: const MakeChessLocalizedText('Сохранить'),
                          ),
                        ],
                      ),
                    ),
                    if (!finishedRound)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF16834F),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () async {
                              if (mode != 'view') {
                                await _applyPairingOrder(
                                  displayed,
                                  replaceRound: round,
                                  reopen: false,
                                );
                              }
                              await _save();
                              if (!mounted) return;
                              final navigator = Navigator.of(dialogContext);
                              final closePairingControl = _pairingControlOpen;
                              navigator.pop();
                              if (closePairingControl && navigator.canPop()) {
                                navigator.pop();
                              }
                            },
                            icon: const Icon(Icons.check_circle_outline,
                                size: 25),
                            label: const MakeChessLocalizedText(
                              'Принять жеребьёвку',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
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

  List<int> get _pairedRounds {
    final source = _pairingSchedule.isNotEmpty ? _pairingSchedule : _pairings;
    final rounds = source
        .map((pairing) => (pairing['round'] as num?)?.toInt() ?? 1)
        .where((round) => round > 0)
        .toSet()
        .toList();
    rounds.sort();
    return rounds;
  }

  Widget _buildRoundPairingButtons() {
    final rounds = _pairedRounds;
    final configuredRounds = int.tryParse(_roundsCtl.text.trim()) ?? 0;
    final totalRounds = math.max(
      configuredRounds,
      rounds.isEmpty ? 1 : rounds.last,
    );
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: MakeChessLocalizedText(
                'Игровые пары:',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final round in rounds) ...[
              OutlinedButton.icon(
                onPressed: () => _openRoundPairings(round),
                icon: const Icon(Icons.groups_2_outlined, size: 18),
                label: MakeChessLocalizedText('$round/$totalRounds'),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _prettyHead(String text, double width, {VoidCallback? onTap}) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        child: Container(
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
            InkWell(
              onTap: widget.organizerMode && _offlineMode
                  ? () => _editParticipant(row)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    _avatar(person),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MakeChessLocalizedText(
                        person.name.trim().isEmpty
                            ? (_offlineMode
                                ? 'Нажмите, чтобы записать игрока'
                                : '—')
                            : person.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: person.name.trim().isEmpty
                              ? Colors.cyanAccent
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: person.name.trim().isEmpty ? 11 : 14,
                        ),
                      ),
                    ),
                    if (widget.organizerMode && _offlineMode)
                      const Icon(Icons.edit_outlined,
                          size: 16, color: Colors.white38),
                  ],
                ),
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
          for (var column = 0; column < _resultColumnCount; column++)
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
    if (!_isSwissTournament && row == column) {
      return _prettyCell(
        48,
        const MakeChessLocalizedText('×',
            style: TextStyle(color: Colors.white30, fontSize: 18)),
        background: const Color(0xFF1A2A38),
      );
    }
    final value = _results[_resultKey(row, column)] ?? '—';
    if (_isSwissTournament) {
      final pairing = _swissPairingFor(row, column);
      final participantId = _participants[row].id;
      final isWhite = '${pairing?['whiteId'] ?? ''}' == participantId;
      final opponentId = '${pairing?[isWhite ? 'blackId' : 'whiteId'] ?? ''}';
      final opponentIndex = _participants
          .indexWhere((participant) => participant.id == opponentId);
      Widget field(String text, VoidCallback onTap) => Expanded(
            child: InkWell(
              onTap: widget.organizerMode && !widget.previewMode ? onTap : null,
              child: Center(
                child: MakeChessLocalizedText(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
      return _prettyCell(
        66,
        Column(
          children: [
            field(opponentIndex < 0 ? '—' : '${opponentIndex + 1}',
                () => _editSwissOpponent(row, column)),
            field(pairing == null ? '—' : (isWhite ? 'Б' : 'Ч'),
                () => _editSwissColor(row, column)),
            field(value, () => _editSwissResult(row, column)),
          ],
        ),
      );
    }
    return _prettyCell(
      48,
      MakeChessLocalizedText(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          height: 1.15,
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

  Widget _titleRestrictionsField() {
    final label = _allowedTitles.isEmpty
        ? 'Без ограничений — может играть любой'
        : _allowedTitles.join(', ');
    return PopupMenuButton<String>(
      tooltip: 'Выбрать допустимые звания',
      onSelected: (value) {
        setState(() {
          if (value == '__any__') {
            _allowedTitles.clear();
          } else if (_allowedTitles.contains(value)) {
            _allowedTitles.remove(value);
          } else {
            _allowedTitles.add(value);
          }
        });
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        CheckedPopupMenuItem<String>(
          value: '__any__',
          checked: _allowedTitles.isEmpty,
          child: const MakeChessLocalizedText(
              'Без ограничений — может играть любой'),
        ),
        const PopupMenuDivider(),
        for (final title in _chessTitles)
          CheckedPopupMenuItem<String>(
            value: title,
            checked: _allowedTitles.contains(title),
            child: MakeChessLocalizedText(title),
          ),
      ],
      child: InputDecorator(
        decoration: _decoration('Допустимые шахматные звания'),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool numeric = false,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(label),
      onChanged: onChanged,
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

  Widget _readonlyValue(String label, String value) => InputDecorator(
        decoration: _decoration(label),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 16, color: _gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  Widget _buildTableConstructor() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _panel2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          const Icon(Icons.view_column_outlined, color: _gold),
          const SizedBox(width: 10),
          const MakeChessLocalizedText(
            'Столбцы турнирной таблицы',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0;
                      index < _customColumns.length;
                      index++) ...[
                    InputChip(
                      label: Text(_customColumns[index]),
                      onPressed: widget.previewMode
                          ? null
                          : () => _editCustomColumn(index),
                      onDeleted: widget.previewMode
                          ? null
                          : () => _removeCustomColumn(index),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: widget.previewMode ? null : _addCustomColumn,
            icon: const Icon(Icons.add),
            label: const MakeChessLocalizedText('Добавить столбец'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCustomColumn() async {
    final name = await _askCustomColumnName('Новый столбец');
    if (name == null) return;
    setState(() => _customColumns.add(name));
  }

  Future<void> _editCustomColumn(int index) async {
    final name = await _askCustomColumnName(_customColumns[index]);
    if (name == null || !mounted) return;
    setState(() => _customColumns[index] = name);
  }

  void _removeCustomColumn(int index) {
    setState(() {
      _customColumns.removeAt(index);
      _customColumnValues.removeWhere((key, _) => key.startsWith('$index:'));
    });
  }

  Future<String?> _askCustomColumnName(String initialValue) async {
    final controller = TextEditingController(
      text: initialValue == 'Новый столбец' ? '' : initialValue,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel2,
        title: const MakeChessLocalizedText('Название нового столбца'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Название столбца',
            hintText: 'Например: Команда',
          ),
          onSubmitted: (value) {
            final name = value.trim();
            if (name.isNotEmpty) Navigator.pop(dialogContext, name);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const MakeChessLocalizedText('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.pop(dialogContext, name);
            },
            child: const MakeChessLocalizedText('Добавить'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Widget _buildTable() {
    final count = _participants.length;
    final resultColumnCount = _resultColumnCount;
    final resultCellWidth = _isSwissTournament ? 72.0 : 54.0;
    final matrixWidth = resultColumnCount * resultCellWidth;
    final customWidth = _customColumns.length * 140.0;
    final tableHeight = math.min(520.0, 54.0 + count * 66.0 + 54.0);
    return SizedBox(
      height: tableHeight,
      child: Container(
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _blue.withOpacity(0.45)),
        ),
        child: Column(
          children: [
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 84 +
                        260 +
                        92 +
                        230 +
                        customWidth +
                        matrixWidth +
                        92 +
                        105 * 3 +
                        82,
                    child: Column(
                      children: [
                        _tableHeader(resultColumnCount),
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: count,
                            itemExtent: 66,
                            itemBuilder: (_, row) => _participantRow(row),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
          for (final name in _customColumns) _head(name, 140),
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
          for (var column = 0; column < _customColumns.length; column++)
            _customColumnCell(row, column),
          for (var column = 0; column < _resultColumnCount; column++)
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

  Widget _customColumnCell(int row, int column) {
    final key = '$column:$row';
    return _cell(
      140,
      TextFormField(
        key: ValueKey('custom-column-$column-$row'),
        initialValue: _customColumnValues[key] ?? '',
        style: const TextStyle(color: Colors.white),
        decoration: _tableInputDecoration(hint: _customColumns[column]),
        onChanged: (value) => _customColumnValues[key] = value,
      ),
    );
  }

  Widget _resultCell(int row, int column) {
    if (!_isSwissTournament && row == column) {
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
      _isSwissTournament ? 72 : 54,
      DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isDense: true,
          dropdownColor: _panel2,
          hint: MakeChessLocalizedText(
            _isSwissTournament ? _swissCellText(row, column, '—') : '—',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white30, fontSize: 11),
          ),
          icon: const Icon(Icons.arrow_drop_down,
              color: Colors.white38, size: 18),
          selectedItemBuilder: _isSwissTournament
              ? (_) => <Widget>[
                    for (final result in const <String?>[null, '1', '½', '0'])
                      Center(
                        child: MakeChessLocalizedText(
                          _swissCellText(row, column, result ?? '—'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            height: 1.05,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ]
              : null,
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
                if (!_isSwissTournament) {
                  final opposite = _resultKey(column, row);
                  _results[opposite] = next == '1'
                      ? '0'
                      : next == '0'
                          ? '1'
                          : '½';
                }
              }
              if (_isSwissTournament) {
                _setSwissPairingResult(row, column, next);
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
    final buttons = (widget.templateSchema?.buttons ??
            TournamentTemplateSchema.defaults.buttons)
        .where((button) =>
            button.action != TournamentTemplateAction.addParticipant &&
            button.action != TournamentTemplateAction.participate)
        .toList(growable: false);
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < buttons.length; index++) ...[
                  _templateActionButton(buttons[index]),
                  if (index != buttons.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF80601C),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          ),
          onPressed: widget.creatingNewTournament
              ? () => _saveAndClose(TournamentTableEditorResult.saved)
              : _returnToTournament,
          icon: Icon(
              widget.creatingNewTournament ? Icons.add_task : Icons.arrow_back),
          label: Text(widget.creatingNewTournament
              ? 'Сохранить новый турнир'
              : 'Вернуться к турниру'),
        ),
      ],
    );
  }

  Future<void> _returnToTournament() async {
    await _save();
    if (!mounted) return;
    setState(() => _showPreview = true);
  }

  Widget _templateActionButton(TournamentTemplateButton button) {
    final prominent = button.action == TournamentTemplateAction.startTournament;
    final pairing = button.action == TournamentTemplateAction.createPairing;
    final icon = switch (button.action) {
      TournamentTemplateAction.editData => Icons.edit_outlined,
      TournamentTemplateAction.save => Icons.save_outlined,
      TournamentTemplateAction.callTournament => Icons.notifications_outlined,
      TournamentTemplateAction.startTournament => Icons.play_arrow,
      TournamentTemplateAction.pauseTournament => Icons.pause,
      TournamentTemplateAction.finishTournament => Icons.stop_circle_outlined,
      TournamentTemplateAction.participate => Icons.person_add_alt_1,
      TournamentTemplateAction.addParticipant => Icons.person_add_alt,
      TournamentTemplateAction.removeParticipant => Icons.person_remove_alt_1,
      TournamentTemplateAction.createPairing => Icons.casino,
      TournamentTemplateAction.enterResult => Icons.scoreboard_outlined,
      TournamentTemplateAction.startRound => Icons.play_circle_outline,
      TournamentTemplateAction.finishRound => Icons.stop_circle_outlined,
      TournamentTemplateAction.recalculate => Icons.calculate_outlined,
      TournamentTemplateAction.publish => Icons.publish,
      TournamentTemplateAction.printTable => Icons.print,
    };
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: prominent
            ? const Color(0xFF167C4D)
            : pairing
                ? const Color(0xFF0D5A91)
                : const Color(0xFF8CCDEE),
        foregroundColor:
            prominent || pairing ? Colors.white : const Color(0xFF183347),
      ),
      onPressed: _templateActionAvailable(button)
          ? () => _runTemplateAction(button.action)
          : null,
      icon: Icon(icon),
      label: Text(
        pairing ? 'Настройка жеребьёвки' : button.label,
        style:
            TextStyle(fontWeight: pairing ? FontWeight.w800 : FontWeight.w500),
      ),
    );
  }

  bool _templateActionAvailable(TournamentTemplateButton button) {
    if (!button.enabled || widget.previewMode) return false;
    return switch (button.action) {
      TournamentTemplateAction.callTournament =>
        widget.onCallTournament != null,
      TournamentTemplateAction.startTournament ||
      TournamentTemplateAction.startRound =>
        widget.onStartTournament != null,
      TournamentTemplateAction.pauseTournament =>
        widget.onPauseTournament != null,
      TournamentTemplateAction.finishTournament ||
      TournamentTemplateAction.finishRound =>
        widget.onFinishTournament != null,
      TournamentTemplateAction.participate => widget.onParticipate != null,
      _ => true,
    };
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
    _minRatingCtl.dispose();
    _maxRatingCtl.dispose();
    _minAgeCtl.dispose();
    _maxAgeCtl.dispose();
    _birthYearFromCtl.dispose();
    _birthYearToCtl.dispose();
    super.dispose();
  }
}

class _PairingVariantsDialog extends StatefulWidget {
  const _PairingVariantsDialog({
    required this.variants,
    required this.manual,
  });

  final List<List<_EditableParticipant?>> variants;
  final bool manual;

  @override
  State<_PairingVariantsDialog> createState() => _PairingVariantsDialogState();
}

class _PairingVariantsDialogState extends State<_PairingVariantsDialog> {
  late final List<List<_EditableParticipant?>> _variants = widget.variants
      .map((variant) => variant.toList())
      .toList(growable: false);
  int _selected = 0;

  void _swap(int from, int to) {
    if (!widget.manual || from == to) return;
    setState(() {
      final value = _variants[_selected][from];
      _variants[_selected][from] = _variants[_selected][to];
      _variants[_selected][to] = value;
    });
  }

  Widget _player(int index) {
    final player = _variants[_selected][index];
    final card = Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color:
            player == null ? const Color(0xFF342719) : const Color(0xFF13293A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(player == null ? Icons.hourglass_empty : Icons.person,
              color:
                  player == null ? Colors.amberAccent : Colors.lightBlueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: MakeChessLocalizedText(
              player == null
                  ? 'Свободный тур • автопобеда'
                  : '${player.name} • ${player.rating}${player.age == null ? '' : ' • ${player.age} лет'}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.manual && player != null)
            const Icon(Icons.drag_indicator, color: Colors.white38),
        ],
      ),
    );
    if (!widget.manual || player == null) return card;
    return DragTarget<int>(
      onAcceptWithDetails: (details) => _swap(details.data, index),
      builder: (_, __, ___) => Draggable<int>(
        data: index,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: 300, child: card),
        ),
        childWhenDragging: Opacity(opacity: .35, child: card),
        child: card,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _variants[_selected];
    return AlertDialog(
      backgroundColor: const Color(0xFF0C1824),
      title: MakeChessLocalizedText(
          widget.manual ? 'Ручная жеребьёвка' : 'Варианты жеребьёвки'),
      content: SizedBox(
        width: 850,
        height: 560,
        child: Column(
          children: [
            DefaultTabController(
              length: _variants.length,
              child: TabBar(
                onTap: (index) => setState(() => _selected = index),
                tabs: [
                  for (var index = 0; index < _variants.length; index++)
                    Tab(
                      text: index == 0
                          ? '1 • лучший'
                          : '${index + 1} • хуже или равный',
                    ),
                ],
              ),
            ),
            if (widget.manual)
              const Padding(
                padding: EdgeInsets.all(10),
                child: MakeChessLocalizedText(
                  'Перетащите игрока на другого игрока, чтобы поменять их местами',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: current.length ~/ 2,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, board) {
                  final first = board * 2;
                  return Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: MakeChessLocalizedText('Стол ${board + 1}'),
                      ),
                      Expanded(child: _player(first)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child:
                            Text('—', style: TextStyle(color: Colors.white54)),
                      ),
                      Expanded(child: _player(first + 1)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const MakeChessLocalizedText('Отмена'),
        ),
        if (widget.manual)
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, _variants[_selected]),
            icon: const Icon(Icons.check),
            label: const MakeChessLocalizedText('Применить вариант'),
          ),
      ],
    );
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
