import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum CabinetGameType { classic, rapid, blitz, puzzles, twoByTwo }

extension CabinetGameTypeX on CabinetGameType {
  String get code {
    switch (this) {
      case CabinetGameType.classic:
        return 'classic';
      case CabinetGameType.rapid:
        return 'rapid';
      case CabinetGameType.blitz:
        return 'blitz';
      case CabinetGameType.puzzles:
        return 'puzzles';
      case CabinetGameType.twoByTwo:
        return 'twoByTwo';
    }
  }

  String get title {
    switch (this) {
      case CabinetGameType.classic:
        return 'Классика';
      case CabinetGameType.rapid:
        return 'Рапид';
      case CabinetGameType.blitz:
        return 'Блиц';
      case CabinetGameType.puzzles:
        return 'Задачи';
      case CabinetGameType.twoByTwo:
        return '2×2';
    }
  }

  static CabinetGameType fromCode(String? code) {
    return CabinetGameType.values.firstWhere(
      (value) => value.code == code,
      orElse: () => CabinetGameType.classic,
    );
  }
}

class CabinetProfile {
  const CabinetProfile({
    required this.userId,
    required this.nickname,
    required this.createdAt,
    required this.ratings,
    this.firstName = '',
    this.lastName = '',
    this.city = '',
    this.country = '',
    this.birthYear = '',
    this.chessTitle = '',
    this.club = '',
    this.about = '',
    this.favoriteControl = '',
    this.socialLink = '',
    this.photoBase64,
    this.profileVisible = true,
    this.gameInvitesEnabled = true,
    this.videoCallsEnabled = true,
    this.notificationsEnabled = true,
  });

  final String userId;
  final String nickname;
  final DateTime createdAt;
  final Map<CabinetGameType, int> ratings;
  final String firstName;
  final String lastName;
  final String city;
  final String country;
  final String birthYear;
  final String chessTitle;
  final String club;
  final String about;
  final String favoriteControl;
  final String socialLink;
  final String? photoBase64;
  final bool profileVisible;
  final bool gameInvitesEnabled;
  final bool videoCallsEnabled;
  final bool notificationsEnabled;

  String get fullName {
    final value = '$firstName $lastName'.trim();
    return value.isEmpty ? nickname : value;
  }

  int ratingFor(CabinetGameType type) => ratings[type] ?? 1200;

