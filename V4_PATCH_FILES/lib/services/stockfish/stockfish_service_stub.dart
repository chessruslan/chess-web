import 'stockfish_models.dart';

class StockfishService {
  bool get isRunning => false;

  String? get executablePath => null;

  Future<void> start({String? executablePath}) {
    throw UnsupportedError(
      'Локальный Stockfish доступен только в desktop/IO версии MakeChess.',
    );
  }

  Future<StockfishAnalysisResult> analyzeFen(
    String fen, {
    int depth = 16,
    int multiPv = 1,
    Duration timeout = const Duration(seconds: 30),
    int? maxThinkingTimeMs,
    List<String> searchMoves = const <String>[],
  }) {
    throw UnsupportedError(
      'Локальный Stockfish недоступен в браузере.',
    );
  }

  Future<void> newGame() async {}

  Future<void> stop() async {}

  Future<void> dispose() async {}
}
