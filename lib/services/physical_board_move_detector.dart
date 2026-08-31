import 'package:chess/chess.dart' as chess;

enum PhysicalMoveDetectionStatus {
  unchanged,
  accepted,
  promotionRequired,
  illegalPosition,
}

class PhysicalMoveCandidate {
  const PhysicalMoveCandidate({
    required this.from,
    required this.to,
    required this.san,
    required this.resultingFen,
    this.promotion = '',
  });

  final String from;
  final String to;
  final String san;
  final String promotion;
  final String resultingFen;
}

class PhysicalMoveDetectionResult {
  const PhysicalMoveDetectionResult({
    required this.status,
    this.candidates = const <PhysicalMoveCandidate>[],
    this.differentSquares = const <String>{},
  });

  final PhysicalMoveDetectionStatus status;
  final List<PhysicalMoveCandidate> candidates;
  final Set<String> differentSquares;

  PhysicalMoveCandidate? get move =>
      candidates.length == 1 ? candidates.single : null;
}

/// Matches a stable 64-square occupancy mask against every legal successor
/// of [fen]. It deliberately ignores temporary lift/place states; callers
/// should invoke it only after the optical signal has settled.
class PhysicalBoardMoveDetector {
  const PhysicalBoardMoveDetector();

  PhysicalMoveDetectionResult detect({
    required String fen,
    required Set<String> occupiedSquares,
  }) {
    final game = chess.Chess.fromFEN(fen);
    final current = occupancyFromFen(game.fen);
    if (_same(current, occupiedSquares)) {
      return const PhysicalMoveDetectionResult(
        status: PhysicalMoveDetectionStatus.unchanged,
      );
    }

    final candidates = <PhysicalMoveCandidate>[];
    final moves = game.moves(<String, dynamic>{'verbose': true});
    for (final raw in moves) {
      if (raw is! Map) continue;
      final move = Map<String, dynamic>.from(raw);
      final from = '${move['from'] ?? ''}';
      final to = '${move['to'] ?? ''}';
      final promotion = '${move['promotion'] ?? ''}';
      if (from.isEmpty || to.isEmpty) continue;

      final next = chess.Chess.fromFEN(fen);
      final applied = next.move(<String, dynamic>{
        'from': from,
        'to': to,
        if (promotion.isNotEmpty) 'promotion': promotion,
      });
      if (!applied) continue;
      if (!_same(occupancyFromFen(next.fen), occupiedSquares)) continue;
      candidates.add(PhysicalMoveCandidate(
        from: from,
        to: to,
        san: '${move['san'] ?? ''}',
        promotion: promotion,
        resultingFen: next.fen,
      ));
    }

    if (candidates.length == 1) {
      return PhysicalMoveDetectionResult(
        status: PhysicalMoveDetectionStatus.accepted,
        candidates: candidates,
      );
    }
    if (candidates.isNotEmpty &&
        candidates.every((candidate) =>
            candidate.from == candidates.first.from &&
            candidate.to == candidates.first.to &&
            candidate.promotion.isNotEmpty)) {
      return PhysicalMoveDetectionResult(
        status: PhysicalMoveDetectionStatus.promotionRequired,
        candidates: candidates,
      );
    }
    return PhysicalMoveDetectionResult(
      status: PhysicalMoveDetectionStatus.illegalPosition,
      candidates: candidates,
      differentSquares: current.symmetricDifference(occupiedSquares),
    );
  }

  static Set<String> occupancyFromFen(String fen) {
    final result = <String>{};
    final ranks = fen.split(' ').first.split('/');
    if (ranks.length != 8) return result;
    for (var rankIndex = 0; rankIndex < 8; rankIndex++) {
      var file = 0;
      for (final symbol in ranks[rankIndex].split('')) {
        final empty = int.tryParse(symbol);
        if (empty != null) {
          file += empty;
          continue;
        }
        if (file < 8) {
          result.add('${String.fromCharCode(97 + file)}${8 - rankIndex}');
        }
        file++;
      }
    }
    return result;
  }

  bool _same(Set<String> first, Set<String> second) =>
      first.length == second.length && first.containsAll(second);
}

extension on Set<String> {
  Set<String> symmetricDifference(Set<String> other) => <String>{
        ...difference(other),
        ...other.difference(this),
      };
}
