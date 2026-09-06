// MAKECHESS_FEATURE_ACCESS_V1
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'temporary_access_request_service.dart';

enum MakeChessFeatureAccess {
  openingChooser,
  videoConnections,
  windowsDownload,
}

extension MakeChessFeatureAccessX on MakeChessFeatureAccess {
  String get code {
    switch (this) {
      case MakeChessFeatureAccess.openingChooser:
        return 'opening_chooser';
      case MakeChessFeatureAccess.videoConnections:
        return 'video_connections';
      case MakeChessFeatureAccess.windowsDownload:
        return 'windows_download';
    }
  }

  String get title {
    switch (this) {
      case MakeChessFeatureAccess.openingChooser:
        return 'Дебютный тренажёр';
      case MakeChessFeatureAccess.videoConnections:
        return 'Видеосвязь';
      case MakeChessFeatureAccess.windowsDownload:
        return 'Скачивание MakeChess';
    }
  }
}

class OpeningAccessSnapshot {
  const OpeningAccessSnapshot({
    required this.used,
    required this.allowed,
    required this.installationId,
  });

  final int used;
  final int allowed;
  final String installationId;

  int get remaining => (allowed - used).clamp(0, 1 << 30);
}

class VideoAccessStatus {
  const VideoAccessStatus({
    required this.used,
    required this.allowed,
    required this.remaining,
    required this.accessAllowed,
    required this.validUntil,
  });

  final int used;
  final int allowed;
  final int remaining;
  final bool accessAllowed;
  final DateTime? validUntil;

  bool get expired =>
      validUntil != null && validUntil!.isBefore(DateTime.now().toUtc());

  factory VideoAccessStatus.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) => int.tryParse('$value') ?? 0;
    final validText = '${json['valid_until'] ?? ''}'.trim();

    return VideoAccessStatus(
      used: asInt(json['used_connections']),
      allowed: asInt(json['allowed_connections']),
      remaining: asInt(json['remaining_connections']),
      accessAllowed: json['access_allowed'] == true,
      validUntil:
          validText.isEmpty ? null : DateTime.tryParse(validText)?.toUtc(),
    );
  }
}

class FeatureAccessRequest {
  const FeatureAccessRequest({
    required this.id,
    required this.senderUserId,
    required this.senderName,
    required this.installationId,
    required this.featureCode,
    required this.usedUnits,
    required this.allowedUnits,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String senderUserId;
  final String senderName;
  final String installationId;
  final String featureCode;
  final int usedUnits;
  final int allowedUnits;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get featureTitle {
    switch (featureCode) {
      case 'video_connections':
        return 'Видеосвязь';
      case 'opening_chooser':
        return 'Дебютный тренажёр';
      case 'windows_download':
        return 'Скачивание MakeChess';
      default:
        return featureCode;
    }
  }

  factory FeatureAccessRequest.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) => int.tryParse('$value') ?? 0;

    return FeatureAccessRequest(
      id: '${json['id'] ?? ''}',
      senderUserId: '${json['sender_user_id'] ?? ''}',
      senderName: '${json['sender_name'] ?? 'Пользователь MakeChess'}',
      installationId: '${json['installation_id'] ?? ''}',
      featureCode: '${json['feature_code'] ?? ''}',
      usedUnits: asInt(json['used_units']),
      allowedUnits: asInt(json['allowed_units']),
      status: '${json['status'] ?? 'pending'}',
      createdAt:
          DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse('${json['updated_at'] ?? ''}') ?? DateTime.now(),
    );
  }
}

class TemporaryFeatureAccessService {
  TemporaryFeatureAccessService._();

  static final TemporaryFeatureAccessService instance =
      TemporaryFeatureAccessService._();

  static const int initialOpeningAllowance = 20;

  static const String _installationIdKey = 'makechess_temp_installation_id_v1';
  static const String _openingUsedKey =
      'makechess_temp_used_opening_chooser_v1';
  static const String _openingBonusKey =
      'makechess_temp_bonus_opening_chooser_v1';

  final ValueNotifier<int> pendingRequestCount = ValueNotifier<int>(0);

  Timer? _adminPollTimer;
  bool _refreshingAdmin = false;

