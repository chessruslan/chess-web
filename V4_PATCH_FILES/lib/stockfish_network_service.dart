// MakeChess network Stockfish backend.
// Kept separate so lib/stockfish_service.dart can be the global router.
import 'dart:convert';

import 'package:http/http.dart' as http;

final Uri _chessApiUrl = Uri.parse('https://chess-api.com/v1');

String _sanitizeFenForApi(String fen) {
  final parts = fen.trim().split(RegExp(r'\s+'));
  if (parts.length < 4) return fen.trim();
  parts[3] = '-';
  if (parts.length == 4) parts.add('0');
  if (parts.length == 5) parts.add('1');
  return parts.take(6).join(' ');
}

Future<Map<String, dynamic>> getAnalysisRaw(
  String fen, {
  int depth = 20,
  int multiPv = 4,
  int maxThinkingTime = 2500,
  List<String> searchMoves = const <String>[],
}) async {
  final safeFen = _sanitizeFenForApi(fen);
  final payload = <String, dynamic>{
    'fen': safeFen,
    'depth': depth,
    'variants': multiPv,
    'maxThinkingTime': maxThinkingTime,
  };
  if (searchMoves.isNotEmpty) {
    payload['searchmoves'] = searchMoves.join(' ');
  }

  final res = await http.post(
    _chessApiUrl,
    headers: const <String, String>{'Content-Type': 'application/json'},
    body: jsonEncode(payload),
  );

  if (res.statusCode != 200) {
    throw Exception(
      'Stockfish analyze (network) HTTP ${res.statusCode}: ${res.body}',
    );
  }

  final data = jsonDecode(res.body);
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return <String, dynamic>{'raw': data};
}

Future<String> getAnalysisText(
  String fen, {
  int depth = 18,
  int multiPv = 3,
}) async {
  final raw = await getAnalysisRaw(
    fen,
    depth: depth,
    multiPv: multiPv,
    maxThinkingTime: 3000,
  );
  final text = raw['text'];
  if (text is String && text.trim().isNotEmpty) return text;
  return const JsonEncoder.withIndent('  ').convert(raw);
}

Future<String> getBestMoveUci(
  String fen, {
  int depth = 16,
  int maxThinkingTime = 1500,
}) async {
  final raw = await getAnalysisRaw(
    fen,
    depth: depth,
    multiPv: 1,
    maxThinkingTime: maxThinkingTime,
  );
  for (final key in const <String>['move', 'uci', 'bestMove', 'best_move']) {
    final value = raw[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  throw StateError('Network Stockfish did not return a best move.');
}
