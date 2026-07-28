import 'package:flutter/material.dart';

/// Палитра, которую можно менять из меню "Настройки".
class AppPalette {
  final Color bg; // фон страниц
  final Color card; // карточки/панели
  final Color primary; // основные кнопки
  final Color accent; // акцентные элементы (иконки/выделения)
  final Color text; // основной текст
  final Color subtext; // вторичный текст

  const AppPalette({
    required this.bg,
    required this.card,
    required this.primary,
    required this.accent,
    required this.text,
    required this.subtext,
  });

  AppPalette copyWith({
    Color? bg,
    Color? card,
    Color? primary,
    Color? accent,
    Color? text,
    Color? subtext,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      card: card ?? this.card,
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      text: text ?? this.text,
      subtext: subtext ?? this.subtext,
    );
  }
}

/// Контроллер темы (подключается к Settings и дергает notifyListeners()).
class AppTheme extends ChangeNotifier {
  AppPalette _palette = const AppPalette(
    bg: Color(0xFFF4ECF7), // мягкий светлый фон
    card: Color(0xFFFFFFFF), // белые карточки
    primary: Color(0xFF7352C7), // фиолетовая кнопка
    accent: Color(0xFFE39A5B), // тёплый акцент (оранжево-терракотовый)
    text: Color(0xFF221A2D), // почти-чёрный текст
    subtext: Color(0xFF7B6E8C), // мягкий серо-фиолетовый
  );

  AppPalette get palette => _palette;

  void updatePalette(AppPalette p) {
    _palette = p;
    notifyListeners();
  }

  /// Превращаем палитру в ThemeData.
  ThemeData toThemeData() {
    final cs = ColorScheme.fromSeed(
      seedColor: _palette.primary,
      background: _palette.bg,
      brightness: Brightness.light,
      primary: _palette.primary,
      secondary: _palette.accent,
      surface: _palette.card,
      onSurface: _palette.text,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    );

    return ThemeData(
      colorScheme: cs,
      scaffoldBackgroundColor: _palette.bg,
      useMaterial3: true,
      textTheme: Typography.blackMountainView.apply(
        bodyColor: _palette.text,
        displayColor: _palette.text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _palette.bg,
        foregroundColor: _palette.text,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _palette.primary,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _palette.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _palette.subtext.withOpacity(.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _palette.subtext.withOpacity(.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _palette.accent, width: 1.6),
        ),
        labelStyle: TextStyle(color: _palette.subtext),
      ),
      cardTheme: CardThemeData(
        color: _palette.card,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerColor: _palette.subtext.withOpacity(.2),
      iconTheme: IconThemeData(color: _palette.accent),
    );
  }
}
