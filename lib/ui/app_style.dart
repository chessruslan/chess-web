import 'package:flutter/material.dart';

class AppStyle {
  AppStyle._();
}

class AppColors {
  AppColors._();

  static const Color appBg = Color(0xFF1B1E23);
  static const Color appBgSoft = Color(0xFF22262C);

  static const Color surface = Color(0xFF2A2E35);
  static const Color surfaceSoft = Color(0xFF30353D);
  static const Color surfaceCard = Color(0xFF262A31);

  static const Color accent = Color(0xFF00CFFF);
  static const Color accentSoft = Color(0xFF00B8E6);
  static const Color accentDeep = Color(0xFF0B7FA5);

  static const Color accentGlow = Color(0x6600CFFF);
  static const Color accentGlowSoft = Color(0x3300CFFF);

  static const Color text = Color(0xFFE9F7FF);
  static const Color textDim = Color(0xFF98A9B8);
  static const Color textMuted = Color(0xFF7E8C98);
  static const Color textDark = Color(0xFF111827);

  static const Color border = Color(0xFF111418);
  static const Color borderSoft = Color(0xFF3A4048);
  static const Color borderBright = Color(0xFF11CFFF);

  static const Color success = Color(0xFF39D98A);
  static const Color warning = Color(0xFFFFC857);
  static const Color danger = Color(0xFFFF6B6B);

  static const Color paper = Color(0xFFF3F4F6);
  static const Color paperBorder = Color(0xFF2A2A2A);

  static const Color boardLight = Color(0xFFE7D3B0);
  static const Color boardDark = Color(0xFFAE825C);
  static const Color boardBorder = Color(0xFF171A1F);

  static const Color legalMove = Color(0x8839D98A);
  static const Color captureMove = Color(0x88FF6B6B);
  static const Color selected = Color(0xAA00CFFF);

  static const Color topBarBgTop = Color(0xFF3E434A);
  static const Color topBarBgMid = Color(0xFF2A2E35);
  static const Color topBarBgBottom = Color(0xFF1C2025);

  static const Color topBarMenu = Color(0xFFD7DCE2);
  static const Color topBarMenuHover = Color(0xFF00CFFF);

  static const Color neoButtonTop = Color(0xFF4E545B);
  static const Color neoButtonMid = Color(0xFF2B3037);
  static const Color neoButtonBottom = Color(0xFF181C21);

  static const Color neoButtonPressedTop = Color(0xFF1A1D22);
  static const Color neoButtonPressedMid = Color(0xFF111419);
  static const Color neoButtonPressedBottom = Color(0xFF0D1014);

  static const Color topBarShadow = Color(0x88000000);
  static const Color topBarHighlight = Color(0x22FFFFFF);
}

class AppRadius {
  AppRadius._();

  static BorderRadius get r8 => BorderRadius.circular(8);
  static BorderRadius get r10 => BorderRadius.circular(10);
  static BorderRadius get r12 => BorderRadius.circular(12);
  static BorderRadius get r14 => BorderRadius.circular(14);
  static BorderRadius get r16 => BorderRadius.circular(16);
  static BorderRadius get r20 => BorderRadius.circular(20);
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  static const EdgeInsets page = EdgeInsets.all(12);
  static const EdgeInsets panel = EdgeInsets.all(12);
  static const EdgeInsets card = EdgeInsets.all(16);

  static const EdgeInsets inputPadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 10);

  static const EdgeInsets buttonPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 12);

  static const EdgeInsets buttonPaddingCompact =
      EdgeInsets.symmetric(horizontal: 12, vertical: 10);

  static const EdgeInsets topBarButtonPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 0);
}

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
    letterSpacing: 0.2,
  );

  static const TextStyle panelTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.text,
  );

  static const TextStyle bodyDim = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textDim,
  );

  static const TextStyle muted = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textDim,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textDim,
  );

  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
    letterSpacing: 0.1,
  );

  static const TextStyle buttonCompact = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  static const TextStyle lightPanelTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
  );

  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    color: AppColors.text,
  );

  static const TextStyle topBarTitle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: Color(0xFFF2F5F7),
    letterSpacing: 0.2,
    shadows: [
      Shadow(
        color: Color(0x55000000),
        blurRadius: 6,
        offset: Offset(0, 1),
      ),
    ],
  );

  static const TextStyle topBarMenu = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.topBarMenu,
  );

  static const TextStyle topBarButton = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  static const TextStyle scaleText = TextStyle(
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
}

