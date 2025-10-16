// lib/services/bg_controller.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BgController extends ChangeNotifier {
  BgController._();
  static final BgController instance = BgController._();

  static const _kKey = 'bg_image_base64';

  Uint8List? _bgBytes;
  Uint8List? get bgBytes => _bgBytes;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final b64 = sp.getString(_kKey);
    if (b64 == null || b64.isEmpty) return;
    try {
      _bgBytes = base64Decode(b64);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setBg(Uint8List? bytes) async {
    _bgBytes = bytes;
    final sp = await SharedPreferences.getInstance();
    if (bytes == null) {
      await sp.remove(_kKey);
    } else {
      await sp.setString(_kKey, base64Encode(bytes));
    }
    notifyListeners();
  }

  Future<void> reset() => setBg(null);
}
