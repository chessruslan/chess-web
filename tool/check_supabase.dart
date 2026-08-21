// tool/check_supabase.dart
//
// Запуск из корня Flutter-проекта:
//   dart run tool/check_supabase.dart
//
// Файл автоматически использует:
//   lib/secrets.dart -> supabaseUrl / supabaseAnonKey

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../lib/secrets.dart';

Future<void> main() async {
  stdout.writeln('=== ПРОВЕРКА SUPABASE ===');
  stdout.writeln('URL: $supabaseUrl');
  stdout.writeln('Project ref: ${_projectRef(supabaseUrl)}');
  stdout.writeln('');

  final uri = Uri.tryParse(supabaseUrl.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    stderr.writeln('ОШИБКА: supabaseUrl имеет неверный формат.');
    exitCode = 2;
    return;
  }

  if (supabaseAnonKey.trim().isEmpty) {
    stderr.writeln('ОШИБКА: supabaseAnonKey пустой.');
    exitCode = 2;
    return;
  }

  await _checkDns(uri.host);

  final authResult = await _request(
    name: 'AUTH HEALTH',
    uri: uri.resolve('/auth/v1/health'),
  );

  final restRootResult = await _request(
    name: 'REST ROOT',
    uri: uri.resolve('/rest/v1/'),
  );

  final profilesResult = await _request(
    name: 'PROFILES',
    uri: uri.resolve('/rest/v1/profiles?select=nickname&limit=1'),
  );

  stdout.writeln('');
  stdout.writeln('=== ВЫВОД ===');

  final results = [authResult, restRootResult, profilesResult];

  if (results.any((r) => r.networkError != null)) {
    stdout.writeln(
      'СЕТЕВАЯ ПОЛОМКА: браузер/компьютер не получает HTTP-ответ от Supabase.',
    );
    stdout.writeln(
      'Это не ошибка регистрации и не ошибка функции входа в лобби.',
    );
    stdout.writeln(
      'Проверь VPN, DNS, антивирус, прокси или доступность самого проекта.',
    );
  } else if (authResult.statusCode == 401 ||
      authResult.statusCode == 403 ||
      restRootResult.statusCode == 401 ||
      restRootResult.statusCode == 403) {
    stdout.writeln(
      'КЛЮЧ НЕ ПОДХОДИТ: URL доступен, но anon/public key не принят.',
    );
    stdout.writeln(
      'Нужно восстановить правильную пару Project URL + anon/public key.',
    );
  } else if (_isServerFailure(authResult.statusCode) ||
      _isServerFailure(restRootResult.statusCode)) {
    stdout.writeln(
      'SUPABASE НЕДОСТУПЕН: сервер ответил ошибкой 5xx.',
    );
    stdout.writeln(
      'Вероятно, проект остановлен, восстанавливается или сервис проекта неисправен.',
    );
  } else if (_isSuccess(authResult.statusCode) &&
      _isSuccess(restRootResult.statusCode) &&
      !_isSuccess(profilesResult.statusCode)) {
    stdout.writeln(
      'AUTH И REST РАБОТАЮТ, но запрос к public.profiles не проходит.',
    );
    stdout.writeln(
      'Тогда проблема в таблице profiles, RLS-политике или разрешениях anon.',
    );
  } else if (_isSuccess(authResult.statusCode) &&
      _isSuccess(profilesResult.statusCode)) {
    stdout.writeln(
      'SUPABASE РАБОТАЕТ: Auth и profiles доступны.',
    );
    stdout.writeln(
      'Тогда нужно искать ошибку уже в клиентском коде или опубликованном кэше.',
    );
  } else {
    stdout.writeln(
      'Получена нестандартная комбинация ответов. Скопируй весь вывод терминала.',
    );
  }

  stdout.writeln('');
  await _checkCliProject();
}

String _projectRef(String url) {
  final uri = Uri.tryParse(url.trim());
  final host = uri?.host ?? '';
  if (host.isEmpty) return 'не определён';
  return host.split('.').first;
}