class AppDecorations {
  AppDecorations._();

  static LinearGradient get panelGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF343942),
          Color(0xFF2B2F36),
          Color(0xFF24282E),
        ],
      );

  static LinearGradient get buttonGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.neoButtonTop,
          AppColors.neoButtonMid,
          AppColors.neoButtonBottom,
        ],
      );

  static LinearGradient get activeButtonGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF464D55),
          Color(0xFF23282F),
          Color(0xFF171B20),
        ],
      );

  static LinearGradient get pressedButtonGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.neoButtonPressedTop,
          AppColors.neoButtonPressedMid,
          AppColors.neoButtonPressedBottom,
        ],
      );

  static LinearGradient get topBarGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.topBarBgTop,
          AppColors.topBarBgMid,
          AppColors.topBarBgBottom,
        ],
      );

  static BoxDecoration panel({
    bool bright = false,
    bool soft = false,
  }) {
    return BoxDecoration(
      gradient: panelGradient,
      color: soft ? AppColors.surfaceSoft : AppColors.surface,
      borderRadius: AppRadius.r16,
      border: Border.all(
        color: bright ? AppColors.borderBright : AppColors.borderSoft,
        width: bright ? 1.2 : 1,
      ),
      boxShadow: [
        const BoxShadow(
          color: Color(0x88000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
        if (bright)
          const BoxShadow(
            color: AppColors.accentGlowSoft,
            blurRadius: 18,
            spreadRadius: 1,
          ),
      ],
    );
  }

  static BoxDecoration card({
    bool highlighted = false,
  }) {
    return BoxDecoration(
      gradient: panelGradient,
      borderRadius: AppRadius.r14,
      border: Border.all(
        color: highlighted ? AppColors.borderBright : AppColors.borderSoft,
        width: 1,
      ),
      boxShadow: [
        const BoxShadow(
          color: Color(0x77000000),
          blurRadius: 12,
          offset: Offset(0, 6),
        ),
        if (highlighted)
          const BoxShadow(
            color: AppColors.accentGlowSoft,
            blurRadius: 14,
          ),
      ],
    );
  }

  static BoxDecoration lightPanel() {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFF7F8FA),
          Color(0xFFE9EDF2),
        ],
      ),
      border: Border.all(color: AppColors.paperBorder, width: 1.1),
      borderRadius: AppRadius.r10,
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    );
  }

  static BoxDecoration boardFrame() {
    return BoxDecoration(
      color: AppColors.boardBorder,
      borderRadius: AppRadius.r12,
      border: Border.all(color: AppColors.borderBright, width: 1.2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x88000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
        BoxShadow(
          color: AppColors.accentGlowSoft,
          blurRadius: 12,
        ),
      ],
    );
  }

  static BoxDecoration topBar() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.topBarBgTop,
          AppColors.topBarBgMid,
          AppColors.topBarBgBottom,
        ],
      ),
      border: Border(
        bottom: BorderSide(color: AppColors.border, width: 1),
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.topBarShadow,
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
        BoxShadow(
          color: AppColors.accentGlowSoft,
          blurRadius: 10,
        ),
      ],
    );
  }

  static BoxDecoration neoButton({
    bool active = false,
    bool pressed = false,
    bool danger = false,
    bool enabled = true,
  }) {
    return BoxDecoration(
      gradient: pressed
          ? pressedButtonGradient
          : (active ? activeButtonGradient : buttonGradient),
      borderRadius: AppRadius.r12,
      border: Border.all(
        color: !enabled
            ? AppColors.borderSoft
            : danger
                ? AppColors.danger
                : (active ? AppColors.borderBright : AppColors.border),
        width: active ? 1.2 : 1,
      ),
      boxShadow: [
        const BoxShadow(
          color: AppColors.topBarShadow,
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
        const BoxShadow(
          color: AppColors.topBarHighlight,
          blurRadius: 0,
          offset: Offset(0, 1),
        ),
        if (active)
          BoxShadow(
            color: danger ? const Color(0x44FF6B6B) : AppColors.accentGlow,
            blurRadius: 14,
            spreadRadius: 0.4,
          ),
      ],
    );
  }

  static BoxDecoration scaleBox() {
    return BoxDecoration(
      gradient: buttonGradient,
      borderRadius: AppRadius.r16,
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: AppColors.topBarShadow,
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    );
  }
}

class AppButtons {
  AppButtons._();

