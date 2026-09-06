// MAKECHESS_APP_ONLY_LIMIT_V3
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class TemporaryTournamentAccessSnapshot {
  const TemporaryTournamentAccessSnapshot({
    required this.installationId,
    required this.initialAllowance,
    required this.bonusTournaments,
    required this.usedTournaments,
  });

  final String installationId;
  final int initialAllowance;
  final int bonusTournaments;
  final int usedTournaments;

  int get totalAllowance => initialAllowance + bonusTournaments;
  int get remainingTournaments => max(0, totalAllowance - usedTournaments);
}

class TemporaryExtensionKeyResult {
  const TemporaryExtensionKeyResult({
    required this.ok,
    required this.message,
    this.grantedTournaments = 0,
  });

  final bool ok;
  final String message;
  final int grantedTournaments;
}

class TemporaryTournamentAccessService {
  TemporaryTournamentAccessService._();

  static final TemporaryTournamentAccessService instance =
      TemporaryTournamentAccessService._();

  static const int initialAllowance = 10;

  // Preserve the same installation id created by earlier test builds.
  static const String _installationIdKey = 'makechess_temp_installation_id_v1';

  // Fresh tournament-only counters. Old ROUND counters are ignored.
  static const String _usedTournamentsKey =
      'makechess_temp_used_tournaments_v3';
  static const String _bonusTournamentsKey =
      'makechess_temp_bonus_tournaments_v3';
  static const String _usedExtensionKeysKey =
      'makechess_temp_used_tournament_keys_v3';

  // Temporary test protection only.
  static const String _temporarySigningSalt =
      'MAKECHESS_TEMP_TOURNAMENT_V3_2026_P4Q7_91M';

  Future<String> installationId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = (prefs.getString(_installationIdKey) ?? '').trim();
    if (existing.isNotEmpty) return existing;

    final random = _secureRandom();

    String block() => random
        .nextInt(0x7fffffff)
        .toRadixString(36)
        .toUpperCase()
        .padLeft(6, '0')
        .substring(0, 6);

    final id = 'MC-${block()}-${block()}';
    await prefs.setString(_installationIdKey, id);
    return id;
  }

  Future<TemporaryTournamentAccessSnapshot> snapshot() async {
    final prefs = await SharedPreferences.getInstance();
    return TemporaryTournamentAccessSnapshot(
      installationId: await installationId(),
      initialAllowance: initialAllowance,
      bonusTournaments: max(0, prefs.getInt(_bonusTournamentsKey) ?? 0),
      usedTournaments: max(0, prefs.getInt(_usedTournamentsKey) ?? 0),
    );
  }

  Future<bool> tryConsumeTournament() async {
    final prefs = await SharedPreferences.getInstance();
    final state = await snapshot();

    if (state.remainingTournaments <= 0) return false;

    await prefs.setInt(
      _usedTournamentsKey,
      state.usedTournaments + 1,
    );
    return true;
  }

  Future<TemporaryExtensionKeyResult> applyExtensionKey(String rawKey) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _normalizeKey(rawKey);

    if (key.isEmpty) {
      return const TemporaryExtensionKeyResult(
        ok: false,
        message: 'Введите ключ продолжения.',
      );
    }

    final usedKeys = prefs.getStringList(_usedExtensionKeysKey) ?? <String>[];

    if (usedKeys.contains(key)) {
      return const TemporaryExtensionKeyResult(
        ok: false,
        message: 'Этот ключ уже был использован на данном компьютере.',
      );
    }

    final parts = key.split('-');
    if (parts.length != 4 || parts[0] != 'MC3') {
      return const TemporaryExtensionKeyResult(
        ok: false,
        message: 'Неверный формат ключа.',
      );
    }

    final grant = int.tryParse(parts[1]);
    final nonce = parts[2];
    final signature = parts[3];

    if (grant == null || grant < 1 || grant > 5000 || nonce.length < 3) {
      return const TemporaryExtensionKeyResult(
        ok: false,
        message: 'Ключ содержит неверные данные.',
      );
    }

    final id = await installationId();
    final expected = _signature(
      installationId: id,
      grantTournaments: grant,
      nonce: nonce,
    );

    if (signature != expected) {
      return const TemporaryExtensionKeyResult(
        ok: false,
        message: 'Этот ключ не подходит к данной установке MakeChess.',
      );
    }

    final bonus = max(0, prefs.getInt(_bonusTournamentsKey) ?? 0);
    await prefs.setInt(_bonusTournamentsKey, bonus + grant);

    final updated = <String>[...usedKeys, key];
    if (updated.length > 200) {
      updated.removeRange(0, updated.length - 200);
    }
    await prefs.setStringList(_usedExtensionKeysKey, updated);

    return TemporaryExtensionKeyResult(
      ok: true,
      message: 'Разрешение принято. Добавлено турниров: $grant.',
      grantedTournaments: grant,
    );
  }

  static String generateExtensionKey({
    required String installationId,
    required int grantTournaments,
  }) {
    final normalizedId = installationId.trim().toUpperCase();

    if (normalizedId.isEmpty) {
      throw ArgumentError('installationId is empty');
    }
    if (grantTournaments < 1 || grantTournaments > 5000) {
      throw ArgumentError('grantTournaments must be 1..5000');
    }

    final random = _secureRandom();
    final nonce = random
        .nextInt(60466176)
        .toRadixString(36)
        .toUpperCase()
        .padLeft(5, '0');

    final signature = _signature(
      installationId: normalizedId,
      grantTournaments: grantTournaments,
      nonce: nonce,
    );

    return 'MC3-$grantTournaments-$nonce-$signature';
  }

  static String _normalizeKey(String value) =>
      value.trim().toUpperCase().replaceAll(' ', '');

  static String _signature({
    required String installationId,
    required int grantTournaments,
    required String nonce,
  }) {
    final source =
        '${installationId.trim().toUpperCase()}|$grantTournaments|${nonce.toUpperCase()}|$_temporarySigningSalt';

    var hash = 17;
    for (final unit in source.codeUnits) {
      hash = (hash * 131 + unit) % 2147483629;
    }

    return hash.toRadixString(36).toUpperCase().padLeft(6, '0');
  }

  static Random _secureRandom() {
    try {
      return Random.secure();
    } catch (_) {
      return Random(DateTime.now().microsecondsSinceEpoch);
    }
  }
}
