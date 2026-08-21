import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_style.dart';
import '../../localization/makechess_localization.dart';

/// Режим антизевкового задания.
///
/// direct  — ученик должен не допустить собственный зевок.
/// reverse — ученик должен не пропустить зевок соперника.
enum AntiBlunderMode {
  direct,
  reverse,
}

/// Результат проверки одного хода-кандидата относительно эталона учителя.
enum AntiBlunderCandidateStatus {
  /// Ход входит в заданный учителем коридор безопасности.
  safe,

  /// Ход входит в заданную учителем зону зевка.
  blunder,

  /// Учитель этот ход не классифицировал.
  ///
  /// ВАЖНО: такой ход нельзя автоматически считать ошибкой ученика.
  /// Это защищает систему от ложного штрафа, если учитель отметил
  /// только существенные кандидаты, а не все легальные ходы позиции.
  unclassified,
}

/// Один ход, задаваемый стрелкой на доске.
@immutable
class AntiBlunderMove {
  const AntiBlunderMove({
    required this.from,
    required this.to,
  });

  final String from;
  final String to;

  String get key => '${from.trim().toLowerCase()}->${to.trim().toLowerCase()}';

  bool get isValid =>
      from.trim().isNotEmpty &&
      to.trim().isNotEmpty &&
      from.trim().toLowerCase() != to.trim().toLowerCase();

  factory AntiBlunderMove.fromJson(Map<String, dynamic> json) {
    return AntiBlunderMove(
      from: '${json['from'] ?? json['start'] ?? ''}'.trim(),
      to: '${json['to'] ?? json['end'] ?? ''}'.trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'from': from,
      'to': to,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is AntiBlunderMove && other.key == key;
  }

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => key;
}

/// Линия наказания после зевочного кандидата.
///
/// Сам ход-кандидат сюда НЕ входит.
/// moves[0] — первый ответ после кандидата,
/// moves[1] — следующий ход и т.д.
///
/// Поэтому глубину можно увеличивать без изменения самой модели задания.
@immutable
class AntiBlunderPunishmentLine {
  const AntiBlunderPunishmentLine({
    required this.id,
    required this.moves,
    this.comment = '',
  });

  final String id;
  final List<AntiBlunderMove> moves;
  final String comment;

  factory AntiBlunderPunishmentLine.fromJson(Map<String, dynamic> json) {
    final raw = json['moves'];
    final parsed = <AntiBlunderMove>[];

    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final move = AntiBlunderMove.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (move.isValid) parsed.add(move);
        }
      }
    }

    return AntiBlunderPunishmentLine(
      id: '${json['id'] ?? ''}'.trim(),
      moves: List<AntiBlunderMove>.unmodifiable(parsed),
      comment: '${json['comment'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'moves': moves.map((move) => move.toJson()).toList(growable: false),
      'comment': comment,
    };
  }
}

/// Одна зона зевка.
///
/// candidate — ход ученика, который выходит из коридора безопасности.
/// punishmentLines — одна или несколько линий, показывающих почему
/// этот кандидат является зевком.
@immutable
class AntiBlunderZone {
  const AntiBlunderZone({
    required this.candidate,
    this.punishmentLines = const <AntiBlunderPunishmentLine>[],
    this.comment = '',
  });

  final AntiBlunderMove candidate;
  final List<AntiBlunderPunishmentLine> punishmentLines;
  final String comment;

