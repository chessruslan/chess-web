import 'dart:convert';

import 'anti_blunder_trainer.dart';

class PuzzleTask {
  const PuzzleTask({
    required this.id,
    required this.type,
    required this.typeTitle,
    required this.title,
    required this.number,
    required this.startFen,
    required this.solutionLines,
    this.description = '',
    this.analysisArrows = const {},
    this.antiBlunder,
  });

  final String id;
  final String type;
  final String typeTitle;
  final String title;
  final int number;
  final String startFen;
  final List<PuzzleLine> solutionLines;
  final String description;

  /// Правильные элементы анализа по категориям.
  /// Стрелки: threat, pin, xray, r1, r3, safe_corridor, blunder_zone.
  /// Кружки: weakness, r2, r4. Для кружка from == to.
  final Map<String, List<PuzzleAnalysisArrow>> analysisArrows;

  /// Данные отдельного антизевкового тренажёра.
  /// Для обычных композиций остаётся null.
  final AntiBlunderTaskSpec? antiBlunder;

  factory PuzzleTask.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('JSON задачи должен быть объектом.');
    }
    return PuzzleTask.fromJson(Map<String, dynamic>.from(decoded));
  }

  factory PuzzleTask.fromJson(Map<String, dynamic> json) {
    final typeTitle = '${json['typeTitle'] ?? json['type_title'] ?? ''}'.trim();
    final type = '${json['type'] ?? ''}'.trim();
    final linesRaw =
        json['solutionLines'] ?? json['solution_lines'] ?? json['solutions'];

    final analysisRaw =
        json['analysisArrows'] ?? json['analysis_arrows'] ?? json['analysis'];

    final antiBlunderRaw = json['antiBlunder'] ??
        json['anti_blunder'] ??
        json['antiBlunderTrainer'];

    return PuzzleTask(
      id: '${json['id'] ?? DateTime.now().microsecondsSinceEpoch}',
      type: type.isEmpty ? _typeKeyFromTitle(typeTitle) : type,
      typeTitle: typeTitle.isEmpty ? _titleFromTypeKey(type) : typeTitle,
      title: '${json['title'] ?? 'Новая задача'}'.trim().isEmpty
          ? 'Новая задача'
          : '${json['title']}'.trim(),
      number: _intValue(json['number'], fallback: 1),
      startFen: '${json['startFen'] ?? json['start_fen'] ?? json['fen'] ?? ''}',
      solutionLines: _parseLines(linesRaw),
      description: '${json['description'] ?? ''}',
      analysisArrows: _parseAnalysisArrows(analysisRaw),
      antiBlunder: antiBlunderRaw is Map
          ? AntiBlunderTaskSpec.fromJson(
              Map<String, dynamic>.from(antiBlunderRaw),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'typeTitle': typeTitle,
      'title': title,
      'number': number,
      'startFen': startFen,
      'solutionLines': solutionLines.map((line) => line.toJson()).toList(),
      'description': description,
      'analysisArrows': analysisArrows.map(
        (key, value) => MapEntry(
          key,
          value.map((arrow) => arrow.toJson()).toList(),
        ),
      ),
      if (antiBlunder != null) 'antiBlunder': antiBlunder!.toJson(),
    };
  }

  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }

  int correctArrowCountFor(String key) => analysisArrows[key]?.length ?? 0;

  int get totalCorrectArrowCount {
    var total = 0;
    for (final arrows in analysisArrows.values) {
      total += arrows.length;
    }
    return total;
  }

  static int _intValue(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  static List<PuzzleLine> _parseLines(dynamic raw) {
    if (raw is! List) return const [];

    final result = <PuzzleLine>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is Map) {
        result.add(
            PuzzleLine.fromJson(Map<String, dynamic>.from(item), index: i));
      } else if (item is List) {
        result.add(
          PuzzleLine(
            id: 'line_${i + 1}',
            moves: item
                .map((move) => '$move')
                .where((move) => move.trim().isNotEmpty)
                .toList(),
          ),
        );
      }
    }
    return result
        .where((line) => line.moves.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, List<PuzzleAnalysisArrow>> _parseAnalysisArrows(
      dynamic raw) {
    if (raw is! Map) return const {};

    final result = <String, List<PuzzleAnalysisArrow>>{};
    final source = Map<dynamic, dynamic>.from(raw);

    for (final entry in source.entries) {
      final key = _normalizeAnalysisKey('${entry.key}');
      final value = entry.value;
      if (value is! List) continue;

      final arrows = <PuzzleAnalysisArrow>[];
      for (var i = 0; i < value.length; i++) {
        final item = value[i];
        if (item is Map) {
          final arrow = PuzzleAnalysisArrow.fromJson(
            Map<String, dynamic>.from(item),
            index: i,
          );
          if (arrow.from.isNotEmpty && arrow.to.isNotEmpty) {
            arrows.add(arrow);
          }
        }
      }

      result[key] = arrows;
    }

    return result;
  }

  static String _normalizeAnalysisKey(String key) {
    switch (key.trim().toLowerCase()) {
      case 'угроза':
      case 'threat':
        return 'threat';
      case 'связка':
      case 'pin':
        return 'pin';
      case 'рентген':
      case 'xray':
      case 'x-ray':
        return 'xray';
      case 'слабость':
      case 'weakness':
        return 'weakness';
      case 'p1':
      case 'р1':
      case 'r1':
        return 'r1';
      case 'p2':
      case 'р2':
      case 'r2':
        return 'r2';
      case 'p3':
      case 'р3':
      case 'r3':
        return 'r3';
      case 'p4':
      case 'р4':
      case 'r4':
        return 'r4';
      default:
        return key.trim().toLowerCase();
    }
  }

  static String _typeKeyFromTitle(String title) {
    switch (title) {
      case 'Задачи на зевки':
        return 'blunders';
      case 'Мат':
        return 'mate';
      case 'Найти лучший ход':
        return 'bestMove';
      case 'Антизевковый тренажёр':
        return 'antiBlunderTrainer';
      default:
        return 'blunders';
    }
  }

  static String _titleFromTypeKey(String type) {
    switch (type) {
      case 'blunders':
        return 'Задачи на зевки';
      case 'mate':
        return 'Мат';
      case 'bestMove':
        return 'Найти лучший ход';
      case 'antiBlunderTrainer':
        return 'Антизевковый тренажёр';
      default:
        return 'Задачи на зевки';
    }
  }
}

