// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
import 'package:flutter/material.dart';

import '../../localization/makechess_localization.dart';

enum TournamentPairingMode { automatic, semiAutomatic, manual }

enum TournamentColorOrder {
  alternateEveryGame,
  reverseEveryCycle,
  automaticBalance,
}

extension TournamentColorOrderLabel on TournamentColorOrder {
  String get label => switch (this) {
        TournamentColorOrder.alternateEveryGame =>
          'Менять цвет после каждой партии',
        TournamentColorOrder.reverseEveryCycle =>
          'Менять цвет после полного круга',
        TournamentColorOrder.automaticBalance =>
          'Автоматически балансировать цвета',
      };
}

extension TournamentPairingModeLabel on TournamentPairingMode {
  String get label => switch (this) {
        TournamentPairingMode.automatic => 'Автоматический',
        TournamentPairingMode.semiAutomatic => 'Полуавтоматический',
        TournamentPairingMode.manual => 'Ручной',
      };

  String get description => switch (this) {
        TournamentPairingMode.automatic =>
          'Система сама формирует пары, начинает и завершает туры.',
        TournamentPairingMode.semiAutomatic =>
          'Пары рассчитывает система, начало и окончание тура подтверждает организатор.',
        TournamentPairingMode.manual =>
          'Все действия выполняет организатор. Автоматическую жеребьёвку можно вызвать отдельно.',
      };
}

class TournamentPairingSettings {
  const TournamentPairingSettings({
    this.mode = TournamentPairingMode.automatic,
    this.useRating = true,
    this.avoidRematches = true,
    this.balanceColors = true,
    this.autoFinishRound = true,
    this.autoStartNextRound = true,
    this.nextRoundDelaySeconds = 30,
    this.allowManualCorrections = true,
    this.cycles = 1,
    this.gamesPerOpponent = 2,
    this.colorOrder = TournamentColorOrder.alternateEveryGame,
  });

  final TournamentPairingMode mode;
  final bool useRating;
  final bool avoidRematches;
  final bool balanceColors;
  final bool autoFinishRound;
  final bool autoStartNextRound;
  final int nextRoundDelaySeconds;
  final bool allowManualCorrections;
  final int cycles;
  final int gamesPerOpponent;
  final TournamentColorOrder colorOrder;

  TournamentPairingSettings copyWith({
    TournamentPairingMode? mode,
    bool? useRating,
    bool? avoidRematches,
    bool? balanceColors,
    bool? autoFinishRound,
    bool? autoStartNextRound,
    int? nextRoundDelaySeconds,
    bool? allowManualCorrections,
    int? cycles,
    int? gamesPerOpponent,
    TournamentColorOrder? colorOrder,
  }) {
    return TournamentPairingSettings(
      mode: mode ?? this.mode,
      useRating: useRating ?? this.useRating,
      avoidRematches: avoidRematches ?? this.avoidRematches,
      balanceColors: balanceColors ?? this.balanceColors,
      autoFinishRound: autoFinishRound ?? this.autoFinishRound,
      autoStartNextRound: autoStartNextRound ?? this.autoStartNextRound,
      nextRoundDelaySeconds:
          nextRoundDelaySeconds ?? this.nextRoundDelaySeconds,
      allowManualCorrections:
          allowManualCorrections ?? this.allowManualCorrections,
      cycles: cycles ?? this.cycles,
      gamesPerOpponent: gamesPerOpponent ?? this.gamesPerOpponent,
      colorOrder: colorOrder ?? this.colorOrder,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mode': mode.name,
        'useRating': useRating,
        'avoidRematches': avoidRematches,
        'balanceColors': balanceColors,
        'autoFinishRound': autoFinishRound,
        'autoStartNextRound': autoStartNextRound,
        'nextRoundDelaySeconds': nextRoundDelaySeconds,
        'allowManualCorrections': allowManualCorrections,
        'cycles': cycles,
        'gamesPerOpponent': gamesPerOpponent,
        'colorOrder': colorOrder.name,
      };

  factory TournamentPairingSettings.fromJson(Map<String, dynamic> json) {
    final rawMode = '${json['mode'] ?? ''}';
    final mode = TournamentPairingMode.values.firstWhere(
      (value) => value.name == rawMode,
      orElse: () => TournamentPairingMode.automatic,
    );
    final rawColorOrder = '${json['colorOrder'] ?? ''}';
    final colorOrder = TournamentColorOrder.values.firstWhere(
      (value) => value.name == rawColorOrder,
      orElse: () => TournamentColorOrder.alternateEveryGame,
    );
    return TournamentPairingSettings(
      mode: mode,
      useRating: json['useRating'] != false,
      avoidRematches: json['avoidRematches'] != false,
      balanceColors: json['balanceColors'] != false,
      autoFinishRound: json['autoFinishRound'] != false,
      autoStartNextRound: json['autoStartNextRound'] != false,
      nextRoundDelaySeconds:
          (json['nextRoundDelaySeconds'] as num?)?.toInt() ?? 30,
      allowManualCorrections: json['allowManualCorrections'] != false,
      cycles: ((json['cycles'] as num?)?.toInt() ?? 1).clamp(1, 10),
      gamesPerOpponent:
          ((json['gamesPerOpponent'] as num?)?.toInt() ?? 2).clamp(1, 10),
      colorOrder: colorOrder,
    );
  }
}

enum TournamentPairingAction {
  save,
  generateAutomatically,
  startRound,
  finishRound,
  nextRound,
  editManually,
}

class TournamentPairingControlResult {
  const TournamentPairingControlResult(this.settings, this.action);

