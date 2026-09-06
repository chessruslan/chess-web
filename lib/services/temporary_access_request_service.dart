// MAKECHESS_AUTO_APPROVE_ACCESS_V4
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TemporaryAccessRequest {
  const TemporaryAccessRequest({
    required this.id,
    required this.senderUserId,
    required this.senderName,
    required this.installationId,
    required this.usedTournaments,
    required this.allowedTournaments,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String senderUserId;
  final String senderName;
  final String installationId;
  final int usedTournaments;
  final int allowedTournaments;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TemporaryAccessRequest.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) => int.tryParse('$value') ?? 0;

    return TemporaryAccessRequest(
      id: '${json['id'] ?? ''}',
      senderUserId: '${json['sender_user_id'] ?? ''}',
      senderName: '${json['sender_name'] ?? 'Пользователь MakeChess'}',
      installationId: '${json['installation_id'] ?? ''}',
      usedTournaments: asInt(json['used_tournaments']),
      allowedTournaments: asInt(json['allowed_tournaments']),
      status: '${json['status'] ?? 'pending'}',
      createdAt:
          DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse('${json['updated_at'] ?? ''}') ?? DateTime.now(),
    );
  }
}

class TemporaryAccessRequestService {
  TemporaryAccessRequestService._();

  static final TemporaryAccessRequestService instance =
      TemporaryAccessRequestService._();

  static const String _installationIdKey = 'makechess_temp_installation_id_v1';
  static const String _bonusTournamentsKey =
      'makechess_temp_bonus_tournaments_v3';

  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  // MAKECHESS_FEATURE_EXTERNAL_BADGE_V1
  int _tournamentPendingCount = 0;
  int _externalPendingCount = 0;

  void _syncPendingCount() {
    pendingCount.value = _tournamentPendingCount + _externalPendingCount;
  }

  void setExternalPendingCount(int count) {
    _externalPendingCount = count < 0 ? 0 : count;
    _syncPendingCount();
  }

  String _adminSessionToken = '';
  Timer? _adminPollTimer;

  bool get adminSessionOpen => _adminSessionToken.isNotEmpty;
  String get adminSessionToken => _adminSessionToken;

  Future<bool> loginAdmin(String password) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'makechess_temp_admin_login_v1',
        params: <String, dynamic>{'p_password': password},
      );

      final row = _firstMap(response);
      final token = '${row['session_token'] ?? ''}'.trim();
      if (token.isEmpty) return false;

      _adminSessionToken = token;
      await refreshPendingCount();

      _adminPollTimer?.cancel();
      _adminPollTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => unawaited(refreshPendingCount()),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void logoutAdmin() {
    _adminPollTimer?.cancel();
    _adminPollTimer = null;
    _adminSessionToken = '';
    _tournamentPendingCount = 0;
    _externalPendingCount = 0;
    _syncPendingCount();
  }

  Future<void> changeAdminPassword({
    required String curatorPassword,
    required String newPassword,
  }) async {
    await Supabase.instance.client.rpc(
      'makechess_temp_admin_change_password_v1',
      params: <String, dynamic>{
        'p_curator_password': curatorPassword,
        'p_new_password': newPassword,
      },
    );
  }

  Future<void> submitRequest({
    required String installationId,
    required int usedTournaments,
    required int allowedTournaments,
  }) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null || user.id.trim().isEmpty) {
      throw StateError('Требуется подключение к аккаунту MakeChess.');
    }

    await client.rpc(
      'makechess_submit_app_access_request_v1',
      params: <String, dynamic>{
        'p_installation_id': installationId.trim().toUpperCase(),
        'p_used_tournaments': usedTournaments,
        'p_allowed_tournaments': allowedTournaments,
      },
    );
  }

  Future<List<TemporaryAccessRequest>> listAdminRequests() async {
    final token = _adminSessionToken;
    if (token.isEmpty) return const <TemporaryAccessRequest>[];

    final response = await Supabase.instance.client.rpc(
      'makechess_admin_list_app_access_requests_v1',
      params: <String, dynamic>{'p_session_token': token},
    );

    final requests = _asList(response)
        .whereType<Map>()
        .map(
          (row) => TemporaryAccessRequest.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .where(
          (request) =>
              request.id.isNotEmpty && request.installationId.isNotEmpty,
        )
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    _tournamentPendingCount = requests.length;
    _syncPendingCount();
    return requests;
  }

  Future<void> refreshPendingCount() async {
    if (_adminSessionToken.isEmpty) {
      _tournamentPendingCount = 0;
      _externalPendingCount = 0;
      _syncPendingCount();
      return;
    }

    try {
      await listAdminRequests();
    } catch (_) {
      // A temporary network error must not close the admin session.
    }
  }

  Future<void> grantAdminRequest({
    required String requestId,
    required int grantTournaments,
  }) async {
    final token = _adminSessionToken;
    if (token.isEmpty) {
      throw StateError('Административная сессия отсутствует.');
    }

    if (grantTournaments <= 0 || grantTournaments > 100000) {
      throw ArgumentError.value(
        grantTournaments,
        'grantTournaments',
        'Количество должно быть от 1 до 100000.',
      );
    }

    await Supabase.instance.client.rpc(
      'makechess_admin_grant_app_access_v1',
      params: <String, dynamic>{
        'p_session_token': token,
        'p_request_id': requestId,
        'p_grant_tournaments': grantTournaments,
      },
    );

    await refreshPendingCount();
  }

  Future<void> closeAdminRequest(String requestId) async {
    final token = _adminSessionToken;
    if (token.isEmpty) {
      throw StateError('Административная сессия отсутствует.');
    }

    await Supabase.instance.client.rpc(
      'makechess_admin_set_app_access_request_status_v1',
      params: <String, dynamic>{
        'p_session_token': token,
        'p_request_id': requestId,
        'p_status': 'closed',
      },
    );

    await refreshPendingCount();
  }

  /// Claims every server-side grant for this Windows installation and adds
  /// it to the same local V3 bonus counter used by the temporary limiter.
  ///
  /// Returns how many tournaments were added locally.
  Future<int> claimAndApplyAvailableGrants() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || user.id.trim().isEmpty) return 0;

    final prefs = await SharedPreferences.getInstance();
    final installationId =
        (prefs.getString(_installationIdKey) ?? '').trim().toUpperCase();
    if (installationId.isEmpty) return 0;

    final response = await client.rpc(
      'makechess_claim_app_access_grants_v1',
      params: <String, dynamic>{
        'p_installation_id': installationId,
      },
    );

    final row = _firstMap(response);
    final granted = int.tryParse('${row['grant_tournaments'] ?? 0}') ?? 0;
    if (granted <= 0) return 0;

    final currentBonus = prefs.getInt(_bonusTournamentsKey) ?? 0;
    await prefs.setInt(_bonusTournamentsKey, currentBonus + granted);

    return granted;
  }

  static Map<String, dynamic> _firstMap(dynamic response) {
    dynamic value = response;

    if (value is String && value.trim().isNotEmpty) {
      value = jsonDecode(value);
    }

    if (value is List) {
      if (value.isEmpty || value.first is! Map) {
        return <String, dynamic>{};
      }
      return Map<String, dynamic>.from(value.first as Map);
    }

    if (value is Map) return Map<String, dynamic>.from(value);

    return <String, dynamic>{};
  }

  static List<dynamic> _asList(dynamic response) {
    dynamic value = response;

    if (value is String && value.trim().isNotEmpty) {
      value = jsonDecode(value);
    }

    if (value is Map && value['data'] is List) {
      value = value['data'];
    }

    return value is List ? value : const <dynamic>[];
  }
}