  CabinetProfile copyWith({
    String? nickname,
    DateTime? createdAt,
    Map<CabinetGameType, int>? ratings,
    String? firstName,
    String? lastName,
    String? city,
    String? country,
    String? birthYear,
    String? chessTitle,
    String? club,
    String? about,
    String? favoriteControl,
    String? socialLink,
    String? photoBase64,
    bool clearPhoto = false,
    bool? profileVisible,
    bool? gameInvitesEnabled,
    bool? videoCallsEnabled,
    bool? notificationsEnabled,
  }) {
    return CabinetProfile(
      userId: userId,
      nickname: nickname ?? this.nickname,
      createdAt: createdAt ?? this.createdAt,
      ratings: ratings ?? Map<CabinetGameType, int>.from(this.ratings),
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      city: city ?? this.city,
      country: country ?? this.country,
      birthYear: birthYear ?? this.birthYear,
      chessTitle: chessTitle ?? this.chessTitle,
      club: club ?? this.club,
      about: about ?? this.about,
      favoriteControl: favoriteControl ?? this.favoriteControl,
      socialLink: socialLink ?? this.socialLink,
      photoBase64: clearPhoto ? null : (photoBase64 ?? this.photoBase64),
      profileVisible: profileVisible ?? this.profileVisible,
      gameInvitesEnabled: gameInvitesEnabled ?? this.gameInvitesEnabled,
      videoCallsEnabled: videoCallsEnabled ?? this.videoCallsEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'userId': userId,
        'nickname': nickname,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'ratings': <String, int>{
          for (final entry in ratings.entries) entry.key.code: entry.value,
        },
        'firstName': firstName,
        'lastName': lastName,
        'city': city,
        'country': country,
        'birthYear': birthYear,
        'chessTitle': chessTitle,
        'club': club,
        'about': about,
        'favoriteControl': favoriteControl,
        'socialLink': socialLink,
        'photoBase64': photoBase64,
        'profileVisible': profileVisible,
        'gameInvitesEnabled': gameInvitesEnabled,
        'videoCallsEnabled': videoCallsEnabled,
        'notificationsEnabled': notificationsEnabled,
      };

  factory CabinetProfile.fromJson(Map<String, dynamic> json) {
    final rawRatings = json['ratings'];
    final ratings = <CabinetGameType, int>{};
    if (rawRatings is Map) {
      for (final entry in rawRatings.entries) {
        final type = CabinetGameTypeX.fromCode('${entry.key}');
        final raw = entry.value;
        ratings[type] = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 1200;
      }
    }
    for (final type in CabinetGameType.values) {
      ratings.putIfAbsent(type, () => 1200);
    }

    return CabinetProfile(
      userId: '${json['userId'] ?? ''}',
      nickname: '${json['nickname'] ?? 'player'}',
      createdAt:
          DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
      ratings: ratings,
      firstName: '${json['firstName'] ?? ''}',
      lastName: '${json['lastName'] ?? ''}',
      city: '${json['city'] ?? ''}',
      country: '${json['country'] ?? ''}',
      birthYear: '${json['birthYear'] ?? ''}',
      chessTitle: '${json['chessTitle'] ?? ''}',
      club: '${json['club'] ?? ''}',
      about: '${json['about'] ?? ''}',
      favoriteControl: '${json['favoriteControl'] ?? ''}',
      socialLink: '${json['socialLink'] ?? ''}',
      photoBase64: (json['photoBase64'] as String?)?.trim().isEmpty == true
          ? null
          : json['photoBase64'] as String?,
      profileVisible: json['profileVisible'] != false,
      gameInvitesEnabled: json['gameInvitesEnabled'] != false,
      videoCallsEnabled: json['videoCallsEnabled'] != false,
      notificationsEnabled: json['notificationsEnabled'] != false,
    );
  }
}

class CabinetGameRecord {
  const CabinetGameRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.savedAt,
    required this.whiteName,
    required this.blackName,
    required this.opponentName,
    required this.result,
    required this.timeControl,
    required this.source,
    required this.pgn,
  });

  final String id;
  final String userId;
  final CabinetGameType type;
  final DateTime savedAt;
  final String whiteName;
  final String blackName;
  final String opponentName;
  final String result;
  final String timeControl;
  final String source;
  final String pgn;

  String get duplicateKey => <String>[
        type.code,
        whiteName.trim().toLowerCase(),
        blackName.trim().toLowerCase(),
        result.trim(),
        timeControl.trim(),
        pgn.trim(),
      ].join('|');

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'type': type.code,
        'savedAt': savedAt.toUtc().toIso8601String(),
        'whiteName': whiteName,
        'blackName': blackName,
        'opponentName': opponentName,
        'result': result,
        'timeControl': timeControl,
        'source': source,
        'pgn': pgn,
      };

  factory CabinetGameRecord.fromJson(Map<String, dynamic> json) {
    return CabinetGameRecord(
      id: '${json['id'] ?? ''}',
      userId: '${json['userId'] ?? ''}',
      type: CabinetGameTypeX.fromCode('${json['type'] ?? ''}'),
      savedAt: DateTime.tryParse('${json['savedAt'] ?? ''}') ?? DateTime.now(),
      whiteName: '${json['whiteName'] ?? 'Белые'}',
      blackName: '${json['blackName'] ?? 'Чёрные'}',
      opponentName: '${json['opponentName'] ?? 'Соперник'}',
      result: '${json['result'] ?? '*'}',
      timeControl: '${json['timeControl'] ?? ''}',
      source: '${json['source'] ?? 'MakeChess'}',
      pgn: '${json['pgn'] ?? ''}',
    );
  }
}

