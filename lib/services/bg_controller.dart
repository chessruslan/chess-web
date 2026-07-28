import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BgController extends ChangeNotifier {
  BgController._();
  static final BgController instance = BgController._();

  static const _imageKey = 'bg_image_base64';
  static const _personalKey = 'bg_personal_override';

  Uint8List? _bgBytes;
  Uint8List? _siteDefaultBytes;
  bool _hasPersonalBackground = false;

  Uint8List? get bgBytes => _bgBytes;
  bool get hasPersonalBackground => _hasPersonalBackground;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_imageKey);
    // Existing saved backgrounds predate the explicit override marker and
    // must remain personal choices after this update.
    _hasPersonalBackground =
        prefs.getBool(_personalKey) ?? (encoded != null && encoded.isNotEmpty);
    if (!_hasPersonalBackground || encoded == null || encoded.isEmpty) return;
    try {
      _bgBytes = base64Decode(encoded);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setBg(Uint8List? bytes) async {
    _hasPersonalBackground = true;
    _bgBytes = bytes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_personalKey, true);
    if (bytes == null) {
      await prefs.remove(_imageKey);
    } else {
      await prefs.setString(_imageKey, base64Encode(bytes));
    }
    notifyListeners();
  }

  void applySiteDefault(Uint8List? bytes) {
    _siteDefaultBytes = bytes;
    if (_hasPersonalBackground) return;
    _bgBytes = bytes;
    notifyListeners();
  }

  Future<void> resetToSiteDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_personalKey);
    await prefs.remove(_imageKey);
    _hasPersonalBackground = false;
    _bgBytes = _siteDefaultBytes;
    notifyListeners();
  }

  Future<void> reset() => setBg(null);
}