  factory AntiBlunderZone.fromJson(Map<String, dynamic> json) {
    final rawCandidate = json['candidate'];
    final candidate = rawCandidate is Map
        ? AntiBlunderMove.fromJson(
            Map<String, dynamic>.from(rawCandidate),
          )
        : const AntiBlunderMove(from: '', to: '');

    final rawLines = json['punishmentLines'] ?? json['punishment_lines'];
    final lines = <AntiBlunderPunishmentLine>[];

    if (rawLines is List) {
      for (final item in rawLines) {
        if (item is Map) {
          lines.add(
            AntiBlunderPunishmentLine.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    return AntiBlunderZone(
      candidate: candidate,
      punishmentLines: List<AntiBlunderPunishmentLine>.unmodifiable(lines),
      comment: '${json['comment'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'candidate': candidate.toJson(),
      'punishmentLines':
          punishmentLines.map((line) => line.toJson()).toList(growable: false),
      'comment': comment,
    };
  }
}

/// Эталон антизевкового задания, созданный тренером.
///
/// ВАЖНАЯ АРХИТЕКТУРА:
///
/// safetyCorridor — ходы, которые тренер считает допустимыми;
/// blunderZones   — ходы, которые тренер специально отметил как зевки;
/// всё остальное  — НЕ КЛАССИФИЦИРОВАНО и автоматически не штрафуется.
///
/// Это позволяет тренеру не перечислять все легальные ходы позиции.
@immutable
class AntiBlunderTaskSpec {
  const AntiBlunderTaskSpec({
    required this.mode,
    required this.depth,
    this.safetyCorridor = const <AntiBlunderMove>[],
    this.blunderZones = const <AntiBlunderZone>[],
  }) : assert(depth >= 1);

  final AntiBlunderMode mode;

  /// Глубина анализа.
  ///
  /// На первом этапе храним как универсальное целое число.
  /// Конкретное отображение "1, 2, 3..." в интерфейсе можно менять,
  /// не меняя формат задания.
  final int depth;

  /// Коридор безопасности.
  final List<AntiBlunderMove> safetyCorridor;

  /// Зоны зевка с объясняющими линиями.
  final List<AntiBlunderZone> blunderZones;

  Set<String> get _safeKeys => safetyCorridor
      .where((move) => move.isValid)
      .map((move) => move.key)
      .toSet();

  Map<String, AntiBlunderZone> get _zonesByKey {
    final result = <String, AntiBlunderZone>{};
    for (final zone in blunderZones) {
      if (zone.candidate.isValid) {
        result[zone.candidate.key] = zone;
      }
    }
    return result;
  }

  AntiBlunderCandidateStatus classify(AntiBlunderMove move) {
    final key = move.key;

    if (_safeKeys.contains(key)) {
      return AntiBlunderCandidateStatus.safe;
    }

    if (_zonesByKey.containsKey(key)) {
      return AntiBlunderCandidateStatus.blunder;
    }

    return AntiBlunderCandidateStatus.unclassified;
  }

  AntiBlunderZone? zoneFor(AntiBlunderMove move) {
    return _zonesByKey[move.key];
  }

  /// Проверка целостности задания.
  ///
  /// Один и тот же ход не должен одновременно находиться
  /// и в коридоре безопасности, и в зоне зевка.
  List<String> validate() {
    final problems = <String>[];
    final safe = _safeKeys;
    final zones = _zonesByKey.keys.toSet();

    final conflict = safe.intersection(zones);
    for (final key in conflict) {
      problems.add(
        'Ход $key одновременно находится в коридоре безопасности и в зоне зевка.',
      );
    }

    if (depth < 1) {
      problems.add('Глубина должна быть не меньше 1.');
    }

    return problems;
  }

  factory AntiBlunderTaskSpec.fromJson(Map<String, dynamic> json) {
    final rawMode = '${json['mode'] ?? 'direct'}'.trim().toLowerCase();
    final mode =
        rawMode == 'reverse' ? AntiBlunderMode.reverse : AntiBlunderMode.direct;

    final rawDepth = json['depth'];
    final parsedDepth =
        rawDepth is num ? rawDepth.toInt() : int.tryParse('$rawDepth') ?? 1;

    final corridor = <AntiBlunderMove>[];
    final rawCorridor = json['safetyCorridor'] ?? json['safety_corridor'];

    if (rawCorridor is List) {
      for (final item in rawCorridor) {
        if (item is Map) {
          final move = AntiBlunderMove.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (move.isValid) corridor.add(move);
        }
      }
    }

    final zones = <AntiBlunderZone>[];
    final rawZones = json['blunderZones'] ?? json['blunder_zones'];

    if (rawZones is List) {
      for (final item in rawZones) {
        if (item is Map) {
          final zone = AntiBlunderZone.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (zone.candidate.isValid) zones.add(zone);
        }
      }
    }

    return AntiBlunderTaskSpec(
      mode: mode,
      depth: parsedDepth < 1 ? 1 : parsedDepth,
      safetyCorridor: List<AntiBlunderMove>.unmodifiable(corridor),
      blunderZones: List<AntiBlunderZone>.unmodifiable(zones),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mode': mode.name,
      'depth': depth,
      'safetyCorridor':
          safetyCorridor.map((move) => move.toJson()).toList(growable: false),
      'blunderZones':
          blunderZones.map((zone) => zone.toJson()).toList(growable: false),
    };
  }
}

/// Проверка одного нарисованного учеником хода-кандидата.
@immutable
class AntiBlunderCandidateCheck {
  const AntiBlunderCandidateCheck({
    required this.move,
    required this.status,
    this.zone,
  });

  final AntiBlunderMove move;
  final AntiBlunderCandidateStatus status;
  final AntiBlunderZone? zone;

  bool get insideSafetyCorridor => status == AntiBlunderCandidateStatus.safe;

  bool get insideBlunderZone => status == AntiBlunderCandidateStatus.blunder;
}

/// Итог проверки набора ходов-кандидатов ученика.
///
/// Здесь намеренно хранятся НЕ только "правильно/неправильно".
/// Нам нужны отдельные измеряемые показатели для будущего графика успеваемости.
@immutable
class AntiBlunderCandidateSummary {
  const AntiBlunderCandidateSummary({
    required this.items,
    required this.safeCandidateCount,
    required this.blunderCandidateCount,
    required this.unclassifiedCandidateCount,
    required this.foundCorridorMoveCount,
    required this.totalCorridorMoveCount,
  });

  final List<AntiBlunderCandidateCheck> items;

  /// Сколько кандидатов ученика попали в коридор безопасности.
  final int safeCandidateCount;

  /// Сколько кандидатов ученика попали в зоны зевка.
  final int blunderCandidateCount;

  /// Сколько кандидатов тренер не классифицировал.
  final int unclassifiedCandidateCount;

  /// Сколько различных ходов из коридора безопасности ученик сам нашёл.
  final int foundCorridorMoveCount;

  /// Сколько ходов всего задал тренер в коридоре безопасности.
  final int totalCorridorMoveCount;

  int get classifiedCandidateCount =>
      safeCandidateCount + blunderCandidateCount;

  /// Качество набора кандидатов ученика.
  ///
  /// Неизвестные тренеру ходы сюда не входят.
  double get safetyRate {
    final total = classifiedCandidateCount;
    if (total == 0) return 0;
    return safeCandidateCount / total;
  }

  /// Насколько полно ученик увидел коридор безопасности.
  ///
  /// Этот показатель можно использовать только там, где тренер
  /// действительно ожидает поиск всех безопасных кандидатов.
  double get corridorCoverage {
    if (totalCorridorMoveCount == 0) return 0;
    return foundCorridorMoveCount / totalCorridorMoveCount;
  }
}

/// Результат проверки объясняющей линии после зевочного кандидата.
@immutable
class AntiBlunderLineCheck {
  const AntiBlunderLineCheck({
    required this.matched,
    required this.matchedMoveCount,
    required this.expectedMoveCount,
    this.matchedTeacherLineId,
  });

  final bool matched;
  final int matchedMoveCount;
  final int expectedMoveCount;
  final String? matchedTeacherLineId;
}

/// Чистая логика антизевкового тренажёра.
///
/// Этот класс НЕ знает ничего про конкретный Flutter-виджет доски.
/// main.dart сможет передавать сюда уже существующие стрелки как
/// AntiBlunderMove(from: ..., to: ...).
///
/// Благодаря этому тренажёр не копирует существующую доску и не ломает
/// текущий механизм задач.
class AntiBlunderTrainerController extends ChangeNotifier {
  AntiBlunderTaskSpec? _task;
  final List<AntiBlunderMove> _studentCandidates = <AntiBlunderMove>[];
  AntiBlunderMode _authorMode = AntiBlunderMode.direct;
  int _authorDepth = 1;

  AntiBlunderTaskSpec? get task => _task;
  AntiBlunderMode get authorMode => _authorMode;
  int get authorDepth => _authorDepth;

  List<AntiBlunderMove> get studentCandidates =>
      List<AntiBlunderMove>.unmodifiable(_studentCandidates);

  bool get hasTask => _task != null;

  void setAuthorMode(AntiBlunderMode mode) {
    if (_authorMode == mode) return;
    _authorMode = mode;
    notifyListeners();
  }

  void setAuthorDepth(int depth) {
    final clean = depth < 1 ? 1 : depth;
    if (_authorDepth == clean) return;
    _authorDepth = clean;
    notifyListeners();
  }

  void resetAuthoring() {
    _authorMode = AntiBlunderMode.direct;
    _authorDepth = 1;
    notifyListeners();
  }

  void loadTask(AntiBlunderTaskSpec task) {
    _task = task;
    _studentCandidates.clear();
    notifyListeners();
  }

  void clearTask() {
    _task = null;
    _studentCandidates.clear();
    notifyListeners();
  }

  void clearStudentCandidates() {
    if (_studentCandidates.isEmpty) return;
    _studentCandidates.clear();
    notifyListeners();
  }

  void addStudentCandidate(AntiBlunderMove move) {
    if (!move.isValid) return;
    if (_studentCandidates.contains(move)) return;
    _studentCandidates.add(move);
    notifyListeners();
  }

  void removeStudentCandidate(AntiBlunderMove move) {
    if (_studentCandidates.remove(move)) {
      notifyListeners();
    }
  }

  AntiBlunderCandidateSummary checkCandidates() {
    final current = _task;

    if (current == null) {
      return const AntiBlunderCandidateSummary(
        items: <AntiBlunderCandidateCheck>[],
        safeCandidateCount: 0,
        blunderCandidateCount: 0,
        unclassifiedCandidateCount: 0,
        foundCorridorMoveCount: 0,
        totalCorridorMoveCount: 0,
      );
    }

    var safeCount = 0;
    var blunderCount = 0;
    var unclassifiedCount = 0;

    final items = <AntiBlunderCandidateCheck>[];
    final foundSafeKeys = <String>{};

    for (final move in _studentCandidates) {
      final status = current.classify(move);

      switch (status) {
        case AntiBlunderCandidateStatus.safe:
          safeCount++;
          foundSafeKeys.add(move.key);
          break;
        case AntiBlunderCandidateStatus.blunder:
          blunderCount++;
          break;
        case AntiBlunderCandidateStatus.unclassified:
          unclassifiedCount++;
          break;
      }

      items.add(
        AntiBlunderCandidateCheck(
          move: move,
          status: status,
          zone: current.zoneFor(move),
        ),
      );
    }

    final teacherSafeKeys = current.safetyCorridor
        .where((move) => move.isValid)
        .map((move) => move.key)
        .toSet();

    return AntiBlunderCandidateSummary(
      items: List<AntiBlunderCandidateCheck>.unmodifiable(items),
      safeCandidateCount: safeCount,
      blunderCandidateCount: blunderCount,
      unclassifiedCandidateCount: unclassifiedCount,
      foundCorridorMoveCount:
          foundSafeKeys.intersection(teacherSafeKeys).length,
      totalCorridorMoveCount: teacherSafeKeys.length,
    );
  }

  /// Проверяет, смог ли ученик объяснить, ПОЧЕМУ выбранный кандидат является
  /// зевком.
  ///
  /// Если тренер задал несколько допустимых линий наказания,
  /// выбирается наиболее совпавшая.
  AntiBlunderLineCheck checkPunishmentLine({
    required AntiBlunderMove candidate,
    required List<AntiBlunderMove> studentLine,
  }) {
    final current = _task;
    final zone = current?.zoneFor(candidate);

    if (zone == null || zone.punishmentLines.isEmpty) {
      return const AntiBlunderLineCheck(
        matched: false,
        matchedMoveCount: 0,
        expectedMoveCount: 0,
      );
    }

    AntiBlunderPunishmentLine? bestLine;
    var bestMatched = -1;

    for (final teacherLine in zone.punishmentLines) {
      final limit = studentLine.length < teacherLine.moves.length
          ? studentLine.length
          : teacherLine.moves.length;

      var matched = 0;
      for (var i = 0; i < limit; i++) {
        if (studentLine[i] != teacherLine.moves[i]) break;
        matched++;
      }

      if (matched > bestMatched) {
        bestMatched = matched;
        bestLine = teacherLine;
      }

      if (matched == teacherLine.moves.length &&
          studentLine.length == teacherLine.moves.length) {
        return AntiBlunderLineCheck(
          matched: true,
          matchedMoveCount: matched,
          expectedMoveCount: teacherLine.moves.length,
          matchedTeacherLineId: teacherLine.id,
        );
      }
    }

    final expected = bestLine?.moves.length ?? 0;

    return AntiBlunderLineCheck(
      matched: false,
      matchedMoveCount: bestMatched < 0 ? 0 : bestMatched,
      expectedMoveCount: expected,
      matchedTeacherLineId: bestLine?.id,
    );
  }
}

/// Короткое описание опубликованной задачи для списка внутри окна
/// антизевкового тренажёра. Сам PuzzleTask сюда не импортируем, чтобы
/// anti_blunder_trainer.dart оставался независимым от puzzle_task.dart.
@immutable
class AntiBlunderTaskListItem {
  const AntiBlunderTaskListItem({
    required this.number,
    required this.title,
    required this.mode,
    required this.depth,
  });

  final int number;
  final String title;
  final AntiBlunderMode mode;
  final int depth;
}

/// Самостоятельное плавающее окно антизевкового тренажёра.
///
/// Архитектурный принцип: общая панель «Задачи» только открывает этот режим.
/// Всё управление тренажёром — выбор задания, режим ученика, настройка учителя,
/// создание эталона, публикация и проверка — находится внутри этого окна.
class AntiBlunderTrainerDialog extends StatefulWidget {
  const AntiBlunderTrainerDialog({
    super.key,
    required this.controller,
    required this.width,
    required this.height,
    required this.onDragDelta,
    required this.onResize,
    required this.onClose,
    required this.settingsMode,
    required this.onSettingsModeChanged,
    required this.publishedTasks,
    required this.activeTaskIndex,
    required this.loadingTasks,
    required this.onOpenTasks,
    required this.onTaskSelected,
    required this.onPreviousTask,
    required this.onNextTask,
    required this.drawingCandidates,
    required this.studentCandidateCount,
    required this.onToggleCandidateDrawing,
    required this.onClearCandidates,
    required this.onBeforeCheck,
    required this.draftTitle,
    required this.draftNumber,
    required this.currentFen,
    required this.startFen,
    required this.savedLines,
    required this.currentLine,
    required this.isRecordingLine,
    required this.isPublished,
    required this.activeAuthorAnalysisKey,
    required this.authorAnalysisCounts,
    required this.authorAnalysisSide,
    required this.authorDrawingEnabled,
    required this.authorShowAnswer,
    required this.onDraftTitleChanged,
    required this.onDraftNumberChanged,
    required this.onAuthorModeChanged,
    required this.onAuthorDepthChanged,
    required this.onTogglePositionEditor,
    required this.onSetInitialPosition,
    required this.onStartRecordingLine,
    required this.onFinishRecordingLine,
    required this.onClearDraft,
    required this.onNewTask,
    required this.onPublish,
    required this.onDownload,
    required this.onCopyJson,
    required this.onAuthorAnalysisModeChanged,
    required this.onAuthorAnalysisSideToggle,
    required this.onToggleAuthorDrawing,
    required this.onFinishAuthorAnalysis,
    required this.onAuthorShowAnswerChanged,
    required this.onClearAuthorAnalysisElements,
  });

  final AntiBlunderTrainerController controller;
  final double width;
  final double height;

  /// Перемещение от исходной позиции окна в момент начала drag.
  final ValueChanged<Offset> onDragDelta;

  /// Новый размер окна. Размер хранится в main.dart, чтобы окно не прыгало
  /// при перестроениях внешнего Stack.
  final ValueChanged<Size> onResize;
  final VoidCallback onClose;

  final bool settingsMode;
  final ValueChanged<bool> onSettingsModeChanged;

  final List<AntiBlunderTaskListItem> publishedTasks;
  final int activeTaskIndex;
  final bool loadingTasks;
  final Future<void> Function() onOpenTasks;
  final ValueChanged<int> onTaskSelected;
  final VoidCallback onPreviousTask;
  final VoidCallback onNextTask;

  final bool drawingCandidates;
  final int studentCandidateCount;
  final VoidCallback onToggleCandidateDrawing;
  final VoidCallback onClearCandidates;
  final VoidCallback onBeforeCheck;

  final String draftTitle;
  final int draftNumber;
  final String currentFen;
  final String? startFen;
  final List<List<String>> savedLines;
  final List<String> currentLine;
  final bool isRecordingLine;
  final bool isPublished;

  final String? activeAuthorAnalysisKey;
  final Map<String, Map<String, int>> authorAnalysisCounts;
  final String authorAnalysisSide;
  final bool authorDrawingEnabled;
  final bool authorShowAnswer;

  final ValueChanged<String> onDraftTitleChanged;
  final ValueChanged<int> onDraftNumberChanged;
  final ValueChanged<AntiBlunderMode> onAuthorModeChanged;
  final ValueChanged<int> onAuthorDepthChanged;
  final VoidCallback onTogglePositionEditor;
  final VoidCallback onSetInitialPosition;
  final VoidCallback onStartRecordingLine;
  final VoidCallback onFinishRecordingLine;
  final VoidCallback onClearDraft;
  final VoidCallback onNewTask;
  final Future<void> Function() onPublish;
  final Future<void> Function() onDownload;
  final Future<void> Function() onCopyJson;

  final ValueChanged<String?> onAuthorAnalysisModeChanged;
  final VoidCallback onAuthorAnalysisSideToggle;
  final VoidCallback onToggleAuthorDrawing;
  final VoidCallback onFinishAuthorAnalysis;
  final ValueChanged<bool> onAuthorShowAnswerChanged;
  final VoidCallback onClearAuthorAnalysisElements;

  @override
  State<AntiBlunderTrainerDialog> createState() =>
      _AntiBlunderTrainerDialogState();
}

class _AntiBlunderTrainerDialogState extends State<AntiBlunderTrainerDialog> {
  AntiBlunderCandidateSummary? _summary;
  bool _collapsed = false;
  bool _publishing = false;
  bool _downloading = false;
  bool _opening = false;

  Offset? _dragStartGlobalPosition;
  ValueChanged<Offset>? _dragHandlerAtStart;

  Offset? _resizeStartGlobalPosition;
  Size? _resizeStartSize;
  ValueChanged<Size>? _resizeHandlerAtStart;

  late final TextEditingController _titleController;
  late final TextEditingController _numberController;
  late final TextEditingController _statsParticipantController;
  late final TextEditingController _statsReviewerController;
  late final TextEditingController _statsPeriodController;
  int _statsTab = 0;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.draftTitle);
    _numberController = TextEditingController(text: '${widget.draftNumber}');
    _statsParticipantController = TextEditingController();
    _statsReviewerController = TextEditingController();
    _statsPeriodController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant AntiBlunderTrainerDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.task != widget.controller.task) {
      _summary = null;
    }
    if (oldWidget.draftTitle != widget.draftTitle &&
        _titleController.text != widget.draftTitle) {
      _titleController.text = widget.draftTitle;
    }
    if (oldWidget.draftNumber != widget.draftNumber &&
        _numberController.text != '${widget.draftNumber}') {
      _numberController.text = '${widget.draftNumber}';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _numberController.dispose();
    _statsParticipantController.dispose();
    _statsReviewerController.dispose();
    _statsPeriodController.dispose();
    super.dispose();
  }

  String _modeTitle(AntiBlunderMode mode) {
    return mode == AntiBlunderMode.reverse ? 'Обратный зевок' : 'Прямой зевок';
  }

  void _check() {
    widget.onBeforeCheck();
    setState(() {
      _summary = widget.controller.checkCandidates();
    });
  }

  void _clearCandidates() {
    widget.onClearCandidates();
    setState(() => _summary = null);
  }

  Future<void> _openTasks() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await widget.onOpenTasks();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _publish() async {
    if (_publishing) return;
    setState(() => _publishing = true);
    try {
      await widget.onPublish();
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      await widget.onDownload();
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _startWindowDrag(DragStartDetails details) {
    _dragStartGlobalPosition = details.globalPosition;
    _dragHandlerAtStart = widget.onDragDelta;
  }

  void _updateWindowDrag(DragUpdateDetails details) {
    final start = _dragStartGlobalPosition;
    final handler = _dragHandlerAtStart;
    if (start == null || handler == null) return;
    handler(details.globalPosition - start);
  }

  void _endWindowDrag() {
    _dragStartGlobalPosition = null;
    _dragHandlerAtStart = null;
  }

  void _startResize(DragStartDetails details) {
    _resizeStartGlobalPosition = details.globalPosition;
    _resizeStartSize = Size(widget.width, widget.height);
    _resizeHandlerAtStart = widget.onResize;
  }

  void _updateResize(DragUpdateDetails details) {
    final start = _resizeStartGlobalPosition;
    final startSize = _resizeStartSize;
    final handler = _resizeHandlerAtStart;
    if (start == null || startSize == null || handler == null) return;
    final delta = details.globalPosition - start;
    handler(Size(startSize.width + delta.dx, startSize.height + delta.dy));
  }

  void _endResize() {
    _resizeStartGlobalPosition = null;
    _resizeStartSize = null;
    _resizeHandlerAtStart = null;
  }

  Widget _headerButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    bool active = false,
  }) {
    return IconButton(
      tooltip: MakeChessLocalization.phrase(tooltip),
      visualDensity: VisualDensity.compact,
      splashRadius: 18,
      onPressed: onPressed,
      color: active ? AppColors.accent : AppColors.textDim,
      hoverColor: AppColors.accentGlowSoft,
      icon: Icon(icon, size: 19),
    );
  }

  Widget _header() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.neoButtonTop,
            AppColors.neoButtonMid,
            AppColors.neoButtonBottom,
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.borderSoft),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: _startWindowDrag,
              onPanUpdate: _updateWindowDrag,
              onPanEnd: (_) => _endWindowDrag(),
              onPanCancel: _endWindowDrag,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    const MakeChessLocalizedText(
                      'Антизевковый тренажёр',
                      style: AppTextStyles.panelTitle,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: MakeChessLocalizedText(
                        widget.settingsMode
                            ? 'Режим настройки'
                            : 'Режим ученика',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _headerButton(
            tooltip: 'Настройка',
            icon: Icons.settings_outlined,
            active: widget.settingsMode,
            onPressed: () => widget.onSettingsModeChanged(!widget.settingsMode),
          ),
          _headerButton(
            tooltip: _collapsed ? 'Развернуть' : 'Свернуть',
            icon: _collapsed
                ? Icons.keyboard_arrow_up
                : Icons.keyboard_arrow_down,
            onPressed: () => setState(() => _collapsed = !_collapsed),
          ),
          _headerButton(
            tooltip: 'Закрыть',
            icon: Icons.close,
            onPressed: widget.onClose,
          ),
          const SizedBox(width: 3),
        ],
      ),
    );
  }

  Widget _neoButton({
    required String text,
    required IconData icon,
    required VoidCallback? onTap,
    bool active = false,
    Widget? iconWidget,
  }) {
    return SizedBox(
      height: 38,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: active ? AppColors.accent : AppColors.surfaceCard,
          foregroundColor: active ? Colors.white : AppColors.text,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          side: BorderSide(
            color: active ? AppColors.accent : AppColors.borderSoft,
          ),
        ),
        onPressed: onTap,
        icon: iconWidget ?? Icon(icon, size: 17),
        label: MakeChessLocalizedText(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.buttonCompact.copyWith(
            color: active ? Colors.white : AppColors.text,
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.35),
        borderRadius: AppRadius.r12,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MakeChessLocalizedText(title, style: AppTextStyles.panelTitle),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _infoCard(String title, String value) {
    return Expanded(
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard.withOpacity(0.55),
          borderRadius: AppRadius.r10,
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MakeChessLocalizedText(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.button.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskList() {
    return _section(
      title: 'Задачи тренажёра',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _neoButton(
                  text: 'Открыть задачи',
                  icon: Icons.folder_open,
                  onTap: _opening ? null : () => _openTasks(),
                  iconWidget: _opening
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _neoButton(
                  text: 'Назад',
                  icon: Icons.arrow_back,
                  onTap: widget.publishedTasks.isEmpty
                      ? null
                      : widget.onPreviousTask,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _neoButton(
                  text: 'Следующая',
                  icon: Icons.arrow_forward,
                  onTap:
                      widget.publishedTasks.isEmpty ? null : widget.onNextTask,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: widget.loadingTasks
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : widget.publishedTasks.isEmpty
                    ? const Center(
                        child: MakeChessLocalizedText(
                          'Пока нет опубликованных задач этого типа.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.muted,
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: widget.publishedTasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 5),
                        itemBuilder: (context, index) {
                          final item = widget.publishedTasks[index];
                          final selected = index == widget.activeTaskIndex;
                          return Material(
                            color: selected
                                ? AppColors.accent.withOpacity(0.14)
                                : Colors.transparent,
                            borderRadius: AppRadius.r8,
                            child: InkWell(
                              borderRadius: AppRadius.r8,
                              onTap: () => widget.onTaskSelected(index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: AppRadius.r8,
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.accent
                                        : AppColors.borderSoft,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '№${item.number} ${item.title}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.buttonCompact,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    MakeChessLocalizedText(
                                      _modeTitle(item.mode),
                                      style: AppTextStyles.caption,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${MakeChessLocalization.phrase('Глубина')}: ${item.depth}',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
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

  Widget _resultBlock(AntiBlunderCandidateSummary summary) {
    final safePercent = summary.classifiedCandidateCount == 0
        ? 0
        : (summary.safetyRate * 100).round();

    return _section(
      title: 'Результат проверки',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _infoCard('Безопасно', '${summary.safeCandidateCount}'),
              const SizedBox(width: 8),
              _infoCard('Зевки', '${summary.blunderCandidateCount}'),
              const SizedBox(width: 8),
              _infoCard(
                'Не классифицировано',
                '${summary.unclassifiedCandidateCount}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${MakeChessLocalization.phrase('Безопасность кандидатов')}: '
            '$safePercent%',
            style: AppTextStyles.buttonCompact,
          ),
          const SizedBox(height: 4),
          Text(
            '${MakeChessLocalization.phrase('Коридор найден')}: '
            '${summary.foundCorridorMoveCount}/${summary.totalCorridorMoveCount}',
            style: AppTextStyles.buttonCompact,
          ),
        ],
      ),
    );
  }

  Widget _statsField(String label, TextEditingController controller) {
    return SizedBox(
      height: 34,
      child: TextField(
        controller: controller,
        style: AppTextStyles.caption,
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          label: MakeChessLocalizedText(label, style: AppTextStyles.caption),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _statsTabButton(String text, int index, {IconData? icon}) {
    final active = _statsTab == index;
    return SizedBox(
      width: 48,
      height: 34,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor:
              active ? AppColors.accent.withOpacity(0.14) : Colors.transparent,
          side: BorderSide(
            color: active ? AppColors.accent : AppColors.borderSoft,
          ),
        ),
        onPressed: () => setState(() => _statsTab = index),
        child: icon == null
            ? Text(text, style: AppTextStyles.buttonCompact)
            : Icon(icon, size: 18, color: AppColors.accent),
      ),
    );
  }

  Widget _statisticsPanel() {
    return _section(
      title: 'Статистика',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _statsTabButton('F1', 0),
              const SizedBox(width: 5),
              _statsTabButton('F2', 1),
              const SizedBox(width: 5),
              _statsTabButton('F3', 2),
              const SizedBox(width: 5),
              _statsTabButton('', 3, icon: Icons.show_chart),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final fields = Column(
                children: [
                  _statsField('Участник', _statsParticipantController),
                  const SizedBox(height: 6),
                  _statsField('Проверяющий', _statsReviewerController),
                  const SizedBox(height: 6),
                  _statsField('Период', _statsPeriodController),
                ],
              );
              final result = Container(
                height: compact ? 150 : 118,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard.withOpacity(0.25),
                  borderRadius: AppRadius.r8,
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: _statsTab == 3
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CustomPaint(
                          painter: _AntiBlunderStatsPainter(),
                          child: SizedBox.expand(),
                        ),
                      )
                    : Center(
                        child: MakeChessLocalizedText(
                          _statsTab == 0
                              ? 'Данные F1'
                              : _statsTab == 1
                                  ? 'Данные F2'
                                  : 'Данные F3',
                          style: AppTextStyles.muted,
                        ),
                      ),
              );

              if (compact) {
                return Column(
                  children: [
                    fields,
                    const SizedBox(height: 8),
                    result,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 190, child: fields),
                  const SizedBox(width: 10),
                  Expanded(child: result),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _studentBody() {
    final task = widget.controller.task;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _taskList(),
          const SizedBox(height: 10),
          if (task == null)
            _section(
              title: 'Антизевковый тренажёр',
              child: const SizedBox(
                height: 110,
                child: Center(
                  child: MakeChessLocalizedText(
                    'Откройте задачу антизевкового тренажёра',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.button,
                  ),
                ),
              ),
            )
          else ...[
            _section(
              title: 'Задание',
              child: Column(
                children: [
                  Row(
                    children: [
                      _infoCard(
                        'Режим',
                        MakeChessLocalization.phrase(_modeTitle(task.mode)),
                      ),
                      const SizedBox(width: 8),
                      _infoCard('Глубина', '${task.depth}'),
                      const SizedBox(width: 8),
                      _infoCard(
                        'Коридор безопасности',
                        '${task.safetyCorridor.length}',
                      ),
                      const SizedBox(width: 8),
                      _infoCard('Зоны зевка', '${task.blunderZones.length}'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _neoButton(
                          text: widget.drawingCandidates
                              ? 'Рисование кандидатов включено'
                              : 'Рисовать кандидаты',
                          icon: Icons.arrow_outward,
                          active: widget.drawingCandidates,
                          onTap: widget.onToggleCandidateDrawing,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _neoButton(
                          text: 'Очистить кандидаты',
                          icon: Icons.delete_outline,
                          onTap: _clearCandidates,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _neoButton(
                          text: 'Проверить',
                          icon: Icons.check_circle_outline,
                          onTap: _check,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${MakeChessLocalization.phrase('Ходы-кандидаты')}: '
                      '${widget.studentCandidateCount}',
                      style: AppTextStyles.buttonCompact,
                    ),
                  ),
                ],
              ),
            ),
            if (_summary != null) ...[
              const SizedBox(height: 10),
              _resultBlock(_summary!),
            ],
          ],
          const SizedBox(height: 10),
          _statisticsPanel(),
        ],
      ),
    );
  }

  Widget _modeButton(AntiBlunderMode mode) {
    final selected = widget.controller.authorMode == mode;
    return Expanded(
      child: _neoButton(
        text: _modeTitle(mode),
        icon:
            mode == AntiBlunderMode.direct ? Icons.shield_outlined : Icons.undo,
        active: selected,
        onTap: () => widget.onAuthorModeChanged(mode),
      ),
    );
  }

  int _countFor(String key) {
    return widget.authorAnalysisCounts[widget.authorAnalysisSide]?[key] ?? 0;
  }

  Widget _authorTool({
    required String title,
    required String keyName,
    required Color color,
    IconData icon = Icons.arrow_forward,
  }) {
    final active = widget.activeAuthorAnalysisKey == keyName &&
        widget.authorDrawingEnabled;
    return SizedBox(
      width: 174,
      child: _neoButton(
        text: '${MakeChessLocalization.phrase(title)}  ${_countFor(keyName)}',
        icon: icon,
        active: active,
        onTap: () => widget.onAuthorAnalysisModeChanged(keyName),
      ),
    );
  }

  Widget _authorTools() {
    return _section(
      title: 'Инструменты учителя',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _authorTool(
                title: 'Коридор безопасности',
                keyName: 'safe_corridor',
                color: const Color(0xFF00C853),
              ),
              _authorTool(
                title: 'Зона зевка',
                keyName: 'blunder_zone',
                color: const Color(0xFFFF6D00),
              ),
              _authorTool(
                title: 'Угроза',
                keyName: 'threat',
                color: const Color(0xFFFF2D2D),
              ),
              _authorTool(
                title: 'Связка',
                keyName: 'pin',
                color: const Color(0xFF6A35FF),
              ),
              _authorTool(
                title: 'Рентген',
                keyName: 'xray',
                color: const Color(0xFFFF00C8),
              ),
              _authorTool(
                title: 'Слабость',
                keyName: 'weakness',
                color: const Color(0xFF4CFF2E),
                icon: Icons.circle_outlined,
              ),
              _authorTool(
                title: 'P1',
                keyName: 'r1',
                color: const Color(0xFFFFB07A),
              ),
              _authorTool(
                title: 'P2',
                keyName: 'r2',
                color: const Color(0xFF0057FF),
                icon: Icons.circle_outlined,
              ),
              _authorTool(
                title: 'P3',
                keyName: 'r3',
                color: const Color(0xFF40F7F7),
              ),
              _authorTool(
                title: 'P4',
                keyName: 'r4',
                color: const Color(0xFFFF5F93),
                icon: Icons.circle_outlined,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _neoButton(
                  text: 'Установить',
                  icon: Icons.edit_outlined,
                  active: widget.authorDrawingEnabled,
                  onTap: widget.onToggleAuthorDrawing,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _neoButton(
                  text:
                      widget.authorAnalysisSide == 'black' ? 'Чёрные' : 'Белые',
                  icon: Icons.swap_horiz,
                  onTap: widget.onAuthorAnalysisSideToggle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _neoButton(
                  text: 'Готово',
                  icon: Icons.check,
                  onTap: widget.onFinishAuthorAnalysis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _neoButton(
                  text: widget.authorShowAnswer
                      ? 'Скрыть ответ'
                      : 'Показать ответ',
                  icon: Icons.visibility_outlined,
                  active: widget.authorShowAnswer,
                  onTap: () => widget.onAuthorShowAnswerChanged(
                    !widget.authorShowAnswer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _neoButton(
                  text: 'Очистить',
                  icon: Icons.delete_outline,
                  onTap: widget.onClearAuthorAnalysisElements,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lineBox(String title, String text) {
    return Expanded(
      child: Container(
        height: 94,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.18),
          borderRadius: AppRadius.r8,
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MakeChessLocalizedText(title, style: AppTextStyles.caption),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  text.isEmpty ? '—' : text,
                  style: AppTextStyles.caption,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsBody() {
    final startFen = widget.startFen?.trim();
    final effectiveFen = (startFen != null && startFen.isNotEmpty)
        ? startFen
        : widget.currentFen;

    final savedText = widget.savedLines.isEmpty
        ? ''
        : widget.savedLines
            .asMap()
            .entries
            .map((entry) => '${entry.key + 1}. ${entry.value.join(' ')}')
            .join('\n');
    final currentText = widget.currentLine.join(' ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _section(
            title: 'Управление задачей',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _neoButton(
                  text: 'Открыть задачи',
                  icon: Icons.folder_open,
                  onTap: _opening ? null : () => _openTasks(),
                ),
                _neoButton(
                  text: 'Новая задача',
                  icon: Icons.add,
                  onTap: () {
                    widget.onNewTask();
                    _summary = null;
                  },
                ),
                _neoButton(
                  text: 'Опубликовать',
                  icon: Icons.publish,
                  onTap: _publishing ? null : () => _publish(),
                  iconWidget: _publishing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
                _neoButton(
                  text: 'Скачать',
                  icon: Icons.download,
                  onTap: _downloading ? null : () => _download(),
                ),
                _neoButton(
                  text: 'JSON',
                  icon: Icons.copy,
                  onTap: () => widget.onCopyJson(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _section(
            title: 'Параметры задачи',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _titleController,
                        onChanged: widget.onDraftTitleChanged,
                        style: AppTextStyles.buttonCompact,
                        decoration: InputDecoration(
                          label: const MakeChessLocalizedText('Название'),
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _numberController,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          final number = int.tryParse(value.trim()) ?? 1;
                          widget.onDraftNumberChanged(number < 1 ? 1 : number);
                        },
                        style: AppTextStyles.buttonCompact,
                        decoration: InputDecoration(
                          label: const MakeChessLocalizedText('Номер'),
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _modeButton(AntiBlunderMode.direct),
                    const SizedBox(width: 8),
                    _modeButton(AntiBlunderMode.reverse),
                    const SizedBox(width: 12),
                    MakeChessLocalizedText(
                      'Глубина',
                      style: AppTextStyles.buttonCompact,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '−',
                      onPressed: widget.controller.authorDepth <= 1
                          ? null
                          : () => widget.onAuthorDepthChanged(
                                widget.controller.authorDepth - 1,
                              ),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Container(
                      width: 46,
                      alignment: Alignment.center,
                      child: Text(
                        '${widget.controller.authorDepth}',
                        style: AppTextStyles.button.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '+',
                      onPressed: () => widget.onAuthorDepthChanged(
                        widget.controller.authorDepth + 1,
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _section(
            title: 'Позиция и ветки',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  effectiveFen,
                  maxLines: 2,
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _neoButton(
                      text: 'Редактор позиции',
                      icon: Icons.edit_outlined,
                      onTap: widget.onTogglePositionEditor,
                    ),
                    _neoButton(
                      text: 'Записать позицию',
                      icon: Icons.flag_outlined,
                      onTap: widget.onSetInitialPosition,
                    ),
                    _neoButton(
                      text: widget.isRecordingLine
                          ? 'Идёт запись'
                          : 'Начать ветку',
                      icon: Icons.fiber_manual_record,
                      active: widget.isRecordingLine,
                      onTap: widget.onStartRecordingLine,
                    ),
                    _neoButton(
                      text: 'Записать ветку',
                      icon: Icons.playlist_add_check,
                      onTap: widget.onFinishRecordingLine,
                    ),
                    _neoButton(
                      text: 'Очистить',
                      icon: Icons.delete_outline,
                      onTap: widget.onClearDraft,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _lineBox('Записанные ветки', savedText),
                    const SizedBox(width: 8),
                    _lineBox('Текущая ветка', currentText),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _authorTools(),
          const SizedBox(height: 10),
          _section(
            title: 'Состояние',
            child: Row(
              children: [
                Expanded(
                  child: MakeChessLocalizedText(
                    widget.isPublished
                        ? 'Задача опубликована'
                        : 'Задача ещё не опубликована',
                    style: AppTextStyles.buttonCompact,
                  ),
                ),
                Text(
                  '${MakeChessLocalization.phrase('Коридор безопасности')}: '
                  '${_countFor('safe_corridor')}   '
                  '${MakeChessLocalization.phrase('Зоны зевка')}: '
                  '${_countFor('blunder_zone')}',
                  style: AppTextStyles.buttonCompact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Material(
          color: Colors.transparent,
          child: Container(
            width: widget.width,
            height: _collapsed ? 48 : widget.height,
            decoration: AppDecorations.panel(bright: true).copyWith(
              boxShadow: const [
                BoxShadow(
                  color: Color(0x42000000),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Column(
                  children: [
                    _header(),
                    if (!_collapsed)
                      Expanded(
                        child: widget.settingsMode
                            ? _settingsBody()
                            : _studentBody(),
                      ),
                  ],
                ),
                if (!_collapsed)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeDownRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: _startResize,
                        onPanUpdate: _updateResize,
                        onPanEnd: (_) => _endResize(),
                        onPanCancel: _endResize,
                        child: const SizedBox(
                          width: 30,
                          height: 30,
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: Icon(
                              Icons.drag_handle,
                              size: 18,
                              color: AppColors.textDim,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AntiBlunderStatsPainter extends CustomPainter {
  const _AntiBlunderStatsPainter();

  static const List<double> _values = <double>[42, 48, 53, 57, 64, 68, 74];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 10 || size.height <= 10) return;

    final grid = Paint()
      ..color = AppColors.borderSoft.withOpacity(0.55)
      ..strokeWidth = 1;
    final line = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dot = Paint()
      ..color = const Color(0xFF39D7FF)
      ..style = PaintingStyle.fill;

    const left = 26.0;
    const right = 8.0;
    const top = 8.0;
    const bottom = 18.0;
    final chartW =
        (size.width - left - right).clamp(1.0, double.infinity).toDouble();
    final chartH =
        (size.height - top - bottom).clamp(1.0, double.infinity).toDouble();

    for (var i = 0; i <= 3; i++) {
      final y = top + chartH * i / 3;
      canvas.drawLine(Offset(left, y), Offset(left + chartW, y), grid);
    }

    final path = Path();
    for (var i = 0; i < _values.length; i++) {
      final x = left + chartW * i / (_values.length - 1);
      final normalized = (_values[i] / 100).clamp(0.0, 1.0);
      final y = top + chartH * (1 - normalized);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 2.6, dot);
    }
    canvas.drawPath(path, line);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    const labels = <String>['01.05', '15.05', '30.05'];
    for (var i = 0; i < labels.length; i++) {
      final x = left + chartW * i / (labels.length - 1);
      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(
          color: AppColors.textDim,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - bottom + 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AntiBlunderStatsPainter oldDelegate) => false;
}
