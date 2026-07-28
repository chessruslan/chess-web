import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_style.dart';

class GameModePanel extends StatelessWidget {
  const GameModePanel({
    super.key,
    required this.leftColWidth,
    required this.canVsEngine,
    required this.canContinueVsEngine,
    required this.canContinueVsHuman,
    required this.inRoom,
    required this.syncBoard,
    required this.vsEngine,
    required this.humanColor,
    required this.duelDelayCtl,
    required this.onContinueVsEngine,
    required this.onContinueVsHuman,
    required this.onToggleSyncBoard,
    required this.onStartEngineDuel,
    required this.onNewGame,
    required this.onHumanColorChanged,
    required this.onEngineDelayChanged,
  });

  final double leftColWidth;

  final bool canVsEngine;
  final bool canContinueVsEngine;
  final bool canContinueVsHuman;
  final bool inRoom;
  final bool syncBoard;
  final bool vsEngine;
  final ch.Color humanColor;

  final TextEditingController duelDelayCtl;

  final VoidCallback onContinueVsEngine;
  final VoidCallback onContinueVsHuman;
  final VoidCallback onToggleSyncBoard;
  final VoidCallback onStartEngineDuel;
  final VoidCallback onNewGame;

  final ValueChanged<ch.Color> onHumanColorChanged;
  final ValueChanged<String> onEngineDelayChanged;

  @override
  Widget build(BuildContext context) {
    Widget twoEqualCells(Widget left, Widget right) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : leftColWidth;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            width: panelWidth,
            child: Container(
              decoration: AppDecorations.panel(),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  twoEqualCells(
                    _NeoModeButton(
                      text: 'Продолжить с компьютером',
                      icon: Icons.smart_toy,
                      onTap:
                          canContinueVsEngine ? onContinueVsEngine : null,
                    ),
                    _NeoModeButton(
                      text: 'С человеком',
                      icon: Icons.group,
                      onTap:
                          canContinueVsHuman ? onContinueVsHuman : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  twoEqualCells(
                    _NeoModeButton(
                      text: syncBoard
                          ? 'Совместный режим: ВКЛ'
                          : 'Совместный режим',
                      icon: syncBoard ? Icons.sync : Icons.sync_disabled,
                      onTap: inRoom ? onToggleSyncBoard : null,
                      active: syncBoard,
                    ),
                    _NeoModeButton(
                      text: 'Компьютер vs Компьютер',
                      icon: Icons.auto_awesome_motion,
                      onTap: canVsEngine ? onStartEngineDuel : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  twoEqualCells(
                    _EngineDelayFieldCompact(
                      width: double.infinity,
                      controller: duelDelayCtl,
                      onChanged: onEngineDelayChanged,
                    ),
                    _ColorSelectorCompact(
                      width: double.infinity,
                      humanColor: humanColor,
                      enabled: !(vsEngine || inRoom),
                      onChanged: onHumanColorChanged,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: _NeoModeButton(
                      text: 'Новый игрок',
                      icon: Icons.fiber_new,
                      onTap: onNewGame,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

}

class _NeoModeButton extends StatefulWidget {
  const _NeoModeButton({
    required this.text,
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final String text;
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;

  @override
  State<_NeoModeButton> createState() => _NeoModeButtonState();
}

class _NeoModeButtonState extends State<_NeoModeButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final active = widget.active || (_hover && enabled);
    final pressed = _pressed && enabled;

    final fgColor = !enabled
        ? AppColors.text.withOpacity(0.35)
        : (active ? AppColors.accent : AppColors.text);

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
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: AppDecorations.neoButton(
            active: active,
            pressed: pressed,
            enabled: enabled,
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: fgColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button.copyWith(
                    color: fgColor,
                    fontSize: 13.5,
                    shadows: active
                        ? const [
                            Shadow(
                              color: AppColors.accentGlow,
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorSelectorCompact extends StatelessWidget {
  const _ColorSelectorCompact({
    required this.width,
    required this.humanColor,
    required this.enabled,
    required this.onChanged,
  });

  final double width;
  final ch.Color humanColor;
  final bool enabled;
  final ValueChanged<ch.Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final whiteSelected = humanColor == ch.Color.WHITE;
    final blackSelected = humanColor == ch.Color.BLACK;

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Вы играете за:', style: AppTextStyles.caption),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _ColorButton(
                  text: 'Белые',
                  selected: whiteSelected,
                  enabled: enabled,
                  onTap: () => onChanged(ch.Color.WHITE),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ColorButton(
                  text: 'Чёрные',
                  selected: blackSelected,
                  enabled: enabled,
                  onTap: () => onChanged(ch.Color.BLACK),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorButton extends StatefulWidget {
  const _ColorButton({
    required this.text,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_ColorButton> createState() => _ColorButtonState();
}

class _ColorButtonState extends State<_ColorButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || (_hover && widget.enabled);
    final fgColor = !widget.enabled
        ? AppColors.text.withOpacity(0.35)
        : (active ? AppColors.accent : AppColors.text);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown:
            widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp:
            widget.enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel:
            widget.enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 40,
          alignment: Alignment.center,
          decoration: AppDecorations.neoButton(
            active: active,
            pressed: _pressed && widget.enabled,
            enabled: widget.enabled,
          ),
          child: Text(
            widget.text,
            style: AppTextStyles.button.copyWith(
              color: fgColor,
              fontSize: 13,
              shadows: active
                  ? const [
                      Shadow(
                        color: AppColors.accentGlow,
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _EngineDelayFieldCompact extends StatelessWidget {
  const _EngineDelayFieldCompact({
    required this.width,
    required this.controller,
    required this.onChanged,
  });

  final double width;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Задержка, мс', style: AppTextStyles.caption),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            style: const TextStyle(color: AppColors.text),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: AppInputs.dark(),

            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
