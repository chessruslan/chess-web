// MAKECHESS_AUTO_APPROVE_ACCESS_V4
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/temporary_access_request_service.dart';
import '../../services/temporary_feature_access_service.dart';
import '../../services/temporary_round_access_service.dart';

bool get temporaryAdminSessionOpen =>
    TemporaryAccessRequestService.instance.adminSessionOpen;

ValueNotifier<int> get temporaryAccessRequestUnreadCount =>
    TemporaryAccessRequestService.instance.pendingCount;

Future<void> refreshTemporaryAccessRequestCount() =>
    TemporaryAccessRequestService.instance.refreshPendingCount();

Future<bool> temporaryAdminLoginWithPassword(String password) async {
  final ok = await TemporaryAccessRequestService.instance.loginAdmin(password);
  if (ok) {
    TemporaryFeatureAccessService.instance.startAdminPolling();
  }
  return ok;
}

void temporaryAdminLogout() {
  TemporaryFeatureAccessService.instance.stopAdminPolling();
  TemporaryAccessRequestService.instance.logoutAdmin();
}

Future<void> showTemporaryLicenseAdminDialog(
  BuildContext context, {
  String initialInstallationId = '',
  int initialTournaments = 10,
}) async {
  if (!temporaryAdminSessionOpen) {
    final allowed = await _requestTemporaryAdminLogin(context);
    if (!allowed || !context.mounted) return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TemporaryLicenseAdminDialog(
      initialInstallationId: initialInstallationId,
      initialTournaments: initialTournaments,
    ),
  );
}

Future<bool> _requestTemporaryAdminLogin(BuildContext context) async {
  final controller = TextEditingController();
  String? errorText;
  bool checking = false;

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocalState) {
        Future<void> submit() async {
          if (checking) return;

          setLocalState(() {
            checking = true;
            errorText = null;
          });

          final ok = await temporaryAdminLoginWithPassword(controller.text);
          if (!dialogContext.mounted) return;

          if (ok) {
            Navigator.of(dialogContext).pop(true);
            return;
          }

          setLocalState(() {
            checking = false;
            errorText = 'Неверный пароль администратора.';
          });
        }

        return AlertDialog(
          title: const Text('Вход администратора'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Пароль администратора',
                errorText: errorText,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => submit(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: checking
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: checking ? null : submit,
              child: checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Войти'),
            ),
          ],
        );
      },
    ),
  );

  controller.dispose();
  return result == true;
}

class _TemporaryLicenseAdminDialog extends StatefulWidget {
  const _TemporaryLicenseAdminDialog({
    required this.initialInstallationId,
    required this.initialTournaments,
  });

  final String initialInstallationId;
  final int initialTournaments;

  @override
  State<_TemporaryLicenseAdminDialog> createState() =>
      _TemporaryLicenseAdminDialogState();
}

