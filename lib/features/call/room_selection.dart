import 'package:flutter/foundation.dart';

/// Глобальный буфер выбранной комнаты (обычно это ник соперника).
class RoomSelection extends ChangeNotifier {
  RoomSelection._();
  static final RoomSelection instance = RoomSelection._();

  String? _room;
  String? get room => _room;

  void setRoom(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return;
    _room = v;
    notifyListeners();
  }

  void clear() {
    _room = null;
    notifyListeners();
  }
}