  final TournamentPairingSettings settings;
  final TournamentPairingAction action;
}

Future<TournamentPairingControlResult?> showTournamentPairingControlDialog({
  required BuildContext context,
  required TournamentPairingSettings initialSettings,
  required int participantCount,
  required Future<void> Function(
          TournamentPairingSettings, TournamentPairingAction)
      onAction,
  required ValueChanged<TournamentPairingSettings> onSettingsChanged,
}) {
  return showGeneralDialog<TournamentPairingControlResult>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (_, __, ___) => _TournamentPairingControlDialog(
      initialSettings: initialSettings,
      participantCount: participantCount,
      onAction: onAction,
      onSettingsChanged: onSettingsChanged,
    ),
  );
}

class _TournamentPairingControlDialog extends StatefulWidget {
  const _TournamentPairingControlDialog({
    required this.initialSettings,
    required this.participantCount,
    required this.onAction,
    required this.onSettingsChanged,
  });

  final TournamentPairingSettings initialSettings;
  final int participantCount;
  final Future<void> Function(
      TournamentPairingSettings, TournamentPairingAction) onAction;
  final ValueChanged<TournamentPairingSettings> onSettingsChanged;

  @override
  State<_TournamentPairingControlDialog> createState() =>
      _TournamentPairingControlDialogState();
}

