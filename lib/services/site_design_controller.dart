import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../ui/board_theme_controller.dart';
import 'bg_controller.dart';

class SiteDesignSettings {
  const SiteDesignSettings({
    this.boardLight = 0xFFE7D3B0,
    this.boardDark = 0xFFAE825C,
    this.backgroundBase64,
    this.piecesTheme = 'Классические',
    this.buttonsTheme = 'Графит и неон',
    this.fieldsTheme = 'Тёмные',
    this.bordersTheme = 'Голубое свечение',
    this.fontTheme = 'Системный',
  });

  final int boardLight;
  final int boardDark;
  final String? backgroundBase64;
  final String piecesTheme;
  final String buttonsTheme;
  final String fieldsTheme;
  final String bordersTheme;
  final String fontTheme;

  SiteDesignSettings copyWith({
    int? boardLight,
    int? boardDark,
    String? backgroundBase64,
    bool clearBackground = false,
    String? piecesTheme,
    String? buttonsTheme,
    String? fieldsTheme,
    String? bordersTheme,
    String? fontTheme,
  }) =>
      SiteDesignSettings(
        boardLight: boardLight ?? this.boardLight,
        boardDark: boardDark ?? this.boardDark,
        backgroundBase64:
            clearBackground ? null : backgroundBase64 ?? this.backgroundBase64,
        piecesTheme: piecesTheme ?? this.piecesTheme,
        buttonsTheme: buttonsTheme ?? this.buttonsTheme,
        fieldsTheme: fieldsTheme ?? this.fieldsTheme,
        bordersTheme: bordersTheme ?? this.bordersTheme,
        fontTheme: fontTheme ?? this.fontTheme,
      );

  Map<String, dynamic> toJson() => {
        'board_light': boardLight,
        'board_dark': boardDark,
        'pieces_theme': piecesTheme,
        'buttons_theme': buttonsTheme,
        'fields_theme': fieldsTheme,
        'borders_theme': bordersTheme,
        'font_theme': fontTheme,
      };

  factory SiteDesignSettings.fromRow(Map<String, dynamic> row) {
    final settings = Map<String, dynamic>.from(
      row['settings'] as Map? ?? const <String, dynamic>{},
    );
    return SiteDesignSettings(
      boardLight: (settings['board_light'] as num?)?.toInt() ?? 0xFFE7D3B0,
      boardDark: (settings['board_dark'] as num?)?.toInt() ?? 0xFFAE825C,
      backgroundBase64: row['background_base64'] as String?,
      piecesTheme: '${settings['pieces_theme'] ?? 'Классические'}',
      buttonsTheme: '${settings['buttons_theme'] ?? 'Графит и неон'}',
      fieldsTheme: '${settings['fields_theme'] ?? 'Тёмные'}',
      bordersTheme: '${settings['borders_theme'] ?? 'Голубое свечение'}',
      fontTheme: '${settings['font_theme'] ?? 'Системный'}',
    );
  }
}

class SiteDesignController extends ChangeNotifier {
  SiteDesignController._();
  static final instance = SiteDesignController._();

  static const _personalVisualKey = 'site_visual_personal_override';
  static const _personalVisualSettingsKey = 'site_visual_personal_settings';

  SiteDesignSettings _defaults = const SiteDesignSettings();
  SiteDesignSettings? _personalVisual;
  bool _loaded = false;

  SiteDesignSettings get defaults => _defaults;
  SiteDesignSettings get effective => _personalVisual ?? _defaults;
  bool get hasPersonalVisual => _personalVisual != null;
  bool get loaded => _loaded;

  Future<void> initialize({
    required BoardThemeController boardTheme,
    required BgController background,
  }) async {
    await boardTheme.load();
    await _loadPersonalVisual();
    try {
      final row = await Supabase.instance.client
          .from('site_design_defaults')
          .select('settings, background_base64')
          .eq('id', 1)
          .maybeSingle();
      if (row != null) _defaults = SiteDesignSettings.fromRow(row);
    } catch (error) {
      debugPrint('[SITE DESIGN] Default loading failed: $error');
    }
    _loaded = true;
    _applyDefaults(boardTheme, background);
    notifyListeners();
  }

  Future<void> refresh({
    required BoardThemeController boardTheme,
    required BgController background,
  }) async {
    _loaded = false;
    await initialize(boardTheme: boardTheme, background: background);
  }

  Future<void> saveDefaults({
    required SiteDesignSettings settings,
    required String adminPassword,
    required BoardThemeController boardTheme,
    required BgController background,
  }) async {
    await Supabase.instance.client.rpc(
      'admin_update_site_design',
      params: {
        'p_admin_password': adminPassword,
        'p_settings': settings.toJson(),
        'p_background_base64': settings.backgroundBase64,
      },
    );
    _defaults = settings;
    _applyDefaults(boardTheme, background);
    notifyListeners();
  }

  Future<void> savePersonalVisual(SiteDesignSettings settings) async {
    _personalVisual = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_personalVisualKey, true);
    await prefs.setString(
      _personalVisualSettingsKey,
      jsonEncode(settings.toJson()),
    );
    notifyListeners();
  }

  Future<void> resetPersonalVisual() async {
    _personalVisual = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_personalVisualKey);
    await prefs.remove(_personalVisualSettingsKey);
    notifyListeners();
  }

  void _applyDefaults(
    BoardThemeController boardTheme,
    BgController background,
  ) {
    boardTheme.applySiteDefault(
      Color(_defaults.boardLight),
      Color(_defaults.boardDark),
    );
    background.applySiteDefault(_decodeBackground(_defaults.backgroundBase64));
  }

  Uint8List? _decodeBackground(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadPersonalVisual() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_personalVisualKey) ?? false)) return;
    final raw = prefs.getString(_personalVisualSettingsKey);
    if (raw == null) return;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      _personalVisual = SiteDesignSettings.fromRow({'settings': json});
    } catch (_) {}
  }
}