  static ButtonStyle primary({
    bool active = false,
    bool compact = false,
  }) {
    return ButtonStyle(
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      foregroundColor: const WidgetStatePropertyAll(AppColors.text),
      overlayColor: const WidgetStatePropertyAll(Color(0x1400CFFF)),
      elevation: const WidgetStatePropertyAll(0),
      padding: WidgetStatePropertyAll(
        compact ? AppSpacing.buttonPaddingCompact : AppSpacing.buttonPadding,
      ),
      textStyle: WidgetStatePropertyAll(
        compact ? AppTextStyles.buttonCompact : AppTextStyles.button,
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: AppRadius.r10,
          side: BorderSide(
            color: active ? AppColors.borderBright : AppColors.border,
            width: active ? 1.2 : 1,
          ),
        ),
      ),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }

  static ButtonStyle secondary({
    bool compact = false,
  }) {
    return ButtonStyle(
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      foregroundColor: const WidgetStatePropertyAll(AppColors.text),
      overlayColor: const WidgetStatePropertyAll(Color(0x1400CFFF)),
      elevation: const WidgetStatePropertyAll(0),
      padding: WidgetStatePropertyAll(
        compact ? AppSpacing.buttonPaddingCompact : AppSpacing.buttonPadding,
      ),
      textStyle: WidgetStatePropertyAll(
        compact ? AppTextStyles.buttonCompact : AppTextStyles.button,
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: AppRadius.r10,
          side: const BorderSide(
            color: AppColors.borderBright,
            width: 1,
          ),
        ),
      ),
    );
  }

  static ButtonStyle lightPrimary() {
    return FilledButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textDark,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.r10),
      elevation: 0,
    );
  }

  static ButtonStyle danger() {
    return ButtonStyle(
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      foregroundColor: const WidgetStatePropertyAll(Colors.white),
      overlayColor: const WidgetStatePropertyAll(Color(0x14FF6B6B)),
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: AppRadius.r10,
          side: const BorderSide(color: AppColors.danger, width: 1),
        ),
      ),
    );
  }
}

class AppInputs {
  AppInputs._();

  static InputDecoration dark({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    bool dense = false,
  }) {
    return InputDecoration(
      isDense: dense,
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: const Color(0xFF1A1E24),
      contentPadding: AppSpacing.inputPadding,
      labelStyle: AppTextStyles.muted,
      hintStyle: AppTextStyles.muted,
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.r10,
        borderSide: const BorderSide(color: AppColors.borderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.r10,
        borderSide: const BorderSide(
          color: AppColors.borderBright,
          width: 1.2,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadius.r10,
      ),
    );
  }

  static InputDecoration light({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    bool dense = false,
  }) {
    return InputDecoration(
      isDense: dense,
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      contentPadding: AppSpacing.inputPadding,
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.r10,
        borderSide: const BorderSide(color: Color(0xFFBFC7D1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.r10,
        borderSide: const BorderSide(
          color: AppColors.accentSoft,
          width: 1.2,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadius.r10,
      ),
    );
  }
}

class AppBoardStyle {
  AppBoardStyle._();

  static const Color lightSquare = AppColors.boardLight;
  static const Color darkSquare = AppColors.boardDark;
  static const Color selectedSquare = AppColors.selected;
  static const Color legalTarget = AppColors.legalMove;
  static const Color captureTarget = AppColors.captureMove;

  static BoxDecoration frame() => AppDecorations.boardFrame();
}

class AppNeoButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;
  final bool showIcon;
  final bool compact;

  const AppNeoButton({
    super.key,
    required this.text,
    required this.icon,
    this.onTap,
    this.danger = false,
    this.showIcon = true,
    this.compact = false,
  });

  @override
  State<AppNeoButton> createState() => _AppNeoButtonState();
}

class _AppNeoButtonState extends State<AppNeoButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 4 : 14,
            vertical: widget.compact ? 8 : 12,
          ),
          decoration: AppDecorations.neoButton(
            active: _hover,
            pressed: _pressed,
            danger: widget.danger,
            enabled: enabled,
          ),
          child: Row(
            children: [
              if (widget.showIcon) ...[
                Icon(widget.icon, size: widget.compact ? 14 : 18, color: AppColors.text),
                SizedBox(width: widget.compact ? 4 : 10),
              ],
              Expanded(
                child: Text(
                  widget.text,
                  textAlign: widget.showIcon ? TextAlign.start : TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: widget.compact
                      ? AppTextStyles.buttonCompact.copyWith(fontSize: 10)
                      : AppTextStyles.button,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
