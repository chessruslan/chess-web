import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherAccount {
  const TeacherAccount({
    required this.id,
    required this.schoolName,
    required this.about,
    required this.login,
    required this.passwordDigest,
    required this.tariff,
    required this.temporary,
    this.ownerUserId = '',
  });

  final String id;
  final String schoolName;
  final String about;
  final String login;
  final String passwordDigest;
  final String tariff;
  final bool temporary;
  final String ownerUserId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'schoolName': schoolName,
        'about': about,
        'login': login,
        'passwordDigest': passwordDigest,
        'tariff': tariff,
        'temporary': temporary,
        'ownerUserId': ownerUserId,
      };

  factory TeacherAccount.fromJson(Map<String, dynamic> json) => TeacherAccount(
        id: '${json['id'] ?? ''}',
        schoolName: '${json['schoolName'] ?? ''}',
        about: '${json['about'] ?? ''}',
        login: '${json['login'] ?? ''}',
        passwordDigest: '${json['passwordDigest'] ?? ''}',
        tariff: '${json['tariff'] ?? 'trial'}',
        temporary: json['temporary'] == true,
        ownerUserId: '${json['ownerUserId'] ?? ''}',
      );

  factory TeacherAccount.fromServer(Map<String, dynamic> row) => TeacherAccount(
        id: '${row['id'] ?? ''}',
        schoolName: '${row['school_name'] ?? ''}',
        about: '${row['about'] ?? ''}',
        login: '${row['teacher_login'] ?? ''}',
        passwordDigest: '',
        tariff: '${row['tariff'] ?? 'trial'}',
        temporary: false,
        ownerUserId: '${row['owner_user_id'] ?? ''}',
      );
}

class TeacherAccountStore {
  TeacherAccountStore._();

  static final TeacherAccountStore instance = TeacherAccountStore._();

  static const _accountsKey = 'makechess_teacher_accounts_v1';
  static const _sessionKey = 'makechess_teacher_session_v1';
  static const _schoolsTable = 'makechess_schools_v1';

