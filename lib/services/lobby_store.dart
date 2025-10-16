import 'package:flutter/foundation.dart';

class LobbyUser {
  final String id;
  final String username;
  final int? rating;
  final bool isMe;

  const LobbyUser({
    required this.id,
    required this.username,
    this.rating,
    this.isMe = false,
  });
}

class LobbyStore {
  LobbyStore._();
  static final instance = LobbyStore._();

  /// Единый источник списка игроков для всего приложения.
  /// СЛУШАЕМ через .users, читаем список через .users.value
  final ValueNotifier<List<LobbyUser>> users =
      ValueNotifier<List<LobbyUser>>(<LobbyUser>[]);

  void set(List<LobbyUser> v) => users.value = List.unmodifiable(v);
  void clear() => users.value = const <LobbyUser>[];
}
