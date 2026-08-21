import 'dart:io';

import '../lib/services/stockfish/stockfish_service.dart';

Future<void> main() async {
  const startFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  final stockfish = StockfishService();

  try {
    print('1. Запускаю локальный Stockfish...');
    await stockfish.start();
    print('OK: ${stockfish.executablePath}');

    print('2. Анализирую начальную позицию, depth 12, MultiPV 3...');
    final result = await stockfish.analyzeFen(
      startFen,
      depth: 12,
      multiPv: 3,
      timeout: const Duration(seconds: 30),
    );

    print('BESTMOVE: ${result.bestMove}');
    for (final line in result.lines) {
      print(
        'PV${line.multiPv}: depth=${line.depth} '
        'score=${line.scoreText} '
        'line=${line.pv.take(8).join(' ')}',
      );
    }

    print('');
    print('STOCKFISH_LOCAL_OK');
    exitCode = 0;
  } catch (e, st) {
    print('');
    print('STOCKFISH_LOCAL_ERROR');
    print(e);
    print(st);

    // Это важно: setup.cmd теперь реально увидит ошибку.
    exitCode = 1;
  } finally {
    await stockfish.dispose();
  }
}
