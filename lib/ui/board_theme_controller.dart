import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BoardThemeController extends ChangeNotifier {
  static const _personalKey = 'board_theme_personal_override';
  static const _lightKey = 'board_theme_light';
  static const _darkKey = 'board_theme_dark';

  Color lightSquare = const Color(0xFFE7D3B0);
  Color darkSquare = const Color(0xFFAE825C);
  bool _hasPersonalTheme = false;

  bool get hasPersonalTheme => _hasPersonalTheme;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _hasPersonalTheme = prefs.getBool(_personalKey) ?? false;
    if (!_hasPersonalTheme) return;
    final light = prefs.getInt(_lightKey);
    final dark = prefs.getInt(_darkKey);
    if (light != null) lightSquare = Color(light);
    if (dark != null) darkSquare = Color(dark);
    notifyListeners();
  }

  void setLight(Color color) {
    lightSquare = color;
    _markPersonal();
    notifyListeners();
  }

  void setDark(Color color) {
    darkSquare = color;
    _markPersonal();
    notifyListeners();
  }

  void setTheme(Color light, Color dark) {
    lightSquare = light;
    darkSquare = dark;
    _markPersonal();
    notifyListeners();
  }

  void applySiteDefault(Color light, Color dark) {
    if (_hasPersonalTheme) return;
    lightSquare = light;
    darkSquare = dark;
    notifyListeners();
  }

  Future<void> resetToSiteDefault(Color light, Color dark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_personalKey);
    await prefs.remove(_lightKey);
    await prefs.remove(_darkKey);
    _hasPersonalTheme = false;
    lightSquare = light;
    darkSquare = dark;
    notifyListeners();
  }

  void _markPersonal() {
    _hasPersonalTheme = true;
    unawaited(_savePersonal());
  }

  Future<void> _savePersonal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_personalKey, true);
    await prefs.setInt(_lightKey, lightSquare.value);
    await prefs.setInt(_darkKey, darkSquare.value);
  }
}
