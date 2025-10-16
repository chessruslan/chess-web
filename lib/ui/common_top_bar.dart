import 'dart:async';
import 'package:flutter/material.dart';

/// Верхняя шапка приложения.
/// Меню, «Настройки», аудио/видео, масштаб, вход, и таблетка "Принять звонок".
class CommonTopBar extends StatelessWidget implements PreferredSizeWidget {
  // --------- Навигация / заголовок ----------
  final VoidCallback? onTitleTap;
  final VoidCallback? onPlay;
  final VoidCallback? onLearn;
  final VoidCallback? onPuzzles;
  final VoidCallback? onTeams;
  final VoidCallback? onTournaments;
  final VoidCallback? onWatch;
  final VoidCallback? onCommunity;

  // --------- Настройки ----------
  final VoidCallback? onBackgroundTheme; // «Тема фона»
  final VoidCallback? onBoardTheme; // «Тема доски»
  final VoidCallback? onGptSettings; // «Настройка запроса GPT»

  // --------- Аудио/Видео ----------
  final VoidCallback? onVoiceCall;
  final VoidCallback? onVideoCall;

  // --------- Вход / Регистрация ----------
  final VoidCallback? onLoginTap;

  // --------- Масштаб ----------
  final bool showScale;
  final double? scalePercent;
  final VoidCallback? onScaleMinus;
  final VoidCallback? onScalePlus;
  final VoidCallback? onScaleReset;

  // --------- Входящий вызов ----------
  final bool hasIncomingCall;
  final String? incomingFrom;
  final VoidCallback? onAcceptCall;
  final VoidCallback? onDeclineCall;
  final bool blink;

  const CommonTopBar({
    super.key,
    // Навигация
    this.onTitleTap,
    this.onPlay,
    this.onLearn,
    this.onPuzzles,
    this.onTeams,
    this.onTournaments,
    this.onWatch,
    this.onCommunity,

    // Настройки
    this.onBackgroundTheme,
    this.onBoardTheme,
    this.onGptSettings,

    // Аудио/Видео
    this.onVoiceCall,
    this.onVideoCall,

    // Login
    this.onLoginTap,

    // Масштаб
    this.showScale = true,
    this.scalePercent,
    this.onScaleMinus,
    this.onScalePlus,
    this.onScaleReset,

    // Входящий
    this.hasIncomingCall = false,
    this.incomingFrom,
    this.onAcceptCall,
    this.onDeclineCall,
    this.blink = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      elevation: 0,
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      titleSpacing: 8,
      title: InkWell(
        onTap: onTitleTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            'TwinChess',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      centerTitle: false,
      actions: [
        // -------- Меню слева --------
        _menuBtn('Играть', onPlay),
        _menuBtn('Учиться', onLearn),
        _menuBtn('Задачи', onPuzzles),
        _menuBtn('2×2', onTeams),
        _menuBtn('Турниры', onTournaments),
        _menuBtn('Сообщество', onCommunity),

        // -------- Кнопка "Настройки" --------
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: PopupMenuButton<String>(
            tooltip: 'Настройки',
            onSelected: (value) {
              switch (value) {
                case 'bg':
                  onBackgroundTheme?.call();
                  break;
                case 'board':
                  onBoardTheme?.call();
                  break;
                case 'gpt':
                  onGptSettings?.call();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'bg', child: Text('Тема фона')),
              PopupMenuItem(value: 'board', child: Text('Тема доски')),
              PopupMenuItem(value: 'gpt', child: Text('Настройка запроса GPT')),
            ],
            child: TextButton(
              onPressed: null, // клик обрабатывает сам PopupMenuButton
              child: const Text('Настройки'),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // -------- "Принять звонок" --------
        _IncomingCallPill(
          enabled: hasIncomingCall && onAcceptCall != null,
          from: incomingFrom,
          blink: blink,
          onAccept: onAcceptCall,
          onDecline: onDeclineCall,
        ),

        const SizedBox(width: 8),

        // -------- Аудио / Видео --------
        _textPill(context, 'Аудио', Icons.call, onVoiceCall),
        const SizedBox(width: 8),
        _textPill(context, 'Видео', Icons.videocam, onVideoCall),

        const SizedBox(width: 16),

        // -------- Масштаб --------
        if (showScale)
          _ScaleControl(
            percent: (scalePercent ?? 100).toInt(),
            onMinus: onScaleMinus,
            onPlus: onScalePlus,
            onReset: onScaleReset,
          ),

        const SizedBox(width: 16),

        // -------- Вход / Регистрация --------
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(
            onPressed: onLoginTap,
            child: const Text('Вход / Регистрация'),
          ),
        ),
      ],
    );
  }

  Widget _menuBtn(String text, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: onTap,
        child: Text(text),
      ),
    );
  }

  Widget _textPill(
      BuildContext context, String text, IconData icon, VoidCallback? onTap) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(text),
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return cs.primary.withOpacity(0.5);
          }
          return cs.primary;
        }),
        foregroundColor: WidgetStatePropertyAll(cs.onPrimary),
        elevation: const WidgetStatePropertyAll(0),
      ),
    );
  }
}

/// Небольшой контрол масштаба вида "— 100% +".
class _ScaleControl extends StatelessWidget {
  const _ScaleControl({
    required this.percent,
    this.onMinus,
    this.onPlus,
    this.onReset,
  });

  final int percent;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        IconButton(
          tooltip: 'Уменьшить',
          icon: const Icon(Icons.remove),
          onPressed: onMinus,
        ),
        GestureDetector(
          onDoubleTap: onReset,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text('$percent%'),
          ),
        ),
        IconButton(
          tooltip: 'Увеличить',
          icon: const Icon(Icons.add),
          onPressed: onPlus,
        ),
      ],
    );
  }
}

/// Таблетка "Принять звонок" с мигающей точкой.
class _IncomingCallPill extends StatelessWidget {
  const _IncomingCallPill({
    required this.enabled,
    required this.from,
    required this.blink,
    required this.onAccept,
    required this.onDecline,
  });

  final bool enabled;
  final String? from;
  final bool blink;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final txt = from == null || from!.isEmpty
        ? 'Принять звонок'
        : 'Принять звонок от $from';

    final pill = FilledButton(
      onPressed: enabled ? onAccept : null,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (enabled) const _BlinkDot(),
          if (enabled) const SizedBox(width: 8),
          const Icon(Icons.call, size: 18),
          const SizedBox(width: 8),
          Text(txt),
          const SizedBox(width: 6),
          if (enabled)
            InkWell(
              onTap: onDecline,
              child: const Padding(
                padding: EdgeInsets.only(left: 4.0),
                child: Icon(Icons.close, size: 18),
              ),
            ),
        ],
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: pill,
    );
  }
}

class _BlinkDot extends StatefulWidget {
  const _BlinkDot();

  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot> {
  bool _on = true;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 600), (_) {
      setState(() => _on = !_on);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: _on ? 1 : .2,
      child: const Icon(Icons.circle, size: 10, color: Colors.redAccent),
    );
  }
}