  Future<String> installationId() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_installationIdKey) ?? '').trim().toUpperCase();
  }

  Future<int> _claimOpeningGrants() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return 0;

    final id = await installationId();
    if (id.isEmpty) return 0;

    final response = await client.rpc(
      'makechess_claim_feature_access_grants_v1',
      params: <String, dynamic>{
        'p_feature_code': MakeChessFeatureAccess.openingChooser.code,
        'p_installation_id': id,
      },
    );

    final row = _firstMap(response);
    final granted = int.tryParse('${row['grant_units'] ?? 0}') ?? 0;
    if (granted <= 0) return 0;

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_openingBonusKey) ?? 0;
    await prefs.setInt(_openingBonusKey, current + granted);
    return granted;
  }

  Future<OpeningAccessSnapshot> openingSnapshot({
    bool claimOnlineGrants = true,
  }) async {
    if (claimOnlineGrants) {
      try {
        await _claimOpeningGrants();
      } catch (_) {
        // Opening trainer remains usable offline.
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(_openingUsedKey) ?? 0;
    final bonus = prefs.getInt(_openingBonusKey) ?? 0;

    return OpeningAccessSnapshot(
      used: used,
      allowed: initialOpeningAllowance + bonus,
      installationId:
          (prefs.getString(_installationIdKey) ?? '').trim().toUpperCase(),
    );
  }

  /// Consumes exactly one "Выбрать дебют" opening.
  Future<bool> tryConsumeOpeningChooser() async {
    final snapshot = await openingSnapshot();
    if (snapshot.used >= snapshot.allowed) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_openingUsedKey, snapshot.used + 1);
    return true;
  }

  Future<VideoAccessStatus> videoStatus() async {
    final response = await Supabase.instance.client.rpc(
      'makechess_video_access_status_v1',
    );
    return VideoAccessStatus.fromJson(_firstMap(response));
  }

  /// Call ONLY after remote video connection is actually established.
  Future<bool> consumeSuccessfulVideoConnection() async {
    final response = await Supabase.instance.client.rpc(
      'makechess_consume_video_connection_v1',
    );
    final row = _firstMap(response);
    return row['ok'] == true && row['consumed'] == true;
  }

  Future<void> submitOpeningRequest() async {
    final snapshot = await openingSnapshot(claimOnlineGrants: false);
    await _submitFeatureRequest(
      feature: MakeChessFeatureAccess.openingChooser,
      installationId: snapshot.installationId,
      used: snapshot.used,
      allowed: snapshot.allowed,
    );
  }

  Future<void> submitVideoRequest() async {
    final status = await videoStatus();
    await _submitFeatureRequest(
      feature: MakeChessFeatureAccess.videoConnections,
      installationId: await installationId(),
      used: status.used,
      allowed: status.allowed,
    );
  }

  Future<void> submitWindowsDownloadRequest() async {
    await _submitFeatureRequest(
      feature: MakeChessFeatureAccess.windowsDownload,
      installationId: await installationId(),
      used: 0,
      allowed: 0,
    );
  }

  Future<Uri?> windowsDownloadUri() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || user.id.trim().isEmpty) {
      throw StateError('Требуется вход в аккаунт MakeChess.');
    }

    final response = await client.rpc(
      'makechess_windows_download_status_v1',
    );
    final row = _firstMap(response);
    if (row['can_download'] != true) return null;

    final signedUrl = await client.storage
        .from('downloads')
        .createSignedUrl('MakeChess_Setup.exe', 15 * 60);

    final uri = Uri.tryParse(signedUrl);
    if (uri == null || !uri.hasScheme) {
      throw StateError('Не удалось получить временную ссылку скачивания.');
    }
    return uri;
  }

  Future<void> _submitFeatureRequest({
    required MakeChessFeatureAccess feature,
    required String installationId,
    required int used,
    required int allowed,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw StateError('Требуется подключение к аккаунту MakeChess.');
    }

    await Supabase.instance.client.rpc(
      'makechess_submit_feature_access_request_v1',
      params: <String, dynamic>{
        'p_feature_code': feature.code,
        'p_installation_id': installationId,
        'p_used_units': used,
        'p_allowed_units': allowed,
      },
    );
  }

  void startAdminPolling() {
    _adminPollTimer?.cancel();
    unawaited(refreshAdminRequests());
    _adminPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(refreshAdminRequests()),
    );
  }

  void stopAdminPolling() {
    _adminPollTimer?.cancel();
    _adminPollTimer = null;
    pendingRequestCount.value = 0;
    TemporaryAccessRequestService.instance.setExternalPendingCount(0);
  }

  Future<List<FeatureAccessRequest>> listAdminRequests() async {
    final token =
        TemporaryAccessRequestService.instance.adminSessionToken.trim();
    if (token.isEmpty) return const <FeatureAccessRequest>[];

    final response = await Supabase.instance.client.rpc(
      'makechess_admin_list_feature_access_requests_v1',
      params: <String, dynamic>{'p_session_token': token},
    );

    final requests = _asList(response)
        .whereType<Map>()
        .map(
          (row) => FeatureAccessRequest.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((request) => request.id.isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    pendingRequestCount.value = requests.length;
    TemporaryAccessRequestService.instance
        .setExternalPendingCount(requests.length);
    return requests;
  }

  Future<void> refreshAdminRequests() async {
    if (_refreshingAdmin) return;
    _refreshingAdmin = true;
    try {
      await listAdminRequests();
    } catch (_) {
      // Keep last badge count on a temporary network error.
    } finally {
      _refreshingAdmin = false;
    }
  }

  Future<void> grantAdminRequest({
    required String requestId,
    required int units,
    int validDays = 0,
  }) async {
    if (units <= 0 || units > 100000) {
      throw ArgumentError.value(
        units,
        'units',
        'Количество должно быть от 1 до 100000.',
      );
    }
    if (validDays < 0 || validDays > 3650) {
      throw ArgumentError.value(
        validDays,
        'validDays',
        'Срок должен быть от 0 до 3650 дней.',
      );
    }

    final token =
        TemporaryAccessRequestService.instance.adminSessionToken.trim();
    if (token.isEmpty) {
      throw StateError('Административная сессия отсутствует.');
    }

    await Supabase.instance.client.rpc(
      'makechess_admin_grant_feature_access_v1',
      params: <String, dynamic>{
        'p_session_token': token,
        'p_request_id': requestId,
        'p_grant_units': units,
        'p_valid_days': validDays,
      },
    );

    await refreshAdminRequests();
  }

  Future<void> closeAdminRequest(String requestId) async {
    final token =
        TemporaryAccessRequestService.instance.adminSessionToken.trim();
    if (token.isEmpty) {
      throw StateError('Административная сессия отсутствует.');
    }

    await Supabase.instance.client.rpc(
      'makechess_admin_close_feature_access_request_v1',
      params: <String, dynamic>{
        'p_session_token': token,
        'p_request_id': requestId,
      },
    );

    await refreshAdminRequests();
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
