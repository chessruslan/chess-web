import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../app_style.dart';
import '../start_modal.dart';

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
    if (!kIsWeb) {
      final label = (nickname ?? '').trim().isEmpty ? 'Имя' : nickname!.trim();
      return FilledButton.tonalIcon(
        style: AppButtons.primary(active: true),
        onPressed: onTap,
        icon: const Icon(Icons.person),
        label: Text(label),
      );
    }

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
            child: const Text('Тарифы'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            style: AppButtons.primary(active: true),
            onPressed: onTap,
            child: const Text('Вход'),
          ),
        ],
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Аккаунт',
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
          child: Text(nickname ?? 'player'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'pricing',
          child: Text('Тарифы'),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Text('Выйти'),
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
        label: Text(
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
    if (!kIsWeb) {
      return ConstrainedBox(
        constraints: const BoxConstraints.tightFor(width: 380),
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
                      child: Text(
                        'Ваше имя в MakeChess',
                        style: AppTextStyles.sectionTitle,
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close, color: AppColors.text),
                      tooltip: 'Закрыть',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Пароль не нужен. Имя сохраняется на этом компьютере. '
                  'Если есть интернет, MakeChess проверит похожие имена на сайте.',
                  style: TextStyle(color: AppColors.textDim, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: widget.nickCtl,
                  autofocus: true,
                  style: const TextStyle(color: AppColors.text),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => widget.onSubmit(),
                  decoration: AppInputs.dark(labelText: 'Имя пользователя'),
                ),
                const SizedBox(height: 10),
                if (widget.authError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      widget.authError!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                FilledButton.icon(
                  style: AppButtons.primary(active: true),
                  onPressed: widget.onSubmit,
                  icon: const Icon(Icons.check),
                  label: const Text('Использовать это имя'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                    child: Text(
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
                    tooltip: 'Закрыть',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: widget.nickCtl,
                style: const TextStyle(color: AppColors.text),
                decoration: AppInputs.dark(
                  labelText: 'Ник (a-z, 0-9, _)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: widget.passCtl,
                style: const TextStyle(color: AppColors.text),
                obscureText: !_passwordVisible,
                decoration: AppInputs.dark(
                  labelText: 'Пароль (≥ 6 символов)',
                ).copyWith(
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _passwordVisible = !_passwordVisible;
                      });
                    },
                    tooltip: _passwordVisible
                        ? 'Скрыть пароль'
                        : 'Показать пароль',
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
                  child: Text(
                    widget.authError!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              FilledButton(
                style: AppButtons.primary(active: true),
                onPressed: widget.onSubmit,
                child: Text(
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
                child: Text(
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
