import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart'; // <— ДЛЯ проводника

import '../landing_page.dart';
import 'common_top_bar.dart';
import '../features/call/call_overlay.dart';
import '../features/call/ring_service.dart';
import '../services/lobby_store.dart';
import '../services/bg_controller.dart';

typedef PlayBuilder = Widget Function(Key? key);

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.playBuilder,
  });

  final PlayBuilder playBuilder;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // навигация и состояние игры
  final _navKey = GlobalKey<NavigatorState>();
  final GlobalKey _playKey = GlobalKey();
  String _currentPath = '/';

  // масштаб
  double _scalePercent = 100;
  dynamic get _playState => _playKey.currentState as dynamic;

  // звонки
  final _ringer = AudioPlayer();
  StreamSubscription<IncomingCall>? _incomingSub;
  IncomingCall? _incoming; // для кнопки "Принять звонок" в шапке

  // Кэш «моего» ника
  String _myUsername = '';

  @override
  void initState() {
    super.initState();

    // фон: подхват сохранённого изображения
    BgController.instance.load();

    // звонки: подписка (нужен именно приватный метод с подчёркиванием)
    _listenIncoming();

    // подтянуть масштаб после построения play-экрана
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScaleFromGame(scheduleIfNull: true);
    });
  }
// подписка на входящие звонки
// подписка на входящие звонки

  @override
  void dispose() {
    _incomingSub?.cancel();
    _ringer.dispose();
    super.dispose();
  }

  // ---------- вспомогательное: определить мой ник ----------
  String _resolveMyUsername() {
    final users = LobbyStore.instance.users.value;
    final hasMe = users.where((u) => u.isMe).toList();
    if (hasMe.isNotEmpty) return hasMe.first.username.trim();

    final mySupabaseId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final byId = users.where((u) => u.id == mySupabaseId).toList();
    if (byId.isNotEmpty) return byId.first.username.trim();

    return 'player';
  }

  // --- масштаб из экрана игры ---
  void _refreshScaleFromGame({bool scheduleIfNull = false}) {
    try {
      final st = _playState;
      final v = (st?.readBoardPercent() as double?);
      if (v != null) {
        if (mounted) setState(() => _scalePercent = v);
      } else if (scheduleIfNull) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _refreshScaleFromGame();
        });
      }
    } catch (_) {}
  }

  void _scaleMinus() {
    setState(() {
      _scalePercent = (_scalePercent - 10).clamp(10, 500).toDouble();
    });
    if (_currentPath == '/play') {
      final st = _playState;
      st?.changeBoardPercent(-10);
      _refreshScaleFromGame(scheduleIfNull: true);
    }
  }

  void _scalePlus() {
    setState(() {
      _scalePercent = (_scalePercent + 10).clamp(10, 500).toDouble();
    });
    if (_currentPath == '/play') {
      final st = _playState;
      st?.changeBoardPercent(10);
      _refreshScaleFromGame(scheduleIfNull: true);
    }
  }

  void _scaleReset() {
    setState(() {
      _scalePercent = 100;
    });
    if (_currentPath == '/play') {
      final st = _playState;
      st?.resetBoardPercent();
      _refreshScaleFromGame(scheduleIfNull: true);
    }
  }

  // --- входящие звонки: звук + диалог + открытие CallOverlay ---
  void _listenIncoming() {
    _incomingSub?.cancel();
    _incomingSub = RingService.instance.onIncoming.listen((p) async {
      // кого именно зовут — фильтр оставляем как у тебя
      final myName = _myUsername.isEmpty ? _resolveMyUsername() : _myUsername;
      String norm(String s) => s.trim().toLowerCase();
      final isUnknownMe = norm(myName) == 'player';
      final isForMe = norm(p.toName) == norm(myName);
      if (!isUnknownMe && !isForMe) {
        return; // не мне — пропускаем
      }

      setState(() => _incoming = p);

      try {
        // ЗВУК ЗВОНИТ ПО КРУГУ
        await _ringer.setReleaseMode(ReleaseMode.loop);
        // ВАЖНО: путь совпадает с твоей структурой assets/sfx/ring.mp3
        await _ringer.play(AssetSource('sfx/ring.mp3'), volume: 0.6);
      } catch (_) {}

      // Диалог "Входящий звонок"
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Входящий звонок'),
          content: Text(
            '${p.fromName} звонит вам\n'
            '(${p.audioOnly ? "аудио" : "видео"})\n'
            'Комната: ${p.roomId}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отклонить'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Принять'),
            ),
          ],
        ),
      );

      // Останавливаем рингтон
      try {
        await _ringer.stop();
      } catch (_) {}

      if (ok == true && mounted) {
        // Открываем оверлей звонка
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => CallOverlay(
            initialRoomId: p.roomId,
            audioOnly: p.audioOnly,
            autoJoin: true,
          ),
        );
      }

      if (mounted) setState(() => _incoming = null);
    });
  }

  Future<void> _acceptIncoming() async {
    final inc = _incoming;
    if (inc == null) return;
    try {
      await _ringer.stop();
    } catch (_) {}
    setState(() => _incoming = null);

    _openCall(
      audioOnly: inc.audioOnly,
      roomId: inc.roomId,
      autoJoin: true,
    );
  }

  Future<void> _declineIncoming() async {
    try {
      await _ringer.stop();
    } catch (_) {}
    setState(() => _incoming = null);
  }

  void _openCall(
      {required bool audioOnly, String? roomId, bool autoJoin = false}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.black,
        child: SizedBox(
          width: 980,
          height: 640,
          child: CallOverlay(
              audioOnly: audioOnly, initialRoomId: roomId, autoJoin: autoJoin),
        ),
      ),
    );
  }

  // --- НАЖАТИЕ «Тема фона»: ОТКРЫВАЕМ ПРОВОДНИК НАПРЯМУЮ ЗДЕСЬ ---
  Future<void> _openBackgroundFilePicker() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true, // для web/desktop — вернёт bytes
    );
    if (res == null || res.files.isEmpty) return;

    // На этом этапе нам важно лишь, что проводник открылся и файл выбран
    final name = res.files.first.name;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Картинка выбрана: $name')),
    );

    // Дальше можно будет сохранить bytes и показать фон — это следующий шаг.
    // final bytes = res.files.first.bytes; // Uint8List?
    // await bgController.setBg(bytes);
  }

  // --- навигация ---
  void _go(String name) {
    if (_currentPath == name) return;
    _navKey.currentState?.pushReplacementNamed(name);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ===== ФОН ЗА ВСЕМ UI (картинка из BgController или запасной цвет) =====
        AnimatedBuilder(
          animation: BgController.instance,
          builder: (context, _) {
            final bytes = BgController.instance.bgBytes;
            if (bytes != null) {
              return IgnorePointer(
                ignoring: true,
                child: Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              );
            }
            // Твой базовый светло-фиолетовый, когда картинка не выбрана
            return const ColoredBox(color: Color(0xFFF3EAF7));
          },
        ),

        // ===== ОСНОВНОЙ UI (прозрачный Scaffold поверх фона) =====
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          extendBodyBehindAppBar: true,
          appBar: CommonTopBar(
            onTitleTap: () => _go('/'),

            // разделы
            onPlay: () => _go('/play'),
            onLearn: () => _go('/learn'),
            onPuzzles: () => _go('/puzzles'),
            onTeams: () => _go('/teams'),
            onTournaments: () => _go('/tournaments'),
            onWatch: () => _go('/watch'),
            onCommunity: () => _go('/community'),

            // звонки
            onVoiceCall: () => _openCall(audioOnly: true),
            onVideoCall: () => _openCall(audioOnly: false),

            // входящий
            hasIncomingCall: _incoming != null,
            incomingFrom: _incoming?.fromName ?? '',
            onAcceptCall: _acceptIncoming,
            onDeclineCall: _declineIncoming,

            // масштаб
            showScale: true,
            scalePercent: _scalePercent,
            onScaleMinus: _scaleMinus,
            onScalePlus: _scalePlus,
            onScaleReset: _scaleReset,

            // логин
            onLoginTap: () {
              if (_currentPath != '/play') {
                _navKey.currentState
                    ?.pushNamed('/play', arguments: {'openAuth': true});
              } else {
                _navKey.currentState?.pushReplacementNamed('/play',
                    arguments: {'openAuth': true});
              }
            },

            // настройки
            onBackgroundTheme: () {
              final st = _playKey.currentState as dynamic;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                st?.openPickBackground(); // откроет диалог выбора файла
              });
            },
            onBoardTheme: () {
              final st = _playKey.currentState as dynamic;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                st?.openBoardTheme();
              });
            },
            onGptSettings: () {
              final st = _playKey.currentState as dynamic;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                st?.openGptSettings();
              });
            },
          ),

          // Навигация по страницам
          body: Navigator(
            key: _navKey,
            initialRoute: '/',
            onGenerateRoute: (settings) {
              _currentPath = settings.name ?? '/';

              late final Widget page;
              switch (_currentPath) {
                case '/':
                  page = const LandingPage();
                  break;
                case '/play':
                  page = widget.playBuilder.call(_playKey);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _refreshScaleFromGame();
                  });
                  break;
                case '/learn':
                  page = const _StubScreen(title: 'Учиться');
                  break;
                case '/puzzles':
                  page = const _StubScreen(title: 'Задачи');
                  break;
                case '/teams':
                  page = const _StubScreen(title: '2×2');
                  break;
                case '/tournaments':
                  page = const _StubScreen(title: 'Турниры');
                  break;
                case '/watch':
                  page = const _StubScreen(title: 'Смотреть');
                  break;
                case '/community':
                  page = const _StubScreen(title: 'Сообщество');
                  break;
                default:
                  page = const LandingPage();
              }

              return PageRouteBuilder(
                settings: settings,
                pageBuilder: (_, __, ___) => page,
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              );
            },
          ),
        ),
      ],
    );
  }
}

// Заглушки
class _StubScreen extends StatelessWidget {
  const _StubScreen({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title (скоро)',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}
