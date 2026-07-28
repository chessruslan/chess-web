import 'package:flutter/material.dart';

import 'app_style.dart';

class AppControls {
  AppControls._();

  static const Color accent = AppColors.accent;
  static const Color accentSoft = AppColors.accentSoft;

  static const Color bg = AppColors.appBg;
  static const Color panel = AppColors.surface;
  static const Color panelSoft = AppColors.surfaceSoft;

  static const Color border = AppColors.border;
  static const Color borderBright = AppColors.borderBright;

  static const Color text = AppColors.text;
  static const Color textDim = AppColors.textDim;

  static BorderRadius get r12 => AppRadius.r12;
  static BorderRadius get r14 => AppRadius.r14;
  static BorderRadius get r16 => AppRadius.r16;

  static BoxDecoration panelDecoration({
    bool bright = false,
    bool soft = false,
  }) {
    return AppDecorations.panel(
      bright: bright,
      soft: soft,
    );
  }

  static ButtonStyle pillButton({
    bool active = false,
    bool compact = false,
  }) {
    return AppButtons.primary(
      active: active,
      compact: compact,
    );
  }

  static ButtonStyle outlinedPill({
    bool compact = false,
  }) {
    return AppButtons.secondary(
      compact: compact,
    );
  }

  static InputDecoration input({
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool dense = false,
  }) {
    return AppInputs.dark(
      hintText: hintText,
      labelText: labelText,
      prefixIcon: prefixIcon,
      dense: dense,
    ).copyWith(
      suffixIcon: suffixIcon,
    );
  }

  static const TextStyle sectionTitle = AppTextStyles.panelTitle;
  static const TextStyle muted = AppTextStyles.muted;
}