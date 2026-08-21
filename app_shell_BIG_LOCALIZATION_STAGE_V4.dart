// MAKECHESS_BIG_LOCALIZATION_STAGE_V4_20260807
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

import 'common_top_bar.dart';
import '../localization/makechess_localization.dart';
import 'app_style.dart';
import '../features/call/video_overlay.dart';
import '../features/call/ring_service.dart';
import '../services/lobby_store.dart';
import '../services/bg_controller.dart';
import '../services/site_design_controller.dart';
import '../services/lichess_service.dart';
import '../platform/web_compat.dart';
import '../classroom/classroom_signaling.dart';

import '../features/call/call_coordinator.dart';
import '../features/call/room_selection.dart';

import 'start_modal.dart';
import 'board_theme_controller.dart';
import 'dialogs/site_settings_dialog.dart';
import 'dialogs/board_theme_picker_dialog.dart';
import 'dialogs/personal_cabinet_dialog.dart';
import 'dialogs/teacher_access_dialog.dart';
import 'messages/general_messages_dialog.dart';
import 'tournament/tournament_manager_dialog.dart';

// file_picker используется в проекте рядом с настройками фона.
// Этот стаб нужен, чтобы анализатор не ругался на импорт, если прямого вызова здесь нет.
void _keepFilePickerImport() {
  FilePicker.platform;
}

