class StockfishInfo {
  const StockfishInfo({
    required this.depth,
    required this.multiPv,
    required this.pv,
    this.scoreCp,
    this.mateIn,
    this.nodes,
    this.nps,
  });

  final int depth;
  final int multiPv;
  final List<String> pv;
  final int? scoreCp;
  final int? mateIn;
  final int? nodes;
  final int? nps;

  String get scoreText {
    if (mateIn != null) {
      return mateIn! >= 0 ? 'Мат в $mateIn' : 'Получаем мат в ${mateIn!.abs()}';
    }
    if (scoreCp != null) {
      final pawns = scoreCp! / 100.0;
      final sign = pawns > 0 ? '+' : '';
      return '$sign${pawns.toStringAsFixed(2)}';
    }
    return '—';
  }
}

class StockfishAnalysisResult {
  const StockfishAnalysisResult({
    required this.bestMove,
    required this.lines,
    this.ponderMove,
  });

  final String bestMove;
  final String? ponderMove;
  final List<StockfishInfo> lines;

  StockfishInfo? get principalVariation =>
      lines.isEmpty ? null : lines.first;
}
