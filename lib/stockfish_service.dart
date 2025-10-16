import 'dart:convert';
import 'package:http/http.dart' as http;

/// Если сайт на Netlify — оставь базу пустой: запросы пойдут на тот же домен.
const String _baseUrl = '';

/// Твои Netlify-функции (ожидается, что они отдают “богатый” JSON,
/// как в твоём старом проекте: text, san, lan, flags, continuation*, winChance, debug и т.п.)
const String _bestmovePath = '/.netlify/functions/stockfish/bestmove';
const String _analyzePath = '/.netlify/functions/stockfish/analyze';

/// chess-api.com — используем как запасной вариант для простого текста
final Uri _chessApiUrl = Uri.parse('https://chess-api.com/v1');

Uri _uri(String path) => Uri.parse('$_baseUrl$path');

/// --- Утилита ---
String _sanitizeFenForApi(String fen) {
  final parts = fen.trim().split(RegExp(r'\s+'));
  if (parts.length < 4) return fen.trim();
  parts[3] = '-';
  if (parts.length == 4) parts.add('0');
  if (parts.length == 5) parts.add('1');
  return parts.take(6).join(' ');
}

/// Общий POST helper с JSON
Future<Map<String, dynamic>> _postJson(
    Uri url, Map<String, dynamic> body) async {
  final res = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('${url.toString()} HTTP ${res.statusCode}: ${res.body}');
  }
  final data = jsonDecode(res.body);
  if (data is Map<String, dynamic>) return data;
  return {'raw': data};
}

/// =========================
///  ПУБЛИЧНЫЕ ФУНКЦИИ API
/// =========================

/// 1) “Богатый” bestmove — идём в твою Netlify-функцию /stockfish/bestmove
Future<Map<String, dynamic>> getBestMoveRich(
  String fen, {
  int depth = 18,
  int multiPv = 1,
  int maxThinkingTime = 2000,
}) async {
  final safeFen = _sanitizeFenForApi(fen);
  return _postJson(
    _uri(_bestmovePath),
    {
      'fen': safeFen,
      'depth': depth,
      'variants': multiPv,
      'multiPv': multiPv,
      'maxThinkingTime': maxThinkingTime,
    },
  );
}

/// 2) Полный анализ из твоей Netlify-функции /stockfish/analyze (тоже богатый JSON)
Future<Map<String, dynamic>> getAnalysisRaw(
  String fen, {
  int depth = 20,
  int multiPv = 4,
  int maxThinkingTime = 2500,
}) async {
  final safeFen = _sanitizeFenForApi(fen);
  return _postJson(
    _uri(_analyzePath),
    {
      'fen': safeFen,
      'depth': depth,
      'variants': multiPv,
      'multiPv': multiPv,
      'maxThinkingTime': maxThinkingTime,
    },
  );
}

/// 3) Короткий “человеческий” текст анализа (fallback через chess-api.com)
Future<String> getAnalysisText(
  String fen, {
  int depth = 18,
  int multiPv = 3,
  int maxThinkingTime = 3000,
}) async {
  final safeFen = _sanitizeFenForApi(fen);

  try {
    final m = await _postJson(
      _uri(_analyzePath),
      {
        'fen': safeFen,
        'depth': depth,
        'variants': multiPv,
        'multiPv': multiPv,
        'maxThinkingTime': maxThinkingTime,
      },
    );
    if (m['text'] is String && (m['text'] as String).trim().isNotEmpty) {
      return m['text'] as String;
    }
    return const JsonEncoder.withIndent('  ').convert(m);
  } catch (_) {
    // fallback на chess-api.com
  }

  final res = await http.post(
    _chessApiUrl,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'fen': safeFen,
      'depth': depth,
      'variants': multiPv,
      'maxThinkingTime': maxThinkingTime,
    }),
  );

  if (res.statusCode != 200) {
    throw Exception('chess-api analyze HTTP ${res.statusCode}: ${res.body}');
  }

  final data = jsonDecode(res.body);
  if (data is Map &&
      data['text'] is String &&
      (data['text'] as String).isNotEmpty) {
    return data['text'] as String;
  }

  return const JsonEncoder.withIndent('  ').convert(data);
}

/// 4) Быстрый UCI (через chess-api.com)
Future<String> getBestMoveUci(
  String fen, {
  int depth = 16,
  int maxThinkingTime = 1500,
}) async {
  final safeFen = _sanitizeFenForApi(fen);
  final res = await http.post(
    _chessApiUrl,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'fen': safeFen,
      'depth': depth,
      'variants': 1,
      'maxThinkingTime': maxThinkingTime,
    }),
  );
  if (res.statusCode != 200) {
    throw Exception('chess-api bestmove HTTP ${res.statusCode}: ${res.body}');
  }
  final data = jsonDecode(res.body);
  if (data is Map && data['move'] is String) return data['move'] as String;
  if (data is Map && data['uci'] is String) return data['uci'] as String;
  return data.toString();
}

/// 5) ✅ Совместимость со старым кодом
/// Возвращает просто UCI, чтобы main.dart не пришлось менять
Future<String> getBestMove(String fen, {int depth = 18}) {
  return getBestMoveUci(fen, depth: depth);
}
