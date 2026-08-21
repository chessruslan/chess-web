// MAKECHESS_REMAINING_UI_V6_20260807
// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/teacher_account_store.dart';

import '../../localization/makechess_localization.dart';

Future<bool> showTeacherAccessDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _TeacherAccessDialog(),
      ) ??
      false;
}

class _TeacherAccessDialog extends StatefulWidget {
  const _TeacherAccessDialog();

  @override
  State<_TeacherAccessDialog> createState() => _TeacherAccessDialogState();
}

class _TeacherAccessDialogState extends State<_TeacherAccessDialog> {
  final _school = TextEditingController();
  final _about = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();
  TeacherAccount? _current;
  bool _register = false;
  bool _busy = true;
  bool _hidePassword = true;
  String _tariff = 'trial';
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final current = await TeacherAccountStore.instance.current();
    if (!mounted) return;
    setState(() {
      _current = current;
      _busy = false;
      if (current != null) _login.text = current.login;
    });
  }

  @override
  void dispose() {
    _school.dispose();
    _about.dispose();
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<TeacherAccount> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final account = await action();
      if (!mounted) return;
      setState(() => _current = account);
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$error'.replaceFirst('Bad state: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF17222E),
      title: Row(
        children: [
          const Icon(Icons.school_outlined, color: Colors.cyanAccent),
          const SizedBox(width: 10),
          const Expanded(child: MakeChessLocalizedText('Вход учителя')),
          IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: _busy
            ? const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            : _current != null
                ? _currentSession()
                : _accessForm(),
      ),
    );
  }

  Widget _currentSession() {
    final account = _current!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.school)),
          title: MakeChessLocalizedText(account.schoolName),
          subtitle: MakeChessLocalizedText(account.temporary
              ? 'Временный вход для разработки'
              : 'Логин: ${account.login} • ${_tariffTitle(account.tariff)}'),
        ),
        if (account.about.isNotEmpty) MakeChessLocalizedText(account.about),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () async {
                await TeacherAccountStore.instance.signOut();
                if (mounted) setState(() => _current = null);
              },
              icon: const Icon(Icons.logout),
              label: const MakeChessLocalizedText('Выйти'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.login),
              label: const MakeChessLocalizedText('Продолжить как учитель'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _accessForm() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                  value: false, label: MakeChessLocalizedText('Вход')),
              ButtonSegment(
                  value: true, label: MakeChessLocalizedText('Регистрация')),
            ],
            selected: <bool>{_register},
            onSelectionChanged: (value) => setState(() {
              _register = value.first;
              _error = null;
            }),
          ),
          const SizedBox(height: 16),
          if (_register) ...[
            _field(_school, 'Название школы или имя учителя', Icons.school),
            const SizedBox(height: 10),
            _field(_about, 'О себе / дополнительная информация', Icons.notes,
                maxLines: 3),
            const SizedBox(height: 10),
          ],
          _field(_login, 'Логин', Icons.person_outline),
          const SizedBox(height: 10),
          TextField(
            controller: _password,
            obscureText: _hidePassword,
            decoration: InputDecoration(
              labelText: MakeChessLocalization.phrase('Пароль'),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
                icon: Icon(
                    _hidePassword ? Icons.visibility : Icons.visibility_off),
              ),
            ),
          ),
          if (_register) ...[
            const SizedBox(height: 14),
            const MakeChessLocalizedText('Тариф после бесплатных 7 дней',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _tariff,
              items: const [
                DropdownMenuItem(
                    value: 'trial',
                    child: MakeChessLocalizedText('7 дней бесплатно')),
                DropdownMenuItem(
                    value: 'economy',
                    child: MakeChessLocalizedText('Эконом — базовые занятия')),
                DropdownMenuItem(
                    value: 'premium',
                    child: MakeChessLocalizedText(
                        'Премиум — турниры и видеосвязь')),
                DropdownMenuItem(
                    value: 'pro',
                    child: MakeChessLocalizedText(
                        'PRO Расширенный — все возможности')),
              ],
              onChanged: (value) => setState(() => _tariff = value ?? 'trial'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            MakeChessLocalizedText(_error!,
                style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    _run(TeacherAccountStore.instance.temporarySignIn),
                icon: const Icon(Icons.timer_outlined),
                label:
                    const MakeChessLocalizedText('Временный вход без пароля'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => _run(
                  _register
                      ? () => TeacherAccountStore.instance.register(
                            schoolName: _school.text,
                            about: _about.text,
                            login: _login.text,
                            password: _password.text,
                            tariff: _tariff,
                            ownerUserId:
                                Supabase.instance.client.auth.currentUser?.id ??
                                    '',
                          )
                      : () => TeacherAccountStore.instance
                          .signIn(_login.text, _password.text),
                ),
                child: MakeChessLocalizedText(
                    _register ? 'Зарегистрироваться' : 'Войти'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: MakeChessLocalization.phrase(label),
        prefixIcon: Icon(icon),
      ),
    );
  }

  String _tariffTitle(String value) => switch (value) {
        'economy' => 'Эконом',
        'premium' => 'Премиум',
        'pro' => 'PRO Расширенный',
        _ => '7 дней бесплатно',
      };
}
