import 'dart:convert';
import 'package:http/http.dart' as http;

final Uri _stockfishUrl =
    Uri.parse('https://api.111-88-227-25.sslip.io/stockfish/v1');

String _sanitizeFenForApi(String fen) {
  final parts = fen.trim().split(RegExp(r'\s+'));
  if (parts.length < 4) return fen.trim();
  parts[3] = '-';
  if (parts.length == 4) parts.add('0');
  if (parts.length == 5) parts.add('1');
  return parts.take(6).join(' ');
}

Future<Map<String, dynamic>> _analyse(
  String fen, {
  required int depth,
  required int multiPv,
  required int maxThinkingTime,
}) async {
  final res = await http.post(
    _stockfishUrl,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'fen': _sanitizeFenForApi(fen),
      'depth': depth,
      'variants': multiPv.clamp(1, 5),
      'maxThinkingTime': maxThinkingTime,
    }),
  );
  if (res.statusCode != 200) {
    throw Exception('Stockfish HTTP ${res.statusCode}: ${res.body}');
  }
  return jsonDecode(res.body) as Map<String, dynamic>;
}

Future<Map<String, dynamic>> getAnalysisRaw(
  String fen, {
  int depth = 20,
  int multiPv = 4,
  int maxThinkingTime = 2500,
}) =>
    _analyse(
      fen,
      depth: depth,
      multiPv: multiPv,
      maxThinkingTime: maxThinkingTime,
    );

Future<String> getAnalysisText(
  String fen, {
  int depth = 18,
  int multiPv = 3,
}) async {
  final data = await _analyse(
    fen,
    depth: depth,
    multiPv: multiPv,
    maxThinkingTime: 3000,
  );
  return const JsonEncoder.withIndent('  ').convert(data);
}

Future<String> getBestMoveUci(
  String fen, {
  int depth = 16,
  int maxThinkingTime = 1500,
}) async {
  final data = await _analyse(
    fen,
    depth: depth,
    multiPv: 1,
    maxThinkingTime: maxThinkingTime,
  );
  return (data['uci'] ?? '').toString();
}