Future<void> _checkDns(String host) async {
  stdout.writeln('[DNS] $host');
  try {
    final addresses =
        await InternetAddress.lookup(host).timeout(const Duration(seconds: 10));
    if (addresses.isEmpty) {
      stdout.writeln('  ОШИБКА: DNS не вернул адрес.');
      return;
    }
    stdout.writeln(
      '  OK: ${addresses.map((e) => e.address).join(', ')}',
    );
  } on TimeoutException {
    stdout.writeln('  ОШИБКА: превышено время ожидания DNS.');
  } on SocketException catch (e) {
    stdout.writeln('  ОШИБКА DNS: ${e.message}');
  } catch (e) {
    stdout.writeln('  ОШИБКА DNS: $e');
  }
}

Future<_ProbeResult> _request({
  required String name,
  required Uri uri,
}) async {
  stdout.writeln('[$name] $uri');

  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 15);

  try {
    final request = await client.getUrl(uri).timeout(
          const Duration(seconds: 20),
        );

    request.headers.set('apikey', supabaseAnonKey);
    request.headers.set('Authorization', 'Bearer $supabaseAnonKey');
    request.headers.set('Accept', 'application/json');

    final response = await request.close().timeout(
          const Duration(seconds: 20),
        );

    final body = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 20));

    final preview = body.length > 500 ? '${body.substring(0, 500)}…' : body;

    stdout.writeln('  HTTP ${response.statusCode}');
    if (preview.trim().isNotEmpty) {
      stdout.writeln('  Ответ: $preview');
    }

    return _ProbeResult(statusCode: response.statusCode);
  } on TimeoutException catch (e) {
    stdout.writeln('  СЕТЕВАЯ ОШИБКА: timeout: $e');
    return _ProbeResult(networkError: e.toString());
  } on HandshakeException catch (e) {
    stdout.writeln('  TLS ОШИБКА: ${e.message}');
    return _ProbeResult(networkError: e.toString());
  } on SocketException catch (e) {
    stdout.writeln('  СЕТЕВАЯ ОШИБКА: ${e.message}');
    return _ProbeResult(networkError: e.toString());
  } catch (e) {
    stdout.writeln('  ОШИБКА: $e');
    return _ProbeResult(networkError: e.toString());
  } finally {
    client.close(force: true);
  }
}

Future<void> _checkCliProject() async {
  stdout.writeln('=== SUPABASE CLI ===');

  try {
    final result = await Process.run(
      'supabase',
      const ['projects', 'list', '--output', 'json'],
      runInShell: true,
    ).timeout(const Duration(seconds: 30));

    if (result.exitCode != 0) {
      stdout.writeln('CLI не смог получить список проектов.');
      final err = '${result.stderr}'.trim();
      if (err.isNotEmpty) stdout.writeln(err);
      stdout.writeln(
        'Это означает, что CLI не установлен или в нём нет действующего access token.',
      );
      return;
    }

    final text = '${result.stdout}'.trim();
    stdout.writeln(text.isEmpty ? 'CLI вернул пустой список.' : text);

    final ref = _projectRef(supabaseUrl);
    if (!text.contains(ref)) {
      stdout.writeln('');
      stdout.writeln(
        'ВНИМАНИЕ: проект $ref отсутствует среди проектов, доступных текущему CLI-токену.',
      );
    } else {
      stdout.writeln('');
      stdout.writeln(
        'Проект $ref доступен через текущий Supabase CLI-токен.',
      );
    }
  } on TimeoutException {
    stdout.writeln('CLI: превышено время ожидания.');
  } on ProcessException catch (e) {
    stdout.writeln('CLI не найден: ${e.message}');
  } catch (e) {
    stdout.writeln('Ошибка проверки CLI: $e');
  }
}

bool _isSuccess(int? code) => code != null && code >= 200 && code < 300;

bool _isServerFailure(int? code) => code != null && code >= 500 && code <= 599;

class _ProbeResult {
  const _ProbeResult({
    this.statusCode,
    this.networkError,
  });

  final int? statusCode;
  final String? networkError;
}
