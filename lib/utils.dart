import 'package:chess/chess.dart' as ch;

/// Санация en passant: если указано поле, но реального взятия нет → ставим '-'
String sanitizeFenEp(String fen) {
  final parts = fen.trim().split(RegExp(r'\s+'));
  if (parts.length < 6) return fen;
  final ep = parts[3];
  if (ep == '-') return fen;

  final g = ch.Chess();
  if (!g.load(fen)) return fen;

  final moves = g.moves({'verbose': true});
  final hasEpCapture = moves.any((m) {
    if (m is! Map) return false;
    final flags = m['flags'];
    final to = m['to'];
    return (flags is String) && flags.contains('e') && to == ep;
  });

  if (!hasEpCapture) {
    parts[3] = '-';
    return parts.join(' ');
  }
  return fen;
}

/// Жёсткий вариант: всегда убираем EP поле — нужно для API, которое падает
String stripEpField(String fen) {
  final parts = fen.trim().split(RegExp(r'\s+'));
  if (parts.length < 6) return fen;
  parts[3] = '-';
  return parts.join(' ');
}
