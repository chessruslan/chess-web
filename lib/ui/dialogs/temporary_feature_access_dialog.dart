// MAKECHESS_FEATURE_ACCESS_DIALOG_V1
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/temporary_feature_access_service.dart';

Future<bool> ensureOpeningChooserAccess(BuildContext context) async {
  if (kIsWeb) return true;

  if (await TemporaryFeatureAccessService.instance.tryConsumeOpeningChooser()) {
    return true;
  }

  if (!context.mounted) return false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _FeatureLimitDialog(
      feature: MakeChessFeatureAccess.openingChooser,
    ),
  );
  return result == true;
}

Future<bool> ensureVideoConnectionAccess(BuildContext context) async {
  try {
    final status = await TemporaryFeatureAccessService.instance.videoStatus();
    if (status.accessAllowed) return true;
  } catch (_) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Не удалось проверить доступ к видеосвязи. Проверьте интернет.',
        ),
      ),
    );
    return false;
  }

  if (!context.mounted) return false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _FeatureLimitDialog(
      feature: MakeChessFeatureAccess.videoConnections,
    ),
  );
  return result == true;
}

class _FeatureLimitDialog extends StatefulWidget {
  const _FeatureLimitDialog({required this.feature});

  final MakeChessFeatureAccess feature;

  @override
  State<_FeatureLimitDialog> createState() => _FeatureLimitDialogState();
}

class _FeatureLimitDialogState extends State<_FeatureLimitDialog> {
  Timer? _pollTimer;
  bool _sending = false;
  bool _sent = false;
  bool _checking = false;
  String? _message;

  OpeningAccessSnapshot? _opening;
  VideoAccessStatus? _video;

  @override
  void initState() {
    super.initState();
    unawaited(_loadState());
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_checkGrant()),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    try {
      if (widget.feature == MakeChessFeatureAccess.openingChooser) {
        final value = await TemporaryFeatureAccessService.instance
            .openingSnapshot(claimOnlineGrants: false);
        if (mounted) setState(() => _opening = value);
      } else {
        final value =
            await TemporaryFeatureAccessService.instance.videoStatus();
        if (mounted) setState(() => _video = value);
      }
    } catch (_) {}
  }

  Future<void> _checkGrant() async {
    if (_checking) return;
    _checking = true;
    try {
      if (widget.feature == MakeChessFeatureAccess.openingChooser) {
        final allowed = await TemporaryFeatureAccessService.instance
            .tryConsumeOpeningChooser();
        if (allowed && mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        final status =
            await TemporaryFeatureAccessService.instance.videoStatus();
        if (!mounted) return;
        setState(() => _video = status);
        if (status.accessAllowed) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (_) {
      // Keep waiting. Offline is possible for the opening trainer.
    } finally {
      _checking = false;
    }
  }

  Future<void> _sendRequest() async {
    if (_sending || _sent) return;

    setState(() {
      _sending = true;
      _message = null;
    });

    try {
      if (widget.feature == MakeChessFeatureAccess.openingChooser) {
        await TemporaryFeatureAccessService.instance.submitOpeningRequest();
      } else {
        await TemporaryFeatureAccessService.instance.submitVideoRequest();
      }

      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
        _message =
            'Запрос отправлен администратору. Разрешение применится автоматически.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _message =
            'Не удалось отправить запрос. Проверьте интернет и попробуйте ещё раз.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOpening = widget.feature == MakeChessFeatureAccess.openingChooser;

    final title = isOpening
        ? 'Лимит дебютного тренажёра исчерпан'
        : 'Видеосвязь временно недоступна';

    String details;
    if (isOpening) {
      final s = _opening;
      details = s == null
          ? 'Разрешено 20 открытий окна выбора дебюта.'
          : 'Использовано: ${s.used} из ${s.allowed}.';
    } else {
      final s = _video;
      if (s == null) {
        details = 'Доступ проверяется...';
      } else {
        final expiry = s.validUntil == null
            ? 'без ограничения по сроку'
            : 'до ${_formatDate(s.validUntil!.toLocal())}';
        details = 'Использовано соединений: ${s.used} из ${s.allowed}. '
            'Осталось: ${s.remaining}. Срок: $expiry.';
      }
    }

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isOpening
                  ? 'Для продолжения отправьте запрос администратору MakeChess.'
                  : 'Администратор может разрешить выбранное количество '
                      'видеосоединений и срок использования.',
            ),
            const SizedBox(height: 14),
            Text(
              details,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _sent
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton.icon(
          onPressed: _sending || _sent ? null : _sendRequest,
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: Text(_sent ? 'Запрос отправлен' : 'Отправить запрос'),
        ),
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }

  String _formatDate(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}
