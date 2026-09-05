import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../secrets.dart';

class NameCheckResult {
  const NameCheckResult({
    required this.online,
    required this.similarNames,
    this.error,
  });

  final bool online;
  final List<String> similarNames;
  final Object? error;

  bool get hasSimilar => similarNames.isNotEmpty;
}

class LocalIdentityService extends ChangeNotifier {
  LocalIdentityService._();

  static final LocalIdentityService instance = LocalIdentityService._();

  static const _nameKey = 'makechess_local_identity_name_v1';
  static const _serverUserIdKey = 'makechess_local_identity_server_uid_v1';
  static const _fallbackEmailKey = 'makechess_local_identity_email_v1';
  static const _fallbackPasswordKey =
      'makechess_local_identity_password_v1';

  SharedPreferences? _prefs;

  String _name = '';
  String _serverUserId = '';

  Timer? _networkTimer;
  bool? _online;
  Future<bool>? _networkCheckFuture;

  final ValueNotifier<bool?> online = ValueNotifier<bool?>(null);

  String get name => _name;
  bool get hasName => _name.trim().isNotEmpty;
  String get serverUserId => _serverUserId;
  bool get hasServerIdentity => _serverUserId.trim().isNotEmpty;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    _name = (_prefs!.getString(_nameKey) ?? '').trim();
    _serverUserId =
        (_prefs!.getString(_serverUserIdKey) ?? '').trim();
  }

  Future<void> setName(String value) async {
    await initialize();
    final next = _cleanDisplayName(value);
    _name = next;
    await _prefs!.setString(_nameKey, next);

    // ВАЖНО:
    // обычная смена отображаемого имени НЕ создаёт нового пользователя.
    // Серверный UUID и скрытая техническая учётная запись остаются прежними.
    notifyListeners();
  }

  String? validateName(String value) {
    final v = _cleanDisplayName(value);

    if (v.length < 2) {
      return 'Введите имя не короче 2 символов.';
    }
    if (v.length > 40) {
      return 'Имя должно быть не длиннее 40 символов.';
    }
    if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(v)) {
      return 'В имени должна быть хотя бы одна буква или цифра.';
    }

    return null;
  }

  Future<NameCheckResult> checkSimilarNames(String value) async {
    final candidate = _cleanDisplayName(value);
    if (candidate.isEmpty) {
      return const NameCheckResult(
        online: false,
        similarNames: [],
      );
    }

    final reachable = await checkNetworkNow();
    if (!reachable) {
      return const NameCheckResult(
        online: false,
        similarNames: [],
      );
    }

    try {
      final client = Supabase.instance.client;

      final patternSeed = candidate
          .replaceAll('%', '')
          .replaceAll('_', '')
          .trim();

      final pattern = patternSeed.length >= 3
          ? '%${patternSeed.substring(0, min(12, patternSeed.length))}%'
          : '%$patternSeed%';

      final rows = await client
          .from('profiles')
          .select('id, nickname')
          .ilike('nickname', pattern)
          .limit(25);

      final currentUid =
          (client.auth.currentUser?.id ?? '').trim();
      final localKnownUid = _serverUserId.trim();

      final similar = <String>[];

      for (final raw in rows) {
        if (raw is! Map) continue;

        final row = Map<String, dynamic>.from(raw);
        final id = '${row['id'] ?? ''}'.trim();
        final nick = '${row['nickname'] ?? ''}'.trim();

        if (nick.isEmpty) continue;

        if (id.isNotEmpty &&
            (id == currentUid || id == localKnownUid)) {
          continue;
        }

        if (_looksSimilar(candidate, nick)) {
          similar.add(nick);
        }
      }

      similar.sort(
        (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
      );

      return NameCheckResult(
        online: true,
        similarNames:
            similar.toSet().take(8).toList(growable: false),
      );
    } catch (error) {
      return NameCheckResult(
        online: true,
        similarNames: const [],
        error: error,
      );
    }
  }

  /// Гарантирует сетевую личность для Windows-приложения.
  ///
  /// Принципы:
  /// 1. Локальное имя работает и без интернета.
  /// 2. Если Supabase-сессия уже восстановилась — используем её.
  /// 3. Если сессии нет — сначала восстанавливаем сохранённую скрытую
  ///    техническую учётную запись.
  /// 4. Если у этой установки уже известен serverUserId, НИКОГДА молча
  ///    не создаём другого серверного пользователя.
  /// 5. Новый скрытый серверный аккаунт создаётся только для действительно
  ///    новой локальной установки/личности, у которой ещё нет serverUserId.
  Future<bool> ensureNetworkIdentity({
    String? nameOverride,
  }) async {
    await initialize();

    final displayName =
        _cleanDisplayName(nameOverride ?? _name);

    if (displayName.isEmpty) return false;
    if (!await checkNetworkNow()) return false;

    final client = Supabase.instance.client;
    User? user = client.auth.currentUser;

    // Если Supabase восстановил не ту сессию, которая принадлежит
    // этой локальной личности, не разрешаем случайно "перепрыгнуть"
    // на другой UUID.
    if (user != null &&
        _serverUserId.isNotEmpty &&
        user.id != _serverUserId) {
      try {
        await client.auth.signOut();
      } catch (_) {
        // Даже если signOut не удался, чужую сессию ниже не используем.
      }
      user = null;
    }

    // Сначала всегда пытаемся восстановить уже существующий скрытый аккаунт.
    if (user == null) {
      user = await _restoreStoredSilentAccount(client);
    }

    // Если UUID уже известен, но восстановить его сессию не удалось,
    // НЕ создаём новый UUID. Это защищает турниры, рейтинг, сообщения,
    // учеников и историю от раздвоения одного человека на два аккаунта.
    if (user == null && _serverUserId.isNotEmpty) {
      return false;
    }

    // Новый технический аккаунт создаём только один раз —
    // когда у установки ещё вообще нет серверной личности.
    if (user == null) {
      user = await _createSilentAccount(client);
    }

    if (user == null) return false;

    // Дополнительная защита от неожиданной смены UUID.
    if (_serverUserId.isNotEmpty &&
        _serverUserId != user.id) {
      return false;
    }

    _serverUserId = user.id;
    await _prefs!.setString(
      _serverUserIdKey,
      user.id,
    );

    await _syncProfile(
      client: client,
      user: user,
      displayName: displayName,
    );

    return true;
  }

  Future<User?> _restoreStoredSilentAccount(
    SupabaseClient client,
  ) async {
    final prefs = _prefs!;

    final email =
        (prefs.getString(_fallbackEmailKey) ?? '').trim();
    final password =
        prefs.getString(_fallbackPasswordKey) ?? '';

    if (email.isEmpty || password.length < 12) {
      return null;
    }

    try {
      final login = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user =
          login.user ?? client.auth.currentUser;

      if (user == null) return null;

      // Если ранее уже был сохранён UUID, восстановленный аккаунт
      // обязан иметь именно этот UUID.
      if (_serverUserId.isNotEmpty &&
          user.id != _serverUserId) {
        try {
          await client.auth.signOut();
        } catch (_) {}
        return null;
      }

      return user;
    } catch (_) {
      return null;
    }
  }

  Future<User?> _createSilentAccount(
    SupabaseClient client,
  ) async {
    final prefs = _prefs!;

    // Защита: новый аккаунт нельзя создавать поверх уже известного UUID.
    if (_serverUserId.isNotEmpty) {
      return null;
    }

    var email =
        (prefs.getString(_fallbackEmailKey) ?? '').trim();
    var password =
        prefs.getString(_fallbackPasswordKey) ?? '';

    if (email.isEmpty || password.length < 12) {
      final seed = _randomToken(18).toLowerCase();

      email = 'desktop_$seed@noemail.local';
      password = '${_randomToken(24)}aA1!';

      await prefs.setString(
        _fallbackEmailKey,
        email,
      );
      await prefs.setString(
        _fallbackPasswordKey,
        password,
      );
    }

    // Возможно, учётная запись уже была создана, а приложение
    // закрылось до сохранения serverUserId. Сначала пробуем вход.
    try {
      final login = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      return login.user ?? client.auth.currentUser;
    } catch (_) {
      // Если аккаунта ещё нет — создаём.
    }

    try {
      final signup = await client.auth.signUp(
        email: email,
        password: password,
      );

      final userAfterSignup =
          signup.user ?? client.auth.currentUser;

      if (client.auth.currentUser != null) {
        return client.auth.currentUser;
      }

      // На конфигурациях, где signUp не возвращает готовую сессию,
      // сразу пробуем обычный вход.
      final login = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      return login.user ??
          client.auth.currentUser ??
          userAfterSignup;
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncProfile({
    required SupabaseClient client,
    required User user,
    required String displayName,
  }) async {
    try {
      final existing = await client
          .from('profiles')
          .select('rating, games_played')
          .eq('id', user.id)
          .maybeSingle();

      final rating = existing?['rating'] is num
          ? (existing?['rating'] as num).toInt()
          : 1200;

      final games = existing?['games_played'] is num
          ? (existing?['games_played'] as num).toInt()
          : 0;

      await client.from('profiles').upsert({
        'id': user.id,
        'nickname': displayName,
        'rating': rating,
        'games_played': games,
      }, onConflict: 'id');
    } catch (_) {
      // Сессия уже полезна для сетевых функций даже если профиль
      // временно не удалось синхронизировать. Следующая попытка будет
      // при очередном подключении/синхронизации.
    }
  }

  void startNetworkMonitoring({
    Duration interval = const Duration(seconds: 8),
  }) {
    _networkTimer?.cancel();

    unawaited(checkNetworkNow());

    _networkTimer = Timer.periodic(
      interval,
      (_) => unawaited(checkNetworkNow()),
    );
  }

  void stopNetworkMonitoring() {
    _networkTimer?.cancel();
    _networkTimer = null;
  }

  Future<bool> checkNetworkNow() {
    final running = _networkCheckFuture;
    if (running != null) {
      return running;
    }

    final future = _performNetworkCheck();
    _networkCheckFuture = future;

    return future.whenComplete(() {
      if (identical(_networkCheckFuture, future)) {
        _networkCheckFuture = null;
      }
    });
  }

  Future<bool> _performNetworkCheck() async {
    try {
      final uri = Uri.tryParse(
        '${supabaseUrl.trim()}/auth/v1/health',
      );

      if (uri == null ||
          !uri.hasScheme ||
          uri.host.isEmpty) {
        _setOnline(false);
        return false;
      }

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 4));

      // Здесь проверяем именно доступность сервера.
      // Даже 401/404 означает, что сеть и backend отвечают.
      final ok =
          response.statusCode >= 200 &&
          response.statusCode < 500;

      _setOnline(ok);
      return ok;
    } catch (_) {
      _setOnline(false);
      return false;
    }
  }

  void _setOnline(bool value) {
    if (_online == value) return;

    _online = value;
    online.value = value;
  }

  String _cleanDisplayName(String value) =>
      value.trim().replaceAll(
            RegExp(r'\s+'),
            ' ',
          );

  bool _looksSimilar(String a, String b) {
    final x = _norm(a);
    final y = _norm(b);

    if (x.isEmpty || y.isEmpty) return false;
    if (x == y) return true;

    if (x.length >= 4 &&
        y.length >= 4 &&
        (x.contains(y) || y.contains(x))) {
      return true;
    }

    final distance = _levenshtein(x, y);
    final longest = max(x.length, y.length);

    final similarity = longest == 0
        ? 1.0
        : 1.0 - distance / longest;

    return similarity >= 0.80;
  }

  String _norm(String value) => value
      .toLowerCase()
      .replaceAll(
        RegExp(
          r'[^\p{L}\p{N}]',
          unicode: true,
        ),
        '',
      );

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous =
        List<int>.generate(b.length + 1, (i) => i);

    for (var i = 0; i < a.length; i++) {
      final current =
          List<int>.filled(b.length + 1, 0);

      current[0] = i + 1;

      for (var j = 0; j < b.length; j++) {
        final cost =
            a.codeUnitAt(i) == b.codeUnitAt(j)
                ? 0
                : 1;

        current[j + 1] = min(
          min(
            current[j] + 1,
            previous[j + 1] + 1,
          ),
          previous[j] + cost,
        );
      }

      previous = current;
    }

    return previous.last;
  }

  String _randomToken(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyz'
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        '0123456789';

    final random = Random.secure();

    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }
}
