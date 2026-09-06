// MAKECHESS_AUTO_APPROVE_ACCESS_V4
import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/temporary_access_request_service.dart';
import '../../services/temporary_round_access_service.dart';

Future<bool> ensureTemporaryTournamentAccess(BuildContext context) async {
  final limiter = TemporaryTournamentAccessService.instance;
  final requests = TemporaryAccessRequestService.instance;

  // If the administrator already approved this installation, apply the
  // server grant before checking the local limiter.
  try {
    await requests.claimAndApplyAvailableGrants();
  } catch (_) {
    // Offline mode remains valid. The local limiter still works.
  }

  if (await limiter.tryConsumeTournament()) {
    final state = await limiter.snapshot();

    if (context.mounted && state.remainingTournaments <= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Осталось создать турниров: ${state.remainingTournaments}.',
          ),
        ),
      );
    }
    return true;
  }

  if (!context.mounted) return false;

  final state = await limiter.snapshot();

  final granted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TemporaryTournamentAccessDialog(
      limiter: limiter,
      installationId: state.installationId,
      usedTournaments: state.usedTournaments,
      totalAllowance: state.totalAllowance,
    ),
  );

  return granted == true;
}

class _TemporaryTournamentAccessDialog extends StatefulWidget {
  const _TemporaryTournamentAccessDialog({
    required this.limiter,
    required this.installationId,
    required this.usedTournaments,
    required this.totalAllowance,
  });

  final TemporaryTournamentAccessService limiter;
  final String installationId;
  final int usedTournaments;
  final int totalAllowance;

  @override
  State<_TemporaryTournamentAccessDialog> createState() =>
      _TemporaryTournamentAccessDialogState();
}

class _TemporaryTournamentAccessDialogState
    extends State<_TemporaryTournamentAccessDialog> {
  final TextEditingController _keyController = TextEditingController();

  Timer? _grantPollTimer;
  bool _checkingGrant = false;
  bool _sendingRequest = false;
  bool _requestSent = false;
  bool _applyingKey = false;
  String? _requestMessage;
  String? _keyErrorText;

  @override
  void initState() {
    super.initState();

    _grantPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_checkAutomaticGrant()),
    );

    unawaited(_checkAutomaticGrant());
  }

  @override
  void dispose() {
    _grantPollTimer?.cancel();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _checkAutomaticGrant() async {
    if (_checkingGrant) return;
    _checkingGrant = true;

    try {
      final granted = await TemporaryAccessRequestService.instance
          .claimAndApplyAvailableGrants();

      if (granted <= 0 || !mounted) return;

      final consumed = await widget.limiter.tryConsumeTournament();
      if (!mounted) return;

      if (consumed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Администратор разрешил ещё $granted турниров. '
              'Можно продолжать.',
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      // No internet: keep the dialog open and retry automatically.
    } finally {
      _checkingGrant = false;
    }
  }

  Future<void> _sendRequest() async {
    if (_sendingRequest || _requestSent) return;

    setState(() {
      _sendingRequest = true;
      _requestMessage = null;
    });

    try {
      await TemporaryAccessRequestService.instance.submitRequest(
        installationId: widget.installationId,
        usedTournaments: widget.usedTournaments,
        allowedTournaments: widget.totalAllowance,
      );

      if (!mounted) return;

      setState(() {
        _sendingRequest = false;
        _requestSent = true;
        _requestMessage = 'Запрос отправлен. Окно можно оставить открытым — '
            'разрешение применится автоматически.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _sendingRequest = false;
        _requestMessage = 'Не удалось отправить запрос. Проверьте интернет '
            'и попробуйте ещё раз.';
      });
    }
  }

  Future<void> _applyKey() async {
    if (_applyingKey) return;

    setState(() {
      _applyingKey = true;
      _keyErrorText = null;
    });

    final result =
        await widget.limiter.applyExtensionKey(_keyController.text.trim());

    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _applyingKey = false;
        _keyErrorText = result.message;
      });
      return;
    }

    final consumed = await widget.limiter.tryConsumeTournament();

    if (!mounted) return;

    if (!consumed) {
      setState(() {
        _applyingKey = false;
        _keyErrorText = 'Ключ принят, но продолжение не удалось разрешить.';
      });
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Лимит создания турниров исчерпан'),
      content: SizedBox(
        width: 580,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Отправьте запрос администратору MakeChess. '
              'После разрешения работа продолжится автоматически.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Номер установки:',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            SelectableText(
              widget.installationId,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Создано турниров: ${widget.usedTournaments} из '
              '${widget.totalAllowance}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_requestMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _requestMessage!,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _requestSent
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 18),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Есть ручной ключ?'),
              children: [
                TextField(
                  controller: _keyController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Ключ доступа',
                    errorText: _keyErrorText,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _applyKey(),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _applyingKey ? null : _applyKey,
                    icon: const Icon(Icons.vpn_key_outlined),
                    label: const Text('Применить ключ'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        FilledButton.icon(
          onPressed: _sendingRequest || _requestSent ? null : _sendRequest,
          icon: _sendingRequest
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _requestSent
                      ? Icons.check_circle_outline
                      : Icons.send_outlined,
                ),
          label: Text(
            _requestSent ? 'Запрос отправлен' : 'Отправить запрос',
          ),
        ),
        TextButton(
          onPressed:
              _sendingRequest ? null : () => Navigator.of(context).pop(false),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}
