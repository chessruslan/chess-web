// MAKECHESS_FEATURE_ACCESS_ADMIN_PANEL_V1
import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/temporary_feature_access_service.dart';

class TemporaryFeatureAccessRequestsAdminPanel extends StatefulWidget {
  const TemporaryFeatureAccessRequestsAdminPanel({super.key});

  @override
  State<TemporaryFeatureAccessRequestsAdminPanel> createState() =>
      _TemporaryFeatureAccessRequestsAdminPanelState();
}

class _TemporaryFeatureAccessRequestsAdminPanelState
    extends State<TemporaryFeatureAccessRequestsAdminPanel> {
  Timer? _timer;
  bool _loading = true;
  String? _error;
  List<FeatureAccessRequest> _requests = const <FeatureAccessRequest>[];

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
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final rows =
          await TemporaryFeatureAccessService.instance.listAdminRequests();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _requests = rows;
      });
    } catch (_) {
      if (!mounted || silent) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить запросы доступа.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_clock_outlined),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Платные функции: запросы доступа',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Обновить',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Здесь выдаётся доступ к видеосвязи, дебютному тренажёру '
            'и скачиванию MakeChess.',
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else if (_requests.isEmpty)
            const Text('Новых запросов по платным функциям нет.')
          else
            for (final request in _requests)
              _FeatureRequestCard(
                key: ValueKey<String>(request.id),
                request: request,
                onProcessed: _load,
              ),
        ],
      ),
    );
  }
}

class _FeatureRequestCard extends StatefulWidget {
  const _FeatureRequestCard({
    super.key,
    required this.request,
    required this.onProcessed,
  });

  final FeatureAccessRequest request;
  final Future<void> Function({bool silent}) onProcessed;

  @override
  State<_FeatureRequestCard> createState() => _FeatureRequestCardState();
}

class _FeatureRequestCardState extends State<_FeatureRequestCard> {
  final TextEditingController _customController = TextEditingController();

  bool _working = false;
  String? _error;
  int _validDays = 7;

  bool get _isVideo => widget.request.featureCode == 'video_connections';
  bool get _isDownload => widget.request.featureCode == 'windows_download';

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _grant(int units) async {
    if (_working) return;

    if (units <= 0 || units > 100000) {
      setState(() => _error = 'Введите целое число от 1 до 100000.');
      return;
    }

    setState(() {
      _working = true;
      _error = null;
    });

    try {
      await TemporaryFeatureAccessService.instance.grantAdminRequest(
        requestId: widget.request.id,
        units: units,
        validDays: _isDownload ? 1 : (_isVideo ? _validDays : 0),
      );

      if (!mounted) return;

      String message;
      if (_isDownload) {
        message = 'Скачивание MakeChess разрешено на 24 часа.';
      } else {
        final suffix = _isVideo
            ? (_validDays == 0
                ? ', без ограничения по сроку'
                : ', срок $_validDays дн.')
            : '';
        message =
            '${widget.request.featureTitle}: разрешено ещё $units$suffix.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      await widget.onProcessed(silent: false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = 'Не удалось выдать разрешение.';
      });
    }
  }

  Future<void> _grantCustom() async {
    final value = int.tryParse(_customController.text.trim());
    if (value == null) {
      setState(() => _error = 'Введите положительное целое число.');
      return;
    }
    await _grant(value);
  }

  Future<void> _close() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await TemporaryFeatureAccessService.instance
          .closeAdminRequest(widget.request.id);
      if (!mounted) return;
      await widget.onProcessed(silent: false);
    } catch (_) {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final quickA = _isVideo ? 7 : 10;
    final quickB = 20;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  _isDownload
                      ? Icons.download_outlined
                      : (_isVideo
                          ? Icons.videocam_outlined
                          : Icons.account_tree),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.featureTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Пользователь: ${r.senderName}'),
            if (r.installationId.isNotEmpty)
              SelectableText('Установка: ${r.installationId}'),
            if (!_isDownload)
              Text('Использовано: ${r.usedUnits} из ${r.allowedUnits}'),
            Text(
              'Запрос: ${_formatDateTime(r.updatedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_isVideo) ...[
              const SizedBox(height: 10),
              const Text(
                'Срок видеодоступа:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _dayChoice(0, 'Без срока'),
                  _dayChoice(1, '1 день'),
                  _dayChoice(7, '7 дней'),
                  _dayChoice(30, '30 дней'),
                  _dayChoice(90, '90 дней'),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (_isDownload)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _working ? null : () => _grant(1),
                    icon: const Icon(Icons.download_done_outlined),
                    label: const Text('Разрешить скачивание'),
                  ),
                  TextButton(
                    onPressed: _working ? null : _close,
                    child: const Text('Отклонить'),
                  ),
                  if (_working)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton(
                    onPressed: _working ? null : () => _grant(quickA),
                    child: Text('+$quickA'),
                  ),
                  FilledButton(
                    onPressed: _working ? null : () => _grant(quickB),
                    child: Text('+$quickB'),
                  ),
                  SizedBox(
                    width: 190,
                    child: TextField(
                      controller: _customController,
                      enabled: !_working,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _isVideo
                            ? 'Своё число соединений'
                            : 'Своё число открытий',
                        errorText: _error,
                        isDense: true,
                        border: const OutlineInputBorder(),
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
                    onPressed: _working ? null : _close,
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

  Widget _dayChoice(int value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _validDays == value,
      onSelected: _working
          ? null
          : (_) {
              setState(() => _validDays = value);
            },
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
