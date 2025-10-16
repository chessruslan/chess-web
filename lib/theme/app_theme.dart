import 'package:flutter/material.dart';

/// === Единая палитра для всех кнопок и UI ===
class AppColors {
  static const Color buttonBg = Color(0xFF6C63FF);
  static const Color buttonFg = Colors.white;

  static const Color buttonHover = Color(0xFF5B54D9);
  static const Color buttonPressed = Color(0xFF4A45B5);

  static const Color buttonDisabledBg = Color(0xFFE9E6F5);
  static const Color buttonDisabledFg = Color(0xFF9A98A6);

  static const Color outline = Color(0xFFD5CFF0);
  static const Color textButtonBg = Color(0xFFF3F0FF);
}

/// === Главная тема приложения ===
class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.buttonBg,
        brightness: Brightness.light,
      ),
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    // Универсальные функции для состояний
    Color _resolveBg(Set<WidgetState> s, Color baseColor) {
      if (s.contains(WidgetState.disabled)) return AppColors.buttonDisabledBg;
      if (s.contains(WidgetState.pressed)) return AppColors.buttonPressed;
      if (s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)) {
        return AppColors.buttonHover;
      }
      return baseColor;
    }

    Color _resolveFg(Set<WidgetState> s, Color baseColor) {
      if (s.contains(WidgetState.disabled)) return AppColors.buttonDisabledFg;
      return baseColor;
    }

    return base.copyWith(
      // ===== TextButton (плоские кнопки, вкладки меню и т.п.) =====
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => _resolveBg(s, AppColors.textButtonBg),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => _resolveFg(s, Colors.black87),
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.black12),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          shape: WidgetStatePropertyAll(shape),
        ),
      ),

      // ===== FilledButton (основные фиолетовые) =====
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => _resolveBg(s, AppColors.buttonBg),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => _resolveFg(s, AppColors.buttonFg),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          shape: WidgetStatePropertyAll(shape),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),

      // ===== ElevatedButton (если где-то используется) =====
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => _resolveBg(s, AppColors.buttonBg),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => _resolveFg(s, AppColors.buttonFg),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          shape: WidgetStatePropertyAll(shape),
          elevation: const WidgetStatePropertyAll(2),
          shadowColor: const WidgetStatePropertyAll(Colors.black26),
        ),
      ),

      // ===== OutlinedButton (контурные кнопки / “пилюли”) =====
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.outline),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => _resolveBg(s, Colors.white),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => _resolveFg(s, Colors.black87),
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.black12),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          shape: WidgetStatePropertyAll(shape),
        ),
      ),

      // ===== IconButton (чтобы не был прозрачным) =====
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          overlayColor: const WidgetStatePropertyAll(Colors.black12),
          shape: WidgetStatePropertyAll(shape),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
          foregroundColor: const WidgetStatePropertyAll(Colors.black87),
        ),
      ),

      // ===== Chips =====
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.textButtonBg,
        selectedColor: AppColors.buttonBg,
        labelStyle: const TextStyle(color: Colors.black87),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: shape,
      ),
    );
  }
}