class _TemporaryLicenseAdminDialogState
    extends State<_TemporaryLicenseAdminDialog> {
  late final TextEditingController _installationController;
  late final TextEditingController _tournamentsController;

  String _generatedKey = '';
  String? _errorText;

  @override
  void initState() {
    super.initState();

    _installationController = TextEditingController(
      text: widget.initialInstallationId,
    );

    _tournamentsController = TextEditingController(
      text: '${widget.initialTournaments}',
    );
  }

  @override
  void dispose() {
    _installationController.dispose();
    _tournamentsController.dispose();
    super.dispose();
  }

  void _generate() {
    final installationId = _installationController.text.trim().toUpperCase();
    final tournaments = int.tryParse(_tournamentsController.text.trim());

    if (installationId.isEmpty) {
      setState(() => _errorText = 'Введите номер установки.');
      return;
    }

    if (tournaments == null || tournaments < 1 || tournaments > 5000) {
      setState(
        () => _errorText = 'Количество турниров должно быть от 1 до 5000.',
      );
      return;
    }

    try {
      final key = TemporaryTournamentAccessService.generateExtensionKey(
        installationId: installationId,
        grantTournaments: tournaments,
      );

      setState(() {
        _generatedKey = key;
        _errorText = null;
      });
    } catch (error) {
      setState(() => _errorText = '$error');
    }
  }

  Future<void> _copyKey() async {
    if (_generatedKey.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: _generatedKey));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ключ скопирован.')),
    );
  }

  Future<void> _changeAdminPassword() async {
    final curatorController = TextEditingController();
    final newPasswordController = TextEditingController();
    final repeatController = TextEditingController();

    String? errorText;
    bool saving = false;

    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          Future<void> save() async {
            if (saving) return;

            final password = newPasswordController.text;

            if (password.trim().length < 6) {
              setLocalState(
                () => errorText =
                    'Новый пароль должен быть не короче 6 символов.',
              );
              return;
            }

            if (password != repeatController.text) {
              setLocalState(() => errorText = 'Пароли не совпадают.');
              return;
            }

            setLocalState(() {
              saving = true;
              errorText = null;
            });

            try {
              await TemporaryAccessRequestService.instance.changeAdminPassword(
                curatorPassword: curatorController.text,
                newPassword: password,
              );

              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            } catch (_) {
              if (!dialogContext.mounted) return;

              setLocalState(() {
                saving = false;
                errorText = 'Неверный пароль куратора.';
              });
            }
          }

          return AlertDialog(
            title: const Text('Смена пароля администратора'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: curatorController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Пароль куратора',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Новый пароль администратора',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: repeatController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Повторите новый пароль',
                      errorText: errorText,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: saving ? null : save,
                child: const Text('Сохранить пароль'),
              ),
            ],
          );
        },
      ),
    );

    curatorController.dispose();
    newPasswordController.dispose();
    repeatController.dispose();

    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль администратора изменён.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ручной ключ доступа'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Этот раздел остаётся как резервный способ. '
                'Обычные запросы теперь разрешаются прямо в «Сообщениях».',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _installationController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Номер установки',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _tournamentsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Разрешить ещё турниров',
                  errorText: _errorText,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.vpn_key),
                label: const Text('Создать ручной ключ'),
              ),
              if (_generatedKey.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'Ключ доступа:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  _generatedKey,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _copyKey,
                  icon: const Icon(Icons.copy),
                  label: const Text('Скопировать ключ'),
                ),
              ],
              const SizedBox(height: 18),
              const Divider(),
              OutlinedButton.icon(
                onPressed: _changeAdminPassword,
                icon: const Icon(Icons.password),
                label: const Text('Сменить пароль администратора'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}

class TemporaryAccessRequestsAdminPanel extends StatefulWidget {
  const TemporaryAccessRequestsAdminPanel({super.key});

  @override
  State<TemporaryAccessRequestsAdminPanel> createState() =>
      _TemporaryAccessRequestsAdminPanelState();
}

class _TemporaryAccessRequestsAdminPanelState
    extends State<TemporaryAccessRequestsAdminPanel> {
  bool _loading = true;
  String? _error;
  List<TemporaryAccessRequest> _requests = const <TemporaryAccessRequest>[];
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _load();

    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!temporaryAdminSessionOpen) {
      if (mounted) {
        setState(() {
          _loading = false;
          _requests = const <TemporaryAccessRequest>[];
        });
      }
      return;
    }

    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final requests =
          await TemporaryAccessRequestService.instance.listAdminRequests();

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = null;
        _requests = requests;
      });
    } catch (_) {
      if (!mounted || silent) return;

      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить запросы из приложения.';
      });
    }
  }

  Future<void> _requestProcessed() async {
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.mark_email_unread_outlined),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Запросы на продолжение работы',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable:
                    TemporaryAccessRequestService.instance.pendingCount,
                builder: (_, count, __) => count <= 0
                    ? const SizedBox.shrink()
                    : Container(
                        margin: const EdgeInsets.only(right: 8),
                        constraints: const BoxConstraints(minWidth: 24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
              IconButton(
                tooltip: 'Обновить',
                onPressed: () => _load(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Разрешение выдаётся прямо здесь. Пользователь ничего '
            'не копирует и не вводит вручную.',
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            )
          else if (_requests.isEmpty)
            const Text('Новых запросов нет.')
          else
            for (final request in _requests)
              _AccessRequestCard(
                key: ValueKey<String>(request.id),
                request: request,
                onProcessed: _requestProcessed,
              ),
        ],
      ),
    );
  }
}

class _AccessRequestCard extends StatefulWidget {
  const _AccessRequestCard({
    super.key,
    required this.request,
    required this.onProcessed,
  });

  final TemporaryAccessRequest request;
  final Future<void> Function() onProcessed;

  @override
  State<_AccessRequestCard> createState() => _AccessRequestCardState();
}

class _AccessRequestCardState extends State<_AccessRequestCard> {
  final TextEditingController _customController = TextEditingController();

  bool _working = false;
  String? _fieldError;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _grant(int amount) async {
    if (_working) return;

    if (amount <= 0 || amount > 100000) {
      setState(() {
        _fieldError = 'Введите целое число от 1 до 100000.';
      });
      return;
    }

    setState(() {
      _working = true;
      _fieldError = null;
    });

    try {
      await TemporaryAccessRequestService.instance.grantAdminRequest(
        requestId: widget.request.id,
        grantTournaments: amount,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Разрешено ещё $amount турниров для '
            '${widget.request.installationId}.',
          ),
        ),
      );

      await widget.onProcessed();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _working = false;
        _fieldError = 'Не удалось выдать разрешение. Попробуйте ещё раз.';
      });
    }
  }

  Future<void> _grantCustom() async {
    final amount = int.tryParse(_customController.text.trim());

    if (amount == null) {
      setState(() {
        _fieldError = 'Введите положительное целое число.';
      });
      return;
    }

    await _grant(amount);
  }

  Future<void> _closeWithoutGrant() async {
    if (_working) return;

    setState(() => _working = true);

    try {
      await TemporaryAccessRequestService.instance
          .closeAdminRequest(widget.request.id);

      if (!mounted) return;

      await widget.onProcessed();
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              request.senderName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            SelectableText('Установка: ${request.installationId}'),
            Text(
              'Создано турниров: ${request.usedTournaments} из '
              '${request.allowedTournaments}',
            ),
            Text(
              'Запрос: ${_formatDateTime(request.updatedAt)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Разрешить продолжение:',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton(
                  onPressed: _working ? null : () => _grant(10),
                  child: const Text('+10 турниров'),
                ),
                FilledButton(
                  onPressed: _working ? null : () => _grant(20),
                  child: const Text('+20 турниров'),
                ),
                SizedBox(
                  width: 170,
                  child: TextField(
                    controller: _customController,
                    enabled: !_working,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Своё количество',
                      hintText: 'Например 35',
                      errorText: _fieldError,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _grantCustom(),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _working ? null : _grantCustom,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Разрешить'),
                ),
                TextButton(
                  onPressed: _working ? null : _closeWithoutGrant,
                  child: const Text('Закрыть без разрешения'),
                ),
                if (_working)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