class _TournamentPairingControlDialogState
    extends State<_TournamentPairingControlDialog> {
  late TournamentPairingSettings _settings = widget.initialSettings;
  Offset _offset = Offset.zero;
  bool _busy = false;

  void _close(TournamentPairingAction action) {
    Navigator.pop(
      context,
      TournamentPairingControlResult(_settings, action),
    );
  }

  Future<void> _openSettings() async {
    final updated = await showDialog<TournamentPairingSettings>(
      context: context,
      builder: (_) => _TournamentPairingSettingsDialog(settings: _settings),
    );
    if (updated != null) {
      setState(() => _settings = updated);
      widget.onSettingsChanged(updated);
    }
  }

  Future<void> _run(TournamentPairingAction action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onAction(_settings, action);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPair = widget.participantCount >= 2;
    return Transform.translate(
        offset: _offset,
        child: AlertDialog(
          insetPadding: const EdgeInsets.all(18),
          elevation: 24,
          shadowColor: Colors.black,
          backgroundColor: const Color(0xFF101C28),
          titlePadding: EdgeInsets.zero,
          title: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) => setState(() => _offset += details.delta),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(22, 16, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.drag_indicator, color: Colors.white38),
                  SizedBox(width: 8),
                  Icon(Icons.casino, color: Colors.lightBlueAccent),
                  SizedBox(width: 10),
                  Expanded(
                      child: MakeChessLocalizedText('Управление жеребьёвкой')),
                  MakeChessLocalizedText('Перетащите',
                      style: TextStyle(fontSize: 11, color: Colors.white38)),
                ],
              ),
            ),
          ),
          content: SizedBox(
            width: 720,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<TournamentPairingMode>(
                  segments: TournamentPairingMode.values
                      .map((mode) => ButtonSegment<TournamentPairingMode>(
                            value: mode,
                            label: MakeChessLocalizedText(mode.label),
                          ))
                      .toList(growable: false),
                  selected: <TournamentPairingMode>{_settings.mode},
                  onSelectionChanged: (selection) {
                    final updated = _settings.copyWith(mode: selection.first);
                    setState(() => _settings = updated);
                    widget.onSettingsChanged(updated);
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: MakeChessLocalizedText(
                    _settings.mode.description,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ),
                const SizedBox(height: 12),
                MakeChessLocalizedText(
                  'Участников: ${widget.participantCount}',
                  style: TextStyle(
                    color: canPair ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _openSettings,
                      icon: const Icon(Icons.settings),
                      label: const MakeChessLocalizedText('Настройка'),
                    ),
                    if (_settings.mode == TournamentPairingMode.manual)
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(TournamentPairingAction.editManually),
                        icon: const Icon(Icons.edit),
                        label: const MakeChessLocalizedText(
                            'Составить пары вручную'),
                      ),
                    FilledButton.icon(
                      onPressed: canPair && !_busy
                          ? () => _run(
                                TournamentPairingAction.generateAutomatically,
                              )
                          : null,
                      icon: const Icon(Icons.shuffle),
                      label: MakeChessLocalizedText(
                        _settings.mode == TournamentPairingMode.manual
                            ? 'Автоматическая жеребьёвка'
                            : 'Сформировать пары',
                      ),
                    ),
                    if (_settings.mode != TournamentPairingMode.automatic) ...[
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(TournamentPairingAction.startRound),
                        icon: const Icon(Icons.play_arrow),
                        label: const MakeChessLocalizedText('Начать тур'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(TournamentPairingAction.finishRound),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const MakeChessLocalizedText('Завершить тур'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(TournamentPairingAction.nextRound),
                        icon: const Icon(Icons.skip_next),
                        label: const MakeChessLocalizedText('Следующий тур'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const MakeChessLocalizedText('Закрыть'),
            ),
            FilledButton(
              onPressed:
                  _busy ? null : () => _close(TournamentPairingAction.save),
              child: const MakeChessLocalizedText('Сохранить режим'),
            ),
          ],
        ));
  }
}

class _TournamentPairingSettingsDialog extends StatefulWidget {
  const _TournamentPairingSettingsDialog({required this.settings});

  final TournamentPairingSettings settings;

  @override
  State<_TournamentPairingSettingsDialog> createState() =>
      _TournamentPairingSettingsDialogState();
}

class _TournamentPairingSettingsDialogState
    extends State<_TournamentPairingSettingsDialog> {
  late TournamentPairingSettings _value = widget.settings;

  Widget _toggle(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: MakeChessLocalizedText(title),
      value: value,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const MakeChessLocalizedText('Настройка жеребьёвки'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<int>(
                initialValue: _value.cycles,
                decoration: InputDecoration(
                  labelText:
                      MakeChessLocalization.phrase('Количество полных кругов'),
                ),
                items: List<int>.generate(10, (index) => index + 1)
                    .map((count) => DropdownMenuItem<int>(
                          value: count,
                          child: MakeChessLocalizedText('$count'),
                        ))
                    .toList(growable: false),
                onChanged: (count) => setState(
                  () => _value = _value.copyWith(cycles: count ?? 1),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _value.gamesPerOpponent,
                decoration: InputDecoration(
                  labelText:
                      MakeChessLocalization.phrase('Партий с одним соперником'),
                ),
                items: List<int>.generate(10, (index) => index + 1)
                    .map((count) => DropdownMenuItem<int>(
                          value: count,
                          child: MakeChessLocalizedText('$count'),
                        ))
                    .toList(growable: false),
                onChanged: (count) => setState(
                  () => _value = _value.copyWith(gamesPerOpponent: count ?? 1),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<TournamentColorOrder>(
                initialValue: _value.colorOrder,
                decoration: InputDecoration(
                  labelText: MakeChessLocalization.phrase('Порядок цветов'),
                ),
                items: TournamentColorOrder.values
                    .map((order) => DropdownMenuItem<TournamentColorOrder>(
                          value: order,
                          child: MakeChessLocalizedText(order.label),
                        ))
                    .toList(growable: false),
                onChanged: (order) => setState(
                  () => _value = _value.copyWith(colorOrder: order),
                ),
              ),
              const Divider(height: 28),
              _toggle(
                  'Учитывать рейтинг',
                  _value.useRating,
                  (v) =>
                      setState(() => _value = _value.copyWith(useRating: v))),
              _toggle(
                  'Запрещать повторные встречи',
                  _value.avoidRematches,
                  (v) => setState(
                      () => _value = _value.copyWith(avoidRematches: v))),
              _toggle(
                  'Балансировать белые и чёрные',
                  _value.balanceColors,
                  (v) => setState(
                      () => _value = _value.copyWith(balanceColors: v))),
              _toggle(
                  'Завершать тур после окончания всех партий',
                  _value.autoFinishRound,
                  (v) => setState(
                      () => _value = _value.copyWith(autoFinishRound: v))),
              _toggle(
                  'Автоматически запускать следующий тур',
                  _value.autoStartNextRound,
                  (v) => setState(
                      () => _value = _value.copyWith(autoStartNextRound: v))),
              _toggle(
                  'Разрешить ручные исправления',
                  _value.allowManualCorrections,
                  (v) => setState(() =>
                      _value = _value.copyWith(allowManualCorrections: v))),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: _value.nextRoundDelaySeconds,
                decoration: InputDecoration(
                  labelText: MakeChessLocalization.phrase(
                      'Пауза перед следующим туром'),
                ),
                items: const [0, 10, 30, 60, 120, 300]
                    .map((seconds) => DropdownMenuItem<int>(
                          value: seconds,
                          child: MakeChessLocalizedText('$seconds сек.'),
                        ))
                    .toList(growable: false),
                onChanged: (seconds) => setState(() => _value =
                    _value.copyWith(nextRoundDelaySeconds: seconds ?? 30)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const MakeChessLocalizedText('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _value),
          child: const MakeChessLocalizedText('Применить'),
        ),
      ],
    );
  }
}