  String _digest(String value) {
    // The teacher password remains local for the current legacy sign-in flow.
    // The global school directory never stores passwordDigest on the server.
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode('makechess-teacher-v1::$value')) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<List<TeacherAccount>> _loadLocalAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountsKey);
    if (raw == null || raw.isEmpty) return <TeacherAccount>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <TeacherAccount>[];

    return decoded
        .whereType<Map>()
        .map((item) => TeacherAccount.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => !item.temporary && item.schoolName.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _saveLocalAccounts(List<TeacherAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _accountsKey,
      jsonEncode(accounts.map((item) => item.toJson()).toList()),
    );
  }

  String _currentSupabaseUserId() {
    return Supabase.instance.client.auth.currentUser?.id.trim() ?? '';
  }

  TeacherAccount _withResolvedOwner(
    TeacherAccount account,
    String currentUserId,
  ) {
    final existingOwner = account.ownerUserId.trim();
    if (existingOwner.isNotEmpty || currentUserId.isEmpty) {
      return account;
    }

    return TeacherAccount(
      id: account.id,
      schoolName: account.schoolName,
      about: account.about,
      login: account.login,
      passwordDigest: account.passwordDigest,
      tariff: account.tariff,
      temporary: account.temporary,
      ownerUserId: currentUserId,
    );
  }

  Future<void> _upsertServerSchool(
    TeacherAccount account, {
    required String currentUserId,
  }) async {
    final ownerUserId = account.ownerUserId.trim();
    if (account.temporary || account.schoolName.trim().isEmpty) {
      return;
    }

    if (currentUserId.isEmpty ||
        ownerUserId.isEmpty ||
        ownerUserId != currentUserId) {
      throw StateError('SCHOOL_SERVER_OWNER_AUTH_REQUIRED');
    }

    await Supabase.instance.client.from(_schoolsTable).upsert(
      <String, dynamic>{
        'id': account.id.trim(),
        'school_name': account.schoolName.trim(),
        'about': account.about.trim(),
        'teacher_login': account.login.trim(),
        'tariff':
            account.tariff.trim().isEmpty ? 'trial' : account.tariff.trim(),
        'owner_user_id': ownerUserId,
      },
    );
  }

  Future<void> _syncLocalSchoolsToServer() async {
    final currentUserId = _currentSupabaseUserId();
    if (currentUserId.isEmpty) return;

    final local = await _loadLocalAccounts();
    if (local.isEmpty) return;

    var localChanged = false;
    final normalizedLocal = <TeacherAccount>[];

    for (final original in local) {
      final account = _withResolvedOwner(original, currentUserId);

      if (account.ownerUserId != original.ownerUserId) {
        localChanged = true;
      }

      normalizedLocal.add(account);

      // RLS allows a user to write only schools owned by that same user.
      if (account.ownerUserId.trim() == currentUserId) {
        await _upsertServerSchool(
          account,
          currentUserId: currentUserId,
        );
      }
    }

    if (localChanged) {
      await _saveLocalAccounts(normalizedLocal);
    }
  }

  /// Global MakeChess school/teacher directory.
  ///
  /// Server is the source of truth. Existing local schools belonging to the
  /// current authenticated user are migrated/upserted before reading the
  /// directory, so old installations can join the global catalog.
  Future<List<TeacherAccount>> loadAccounts() async {
    try {
      await _syncLocalSchoolsToServer();

      final raw = await Supabase.instance.client
          .from(_schoolsTable)
          .select(
            'id, school_name, about, teacher_login, tariff, owner_user_id, created_at, updated_at',
          )
          .order('school_name');

      final rows = raw is List ? raw : const <dynamic>[];
      return rows
          .whereType<Map>()
          .map(
            (item) =>
                TeacherAccount.fromServer(Map<String, dynamic>.from(item)),
          )
          .where(
            (item) =>
                item.id.trim().isNotEmpty &&
                item.schoolName.trim().isNotEmpty &&
                item.ownerUserId.trim().isNotEmpty,
          )
          .toList(growable: false);
    } catch (_) {
      // Offline/error fallback only. SharedPreferences is not the global source
      // of truth; it is used here only so the current browser is not unusable
      // during a temporary server failure.
      return _loadLocalAccounts();
    }
  }

  Future<TeacherAccount?> current() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    return decoded is Map
        ? TeacherAccount.fromJson(Map<String, dynamic>.from(decoded))
        : null;
  }

  Future<void> _remember(TeacherAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(account.toJson()));
  }

  Future<TeacherAccount> register({
    required String schoolName,
    required String about,
    required String login,
    required String password,
    required String tariff,
    String ownerUserId = '',
  }) async {
    final normalized = login.trim().toLowerCase();
    if (schoolName.trim().isEmpty) {
      throw StateError('Укажите школу или имя учителя');
    }
    if (normalized.length < 3) {
      throw StateError('Логин должен содержать минимум 3 символа');
    }
    if (password.length < 4) {
      throw StateError('Пароль должен содержать минимум 4 символа');
    }

    final localAccounts = await _loadLocalAccounts();
    if (localAccounts.any(
      (item) => item.login.toLowerCase() == normalized,
    )) {
      throw StateError('Такой логин учителя уже зарегистрирован');
    }

    final currentUserId = _currentSupabaseUserId();
    final resolvedOwnerUserId =
        ownerUserId.trim().isNotEmpty ? ownerUserId.trim() : currentUserId;

    final account = TeacherAccount(
      id: 'teacher_${DateTime.now().microsecondsSinceEpoch}',
      schoolName: schoolName.trim(),
      about: about.trim(),
      login: normalized,
      passwordDigest: _digest(password),
      tariff: tariff,
      temporary: false,
      ownerUserId: resolvedOwnerUserId,
    );

    // The server write is deliberately performed before the local save.
    // A school must not look successfully registered if it failed to enter the
    // global MakeChess directory.
    await _upsertServerSchool(
      account,
      currentUserId: currentUserId,
    );

    await _saveLocalAccounts(<TeacherAccount>[
      ...localAccounts,
      account,
    ]);
    await _remember(account);
    return account;
  }

  Future<TeacherAccount> signIn(String login, String password) async {
    final normalized = login.trim().toLowerCase();

    // Authentication remains local in this legacy teacher-account flow.
    // Never use the public/global server directory for password verification.
    final accounts = await _loadLocalAccounts();

    TeacherAccount? account;
    for (final item in accounts) {
      if (item.login == normalized) {
        account = item;
        break;
      }
    }

    if (account == null || account.passwordDigest != _digest(password)) {
      throw StateError('Неверный логин или пароль');
    }

    final currentUserId = _currentSupabaseUserId();
    final resolved = _withResolvedOwner(account, currentUserId);

    if (resolved.ownerUserId != account.ownerUserId) {
      final updated = accounts
          .map((item) => item.id == account!.id ? resolved : item)
          .toList(growable: false);
      await _saveLocalAccounts(updated);
    }

    if (resolved.ownerUserId.trim() == currentUserId &&
        currentUserId.isNotEmpty) {
      await _upsertServerSchool(
        resolved,
        currentUserId: currentUserId,
      );
    }

    await _remember(resolved);
    return resolved;
  }

  Future<TeacherAccount> temporarySignIn() async {
    final account = TeacherAccount(
      id: 'temporary_${DateTime.now().microsecondsSinceEpoch}',
      schoolName: 'Временный учитель',
      about: 'Временный вход для разработки',
      login: 'temporary',
      passwordDigest: '',
      tariff: 'trial',
      temporary: true,
      ownerUserId: '',
    );
    await _remember(account);
    return account;
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
