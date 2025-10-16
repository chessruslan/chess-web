// lib/services/gpt_explain_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GptExplainService {
  /// ПРОСТОЙ ВАРИАНТ БЕЗ JWT:
  /// используем .functions.supabase.co (Verify JWT в Supabase выключен).
  static const String _endpoint =
      'https://chmebxirnmqgvdpwskhw.functions.supabase.co/gpt-explain';

  /// Таймаут сети
  static const Duration _timeout = Duration(seconds: 30);

  /// Вызов функции объяснения позиции.
  ///
  /// [fen] — позиция в FEN (обязательно)
  /// [pv]  — список ходов в SAN/алгебраическом виде (необязательно)
  /// [ask] — формулировка запроса для модели (необязательно)
  static Future<Map<String, dynamic>> explainPosition({
    required String fen,
    List<String>? pv,
    String ask = 'Кратко объясни план за сторону, которая ходит.',
  }) async {
    final uri = Uri.parse(_endpoint);

    // Формируем JSON тела
    final payload = <String, dynamic>{
      'fen': fen.trim(),
      if (pv != null && pv.isNotEmpty) 'pv': pv,
      'ask': ask,
    };

    try {
      final res = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              // просим сервер и клиент строго в UTF-8
              'Accept-Charset': 'utf-8',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      // Строго декодируем тело ответа из bytes → UTF-8
      final decoded = utf8.decode(res.bodyBytes);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final map = jsonDecode(decoded) as Map<String, dynamic>;
        return map; // ожидаем {"text": "..."} — дальше ты уже показываешь в модалке
      } else {
        // Пытаемся вытащить человекочитаемую ошибку
        String msg = decoded;
        try {
          final err = jsonDecode(decoded);
          msg = (err is Map && err['error'] != null)
              ? err['error'].toString()
              : decoded;
        } catch (_) {}
        throw Exception('HTTP ${res.statusCode}: $msg');
      }
    } on TimeoutException {
      throw Exception('Тайм-аут запроса к функции объяснения.');
    } catch (e) {
      throw Exception('Сетевая ошибка/функция недоступна: $e');
    }
  }
}