class PuzzleLine {
  const PuzzleLine({
    required this.id,
    required this.moves,
    this.comment = '',
  });

  final String id;
  final List<String> moves;
  final String comment;

  factory PuzzleLine.fromJson(Map<String, dynamic> json, {int index = 0}) {
    final rawMoves = json['moves'];
    final moves = rawMoves is List
        ? rawMoves
            .map((move) => '$move')
            .where((move) => move.trim().isNotEmpty)
            .toList()
        : const <String>[];

    return PuzzleLine(
      id: '${json['id'] ?? 'line_${index + 1}'}',
      moves: moves,
      comment: '${json['comment'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'moves': moves,
      'comment': comment,
    };
  }
}

class PuzzleAnalysisArrow {
  const PuzzleAnalysisArrow({
    required this.id,
    required this.from,
    required this.to,
    this.comment = '',
    this.side = 'white',
  });

  final String id;
  final String from;
  final String to;
  final String comment;
  final String side;

  static String _normalizeSide(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'black' ||
        value == 'ч' ||
        value == 'черные' ||
        value == 'чёрные') {
      return 'black';
    }
    return 'white';
  }

  factory PuzzleAnalysisArrow.fromJson(
    Map<String, dynamic> json, {
    int index = 0,
  }) {
    return PuzzleAnalysisArrow(
      id: '${json['id'] ?? 'arrow_${index + 1}'}',
      from: '${json['from'] ?? json['start'] ?? ''}'.trim(),
      to: '${json['to'] ?? json['end'] ?? ''}'.trim(),
      comment: '${json['comment'] ?? ''}',
      side: _normalizeSide(
          '${json['side'] ?? json['color'] ?? json['player'] ?? 'white'}'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from': from,
      'to': to,
      'comment': comment,
      'side': side,
    };
  }
}
