// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
// MAKECHESS_BIG_LOCALIZATION_STAGE_V4_20260807
// lib/ui/start_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_style.dart';
import '../localization/makechess_localization.dart';

/// ===== StartModal: окно с тарифами =====
class StartModal {
  static bool _isOpen = false;
  static bool get isOpen => _isOpen;

  static Future<void> show({
    required BuildContext context,
    required VoidCallback onFree,
    required VoidCallback onPro,
    required VoidCallback onPremium,
    required VoidCallback onLogin,
    required VoidCallback onRegister,
    VoidCallback? onSchool,
    bool rootNavigator = false,
  }) {
    if (_isOpen) return Future.value();
    _isOpen = true;

    final rootNav = Navigator.of(context, rootNavigator: rootNavigator);

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      useSafeArea: true,
      builder: (ctx) {
        return GestureDetector(
          onTap: () {},
          child: Stack(
            alignment: Alignment.center,
            children: [
              const _Backdrop(opacity: 0.45),
              _EscListener(
                onEsc: () => rootNav.pop(),
                child: Center(
                  child: _PricingCard(
                    onClose: () => rootNav.pop(),
                    onFree: () {
                      rootNav.pop();
                      onFree();
                    },
                    onPro: () {
                      rootNav.pop();
                      onPro();
                    },
                    onPremium: () {
                      rootNav.pop();
                      onPremium();
                    },
                    onSchool: onSchool == null
                        ? null
                        : () {
                            rootNav.pop();
                            onSchool();
                          },
                    onLogin: () {
                      rootNav.pop();
                      onLogin();
                    },
                    onRegister: () {
                      rootNav.pop();
                      onRegister();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      _isOpen = false;
    });
  }
}

/// Полупрозрачный фон
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.opacity});
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity((opacity + 0.10).clamp(0.0, 1.0)),
              AppColors.appBg.withOpacity((opacity + 0.05).clamp(0.0, 1.0)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Основная карточка модалки (список тарифов)
class _PricingCard extends StatelessWidget {
  const _PricingCard({
    required this.onClose,
    required this.onFree,
    required this.onPro,
    required this.onPremium,
    required this.onLogin,
    required this.onRegister,
    this.onSchool,
  });

  final VoidCallback onClose;
  final VoidCallback onFree;
  final VoidCallback onPro;
  final VoidCallback onPremium;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback? onSchool;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
          decoration: AppDecorations.panel(bright: true),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: MakeChessLocalizedText(
                      'MakeChess',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: 0.3,
                        shadows: [
                          Shadow(
                            color: AppColors.accentGlow,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: AppRadius.r10,
                    onTap: onClose,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: AppDecorations.neoButton(
                        active: false,
                        pressed: false,
                        enabled: true,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const MakeChessLocalizedText(
                'Выберите режим доступа к платформе',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyDim,
              ),
              const SizedBox(height: 18),
              _PlanTile(
                highlight: true,
                title: 'Играть бесплатно',
                subtitle: 'Игра по сети. Редактор доски.',
                showChevron: true,
                onTap: onFree,
              ),
              const SizedBox(height: 10),
              _PlanTile(
                title: 'Pro — расширенная версия',
                subtitle: '+ Анализ, совместный режим',
                trialLabel: '7 дней бесплатно',
                showChevron: true,
                onTap: () {
                  PaymentModal.show(
                    context: context,
                    planTitle: 'Pro — расширенная версия',
                    price: '290 ₽ / месяц',
                    features: const [
                      'Совместная доска',
                      'Продвинутый анализ Stockfish (до 4 линий)',
                    ],
                    onPay: onPro,
                    onTrial: onPro,
                  );
                },
                onTrialTap: () {
                  PaymentModal.show(
                    context: context,
                    planTitle: 'Pro — расширенная версия',
                    price: 'Пробный период 7 дней',
                    features: const [
                      'Совместная доска',
                      'Продвинутый анализ Stockfish (до 4 линий)',
                    ],
                    onPay: onPro,
                    onTrial: onPro,
                  );
                },
              ),
              const SizedBox(height: 10),
              _PlanTile(
                title: 'Premium — полный доступ',
                subtitle: '+ Видеосвязь',
                trialLabel: '7 дней бесплатно',
                showChevron: true,
                onTap: () {
                  PaymentModal.show(
                    context: context,
                    planTitle: 'Premium — полный доступ',
                    price: '390 ₽ / месяц',
                    features: const [
                      'Совместная доска',
                      'Анализ Stockfish (до 4 линий)',
                      'Видеосвязь и онлайн-школа',
                    ],
                    onPay: onPremium,
                    onTrial: onPremium,
                  );
                },
                onTrialTap: () {
                  PaymentModal.show(
                    context: context,
                    planTitle: 'Premium — полный доступ',
                    price: 'Пробный период 7 дней',
                    features: const [
                      'Совместная доска',
                      'Анализ Stockfish (до 4 линий)',
                      'Видеосвязь и онлайн-школа',
                    ],
                    onPay: onPremium,
                    onTrial: onPremium,
                  );
                },
              ),
              const SizedBox(height: 10),
              _PlanTile(
                title: 'Онлайн школа',
                subtitle: 'Курсы и занятия',
                trialLabel: '7 дней бесплатно',
                showChevron: true,
                onTap: onSchool ?? () {},
                onTrialTap: onSchool,
                disabled: onSchool == null,
              ),
              const SizedBox(height: 18),
              const Divider(color: AppColors.borderSoft, height: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _BottomButton(
                      text: 'Войти',
                      onTap: onLogin,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BottomButton(
                      text: 'Регистрация',
                      onTap: onRegister,
                      filled: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Строка с планом (универсальная)
class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trialLabel,
    this.onTrialTap,
    this.highlight = false,
    this.showChevron = false,
    this.disabled = false,
  });

  final String title;
  final String? subtitle;
  final String? trialLabel;
  final VoidCallback onTap;
  final VoidCallback? onTrialTap;
  final bool highlight;
  final bool showChevron;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        highlight ? AppColors.borderBright : AppColors.borderSoft;

    final tile = InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: AppRadius.r14,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: highlight
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0E3A46),
                    Color(0xFF0A2D36),
                    Color(0xFF08232A),
                  ],
                )
              : AppDecorations.panelGradient,
          borderRadius: AppRadius.r14,
          border: Border.all(color: borderColor, width: highlight ? 1.2 : 1),
          boxShadow: [
            const BoxShadow(
              color: Color(0x77000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
            if (highlight)
              const BoxShadow(
                color: AppColors.accentGlowSoft,
                blurRadius: 14,
              ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MakeChessLocalizedText(
                    title,
                    style: AppTextStyles.panelTitle.copyWith(
                      color: AppColors.text,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    MakeChessLocalizedText(
                      subtitle!,
                      style: AppTextStyles.bodyDim.copyWith(
                        color: highlight ? AppColors.text : AppColors.textDim,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trialLabel != null)
              _TrialPill(
                label: trialLabel!,
                onTap: disabled ? null : (onTrialTap ?? onTap),
              ),
            if (showChevron) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textDim,
              ),
            ],
          ],
        ),
      ),
    );

    return Opacity(
      opacity: disabled ? .5 : 1,
      child: tile,
    );
  }
}

class _TrialPill extends StatelessWidget {
  const _TrialPill({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF14D9FF),
                Color(0xFF00A9D1),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderBright),
            boxShadow: const [
              BoxShadow(
                color: AppColors.accentGlow,
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              MakeChessLocalizedText(
                label,
                style: AppTextStyles.buttonCompact.copyWith(
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textDark,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomButton extends StatefulWidget {
  const _BottomButton({
    required this.text,
    required this.onTap,
    this.filled = false,
  });

  final String text;
  final VoidCallback onTap;
  final bool filled;

  @override
  State<_BottomButton> createState() => _BottomButtonState();
}

class _BottomButtonState extends State<_BottomButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 46,
          alignment: Alignment.center,
          decoration: widget.filled
              ? AppDecorations.neoButton(
                  active: _hover,
                  pressed: _pressed,
                  enabled: true,
                )
              : BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: AppRadius.r14,
                  border: Border.all(color: AppColors.borderBright),
                  boxShadow: [
                    const BoxShadow(
                      color: Color(0x77000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                    if (_hover)
                      const BoxShadow(
                        color: AppColors.accentGlowSoft,
                        blurRadius: 12,
                      ),
                  ],
                ),
          child: MakeChessLocalizedText(
            widget.text,
            style: AppTextStyles.button.copyWith(
              color: AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// Обработчик Esc на web/desktop
class _EscListener extends StatelessWidget {
  const _EscListener({required this.child, required this.onEsc});
  final Widget child;
  final VoidCallback onEsc;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isMobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    if (isMobile) return child;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          onEsc();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

/// ===== PaymentModal: окно оплаты конкретного тарифа =====
class PaymentModal {
  static Future<void> show({
    required BuildContext context,
    required String planTitle,
    required String price,
    required List<String> features,
    required VoidCallback onPay,
    VoidCallback? onTrial,
    VoidCallback? onEnterKey,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            decoration: AppDecorations.panel(bright: true),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MakeChessLocalizedText(
                    'MakeChess',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      letterSpacing: 0.3,
                      shadows: [
                        Shadow(
                          color: AppColors.accentGlow,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PlanTile(
                    title: planTitle,
                    subtitle: price,
                    highlight: true,
                    trialLabel: onTrial != null ? '7 дней бесплатно' : null,
                    onTrialTap: onTrial,
                    onTap: () {},
                    showChevron: false,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: features
                          .map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 1),
                                    child: Icon(
                                      Icons.check_circle,
                                      size: 18,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: MakeChessLocalizedText(
                                      f,
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: AppColors.borderSoft, height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (onEnterKey != null)
                        Expanded(
                          child: _BottomButton(
                            text: 'Ввести ключ',
                            onTap: () {
                              Navigator.pop(ctx);
                              onEnterKey();
                            },
                          ),
                        ),
                      if (onEnterKey != null) const SizedBox(width: 12),
                      Expanded(
                        child: _BottomButton(
                          text: 'Оплатить',
                          onTap: () {
                            Navigator.pop(ctx);
                            onPay();
                          },
                          filled: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const MakeChessLocalizedText(
                      'Отмена',
                      style: TextStyle(color: AppColors.textDim),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