typedef PlayBuilder = Widget Function(
  Key? key,
  BoardThemeController boardTheme,
);

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
  late final BoardThemeController boardTheme = BoardThemeController();

  bool _startModalShown = false;
  bool _pricingOpen = false;

  final _navKey = GlobalKey<NavigatorState>();
  final GlobalKey _playKey = GlobalKey();
  String _currentPath = '/play';
  String _currentLanguage = 'RU';

  double _scalePercent = 100;
  dynamic get _playState => _playKey.currentState;

  final _ringer = AudioPlayer();
  StreamSubscription<IncomingCall>? _incomingSub;
  IncomingCall? _incoming;

  final _lessonRinger = AudioPlayer();
  StreamSubscription<LessonInvitation>? _lessonInvitationSub;
  bool _lessonInvitationDialogOpen = false;

  StreamSubscription<AuthState>? _authStateSub;
  StreamSubscription<MakeChessMessage>? _messageIncomingSub;
  String? _listenersUserId;
  int _listenersGeneration = 0;
  int _unreadMessages = 0;

  String _myUsername = '';

  Future<void> _endCallFromTopBar() async {
    VideoOverlay.instance.unbindRenderers();

    try {
      await CallCoordinator.instance.hangup();
    } catch (_) {}
    try {
      await _playState?.stopClassroomVideo?.call();
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: MakeChessLocalizedText('Звонок завершён')),
    );
  }

  @override
  void initState() {
    super.initState();
    MakeChessLocalization.validateOrThrow();
    MakeChessLocalizationController.setLanguage(_currentLanguage);
    _keepFilePickerImport();
    unawaited(
      SiteDesignController.instance.initialize(
        boardTheme: boardTheme,
        background: BgController.instance,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      VideoOverlay.instance.attach(context);
    });

    _authStateSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      unawaited(_syncIncomingListenersWithAuth());
    });
    unawaited(_syncIncomingListenersWithAuth());
  }

  Future<void> _openPricingModal() async {
    if (_pricingOpen || StartModal.isOpen) return;
    _pricingOpen = true;

    try {
      await StartModal.show(
        context: context,
        onFree: () {},
        onPro: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: MakeChessLocalizedText('Pro: позже подключим оплату')),
          );
        },
        onPremium: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: MakeChessLocalizedText('Premium: позже подключим оплату')),
          );
        },
        onLogin: () {
          _openPlayScreen(openAuth: true);
        },
        onRegister: () {
          _openPlayScreen(openAuth: true);
        },
        onSchool: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: MakeChessLocalizedText('School: позже подключим школу')),
          );
        },
      );
    } finally {
      _pricingOpen = false;
    }
  }

  void _openTeacherAvatar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: MakeChessLocalizedText('Учитель аватар будет подключён позже'),
      ),
    );
  }

  Future<void> _openBoardThemeDialog() async {
    final result = await showBoardThemePickerDialog(
      context,
      initialLight: boardTheme.lightSquare,
      initialDark: boardTheme.darkSquare,
    );
    if (result == null) return;
    boardTheme.setLight(result.$1);
    boardTheme.setDark(result.$2);
  }

  Future<void> _openGeneralMessages() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final userId = (user?.id ?? '').trim();
    if (userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: MakeChessLocalizedText('Сообщения доступны после входа в аккаунт'),
        ),
      );
      _openPlayScreen(openAuth: true);
      return;
    }

    var name = await _resolveMyUsernameFromProfile();
    if (name.trim().isEmpty) name = 'Пользователь';
    if (!mounted) return;
    await showGeneralMessagesDialog(
      context: context,
      currentUserId: userId,
      currentUserName: name,
    );
    await _refreshUnreadMessages();
  }

  Future<void> _openTournamentsFromTopBar() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final userId = (user?.id ?? '').trim();
    if (userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: MakeChessLocalizedText('Турниры доступны после входа в аккаунт'),
        ),
      );
      _openPlayScreen(openAuth: true);
      return;
    }

    var students = const <TournamentStudent>[];
    Object? loadError;
    try {
      final rows = await client
          .from('teacher_students')
          .select('student_id, student_nickname, created_at')
          .eq('teacher_id', userId)
          .order('created_at', ascending: true);

      students = rows
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .map(
            (row) => TournamentStudent(
              id: '${row['student_id'] ?? ''}'.trim(),
              name: '${row['student_nickname'] ?? ''}'.trim(),
              online: false,
            ),
          )
          .where(
            (student) =>
                student.id.isNotEmpty &&
                student.name.isNotEmpty &&
                student.id != userId,
          )
          .toList(growable: false);
    } catch (error) {
      loadError = error;
    }

    if (!mounted) return;
    if (loadError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: MakeChessLocalizedText(
            'Список учеников не загрузился. '
            'Турниры открыты без этого списка.',
          ),
        ),
      );
    }
    await showTournamentManagerDialog(
      context: context,
      students: students,
    );
  }

  Future<void> _openTeacherAccess() async {
    final allowed = await showTeacherAccessDialog(context);
    if (!mounted || !allowed) return;
    _openPlayScreen(openLearningTeacher: true);
  }

  Future<void> _refreshUnreadMessages() async {
    final userId = (Supabase.instance.client.auth.currentUser?.id ?? '').trim();
    if (userId.isEmpty) {
      if (mounted && _unreadMessages != 0) {
        setState(() => _unreadMessages = 0);
      }
      return;
    }
    try {
      final messages =
          await MakeChessMessageRealtimeService.instance.syncFromDatabase();
      final count = messages
          .where((message) =>
              message.recipientId == userId && message.status == 'unread')
          .length;
      if (mounted && count != _unreadMessages) {
        setState(() => _unreadMessages = count);
      }
    } catch (_) {}
  }

  Future<void> _openPersonalCabinet() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || user.id.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: MakeChessLocalizedText('Личный кабинет доступен после входа в аккаунт'),
        ),
      );
      _openPlayScreen(openAuth: true);
      return;
    }

    var nickname = await _resolveMyUsernameFromProfile();
    var classicRating = 1200;
    try {
      final row = await client
          .from('profiles')
          .select('nickname, rating')
          .eq('id', user.id)
          .maybeSingle();
      final profileNickname = '${row?['nickname'] ?? ''}'.trim();
      if (profileNickname.isNotEmpty) nickname = profileNickname;
      final rawRating = row?['rating'];
      classicRating = rawRating is num
          ? rawRating.toInt()
          : int.tryParse('$rawRating') ?? 1200;
    } catch (_) {}

    if (!mounted) return;
    await showPersonalCabinetDialog(
      context,
      userId: user.id,
      initialNickname: nickname,
      initialClassicRating: classicRating,
    );
  }

  // Старая реализация оставлена временно для безопасного сравнения поведения.
  // Оба рабочих маршрута используют общий showBoardThemePickerDialog выше.
  Future<void> _openBoardThemeDialogLegacy() async {
    Color light = boardTheme.lightSquare;
    Color dark = boardTheme.darkSquare;

    Future<Color?> pickColor(Color current) {
      final swatches = <Color>[
        const Color(0xFFF0D9B5),
        const Color(0xFFB58863),
        const Color(0xFFE7D3B0),
        const Color(0xFFAE825C),
        const Color(0xFFEEEED2),
        const Color(0xFF769656),
        const Color(0xFFD8C3A5),
        const Color(0xFF8B6A4E),
        const Color(0xFFC2A383),
        const Color(0xFF7A5C3E),
        const Color(0xFFE6CCB2),
        const Color(0xFFB08968),
        const Color(0xFFE0E0E0),
        const Color(0xFF9E9E9E),
        const Color(0xFFBDBDBD),
        const Color(0xFF616161),
        const Color(0xFFEEEEEE),
        const Color(0xFF424242),
        const Color(0xFFB7D7A8),
        const Color(0xFF4CAF50),
        const Color(0xFF81C784),
        const Color(0xFF2E7D32),
        const Color(0xFFA5D6A7),
        const Color(0xFF1B5E20),
        const Color(0xFFDDEEFF),
        const Color(0xFF6B8FB3),
        const Color(0xFFBBDEFB),
        const Color(0xFF1E88E5),
        const Color(0xFF90CAF9),
        const Color(0xFF0D47A1),
        const Color(0xFFE6E6FA),
        const Color(0xFF7B68EE),
        const Color(0xFFD1C4E9),
        const Color(0xFF512DA8),
        const Color(0xFFB39DDB),
        const Color(0xFF311B92),
        const Color(0xFFFFCDD2),
        const Color(0xFFE57373),
        const Color(0xFFEF9A9A),
        const Color(0xFFC62828),
        const Color(0xFFFFAB91),
        const Color(0xFFD84315),
        const Color(0xFFFFF9C4),
        const Color(0xFFFFF59D),
        const Color(0xFFE1BEE7),
        const Color(0xFFF8BBD0),
        const Color(0xFFB2EBF2),
        const Color(0xFFC8E6C9),
      ];

      return showDialog<Color>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const MakeChessLocalizedText('Выберите цвет'),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: swatches.map((c) {
              final selected = c.value == current.value;
              return GestureDetector(
                onTap: () => Navigator.of(ctx).pop(c),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? Colors.black : Colors.black12,
                      width: selected ? 2 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const MakeChessLocalizedText('Отмена'),
            ),
          ],
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 220, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MakeChessLocalizedText(
                  'Тема доски',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const MakeChessLocalizedText('Светлая клетка'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final picked = await pickColor(light);
                              if (picked != null) {
                                setLocalState(() => light = picked);
                              }
                            },
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: light,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.black12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        children: [
                          const MakeChessLocalizedText('Тёмная клетка'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final picked = await pickColor(dark);
                              if (picked != null) {
                                setLocalState(() => dark = picked);
                              }
                            },
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: dark,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.black12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const MakeChessLocalizedText('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          boardTheme.setLight(light);
                          boardTheme.setDark(dark);
                          Navigator.of(ctx).pop();
                        },
                        child: const MakeChessLocalizedText('Применить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _authStateSub?.cancel();
    _authStateSub = null;
    _messageIncomingSub?.cancel();
    _messageIncomingSub = null;
    _incomingSub?.cancel();
    _incomingSub = null;
    _lessonInvitationSub?.cancel();
    _lessonInvitationSub = null;
    unawaited(LessonInvitationService.instance.stop());

    try {
      _ringer.stop();
    } catch (_) {}
    try {
      _lessonRinger.stop();
    } catch (_) {}

    _ringer.dispose();
    _lessonRinger.dispose();
    VideoOverlay.instance.detach();
    unawaited(MakeChessMessageRealtimeService.instance.stop());

    super.dispose();
  }

  String _resolveMyUsername() {
    final users = LobbyStore.instance.users.value;
    final hasMe = users.where((u) => u.isMe).toList();
    if (hasMe.isNotEmpty) return hasMe.first.username.trim();

    final mySupabaseId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final byId = users.where((u) => u.id == mySupabaseId).toList();
    if (byId.isNotEmpty) return byId.first.username.trim();

    return 'player';
  }

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
      _scalePercent = (_scalePercent - 5).clamp(10, 500).toDouble();
    });
    if (_currentPath == '/play') {
      final st = _playState;
      st?.changeBoardPercent(-5);
      _refreshScaleFromGame(scheduleIfNull: true);
    }
  }

  void _scalePlus() {
    setState(() {
      _scalePercent = (_scalePercent + 5).clamp(10, 500).toDouble();
    });
    if (_currentPath == '/play') {
      final st = _playState;
      st?.changeBoardPercent(5);
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

  Future<void> _syncIncomingListenersWithAuth() async {
    final generation = ++_listenersGeneration;
    final client = Supabase.instance.client;
    final userId = (client.auth.currentUser?.id ?? '').trim();

    if (_listenersUserId == userId &&
        (userId.isEmpty ||
            (_incomingSub != null &&
                _lessonInvitationSub != null &&
                _messageIncomingSub != null))) {
      return;
    }

    _listenersUserId = userId;

    await _incomingSub?.cancel();
    _incomingSub = null;
    await _lessonInvitationSub?.cancel();
    _lessonInvitationSub = null;
    await _messageIncomingSub?.cancel();
    _messageIncomingSub = null;

    try {
      await _ringer.stop();
    } catch (_) {}
    try {
      await _lessonRinger.stop();
    } catch (_) {}

    await LessonInvitationService.instance.stop();
    await MakeChessMessageRealtimeService.instance.stop();

    if (generation != _listenersGeneration) return;

    if (userId.isEmpty) {
      if (mounted && _incoming != null) {
        setState(() => _incoming = null);
      }
      if (mounted && _unreadMessages != 0) {
        setState(() => _unreadMessages = 0);
      }
      return;
    }

    _listenIncoming(userId);
    await _listenLessonInvitations(userId);
    await MakeChessMessageRealtimeService.instance.start(client);
    _messageIncomingSub =
        MakeChessMessageRealtimeService.instance.incoming.listen((_) {
      unawaited(_refreshUnreadMessages());
    });
    await _refreshUnreadMessages();
  }

  void _listenIncoming(String expectedUserId) {
    if (expectedUserId.isEmpty) return;

    _incomingSub?.cancel();
    // Сам Realtime-канал общий, поэтому адресата обязательно проверяем
    // по неизменяемому ID аккаунта, а не по нику и не по слову "player".
    unawaited(
      RingService.instance.ensureConnected().catchError((Object error) {
        debugPrint('[CALLS] Failed to subscribe to incoming calls: $error');
      }),
    );
    _incomingSub = RingService.instance.onIncoming.listen((p) async {
      final currentUserId =
          (Supabase.instance.client.auth.currentUser?.id ?? '').trim();
      if (currentUserId.isEmpty || currentUserId != expectedUserId) return;
      if (p.toId.trim().isEmpty || p.toId.trim() != currentUserId) return;

      // sendRing repeats ephemeral invitations; show only one dialog per call.
      if (_incoming?.roomId == p.roomId) return;

      if (!mounted) return;
      setState(() => _incoming = p);

      try {
        await _ringer.setReleaseMode(ReleaseMode.loop);
        await _ringer.play(AssetSource('sfx/ring.mp3'), volume: 0.6);
      } catch (_) {}

      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const MakeChessLocalizedText('Входящий звонок'),
          content: Text(
            '${p.fromName} звонит вам\n'
            '(${p.audioOnly ? "аудио" : "видео"})\n'
            'Комната: ${p.roomId}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const MakeChessLocalizedText('Отклонить'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const MakeChessLocalizedText('Принять'),
            ),
          ],
        ),
      );

      try {
        await _ringer.stop();
      } catch (_) {}

      final userIdAfterDialog =
          (Supabase.instance.client.auth.currentUser?.id ?? '').trim();
      if (ok == true &&
          mounted &&
          userIdAfterDialog == expectedUserId &&
          p.toId.trim() == userIdAfterDialog) {
        await CallCoordinator.instance.acceptIncoming(p);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: MakeChessLocalizedText('Вызов принят, устанавливается соединение'),
          ),
        );
      }

      if (!mounted) return;
      setState(() => _incoming = null);
    });
  }

  Future<String> _resolveMyUsernameFromProfile() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return _resolveMyUsername();

    try {
      final row = await client
          .from('profiles')
          .select('nickname')
          .eq('id', uid)
          .maybeSingle();
      final nickname = '${row?['nickname'] ?? ''}'.trim();
      if (nickname.isNotEmpty) return nickname;
    } catch (_) {}

    return _resolveMyUsername();
  }

  Future<void> _listenLessonInvitations(String expectedUserId) async {
    if (expectedUserId.isEmpty) return;

    try {
      final client = Supabase.instance.client;
      if ((client.auth.currentUser?.id ?? '').trim() != expectedUserId) return;

      final service = LessonInvitationService.instance;
      await service.start(client);

      if ((client.auth.currentUser?.id ?? '').trim() != expectedUserId) {
        await service.stop();
        return;
      }

      await _lessonInvitationSub?.cancel();
      _lessonInvitationSub = service.incoming.listen((invitation) {
        final currentUserId =
            (Supabase.instance.client.auth.currentUser?.id ?? '').trim();
        if (currentUserId != expectedUserId ||
            invitation.studentId != expectedUserId) {
          return;
        }
        unawaited(_showLessonInvitation(invitation));
      });
    } catch (error) {
      debugPrint('[LESSON INVITES] Не удалось запустить канал: $error');
    }
  }

  Future<void> _showLessonInvitation(LessonInvitation invitation) async {
    if (!mounted || _lessonInvitationDialogOpen) return;

    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (myId.isEmpty || invitation.studentId != myId) return;

    _lessonInvitationDialogOpen = true;

    try {
      try {
        await _lessonRinger.setReleaseMode(ReleaseMode.loop);
        await _lessonRinger.play(
          AssetSource('sfx/ring.mp3'),
          volume: 0.65,
        );
      } catch (_) {}

      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            invitation.isVideo ? 'Входящий видеовызов' : 'Приглашение на урок',
          ),
          content: Text(
            invitation.isVideo
                ? '${invitation.teacherName} приглашает вас на видеосвязь.'
                : '${invitation.teacherName} приглашает вас на урок.\n\n'
                    'После принятия откроется панель «Учиться» и включится '
                    'совместный режим доски.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const MakeChessLocalizedText('Отклонить'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const MakeChessLocalizedText('Принять'),
            ),
          ],
        ),
      );

      try {
        await _lessonRinger.stop();
      } catch (_) {}

      final currentUserId =
          (Supabase.instance.client.auth.currentUser?.id ?? '').trim();
      if (currentUserId != myId) return;

      final studentName = await _resolveMyUsernameFromProfile();
      await LessonInvitationService.instance.sendResponse(
        LessonInvitationResponse(
          lessonId: invitation.lessonId,
          teacherId: invitation.teacherId,
          studentId: myId,
          studentName: studentName,
          accepted: accepted == true,
          createdAt: DateTime.now(),
        ),
      );

      if (accepted == true && mounted) {
        _openPlayScreen(
          lessonInvitation: invitation,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка приглашения на урок: $error')),
        );
      }
    } finally {
      try {
        await _lessonRinger.stop();
      } catch (_) {}
      _lessonInvitationDialogOpen = false;
    }
  }

  void _go(String name) {
    if (_currentPath == name) return;
    _navKey.currentState?.pushReplacementNamed(name);
    if (mounted) {
      setState(() {
        _currentPath = name;
      });
    }
  }

  void _runWhenPlayReady(VoidCallback action, {int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_currentPath == '/play' && _playKey.currentState != null) {
        action();
        _refreshScaleFromGame(scheduleIfNull: true);
        return;
      }
      if (attempt < 12) {
        _runWhenPlayReady(action, attempt: attempt + 1);
      }
    });
  }

  void _openPlayScreen({
    bool openPuzzles = false,
    bool openLearning = false,
    bool openLearningTeacher = false,
    bool openLearningStudent = false,
    bool openAuth = false,
    bool boardOnly = false,
    bool openLobby = false,
    bool openGameSettings = false,
    bool openMoves = false,
    bool openChat = false,
    LessonInvitation? lessonInvitation,
  }) {
    if (_currentPath != '/play') {
      _navKey.currentState?.pushReplacementNamed(
        '/play',
        arguments: openAuth ? {'openAuth': true} : null,
      );
      if (mounted) {
        setState(() {
          _currentPath = '/play';
        });
      }
    } else if (openAuth) {
      final st = _playState;
      st?.openAuthPanel?.call();
    }

    _runWhenPlayReady(() {
      final st = _playState;
      if (lessonInvitation != null) {
        if (lessonInvitation.isVideo) {
          st?.acceptVideoInvitation?.call(lessonInvitation);
        } else {
          st?.openLearningAsStudent?.call(
            lessonInvitation.lessonId,
            lessonInvitation.teacherId,
            lessonInvitation.teacherName,
          );
        }
      } else if (openLearningTeacher) {
        st?.openLearningAsTeacherFromMenu?.call();
      } else if (openLearningStudent) {
        st?.openLearningAsStudentFromMenu?.call();
      } else if (openLearning) {
        st?.openLearningPanel?.call();
      } else if (openPuzzles) {
        st?.openPuzzlesPanel?.call();
      } else if (openLobby) {
        st?.openLobbyPanel?.call();
      } else if (openGameSettings) {
        st?.openMobileGamePanel?.call();
      } else if (openMoves) {
        st?.openMobileRightPanel?.call();
      } else if (openChat) {
        st?.openMobileChatPanel?.call();
      } else if (boardOnly) {
        st?.openBoardOnly?.call();
      }
    });
  }

  Future<_AutoSearchMode?> _pickCustomSearchMode() async {
    final minutesCtl = TextEditingController(text: '10');
    final incrementCtl = TextEditingController(text: '0');

    final result = await showDialog<_AutoSearchMode>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const MakeChessLocalizedText('Своя настройка'),
          content: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: minutesCtl,
                  keyboardType: TextInputType.number,
                  decoration: AppInputs.dark(labelText: MakeChessLocalization.phrase('Минуты')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: incrementCtl,
                  keyboardType: TextInputType.number,
                  decoration: AppInputs.dark(labelText: MakeChessLocalization.phrase('Добавление, сек')),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const MakeChessLocalizedText('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final minutes = int.tryParse(minutesCtl.text.trim()) ?? 10;
                final increment = int.tryParse(incrementCtl.text.trim()) ?? 0;
                final safeMinutes = minutes.clamp(1, 180).toInt();
                final safeIncrement = increment.clamp(0, 60).toInt();
                Navigator.of(dialogContext).pop(
                  _AutoSearchMode(
                    '$safeMinutes + $safeIncrement',
                    safeMinutes,
                    safeIncrement,
                    'Своя игра',
                  ),
                );
              },
              child: const MakeChessLocalizedText('Искать'),
            ),
          ],
        );
      },
    );

    minutesCtl.dispose();
    incrementCtl.dispose();
    return result;
  }

  Future<void> _openAutomaticSearchMenu() async {
    const modes = <_AutoSearchMode>[
      _AutoSearchMode('1 + 0', 1, 0, 'Пуля'),
      _AutoSearchMode('2 + 1', 2, 1, 'Пуля'),
      _AutoSearchMode('3 + 0', 3, 0, 'Блиц'),
      _AutoSearchMode('3 + 2', 3, 2, 'Блиц'),
      _AutoSearchMode('5 + 0', 5, 0, 'Блиц'),
      _AutoSearchMode('10 + 0', 10, 0, 'Рапид'),
      _AutoSearchMode('10 + 5', 10, 5, 'Рапид'),
      _AutoSearchMode('15 + 10', 15, 10, 'Классика'),
    ];

    var lichessEnabled = false;
    var selected = await showModalBottomSheet<_AutoSearchMode>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        return StatefulBuilder(
            builder: (sheetContext, setSheetState) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: MakeChessLocalizedText(
                              'Автоматический поиск',
                              style: AppTextStyles.sectionTitle,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon:
                                const Icon(Icons.close, color: AppColors.text),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: AppDecorations.neoButton(),
                        child: SwitchListTile(
                          title: const Text('+ Lichess',
                              style: AppTextStyles.button),
                          subtitle: const MakeChessLocalizedText(
                            'Добавить поиск соперника на Lichess',
                            style: AppTextStyles.caption,
                          ),
                          secondary:
                              const Icon(Icons.public, color: AppColors.accent),
                          value: lichessEnabled,
                          onChanged: (value) =>
                              setSheetState(() => lichessEnabled = value),
                        ),
                      ),
                      const SizedBox(height: 12),
                      MakeChessLocalizedText(
                        'Выберите контроль времени',
                        style: AppTextStyles.bodyDim,
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: modes.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemBuilder: (_, index) {
                          final mode = modes[index];
                          return InkWell(
                            onTap: () => Navigator.of(sheetContext).pop(mode),
                            borderRadius: AppRadius.r12,
                            child: Container(
                              decoration: AppDecorations.neoButton(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.timer,
                                      color: AppColors.text),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(mode.label,
                                            style: AppTextStyles.button),
                                        Text(mode.category,
                                            style: AppTextStyles.caption),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(sheetContext).pop(
                          const _AutoSearchMode(
                              'custom', 0, 0, 'Своя настройка'),
                        ),
                        icon: const Icon(Icons.tune),
                        label: const MakeChessLocalizedText('Своя настройка'),
                      ),
                    ],
                  ),
                ));
      },
    );

    if (!mounted || selected == null) return;
    if (selected.label == 'custom') {
      selected = await _pickCustomSearchMode();
      if (!mounted || selected == null) return;
    }

    if (lichessEnabled) {
      LichessConnection link;
      try {
        link = await LichessService.instance.status();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось проверить Lichess: $error')),
        );
        return;
      }
      if (!link.connected) {
        if (!mounted) return;
        final connect = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const MakeChessLocalizedText('Подключите Lichess'),
            content: const MakeChessLocalizedText(
              'MakeChess автоматически откроет официальный Lichess. '
              'Войдите там и разрешите доступ, после чего Lichess сам вернёт вас сюда.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const MakeChessLocalizedText('Отмена'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                  navigateToUrl('https://lichess.org/signup');
                },
                child: const MakeChessLocalizedText('Регистрация'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const MakeChessLocalizedText('Подключить'),
              ),
            ],
          ),
        );
        if (connect == true) {
          await LichessService.instance.connect();
        }
        return;
      }
    }

    final activeMode = selected;
    if (lichessEnabled && activeMode.minutes < 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: MakeChessLocalizedText(
            'Lichess Board API разрешает автоматический поиск только для рапида и классики. '
            'Для блица и пули позднее добавим прямые вызовы игроков.',
          ),
        ),
      );
      return;
    }
    if (lichessEnabled) {
      unawaited(
        LichessSessionController.instance.startSearch(
          minutes: activeMode.minutes,
          increment: activeMode.increment,
        ),
      );
    }
    _openPlayScreen(boardOnly: true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    var searchDialogOpen = true;
    void onLichessSearchChanged() {
      final controller = LichessSessionController.instance;
      if (searchDialogOpen &&
          (controller.snapshot != null || controller.error != null) &&
          mounted) {
        searchDialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (lichessEnabled) {
      LichessSessionController.instance.addListener(onLichessSearchChanged);
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const MakeChessLocalizedText('Поиск соперника…'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                '${activeMode.label} · ${activeMode.category}',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 8),
              Text(
                lichessEnabled
                    ? 'Ищем соперника также на Lichess. Анализ и подсказки отключены.'
                    : 'Подбор по этому режиму будет подключён следующим шагом.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyDim,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (lichessEnabled) {
                  unawaited(LichessSessionController.instance.stop());
                }
                searchDialogOpen = false;
                Navigator.of(dialogContext).pop();
              },
              child: const MakeChessLocalizedText('Отменить поиск'),
            ),
          ],
        );
      },
    );
    searchDialogOpen = false;
    if (lichessEnabled) {
      LichessSessionController.instance.removeListener(onLichessSearchChanged);
      final controller = LichessSessionController.instance;
      if (controller.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Поиск Lichess остановлен: ${controller.error}')),
        );
      }
      if (controller.snapshot == null && controller.searching) {
        await controller.stop();
      }
    }
  }

  Future<void> _startCallFromTopBar({required bool audioOnly}) async {
    final myId = (Supabase.instance.client.auth.currentUser?.id ?? '').trim();
    if (myId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: MakeChessLocalizedText('Для звонка войдите в зарегистрированный аккаунт'),
        ),
      );
      return;
    }

    if (!audioOnly) {
      final st = _playState;
      try {
        final handled = await st?.startSelectedStudentsVideo?.call();
        if (handled == true) return;
      } catch (error) {
        debugPrint('[CLASSROOM VIDEO] $error');
      }
    }

    String? toName = RoomSelection.instance.room;

    final users = LobbyStore.instance.users.value;
    final me = users.firstWhere(
      (u) => u.isMe || u.id == myId,
      orElse: () => LobbyUser(id: myId, username: 'player'),
    );

    if (toName == null || toName.trim().isEmpty) {
      final others = users.where((u) => !(u.isMe || u.id == myId)).toList();
      if (others.isNotEmpty) {
        toName = others.first.username;
        RoomSelection.instance.setRoom(toName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Room ID: $toName выбран автоматически')),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: MakeChessLocalizedText('Нет доступных игроков в контактах')),
        );
        return;
      }
    }

    final target = users.firstWhere(
      (u) => u.username.trim().toLowerCase() == toName!.trim().toLowerCase(),
      orElse: () => LobbyUser(id: '', username: toName!),
    );

    if (target.id.trim().isEmpty || target.id == myId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: MakeChessLocalizedText('Выберите другого зарегистрированного игрока'),
        ),
      );
      return;
    }

    try {
      await CallCoordinator.instance
          .startOutgoing(me, target, audioOnly: audioOnly);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось начать звонок: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
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
            return const ColoredBox(color: Color(0xFFF3EAF7));
          },
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          extendBodyBehindAppBar: true,
          appBar: CommonTopBar(
            onTitleTap: _openPricingModal,
            onPlayHere: () => _openPlayScreen(boardOnly: true),
            onAutomaticSearch: _openAutomaticSearchMenu,
            onSearchFromList: () => _openPlayScreen(openLobby: true),
            onLearn: () => _openPlayScreen(openLearning: true),
            onTeacherAvatar: _openTeacherAvatar,
            onLearnAsTeacher: _openTeacherAccess,
            onLearnAsStudent: () => _openPlayScreen(openLearningStudent: true),
            onSchool: () => _openPlayScreen(openLearning: true),
            onPuzzles: () => _openPlayScreen(openPuzzles: true),
            onOpenLobby: () => _openPlayScreen(openLobby: true),
            onOpenGameSettings: () => _openPlayScreen(openGameSettings: true),
            onOpenMoves: () => _openPlayScreen(openMoves: true),
            onOpenChat: () => _openPlayScreen(openChat: true),
            onTeams: () => _go('/teams'),
            onTournaments: _openTournamentsFromTopBar,
            onWatch: () => _go('/watch'),
            onCommunity: () => _go('/community'),
            onVoiceCall: () => _startCallFromTopBar(audioOnly: true),
            onVideoCall: () => _startCallFromTopBar(audioOnly: false),
            onHangup: _endCallFromTopBar,
            hasIncomingCall: _incoming != null,
            incomingFrom: _incoming?.fromName ?? '',
            onAcceptCall: () async {
              final inc = _incoming;
              if (inc == null) return;
              await CallCoordinator.instance.acceptIncoming(inc);
              setState(() => _incoming = null);
            },
            onDeclineCall: () => setState(() => _incoming = null),
            showScale: true,
            scalePercent: _scalePercent,
            onScaleMinus: _scaleMinus,
            onScalePlus: _scalePlus,
            onScaleReset: _scaleReset,
            onLoginTap: () => _openPlayScreen(openAuth: true),
            onBackgroundTheme: () {
              _openPlayScreen();
              _runWhenPlayReady(() {
                final st = _playKey.currentState as dynamic;
                st?.openPickBackground?.call();
              });
            },
            onBoardTheme: _openBoardThemeDialog,
            onGptSettings: () {
              _openPlayScreen();
              _runWhenPlayReady(() {
                final st = _playKey.currentState as dynamic;
                st?.openGptSettings?.call();
              });
            },
            onSiteSettings: () => showSiteSettingsDialog(
              context,
              boardTheme: boardTheme,
            ),
            onMessages: _openGeneralMessages,
            unreadMessages: _unreadMessages,
            onPersonalCabinet: _openPersonalCabinet,
            currentLanguage: _currentLanguage,
            onLanguageChanged: (lang) {
              MakeChessLocalizationController.setLanguage(lang);
              setState(() {
                _currentLanguage = MakeChessLocalizationController.currentCode;
              });
            },
          ),
          body: Navigator(
            key: _navKey,
            initialRoute: '/play',
            onGenerateRoute: (settings) {
              _currentPath = settings.name ?? '/play';

              late final Widget page;
              switch (_currentPath) {
                case '/play':
                  page = widget.playBuilder.call(_playKey, boardTheme);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    if (!_startModalShown) {
                      _startModalShown = true;
                      // На телефоне сайт открывается сразу на доске.
                      if (MediaQuery.sizeOf(context).width >= 760) {
                        _openPricingModal();
                      }
                    }
                    _refreshScaleFromGame();
                  });
                  break;

                case '/learn':
                  page = const _StubScreen(title: 'Учиться');
                  break;

                case '/puzzles':
                  page = const _PuzzlesScreen();
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
                  page = widget.playBuilder.call(_playKey, boardTheme);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _refreshScaleFromGame();
                  });
                  break;
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

class _AutoSearchMode {
  const _AutoSearchMode(
    this.label,
    this.minutes,
    this.increment,
    this.category,
  );

  final String label;
  final int minutes;
  final int increment;
  final String category;
}

class _PuzzlesScreen extends StatelessWidget {
  const _PuzzlesScreen();

  static const List<_PuzzleType> _types = [
    _PuzzleType('На зевки', Icons.visibility_off),
    _PuzzleType('Мат в 1 ход', Icons.looks_one),
    _PuzzleType('Мат в 2 хода', Icons.looks_two),
    _PuzzleType('Мат в 3 хода', Icons.looks_3),
    _PuzzleType('Мат в 4 хода', Icons.looks_4),
    _PuzzleType('Мат в 5 ходов', Icons.looks_5),
    _PuzzleType('Найти лучший ход', Icons.flash_on),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 90, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MakeChessLocalizedText(
                'Задачи',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _types.map((t) {
                  return SizedBox(
                    width: 260,
                    height: 90,
                    child: FilledButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${t.title}: скоро')),
                        );
                      },
                      icon: Icon(t.icon),
                      label: Text(
                        t.title,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PuzzleType {
  const _PuzzleType(this.title, this.icon);

  final String title;
  final IconData icon;
}

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
