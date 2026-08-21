// MAKECHESS_REMAINING_UI_V6_20260807
// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
import 'package:flutter/material.dart';

import '../app_style.dart';
import '../start_modal.dart';

import '../../localization/makechess_localization.dart';

class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.nickname,
    required this.isLoggedIn,
    required this.onTap,
    required this.onLogout,
  });

  final String? nickname;
  final bool isLoggedIn;
  final VoidCallback onTap;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            style: AppButtons.primary(),
            onPressed: () {
              StartModal.show(
                context: context,
                onFree: () {},
                onPro: () {},
                onPremium: () {},
                onLogin: onTap,
                onRegister: onTap,
              );
            },
            child: const MakeChessLocalizedText('Тарифы'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            style: AppButtons.primary(active: true),
            onPressed: onTap,
            child: const MakeChessLocalizedText('Вход'),
          ),
        ],
      );
    }

    return PopupMenuButton<String>(
      tooltip: MakeChessLocalization.phrase('Аккаунт'),
      onSelected: (v) async {
        if (v == 'pricing') {
          final rootNav = Navigator.of(context, rootNavigator: true);
          StartModal.show(
            context: context,
            onFree: () => rootNav.pop(),
            onPro: () => rootNav.pop(),
            onPremium: () => rootNav.pop(),
            onLogin: () => rootNav.pop(),
            onRegister: () => rootNav.pop(),
          );
          return;
        }
        if (v == 'logout') await onLogout();
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          value: 'nick',
          enabled: false,
          child: MakeChessLocalizedText(nickname ?? 'player'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'pricing',
          child: MakeChessLocalizedText('Тарифы'),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: MakeChessLocalizedText('Выйти'),
        ),
      ],
      child: Chip(
        backgroundColor: AppColors.surfaceCard,
        side: const BorderSide(color: AppColors.border),
        avatar: const Icon(
          Icons.person,
          size: 18,
          color: AppColors.text,
        ),
        label: MakeChessLocalizedText(
          nickname ?? 'Аккаунт',
          style: const TextStyle(color: AppColors.text),
        ),
      ),
    );
  }
}

class AuthPanel extends StatefulWidget {
  const AuthPanel({
    super.key,
    required this.isLogin,
    required this.passCtl,
    required this.nickCtl,
    required this.authError,
    required this.onClose,
    required this.onToggleMode,
    required this.onSubmit,
  });

  final bool isLogin;
  final TextEditingController passCtl;
  final TextEditingController nickCtl;
  final String? authError;
  final VoidCallback onClose;
  final VoidCallback onToggleMode;
  final Future<void> Function() onSubmit;

  @override
  State<AuthPanel> createState() => _AuthPanelState();
}

class _AuthPanelState extends State<AuthPanel> {
  bool _passwordVisible = false;

  @override
  Widget build(BuildContext context) {
    final card = ConstrainedBox(
      constraints: const BoxConstraints.tightFor(width: 360),
      child: Material(
        elevation: 8,
        borderRadius: AppRadius.r16,
        color: AppColors.surface,
        child: Container(
          decoration: AppDecorations.panel(bright: true),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: MakeChessLocalizedText(
                      'Вход / Регистрация',
                      style: AppTextStyles.sectionTitle,
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.text,
                    ),
                    tooltip: MakeChessLocalization.phrase('Закрыть'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: widget.nickCtl,
                style: const TextStyle(color: AppColors.text),
                decoration: AppInputs.dark(
                  labelText: MakeChessLocalization.phrase('Ник (a-z, 0-9, _)'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: widget.passCtl,
                style: const TextStyle(color: AppColors.text),
                obscureText: !_passwordVisible,
                decoration: AppInputs.dark(
                  labelText:
                      MakeChessLocalization.phrase('Пароль (≥ 6 символов)'),
                ).copyWith(
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _passwordVisible = !_passwordVisible;
                      });
                    },
                    tooltip: MakeChessLocalization.phrase(
                      _passwordVisible ? 'Скрыть пароль' : 'Показать пароль',
                    ),
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppColors.textDim,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (widget.authError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MakeChessLocalizedText(
                    widget.authError!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              FilledButton(
                style: AppButtons.primary(active: true),
                onPressed: widget.onSubmit,
                child: MakeChessLocalizedText(
                  widget.isLogin ? 'Войти' : 'Зарегистрироваться',
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textDim,
                  disabledForegroundColor: AppColors.textMuted,
                ),
                onPressed: widget.onToggleMode,
                child: MakeChessLocalizedText(
                  widget.isLogin
                      ? 'Нет аккаунта? Зарегистрироваться'
                      : 'Уже есть аккаунт? Войти',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return card;
  }
}
