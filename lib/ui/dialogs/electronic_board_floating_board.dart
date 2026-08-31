import 'dart:math' as math;

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/physical_board_move_detector.dart';

class ElectronicBoardFloatingBoard extends StatefulWidget {
  const ElectronicBoardFloatingBoard({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  ElectronicBoardFloatingBoardState createState() =>
      ElectronicBoardFloatingBoardState();
}

class ElectronicBoardFloatingBoardState
    extends State<ElectronicBoardFloatingBoard> {
  static const double _minimumSize = 300;
  final chess.Chess _game = chess.Chess();
  final PhysicalBoardMoveDetector _detector = const PhysicalBoardMoveDetector();
  final Map<String, double> _settledBrightness = <String, double>{};
  List<PhysicalMoveCandidate> _pendingCaptures = <PhysicalMoveCandidate>[];

  Offset _position = const Offset(420, 150);
  double _size = 430;
  String? _selectedSquare;
  String _status = 'Ожидание полной привязки 64 клеток';
  bool _automaticReady = false;

  void updateOpticalPosition({
    required Set<String> occupiedSquares,
    required Map<String, double> brightnessBySquare,
    required bool allSquaresMapped,
  }) {
    if (!mounted) return;
    _automaticReady = allSquaresMapped;
    if (!allSquaresMapped) {
      setState(() => _status = 'Автоматический режим: привяжите все 64 клетки');
      return;
    }

    if (_pendingCaptures.isNotEmpty &&
        _resolvePendingCaptureFromNextMove(
          occupiedSquares,
          brightnessBySquare,
        )) {
      return;
    }

    final result = _detector.detect(
      fen: _game.fen,
      occupiedSquares: occupiedSquares,
    );
    PhysicalMoveCandidate? candidate = result.move;

    // During a capture the destination remains occupied. Several legal
    // captures can therefore have the same occupancy mask. The optical jump
    // at their destination disambiguates them.
    if (candidate == null && result.candidates.isNotEmpty) {
      final ranked = result.candidates.toList()
        ..sort((a, b) => _brightnessJump(b.to, brightnessBySquare)
            .compareTo(_brightnessJump(a.to, brightnessBySquare)));
      final best = ranked.first;
      final bestJump = _brightnessJump(best.to, brightnessBySquare);
      final secondJump = ranked.length > 1
          ? _brightnessJump(ranked[1].to, brightnessBySquare)
          : 0.0;
      if (bestJump >= 3 && bestJump > secondJump + 0.8) candidate = best;
    }

    if (candidate != null) {
      _game.load(candidate.resultingFen);
      _pendingCaptures = <PhysicalMoveCandidate>[];
      _settledBrightness
        ..clear()
        ..addAll(brightnessBySquare);
      setState(() {
        _selectedSquare = null;
        _status = 'Ход распознан: ${candidate!.san}';
      });
      return;
    }

    if (result.status == PhysicalMoveDetectionStatus.unchanged) {
      if (_settledBrightness.isEmpty) {
        _settledBrightness.addAll(brightnessBySquare);
      }
      setState(() => _status = 'Автоматический режим включён');
    } else if (result.candidates.isNotEmpty) {
      _pendingCaptures = result.candidates.toList();
      setState(() => _status =
          'Взятие: ожидаем достаточный скачок яркости клетки назначения');
    } else {
      setState(() => _status = 'Фигура поднята — ожидаем завершение хода');
    }
  }

  bool _resolvePendingCaptureFromNextMove(
    Set<String> occupiedSquares,
    Map<String, double> brightnessBySquare,
  ) {
    final chains = <({PhysicalMoveCandidate capture, PhysicalMoveCandidate next})>[];
    for (final capture in _pendingCaptures) {
      final next = _detector.detect(
        fen: capture.resultingFen,
        occupiedSquares: occupiedSquares,
      );
      if (next.move != null) {
        chains.add((capture: capture, next: next.move!));
      }
    }
    if (chains.length != 1) return false;

    final chain = chains.single;
    _game.load(chain.next.resultingFen);
    _pendingCaptures = <PhysicalMoveCandidate>[];
    _settledBrightness
      ..clear()
      ..addAll(brightnessBySquare);
    setState(() {
      _selectedSquare = null;
      _status = 'Распознаны ходы: ${chain.capture.san}, ${chain.next.san}';
    });
    return true;
  }

  double _brightnessJump(
    String square,
    Map<String, double> current,
  ) =>
      ((current[square] ?? 0) - (_settledBrightness[square] ?? 0)).abs();

  void _reset() {
    setState(() {
      _game.reset();
      _selectedSquare = null;
      _settledBrightness.clear();
      _pendingCaptures = <PhysicalMoveCandidate>[];
      _status = _automaticReady
          ? 'Начальная позиция. Автоматический режим включён'
          : 'Начальная позиция. Ожидание полной привязки';
    });
  }

  void _tapSquare(String square) {
    final selected = _selectedSquare;
    if (selected == null) {
      if (_pieceAt(square) != null) setState(() => _selectedSquare = square);
      return;
    }
    if (selected == square) {
      setState(() => _selectedSquare = null);
      return;
    }
    final moved = _game.move(<String, dynamic>{
      'from': selected,
      'to': square,
      'promotion': 'q',
    });
    setState(() {
      if (moved) {
        _selectedSquare = null;
        _settledBrightness.clear();
        _pendingCaptures = <PhysicalMoveCandidate>[];
        _status = 'Позиция исправлена вручную';
      } else if (_pieceAt(square) != null) {
        _selectedSquare = square;
      } else {
        _status = 'Такой ход невозможен';
      }
    });
  }

  dynamic _pieceAt(String square) {
    try {
      return _game.get(square);
    } catch (_) {
      return null;
    }
  }

  String? _pieceAsset(dynamic piece) {
    if (piece == null) return null;
    final color = piece.color == chess.Color.WHITE ? 'w' : 'b';
    final type = '${piece.type}'.toUpperCase();
    return 'assets/pieces/cburnett/$color$type.svg';
  }

  @override
  Widget build(BuildContext context) => Positioned(
        left: _position.dx,
        top: _position.dy,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: _size,
            decoration: BoxDecoration(
              color: const Color(0xFF20252C),
              border: Border.all(color: const Color(0xFF00C7ED), width: 1.4),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Colors.black54, blurRadius: 18),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) =>
                      setState(() => _position += details.delta),
                  child: SizedBox(
                    height: 42,
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        const Icon(Icons.sensors, color: Color(0xFF00D7FF)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Электронная доска',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        IconButton(
                          tooltip: 'Закрыть',
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _reset,
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: const Text('Начальная позиция'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _status,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: _automaticReady
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: _board(),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) => setState(() {
                    _size = math.max(
                      _minimumSize,
                      _size + math.max(details.delta.dx, details.delta.dy),
                    );
                  }),
                  child: const Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(Icons.drag_handle, size: 22, color: Colors.white54),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _board() => AspectRatio(
        aspectRatio: 1,
        child: Column(
          children: [
            for (var rank = 8; rank >= 1; rank--)
              Expanded(
                child: Row(
                  children: [
                    for (var file = 0; file < 8; file++)
                      Expanded(child: _square(file, rank)),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _square(int file, int rank) {
    final square = '${String.fromCharCode(97 + file)}$rank';
    final asset = _pieceAsset(_pieceAt(square));
    final light = (file + rank).isEven;
    final selected = _selectedSquare == square;
    return InkWell(
      onTap: () => _tapSquare(square),
      child: ColoredBox(
        color: selected
            ? const Color(0xFFFFD54F)
            : light
                ? const Color(0xFFE5C79A)
                : const Color(0xFF8B5A3C),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (asset != null)
              Padding(
                padding: const EdgeInsets.all(3),
                child: SvgPicture.asset(asset),
              ),
            Positioned(
              left: 2,
              bottom: 1,
              child: Text(
                square,
                style: TextStyle(
                  fontSize: math.max(7, _size / 62),
                  color: light ? Colors.brown.shade800 : Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
