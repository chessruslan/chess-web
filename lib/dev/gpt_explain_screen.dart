// services/gpt_explain_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

// ЗАМЕНИ на свой URL Edge Function
const _endpoint = 'https://<твой-ref>.functions.supabase.co/gpt-explain';

// ЗАМЕНИ на свой anon public key из Supabase (Legacy API Keys → anon public)
const _anonKey = '<твoй_anon_key>';

Future<dynamic> explainFen({required String fen, String? ask}) async {
  final r = await http.post(
    Uri.parse(_endpoint),
    headers: {
      'Content-Type': 'application/json',
      'apikey': _anonKey,
      'Authorization': 'Bearer $_anonKey',
    },
    body: jsonEncode({
      'fen': fen,
      'ask': ask ?? "What's the plan?",
    }),
  );

  if (r.statusCode != 200) {
    throw Exception('HTTP ${r.statusCode}: ${r.body}');
  }

  // Пытаемся распарсить как JSON; если не получится — вернем текст как есть
  try {
    return jsonDecode(r.body);
  } catch (_) {
    return r.body;
  }
}
