import 'package:http/http.dart' as http;
import 'dart:convert';

Future<String> getBestMove(String fen) async {
  final res = await http.post(
    Uri.parse('https://your-api.com/stockfish'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'fen': fen,
      'depth': 15,
    }),
  );
  final data = jsonDecode(res.body);
  return data['bestmove'];
}