abstract class PersonalCabinetRepository {
  Future<CabinetProfile?> readProfile(String userId);
  Future<void> writeProfile(CabinetProfile profile);
  Future<List<CabinetGameRecord>> readGames(String userId);
  Future<void> writeGames(String userId, List<CabinetGameRecord> games);
}

class LocalPersonalCabinetRepository implements PersonalCabinetRepository {
  static String _profileKey(String userId) =>
      'makechess.cabinet.$userId.profile.v1';
  static String _gamesKey(String userId) =>
      'makechess.cabinet.$userId.games.v1';

  @override
  Future<CabinetProfile?> readProfile(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey(userId));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return CabinetProfile.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeProfile(CabinetProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _profileKey(profile.userId), jsonEncode(profile.toJson()));
  }

  @override
  Future<List<CabinetGameRecord>> readGames(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_gamesKey(userId));
    if (raw == null || raw.trim().isEmpty) return <CabinetGameRecord>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <CabinetGameRecord>[];
      return decoded
          .whereType<Map>()
          .map((item) => CabinetGameRecord.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((item) => item.userId == userId)
          .toList(growable: true);
    } catch (_) {
      return <CabinetGameRecord>[];
    }
  }

  @override
  Future<void> writeGames(
    String userId,
    List<CabinetGameRecord> games,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _gamesKey(userId),
      jsonEncode(games.map((item) => item.toJson()).toList(growable: false)),
    );
  }
}

class PersonalCabinetStore {
  PersonalCabinetStore._();

  static final PersonalCabinetStore instance = PersonalCabinetStore._();

  PersonalCabinetRepository repository = LocalPersonalCabinetRepository();
  Future<void> _writeQueue = Future<void>.value();

  Future<CabinetProfile> loadProfile({
    required String userId,
    required String initialNickname,
    int initialClassicRating = 1200,
  }) async {
    final existing = await repository.readProfile(userId);
    if (existing != null) return existing;

    final ratings = <CabinetGameType, int>{
      for (final type in CabinetGameType.values) type: 1200,
    };
    ratings[CabinetGameType.classic] = initialClassicRating;

    final profile = CabinetProfile(
      userId: userId,
      nickname:
          initialNickname.trim().isEmpty ? 'player' : initialNickname.trim(),
      createdAt: DateTime.now(),
      ratings: ratings,
    );
    await saveProfile(profile);
    return profile;
  }

  Future<void> saveProfile(CabinetProfile profile) {
    return _enqueue(() => repository.writeProfile(profile));
  }

  Future<List<CabinetGameRecord>> loadGames(String userId) async {
    final games = await repository.readGames(userId);
    games.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return games;
  }

  Future<bool> saveGame(CabinetGameRecord game) {
    return _enqueueResult<bool>(() async {
      final games = await repository.readGames(game.userId);
      final duplicate =
          games.any((item) => item.duplicateKey == game.duplicateKey);
      if (duplicate) return false;
      games.insert(0, game);
      await repository.writeGames(game.userId, games);
      return true;
    });
  }

  Future<void> deleteGame({
    required String userId,
    required String gameId,
  }) {
    return _enqueue(() async {
      final games = await repository.readGames(userId);
      games.removeWhere((item) => item.id == gameId);
      await repository.writeGames(userId, games);
    });
  }

  Future<void> _enqueue(Future<void> Function() action) {
    // Важно сохранить предыдущую очередь ДО назначения нового задания.
    // Иначе новое задание начинает ждать само себя и загрузка кабинета
    // навсегда остаётся на круговом индикаторе.
    final previous = _writeQueue;
    final task = Future<void>(() async {
      await previous;
      await action();
    });
    _writeQueue = task.catchError((_) {});
    return task;
  }

  Future<T> _enqueueResult<T>(Future<T> Function() action) {
    // Та же защита от самоблокировки для операций с результатом.
    final previous = _writeQueue;
    final task = Future<T>(() async {
      await previous;
      return action();
    });
    _writeQueue = task.then<void>((_) {}).catchError((_) {});
    return task;
  }
}
