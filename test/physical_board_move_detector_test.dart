import 'package:flutter_test/flutter_test.dart';
import 'package:my_new_chess_app/services/physical_board_move_detector.dart';

void main() {
  const detector = PhysicalBoardMoveDetector();
  const initial =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  test('accepts a legal e2-e4 occupancy change', () {
    final occupied = PhysicalBoardMoveDetector.occupancyFromFen(initial)
      ..remove('e2')
      ..add('e4');
    final result = detector.detect(fen: initial, occupiedSquares: occupied);
    expect(result.status, PhysicalMoveDetectionStatus.accepted);
    expect(result.move?.from, 'e2');
    expect(result.move?.to, 'e4');
  });

  test('rejects an impossible e2-e5 occupancy change', () {
    final occupied = PhysicalBoardMoveDetector.occupancyFromFen(initial)
      ..remove('e2')
      ..add('e5');
    final result = detector.detect(fen: initial, occupiedSquares: occupied);
    expect(result.status, PhysicalMoveDetectionStatus.illegalPosition);
    expect(result.differentSquares, containsAll(<String>['e2', 'e5']));
  });

  test('recognizes castling from the final occupancy mask', () {
    const fen = 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1';
    final occupied = PhysicalBoardMoveDetector.occupancyFromFen(fen)
      ..removeAll(<String>['e1', 'h1'])
      ..addAll(<String>['g1', 'f1']);
    final result = detector.detect(fen: fen, occupiedSquares: occupied);
    expect(result.status, PhysicalMoveDetectionStatus.accepted);
    expect(result.move?.from, 'e1');
    expect(result.move?.to, 'g1');
  });

  test('keeps ambiguous capture candidates for optical disambiguation', () {
    const fen = '4k3/8/8/3p1p2/4N3/8/8/4K3 w - - 0 1';
    final occupied = PhysicalBoardMoveDetector.occupancyFromFen(fen)
      ..remove('e4');

    final result = detector.detect(fen: fen, occupiedSquares: occupied);

    expect(result.status, PhysicalMoveDetectionStatus.illegalPosition);
    expect(result.candidates.map((move) => move.to).toSet(), {'d6', 'f6'});
  });
}
