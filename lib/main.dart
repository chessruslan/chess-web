// main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'platform/web_compat.dart';
import 'dart:ui' show FontFeature;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'utils.dart'; // sanitizeFenEp, stripEpField
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:chess/chess.dart' as ch;
import 'services/gpt_explain_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart' as rt;
import 'ui/common_top_bar.dart';
import 'package:uuid/uuid.dart';
import 'secrets.dart'; // supabaseUrl / supabaseAnonKey
import 'ui/app_shell.dart';
import 'package:flutter/material.dart';
import 'ui/app_shell.dart';
import 'main.dart' show MyHomePage; // или твой путь к MyHomePage
import 'package:file_picker/file_picker.dart';
// ---------- Одноразовое удаление старого Service Worker и кэшей ----------
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'secrets.dart'; // где лежат supabaseUrl/supabaseAnonKey
import 'ui/app_shell.dart';
import 'landing_page.dart'; // если нужно MyHomePage оттуда
import 'services/lobby_store.dart'; // путь от lib/
import 'package:my_new_chess_app/main.dart' show bgController;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'services/bg_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'theme/app_theme.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'stockfish_service.dart' as sf; // lib/stockfish_service.dart
// === ФОН: контроллер с хранением в SharedPreferences ===
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_new_chess_app/stockfish_service.dart' as sf;
import 'stockfish_service.dart' as sf;
import 'dart:convert'; // для JsonEncoder в модалке
import 'dart:math' as math; // если используется math.exp
import 'features/call/room_selection.dart'; // путь подстрой, если другой

import 'package:supabase_flutter/supabase_flutter.dart';
import 'classroom/school_dialog_new.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'classroom/school_dialog_new.dart';
import 'classroom/classroom_signaling.dart' as cls;
import 'classroom/classroom_call_service.dart';

import 'ui/start_modal.dart';

import 'ui/play_layout.dart';
import 'ui/app_behavior.dart';
import 'app_root.dart';
import 'services/lobby_service.dart';
import 'services/room_service.dart';
import 'ui/panels/move_list_panel.dart';
import 'ui/panels/lobby_panel.dart';
import 'ui/panels/puzzle_types_panel.dart';
import 'ui/panels/learn_panel.dart';
import 'ui/panels/puzzle_task.dart';
import 'ui/panels/puzzle_settings_dialog.dart';
import 'ui/panels/puzzle_file_saver.dart';
import 'ui/panels/game_mode_panel.dart';
import 'ui/panels/right_sidebar_panel.dart';
import 'ui/panels/room_chat_panel.dart';
import 'ui/panels/auth_widgets.dart';
import 'ui/app_style.dart';
import 'profile/personal_cabinet_store.dart';

import '../ui/board_theme_controller.dart';
import 'widgets/eval_bar.dart';

class BackgroundView extends StatelessWidget {
  const BackgroundView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: BgController.instance,
      builder: (context, _) {
        final data = BgController.instance.bgBytes;
        if (data != null) {
          return IgnorePointer(
            ignoring: true,
            child: Image.memory(
              data,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          );
        }
        // запасной фон, как сейчас
        return const ColoredBox(color: Color(0xFFF3EAF7));
      },
    );
  }
}

// Глобально убираем bounce/overscroll и даём нормальный drag мышью/тачем.

void main() async {
  final boardTheme = BoardThemeController();
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Инициализация Supabase (как было у тебя)
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // 2) Загрузка сохранённого фона (без отрисовки)
  await BgController.instance.load();

  // 3) Старт приложения
  runApp(
    AppRoot(
      playBuilder: (key, boardTheme) => MyHomePage(
        key: key,
        title: 'Chess Online',
        boardTheme: boardTheme,
      ),
    ),
  );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.boardTheme,
  });

  final String title;
  final BoardThemeController boardTheme;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

// ======================= LOBBY (broadcast) =======================
class LobbyService {
  LobbyService(
    this.supa, {
    required this.username,
    required this.userId,
    required this.myRating,
  });
  final SupabaseClient supa;
  final String username;
  final String userId;
  int myRating;

  void sendPresenceNow() {
    final ch = _chan;
    if (ch != null) _sendPing(ch);
  }

  // === REPLACE: LobbyService.updateMyRating ===
  void updateMyRating(int r) {
    myRating = r;

    // 1) мгновенно обновим себя в локальном списке
    _touch(userId, username, myRating);

    // 2) сразу дернём UI (на случай, если канал ещё не готов)
    onOnlineChanged?.call();

    // 3) разошлём снапшот + пинг
    final ch = _chan;
    if (ch != null) {
      _sendHello(ch); // снапшот (hello)
      _sendPing(ch); // пульс (ping)
    }
  }

  rt.RealtimeChannel? _chan;

  void Function()? onOnlineChanged;
  void Function(String roomId, String fromId, String fromName, String color,
      int m, int inc, bool rated, String inviteKind)? onInvite;

  void Function(String roomId, String fromId, String fromName, String color)?
      onAccept;

  /// Точечная команда интерфейса конкретному пользователю.
  /// Использует тот же lobby-канал, по которому уже надёжно приходят
  /// приглашения в учебную партию.
  void Function(Map<String, dynamic> event)? onLearningUiControl;

  final Map<String, _Peer> _peers = {};
  List<Map<String, String>> get online => _peers.values
      .map((p) => {
            'id': p.id,
            'username': p.name,
            'rating': '${p.rating}',
          })
      .toList(growable: false);

  static const Duration _beat = Duration(seconds: 12);
  Timer? _heartbeat;

  Map<String, dynamic> _parsePayload(dynamic raw) {
    Map<String, dynamic> unwrap(dynamic v) {
      if (v is Map) {
        final m = Map<String, dynamic>.from(v);
        while (m['payload'] is Map) {
          final inner = Map<String, dynamic>.from(m['payload']);
          m
            ..remove('payload')
            ..addAll(inner);
        }
        return m;
      }
      return <String, dynamic>{};
    }

    return unwrap(raw);
  }

  void _touch(String id, String name, int rating) {
    if (id.isEmpty) return;
    final n = (name.isEmpty ? 'player' : name);
    final p = _peers[id];
    if (p == null) {
      _peers[id] = _Peer(
        id: id,
        name: n,
        rating: rating,
        lastSeen: DateTime.now(),
      );
    } else {
      p.name = n;
      p.rating = rating;
      p.lastSeen = DateTime.now();
    }
    onOnlineChanged?.call();
  }

  Future<void> connect() async {
    if (_chan != null) return;

    final chan =
        supa.channel('lobby', opts: const rt.RealtimeChannelConfig(self: true));

    // Кто-то спрашивает "кто онлайн?" — отвечаем своим hello
    chan.onBroadcast(
      event: 'whois',
      callback: (payload, [ref]) => _sendHello(chan),
    );

    chan.onBroadcast(
      event: 'hello',
      callback: (payload, [ref]) {
        final p = _parsePayload(payload);
        _touch(
          '${p['id'] ?? ''}',
          '${p['name'] ?? 'player'}',
          (p['rating'] is num)
              ? (p['rating'] as num).toInt()
              : int.tryParse('${p['rating'] ?? '1200'}') ?? 1200,
        );
      },
    );

    // Пульс/присутствие игрока
    chan.onBroadcast(
      event: 'ping',
      callback: (payload, [ref]) {
        final p = _parsePayload(payload);
        _touch(
          '${p['id'] ?? ''}',
          '${p['name'] ?? 'player'}',
          (p['rating'] is num)
              ? (p['rating'] as num).toInt()
              : int.tryParse('${p['rating'] ?? '1200'}') ?? 1200,
        );
      },
    );

    // Приглашение в игру
    chan.onBroadcast(
      event: 'invite',
      callback: (payload, [ref]) {
        final p = _parsePayload(payload);

        final String to =
            (p['to'] is String) ? (p['to'] as String) : '${p['to'] ?? ''}';

        if (to.isEmpty) {
          debugPrint('[INVITE RECV] Пропуск: to пустой. payload=$p');
          return;
        }

        debugPrint('[INVITE RECV] to=$to, me=$userId, payload=$p');

        if (to == userId) {
          onInvite?.call(
            '${p['roomId'] ?? ''}',
            '${p['from'] ?? ''}',
            '${p['fromName'] ?? 'player'}',
            '${p['color'] ?? 'white'}',
            (p['m'] as num?)?.toInt() ?? 5,
            (p['inc'] as num?)?.toInt() ?? 3,
            (p['rated'] is bool) ? (p['rated'] as bool) : true,
            '${p['kind'] ?? 'play'}',
          );
        }
      },
    );

    // Принятие приглашения
    chan.onBroadcast(
      event: 'accept',
      callback: (payload, [ref]) {
        final p = _parsePayload(payload);
        if ('${p['to']}' == userId) {
          onAccept?.call(
            '${p['roomId'] ?? ''}',
            '${p['from'] ?? ''}',
            '${p['fromName'] ?? 'player'}',
            '${p['color'] ?? 'white'}',
          );
        }
      },
    );

    // Удалённое управление интерфейсом ученика.
    // Команда принимается только тем аккаунтом, чей ID указан в `to`.
    chan.onBroadcast(
      event: 'learning_ui_control',
      callback: (payload, [ref]) {
        final p = _parsePayload(payload);
        if ('${p['to'] ?? ''}' != userId) return;
        onLearningUiControl?.call(p);
      },
    );

    // Игрок вышел
    chan.onBroadcast(
      event: 'bye',
      callback: (payload, [ref]) {
        final p = _parsePayload(payload);
        final id = '${p['id'] ?? ''}';
        if (id.isEmpty) return;
        _peers.remove(id);
        onOnlineChanged?.call();
      },
    );

    await chan.subscribe();

    // Холодный старт: объявим себя и спросим остальных
    await Future.delayed(const Duration(milliseconds: 120));
    _sendHello(chan);
    _sendPing(chan);
    chan.sendBroadcastMessage(event: 'whois', payload: {'from': userId});

    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_beat, (_) => _sendPing(chan));

    _touch(userId, username, myRating);

    _chan = chan;
  }

  void _sendHello(rt.RealtimeChannel ch) => ch.sendBroadcastMessage(
        event: 'hello',
        payload: {'id': userId, 'name': username, 'rating': myRating},
      );

  void _sendPing(rt.RealtimeChannel ch) => ch.sendBroadcastMessage(
        event: 'ping',
        payload: {'id': userId, 'name': username, 'rating': myRating},
      );

  Future<void> disconnect() async {
    _heartbeat?.cancel();
    final ch = _chan;
    if (ch != null) {
      await ch.sendBroadcastMessage(event: 'bye', payload: {'id': userId});
      await ch.unsubscribe();
    }
    _chan = null;
  }

  Future<void> sendInvite({
    required String toUserId,
    required String toName,
    required String roomId,
    required String color, // 'white' | 'black'
    required int minutes,
    required int increment,
    required bool rated,
    String kind = 'play',
  }) async {
    _chan?.sendBroadcastMessage(event: 'invite', payload: {
      'roomId': roomId,
      'from': userId,
      'fromName': username,
      'to': toUserId,
      'toName': toName,
      'color': color,
      'm': minutes,
      'inc': increment,
      'rated': rated,
      'kind': kind,
    });
  }

  Future<void> sendAccept({
    required String toUserId,
    required String toName,
    required String roomId,
    required String color, // цвет принимающего
  }) async {
    _chan?.sendBroadcastMessage(event: 'accept', payload: {
      'roomId': roomId,
      'from': userId,
      'fromName': username,
      'to': toUserId,
      'toName': toName,
      'color': color,
    });
  }

  Future<void> sendLearningUiControl({
    required String toUserId,
    required String command,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    final channel = _chan;
    if (channel == null) {
      throw StateError('Лобби не подключено');
    }

    await channel.sendBroadcastMessage(
      event: 'learning_ui_control',
      payload: <String, dynamic>{
        'from': userId,
        'to': toUserId,
        'command': command,
        ...data,
        'ts': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }
}

class _Peer {
  _Peer({
    required this.id,
    required this.name,
    required this.rating,
    required this.lastSeen,
  });
  final String id;
  String name;
  int rating;
  DateTime lastSeen;
}

// ======================= ROOM (moves/chat/control) =======================
class RoomService {
  RoomService(this.supa, {required this.roomId});
  final SupabaseClient supa;
  final String roomId;

  Future<void> sendChat({
    required String text,
    required String fromName,
    required String from,
  }) async {
    await _ready.future;
    _chan?.sendBroadcastMessage(event: 'chat', payload: {
      'roomId': roomId,
      'type': 'chat',
      'msg': text,
      'fromName': fromName,
      'from': from,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void Function(Map<String, dynamic> msg)? onChat;

  rt.RealtimeChannel? _chan;
  final Completer<void> _ready = Completer<void>();

  // callbacks
  void Function(Map<String, dynamic> move)? onMove;
  void Function(Map<String, dynamic> evt)?
      onCtrl; // draw/resign/rematch/clock/chat/tc

  // +++ НОВОЕ: колбэки на отдельные события
  void Function(Map<String, dynamic> evt)? onDrawOffer; // {from, roomId}
  void Function(Map<String, dynamic> evt)?
      onDrawAnswer; // {from, roomId, accepted}
  void Function(Map<String, dynamic> evt)? onResign; // {from, roomId}

  // Служебные события школьной партии вынесены в отдельные события
  // Realtime. Так они не смешиваются с обычным игровым управлением.
  void Function(Map<String, dynamic> evt)? onLearningStudentEvaluation;
  void Function(Map<String, dynamic> evt)? onLearningReset;

  Map<String, dynamic> _parsePayload(dynamic raw) {
    Map<String, dynamic> unwrap(dynamic v) {
      if (v is Map) {
        final m = Map<String, dynamic>.from(v);
        while (m['payload'] is Map) {
          final inner = Map<String, dynamic>.from(m['payload']);
          m
            ..remove('payload')
            ..addAll(inner);
        }
        return m;
      }
      return <String, dynamic>{};
    }

    return unwrap(raw);
  }

  Future<void> connect() async {
    if (_chan != null) return;
    _chan = supa.channel('room:$roomId',
        opts: const rt.RealtimeChannelConfig(self: true));

    _chan!.onBroadcast(
        event: 'move',
        callback: (payload, [ref]) {
          onMove?.call(_parsePayload(payload));
        });

    _chan!.onBroadcast(
        event: 'ctrl',
        callback: (payload, [ref]) {
          onCtrl?.call(_parsePayload(payload));
        });

    _chan!.onBroadcast(
      event: 'learning_student_eval',
      callback: (payload, [ref]) {
        onLearningStudentEvaluation?.call(_parsePayload(payload));
      },
    );

    _chan!.onBroadcast(
      event: 'learning_reset',
      callback: (payload, [ref]) {
        onLearningReset?.call(_parsePayload(payload));
      },
    );

    _chan!.onBroadcast(
      event: 'draw_offer',
      callback: (payload, [ref]) {
        onDrawOffer?.call(_parsePayload(payload));
      },
    );

    _chan!.onBroadcast(
      event: 'draw_answer',
      callback: (payload, [ref]) {
        onDrawAnswer?.call(_parsePayload(payload));
      },
    );

    _chan!.onBroadcast(
      event: 'resign',
      callback: (payload, [ref]) {
        onResign?.call(_parsePayload(payload));
      },
    );

    _chan!.onBroadcast(
      event: 'chat',
      callback: (payload, [ref]) {
        onChat?.call(_parsePayload(payload));
      },
    );

    await _chan!.subscribe();
    if (!_ready.isCompleted) _ready.complete();
  }

  Future<void> disconnect() async {
    await _chan?.unsubscribe();
    _chan = null;
    if (!_ready.isCompleted) _ready.completeError(StateError('disconnected'));
  }

  Future<void> sendMove({
    required String from,
    required String to,
    String? promotion,
  }) async {
    await _ready.future;
    _chan?.sendBroadcastMessage(event: 'move', payload: {
      'roomId': roomId,
      'from': from,
      'to': to,
      if (promotion != null) 'promotion': promotion,
      'ts': DateTime.now().toIso8601String(),
    });
  }

  Future<void> sendCtrl(Map<String, dynamic> data) async {
    await _ready.future;
    final payload = Map<String, dynamic>.from(data);
    payload['roomId'] = roomId;
    final channel = _chan;
    if (channel == null) {
      throw StateError('Комната $roomId отключена');
    }
    await channel.sendBroadcastMessage(event: 'ctrl', payload: payload);
  }

  /// Служебные команды учебной партии идут по тому же событию `move`,
  /// по которому уже надёжно передаются реальные ходы между учителем
  /// и учеником. Поле `kind` позволяет не путать команду с шахматным ходом.
  Future<void> sendLearningControl(Map<String, dynamic> data) async {
    await _ready.future;
    final payload = Map<String, dynamic>.from(data);
    payload['roomId'] = roomId;
    payload['kind'] = 'learning_ctrl';
    final channel = _chan;
    if (channel == null) {
      throw StateError('Комната $roomId отключена');
    }
    await channel.sendBroadcastMessage(event: 'move', payload: payload);
  }

  Future<void> sendLearningStudentEvaluation({
    required bool enabled,
    required String clientId,
    required String studentId,
  }) async {
    await _ready.future;
    final channel = _chan;
    if (channel == null) return;
    await channel.sendBroadcastMessage(
      event: 'learning_student_eval',
      payload: <String, dynamic>{
        'roomId': roomId,
        'enabled': enabled,
        'studentId': studentId,
        'clientId': clientId,
        'ts': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> sendLearningReset({
    required String fen,
    required String teacherColor,
    required int whiteMs,
    required int blackMs,
    required String clientId,
    required String resetBy,
  }) async {
    await _ready.future;
    final channel = _chan;
    if (channel == null) return;
    await channel.sendBroadcastMessage(
      event: 'learning_reset',
      payload: <String, dynamic>{
        'roomId': roomId,
        'fen': fen,
        'teacherColor': teacherColor,
        'w': whiteMs,
        'b': blackMs,
        'clientId': clientId,
        'resetBy': resetBy,
        'ts': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> sendDrawOffer({
    required String fromUserId,
    required String fromName,
  }) async {
    await _ready.future;
    _chan?.sendBroadcastMessage(event: 'draw_offer', payload: {
      'roomId': roomId,
      'from': fromUserId,
      'fromName': fromName,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> sendDrawAnswer({
    required String fromUserId,
    required String fromName,
    required bool accepted,
  }) async {
    await _ready.future;
    _chan?.sendBroadcastMessage(event: 'draw_answer', payload: {
      'roomId': roomId,
      'from': fromUserId,
      'fromName': fromName,
      'accepted': accepted,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> sendResign({
    required String fromUserId,
    required String fromName,
  }) async {
    await _ready.future;
    _chan?.sendBroadcastMessage(event: 'resign', payload: {
      'roomId': roomId,
      'from': fromUserId,
      'fromName': fromName,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }
}

// ================== LEARNING: INDEPENDENT GAME SESSIONS ==================
class _PendingLearningGameInvite {
  const _PendingLearningGameInvite({
    required this.student,
    required this.myColor,
    required this.minutes,
    required this.increment,
    required this.rated,
  });

  final LearningStudent student;
  final String myColor;
  final int minutes;
  final int increment;
  final bool rated;
}

class _LearningGameSession {
  _LearningGameSession({
    required this.student,
    required this.roomId,
    required this.myColor,
    required this.minutes,
    required this.increment,
    required this.rated,
    required this.room,
  })  : game = ch.Chess(),
        whiteMs = minutes * 60 * 1000,
        blackMs = minutes * 60 * 1000 {
    fens.add(game.fen);
  }

  final LearningStudent student;
  final String roomId;
  String myColor;
  final int minutes;
  final int increment;
  final bool rated;
  final RoomService room;
  final ch.Chess game;

  final List<String> sanMoves = <String>[];
  final List<String> fens = <String>[];
  final ScrollController movesScroll = ScrollController();
  int plyIndex = 0;

  String? selectedSquare;
  final Set<String> legalTargets = <String>{};
  final Set<String> captureTargets = <String>{};

  String? result;
  String? resultReason;
  bool terminated = false;

  // Оценка Stockfish хранится отдельно для каждой ученической партии.
  // У учителя шкала видна всегда, а ученику её видимость включает учитель.
  bool studentEvaluationEnabled = false;
  double engineEval = 0.0;
  bool loadingEval = false;
  int evalRequestEpoch = 0;
  String? lastEvalFen;

  int whiteMs;
  int blackMs;
  bool clocksStarted = false;
  DateTime? lastTickAt;
  Timer? tick;

  bool get isFlipped => myColor.toLowerCase() == 'black';

  void dispose() {
    tick?.cancel();
    tick = null;
    movesScroll.dispose();
    unawaited(room.disconnect());
  }
}

// ========================= STATE / UI  1/2    =========================
class _MyHomePageState extends State<MyHomePage> {
  Widget _buildLeftColumnPlaceholder() {
    return const SizedBox.shrink();
  }

  Widget _buildCenterColumnPlaceholder() {
    return const SizedBox.shrink();
  }

  Widget _buildRightColumnPlaceholder() {
    return const SizedBox.shrink();
  }
  // ---- chess core ----

  final bgController = BgController.instance;

  static const double _leftColWidth = 360; // ширина левой колонки в пикселях

  final TextEditingController _fenController = TextEditingController(
    text: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  );

// >>> GPT: дополнительный вопрос пользователя
  final TextEditingController _gptPromptCtl = TextEditingController();
  String? _lastGptPrompt;

  // >>> GPT: дополнительный вопрос пользователя

  // === Тема фона ===

// === ТЕМА ФОНА (кросс-платформенно) ===
  Uint8List? _backgroundBytes;

// Подписка на обновления фона
  void _onBgChanged() {
    if (!mounted) return;
    setState(() {
      _backgroundBytes = bgController.bgBytes;
    });
  }

  ImageProvider? get _backgroundProvider =>
      (_backgroundBytes != null) ? MemoryImage(_backgroundBytes!) : null;

  int _engineDuelDelayMs = 2000; // по умолчанию 2 сек
  late final TextEditingController _duelDelayCtl;

  Future<Map<String, int>> _loadProfileStats(String uid) async {
    final supa = Supabase.instance.client;
    final row = await supa
        .from('profiles')
        .select('rating, games_played')
        .eq('id', uid)
        .maybeSingle();

    final rating = (row?['rating'] as int?) ?? 1200;
    final games = (row?['games_played'] as int?) ?? 0;
    return {'rating': rating, 'games_played': games};
  }

  // уникальный ID вкладки/клиента (защита от эха)
  final String _clientId = const Uuid().v4();

  final ch.Chess game = ch.Chess();
  String? _result;

  bool _showPuzzlePanel = false;
  bool _showLearningPanel = false;

  // На телефоне при первом открытии показываем только доску.
  // Остальные зоны открываются из меню с тремя полосками.
  String _mobilePanel = 'none';

  LearningPanelRole _learningRole = LearningPanelRole.none;
  bool _learningStudentEvaluationEnabled = false;
  PuzzleType _selectedPuzzleType = PuzzleType.blunders;

  String _puzzleDraftTitle = 'Новая задача';
  int _puzzleDraftNumber = 1;
  String? _puzzleDraftTypeTitle;
  String? _puzzleDraftStartFen;
  final List<List<String>> _puzzleDraftLines = [];
  final List<String> _puzzleCurrentLine = [];
  bool _puzzleRecordingLine = false;
  bool _puzzleDraftPublished = false;
  OverlayEntry? _puzzleSettingsOverlay;

  final List<PuzzleTask> _publishedPuzzleTasks = [];
  int _activePublishedPuzzleIndex = -1;
  bool _loadingPublishedPuzzleTasks = false;

  // Контур тренера: эталонные стрелки/кружки из окна «Настройка».
  String? _activeAnalysisArrowKey;
  String? _pendingAnalysisArrowFrom;
  Offset? _analysisPointerPosition;
  bool _showPuzzleAnswerArrows = false;
  final List<_PuzzleBoardArrow> _puzzleBoardArrows = [];
  final Set<String> _hiddenPuzzleAnalysisKinds = <String>{};
  String _teacherAnalysisSide = 'white'; // white | black

  // Контур ученика: ответ в окне «Задачи».
  // Эти кнопки и элементы НЕ связаны напрямую с окном «Настройка».
  String? _studentAnalysisArrowKey;
  String? _studentPendingAnalysisArrowFrom;
  Offset? _studentAnalysisPointerPosition;
  bool _studentShowPuzzleAnswer = false;
  final List<_PuzzleBoardArrow> _studentBoardArrows = [];
  final Set<String> _studentHiddenAnalysisKinds = <String>{};
  String _studentAnalysisSide = 'white'; // white | black

  // Полностью независимый контур панели «Учиться».
  // Он не использует состояние панели «Задачи», поэтому обе панели
  // можно дальше развивать независимо друг от друга.
  String? _learningAnalysisArrowKey;
  String? _learningPendingAnalysisArrowFrom;
  Offset? _learningAnalysisPointerPosition;
  bool _learningDrawingEnabled = false;
  bool _learningShowAnswer = false;
  final List<_PuzzleBoardArrow> _learningBoardArrows = [];
  final Set<String> _learningHiddenAnalysisKinds = <String>{};
  String _learningAnalysisSide = 'white'; // white | black

  // Реальные ученики и состояние приглашения на урок.
  final List<LearningStudent> _learningStudents = <LearningStudent>[];
  String? _selectedLearningStudentId;
  final Set<String> _selectedVideoStudentIds = <String>{};

  // До восьми настоящих независимых партий учителя с учениками.
  final Map<String, _LearningGameSession> _learningGameSessions =
      <String, _LearningGameSession>{};
  final Map<String, _PendingLearningGameInvite> _pendingLearningGameInvites =
      <String, _PendingLearningGameInvite>{};
  bool _learningShowAllBoards = false;
  String? _learningFocusedStudentId;

  // Отдельное присутствие школы. Обычный игровой лобби-режим сюда не входит.
  rt.RealtimeChannel? _learningPresenceChannel;
  Timer? _learningPresenceHeartbeat;
  Timer? _learningPresenceCleanup;
  final Map<String, DateTime> _learningStudentLastSeen = <String, DateTime>{};

  String? _confirmedLearningStudentId;
  String? _learningInvitationStatus;
  String? _pendingLearningLessonId;
  String? _learningLessonId;
  String? _learningTeacherId;
  String? _learningTeacherName;
  StreamSubscription<cls.LessonInvitationResponse>? _lessonResponseSub;
  ClassroomCallService? _classroomVideoCall;
  String? _classroomVideoLessonId;
  String? _classroomVideoClassroomId;

  // Ходы ученика для решения текущей задачи.
  // Правая колонка уже показывает SAN-ходы, а для проверки сохраняем UCI-ходы
  // в том же формате, в котором учитель записывает ветки: e2e4, e7e8q и т.п.
  final List<String> _studentPuzzleMoveLine = [];
  bool _puzzleMoveChecked = false;
  bool? _puzzleMoveCorrect;
  int _shownSolutionLineIndex = 0;

  static const Set<String> _circleAnalysisKeys = {
    'weakness',
    'r2',
    'r4',
  };

  // Режим рисования стрелок включён ТОЛЬКО когда нажата одна из кнопок анализа.
  // Просто открытая панель задач НЕ включает рисование и НЕ подставляет красную угрозу.
  static const Set<String> _validAnalysisArrowKeys = {
    'threat',
    'pin',
    'xray',
    'weakness',
    'r1',
    'r2',
    'r3',
    'r4',
  };

  bool get _puzzleSettingsIsOpen => _puzzleSettingsOverlay != null;

  bool get _teacherPuzzleArrowDrawMode =>
      _activeAnalysisArrowKey != null &&
      _validAnalysisArrowKeys.contains(_activeAnalysisArrowKey);

  bool get _studentPuzzleArrowDrawMode =>
      _studentAnalysisArrowKey != null &&
      _validAnalysisArrowKeys.contains(_studentAnalysisArrowKey);

  bool get _learningArrowDrawMode =>
      _showLearningPanel &&
      _learningDrawingEnabled &&
      _learningAnalysisArrowKey != null &&
      _validAnalysisArrowKeys.contains(_learningAnalysisArrowKey);

  bool get _puzzleArrowDrawMode {
    if (_puzzleSettingsIsOpen) return _teacherPuzzleArrowDrawMode;
    if (_showLearningPanel) return _learningArrowDrawMode;
    return _studentPuzzleArrowDrawMode;
  }

  String get _effectivePuzzleArrowKey {
    if (_puzzleSettingsIsOpen) {
      return _activeAnalysisArrowKey ?? 'threat';
    }
    if (_showLearningPanel) {
      return _learningAnalysisArrowKey ?? 'threat';
    }
    return _studentAnalysisArrowKey ?? 'threat';
  }

  String? get _currentAnalysisPreviewFrom {
    if (_puzzleSettingsIsOpen) return _pendingAnalysisArrowFrom;
    if (_showLearningPanel) return _learningPendingAnalysisArrowFrom;
    return _studentPendingAnalysisArrowFrom;
  }

  Offset? get _currentAnalysisPreviewTo {
    if (_puzzleSettingsIsOpen) return _analysisPointerPosition;
    if (_showLearningPanel) return _learningAnalysisPointerPosition;
    return _studentAnalysisPointerPosition;
  }

  Map<String, Map<String, int>> get _analysisElementCounts {
    Map<String, int> emptyCounts() => <String, int>{
          'threat': 0,
          'pin': 0,
          'xray': 0,
          'weakness': 0,
          'r1': 0,
          'r2': 0,
          'r3': 0,
          'r4': 0,
        };

    final result = <String, Map<String, int>>{
      'white': emptyCounts(),
      'black': emptyCounts(),
    };

    for (final arrow in _puzzleBoardArrows) {
      final side = arrow.side == 'black' ? 'black' : 'white';
      final counts = result[side]!;
      if (counts.containsKey(arrow.kind)) {
        counts[arrow.kind] = counts[arrow.kind]! + 1;
      }
    }

    return result;
  }

  int get _analysisTotalElementCount {
    var total = 0;
    for (final sideCounts in _analysisElementCounts.values) {
      total += sideCounts.values.fold<int>(0, (a, b) => a + b);
    }
    return total;
  }

  List<PuzzleTask> get _visiblePublishedPuzzleTasks {
    final selectedTypeKey = _selectedPuzzleType.name;
    final selectedTypeTitle = _selectedPuzzleType.title;
    final tasks = _publishedPuzzleTasks
        .where((task) =>
            task.type == selectedTypeKey || task.typeTitle == selectedTypeTitle)
        .toList();

    tasks.sort((a, b) {
      final byNumber = a.number.compareTo(b.number);
      if (byNumber != 0) return byNumber;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return tasks;
  }

  void _refreshPuzzleSettingsOverlay() {
    _puzzleSettingsOverlay?.markNeedsBuild();
  }

  void _closePuzzleSettingsOverlay() {
    _puzzleSettingsOverlay?.remove();
    _puzzleSettingsOverlay = null;
  }

  String _puzzleTypeKeyFromTitle(String typeTitle) {
    switch (typeTitle) {
      case 'Задачи на зевки':
        return PuzzleType.blunders.name;
      case 'Мат':
        return PuzzleType.mate.name;
      case 'Найти лучший ход':
        return PuzzleType.bestMove.name;
      default:
        return _selectedPuzzleType.name;
    }
  }

  Map<String, List<PuzzleAnalysisArrow>> _buildPuzzleAnalysisArrows() {
    final result = <String, List<PuzzleAnalysisArrow>>{};
    for (final element in _puzzleBoardArrows) {
      final list =
          result.putIfAbsent(element.kind, () => <PuzzleAnalysisArrow>[]);
      list.add(
        PuzzleAnalysisArrow(
          id: '${element.side}_${element.kind}_${list.length + 1}_${DateTime.now().microsecondsSinceEpoch}',
          from: element.from,
          to: element.to,
          side: element.side,
        ),
      );
    }
    return result;
  }

  PuzzleTask _buildPuzzleDraft({
    required String title,
    required int number,
    required String typeTitle,
  }) {
    final cleanTitle = title.trim().isEmpty ? 'Новая задача' : title.trim();
    final cleanTypeTitle = typeTitle.trim().isEmpty
        ? (_selectedPuzzleType.title.isEmpty
            ? 'Задача'
            : _selectedPuzzleType.title)
        : typeTitle.trim();

    return PuzzleTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _puzzleTypeKeyFromTitle(cleanTypeTitle),
      typeTitle: cleanTypeTitle,
      title: cleanTitle,
      number: number < 1 ? 1 : number,
      startFen: _puzzleDraftStartFen ?? game.fen,
      solutionLines: _puzzleDraftLines
          .map((line) => PuzzleLine(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                moves: List<String>.from(line),
              ))
          .toList(),
      description: _selectedPuzzleType.description,
      analysisArrows: _buildPuzzleAnalysisArrows(),
    );
  }

  void _puzzleSetInitialPosition() {
    setState(() {
      _puzzleDraftStartFen = game.fen;
      _puzzleCurrentLine.clear();
      _puzzleRecordingLine = false;
      _puzzleDraftPublished = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Начальная позиция задачи записана')),
    );
  }

  void _puzzleStartRecordingLine() {
    final startFen = _puzzleDraftStartFen;
    if (startFen == null || startFen.trim().isEmpty) {
      _puzzleSetInitialPosition();
    }

    final fen = _puzzleDraftStartFen ?? game.fen;
    final ok = game.load(fen);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить начальную позицию')),
      );
      return;
    }

    setState(() {
      _fenController.text = game.fen;
      _sanMoves.clear();
      _fens
        ..clear()
        ..add(game.fen);
      _plyIndex = 0;
      _selectedSquare = null;
      _legalTargets.clear();
      _captureTargets.clear();
      _puzzleCurrentLine.clear();
      _puzzleRecordingLine = true;
      _puzzleDraftPublished = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Запись ветки началась. Делайте ходы на доске')),
    );
  }

  void _puzzleFinishRecordingLine() {
    if (_puzzleCurrentLine.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ветка пустая. Сначала сделайте ходы')),
      );
      return;
    }

    setState(() {
      _puzzleDraftLines.add(List<String>.from(_puzzleCurrentLine));
      _puzzleCurrentLine.clear();
      _puzzleRecordingLine = false;
      _puzzleDraftPublished = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ветка решения записана')),
    );
  }

  void _puzzleClearDraft() {
    setState(() {
      _puzzleDraftTitle = 'Новая задача';
      _puzzleDraftNumber = 1;
      _puzzleDraftTypeTitle = _selectedPuzzleType.title;
      _puzzleDraftStartFen = null;
      _puzzleDraftLines.clear();
      _puzzleCurrentLine.clear();
      _puzzleRecordingLine = false;
      _puzzleDraftPublished = false;
      _puzzleBoardArrows.clear();
      _hiddenPuzzleAnalysisKinds.clear();
      _teacherAnalysisSide = 'white';
      _activeAnalysisArrowKey = null;
      _pendingAnalysisArrowFrom = null;
      _analysisPointerPosition = null;
      _studentAnalysisArrowKey = null;
      _studentPendingAnalysisArrowFrom = null;
      _studentAnalysisPointerPosition = null;
      _studentShowPuzzleAnswer = false;
      _studentBoardArrows.clear();
      _studentHiddenAnalysisKinds.clear();
      _studentAnalysisSide = 'white';
      _resetStudentPuzzleMoveCheck();
    });
  }

  void _puzzleNewTask() {
    setState(() {
      _puzzleDraftTitle = 'Новая задача';
      _puzzleDraftNumber = _puzzleDraftNumber + 1;
      _puzzleDraftTypeTitle = _selectedPuzzleType.title;
      _puzzleDraftStartFen = null;
      _puzzleDraftLines.clear();
      _puzzleCurrentLine.clear();
      _puzzleRecordingLine = false;
      _puzzleDraftPublished = false;
      _puzzleBoardArrows.clear();
      _hiddenPuzzleAnalysisKinds.clear();
      _teacherAnalysisSide = 'white';
      _activeAnalysisArrowKey = null;
      _pendingAnalysisArrowFrom = null;
      _analysisPointerPosition = null;
      _studentAnalysisArrowKey = null;
      _studentPendingAnalysisArrowFrom = null;
      _studentAnalysisPointerPosition = null;
      _studentShowPuzzleAnswer = false;
      _studentBoardArrows.clear();
      _studentHiddenAnalysisKinds.clear();
      _studentAnalysisSide = 'white';
      _resetStudentPuzzleMoveCheck();
    });
  }

  void _puzzleMarkPublished() {
    setState(() {
      _puzzleDraftPublished = true;
      _puzzleRecordingLine = false;
    });
  }

  Future<void> _openPublishedPuzzlesFolder() async {
    if (_loadingPublishedPuzzleTasks) return;

    setState(() => _loadingPublishedPuzzleTasks = true);

    try {
      await choosePuzzleFolder();
      final files = await loadPuzzleTextFilesFromFolder();
      final parsedTasks = <PuzzleTask>[];
      var failed = 0;

      for (final file in files) {
        try {
          final task = PuzzleTask.fromJsonString(file.content);
          if (task.startFen.trim().isNotEmpty) {
            parsedTasks.add(task);
          }
        } catch (_) {
          failed++;
        }
      }

      final byId = <String, PuzzleTask>{};
      for (final task in parsedTasks) {
        final key = task.id.trim().isEmpty
            ? '${task.type}_${task.number}_${task.title}_${task.startFen}'
            : task.id;
        byId[key] = task;
      }

      if (!mounted) return;
      setState(() {
        _publishedPuzzleTasks
          ..clear()
          ..addAll(byId.values);
        _activePublishedPuzzleIndex = -1;
      });

      final visibleCount = _visiblePublishedPuzzleTasks.length;
      final message = failed == 0
          ? 'Загружено задач: ${parsedTasks.length}. В текущем типе: $visibleCount.'
          : 'Загружено задач: ${parsedTasks.length}. Пропущено файлов: $failed. В текущем типе: $visibleCount.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть задачи: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingPublishedPuzzleTasks = false);
      }
    }
  }

  void _activatePublishedPuzzle(int index) {
    final tasks = _visiblePublishedPuzzleTasks;
    if (index < 0 || index >= tasks.length) return;

    final task = tasks[index];
    final ok = game.load(task.startFen);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить FEN задачи')),
      );
      return;
    }

    setState(() {
      _activePublishedPuzzleIndex = index;
      _fenController.text = game.fen;
      _sanMoves.clear();
      _fens
        ..clear()
        ..add(game.fen);
      _plyIndex = 0;
      _selectedSquare = null;
      _legalTargets.clear();
      _captureTargets.clear();
      _result = null;
      _editMode = false;
      _vsEngine = false;
      _engineThinking = false;
      _activeAnalysisArrowKey = null;
      _pendingAnalysisArrowFrom = null;
      _showPuzzleAnswerArrows = false;
      _puzzleBoardArrows.clear();
      _hiddenPuzzleAnalysisKinds.clear();
      _studentAnalysisArrowKey = null;
      _studentPendingAnalysisArrowFrom = null;
      _studentAnalysisPointerPosition = null;
      _studentShowPuzzleAnswer = false;
      _studentBoardArrows.clear();
      _studentHiddenAnalysisKinds.clear();
      _studentAnalysisSide = 'white';
      _resetStudentPuzzleMoveCheck();
    });

    _syncSendFen();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Открыта задача: №${task.number} ${task.title}')),
    );
  }

  void _activatePreviousPublishedPuzzle() {
    final tasks = _visiblePublishedPuzzleTasks;
    if (tasks.isEmpty) return;
    final nextIndex = _activePublishedPuzzleIndex <= 0
        ? tasks.length - 1
        : _activePublishedPuzzleIndex - 1;
    _activatePublishedPuzzle(nextIndex);
  }

  void _activateNextPublishedPuzzle() {
    final tasks = _visiblePublishedPuzzleTasks;
    if (tasks.isEmpty) return;
    final nextIndex = _activePublishedPuzzleIndex < 0
        ? 0
        : (_activePublishedPuzzleIndex + 1) % tasks.length;
    _activatePublishedPuzzle(nextIndex);
  }

  Color _analysisArrowColor(String key) {
    switch (key) {
      case 'threat':
        return const Color(0x99FF2D2D); // красный
      case 'pin':
        return const Color(0x996A35FF); // фиолетовый
      case 'xray':
        return const Color(0x99FF00C8); // розовый
      case 'weakness':
        return const Color(0x994CFF2E); // зелёный
      case 'r1':
        return const Color(0x99FFB07A); // P1
      case 'r2':
        return const Color(0x990057FF); // P2
      case 'r3':
        return const Color(0x9940F7F7); // P3
      case 'r4':
        return const Color(0x99FF5F93); // P4
      default:
        return const Color(0x9900CFFF);
    }
  }

  bool _isCircleAnalysisKey(String key) => _circleAnalysisKeys.contains(key);

  List<_PuzzleBoardArrow> get _visibleTeacherPuzzleBoardArrows {
    if (_showPuzzleAnswerArrows) {
      return List<_PuzzleBoardArrow>.from(_puzzleBoardArrows);
    }
    return _puzzleBoardArrows
        .where((element) =>
            element.side == _teacherAnalysisSide &&
            !_hiddenPuzzleAnalysisKinds.contains(element.kind))
        .toList(growable: false);
  }

  List<_PuzzleBoardArrow> get _visibleStudentPuzzleBoardArrows {
    return _studentBoardArrows
        .where((element) =>
            element.side == _studentAnalysisSide &&
            !_studentHiddenAnalysisKinds.contains(element.kind))
        .toList(growable: false);
  }

  List<_PuzzleBoardArrow> get _visibleLearningBoardArrows {
    final arrows = _learningBoardArrows
        .where((element) => element.side == _learningAnalysisSide);

    if (_learningShowAnswer) {
      return arrows.toList(growable: false);
    }

    return arrows
        .where(
          (element) => !_learningHiddenAnalysisKinds.contains(element.kind),
        )
        .toList(growable: false);
  }

  List<_PuzzleBoardArrow> get _visiblePuzzleBoardArrows {
    if (_puzzleSettingsIsOpen) {
      return _visibleTeacherPuzzleBoardArrows;
    }

    if (_showLearningPanel) {
      return _visibleLearningBoardArrows;
    }

    // В окне «Задачи» обычные кнопки показывают только ответ ученика.
    // Эталон из «Настройка» показывается только через «Показать ответ».
    if (_studentShowPuzzleAnswer) {
      return _puzzleBoardArrows
          .where((element) => element.side == _studentAnalysisSide)
          .toList(growable: false);
    }

    return _visibleStudentPuzzleBoardArrows;
  }

  bool _isSecondaryMouseButton(PointerEvent event) {
    return (event.buttons & kSecondaryMouseButton) != 0;
  }

  double _distanceToSegment(Offset point, Offset a, Offset b) {
    final ab = b - a;
    final length2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (length2 <= 0.0001) return (point - a).distance;

    final ap = point - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / length2).clamp(0.0, 1.0);
    final projection = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (point - projection).distance;
  }

  bool _removePuzzleAnalysisElementAt(Offset localPosition, double boardSize) {
    final cell = boardSize / 8;
    final circleTolerance = cell * 0.42;
    final arrowTolerance = cell * 0.22;

    final visible = _visiblePuzzleBoardArrows;
    for (var i = visible.length - 1; i >= 0; i--) {
      final element = visible[i];
      final fromCenter = _boardCenterForSquare(element.from, boardSize);

      if (element.isCircle || element.from == element.to) {
        if ((localPosition - fromCenter).distance <= circleTolerance) {
          setState(() {
            if (_puzzleSettingsIsOpen) {
              _puzzleBoardArrows.remove(element);
              _pendingAnalysisArrowFrom = null;
              _analysisPointerPosition = null;
              _puzzleDraftPublished = false;
            } else if (_showLearningPanel) {
              _learningBoardArrows.remove(element);
              _learningPendingAnalysisArrowFrom = null;
              _learningAnalysisPointerPosition = null;
            } else {
              _studentBoardArrows.remove(element);
              _studentPendingAnalysisArrowFrom = null;
              _studentAnalysisPointerPosition = null;
            }
          });
          _refreshPuzzleSettingsOverlay();
          return true;
        }
        continue;
      }

      final toCenter = _boardCenterForSquare(element.to, boardSize);
      if (_distanceToSegment(localPosition, fromCenter, toCenter) <=
          arrowTolerance) {
        setState(() {
          if (_puzzleSettingsIsOpen) {
            _puzzleBoardArrows.remove(element);
            _pendingAnalysisArrowFrom = null;
            _analysisPointerPosition = null;
            _puzzleDraftPublished = false;
          } else if (_showLearningPanel) {
            _learningBoardArrows.remove(element);
            _learningPendingAnalysisArrowFrom = null;
            _learningAnalysisPointerPosition = null;
          } else {
            _studentBoardArrows.remove(element);
            _studentPendingAnalysisArrowFrom = null;
            _studentAnalysisPointerPosition = null;
          }
        });
        _refreshPuzzleSettingsOverlay();
        return true;
      }
    }

    return false;
  }

  bool _handlePuzzleAnalysisSquareTap(String square) {
    if (!_puzzleArrowDrawMode) return false;

    final isSettings = _puzzleSettingsIsOpen;
    final isLearning = !isSettings && _showLearningPanel;
    final key = _effectivePuzzleArrowKey;

    setState(() {
      _selectedSquare = null;
      _legalTargets.clear();
      _captureTargets.clear();

      final side = isSettings
          ? _teacherAnalysisSide
          : (isLearning ? _learningAnalysisSide : _studentAnalysisSide);

      if (_isCircleAnalysisKey(key)) {
        final element = _PuzzleBoardArrow(
          from: square,
          to: square,
          kind: key,
          color: _analysisArrowColor(key),
          isCircle: true,
          side: side,
        );

        if (isSettings) {
          _puzzleBoardArrows.add(element);
          _pendingAnalysisArrowFrom = null;
          _analysisPointerPosition = null;
          _puzzleDraftPublished = false;
        } else if (isLearning) {
          _learningBoardArrows.add(element);
          _learningPendingAnalysisArrowFrom = null;
          _learningAnalysisPointerPosition = null;
        } else {
          _studentBoardArrows.add(element);
          _studentPendingAnalysisArrowFrom = null;
          _studentAnalysisPointerPosition = null;
        }
        return;
      }

      final pending = isSettings
          ? _pendingAnalysisArrowFrom
          : (isLearning
              ? _learningPendingAnalysisArrowFrom
              : _studentPendingAnalysisArrowFrom);

      if (pending == null) {
        if (isSettings) {
          _pendingAnalysisArrowFrom = square;
        } else if (isLearning) {
          _learningPendingAnalysisArrowFrom = square;
        } else {
          _studentPendingAnalysisArrowFrom = square;
        }
        return;
      }

      if (pending == square) {
        if (isSettings) {
          _pendingAnalysisArrowFrom = null;
        } else if (isLearning) {
          _learningPendingAnalysisArrowFrom = null;
        } else {
          _studentPendingAnalysisArrowFrom = null;
        }
        return;
      }

      final element = _PuzzleBoardArrow(
        from: pending,
        to: square,
        kind: key,
        color: _analysisArrowColor(key),
        side: side,
      );

      if (isSettings) {
        _puzzleBoardArrows.add(element);
        _pendingAnalysisArrowFrom = null;
        _puzzleDraftPublished = false;
      } else if (isLearning) {
        _learningBoardArrows.add(element);
        _learningPendingAnalysisArrowFrom = null;
      } else {
        _studentBoardArrows.add(element);
        _studentPendingAnalysisArrowFrom = null;
      }
    });
    _refreshPuzzleSettingsOverlay();

    return true;
  }

  void _setPuzzleAnalysisMode(String? key) {
    setState(() {
      _pendingAnalysisArrowFrom = null;
      _analysisPointerPosition = null;

      if (key == null || !_validAnalysisArrowKeys.contains(key)) {
        _activeAnalysisArrowKey = null;
        return;
      }

      final wasActive = _activeAnalysisArrowKey == key;
      if (wasActive) {
        _activeAnalysisArrowKey = null;
        _hiddenPuzzleAnalysisKinds.add(key);
        _showPuzzleAnswerArrows = false;
        return;
      }

      _activeAnalysisArrowKey = key;
      _hiddenPuzzleAnalysisKinds.remove(key);
      _showPuzzleAnswerArrows = false;
    });
    _refreshPuzzleSettingsOverlay();
  }

  void _setStudentPuzzleAnalysisMode(String? key) {
    setState(() {
      _studentPendingAnalysisArrowFrom = null;
      _studentAnalysisPointerPosition = null;

      // РЕЖИМ «ЗАДАЧИ»: повторное нажатие на активную кнопку
      // должно выключать рисование, скрывать слой этого типа и возвращать
      // доске обычные шахматные ходы. Элементы из ответа ученика НЕ удаляются.
      if (key == null || !_validAnalysisArrowKeys.contains(key)) {
        final currentKey = _studentAnalysisArrowKey;
        if (currentKey != null &&
            _validAnalysisArrowKeys.contains(currentKey)) {
          _studentHiddenAnalysisKinds.add(currentKey);
        }
        _studentAnalysisArrowKey = null;
        _studentShowPuzzleAnswer = false;
        return;
      }

      final wasActive = _studentAnalysisArrowKey == key;
      if (wasActive) {
        _studentAnalysisArrowKey = null;
        _studentHiddenAnalysisKinds.add(key);
        _studentShowPuzzleAnswer = false;
        return;
      }

      _studentAnalysisArrowKey = key;
      _studentHiddenAnalysisKinds.remove(key);
      _studentShowPuzzleAnswer = false;
    });
  }

  void _finishStudentPuzzleAnalysisTask() {
    final hasTask = _activePublishedPuzzleTask != null;
    final movesCorrect = hasTask && _studentPuzzleMoveLineMatchesTeacher();

    setState(() {
      _studentAnalysisArrowKey = null;
      _studentPendingAnalysisArrowFrom = null;
      _studentAnalysisPointerPosition = null;
      _studentShowPuzzleAnswer = false;
      _puzzleMoveChecked = hasTask;
      _puzzleMoveCorrect = hasTask ? movesCorrect : null;
      _shownSolutionLineIndex = 0;
    });

    if (!mounted || !hasTask) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          movesCorrect ? 'Ходы решения верные' : 'Ответ по ходам неверный',
        ),
      ),
    );
  }

  void _setStudentShowPuzzleAnswer(bool value) {
    setState(() {
      _studentShowPuzzleAnswer = value;

      // ВАЖНО: когда панель «Задачи» просто сбрасывает флаг
      // «Показать ответ» в false перед переключением кнопки анализа,
      // нельзя стирать _studentAnalysisArrowKey. Иначе повторное нажатие
      // на «Угроза/Связка/.../P4» снова включает рисование вместо выключения.
      if (!value) {
        return;
      }

      _studentAnalysisArrowKey = null;
      _studentPendingAnalysisArrowFrom = null;
      _studentAnalysisPointerPosition = null;

      final lines = _activePuzzleSolutionMoveLines;
      if (lines.isEmpty) {
        _shownSolutionLineIndex = 0;
      } else if (_shownSolutionLineIndex >= lines.length) {
        _shownSolutionLineIndex = 0;
      }
    });
  }

  void _setLearningAnalysisMode(String? key) {
    setState(() {
      _learningPendingAnalysisArrowFrom = null;
      _learningAnalysisPointerPosition = null;

      if (key == null || !_validAnalysisArrowKeys.contains(key)) {
        final currentKey = _learningAnalysisArrowKey;
        if (currentKey != null &&
            _validAnalysisArrowKeys.contains(currentKey)) {
          _learningHiddenAnalysisKinds.add(currentKey);
        }
        _learningAnalysisArrowKey = null;
        _learningShowAnswer = false;
        _learningDrawingEnabled = false;
        return;
      }

      final wasActive = _learningAnalysisArrowKey == key;
      if (wasActive) {
        _learningAnalysisArrowKey = null;
        _learningHiddenAnalysisKinds.add(key);
        _learningShowAnswer = false;
        _learningDrawingEnabled = false;
        return;
      }

      _learningAnalysisArrowKey = key;
      _learningHiddenAnalysisKinds.remove(key);
      _learningShowAnswer = false;
    });
  }

  void _toggleLearningDrawing() {
    setState(() {
      final enable = !_learningDrawingEnabled;
      _learningDrawingEnabled = enable;
      if (enable && _learningAnalysisArrowKey == null) {
        _learningAnalysisArrowKey = 'threat';
        _learningHiddenAnalysisKinds.remove('threat');
      }
      _learningPendingAnalysisArrowFrom = null;
      _learningAnalysisPointerPosition = null;
    });
  }

  void _toggleLearningAnalysisSide() {
    setState(() {
      _learningAnalysisSide =
          _learningAnalysisSide == 'white' ? 'black' : 'white';
      _learningAnalysisArrowKey = null;
      _learningPendingAnalysisArrowFrom = null;
      _learningAnalysisPointerPosition = null;
      _learningShowAnswer = false;
      _learningDrawingEnabled = false;
    });
  }

  void _finishLearningAnalysisTask() {
    setState(() {
      _learningAnalysisArrowKey = null;
      _learningPendingAnalysisArrowFrom = null;
      _learningAnalysisPointerPosition = null;
      _learningShowAnswer = false;
      _learningDrawingEnabled = false;
    });
  }

  void _setLearningShowAnswer(bool value) {
    setState(() {
      _learningShowAnswer = value;
      if (!value) return;

      _learningDrawingEnabled = false;
      _learningAnalysisArrowKey = null;
      _learningPendingAnalysisArrowFrom = null;
      _learningAnalysisPointerPosition = null;
    });
  }

  void _clearPuzzleAnalysisElements() {
    setState(() {
      _puzzleBoardArrows.clear();
      _hiddenPuzzleAnalysisKinds.clear();
      _teacherAnalysisSide = 'white';
      _activeAnalysisArrowKey = null;
      _pendingAnalysisArrowFrom = null;
      _analysisPointerPosition = null;
      _showPuzzleAnswerArrows = false;
      _puzzleDraftPublished = false;
    });
    _refreshPuzzleSettingsOverlay();
  }

  void _finishPuzzleAnalysisTask() {
    setState(() {
      _activeAnalysisArrowKey = null;
      _pendingAnalysisArrowFrom = null;
      _analysisPointerPosition = null;
    });
    _refreshPuzzleSettingsOverlay();
  }

  void _setShowPuzzleAnswer(bool value) {
    setState(() {
      _showPuzzleAnswerArrows = value;
      _activeAnalysisArrowKey = null;
      _pendingAnalysisArrowFrom = null;
      _analysisPointerPosition = null;
    });
    _refreshPuzzleSettingsOverlay();
  }

  Offset _boardCenterForSquare(String square, double boardSize) {
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.tryParse(square.substring(1)) ?? 1;
    final col = _isFlipped ? 7 - file : file;
    final row = _isFlipped ? rank - 1 : 8 - rank;
    final cell = boardSize / 8;
    return Offset((col + 0.5) * cell, (row + 0.5) * cell);
  }

  String? _boardSquareFromLocalPosition(
      Offset localPosition, double boardSize) {
    if (localPosition.dx < 0 ||
        localPosition.dy < 0 ||
        localPosition.dx > boardSize ||
        localPosition.dy > boardSize) {
      return null;
    }

    final cell = boardSize / 8;
    final col = (localPosition.dx / cell).floor().clamp(0, 7).toInt();
    final row = (localPosition.dy / cell).floor().clamp(0, 7).toInt();

    final fileIndex = _isFlipped ? 7 - col : col;
    final rank = _isFlipped ? row + 1 : 8 - row;
    final file = String.fromCharCode('a'.codeUnitAt(0) + fileIndex);
    return '$file$rank';
  }

  void _startPuzzleAnalysisBoardDrag(Offset localPosition, double boardSize) {
    if (!_puzzleArrowDrawMode) return;

    final square = _boardSquareFromLocalPosition(localPosition, boardSize);
    if (square == null) return;

    final isSettings = _puzzleSettingsIsOpen;
    final isLearning = !isSettings && _showLearningPanel;
    final key = _effectivePuzzleArrowKey;

    setState(() {
      _selectedSquare = null;
      _legalTargets.clear();
      _captureTargets.clear();

      final side = isSettings
          ? _teacherAnalysisSide
          : (isLearning ? _learningAnalysisSide : _studentAnalysisSide);

      if (_isCircleAnalysisKey(key)) {
        final element = _PuzzleBoardArrow(
          from: square,
          to: square,
          kind: key,
          color: _analysisArrowColor(key),
          isCircle: true,
          side: side,
        );

        if (isSettings) {
          _puzzleBoardArrows.add(element);
          _pendingAnalysisArrowFrom = null;
          _analysisPointerPosition = null;
          _puzzleDraftPublished = false;
        } else if (isLearning) {
          _learningBoardArrows.add(element);
          _learningPendingAnalysisArrowFrom = null;
          _learningAnalysisPointerPosition = null;
        } else {
          _studentBoardArrows.add(element);
          _studentPendingAnalysisArrowFrom = null;
          _studentAnalysisPointerPosition = null;
        }
        return;
      }

      if (isSettings) {
        _pendingAnalysisArrowFrom = square;
        _analysisPointerPosition = localPosition;
      } else if (isLearning) {
        _learningPendingAnalysisArrowFrom = square;
        _learningAnalysisPointerPosition = localPosition;
      } else {
        _studentPendingAnalysisArrowFrom = square;
        _studentAnalysisPointerPosition = localPosition;
      }
    });
    _refreshPuzzleSettingsOverlay();
  }

  void _updatePuzzleAnalysisBoardDrag(Offset localPosition, double boardSize) {
    if (!_puzzleArrowDrawMode) return;

    final isSettings = _puzzleSettingsIsOpen;
    final isLearning = !isSettings && _showLearningPanel;
    final pending = isSettings
        ? _pendingAnalysisArrowFrom
        : (isLearning
            ? _learningPendingAnalysisArrowFrom
            : _studentPendingAnalysisArrowFrom);
    if (pending == null) return;

    final clamped = Offset(
      localPosition.dx.clamp(0, boardSize).toDouble(),
      localPosition.dy.clamp(0, boardSize).toDouble(),
    );

    setState(() {
      if (isSettings) {
        _analysisPointerPosition = clamped;
      } else if (isLearning) {
        _learningAnalysisPointerPosition = clamped;
      } else {
        _studentAnalysisPointerPosition = clamped;
      }
    });
  }

  void _finishPuzzleAnalysisBoardDrag(Offset localPosition, double boardSize) {
    if (!_puzzleArrowDrawMode) return;
    final key = _effectivePuzzleArrowKey;
    if (_isCircleAnalysisKey(key)) return;

    final isSettings = _puzzleSettingsIsOpen;
    final isLearning = !isSettings && _showLearningPanel;
    final from = isSettings
        ? _pendingAnalysisArrowFrom
        : (isLearning
            ? _learningPendingAnalysisArrowFrom
            : _studentPendingAnalysisArrowFrom);
    if (from == null) return;

    final to = _boardSquareFromLocalPosition(localPosition, boardSize);
    setState(() {
      if (to != null && to != from) {
        final side = isSettings
            ? _teacherAnalysisSide
            : (isLearning ? _learningAnalysisSide : _studentAnalysisSide);
        final element = _PuzzleBoardArrow(
          from: from,
          to: to,
          kind: key,
          color: _analysisArrowColor(key),
          side: side,
        );

        if (isSettings) {
          _puzzleBoardArrows.add(element);
          _puzzleDraftPublished = false;
        } else if (isLearning) {
          _learningBoardArrows.add(element);
        } else {
          _studentBoardArrows.add(element);
        }
      }

      if (isSettings) {
        _pendingAnalysisArrowFrom = null;
        _analysisPointerPosition = null;
      } else if (isLearning) {
        _learningPendingAnalysisArrowFrom = null;
        _learningAnalysisPointerPosition = null;
      } else {
        _studentPendingAnalysisArrowFrom = null;
        _studentAnalysisPointerPosition = null;
      }
    });
    _refreshPuzzleSettingsOverlay();
  }

  void _handlePuzzleAnalysisBoardTap(Offset localPosition, double boardSize) {
    final square = _boardSquareFromLocalPosition(localPosition, boardSize);
    if (square == null) return;
    _handlePuzzleAnalysisSquareTap(square);
  }

  void _toggleTeacherAnalysisSide() {
    setState(() {
      _teacherAnalysisSide =
          _teacherAnalysisSide == 'white' ? 'black' : 'white';
      _activeAnalysisArrowKey = null;
      _pendingAnalysisArrowFrom = null;
      _analysisPointerPosition = null;
      _showPuzzleAnswerArrows = false;
    });
    _refreshPuzzleSettingsOverlay();
  }

  void _toggleStudentAnalysisSide() {
    setState(() {
      _studentAnalysisSide =
          _studentAnalysisSide == 'white' ? 'black' : 'white';
      _studentAnalysisArrowKey = null;
      _studentPendingAnalysisArrowFrom = null;
      _studentAnalysisPointerPosition = null;
      _studentShowPuzzleAnswer = false;
    });
  }

  PuzzleTask? get _activePublishedPuzzleTask {
    final tasks = _visiblePublishedPuzzleTasks;
    if (_activePublishedPuzzleIndex < 0 ||
        _activePublishedPuzzleIndex >= tasks.length) {
      return null;
    }
    return tasks[_activePublishedPuzzleIndex];
  }

  Map<String, PuzzleAnalysisResult> get _studentAnalysisResults {
    const keys = <String>[
      'threat',
      'pin',
      'xray',
      'weakness',
      'r1',
      'r2',
      'r3',
      'r4',
    ];

    final task = _activePublishedPuzzleTask;
    final result = <String, PuzzleAnalysisResult>{};

    for (final key in keys) {
      result[key] = PuzzleAnalysisResult(
        whiteCorrect: _studentCorrectAnalysisCount(task, key, 'white'),
        whiteTotal: _taskCorrectAnalysisTotal(task, key, 'white'),
        blackCorrect: _studentCorrectAnalysisCount(task, key, 'black'),
        blackTotal: _taskCorrectAnalysisTotal(task, key, 'black'),
      );
    }

    return result;
  }

  Map<String, LearningAnalysisResult> get _learningAnalysisResults {
    const keys = <String>[
      'threat',
      'pin',
      'xray',
      'weakness',
      'r1',
      'r2',
      'r3',
      'r4',
    ];

    final result = <String, LearningAnalysisResult>{};
    for (final key in keys) {
      final white = _learningBoardArrows
          .where((element) => element.kind == key && element.side == 'white')
          .length;
      final black = _learningBoardArrows
          .where((element) => element.kind == key && element.side == 'black')
          .length;

      result[key] = LearningAnalysisResult(
        whiteCorrect: white,
        whiteTotal: white,
        blackCorrect: black,
        blackTotal: black,
      );
    }
    return result;
  }

  int _taskCorrectAnalysisTotal(PuzzleTask? task, String kind, String side) {
    if (task == null) return 0;
    return (task.analysisArrows[kind] ?? const <PuzzleAnalysisArrow>[])
        .where((element) => element.side == side)
        .length;
  }

  int _studentCorrectAnalysisCount(PuzzleTask? task, String kind, String side) {
    if (task == null) return 0;

    final correct = (task.analysisArrows[kind] ?? const <PuzzleAnalysisArrow>[])
        .where((element) => element.side == side)
        .map((element) => '${element.from}->${element.to}')
        .toList();

    final answer = _studentBoardArrows
        .where((element) => element.kind == kind && element.side == side)
        .map((element) => '${element.from}->${element.to}')
        .toList();

    final correctBag = <String, int>{};
    for (final item in correct) {
      correctBag[item] = (correctBag[item] ?? 0) + 1;
    }

    var hits = 0;
    for (final item in answer) {
      final left = correctBag[item] ?? 0;
      if (left <= 0) continue;
      correctBag[item] = left - 1;
      hits++;
    }

    return hits;
  }

  List<List<String>> get _activePuzzleSolutionMoveLines {
    final task = _activePublishedPuzzleTask;
    if (task == null) return const <List<String>>[];
    return task.solutionLines
        .map((line) => line.moves
            .map(_normalizePuzzleMoveForCompare)
            .where((move) => move.isNotEmpty)
            .toList(growable: false))
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  List<String> get _currentStudentPuzzleMoveLine => _studentPuzzleMoveLine
      .map(_normalizePuzzleMoveForCompare)
      .where((move) => move.isNotEmpty)
      .toList(growable: false);

  String _normalizePuzzleMoveForCompare(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-h1-8qrbn]'), '');
  }

  bool _movesEqualForPuzzle(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (_normalizePuzzleMoveForCompare(left[i]) !=
          _normalizePuzzleMoveForCompare(right[i])) {
        return false;
      }
    }
    return true;
  }

  bool _studentPuzzleMoveLineMatchesTeacher() {
    final answer = _currentStudentPuzzleMoveLine;
    if (answer.isEmpty) return false;

    for (final correctLine in _activePuzzleSolutionMoveLines) {
      if (_movesEqualForPuzzle(answer, correctLine)) return true;
    }
    return false;
  }

  void _resetStudentPuzzleMoveCheck() {
    _studentPuzzleMoveLine.clear();
    _puzzleMoveChecked = false;
    _puzzleMoveCorrect = null;
    _shownSolutionLineIndex = 0;
  }

  void _openPreviousSolutionLine() {
    final lines = _activePuzzleSolutionMoveLines;
    if (lines.isEmpty) return;
    setState(() {
      _shownSolutionLineIndex = _shownSolutionLineIndex <= 0
          ? lines.length - 1
          : _shownSolutionLineIndex - 1;
    });
  }

  void _openNextSolutionLine() {
    final lines = _activePuzzleSolutionMoveLines;
    if (lines.isEmpty) return;
    setState(() {
      _shownSolutionLineIndex = (_shownSolutionLineIndex + 1) % lines.length;
    });
  }

  bool get _showPuzzleMoveResultPanel =>
      _showPuzzlePanel && _activePublishedPuzzleTask != null;

  Future<void> _openPuzzleSettings() async {
    // Окно «Настройка» — отдельный режим тренера.
    // При входе в него выключаем активное рисование ученика, но ответ ученика
    // не удаляем: он просто не должен управлять эталоном.
    setState(() {
      _studentAnalysisArrowKey = null;
      _studentPendingAnalysisArrowFrom = null;
      _studentAnalysisPointerPosition = null;
      _studentShowPuzzleAnswer = false;
    });

    if (_puzzleSettingsOverlay != null) {
      _refreshPuzzleSettingsOverlay();
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => PuzzleSettingsDialog(
        selectedTypeTitle: _selectedPuzzleType.title,
        taskTitle: _puzzleDraftTitle,
        taskNumber: _puzzleDraftNumber,
        taskTypeTitle: _puzzleDraftTypeTitle ?? _selectedPuzzleType.title,
        currentFen: game.fen,
        startFen: _puzzleDraftStartFen,
        savedLines: _puzzleDraftLines,
        currentLine: _puzzleCurrentLine,
        isRecordingLine: _puzzleRecordingLine,
        isPublished: _puzzleDraftPublished,
        activeAnalysisKey: _activeAnalysisArrowKey,
        showAnswer: _showPuzzleAnswerArrows,
        analysisCounts: _analysisElementCounts,
        activeAnalysisSide: _teacherAnalysisSide,
        onAnalysisSideToggle: _toggleTeacherAnalysisSide,
        buildPuzzle: _buildPuzzleDraft,
        onTaskTitleChanged: (value) {
          _puzzleDraftTitle = value;
          _puzzleDraftPublished = false;
        },
        onTaskNumberChanged: (value) {
          _puzzleDraftNumber = value;
          _puzzleDraftPublished = false;
        },
        onTaskTypeTitleChanged: (value) {
          _puzzleDraftTypeTitle = value;
          _puzzleDraftPublished = false;
        },
        onSetInitialPosition: () {
          _puzzleSetInitialPosition();
          _refreshPuzzleSettingsOverlay();
        },
        onStartRecordingLine: () {
          _puzzleStartRecordingLine();
          _refreshPuzzleSettingsOverlay();
        },
        onFinishRecordingLine: () {
          _puzzleFinishRecordingLine();
          _refreshPuzzleSettingsOverlay();
        },
        onClearDraft: () {
          _puzzleClearDraft();
          _refreshPuzzleSettingsOverlay();
        },
        onNewTask: () {
          _puzzleNewTask();
          _refreshPuzzleSettingsOverlay();
        },
        onPublished: () {
          _puzzleMarkPublished();
          _refreshPuzzleSettingsOverlay();
        },
        onAnalysisModeChanged: _setPuzzleAnalysisMode,
        onFinishAnalysis: _finishPuzzleAnalysisTask,
        onShowAnswerChanged: _setShowPuzzleAnswer,
        onClearAnalysisElements: _clearPuzzleAnalysisElements,
        onClose: _closePuzzleSettingsOverlay,
      ),
    );

    _puzzleSettingsOverlay = entry;
    Overlay.of(context).insert(entry);
  }

  LearningStudent? get _selectedLearningStudent {
    final selectedId = _selectedLearningStudentId;
    if (selectedId == null || selectedId.isEmpty) return null;
    for (final student in _learningStudents) {
      if (student.id == selectedId) return student;
    }
    return null;
  }

  Future<void> _startLessonResponseListener() async {
    try {
      final service = cls.LessonInvitationService.instance;
      await service.start(Supabase.instance.client);
      await _lessonResponseSub?.cancel();
      _lessonResponseSub = service.responses.listen((response) async {
        try {
          await _handleLessonInvitationResponse(response);
        } catch (error) {
          debugPrint('[LESSON] Ошибка обработки ответа: $error');
        }
      });
    } catch (error) {
      debugPrint('[LESSON] Не удалось запустить канал ответов: $error');
    }
  }

  Future<void> _handleLessonInvitationResponse(
    cls.LessonInvitationResponse response,
  ) async {
    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (myId.isEmpty || response.teacherId != myId) return;
    if (_pendingLearningLessonId != response.lessonId) return;
    if (_selectedLearningStudentId != response.studentId) return;

    if (!mounted) return;

    if (!response.accepted) {
      setState(() {
        _learningInvitationStatus =
            '${response.studentName} отклонил приглашение на урок';
        _pendingLearningLessonId = null;
        _confirmedLearningStudentId = null;
      });
      return;
    }

    setState(() {
      _learningInvitationStatus =
          '${response.studentName} принял приглашение. Урок подключён';
      _learningLessonId = response.lessonId;
      _pendingLearningLessonId = null;
    });

    await _activateLearningSession(
      lessonId: response.lessonId,
      role: LearningPanelRole.teacher,
    );
  }

  Future<void> _loadLearningStudents({bool showError = false}) async {
    final client = Supabase.instance.client;
    final teacherId = client.auth.currentUser?.id;

    if (teacherId == null || teacherId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _learningStudents.clear();
        _selectedLearningStudentId = null;
        _confirmedLearningStudentId = null;
        _learningInvitationStatus = null;
      });
      return;
    }

    try {
      final rows = await client
          .from('teacher_students')
          .select('student_id, student_nickname, created_at')
          .eq('teacher_id', teacherId)
          .order('created_at', ascending: true);

      final loaded = <LearningStudent>[];
      for (final raw in rows) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        final studentId = '${row['student_id'] ?? ''}'.trim();
        final nickname = '${row['student_nickname'] ?? ''}'.trim();
        if (studentId.isEmpty || nickname.isEmpty) continue;
        loaded.add(LearningStudent(id: studentId, nickname: nickname));
      }

      if (!mounted) return;
      setState(() {
        _learningStudents
          ..clear()
          ..addAll(loaded);

        final selectedStillExists = _selectedLearningStudentId != null &&
            _learningStudents.any(
              (student) => student.id == _selectedLearningStudentId,
            );
        if (!selectedStillExists) {
          _selectedLearningStudentId = null;
          _confirmedLearningStudentId = null;
          _learningInvitationStatus = null;
        }
        _selectedVideoStudentIds.removeWhere(
          (id) => !_learningStudents.any((student) => student.id == id),
        );
      });
    } catch (error) {
      debugPrint('[LEARNING STUDENTS] Ошибка загрузки: $error');
      if (showError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось загрузить список учеников: $error'),
          ),
        );
      }
    }
  }

  Future<void> _saveLearningStudent({
    required String studentId,
    required String nickname,
  }) async {
    final client = Supabase.instance.client;
    final teacherId = client.auth.currentUser?.id;
    if (teacherId == null || teacherId.isEmpty) {
      throw StateError('Сначала войдите в аккаунт учителя');
    }

    await client.from('teacher_students').upsert(
      {
        'teacher_id': teacherId,
        'student_id': studentId,
        'student_nickname': nickname,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'teacher_id,student_id',
    );
  }

  Future<void> _addLearningStudent() async {
    try {
      final client = Supabase.instance.client;
      final myId = client.auth.currentUser?.id ?? '';
      if (myId.isEmpty) {
        throw StateError('Сначала войдите в аккаунт учителя');
      }

      final rows = await client
          .from('profiles')
          .select('id,nickname')
          .order('nickname', ascending: true);

      final registeredPlayers = <LearningStudent>[];
      for (final row in rows) {
        final id = '${row['id'] ?? ''}'.trim();
        final nickname = '${row['nickname'] ?? ''}'.trim();
        if (id.isEmpty || nickname.isEmpty || id == myId) continue;
        registeredPlayers.add(LearningStudent(id: id, nickname: nickname));
      }

      if (!mounted) return;
      final selected = await _showRegisteredPlayersDialog(registeredPlayers);
      if (selected == null || !mounted) return;

      final alreadyAdded =
          _learningStudents.any((student) => student.id == selected.id);
      if (alreadyAdded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${selected.nickname} уже находится в списке учеников'),
          ),
        );
        return;
      }

      await _saveLearningStudent(
        studentId: selected.id,
        nickname: selected.nickname,
      );

      if (!mounted) return;
      setState(() {
        _learningStudents.add(selected);
        _learningStudents.sort(
          (a, b) =>
              a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()),
        );
        _selectedLearningStudentId = selected.id;
        _confirmedLearningStudentId = null;
        _learningInvitationStatus = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось добавить ученика: $error')),
      );
    }
  }

  Future<LearningStudent?> _showRegisteredPlayersDialog(
    List<LearningStudent> registeredPlayers,
  ) async {
    final searchController = TextEditingController();
    var query = '';
    var ascending = true;

    try {
      return await showDialog<LearningStudent>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final normalizedQuery = query.trim().toLowerCase();
            final visiblePlayers = registeredPlayers
                .where(
                  (player) =>
                      normalizedQuery.isEmpty ||
                      player.nickname.toLowerCase().contains(normalizedQuery),
                )
                .toList(growable: false)
              ..sort(
                (a, b) {
                  final result = a.nickname
                      .toLowerCase()
                      .compareTo(b.nickname.toLowerCase());
                  return ascending ? result : -result;
                },
              );

            return AlertDialog(
              title: const Text('Выбрать ученика'),
              content: SizedBox(
                width: 520,
                height: 520,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            autofocus: true,
                            decoration: const InputDecoration(
                              labelText: 'Поиск по нику',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (value) {
                              setDialogState(() => query = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message:
                              ascending ? 'Сортировка А–Я' : 'Сортировка Я–А',
                          child: IconButton.filledTonal(
                            onPressed: () {
                              setDialogState(() => ascending = !ascending);
                            },
                            icon: Icon(
                              ascending
                                  ? Icons.sort_by_alpha
                                  : Icons.sort_by_alpha_outlined,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Зарегистрированные игроки: ${visiblePlayers.length}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: visiblePlayers.isEmpty
                          ? const Center(
                              child: Text('Игроки не найдены'),
                            )
                          : ListView.separated(
                              itemCount: visiblePlayers.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final player = visiblePlayers[index];
                                final alreadyAdded = _learningStudents.any(
                                  (student) => student.id == player.id,
                                );
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      player.nickname.characters.first
                                          .toUpperCase(),
                                    ),
                                  ),
                                  title: Text(player.nickname),
                                  subtitle: alreadyAdded
                                      ? const Text('Уже добавлен')
                                      : null,
                                  trailing: alreadyAdded
                                      ? const Icon(Icons.check)
                                      : const Icon(Icons.person_add_alt_1),
                                  enabled: !alreadyAdded,
                                  onTap: alreadyAdded
                                      ? null
                                      : () => Navigator.of(dialogContext)
                                          .pop(player),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Закрыть'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      searchController.dispose();
    }
  }

  Set<String> get _learningOnlineStudentIds =>
      _learningStudentLastSeen.keys.toSet();

  Set<String> get _learningConnectedGameStudentIds =>
      _learningGameSessions.keys.toSet();

  Set<String> get _learningPendingGameStudentIds =>
      _pendingLearningGameInvites.values
          .map((invite) => invite.student.id)
          .toSet();

  Map<String, dynamic> _unwrapLearningPresencePayload(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final result = Map<String, dynamic>.from(raw);
    while (result['payload'] is Map) {
      final inner = Map<String, dynamic>.from(result['payload'] as Map);
      result
        ..remove('payload')
        ..addAll(inner);
    }
    return result;
  }

  Future<void> _ensureLearningPresenceChannel() async {
    if (_learningPresenceChannel != null) return;
    final client = Supabase.instance.client;
    final myId = client.auth.currentUser?.id ?? '';
    if (myId.isEmpty) return;

    final channel = client.channel(
      'makechess:school-student-presence:v1',
      opts: const rt.RealtimeChannelConfig(self: false),
    );

    void acceptPresence(dynamic raw) {
      if (_learningRole != LearningPanelRole.teacher) return;
      final payload = _unwrapLearningPresencePayload(raw);
      final id = '${payload['id'] ?? ''}'.trim();
      if (id.isEmpty || id == myId) return;
      _learningStudentLastSeen[id] = DateTime.now();
      if (mounted) setState(() {});
    }

    channel.onBroadcast(
      event: 'student_online',
      callback: (raw, [ref]) => acceptPresence(raw),
    );
    channel.onBroadcast(
      event: 'student_ping',
      callback: (raw, [ref]) => acceptPresence(raw),
    );
    channel.onBroadcast(
      event: 'student_offline',
      callback: (raw, [ref]) {
        if (_learningRole != LearningPanelRole.teacher) return;
        final payload = _unwrapLearningPresencePayload(raw);
        final id = '${payload['id'] ?? ''}'.trim();
        if (id.isEmpty) return;
        if (_learningStudentLastSeen.remove(id) != null && mounted) {
          setState(() {});
        }
      },
    );
    channel.onBroadcast(
      event: 'who_is_student',
      callback: (raw, [ref]) {
        if (_learningRole == LearningPanelRole.student) {
          unawaited(_publishLearningStudentPresence(event: 'student_online'));
        }
      },
    );

    await channel.subscribe();
    _learningPresenceChannel = channel;

    _learningPresenceCleanup ??=
        Timer.periodic(const Duration(seconds: 5), (_) {
      if (_learningRole != LearningPanelRole.teacher) return;
      final threshold = DateTime.now().subtract(const Duration(seconds: 25));
      final before = _learningStudentLastSeen.length;
      _learningStudentLastSeen
          .removeWhere((_, seenAt) => seenAt.isBefore(threshold));
      if (before != _learningStudentLastSeen.length && mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _publishLearningStudentPresence({
    String event = 'student_ping',
  }) async {
    if (_learningRole != LearningPanelRole.student &&
        event != 'student_offline') {
      return;
    }
    await _ensureLearningPresenceChannel();
    final channel = _learningPresenceChannel;
    final user = Supabase.instance.client.auth.currentUser;
    final name = (_nickname ?? '').trim();
    if (channel == null || user == null || name.isEmpty) return;
    await channel.sendBroadcastMessage(
      event: event,
      payload: <String, dynamic>{
        'id': user.id,
        'name': name,
        'role': 'student',
        'ts': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> _updateLearningPresenceForRole(
    LearningPanelRole previous,
    LearningPanelRole next,
  ) async {
    if (previous == LearningPanelRole.student &&
        next != LearningPanelRole.student) {
      await _publishLearningStudentPresence(event: 'student_offline');
    }

    _learningPresenceHeartbeat?.cancel();
    _learningPresenceHeartbeat = null;

    if (next == LearningPanelRole.none) return;
    await _ensureLearningPresenceChannel();

    if (next == LearningPanelRole.student) {
      await _publishLearningStudentPresence(event: 'student_online');
      _learningPresenceHeartbeat =
          Timer.periodic(const Duration(seconds: 8), (_) {
        unawaited(_publishLearningStudentPresence());
      });
      return;
    }

    _learningStudentLastSeen.clear();
    await _learningPresenceChannel?.sendBroadcastMessage(
      event: 'who_is_student',
      payload: <String, dynamic>{
        'from': Supabase.instance.client.auth.currentUser?.id ?? '',
        'ts': DateTime.now().toUtc().toIso8601String(),
      },
    );
    if (mounted) setState(() {});
  }

  void _handleLearningRoleChanged(LearningPanelRole role) {
    final previous = _learningRole;
    if (mounted) {
      setState(() => _learningRole = role);
    } else {
      _learningRole = role;
    }
    unawaited(_updateLearningPresenceForRole(previous, role));
  }

  Future<void> _disposeLearningPresence() async {
    _learningPresenceHeartbeat?.cancel();
    _learningPresenceHeartbeat = null;
    _learningPresenceCleanup?.cancel();
    _learningPresenceCleanup = null;

    final channel = _learningPresenceChannel;
    _learningPresenceChannel = null;

    // При закрытии не создаём канал заново только ради сообщения offline.
    if (_learningRole == LearningPanelRole.student && channel != null) {
      final user = Supabase.instance.client.auth.currentUser;
      final name = (_nickname ?? '').trim();
      if (user != null && name.isNotEmpty) {
        try {
          await channel.sendBroadcastMessage(
            event: 'student_offline',
            payload: <String, dynamic>{
              'id': user.id,
              'name': name,
              'role': 'student',
              'ts': DateTime.now().toUtc().toIso8601String(),
            },
          );
        } catch (_) {}
      }
    }

    if (channel != null) {
      try {
        await channel.unsubscribe();
      } catch (_) {}
      try {
        await Supabase.instance.client.removeChannel(channel);
      } catch (_) {}
    }
    _learningStudentLastSeen.clear();
  }

  void _selectLearningStudent(String studentId) {
    if (!_learningStudents.any((student) => student.id == studentId)) return;
    setState(() {
      _selectedLearningStudentId = studentId;

      // Строка выбрана, но выбор ещё не подтверждён кнопкой.
      _confirmedLearningStudentId = null;
      _learningInvitationStatus = null;
    });
  }

  void _toggleLearningBoardsView() {
    setState(() {
      _learningShowAllBoards = !_learningShowAllBoards;
      if (!_learningShowAllBoards) {
        _learningFocusedStudentId ??= _firstLearningBoardStudentId;
      }
    });
  }

  String? get _firstLearningBoardStudentId {
    // Первая доска — это всегда левый верхний слот.
    if (_learningStudents.isNotEmpty) return _learningStudents.first.id;
    if (_learningGameSessions.isNotEmpty) {
      return _learningGameSessions.keys.first;
    }
    return null;
  }

  _LearningGameSession? get _activeLearningGameSession {
    final focusedId = _learningFocusedStudentId ?? _firstLearningBoardStudentId;
    if (focusedId == null) return null;
    return _learningGameSessions[focusedId];
  }

  _LearningGameSession? get _selectedLearningGameSession {
    final selectedId = _selectedLearningStudentId ?? _learningFocusedStudentId;
    if (selectedId == null) return null;
    return _learningGameSessions[selectedId];
  }

  bool get _selectedLearningStudentEvaluationEnabled =>
      _selectedLearningGameSession?.studentEvaluationEnabled ?? false;

  void _focusLearningStudentBoard(String studentId) {
    if (!_learningStudents.any((student) => student.id == studentId) &&
        !_learningGameSessions.containsKey(studentId)) {
      return;
    }
    setState(() {
      _selectedLearningStudentId = studentId;
      _learningFocusedStudentId = studentId;
      _learningShowAllBoards = false;
    });
  }

  void _toggleVideoLearningStudent(String studentId) {
    if (!_learningStudents.any((student) => student.id == studentId)) return;

    var added = false;
    setState(() {
      if (_selectedVideoStudentIds.contains(studentId)) {
        _selectedVideoStudentIds.remove(studentId);
        return;
      }
      if (_selectedVideoStudentIds.length >= 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Для одного видеозвонка можно выбрать до 8 учеников'),
          ),
        );
        return;
      }
      _selectedVideoStudentIds.add(studentId);
      added = true;
    });

    // Если видеоурок уже идёт, новый отмеченный ученик вызывается сразу.
    // Первый ученик при этом не отключается и продолжает работать в своём окне.
    final activeCall = _classroomVideoCall;
    if (added &&
        activeCall != null &&
        activeCall.isActive &&
        activeCall.isTeacher) {
      unawaited(_extendRunningClassroomVideo());
    }
  }

  Future<void> _extendRunningClassroomVideo() async {
    await startSelectedStudentsVideo();
  }

  Future<void> _inviteLearningStudentToGame(
    LearningStudent student,
  ) async {
    if (!_learningStudents.any((item) => item.id == student.id)) {
      return;
    }
    if (!_learningOnlineStudentIds.contains(student.id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${student.nickname} должен войти через «Войти как ученик»',
            ),
          ),
        );
      }
      return;
    }
    if (_learningPendingGameStudentIds.contains(student.id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ждём ответ от ${student.nickname}')),
        );
      }
      return;
    }

    final existing = _learningGameSessions[student.id];
    if (existing != null && !existing.terminated) {
      _focusLearningStudentBoard(student.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Партия с ${student.nickname} уже открыта'),
          ),
        );
      }
      return;
    }

    if (existing == null && _learningGameSessions.length >= 8) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Одновременно можно открыть не более 8 партий'),
          ),
        );
      }
      return;
    }

    if (_lobby == null) {
      await _enterLobby(showMessage: false);
      if (_lobby == null) return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Партия с ${student.nickname}'),
        content: const Text('Кем хотите играть?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop('random'),
            child: const Text('Случайный'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop('white'),
            child: const Text('Белыми'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop('black'),
            child: const Text('Чёрными'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    var myColor = choice;
    if (myColor == 'random') {
      myColor = math.Random().nextBool() ? 'white' : 'black';
    }

    final pickedTc = await showDialog<_TcChoice>(
      context: context,
      builder: (_) => _TcDialog(
        initialMinutes: _tcMinutes,
        initialIncrement: _tcIncrement,
        initialRated: _matchRated,
      ),
    );
    if (pickedTc == null) return;

    final roomId = const Uuid().v4();
    _pendingLearningGameInvites[roomId] = _PendingLearningGameInvite(
      student: student,
      myColor: myColor,
      minutes: pickedTc.minutes,
      increment: pickedTc.increment,
      rated: pickedTc.rated,
    );

    try {
      _lobby!.sendPresenceNow();
      await _lobby!.sendInvite(
        toUserId: student.id,
        toName: student.nickname,
        roomId: roomId,
        color: myColor,
        minutes: pickedTc.minutes,
        increment: pickedTc.increment,
        rated: pickedTc.rated,
        kind: 'learning',
      );

      if (!mounted) return;
      setState(() {
        _selectedLearningStudentId = student.id;
        _learningFocusedStudentId ??= student.id;
        _learningInvitationStatus =
            'Приглашение отправлено: ${student.nickname}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Приглашение отправлено: ${student.nickname}, '
            '${pickedTc.minutes}+${pickedTc.increment}',
          ),
        ),
      );

      // Если ученик не ответил, кнопка не должна навсегда оставаться «Ждём…».
      unawaited(
        Future<void>.delayed(const Duration(seconds: 45), () {
          final stillPending = _pendingLearningGameInvites[roomId];
          if (stillPending == null || stillPending.student.id != student.id) {
            return;
          }
          _pendingLearningGameInvites.remove(roomId);
          if (!mounted) return;
          setState(() {
            _learningInvitationStatus =
                '${student.nickname} не ответил на приглашение';
          });
        }),
      );
    } catch (error) {
      _pendingLearningGameInvites.remove(roomId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось пригласить ученика: $error')),
      );
    }
  }

  Future<void> _sendClassroomVideoInvitations({
    required SupabaseClient client,
    required String lessonId,
    required String classroomId,
    required String teacherId,
    required String teacherName,
    required List<LearningStudent> students,
  }) async {
    final invitations = cls.LessonInvitationService.instance;
    await invitations.start(client);

    for (final student in students) {
      await invitations.sendInvitation(
        cls.LessonInvitation(
          lessonId: lessonId,
          teacherId: teacherId,
          teacherName: teacherName,
          studentId: student.id,
          studentName: student.nickname,
          createdAt: DateTime.now(),
          kind: 'video',
          classroomId: classroomId,
        ),
      );
    }
  }

  /// Вызывается кнопкой «Видео» из общей шапки приложения.
  ///
  /// Первый вызов создаёт видеокласс. Следующие выбранные ученики добавляются
  /// в тот же видеокласс без отключения уже работающих учеников.
  Future<bool> startSelectedStudentsVideo() async {
    final client = Supabase.instance.client;
    final teacherId = client.auth.currentUser?.id ?? '';
    final teacherName = (_nickname ?? '').trim();
    final students = _learningStudents
        .where((student) => _selectedVideoStudentIds.contains(student.id))
        .take(8)
        .toList(growable: false);

    if (teacherId.isEmpty || teacherName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сначала войдите в аккаунт учителя')),
        );
      }
      return false;
    }
    if (students.isEmpty) return false;

    final activeCall = _classroomVideoCall;
    final activeLessonId = _classroomVideoLessonId;
    final activeClassroomId = _classroomVideoClassroomId;
    final canExtendExistingCall = activeCall != null &&
        activeCall.isActive &&
        activeCall.isTeacher &&
        activeCall.teacherId == teacherId &&
        activeLessonId != null &&
        activeLessonId.isNotEmpty &&
        activeClassroomId != null &&
        activeClassroomId.isNotEmpty;

    if (canExtendExistingCall) {
      final runningCall = activeCall!;
      final runningLessonId = activeLessonId!;
      final runningClassroomId = activeClassroomId!;
      final newStudents = students
          .where((student) => !runningCall.hasTeacherStudent(student.id))
          .toList(growable: false);

      if (newStudents.isEmpty) return true;

      try {
        await runningCall.addTeacherStudents(
          <String, String>{
            for (final student in newStudents) student.id: student.nickname,
          },
        );
        await _sendClassroomVideoInvitations(
          client: client,
          lessonId: runningLessonId,
          classroomId: runningClassroomId,
          teacherId: teacherId,
          teacherName: teacherName,
          students: newStudents,
        );

        if (!mounted) return true;
        setState(() {
          _learningInvitationStatus =
              'Добавлено в видеовызов: ${newStudents.length} ученик(а/ов)';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'В видеовызов добавлено ${newStudents.length} ученик(а/ов)',
            ),
          ),
        );
        return true;
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось добавить ученика: $error')),
          );
        }
        return true;
      }
    }

    final lessonId = const Uuid().v4();
    final signaling = cls.ClassroomSignaling(client);

    try {
      final classroomId = await signaling.ensureActiveClassroom(
        schoolId: 'video:$lessonId',
        teacherId: teacherId,
      );

      await _classroomVideoCall?.stop();
      _classroomVideoCall = null;
      _classroomVideoLessonId = null;
      _classroomVideoClassroomId = null;

      final call = ClassroomCallService(
        client: client,
        signaling: signaling,
        classroomId: classroomId,
        selfId: teacherId,
        teacherId: teacherId,
        isTeacher: true,
        peerNames: <String, String>{
          for (final student in students) student.id: student.nickname,
        },
      );
      _classroomVideoCall = call;
      await call.start(context);
      _classroomVideoLessonId = lessonId;
      _classroomVideoClassroomId = classroomId;

      await _sendClassroomVideoInvitations(
        client: client,
        lessonId: lessonId,
        classroomId: classroomId,
        teacherId: teacherId,
        teacherName: teacherName,
        students: students,
      );

      if (!mounted) return true;
      setState(() {
        _learningInvitationStatus =
            'Видеовызов отправлен: ${students.length} ученик(а/ов)';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Видеовызов отправлен ${students.length} ученик(а/ов)',
          ),
        ),
      );
      return true;
    } catch (error) {
      await _classroomVideoCall?.stop();
      _classroomVideoCall = null;
      _classroomVideoLessonId = null;
      _classroomVideoClassroomId = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось начать видеоурок: $error')),
        );
      }
      return true;
    }
  }

  Future<void> acceptVideoInvitation(cls.LessonInvitation invitation) async {
    final classroomId = invitation.classroomId;
    final client = Supabase.instance.client;
    final studentId = client.auth.currentUser?.id ?? '';
    if (!invitation.isVideo ||
        classroomId == null ||
        classroomId.isEmpty ||
        studentId.isEmpty) {
      return;
    }

    await _classroomVideoCall?.stop();
    final call = ClassroomCallService(
      client: client,
      signaling: cls.ClassroomSignaling(client),
      classroomId: classroomId,
      selfId: studentId,
      teacherId: invitation.teacherId,
      isTeacher: false,
      peerNames: <String, String>{
        invitation.teacherId: invitation.teacherName,
      },
    );
    _classroomVideoCall = call;
    await call.start(context);
    _classroomVideoLessonId = invitation.lessonId;
    _classroomVideoClassroomId = classroomId;
  }

  Future<void> stopClassroomVideo() async {
    await _classroomVideoCall?.stop();
    _classroomVideoCall = null;
    _classroomVideoLessonId = null;
    _classroomVideoClassroomId = null;
  }

  Future<void> _inviteSelectedLearningStudent() async {
    final student = _selectedLearningStudent;
    final client = Supabase.instance.client;
    final teacherId = client.auth.currentUser?.id;

    if (teacherId == null || teacherId.isEmpty || _nickname == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сначала войдите в зарегистрированный аккаунт'),
          ),
        );
      }
      return;
    }

    if (student == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сначала выберите ученика из списка')),
        );
      }
      return;
    }

    final lessonId = const Uuid().v4();

    setState(() {
      _learningRole = LearningPanelRole.teacher;
      _confirmedLearningStudentId = student.id;
      _pendingLearningLessonId = lessonId;
      _learningInvitationStatus =
          'Отправляем приглашение ученику ${student.nickname}…';
    });

    try {
      final service = cls.LessonInvitationService.instance;
      await service.start(client);
      await service.sendInvitation(
        cls.LessonInvitation(
          lessonId: lessonId,
          teacherId: teacherId,
          teacherName: _nickname ?? 'Учитель',
          studentId: student.id,
          studentName: student.nickname,
          createdAt: DateTime.now(),
        ),
      );

      if (!mounted) return;
      setState(() {
        _learningInvitationStatus =
            'Приглашение отправлено ученику ${student.nickname}. Ждём ответ';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pendingLearningLessonId = null;
        _confirmedLearningStudentId = null;
        _learningInvitationStatus = 'Не удалось отправить приглашение';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка приглашения: $error')),
      );
    }
  }

  Future<void> _activateLearningSession({
    required String lessonId,
    required LearningPanelRole role,
  }) async {
    _leaveBoardChannel();

    if (!mounted) return;
    setState(() {
      _showPuzzlePanel = false;
      _showLearningPanel = true;
      _mobilePanel = 'learning';
      _learningRole = role;
      _learningLessonId = lessonId;
      _syncBoard = true;
      _sharedControl = true;
      _syncEditor = true;
      _learningAnalysisArrowKey = null;
      _learningPendingAnalysisArrowFrom = null;
      _learningAnalysisPointerPosition = null;
      _learningShowAnswer = false;
    });

    _joinBoardChannel();

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (role == LearningPanelRole.teacher) {
      _syncSendFen();
      _syncSendEditMode(_editMode);
    } else {
      _boardChannel?.sendBroadcastMessage(
        event: 'sync_request',
        payload: {'from': Supabase.instance.client.auth.currentUser?.id},
      );
    }
  }

  Future<void> openLearningAsStudent(
    String lessonId,
    String teacherId,
    String teacherName,
  ) async {
    _closePuzzleSettingsOverlay();

    setState(() {
      _learningTeacherId = teacherId;
      _learningTeacherName = teacherName;
      _learningInvitationStatus = 'Урок с учителем $teacherName подключён';
    });

    await _activateLearningSession(
      lessonId: lessonId,
      role: LearningPanelRole.student,
    );
  }

  void openPuzzlesPanel() {
    // Окно «Задачи» — отдельный режим ученика.
    // Если было открыто окно «Настройка», закрываем его, чтобы эталонные
    // стрелки/кружки тренера не оставались на доске и не управлялись
    // кнопками ученика.
    _closePuzzleSettingsOverlay();

    setState(() {
      _showPuzzlePanel = true;
      _showLearningPanel = false;
      _mobilePanel = 'puzzles';
      _learningRole = LearningPanelRole.none;

      // Полностью гасим режим тренера на доске, но НЕ удаляем данные эталона.
      _activeAnalysisArrowKey = null;
      _pendingAnalysisArrowFrom = null;
      _analysisPointerPosition = null;
      _showPuzzleAnswerArrows = false;
      _hiddenPuzzleAnalysisKinds.clear();

      // Оставляем ученика в чистом режиме без активного рисования.
      _studentAnalysisArrowKey = null;
      _studentPendingAnalysisArrowFrom = null;
      _studentAnalysisPointerPosition = null;
      _studentShowPuzzleAnswer = false;

      _learningAnalysisArrowKey = null;
      _learningPendingAnalysisArrowFrom = null;
      _learningAnalysisPointerPosition = null;
      _learningShowAnswer = false;
      _learningDrawingEnabled = false;
    });
  }

  void openLearningPanel() {
    _closePuzzleSettingsOverlay();
    unawaited(_loadLearningStudents(showError: true));

    setState(() {
      _showPuzzlePanel = false;
      _showLearningPanel = true;
      _mobilePanel = 'learning';
      _learningRole = LearningPanelRole.none;

      _activeAnalysisArrowKey = null;
      _pendingAnalysisArrowFrom = null;
      _analysisPointerPosition = null;
      _showPuzzleAnswerArrows = false;

      _studentAnalysisArrowKey = null;
      _studentPendingAnalysisArrowFrom = null;
      _studentAnalysisPointerPosition = null;
      _studentShowPuzzleAnswer = false;

      _learningAnalysisArrowKey = null;
      _learningPendingAnalysisArrowFrom = null;
      _learningAnalysisPointerPosition = null;
      _learningShowAnswer = false;
      _learningDrawingEnabled = false;
    });
  }

  Future<void> _toggleLearningStudentEvaluation() async {
    if (_learningRole != LearningPanelRole.teacher) return;

    final session = _selectedLearningGameSession;
    if (session == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Сначала ученик должен принять приглашение и подключиться к партии',
          ),
        ),
      );
      return;
    }

    final next = !session.studentEvaluationEnabled;
    setState(() {
      session.studentEvaluationEnabled = next;
      _learningStudentEvaluationEnabled = next;
    });

    try {
      final lobby = _lobby;
      if (lobby == null) {
        throw StateError('Лобби не подключено');
      }

      // Важно: это не изменение интерфейса учителя.
      // Команда адресуется по ID только выбранному ученику и приходит
      // по тому же каналу, по которому ученик получил приглашение в игру.
      await lobby.sendLearningUiControl(
        toUserId: session.student.id,
        command: 'student_eval',
        data: <String, dynamic>{
          'enabled': next,
          'roomId': session.roomId,
          'studentId': session.student.id,
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        session.studentEvaluationEnabled = !next;
        _learningStudentEvaluationEnabled = !next;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить оценку позиции: $error')),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          next
              ? 'Оценка позиции для ${session.student.nickname} включена'
              : 'Оценка позиции для ${session.student.nickname} выключена',
        ),
      ),
    );
  }

  void openLobbyPanel() {
    setState(() {
      _showPuzzlePanel = false;
      _showLearningPanel = false;
      _mobilePanel = 'lobby';
      _learningRole = LearningPanelRole.none;
    });
  }

  void openBoardOnly() {
    setState(() {
      _showPuzzlePanel = false;
      _showLearningPanel = false;
      _mobilePanel = 'none';
      _learningRole = LearningPanelRole.none;
    });
  }

  void openMobileGamePanel() {
    setState(() {
      _showPuzzlePanel = false;
      _showLearningPanel = false;
      _mobilePanel = 'game';
      _learningRole = LearningPanelRole.none;
    });
  }

  void openMobileRightPanel() {
    setState(() {
      _showPuzzlePanel = false;
      _showLearningPanel = false;
      _mobilePanel = 'moves';
      _learningRole = LearningPanelRole.none;
    });
  }

  void openMobileChatPanel() {
    setState(() {
      _showPuzzlePanel = false;
      _showLearningPanel = false;
      _mobilePanel = 'chat';
      _learningRole = LearningPanelRole.none;
    });
  }

  bool _loading = false;
  bool _engineDuel = false;
  bool _gptLoading = false;

  double _engineEval = 0.0; // диапазон для ползунка: -15 .. +15
  bool _loadingEval = false;
  int _evalRequestEpoch = 0;
  String? _lastEvalScheduledFen;

  // engine
  bool _vsEngine = false;
  bool _engineThinking = false;
  ch.Color _humanColor = ch.Color.WHITE;

// --- Board Editor state ---
  bool _editMode = false; // включён ли редактор
  List<List<String>> _editBoard =
      List.generate(8, (_) => List.filled(8, '.')); // 8×8, '.' = пусто
  ch.Color _editTurn = ch.Color.WHITE; // чей ход в редакторе
  bool _castleK = false, _castleQ = false, _castlek = false, _castleq = false;

  String? _dragFromSquare;

  /// из кода палитры ('wK','wQ','wR','wB','wN','wP','bK','bQ','bR','bB','bN','bP')
  /// в символ FEN ('K','Q','R','B','N','P','k','q','r','b','n','p')

  /// из FEN-символа обратно в код палитры (нужно, чтобы тащить фигуру С ДОСКИ)

  int _fileIndex(String s) =>
      s.codeUnitAt(0) - 'a'.codeUnitAt(0); // a..h -> 0..7
  int _rankIndex(String s) => 8 - int.parse(s[1]); // '8'..'1' -> 0..7

  List<List<String>> _fenToBoard(String fen) {
    final board = List.generate(8, (_) => List.filled(8, '.'));
    final rows = fen.split(' ')[0].split('/');
    for (int r = 0; r < 8; r++) {
      int c = 0;
      for (final chx in rows[r].split('')) {
        final d = int.tryParse(chx);
        if (d != null) {
          for (int k = 0; k < d; k++) board[r][c++] = '.';
        } else {
          board[r][c++] = chx;
        }
      }
    }
    return board;
  }

  String _boardToFen() {
    final ranks = <String>[];
    for (int r = 0; r < 8; r++) {
      int empties = 0;
      final row = StringBuffer();
      for (int c = 0; c < 8; c++) {
        final p = _editBoard[r][c];
        if (p == '.') {
          empties++;
        } else {
          if (empties > 0) {
            row.write(empties);
            empties = 0;
          }
          row.write(p);
        }
      }
      if (empties > 0) row.write(empties);
      ranks.add(row.toString());
    }
    final castle = [
      if (_castleK) 'K',
      if (_castleQ) 'Q',
      if (_castlek) 'k',
      if (_castleq) 'q',
    ].join();
    final castleStr = castle.isEmpty ? '-' : castle;
    final turnStr = _editTurn == ch.Color.WHITE ? 'w' : 'b';
    return '${ranks.join('/')} $turnStr $castleStr - 0 1';
  }

  String? _assetForFenChar(String ch) {
    if (ch == '.') return null;
    final isWhite = ch.toUpperCase() == ch;
    final letter = ch.toUpperCase(); // KQRBNP
    return _assetFor('${isWhite ? 'w' : 'b'}$letter');
  }

  bool get _isFlipped => _humanColor == ch.Color.BLACK;

  int _engineEpoch = 0; // счётчик для отмены "висящих" ответов движка

  // history
  final List<String> _sanMoves = [];
  final List<String> _fens = [];
  int _plyIndex = 0;

  // tap-to-move
  String? _selectedSquare;
  Set<String> _legalTargets = {};
  Set<String> _captureTargets = {};
  final ScrollController _movesScroll = ScrollController();

  // board scale
  static const double _baseAt100 = 560.0;
  static const double _minPercent = 50.0;
  static const double _maxPercent = 200.0;
  static const double _stepPercent = 5.0;
  double _boardPercent = 100.0;
  bool _showFenInput = false;
  void _saveBoardPercent() {
    try {
      writeLocalStorage('board_percent', _boardPercent.toStringAsFixed(0));
    } catch (_) {}
  }

  void _onAcceptCallPressed() {
    // Здесь подключи вашу логику принятия звонка, если она есть.
    // Временный stub — просто покажем подсказку, чтобы кнопка не была пустой.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Принять звонок: действие')),
    );
  }

  Future<void> _logout() async {
    try {
      await _leaveLobby();
    } catch (e) {
      debugPrint('[LOBBY AUTO] Ошибка выхода из лобби: $e');
    }

    try {
      await _disposeLearningPresence();
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _nickname = null;
      _learningStudents.clear();
      for (final session in _learningGameSessions.values) {
        session.dispose();
      }
      _learningGameSessions.clear();
      _pendingLearningGameInvites.clear();
      _learningFocusedStudentId = null;
      _learningShowAllBoards = false;
      _selectedLearningStudentId = null;
      _confirmedLearningStudentId = null;
      _learningInvitationStatus = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вы вышли из аккаунта')),
      );
    }
  }

  void _setBoardPercent(double p) {
    setState(() {
      _boardPercent = p.clamp(_minPercent, _maxPercent);
    });
    _saveBoardPercent();
  }

  void _changeBoardPercent(double delta) {
    _setBoardPercent(_boardPercent + delta);
  }

  void _resetBoardPercent() {
    _setBoardPercent(100.0);
  }

// --- Публичные мостики для шапки ---
  void changeBoardPercent(double delta) => _changeBoardPercent(delta);
  void resetBoardPercent() => _resetBoardPercent();
  double get boardPercentValue => _boardPercent;

  double readBoardPercent() => _boardPercent;

  void openAuthPanel() {
    if (!mounted) return;
    setState(() {
      _authOpen = true;
    });
  }

  // audio
  final AudioPlayer _player = AudioPlayer();

  // auth panel
  // auth panel
  bool _authOpen = false;
  ModalRoute<dynamic>? _lastHandledAuthRoute;
  bool _authIsLogin = true;
  final _passCtl = TextEditingController();
  final _nickCtl = TextEditingController();
  String? _authError;
  String? _nickname;

  // realtime
  LobbyService? _lobby;
  bool _autoLobbyConnecting = false;
  RoomService? _room;
  String? _roomId;
  String? _opponentId;
  String? _opponentName;
  bool get _inRoom => _roomId != null;
  bool _isSpectator = false;

  // Истина только на стороне ученика, если игровая комната открыта
  // приглашением из панели «Учиться».
  bool _activeRoomIsLearning = false;

  // Надёжный признак именно ученической школьной партии. Он не зависит
  // от того, сохранился ли служебный флаг приглашения после открытия комнаты.
  bool get _studentLearningRoomActive =>
      _inRoom &&
      !_isSpectator &&
      _showLearningPanel &&
      _learningRole == LearningPanelRole.student;

  // room chat
  final List<_ChatMsg> _chat = [];
  final TextEditingController _chatCtl = TextEditingController();

  // draw/resign/rematch state
  bool _drawOfferedByMe = false;
  bool _drawOfferedToMe = false;
  bool _rematchOfferedByMe = false;
  bool _rematchOfferedToMe = false;
  bool _inviteDialogOpen = false;
  bool _gameTerminated = false;

  // time control
  int _tcMinutes = 5;
  int _tcIncrement = 3;
  int _whiteMs = 0;
  int _blackMs = 0;
  Timer? _tick;
  DateTime? _lastTickAt;
  DateTime? _lastClockCastAt; // для редкой рассылки clock снапшота
  bool _rated = true;
  bool _matchRated = true; // фиксируем режим для матча при старте онлайна
  bool _clocksStarted = false; // до первого хода false

  // «владелец тика» — только он шлёт снапшоты clock
  bool get _iAmClockAuthority =>
      _inRoom && !_isSpectator && (game.turn == _humanColor);

  // ratings
  int _myRating = 1200;
  int _oppRating = 1200;
  int _myGames = 0;
  int _oppGames = 0;

  // autorc
  static const _LS_ROOM = 'room_restore';

  // ================== lifecycle ==================
  @override
  void initState() {
    super.initState();

    // Flutter Web: отключаем стандартное меню браузера,
    // чтобы правая кнопка мыши удаляла стрелки/кружки на доске.
    BrowserContextMenu.disableContextMenu();

// === загрузим сохранённый фон и начнём слушать изменения ===
    bgController.load().then((_) {
      if (!mounted) return;
      setState(() {
        _backgroundBytes = bgController.bgBytes;
      });
    });
    bgController.addListener(_onBgChanged);
    _backgroundBytes = bgController.bgBytes;
    try {
      final s = readLocalStorage('board_percent');
      if (s != null) {
        final p = double.tryParse(s);
        if (p != null) {
          _boardPercent = p.clamp(_minPercent, _maxPercent);
        }
      }
    } catch (_) {}

    _fens.add(game.fen);
    _plyIndex = 0;
    _loadNickname().then((_) async {
      await _loadLearningStudents();
      await _enterLobbyAutomatically();
      await _tryRestoreRoom();
    });
    _duelDelayCtl = TextEditingController(text: _engineDuelDelayMs.toString());
    _startLessonResponseListener();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshEvalBar();
    });

// Показ стартового окна один раз после первого кадра
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    final args = route?.settings.arguments;

    if (route != null &&
        args is Map &&
        args['openAuth'] == true &&
        !_authOpen &&
        _lastHandledAuthRoute != route) {
      _lastHandledAuthRoute = route;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _authOpen = true);
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _movesScroll.dispose();
    _chatCtl.dispose();
    _stopTick();
    _room?.disconnect();
    _lobby?.disconnect();
    for (final session in _learningGameSessions.values) {
      session.dispose();
    }
    _learningGameSessions.clear();
    _pendingLearningGameInvites.clear();
    unawaited(_disposeLearningPresence());
    _closePuzzleSettingsOverlay();
    _duelDelayCtl.dispose();
    _lessonResponseSub?.cancel();
    _lessonResponseSub = null;
    unawaited(_classroomVideoCall?.stop() ?? Future<void>.value());
    _classroomVideoCall = null;

    // >>> освобождаем контроллер для GPT-подсказки
    _gptPromptCtl.dispose();
    bgController.removeListener(_onBgChanged);

    // Возвращаем стандартное контекстное меню при уничтожении экрана.
    BrowserContextMenu.enableContextMenu();

    super.dispose();
  }

  // --- СОВМЕСТНОЕ РЕДАКТИРОВАНИЕ ДОСКИ (FEN sync через Supabase Realtime) ---
  bool _syncBoard = false;
  RealtimeChannel? _boardChannel;
  bool _sharedControl = false; // общий контроль: можно ходить любыми фигурами

  bool _syncEditor = false;
  String? get _syncRoomId => _learningLessonId ?? _roomId;
  bool _applyingRemoteFen = false; // защита от «эхо» при приёме FEN

// подхватываем текущую комнату, если есть

  void _joinBoardChannel() {
    final roomId = _syncRoomId;
    if (roomId == null || roomId.isEmpty) return;
    _leaveBoardChannel();
    _boardChannel = Supabase.instance.client.channel('board:$roomId');

    _boardChannel!
      // поток FEN (и ходы, и «живые» правки из редактора)
      ..onBroadcast(
        event: 'fen',
        callback: (payload, [ref]) {
          if (!_syncBoard) return;
          final fen = payload['fen'] as String?;
          if (fen == null || fen == game.fen) return;

          _applyingRemoteFen = true; // ← ставим флаг до применения
          setState(() {
            final ok = game.load(fen);
            if (ok) {
              _fenController.text = game.fen;
              _sanMoves.clear();
              _fens
                ..clear()
                ..add(game.fen);
              _plyIndex = 0;
              _selectedSquare = null;
              _legalTargets.clear();
              _captureTargets.clear();
              _result = null;
              // _editMode не трогаем
            }
          });
          _applyingRemoteFen = false; // ← снимаем флаг после применения
        },
      )

      // синхрон включения/выключения «Редактор»
      ..onBroadcast(
        event: 'edit_mode',
        callback: (payload, [ref]) {
          final on = payload['on'] == true;
          setState(() {
            _editMode = on;
          });
        },
      )
      ..onBroadcast(
        event: 'edit_mode',
        callback: (payload, [ref]) {
          final on = payload['on'] == true;
          setState(() {
            _editMode = on;
          });
        },
      )
      ..onBroadcast(
        event: 'student_eval',
        callback: (payload, [ref]) {
          final enabled = payload['enabled'] == true;
          if (!mounted) return;
          setState(() {
            _learningStudentEvaluationEnabled = enabled;
          });
        },
      )
      ..onBroadcast(
        event: 'sync_request',
        callback: (payload, [ref]) {
          if (!_syncBoard || _learningRole != LearningPanelRole.teacher) {
            return;
          }
          _syncSendFen();
          _syncSendEditMode(_editMode);
          _boardChannel?.sendBroadcastMessage(
            event: 'student_eval',
            payload: {'enabled': _learningStudentEvaluationEnabled},
          );
        },
      )
      ..subscribe();
  }

  void _leaveBoardChannel() {
    if (_boardChannel != null) {
      Supabase.instance.client.removeChannel(_boardChannel!);
      _boardChannel = null;
    }
  }

  void _toggleSyncBoard() {
    setState(() {
      _syncBoard = !_syncBoard;
      _sharedControl = _syncBoard; // общий контроль вместе с режимом
      _syncEditor = _syncBoard; // ← включаем синхрон редактора вместе с режимом
    });
    if (_syncBoard) {
      if (_boardChannel == null) {
        _joinBoardChannel();
      }
      _syncSendFen(); // выровнять позицию
      _syncSendEditMode(_editMode); // разослать текущее состояние редактора
    }
  }

  void _syncSendFen() {
    final ch = _boardChannel;
    if (!_syncBoard || ch == null) return;
    ch.sendBroadcastMessage(
      event: 'fen',
      payload: {'fen': game.fen},
    );
  }

// «Живое» превью из редактора (без применения к game)
  void _syncSendEditFen() {
    final ch = _boardChannel;
    if (!_syncEditor || ch == null) return; // только при совместном режиме
    final fen = _boardToFen();
    ch.sendBroadcastMessage(event: 'fen', payload: {'fen': fen});
  }

// Синхрон состояния редактора (вкл/выкл)
  void _syncSendEditMode(bool on) {
    final ch = _boardChannel;
    if (!_syncBoard || ch == null) return; // только при совместном режиме
    ch.sendBroadcastMessage(event: 'edit_mode', payload: {'on': on});
  }

  // ================== helpers & services ==================

  String _opposite(String c) => c.toLowerCase() == 'white' ? 'black' : 'white';

  Future<void> _playSound({required bool capture}) async {
    try {
      final name = capture ? 'sfx/capture.mp3' : 'sfx/move.mp3';
      await _player.play(AssetSource(name));
    } catch (_) {}
  }

  String _assetFor(String code) => 'assets/pieces/cburnett/$code.svg';
  String _codeFor(ch.Piece p) {
    final c = p.color == ch.Color.WHITE ? 'w' : 'b';
    switch (p.type) {
      case ch.PieceType.PAWN:
        return '${c}P';
      case ch.PieceType.KNIGHT:
        return '${c}N';
      case ch.PieceType.BISHOP:
        return '${c}B';
      case ch.PieceType.ROOK:
        return '${c}R';
      case ch.PieceType.QUEEN:
        return '${c}Q';
      case ch.PieceType.KING:
        return '${c}K';
      default:
        return '${c}P';
    }
  }

  String? _unicodeForFen(String ch) {
    switch (ch) {
      case 'K':
        return '♔';
      case 'Q':
        return '♕';
      case 'R':
        return '♖';
      case 'B':
        return '♗';
      case 'N':
        return '♘';
      case 'P':
        return '♙';
      case 'k':
        return '♚';
      case 'q':
        return '♛';
      case 'r':
        return '♜';
      case 'b':
        return '♝';
      case 'n':
        return '♞';
      case 'p':
        return '♟';
      default:
        return null; // пусто
    }
  }

// fen -> код для ассета, и обратно
  String? _pieceCodeFromFen(String fenCh) {
    if (fenCh == '.') return null;
    final isWhite = fenCh.toUpperCase() == fenCh;
    final letter = fenCh.toUpperCase(); // KQRBNP
    return '${isWhite ? 'w' : 'b'}$letter'; // напр. wK, bP
  }

  String _fenFromPieceCode(String code) {
    // code: 'wK','bQ', ... 'wP','bP'
    final isWhite = code[0] == 'w';
    final letter = code[1].toUpperCase();
    return isWhite ? letter : letter.toLowerCase();
  }

  // ============ Auth / profiles ============
  String? _validateSupabaseUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return 'supabaseUrl пустой.';
    final parsed = Uri.tryParse(u);
    if (parsed == null || !parsed.hasScheme || !u.startsWith('https://')) {
      return 'supabaseUrl должен начинаться с https://';
    }
    if (parsed.host.isEmpty) {
      return 'supabaseUrl должен содержать .supabase.co (или .supabase.in).';
    }
    return null;
  }

  String? _validateAnonKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return 'supabaseAnonKey пустой.';
    final parts = k.split('.');
    if (parts.length < 3) return 'supabaseAnonKey должен быть JWT.';
    return null;
  }

  String _diagnoseError(Object e) {
    final s = e.toString();
    if (s.contains('XMLHttpRequest') && s.contains('Invalid URL')) {
      final urlErr = _validateSupabaseUrl(supabaseUrl);
      final keyErr = _validateAnonKey(supabaseAnonKey);
      final hints = <String>[
        'Неверная конфигурация Supabase.',
        if (urlErr != null) '• $urlErr',
        if (keyErr != null) '• $keyErr',
      ];
      return hints.join('\n');
    }
    if (s.contains('AuthApiError') || s.contains('AuthException')) {
      return 'Ошибка авторизации: ${s.replaceAll(RegExp(r'^(Exception: )?'), '')}';
    }
    return s;
  }

  Future<void> _continueVsEngine() async {
    // в онлайне/для зрителя не включаем ИИ
    if (_inRoom || _isSpectator) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сначала выйдите из онлайна (комнаты)')),
        );
      }
      return;
    }

    // если уже включён — просто подсказка и выходим
    if (_vsEngine) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Режим против компьютера уже включён')),
        );
      }
      return;
    }

    // включаем ИИ, позицию НЕ трогаем
    setState(() {
      _vsEngine = true;
      _engineThinking = false;
    });

    // если смотрим не последний полуход — перейдём в конец истории
    if (_plyIndex != _sanMoves.length) {
      _goEnd();
    }

    // если сейчас очередь ИИ — пусть он подумает и сделает ход
    if (!game.game_over && game.turn != _humanColor) {
      await _engineMove();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Режим против компьютера включён')),
      );
    }
  }

  void _syncLobbyStoreFromLobby() {
    // Если лобби ещё не создано/подключено — просто очистим шину
    if (_lobby == null) {
      LobbyStore.instance.clear();
      return;
    }

    final meId = Supabase.instance.client.auth.currentUser?.id ?? '';

    // _lobby!.online — твой текущий список онлайна
    final online =
        _lobby!.online; // ожидаем List<Map<String, dynamic>> или схожее

    final users = online.map<LobbyUser>((u) {
      // Берём поля максимально безопасно, приводим к строкам
      final id = (u['id'] ?? u['userId'] ?? '').toString();
      final username = (u['username'] ?? u['name'] ?? 'player').toString();

      final ratingStr = (u['rating'] ?? u['elo'])?.toString();
      final rating = ratingStr == null ? null : int.tryParse(ratingStr);

      return LobbyUser(
        id: id,
        username: username,
        rating: rating,
        isMe: id == meId,
      );
    }).toList();

    LobbyStore.instance.set(users);
  }

  Future<void> _continueVsHuman() async {
    // в онлайне/для зрителя не включаем пас-энд-плей
    if (_inRoom || _isSpectator) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сначала выйдите из онлайна (комнаты)')),
        );
      }
      return;
    }

    // если ИИ уже выключен — подсказка и выходим
    if (!_vsEngine) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Режим против компьютера уже выключен')),
        );
      }
      return;
    }

    setState(() {
      _vsEngine = false; // выключили ИИ
      _engineThinking = false; // сброс индикатора
      _engineEpoch++; // отменяем любой «висящий» ответ движка
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Игра с человеком на одном устройстве')),
      );
    }
  }

  Future<void> _loadNickname() async {
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _nickname = null);
      return;
    }
    try {
      final row = await supa
          .from('profiles')
          .select('nickname, rating, games_played')
          .eq('id', uid)
          .maybeSingle();
      setState(() {
        _nickname = (row?['nickname'] as String?) ?? 'player';
        _myRating = (row?['rating'] as int?) ?? 1200;
        _myGames = (row?['games_played'] as int?) ?? 0;
      });
    } catch (_) {}
  }

  String _synthEmailFromNick(String nick) =>
      '${nick.trim().toLowerCase()}@noemail.local';
  final RegExp _nickRx = RegExp(r'^[a-z0-9_]{3,20}$');

  Future<bool> _isNickAvailable(SupabaseClient supa, String nick) async {
    final row = await supa
        .from('profiles')
        .select('nickname')
        .ilike('nickname', nick)
        .maybeSingle();
    return row == null;
  }

  Future<void> _signUpWithNick(
      {required String nickname, required String password}) async {
    final supa = Supabase.instance.client;
    final nick = nickname.trim().toLowerCase();

    if (!_nickRx.hasMatch(nick)) {
      throw AuthException('Ник: 3–20 символов, латиница/цифры/_ .');
    }
    if (!await _isNickAvailable(supa, nick)) {
      throw AuthException('Ник уже занят.');
    }

    final email = _synthEmailFromNick(nick);
    final res = await supa.auth.signUp(email: email, password: password);
    final uid = res.user?.id ?? supa.auth.currentUser?.id;
    if (uid == null) throw AuthException('Регистрация не завершилась.');
    await supa.from('profiles').upsert(
        {'id': uid, 'nickname': nick, 'rating': 1200, 'games_played': 0},
        onConflict: 'id');
  }

  Future<void> _signInWithNick(
      {required String nickname, required String password}) async {
    final supa = Supabase.instance.client;
    final email = _synthEmailFromNick(nickname);
    await supa.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> _submitAuth() async {
    setState(() => _authError = null);
    final uname = _nickCtl.text.trim().toLowerCase();
    final pass = _passCtl.text;

    final uErr = _validateSupabaseUrl(supabaseUrl);
    final keyErr = _validateAnonKey(supabaseAnonKey);
    if (uErr != null || keyErr != null) {
      final msg = [
        'Неверная конфигурация Supabase.',
        if (uErr != null) '• $uErr',
        if (keyErr != null) '• $keyErr',
      ].join('\n');
      setState(() => _authError = msg);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    if (pass.length < 6) {
      setState(() => _authError = 'Пароль должен быть минимум 6 символов');
      return;
    }

    try {
      if (_authIsLogin) {
        await _signInWithNick(nickname: uname, password: pass);
      } else {
        await _signUpWithNick(nickname: uname, password: pass);
        await _signInWithNick(nickname: uname, password: pass);
      }
      await _loadNickname();
      await _loadLearningStudents(showError: true);
      await _enterLobbyAutomatically();
      if (mounted) setState(() => _authOpen = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  _authIsLogin ? 'Вход выполнен' : 'Регистрация выполнена')),
        );
      }
    } on AuthException catch (e) {
      final msg = _diagnoseError(e);
      setState(() => _authError = msg);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      final msg = _diagnoseError(e);
      setState(() => _authError = msg);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _openTopMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scroll) {
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              children: [
                const ListTile(
                  title: Text('Меню',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const Divider(),

                // Навигация верхней шапки (перенесено сюда для мобилки)
                ListTile(
                  leading: const Icon(Icons.sports_esports),
                  title: const Text('Играть'),
                  onTap: () {
                    Navigator.pop(ctx);
                    // TODO: навигация в ваш раздел "Играть"
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.school),
                  title: const Text('Учиться'),
                  onTap: () {
                    Navigator.pop(ctx);
                    openLearningPanel();
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.extension),
                  title: const Text('Задачи'),
                  onTap: () {
                    Navigator.pop(ctx);
                    // TODO
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.grid_view),
                  title: const Text('2×2'),
                  onTap: () {
                    Navigator.pop(ctx);
                    // TODO
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.emoji_events),
                  title: const Text('Турниры'),
                  onTap: () {
                    Navigator.pop(ctx);
                    // TODO
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Настройки'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openSettingsSheet(); // ✅ открывает модалку с настройками
                  },
                ),

                const Divider(),

                // Игровые действия (то, что у тебя было в шапке)
                ListTile(
                  leading: const Icon(Icons.smart_toy),
                  title: const Text('Игра с ИИ'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _startNewGameVsEngine();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.play_circle),
                  title: const Text('Продолжить с компьютером'),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (!_inRoom && !_vsEngine) _continueVsEngine();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.group),
                  title: const Text('Продолжить с человеком'),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (_vsEngine && !_inRoom) _continueVsHuman();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.fiber_new),
                  title: const Text('Новый игрок'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _onNewGameUniversal();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.smart_toy_outlined),
                  title: const Text('Компьютер vs Компьютер'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _startEngineDuel();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text(_editMode ? 'Выйти из редактора' : 'Редактор'),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (_inRoom && !_sharedControl) return;
                    _editMode ? _applyEditor() : _enterEditor();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.flag),
                  title: const Text('Сдаться'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _onResignPressed();
                  },
                ),

                const Divider(),

                // Масштаб — если нужно на мобилке
                ListTile(
                  leading: const Icon(Icons.zoom_out_map),
                  title: const Text('Масштаб: 100%'),
                  onTap:
                      () {}, // информативно; при желании свяжи с _boardPercent
                ),

                const Divider(),

                // Аккаунт
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Выйти из аккаунта'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _logout();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void openLearnSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx2) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (ctx3, scroll) {
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              children: [
                const ListTile(
                  title: Text('Учиться',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const Divider(height: 1),

                // 1) Реальный учитель — открывает диалог «Школы»
                ListTile(
                  leading: const Icon(Icons.school),
                  title: const Text('Школа с реальным учителем'),
                  onTap: () async {
                    Navigator.pop(ctx); // закрываем лист
                    final sb = Supabase.instance.client;

                    await showSchoolDialogNew(
                      context: ctx,
                      client: sb,
                      signaling: cls.ClassroomSignaling(
                          sb), // тот же класс, что и в classroom/*
                      schoolId: 'demo-school', // временно
                      teacherId: sb.auth.currentUser?.id ?? 'teacher_demo',
                    );
                  },
                ),

                // 2) Виртуальный учитель — заглушка
                ListTile(
                  leading: const Icon(Icons.smart_toy),
                  title: const Text('Школа с виртуальным учителем (аватар)'),
                  onTap: () {
                    Navigator.pop(ctx2);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Скоро…')),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _acceptIncomingCall() {
    // пока заглушка, сюда подключишь свой код принятия звонка
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Вызов принят")),
    );
  }

  // ============ Engine ============
  String? _extractUci(dynamic obj) {
    if (obj == null) return null;
    String? pick(dynamic v) {
      if (v is String) return v;
      if (v is Map && v['uci'] is String) return v['uci'] as String;
      if (v is Map && v['move'] is String) return v['move'] as String;
      return null;
    }

    for (final k in ['bestMove', 'best_move', 'bestmove', 'move', 'uci']) {
      if (obj is Map && obj[k] != null) {
        final s = pick(obj[k]);
        if (s != null) return s;
      }
    }
    if (obj is Map &&
        obj['variants'] is List &&
        (obj['variants'] as List).isNotEmpty) {
      final v0 = (obj['variants'] as List).first;
      final s = pick(v0);
      if (s != null) return s;
      if (v0 is Map && v0['line'] is List && v0['line'].isNotEmpty) {
        final first = v0['line'].first;
        if (first is String) return first;
      }
    }
    if (obj is Map && obj['pv'] is String) {
      final pv = (obj['pv'] as String).trim().split(RegExp(r'\s+'));
      if (pv.isNotEmpty && pv.first.length >= 4) return pv.first;
    }
    final rx = RegExp(r'\b[a-h][1-8][a-h][1-8][qrbn]?\b', caseSensitive: false);
    final text = const JsonEncoder().convert(obj);
    final m = rx.firstMatch(text);
    return m?.group(0);
  }

  Future<void> _openStockfishAnalysis() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final String fenInput = _fenController.text.trim();
      final String fen = fenInput.isEmpty ? game.fen : fenInput;

      // Берём подробный текст анализа (depth/multiPv при желании подкрути)
      final String text = await sf.getAnalysisText(
        fen,
        depth: 18,
        multiPv: 3,
      );

      if (!mounted) return;

      // Покажем аккуратно в модалке моноширинным шрифтом
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Stockfish analysis'),
          content: SingleChildScrollView(
            child: SelectableText(
              text.isEmpty ? 'Пустой ответ от анализатора.' : text,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stockfish: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _fetchUciBestMove(String fen) async {
    final saneFen = sanitizeFenEp(fen);
    final fenForApi = stripEpField(saneFen);

    try {
      final obj = await sf.getAnalysisRaw(
        fenForApi,
        depth: 18,
        multiPv: 3,
        maxThinkingTime: 2000,
      );
      final uci = _extractUci(obj);
      setState(() => _result = const JsonEncoder.withIndent('  ').convert(obj));
      return uci;
    } catch (e) {
      setState(() => _result = 'Exception: $e');
      return null;
    }
  }

  Future<void> _onExplainPressed() async {
    if (_gptLoading) return;
    setState(() => _gptLoading = true);
    try {
      final fenInput = _fenController.text.trim();
      final fen = fenInput.isEmpty ? game.fen : fenInput;

      final res = await GptExplainService.explainPosition(
        fen: fen,
        pv: List<String>.from(_sanMoves), // <— ВАЖНО: pv, не pgn
        ask: 'Кратко объясни план за сторону, которая ходит.',
      );

      if (!mounted) return;
      _showGptExplain(res); // см. п.4
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('GPT: $e')));
    } finally {
      if (mounted) setState(() => _gptLoading = false);
    }
  }

  Future<void> _explainHere({String? extraPrompt}) async {
    // 1) собираем FEN и ходы
    final String fen = game.fen; // текущая позиция
    final List<String> pv = List<String>.from(_sanMoves); // список ходов SAN

    // 2) дополнительный вопрос пользователя (если дали)
    final String ask = (extraPrompt != null && extraPrompt.trim().isNotEmpty)
        ? extraPrompt.trim()
        : 'Кратко объясни план за сторону, которая ходит.';

    try {
      // 3) запрос к облачной функции через твой сервис
      final Map<String, dynamic> res = await GptExplainService.explainPosition(
        fen: fen,
        pv: pv.isEmpty ? null : pv, // если нет ходов — не отправляем поле pv
        ask: ask,
      );

      final String? answer = res['text'] as String?;

      if (!mounted) return;

      if (answer == null || answer.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пустой ответ от GPT.')),
        );
        return;
      }

      // 4) показы2ваем ответ (можешь заменить на диалог/панель)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            answer,
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка запроса к GPT: $e')),
      );
    }
  }

  // -------------------------------
  // ВЫБОР ФОНОВОГО ИЗОБРАЖЕНИЯ
  // -------------------------------

  Future<void> _openGptPromptDialog() async {
    _gptPromptCtl.text = _lastGptPrompt ?? '';

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Вопрос к GPT'),
          content: TextField(
            controller: _gptPromptCtl,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText:
                  'Напишите, что именно объяснить/на что обратить внимание…',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx, _gptPromptCtl.text.trim());
              },
              child: const Text('Отправить'),
            ),
          ],
        );
      },
    );

    if (result == null) return; // отменили

    _lastGptPrompt = result;
    await _explainHere(extraPrompt: result);
  }

  void _showGptExplain(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => _GptExplainSheet(data: data),
    );
  }

  Future<void> _engineMove() async {
    if (!_vsEngine || _engineThinking) return;
    if (game.game_over) return;
    if (_plyIndex != _sanMoves.length) return;

    setState(() => _engineThinking = true);
    final int epoch = _engineEpoch; // запомним «эпоху» на стартe запроса

    final uci = await _fetchUciBestMove(game.fen);

    // если за это время ИИ выключили/эпоха сменилась — игнорируем ответ
    if (!_vsEngine || epoch != _engineEpoch) {
      setState(() => _engineThinking = false);
      return;
    }

    if (uci != null) {
      await _applyUciMove(uci);
      unawaited(_refreshEvalBar());
      _checkGameOver();
    }
    setState(() => _engineThinking = false);
  }

  Future<void> _engineMoveSafe({bool stopIfHighUsage = true}) async {
    try {
      await _engineMove(); // ✅ вызывать реальный ход
    } catch (e) {
      final msg = e.toString();
      final hitLimit =
          msg.contains('HIGH_USAGE') || msg.contains('Too high daily usage');

      if (hitLimit) {
        if (stopIfHighUsage && _engineDuel) {
          setState(() => _engineDuel = false);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Лимит движка (HIGH_USAGE). Дуэль остановлена. '
                'Попробуйте позже или увеличьте задержку.',
              ),
            ),
          );
        }
        return;
      }
      rethrow;
    }
  }

  // ============ History helpers ============
  void _resetToFen(String fen) {
    game.load(fen);
    _fenController.text = game.fen;
    _selectedSquare = null;
    _legalTargets.clear();
    _captureTargets.clear();

    if (_syncBoard && !_applyingRemoteFen) {
      _syncSendFen();
    }
  }

  void _setPly(int n) {
    _plyIndex = n.clamp(0, _sanMoves.length);
    _resetToFen(_fens[_plyIndex]);
    setState(() {});
    unawaited(_refreshEvalBar());
    _syncSendFen(); // ← отправляем текущий FEN второму игроку
  }

  void _goStart() => _setPly(0);
  void _goEnd() => _setPly(_sanMoves.length);
  void _goPrev() => _setPly(_plyIndex - 1);
  void _goNext() => _setPly(_plyIndex + 1);

  void _truncateFutureBranch() {
    if (_plyIndex < _sanMoves.length) {
      _sanMoves.removeRange(_plyIndex, _sanMoves.length);
      _fens.removeRange(_plyIndex + 1, _fens.length);
    }
  }

  // ============ Board helpers ============
  String _displayIndexToSquare(int index) {
    final row = index ~/ 8; // 0..7 сверху вниз
    final col = index % 8; // 0..7 слева направо
    if (_isFlipped) {
      final file = String.fromCharCode('h'.codeUnitAt(0) - col); // h..a
      final rank = row + 1; // 1..8
      return '$file$rank';
    } else {
      final file = String.fromCharCode('a'.codeUnitAt(0) + col); // a..h
      final rank = 8 - row; // 8..1
      return '$file$rank';
    }
  }

  bool _needsPromotion(String from, String to) {
    final p = game.get(from);
    if (p == null || p.type != ch.PieceType.PAWN) return false;
    final toRank = int.tryParse(to.substring(1)) ?? 0;
    if (p.color == ch.Color.WHITE && toRank == 8) return true;
    if (p.color == ch.Color.BLACK && toRank == 1) return true;
    return false;
  }

  Future<String?> _askPromotionPiece(
      BuildContext context, ch.Color color) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: true, // можно закрыть кликом вне (по желанию)
      builder: (ctx) => AlertDialog(
        title: const Text('Выберите фигуру для превращения'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final entry in {
              'q': color == ch.Color.WHITE ? '♕' : '♛',
              'r': color == ch.Color.WHITE ? '♖' : '♜',
              'b': color == ch.Color.WHITE ? '♗' : '♝',
              'n': color == ch.Color.WHITE ? '♘' : '♞',
            }.entries)
              IconButton(
                icon: Text(entry.value, style: const TextStyle(fontSize: 32)),
                onPressed: () =>
                    Navigator.of(ctx).pop(entry.key), // ← ИСПОЛЬЗУЕМ ctx!
              ),
          ],
        ),
      ),
    );
  }

  bool _willBeCapture(String from, String to) {
    try {
      final ms = List<Map<String, dynamic>>.from(
        game.moves({'square': from, 'verbose': true}),
      );
      final m = ms.firstWhere((m) => m['to'] == to, orElse: () => {});
      if (m.isEmpty) return false;
      final flags = (m['flags'] as String?) ?? '';
      return flags.contains('c') ||
          flags.contains('e') ||
          m['captured'] != null;
    } catch (_) {
      return false;
    }
  }

  String? _sanFor(String from, String to, {String? promotion}) {
    try {
      final List<Map<String, dynamic>> ms = List<Map<String, dynamic>>.from(
        game.moves({'square': from, 'verbose': true}),
      );
      for (final m in ms) {
        if (m['to'] == to) {
          final pr = m['promotion'] as String?;
          if (promotion == null || promotion == pr) return m['san'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  bool _myTurnNow() {
    if (_sharedControl) return true;
    if (_gameTerminated) return false;
    if (!_vsEngine && !_inRoom) return true;
    return game.turn == _humanColor;
  }

  Future<void> _applyUciMove(String uci) async {
    _truncateFutureBranch();
    final from = uci.substring(0, 2);
    final to = uci.substring(2, 4);
    final promo = uci.length >= 5 ? uci[4].toLowerCase() : null;

    final bool isCapture = _willBeCapture(from, to);
    final san = _sanFor(from, to, promotion: promo) ?? '$from-$to';

    final params = {
      'from': from,
      'to': to,
      if (promo != null) 'promotion': promo
    };
    final ok = game.move(params);
    if (!ok) return;

    _afterHumanMoveCommon(san, isCapture);
  }

  void _afterHumanMoveCommon(String san, bool isCapture) {
    _sanMoves.add(san);
    _fens.add(game.fen);
    _plyIndex = _sanMoves.length;

    setState(() {
      _fenController.text = game.fen;
      _selectedSquare = null;
      _legalTargets.clear();
      _captureTargets.clear();
    });

    _playSound(capture: isCapture);
    _scrollMovesToEnd();

    _onLocalMoveAffectClocks();

    _syncSendFen();
    unawaited(_refreshEvalBar());
  }

  void _scrollMovesToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_movesScroll.hasClients) {
        _movesScroll.animateTo(
          _movesScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _checkGameOver() {
    if (game.in_checkmate) {
      final winner = game.turn == ch.Color.WHITE ? "Чёрные" : "Белые";
      _finishGameWithResult(
          game.turn == ch.Color.WHITE ? '0-1' : '1-0', 'Мат: $winner победили');
      return;
    }
    if (game.in_stalemate) {
      _finishGameWithResult('1/2-1/2', 'Пат — ничья');
      return;
    }
    if (game.in_threefold_repetition) {
      _finishGameWithResult('1/2-1/2', 'Троекратное повторение — ничья');
      return;
    }
    if (game.in_draw) {
      _finishGameWithResult('1/2-1/2', 'Ничья по правилам');
      return;
    }
  }

  void _showInfo(String title, String message) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // возможно убрать
//  3/4
  // ================== TIME CONTROL ==================
  void _applyTimeControl({
    required int minutes,
    required int increment,
    required bool rated,
    bool broadcast = false,
  }) {
    final bool noTime = (minutes == 0 && increment == 0);

    setState(() {
      _tcMinutes = minutes;
      _tcIncrement = increment;
      _rated = noTime ? false : rated;
      _matchRated = noTime ? false : rated;
    });

    // если нет контроля времени — выключаем часы полностью
    if (noTime) {
      _stopTick();
      _whiteMs = 0;
      _blackMs = 0;
      _clocksStarted = false;
    } else {
      _resetClocks();
    }

    if (broadcast) _broadcastTimeControl();
    _broadcastClockSnapshot();

    if (mounted) {
      final text = noTime
          ? 'Контроль: без времени'
          : 'Контроль: $minutes+${increment}${rated ? " (рейтинговая)" : ""}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text)),
      );
    }
  }

  void _resetClocks() {
    final ms = _tcMinutes * 60 * 1000;
    _whiteMs = ms;
    _blackMs = ms;
    _lastTickAt = null;
    _lastClockCastAt = _lastClockCastAt = null;
    _clocksStarted = false; // ещё не идут до первого хода
    _stopTick();
    // не запускаем тик до первого хода
  }

  void _startTickForActiveSide() {
    _stopTick();

    // ← РЕЖИМ «БЕЗ КОНТРОЛЯ ВРЕМЕНИ»: минуты=0 и инкремент=0 — не тикаем
    if (_tcMinutes == 0 && _tcIncrement == 0) {
      _clocksStarted = false;
      return;
    }

    if (!_inRoom) return;
    if (_gameTerminated) return;

    _lastTickAt = DateTime.now();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final now = DateTime.now();
      final delta = now.difference(_lastTickAt!).inMilliseconds;
      _lastTickAt = now;

      setState(() {
        if (game.turn == ch.Color.WHITE) {
          _whiteMs = (_whiteMs - delta).clamp(0, 1 << 31);
          if (_whiteMs <= 0) _onFlagFall(ch.Color.WHITE);
        } else {
          _blackMs = (_blackMs - delta).clamp(0, 1 << 31);
          if (_blackMs <= 0) _onFlagFall(ch.Color.BLACK);
        }
      });
    });
  }

  void _stopTick() {
    _tick?.cancel();
    _tick = null;
    _lastTickAt = null;
  }

  void _switchTurnAndApplyIncrement(ch.Color movedColor) {
    if (_tcIncrement > 0) {
      if (movedColor == ch.Color.WHITE) {
        _whiteMs += _tcIncrement * 1000;
      } else {
        _blackMs += _tcIncrement * 1000;
      }
    }
    _startTickForActiveSide();
  }

  void _onFlagFall(ch.Color flagSide) {
    final result = (flagSide == ch.Color.WHITE) ? '0-1' : '1-0';
    final reason =
        (flagSide == ch.Color.WHITE) ? 'Победа черных' : 'Победа белых';
    _finishGameWithResult(result, reason);
  }

  String _fmtMs(int ms) {
    final s = (ms / 1000).floor();
    final m = s ~/ 60;
    final sec = s % 60;
    final pad = (sec < 10) ? '0$sec' : '$sec';
    return '$m:$pad';
  }

  // ================== ONLINE: Lobby & Room ==================

  void _syncLobbyStoreFromOnline() {
    final meId = Supabase.instance.client.auth.currentUser?.id ?? '';

    // берем онлайн именно из лобби-сервиса
    final List<Map<String, String>> online = _lobby?.online ?? const [];

    final users = online.map((u) {
      final id = u['id'] ?? '';
      final name = u['username'] ?? 'player';
      final ratingStr = u['rating'];
      final rating = ratingStr == null ? null : int.tryParse(ratingStr);
      return LobbyUser(
        id: id,
        username: name,
        rating: rating,
        isMe: id == meId,
      );
    }).toList();

    LobbyStore.instance.set(users);
  }

  Future<void> _enterLobbyAutomatically() async {
    final supa = Supabase.instance.client;

    if (_autoLobbyConnecting || _lobby != null) return;
    if (supa.auth.currentUser == null || _nickname == null) return;

    _autoLobbyConnecting = true;
    try {
      await _enterLobby(showMessage: false);
    } catch (e, st) {
      debugPrint('[LOBBY AUTO] Не удалось автоматически войти в лобби: $e');
      debugPrintStack(stackTrace: st);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Аккаунт открыт, но автоматическое подключение к контактам не удалось',
            ),
          ),
        );
      }
    } finally {
      _autoLobbyConnecting = false;
    }
  }

  Future<void> _enterLobby({bool showMessage = true}) async {
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;
    if (uid == null || _nickname == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала войдите в аккаунт')),
      );
      return;
    }

    if (_lobby == null) {
      final lobby = LobbyService(
        supa,
        username: _nickname!,
        userId: uid,
        myRating: _myRating,
      );

      // когда онлайн-список изменился — перерисовать UI и синхронизировать в шину
      lobby.onOnlineChanged = () {
        if (!mounted) return;
        setState(() {});
        _syncLobbyStoreFromOnline(); // <<< добавили
      };

      lobby.onInvite = (roomId, fromId, fromName, inviterColor, m, inc, rated,
          inviteKind) async {
        final isLearningInvite = inviteKind == 'learning';
        final schoolModeActive =
            _showLearningPanel && _learningRole != LearningPanelRole.none;
        if (isLearningInvite && _learningRole != LearningPanelRole.student) {
          return;
        }
        if (!isLearningInvite && schoolModeActive) {
          return;
        }
        if (_inviteDialogOpen) return;
        _inviteDialogOpen = true;

        try {
          final ok = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogCtx) => AlertDialog(
              title: Text(
                isLearningInvite ? 'Приглашение от учителя' : 'Вызов на игру',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$fromName приглашает вас сыграть\n'
                    'Контроль: $m+${inc}${rated ? " (рейтинговая)" : ""}',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('Отклонить'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  child: const Text('Принять'),
                ),
              ],
            ),
          );

          if (ok == true) {
            if (isLearningInvite && mounted) {
              setState(() {
                _learningTeacherId = fromId;
                _learningTeacherName = fromName;
                _learningInvitationStatus =
                    'Партия с учителем $fromName подключена';
              });
            }
            _applyTimeControl(
                minutes: m, increment: inc, rated: rated, broadcast: false);
            _matchRated = rated;

            final myColor = _opposite(inviterColor);
            await lobby.sendAccept(
              toUserId: fromId,
              toName: fromName,
              roomId: roomId,
              color: myColor,
            );

            await _openRoom(
              roomId,
              opponentId: fromId,
              opponentName: fromName,
              myColor: myColor,
              spectator: false,
              learningRoom: isLearningInvite,
            );
          }
        } finally {
          _inviteDialogOpen = false;
        }
      };

      lobby.onAccept = (roomId, fromId, fromName, acceptorColor) {
        final pending = _pendingLearningGameInvites.remove(roomId);
        if (pending != null) {
          unawaited(
            _openLearningGameRoom(
              roomId: roomId,
              studentId: pending.student.id,
              studentName: pending.student.nickname,
              myColor: _opposite(acceptorColor),
              minutes: pending.minutes,
              increment: pending.increment,
              rated: pending.rated,
            ),
          );
          return;
        }

        final myColor = _opposite(acceptorColor);
        _openRoom(roomId,
            opponentId: fromId,
            opponentName: fromName,
            myColor: myColor,
            spectator: false);
      };

      lobby.onLearningUiControl = (event) {
        if ('${event['command'] ?? ''}' != 'student_eval') return;

        final currentUserId =
            Supabase.instance.client.auth.currentUser?.id ?? '';
        final targetUserId = '${event['to'] ?? ''}';
        if (currentUserId.isEmpty || targetUserId != currentUserId) return;

        // Команда относится только к текущей учебной партии этого ученика.
        final eventRoomId = '${event['roomId'] ?? ''}';
        if (eventRoomId.isNotEmpty &&
            _roomId != null &&
            eventRoomId != _roomId) {
          return;
        }

        final enabled = event['enabled'] == true;
        if (!mounted) return;
        setState(() {
          _learningStudentEvaluationEnabled = enabled;
          if (_roomId != null) {
            _activeRoomIsLearning = true;
          }
        });

        if (enabled) {
          unawaited(_refreshEvalBar());
        }
      };

      _lobby = lobby;
    }

    await _lobby!.connect();

    _joinBoardChannel();

    // Сразу после подключения синхронизируем текущий список в шину
    _syncLobbyStoreFromOnline(); // <<< добавили

    if (mounted && showMessage) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Вы в контактах')));
    }
  }

  Future<void> _leaveLobby() async {
    _leaveBoardChannel();
    await _lobby?.disconnect();

    _lobby = null; // << чтобы не держать старую ссылку
    LobbyStore.instance
        .clear(); // << сначала чистим шину (модалка увидит пусто)
    if (mounted) setState(() {}); // << затем перерисовываем UI
  }

  Future<void> _invitePlayer(String id, String name) async {
    // если не в лобби — подключаемся
    if (_lobby == null) {
      await _enterLobby();
      if (_lobby == null) {
        debugPrint('[INVITE] _lobby == null после _enterLobby()');
        return;
      }
    }

    // 1) выбор цвета (важно: использовать dialogCtx для Navigator.pop)
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Выбор цвета'),
        content: const Text('Кем хотите играть?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop('random'),
            child: const Text('Случайный'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop('white'),
            child: const Text('Белыми'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop('black'),
            child: const Text('Чёрными'),
          ),
        ],
      ),
    );
    if (choice == null) {
      debugPrint('[INVITE] Отмена на выборе цвета');
      return;
    }

    String myColor = choice;
    if (myColor == 'random') {
      myColor = (math.Random().nextBool()) ? 'white' : 'black';
    }
    debugPrint('[INVITE] Цвет выбран: $myColor');

    // 2) диалог контроля (наш _TcDialog — отдельный виджет, он ок)
    final pickedTc = await showDialog<_TcChoice>(
      context: context,
      builder: (_) => _TcDialog(
        initialMinutes: _tcMinutes,
        initialIncrement: _tcIncrement,
        initialRated: _matchRated,
      ),
    );
    if (pickedTc == null) {
      debugPrint('[INVITE] Отмена в диалоге контроля');
      return;
    }
    debugPrint(
        '[INVITE] Контроль: ${pickedTc.minutes}+${pickedTc.increment}, rated=${pickedTc.rated}');

    // применим локально (без рассылки)
    _applyTimeControl(
      minutes: pickedTc.minutes,
      increment: pickedTc.increment,
      rated: pickedTc.rated,
      broadcast: false,
    );
    _matchRated = pickedTc.rated;

    // 3) гарантируем подключение канала (если отвалился)

    _lobby!.sendPresenceNow();

    final roomId = const Uuid().v4();

    // 4) отправка инвайта
    try {
      debugPrint('[INVITE] sendInvite → to=$id, room=$roomId, color=$myColor');
      await _lobby!.sendInvite(
        toUserId: id,
        toName: name,
        roomId: roomId,
        color: myColor,
        minutes: pickedTc.minutes,
        increment: pickedTc.increment,
        rated: pickedTc.rated,
      );
      debugPrint('[INVITE] sendInvite DONE');

      if (!mounted) return;
      final colorLabel = (myColor == 'white') ? 'белые' : 'чёрные';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Приглашение отправлено: $name ($colorLabel), '
            'контроль ${pickedTc.minutes}+${pickedTc.increment}'
            '${pickedTc.rated ? " рейтинговая" : ""}',
          ),
        ),
      );
    } catch (e) {
      debugPrint('[INVITE] sendInvite ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось отправить приглашение: $e')),
        );
      }
    }
  }

  Future<void> _openLearningGameRoom({
    required String roomId,
    required String studentId,
    required String studentName,
    required String myColor,
    required int minutes,
    required int increment,
    required bool rated,
  }) async {
    final oldSession = _learningGameSessions.remove(studentId);
    oldSession?.dispose();

    final room = RoomService(Supabase.instance.client, roomId: roomId);
    final session = _LearningGameSession(
      student: LearningStudent(id: studentId, nickname: studentName),
      roomId: roomId,
      myColor: myColor,
      minutes: minutes,
      increment: increment,
      rated: rated,
      room: room,
    );

    room.onMove = (payload) {
      final incomingRoomId = '${payload['roomId'] ?? ''}';
      if (incomingRoomId.isNotEmpty && incomingRoomId != session.roomId) return;
      if ('${payload['kind'] ?? ''}' == 'learning_ctrl') {
        debugPrint(
            '[LEARNING CTRL][teacher] ${payload['type']} room=${session.roomId}');
        _onLearningRemoteCtrl(session, payload);
        return;
      }
      _applyLearningRemoteMove(
        session,
        '${payload['from'] ?? ''}',
        '${payload['to'] ?? ''}',
        payload['promotion']?.toString(),
      );
    };

    room.onCtrl = (event) => _onLearningRemoteCtrl(session, event);
    room.onLearningStudentEvaluation = (event) {
      _onLearningRemoteCtrl(
        session,
        <String, dynamic>{
          ...event,
          'type': 'learning_student_eval',
        },
      );
    };
    room.onLearningReset = (event) {
      _onLearningRemoteCtrl(
        session,
        <String, dynamic>{
          ...event,
          'type': 'learning_reset',
        },
      );
    };

    room.onDrawOffer = (event) {
      final incomingRoomId = '${event['roomId'] ?? ''}';
      if (incomingRoomId.isNotEmpty && incomingRoomId != session.roomId) return;
      unawaited(_askLearningDrawOffer(session));
    };

    room.onDrawAnswer = (event) {
      final incomingRoomId = '${event['roomId'] ?? ''}';
      if (incomingRoomId.isNotEmpty && incomingRoomId != session.roomId) return;
      if (event['accepted'] == true) {
        _finishLearningGameSession(
          session,
          '1/2-1/2',
          'Ничья по соглашению',
          broadcast: false,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${session.student.nickname} отклонил ничью'),
          ),
        );
      }
    };

    room.onResign = (event) {
      final incomingRoomId = '${event['roomId'] ?? ''}';
      if (incomingRoomId.isNotEmpty && incomingRoomId != session.roomId) return;
      final result = session.myColor == 'white' ? '1-0' : '0-1';
      _finishLearningGameSession(
        session,
        result,
        '${session.student.nickname} сдался',
        broadcast: false,
      );
    };

    await room.connect();
    if (!mounted) {
      session.dispose();
      return;
    }

    setState(() {
      _learningGameSessions[studentId] = session;
      _learningFocusedStudentId = studentId;
      _selectedLearningStudentId = studentId;
      _learningShowAllBoards = false;
      _learningInvitationStatus = '$studentName принял приглашение';
    });
    unawaited(_refreshLearningSessionEval(session));
  }

  void _onLearningRemoteCtrl(
    _LearningGameSession session,
    Map<String, dynamic> event,
  ) {
    final senderClientId = '${event['clientId'] ?? ''}';
    if (senderClientId.isNotEmpty && senderClientId == _clientId) return;

    final eventType = '${event['type'] ?? ''}';
    if (session.terminated &&
        eventType != 'result' &&
        eventType != 'learning_reset') {
      return;
    }
    switch (eventType) {
      case 'result':
        final result = '${event['result'] ?? ''}';
        if (result.isEmpty) return;
        _finishLearningGameSession(
          session,
          result,
          '${event['reason'] ?? 'Игра окончена'}',
          broadcast: false,
        );
        break;
      case 'learning_sync_request':
        unawaited(session.room.sendLearningControl(<String, dynamic>{
          'type': 'learning_student_eval',
          'enabled': session.studentEvaluationEnabled,
          'studentId': session.student.id,
          'clientId': _clientId,
          'ts': DateTime.now().millisecondsSinceEpoch,
        }));
        unawaited(session.room.sendLearningControl(<String, dynamic>{
          'type': 'learning_reset',
          'fen': session.game.fen,
          'teacherColor': session.myColor,
          'w': session.whiteMs,
          'b': session.blackMs,
          'clientId': _clientId,
          'resetBy': 'sync',
          'ts': DateTime.now().millisecondsSinceEpoch,
        }));
        break;
      case 'learning_student_eval':
        session.studentEvaluationEnabled = event['enabled'] == true;
        if (mounted) setState(() {});
        break;
      case 'learning_swap_colors':
        final teacherColor = '${event['teacherColor'] ?? session.myColor}';
        session.myColor = teacherColor == 'black' ? 'black' : 'white';
        session.selectedSquare = null;
        session.legalTargets.clear();
        session.captureTargets.clear();
        if (mounted) setState(() {});
        break;
      case 'learning_reset':
        final incomingTeacherColor =
            '${event['teacherColor'] ?? session.myColor}';
        session.myColor = incomingTeacherColor == 'black' ? 'black' : 'white';
        _resetLearningSessionState(session);
        final incomingWhiteMs = (event['w'] as num?)?.toInt();
        final incomingBlackMs = (event['b'] as num?)?.toInt();
        if (incomingWhiteMs != null) session.whiteMs = incomingWhiteMs;
        if (incomingBlackMs != null) session.blackMs = incomingBlackMs;
        if (mounted) setState(() {});
        unawaited(_refreshLearningSessionEval(session));
        break;
      case 'clock':
        final white = (event['w'] as num?)?.toInt();
        final black = (event['b'] as num?)?.toInt();
        if (white == null || black == null) return;
        session.whiteMs = white;
        session.blackMs = black;
        session.clocksStarted = true;
        _startLearningSessionClock(session);
        if (mounted) setState(() {});
        break;
    }
  }

  Future<void> _askLearningDrawOffer(_LearningGameSession session) async {
    if (!mounted || session.terminated) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Предложение ничьей'),
        content: Text('${session.student.nickname} предлагает ничью'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отклонить'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Принять'),
          ),
        ],
      ),
    );
    if (accepted == null) return;
    await session.room.sendDrawAnswer(
      fromUserId: Supabase.instance.client.auth.currentUser?.id ?? '',
      fromName: _nickname ?? 'Учитель',
      accepted: accepted,
    );
    if (accepted) {
      _finishLearningGameSession(
        session,
        '1/2-1/2',
        'Ничья по соглашению',
      );
    }
  }

  bool _learningTeacherTurn(_LearningGameSession session) {
    if (session.terminated) return false;
    final teacherColor =
        session.myColor == 'black' ? ch.Color.BLACK : ch.Color.WHITE;
    return session.game.turn == teacherColor;
  }

  String _learningDisplayIndexToSquare(
    _LearningGameSession session,
    int index,
  ) {
    final row = index ~/ 8;
    final col = index % 8;
    if (session.isFlipped) {
      final file = String.fromCharCode('h'.codeUnitAt(0) - col);
      return '$file${row + 1}';
    }
    final file = String.fromCharCode('a'.codeUnitAt(0) + col);
    return '$file${8 - row}';
  }

  List<Map<String, dynamic>> _learningVerboseMoves(
    _LearningGameSession session,
    String square,
  ) {
    try {
      return List<Map<String, dynamic>>.from(
        session.game.moves({'square': square, 'verbose': true}),
      );
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  void _computeLearningLegalTargets(
    _LearningGameSession session,
    String square,
  ) {
    final moves = _learningVerboseMoves(session, square);
    session.legalTargets
      ..clear()
      ..addAll(moves.map((move) => '${move['to'] ?? ''}').where(
            (target) => target.isNotEmpty,
          ));
    session.captureTargets
      ..clear()
      ..addAll(
        moves.where((move) {
          final flags = '${move['flags'] ?? ''}';
          return flags.contains('c') ||
              flags.contains('e') ||
              move['captured'] != null;
        }).map((move) => '${move['to'] ?? ''}'),
      );
  }

  void _onLearningSquareTap(
    _LearningGameSession session,
    String square,
  ) {
    if (_learningFocusedStudentId != session.student.id && mounted) {
      setState(() => _learningFocusedStudentId = session.student.id);
    }
    if (!_learningTeacherTurn(session)) return;

    final selected = session.selectedSquare;
    if (selected == null) {
      final piece = session.game.get(square);
      if (piece == null || piece.color != session.game.turn) return;
      setState(() {
        session.selectedSquare = square;
        _computeLearningLegalTargets(session, square);
      });
      return;
    }

    if (session.legalTargets.contains(square)) {
      unawaited(_makeLearningMove(session, selected, square));
      return;
    }

    final piece = session.game.get(square);
    setState(() {
      if (piece != null && piece.color == session.game.turn) {
        session.selectedSquare = square;
        _computeLearningLegalTargets(session, square);
      } else {
        session.selectedSquare = null;
        session.legalTargets.clear();
        session.captureTargets.clear();
      }
    });
  }

  bool _learningNeedsPromotion(
    _LearningGameSession session,
    String from,
    String to,
  ) {
    final piece = session.game.get(from);
    if (piece == null || piece.type != ch.PieceType.PAWN) return false;
    final rank = int.tryParse(to.substring(1)) ?? 0;
    return (piece.color == ch.Color.WHITE && rank == 8) ||
        (piece.color == ch.Color.BLACK && rank == 1);
  }

  String? _learningSanFor(
    _LearningGameSession session,
    String from,
    String to, {
    String? promotion,
  }) {
    for (final move in _learningVerboseMoves(session, from)) {
      if ('${move['to'] ?? ''}' != to) continue;
      final movePromotion = move['promotion']?.toString();
      if (promotion == null || promotion == movePromotion) {
        return move['san']?.toString();
      }
    }
    return null;
  }

  Future<void> _makeLearningMove(
    _LearningGameSession session,
    String from,
    String to,
  ) async {
    if (!_learningTeacherTurn(session)) return;
    if (session.plyIndex != session.sanMoves.length) {
      session.plyIndex = session.sanMoves.length;
      session.game.load(session.fens.last);
    }

    String? promotion;
    if (_learningNeedsPromotion(session, from, to)) {
      final piece = session.game.get(from);
      if (piece == null) return;
      promotion = await _askPromotionPiece(context, piece.color);
      if (promotion == null) return;
    }

    final san = _learningSanFor(
          session,
          from,
          to,
          promotion: promotion,
        ) ??
        '$from-$to';
    final movedColor = session.game.turn;
    final ok = session.game.move({
      'from': from,
      'to': to,
      if (promotion != null) 'promotion': promotion,
    });
    if (!ok) return;

    _afterLearningSessionMove(session, san, movedColor);
    await session.room.sendMove(
      from: from,
      to: to,
      promotion: promotion,
    );
  }

  void _applyLearningRemoteMove(
    _LearningGameSession session,
    String from,
    String to,
    String? promotion,
  ) {
    if (session.terminated || from.isEmpty || to.isEmpty) return;
    if (session.plyIndex != session.sanMoves.length) {
      session.plyIndex = session.sanMoves.length;
      session.game.load(session.fens.last);
    }
    final san = _learningSanFor(
          session,
          from,
          to,
          promotion: promotion,
        ) ??
        '$from-$to';
    final movedColor = session.game.turn;
    final ok = session.game.move({
      'from': from,
      'to': to,
      if (promotion != null) 'promotion': promotion,
    });
    if (!ok) return;
    _afterLearningSessionMove(session, san, movedColor);
  }

  void _afterLearningSessionMove(
    _LearningGameSession session,
    String san,
    ch.Color movedColor,
  ) {
    session.sanMoves.add(san);
    session.fens.add(session.game.fen);
    session.plyIndex = session.sanMoves.length;
    session.selectedSquare = null;
    session.legalTargets.clear();
    session.captureTargets.clear();

    _applyLearningClockAfterMove(session, movedColor);
    _checkLearningGameOver(session);
    _broadcastLearningClock(session);
    if (mounted) setState(() {});
    unawaited(_refreshLearningSessionEval(session));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (session.movesScroll.hasClients) {
        session.movesScroll.animateTo(
          session.movesScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _applyLearningClockAfterMove(
    _LearningGameSession session,
    ch.Color movedColor,
  ) {
    if (session.minutes == 0 && session.increment == 0) return;
    session.clocksStarted = true;
    if (session.increment > 0) {
      if (movedColor == ch.Color.WHITE) {
        session.whiteMs += session.increment * 1000;
      } else {
        session.blackMs += session.increment * 1000;
      }
    }
    _startLearningSessionClock(session);
  }

  void _startLearningSessionClock(_LearningGameSession session) {
    session.tick?.cancel();
    session.tick = null;
    if (!session.clocksStarted || session.terminated) return;
    if (session.minutes == 0 && session.increment == 0) return;

    session.lastTickAt = DateTime.now();
    session.tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || session.terminated) {
        session.tick?.cancel();
        session.tick = null;
        return;
      }
      final now = DateTime.now();
      final previous = session.lastTickAt ?? now;
      final delta = now.difference(previous).inMilliseconds;
      session.lastTickAt = now;

      if (session.game.turn == ch.Color.WHITE) {
        session.whiteMs = math.max(0, session.whiteMs - delta).toInt();
        if (session.whiteMs == 0) {
          _finishLearningGameSession(
            session,
            '0-1',
            'Время белых истекло',
          );
        }
      } else {
        session.blackMs = math.max(0, session.blackMs - delta).toInt();
        if (session.blackMs == 0) {
          _finishLearningGameSession(
            session,
            '1-0',
            'Время чёрных истекло',
          );
        }
      }
      if (mounted) setState(() {});
    });
  }

  void _broadcastLearningClock(_LearningGameSession session) {
    unawaited(
      session.room.sendLearningControl({
        'type': 'clock',
        'w': session.whiteMs,
        'b': session.blackMs,
        'turn': session.game.turn == ch.Color.WHITE ? 'w' : 'b',
        'ts': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  void _checkLearningGameOver(_LearningGameSession session) {
    if (session.game.in_checkmate) {
      final result = session.game.turn == ch.Color.WHITE ? '0-1' : '1-0';
      _finishLearningGameSession(session, result, 'Мат');
    } else if (session.game.in_stalemate || session.game.in_draw) {
      _finishLearningGameSession(session, '1/2-1/2', 'Ничья');
    }
  }

  void _finishLearningGameSession(
    _LearningGameSession session,
    String result,
    String reason, {
    bool broadcast = true,
  }) {
    if (session.terminated) return;
    session.terminated = true;
    session.result = result;
    session.resultReason = reason;
    session.tick?.cancel();
    session.tick = null;
    if (broadcast) {
      unawaited(
        session.room.sendLearningControl({
          'type': 'result',
          'result': result,
          'reason': reason,
          'ts': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _offerLearningDraw(_LearningGameSession session) async {
    if (session.terminated) return;
    await session.room.sendDrawOffer(
      fromUserId: Supabase.instance.client.auth.currentUser?.id ?? '',
      fromName: _nickname ?? 'Учитель',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Предложение ничьей отправлено: ${session.student.nickname}',
          ),
        ),
      );
    }
  }

  Future<void> _resignLearningSession(_LearningGameSession session) async {
    if (session.terminated) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Сдаться?'),
        content: Text('Партия с ${session.student.nickname} будет завершена'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Сдаться'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await session.room.sendResign(
      fromUserId: Supabase.instance.client.auth.currentUser?.id ?? '',
      fromName: _nickname ?? 'Учитель',
    );
    final result = session.myColor == 'white' ? '0-1' : '1-0';
    _finishLearningGameSession(session, result, 'Учитель сдался');
  }

  Future<void> _toggleLearningSessionTeacherColor(
    _LearningGameSession session,
  ) async {
    if (session.terminated) return;
    final next = session.myColor == 'white' ? 'black' : 'white';
    if (mounted) {
      setState(() {
        session.myColor = next;
        session.selectedSquare = null;
        session.legalTargets.clear();
        session.captureTargets.clear();
      });
    } else {
      session.myColor = next;
    }
    await session.room.sendLearningControl({
      'type': 'learning_swap_colors',
      'teacherColor': next,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _resetLearningSessionState(_LearningGameSession session) {
    session.tick?.cancel();
    session.tick = null;
    session.game.reset();
    session.sanMoves.clear();
    session.fens
      ..clear()
      ..add(session.game.fen);
    session.plyIndex = 0;
    session.selectedSquare = null;
    session.legalTargets.clear();
    session.captureTargets.clear();
    session.result = null;
    session.resultReason = null;
    session.terminated = false;
    session.whiteMs = session.minutes * 60 * 1000;
    session.blackMs = session.minutes * 60 * 1000;
    session.clocksStarted = false;
    session.lastTickAt = null;
  }

  Future<void> _confirmResetLearningSession(
    _LearningGameSession session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Расставить позицию заново?'),
        content: Text(
          'Партия с ${session.student.nickname} начнётся с начальной позиции.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Начать заново'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _resetLearningSessionState(session);
    if (mounted) setState(() {});
    unawaited(_refreshLearningSessionEval(session));
    await session.room.sendLearningControl(<String, dynamic>{
      'type': 'learning_reset',
      'fen': session.game.fen,
      'teacherColor': session.myColor,
      'w': session.whiteMs,
      'b': session.blackMs,
      'clientId': _clientId,
      'resetBy': 'teacher',
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _confirmResetLearningStudentPosition() async {
    final room = _room;
    if (!_studentLearningRoomActive || room == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сначала подключитесь к учителю'),
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Расставить позицию заново?'),
        content: const Text(
          'Позиция вернётся к начальной и одновременно обновится у учителя.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Начать заново'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final teacherColor = _humanColor == ch.Color.WHITE ? 'black' : 'white';
    final resetMs = _tcMinutes * 60 * 1000;

    _stopTick();
    if (mounted) {
      setState(() {
        game.reset();
        _fenController.text = game.fen;
        _sanMoves.clear();
        _fens
          ..clear()
          ..add(game.fen);
        _plyIndex = 0;
        _selectedSquare = null;
        _legalTargets.clear();
        _captureTargets.clear();
        _gameTerminated = false;
        _result = null;
        _whiteMs = resetMs;
        _blackMs = resetMs;
        _lastTickAt = null;
        _clocksStarted = false;
      });
    }

    await room.sendLearningControl(<String, dynamic>{
      'type': 'learning_reset',
      'fen': game.fen,
      'teacherColor': teacherColor,
      'w': _whiteMs,
      'b': _blackMs,
      'clientId': _clientId,
      'resetBy': 'student',
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _stopLearningVideoForStudent(String studentId) async {
    _selectedVideoStudentIds.remove(studentId);
    final call = _classroomVideoCall;
    if (call != null && call.isActive && call.isTeacher) {
      await call.stopPeer(studentId);
    }
    if (mounted) setState(() {});
  }

  Future<void> _endLearningStudentGame(LearningStudent student) async {
    final session = _learningGameSessions[student.id];
    if (session == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Закончить занятие?'),
        content: Text(
          'Закончить занятие с ${student.nickname}?\n\n'
          'Будут завершены партия и видеосвязь.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Закончить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await session.room.sendLearningControl({
        'type': 'learning_session_end',
        'reason': 'Занятие завершено учителем',
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}

    await _stopLearningVideoForStudent(student.id);

    _learningGameSessions.remove(student.id);
    _pendingLearningGameInvites.removeWhere(
      (_, invite) => invite.student.id == student.id,
    );
    session.dispose();

    if (_learningFocusedStudentId == student.id) {
      _learningFocusedStudentId = _learningGameSessions.isEmpty
          ? null
          : _learningGameSessions.keys.first;
    }
    if (mounted) {
      setState(() {
        _learningInvitationStatus = 'Занятие с ${student.nickname} завершено';
      });
    }
  }

  void _setLearningSessionPly(_LearningGameSession session, int value) {
    final int next = value.clamp(0, session.sanMoves.length);
    session.plyIndex = next;
    session.game.load(session.fens[next]);
    session.selectedSquare = null;
    session.legalTargets.clear();
    session.captureTargets.clear();
    if (mounted) setState(() {});
    unawaited(_refreshLearningSessionEval(session));
  }

  Future<void> _copyLearningSessionPgn(
    _LearningGameSession session,
  ) async {
    final pgn = _rowsFromSan(session.sanMoves).join(' ').trim();
    await Clipboard.setData(ClipboardData(text: pgn));

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || pgn.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pgn.isEmpty ? 'Список ходов пока пуст' : 'PGN скопирован',
            ),
          ),
        );
      }
      return;
    }

    final type = session.minutes <= 3
        ? CabinetGameType.blitz
        : (session.minutes <= 15
            ? CabinetGameType.rapid
            : CabinetGameType.classic);
    final teacherName = (_nickname ?? 'Учитель').trim();
    final teacherIsWhite = session.myColor == 'white';
    final result = session.result ?? '*';

    try {
      await PersonalCabinetStore.instance.saveGame(
        CabinetGameRecord(
          id: '${DateTime.now().microsecondsSinceEpoch}-${session.roomId}',
          userId: user.id,
          type: type,
          savedAt: DateTime.now(),
          whiteName: teacherIsWhite ? teacherName : session.student.nickname,
          blackName: teacherIsWhite ? session.student.nickname : teacherName,
          opponentName: session.student.nickname,
          result: result,
          timeControl: session.minutes == 0 && session.increment == 0
              ? 'Без времени'
              : '${session.minutes}+${session.increment}',
          source: 'Школа MakeChess',
          pgn: pgn,
        ),
      );
    } catch (_) {
      // Копирование PGN должно работать даже при ошибке локального архива.
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PGN скопирован')),
      );
    }
  }

  String _formatLearningClock(int milliseconds) {
    if (milliseconds < 0) milliseconds = 0;
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  List<_LearningGameSession?> _orderedLearningBoardSessions() {
    final result = <_LearningGameSession?>[];
    final used = <String>{};
    for (final student in _learningStudents.take(8)) {
      result.add(_learningGameSessions[student.id]);
      used.add(student.id);
    }
    for (final entry in _learningGameSessions.entries) {
      if (result.length >= 8) break;
      if (used.add(entry.key)) result.add(entry.value);
    }
    while (result.length < 8) {
      result.add(null);
    }
    return result;
  }

  LearningStudent? _learningStudentForSlot(int index) {
    if (index < _learningStudents.length && index < 8) {
      return _learningStudents[index];
    }
    return null;
  }

  Widget _buildLearningBoardsArea({
    required double width,
    required double height,
  }) {
    if (_learningShowAllBoards) {
      final sessions = _orderedLearningBoardSessions();
      return SizedBox(
        width: width,
        height: height,
        child: Scrollbar(
          child: GridView.builder(
            padding: const EdgeInsets.only(right: 8, bottom: 12),
            physics: const ClampingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.86,
            ),
            itemCount: 8,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final fallbackStudent = _learningStudentForSlot(index);
              return LayoutBuilder(
                builder: (context, constraints) {
                  final double boardSize = math
                      .max(
                        120.0,
                        math.min(
                          constraints.maxWidth - 42,
                          constraints.maxHeight - 98,
                        ),
                      )
                      .toDouble();
                  return _buildLearningBoardCard(
                    session: session,
                    fallbackStudent: fallbackStudent,
                    boardSize: boardSize,
                    compact: true,
                  );
                },
              );
            },
          ),
        ),
      );
    }

    final focusedId = _learningFocusedStudentId ?? _firstLearningBoardStudentId;
    final session = focusedId == null ? null : _learningGameSessions[focusedId];
    LearningStudent? fallbackStudent;
    if (focusedId != null) {
      for (final student in _learningStudents) {
        if (student.id == focusedId) {
          fallbackStudent = student;
          break;
        }
      }
    }
    fallbackStudent ??=
        _learningStudents.isEmpty ? null : _learningStudents.first;

    final double boardSize = math
        .max(
          220.0,
          math.min(560.0, math.min(width - 52, height - 98)),
        )
        .toDouble();
    return SizedBox(
      width: width,
      height: height,
      child: Align(
        alignment: Alignment.topCenter,
        child: _buildLearningBoardCard(
          session: session,
          fallbackStudent: fallbackStudent,
          boardSize: boardSize,
          compact: false,
        ),
      ),
    );
  }

  Widget _buildLearningBoardCard({
    required _LearningGameSession? session,
    required LearningStudent? fallbackStudent,
    required double boardSize,
    required bool compact,
  }) {
    final student = session?.student ?? fallbackStudent;
    final studentName = student?.nickname ?? 'Учебная доска';
    final teacherName = (_nickname ?? 'Учитель').trim();
    final teacherIsWhite = session?.myColor != 'black';
    final studentClock = session == null
        ? '--:--'
        : _formatLearningClock(
            teacherIsWhite ? session.blackMs : session.whiteMs,
          );
    final teacherClock = session == null
        ? '--:--'
        : _formatLearningClock(
            teacherIsWhite ? session.whiteMs : session.blackMs,
          );

    Widget playerBar({
      required String name,
      required String clock,
      required ch.Color color,
      required bool isStudentBar,
      required bool isTeacherBar,
    }) {
      final activeTurn =
          session != null && !session.terminated && session.game.turn == color;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.r8,
          onTap: isStudentBar && student != null
              ? () => _focusLearningStudentBoard(student.id)
              : null,
          child: Container(
            height: compact ? 29 : 36,
            padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10),
            decoration: BoxDecoration(
              color: activeTurn
                  ? AppColors.accentGlowSoft
                  : AppColors.surfaceCard.withOpacity(0.82),
              borderRadius: AppRadius.r8,
              border: Border.all(
                color:
                    activeTurn ? AppColors.borderBright : AppColors.borderSoft,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 11 : 13,
                    ),
                  ),
                ),
                if (isTeacherBar && session != null) ...[
                  Tooltip(
                    message: session.myColor == 'white'
                        ? 'Учитель играет белыми. Сменить на чёрные'
                        : 'Учитель играет чёрными. Сменить на белые',
                    child: IconButton(
                      onPressed: session.terminated
                          ? null
                          : () => unawaited(
                                _toggleLearningSessionTeacherColor(session),
                              ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints.tightFor(
                        width: compact ? 25 : 29,
                        height: compact ? 25 : 29,
                      ),
                      visualDensity: VisualDensity.compact,
                      iconSize: compact ? 15 : 17,
                      icon: const Icon(Icons.contrast),
                    ),
                  ),
                  Tooltip(
                    message: 'Начать позицию заново',
                    child: IconButton(
                      onPressed: () => unawaited(
                        _confirmResetLearningSession(session),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints.tightFor(
                        width: compact ? 25 : 29,
                        height: compact ? 25 : 29,
                      ),
                      visualDensity: VisualDensity.compact,
                      iconSize: compact ? 15 : 17,
                      icon: const Icon(Icons.restart_alt),
                    ),
                  ),
                  SizedBox(width: compact ? 2 : 4),
                ],
                Text(
                  clock,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 11 : 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final studentColor = teacherIsWhite ? ch.Color.BLACK : ch.Color.WHITE;
    final teacherColor = teacherIsWhite ? ch.Color.WHITE : ch.Color.BLACK;

    return Container(
      padding: EdgeInsets.all(compact ? 5 : 8),
      decoration: AppDecorations.panel(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ученик всегда сверху. Нажатие только на эту тёмную полосу
          // разворачивает его доску крупно.
          playerBar(
            name: studentName,
            clock: studentClock,
            color: studentColor,
            isStudentBar: true,
            isTeacherBar: false,
          ),
          SizedBox(height: compact ? 4 : 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              session == null
                  ? _buildLearningBoardPlaceholder(boardSize)
                  : _buildLearningGameBoard(session, boardSize),
              SizedBox(width: compact ? 4 : 6),
              SizedBox(
                width: compact ? 18 : 28,
                height: boardSize,
                child: EvalBar(
                  eval: session?.engineEval ?? 0.0,
                  flipped: session?.isFlipped ?? false,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 6),
          // Учитель всегда снизу независимо от выбранного цвета фигур.
          playerBar(
            name: teacherName,
            clock: teacherClock,
            color: teacherColor,
            isStudentBar: false,
            isTeacherBar: true,
          ),
          if (session?.result != null) ...[
            SizedBox(height: compact ? 3 : 5),
            Text(
              '${session!.result} · ${session.resultReason ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLearningBoardPlaceholder(double boardSize) {
    final initialGame = ch.Chess();
    return AnimatedBuilder(
      animation: widget.boardTheme,
      builder: (context, _) => SizedBox(
        width: boardSize,
        height: boardSize,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
          ),
          itemCount: 64,
          itemBuilder: (context, index) {
            final row = index ~/ 8;
            final column = index % 8;
            final file = String.fromCharCode('a'.codeUnitAt(0) + column);
            final square = '$file${8 - row}';
            final piece = initialGame.get(square);
            final cell = boardSize / 8;
            return Container(
              color: (row + column).isEven
                  ? widget.boardTheme.lightSquare
                  : widget.boardTheme.darkSquare,
              child: piece == null
                  ? null
                  : Center(
                      child: SvgPicture.asset(
                        _assetFor(_codeFor(piece)),
                        width: cell * 0.84,
                        height: cell * 0.84,
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLearningGameBoard(
    _LearningGameSession session,
    double boardSize,
  ) {
    return AnimatedBuilder(
      animation: widget.boardTheme,
      builder: (context, _) {
        final cell = boardSize / 8;
        final pieceSize = cell * 0.84;
        return SizedBox(
          width: boardSize,
          height: boardSize,
          child: GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
            ),
            itemCount: 64,
            itemBuilder: (context, index) {
              final square = _learningDisplayIndexToSquare(session, index);
              final row = index ~/ 8;
              final column = index % 8;
              final light = (row + column).isEven;
              final selected = session.selectedSquare == square;
              final legal = session.legalTargets.contains(square);
              final capture = session.captureTargets.contains(square);
              final piece = session.game.get(square);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onLearningSquareTap(session, square),
                child: Container(
                  decoration: BoxDecoration(
                    color: light
                        ? widget.boardTheme.lightSquare
                        : widget.boardTheme.darkSquare,
                    border: Border.all(
                      color: selected ? Colors.amber : Colors.black12,
                      width: selected ? 2.4 : 0.7,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (legal && !capture)
                        Center(
                          child: Container(
                            width: cell * 0.28,
                            height: cell * 0.28,
                            decoration: const BoxDecoration(
                              color: Color(0x6600D67A),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      if (capture)
                        Center(
                          child: Container(
                            width: cell * 0.74,
                            height: cell * 0.74,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.redAccent,
                                width: math.max(1.4, cell * 0.055).toDouble(),
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      if (piece != null)
                        Center(
                          child: SvgPicture.asset(
                            _assetFor(_codeFor(piece)),
                            width: pieceSize,
                            height: pieceSize,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDesktopRightColumn(double width) {
    final session =
        _showLearningPanel && _learningRole == LearningPanelRole.teacher
            ? _activeLearningGameSession
            : null;

    if (session != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoveListPanel(
            san: session.sanMoves,
            currentPly: session.plyIndex,
            controller: session.movesScroll,
            onCopyPGN: () => unawaited(_copyLearningSessionPgn(session)),
            onClear: () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Ходы активной онлайн-партии удалять нельзя',
                    ),
                  ),
                );
              }
            },
            width: width,
            height: 420,
          ),
          const SizedBox(height: 12),
          RightSidebarPanel(
            plyIndex: session.plyIndex,
            sanMoves: session.sanMoves,
            onGoStart: () => _setLearningSessionPly(session, 0),
            onGoPrev: () =>
                _setLearningSessionPly(session, session.plyIndex - 1),
            onGoNext: () =>
                _setLearningSessionPly(session, session.plyIndex + 1),
            onGoEnd: () =>
                _setLearningSessionPly(session, session.sanMoves.length),
            onResignPressed: () => unawaited(_resignLearningSession(session)),
            offerDrawUniversal: () => unawaited(_offerLearningDraw(session)),
            loading: false,
            onBestMove: () async {
              final move = await _fetchUciBestMove(session.game.fen);
              if (mounted && move != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Лучший ход: $move')),
                );
              }
            },
            gptLoading: false,
            explainHere: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Выбрана активная ученическая доска'),
                ),
              );
            },
            showFenInput: false,
            toggleFenInput: () {
              Clipboard.setData(ClipboardData(text: session.game.fen));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('FEN скопирован')),
              );
            },
            loadingBest: false,
            onTakeBestMove: () {},
            loadingAnalysis: false,
            onOpenAnalysis: () {},
            openGptPromptDialog: () {},
            inRoom: true,
            sharedControl: false,
            editMode: false,
            applyEditor: () {},
            enterEditor: () {},
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MoveListPanel(
          san: _sanMoves,
          currentPly: _plyIndex,
          controller: _movesScroll,
          onCopyPGN: () => unawaited(_copyPgnAndSaveToCabinet()),
          onClear: () {
            setState(() {
              _sanMoves.clear();
              _fens
                ..clear()
                ..add(game.fen);
              _plyIndex = 0;
              if (_showPuzzleMoveResultPanel) {
                _resetStudentPuzzleMoveCheck();
                _studentShowPuzzleAnswer = false;
              }
            });
          },
          puzzleMoveChecked:
              _showPuzzleMoveResultPanel ? _puzzleMoveChecked : false,
          puzzleMoveCorrect:
              _showPuzzleMoveResultPanel ? _puzzleMoveCorrect : null,
          showPuzzleCorrectAnswer:
              _showPuzzleMoveResultPanel && _studentShowPuzzleAnswer,
          correctPuzzleLines: _activePuzzleSolutionMoveLines,
          selectedCorrectLineIndex: _shownSolutionLineIndex,
          onPreviousCorrectLine: _openPreviousSolutionLine,
          onNextCorrectLine: _openNextSolutionLine,
          width: width,
          height: 420,
        ),
        const SizedBox(height: 12),
        RightSidebarPanel(
          plyIndex: _plyIndex,
          sanMoves: _sanMoves,
          onGoStart: _goStart,
          onGoPrev: _goPrev,
          onGoNext: _goNext,
          onGoEnd: _goEnd,
          onResignPressed: _onResignPressed,
          offerDrawUniversal: _offerDrawUniversal,
          loading: _loading,
          onBestMove: () async {
            final fen = _fenController.text.trim().isEmpty
                ? game.fen
                : _fenController.text.trim();
            await _fetchUciBestMove(fen);
          },
          gptLoading: _gptLoading,
          explainHere: _explainHere,
          showFenInput: _showFenInput,
          toggleFenInput: () => setState(() => _showFenInput = !_showFenInput),
          loadingBest: _loadingBest,
          onTakeBestMove: _onTakeBestMove,
          loadingAnalysis: _loadingAnalysis,
          onOpenAnalysis: _onOpenAnalysis,
          openGptPromptDialog: _openGptPromptDialog,
          inRoom: _inRoom,
          sharedControl: _sharedControl,
          editMode: _editMode,
          applyEditor: _applyEditor,
          enterEditor: _enterEditor,
        ),
      ],
    );
  }

  Future<void> _openRoom(
    String roomId, {
    required String opponentId,
    required String opponentName,
    required String myColor, // 'white' | 'black'
    required bool spectator,
    bool learningRoom = false,
  }) async {
    _room?.disconnect();
    final supa = Supabase.instance.client;
    final effectiveLearningRoom = learningRoom ||
        (_showLearningPanel &&
            _learningRole == LearningPanelRole.student &&
            !spectator);

    _room = RoomService(supa, roomId: roomId);

    _room!.onMove = (m) {
      final rid = m['roomId'] as String?;
      if (rid != null && _roomId != null && rid != _roomId) return;
      if ('${m['kind'] ?? ''}' == 'learning_ctrl') {
        debugPrint('[LEARNING CTRL][student] ${m['type']} room=$_roomId');
        _onRemoteCtrl(m);
        return;
      }
      _applyRemoteMove(
        '${m['from']}',
        '${m['to']}',
        m['promotion']?.toString(),
      );
    };

    _room!.onChat = (msg) {
      final rid = msg['roomId'] as String?;
      if (rid != null && _roomId != null && rid != _roomId) return;

      final text = (msg['msg'] ?? '') as String;
      if (text.isEmpty) return;

      final fromName = (msg['fromName'] ?? 'player').toString();
      final from = (msg['from'] ?? '').toString();
      final myId = Supabase.instance.client.auth.currentUser?.id;

      final mine = (from.isNotEmpty && myId != null && from == myId);

      setState(() {
        _chat.add(_ChatMsg(from: fromName, text: text, mine: mine));
      });
    };

    _room!.onCtrl = (evt) => _onRemoteCtrl(evt);
    _room!.onLearningStudentEvaluation = (evt) {
      _onRemoteCtrl(
        <String, dynamic>{
          ...evt,
          'type': 'learning_student_eval',
        },
      );
    };
    _room!.onLearningReset = (evt) {
      _onRemoteCtrl(
        <String, dynamic>{
          ...evt,
          'type': 'learning_reset',
        },
      );
    };

    _room!.onDrawOffer = (evt) async {
      final rid = evt['roomId'] as String?;
      if (rid != null && _roomId != null && rid != _roomId) return;

      final from = (evt['from'] ?? '') as String;
      final me = Supabase.instance.client.auth.currentUser?.id;
      if (me != null && from == me) return;

      setState(() {
        _drawOfferedByMe = false;
        _drawOfferedToMe = true;
      });
      _maybeAskDrawDialog();
    };

    _room!.onDrawAnswer = (evt) {
      final rid = evt['roomId'] as String?;
      if (rid != null && _roomId != null && rid != _roomId) return;

      final from = (evt['from'] ?? '') as String;
      final me = Supabase.instance.client.auth.currentUser?.id;
      if (me != null && from == me) return;

      final accepted = evt['accepted'] == true;

      if (accepted) {
        setState(() {
          _drawOfferedByMe = false;
          _drawOfferedToMe = false;
        });
        _finishGameWithResult('1/2-1/2', 'Ничья по соглашению');
      } else {
        setState(() {
          _drawOfferedByMe = false;
          _drawOfferedToMe = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Соперник отклонил ничью')),
        );
      }
    };

    _room!.onResign = (evt) {
      final rid = evt['roomId'] as String?;
      if (rid != null && _roomId != null && rid != _roomId) return;

      final from = (evt['from'] ?? '') as String;
      final me = Supabase.instance.client.auth.currentUser?.id;
      if (me != null && from == me) return;

      final result = (_humanColor == ch.Color.WHITE) ? '1-0' : '0-1';
      _finishGameWithResult(result, 'Соперник сдался');
    };

    await _room!.connect();

    setState(() {
      _roomId = roomId;
      _opponentId = opponentId;
      _opponentName = opponentName;
      _vsEngine = false;
      _engineThinking = false;
      _humanColor =
          (myColor.toLowerCase() == 'white') ? ch.Color.WHITE : ch.Color.BLACK;
      _isSpectator = spectator;
      _activeRoomIsLearning = effectiveLearningRoom;
      _chat.clear();
      _drawOfferedByMe = _drawOfferedToMe = false;
      _rematchOfferedByMe = _rematchOfferedToMe = false;
      _gameTerminated = false;
    });
    _joinBoardChannel();
    try {
      final row = await supa
          .from('profiles')
          .select('rating, games_played, nickname')
          .eq('id', opponentId)
          .maybeSingle();
      setState(() {
        _oppRating = (row?['rating'] as int?) ?? 1200;
        _oppGames = (row?['games_played'] as int?) ?? 0;
        _opponentName = (row?['nickname'] as String?) ?? opponentName;
      });
    } catch (_) {}

    game.reset();
    _fenController.text = game.fen;
    _sanMoves..clear();
    _fens
      ..clear()
      ..add(game.fen);
    _plyIndex = 0;

    _resetClocks();

    writeLocalStorage(
      _LS_ROOM,
      jsonEncode({
        'roomId': roomId,
        'opponentId': opponentId,
        'opponentName': _opponentName,
        'myColor': (myColor.toLowerCase()),
        'spectator': spectator,
        'learningRoom': effectiveLearningRoom,
      }),
    );

    _broadcastTimeControl();

    if (effectiveLearningRoom) {
      Future<void> requestLearningState() async {
        final room = _room;
        if (room == null || _roomId != roomId) return;
        await room.sendLearningControl(<String, dynamic>{
          'type': 'learning_sync_request',
          'clientId': _clientId,
          'ts': DateTime.now().millisecondsSinceEpoch,
        });
      }

      unawaited(requestLearningState());
      unawaited(Future<void>.delayed(
        const Duration(milliseconds: 600),
        requestLearningState,
      ));
      unawaited(Future<void>.delayed(
        const Duration(milliseconds: 1600),
        requestLearningState,
      ));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Игра против $_opponentName (${myColor == 'white' ? 'белыми' : 'чёрными'})')),
      );
    }
  }

  Future<void> _leaveRoom() async {
    await _room?.disconnect();
    _leaveBoardChannel();
    _stopTick();
    setState(() {
      _room = null;
      _roomId = null;
      _opponentId = null;
      _opponentName = null;
      _isSpectator = false;
      _activeRoomIsLearning = false;
    });

    _matchRated = _rated;
    removeLocalStorage(_LS_ROOM);
  }

  Future<void> _tryRestoreRoom() async {
    final s = readLocalStorage(_LS_ROOM);
    if (s == null) return;
    try {
      final map = jsonDecode(s) as Map<String, dynamic>;
      final roomId = map['roomId'] as String?;
      final oppId = map['opponentId'] as String?;
      final oppName = map['opponentName'] as String? ?? 'opponent';
      final myColor = map['myColor'] as String? ?? 'white';
      final spectator = (map['spectator'] as bool?) ?? false;
      final learningRoom = (map['learningRoom'] as bool?) ?? false;
      if (roomId != null && oppId != null) {
        final supa = Supabase.instance.client;
        if (supa.auth.currentUser == null) return;
        await _openRoom(roomId,
            opponentId: oppId,
            opponentName: oppName,
            myColor: myColor,
            spectator: spectator,
            learningRoom: learningRoom);
      }
    } catch (_) {}
  }

  // ================== PGN / Result / Ratings ==================
  List<String> _rowsFromSan(List<String> san) {
    final out = <String>[];
    for (int i = 0; i < san.length; i += 2) {
      final n = i ~/ 2 + 1;
      final w = san[i];
      final b = (i + 1 < san.length) ? san[i + 1] : '';
      out.add('$n. $w ${b.isEmpty ? '' : b}');
    }
    return out;
  }

  CabinetGameType _cabinetGameTypeForCurrentPosition() {
    if (_showPuzzlePanel || _showPuzzleMoveResultPanel) {
      return CabinetGameType.puzzles;
    }
    if (_tcMinutes == 0 && _tcIncrement == 0) {
      return CabinetGameType.classic;
    }
    if (_tcMinutes <= 3) return CabinetGameType.blitz;
    if (_tcMinutes <= 15) return CabinetGameType.rapid;
    return CabinetGameType.classic;
  }

  String _cabinetResultForCurrentPosition() {
    final raw = (_result ?? '').trim();
    if (raw.contains('1/2-1/2')) return '1/2-1/2';
    if (raw.contains('1-0')) return '1-0';
    if (raw.contains('0-1')) return '0-1';
    return '*';
  }

  Future<void> _copyPgnAndSaveToCabinet() async {
    final pgn = _rowsFromSan(_sanMoves).join(' ').trim();
    await Clipboard.setData(ClipboardData(text: pgn));

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.id.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PGN скопирован. Для сохранения в личном кабинете войдите в аккаунт',
          ),
        ),
      );
      return;
    }

    if (pgn.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PGN скопирован, но список ходов пуст')),
      );
      return;
    }

    final type = _cabinetGameTypeForCurrentPosition();
    final myName = (_nickname ?? 'Игрок').trim().isEmpty
        ? 'Игрок'
        : (_nickname ?? 'Игрок').trim();
    final opponentName = type == CabinetGameType.puzzles
        ? 'Задача'
        : (_vsEngine
            ? 'Компьютер'
            : ((_opponentName ?? '').trim().isEmpty
                ? 'Соперник'
                : _opponentName!.trim()));

    final whiteName = _humanColor == ch.Color.WHITE ? myName : opponentName;
    final blackName = _humanColor == ch.Color.BLACK ? myName : opponentName;
    final result = _cabinetResultForCurrentPosition();
    final timeControl = (_tcMinutes == 0 && _tcIncrement == 0)
        ? 'Без времени'
        : '$_tcMinutes+$_tcIncrement';
    final source = type == CabinetGameType.puzzles
        ? 'Задача MakeChess'
        : (_inRoom
            ? 'Онлайн'
            : (_vsEngine ? 'Против компьютера' : 'Локальная партия'));

    try {
      final added = await PersonalCabinetStore.instance.saveGame(
        CabinetGameRecord(
          id: '${DateTime.now().microsecondsSinceEpoch}-${user.id}',
          userId: user.id,
          type: type,
          savedAt: DateTime.now(),
          whiteName: whiteName,
          blackName: blackName,
          opponentName: opponentName,
          result: result,
          timeControl: timeControl,
          source: source,
          pgn: pgn,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added
                ? 'PGN скопирован и сохранён: ${type.title}'
                : 'PGN скопирован. Эта партия уже есть в личном кабинете',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('PGN скопирован, но сохранить партию не удалось: $error'),
        ),
      );
    }
  }

  String _makePGN(String result) {
    final rows = _rowsFromSan(_sanMoves).join(' ');
    return '$rows $result'.trim();
  }

  int _kFactor(int rating, int games) {
    if (games < 30) return 40;
    if (rating >= 2400) return 10;
    return 20;
  }

  Map<String, int> _eloDelta({
    required int rA,
    required int rB,
    required double sA,
    required int gA,
    required int gB,
  }) {
    double expA = 1.0 / (1 + math.pow(10, (rB - rA) / 400.0));
    final kA = _kFactor(rA, gA);
    final kB = _kFactor(rB, gB);
    final dA = (kA * (sA - expA)).round();
    final dB = -dA * kB ~/ kA;
    return {'da': dA, 'db': dB};
  }

  Future<void> _storeGameAndRatings(String result) async {
    final supa = Supabase.instance.client;
    final me = supa.auth.currentUser?.id;
    if (me == null) return;

    final bool ratedGame = _inRoom && !_isSpectator && _matchRated;

    final String? whiteId = (_humanColor == ch.Color.WHITE) ? me : _opponentId;
    final String? blackId = (_humanColor == ch.Color.WHITE) ? _opponentId : me;

    try {
      final pgn = _rowsFromSan(_sanMoves).join(' ');
      await supa.from('games').insert({
        'white_id': whiteId,
        'black_id': blackId,
        'pgn': pgn,
        'result': result,
        'rated': ratedGame,
      });
    } catch (e) {
      debugPrint('games.insert failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить партию: $e')),
        );
      }
    }

    if (!ratedGame) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Нерейтинговая партия — рейтинг не изменён')),
        );
      }
      // не выходим, но рейтинг не трогаем
    }

    try {
      final myStats = await _loadProfileStats(me);
      final int myOld = myStats['rating']!;
      final int myPlayed = myStats['games_played']!;

      int oppOld = _oppRating;
      int oppPlayed = _oppGames;
      if ((_opponentId ?? '').isNotEmpty) {
        final oppStats = await _loadProfileStats(_opponentId!);
        oppOld = oppStats['rating']!;
        oppPlayed = oppStats['games_played']!;
      }

      double sMy;
      if (result == '1-0') {
        sMy = (_humanColor == ch.Color.WHITE) ? 1.0 : 0.0;
      } else if (result == '0-1') {
        sMy = (_humanColor == ch.Color.BLACK) ? 1.0 : 0.0;
      } else {
        sMy = 0.5;
      }

      final deltas = _eloDelta(
        rA: myOld,
        rB: oppOld,
        sA: sMy,
        gA: myPlayed,
        gB: oppPlayed,
      );
      final int dMy = deltas['da']!;
      final int dOpp = deltas['db']!;
      final int myNew = myOld + dMy;
      final int oppNew = oppOld + dOpp;

      await supa
          .from('profiles')
          .update({'rating': myNew, 'games_played': myPlayed + 1}).eq('id', me);

      setState(() {
        _myRating = myNew;
        _myGames = myPlayed + 1;
        _oppRating = oppNew;
        _oppGames = oppPlayed + 1;
      });

      _lobby?.updateMyRating(_myRating);
      _lobby?.sendPresenceNow();

      if (mounted) {
        final sign = (dMy >= 0) ? '+$dMy' : '$dMy';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Рейтинг обновлён: $myOld → $myNew ($sign)')),
        );
      }
    } catch (e) {
      debugPrint('profiles.update failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось обновить рейтинг: $e')),
        );
      }
    }
  }

  void _finishGameWithResult(String result, String reason,
      {bool broadcast = true}) {
    setState(() => _gameTerminated = true);
    _stopTick();

    if (broadcast && _room != null) {
      _room!.sendCtrl({
        'type': 'result',
        'result': result,
        'reason': reason,
        'clientId': _clientId,
        'roomId': _roomId,
      });
    }

    _storeGameAndRatings(result).whenComplete(() {
      final showCompact = reason.toLowerCase().startsWith('победа ');
      final message =
          showCompact ? '$reason  $result' : '$reason — результат $result';
      _showInfo('Игра окончена', message);
    });

    removeLocalStorage(_LS_ROOM);
  }

  // ================== CHAT / CTRL HANDLERS ==================
  void _onRemoteCtrl(Map<String, dynamic> evt) {
    final senderCid = evt['clientId'] as String?;
    if (senderCid != null && senderCid == _clientId) return;

    final String? evtRoom = evt['roomId'] as String?;
    if (_roomId != null && evtRoom != null && evtRoom != _roomId) return;

    switch ((evt['type'] as String?) ?? '') {
      case 'result':
        if (_gameTerminated) break;
        final result = (evt['result'] as String?) ?? '';
        final reason = (evt['reason'] as String?) ?? 'Игра окончена';
        if (result.isEmpty) break;
        _finishGameWithResult(result, reason, broadcast: false);
        break;

      case 'tc':
        {
          final hasRated = evt.containsKey('rated') && evt['rated'] is bool;
          final newRated = hasRated ? (evt['rated'] as bool) : _matchRated;
          _applyTimeControl(
            minutes: (evt['m'] as num?)?.toInt() ?? _tcMinutes,
            increment: (evt['inc'] as num?)?.toInt() ?? _tcIncrement,
            rated: newRated,
            broadcast: false,
          );
          _matchRated = newRated;
          break;
        }

      case 'clock':
        final w = (evt['w'] as num?)?.toInt();
        final b = (evt['b'] as num?)?.toInt();
        final turn = (evt['turn'] as String?) ?? '';
        if (w != null && b != null) {
          setState(() {
            _whiteMs = w;
            _blackMs = b;
            _clocksStarted = true;
          });
        }
        _startTickForActiveSide();
        break;

      case 'learning_student_eval':
        final enabled = evt['enabled'] == true;
        setState(() {
          _activeRoomIsLearning = true;
          _learningStudentEvaluationEnabled = enabled;
        });
        if (enabled) {
          unawaited(_refreshEvalBar());
        }
        break;

      case 'learning_swap_colors':
        final teacherColor = '${evt['teacherColor'] ?? 'white'}';
        setState(() {
          _humanColor =
              teacherColor == 'white' ? ch.Color.BLACK : ch.Color.WHITE;
        });
        break;

      case 'learning_reset':
        final resetFen = '${evt['fen'] ?? ''}'.trim();
        final teacherColor = '${evt['teacherColor'] ?? 'white'}';
        final incomingWhiteMs = (evt['w'] as num?)?.toInt();
        final incomingBlackMs = (evt['b'] as num?)?.toInt();

        _stopTick();
        setState(() {
          _activeRoomIsLearning = true;
          if (resetFen.isNotEmpty) {
            try {
              game.load(resetFen);
            } catch (_) {
              game.reset();
            }
          } else {
            game.reset();
          }
          _fenController.text = game.fen;
          _sanMoves.clear();
          _fens
            ..clear()
            ..add(game.fen);
          _plyIndex = 0;
          _selectedSquare = null;
          _legalTargets.clear();
          _captureTargets.clear();
          _gameTerminated = false;
          _result = null;
          _humanColor =
              teacherColor == 'white' ? ch.Color.BLACK : ch.Color.WHITE;
          final resetMs = _tcMinutes * 60 * 1000;
          _whiteMs = incomingWhiteMs ?? resetMs;
          _blackMs = incomingBlackMs ?? resetMs;
          _lastTickAt = null;
          _clocksStarted = false;
        });
        if (_learningStudentEvaluationEnabled) {
          unawaited(_refreshEvalBar());
        }
        break;

      case 'learning_session_end':
        unawaited(_leaveLearningRoomAfterTeacherEnd());
        break;

      case 'rematch_offer':
        setState(() => _rematchOfferedToMe = true);
        _maybeAskRematchDialog();
        break;

      case 'rematch_accept':
        setState(() => _rematchOfferedToMe = false);
        _startRematch(modeFromOpponent: (evt['mode'] as String?) ?? 'same');
        break;

      case 'rematch_decline':
        setState(() => _rematchOfferedToMe = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Реванш отклонён')));
        break;
    }
  }

  Future<void> _leaveLearningRoomAfterTeacherEnd() async {
    // Завершаем и учебную партию, и видеосвязь ученика с учителем.
    await stopClassroomVideo();
    await _leaveRoom();
    game.reset();
    _fenController.text = game.fen;
    _sanMoves.clear();
    _fens
      ..clear()
      ..add(game.fen);
    _plyIndex = 0;
    _selectedSquare = null;
    _legalTargets.clear();
    _captureTargets.clear();
    _gameTerminated = false;
    _result = null;
    if (mounted) {
      setState(() {
        _learningInvitationStatus = 'Учитель завершил занятие';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Учитель завершил занятие')),
      );
    }
  }

  // ================== MOVES (local & remote) ==================
  void _onLocalMoveAffectClocks() {
    if (!_inRoom) return;
    final movedColor =
        (game.turn == ch.Color.WHITE) ? ch.Color.BLACK : ch.Color.WHITE;
    _switchTurnAndApplyIncrement(movedColor);
  }

  void _applyRemoteMove(String from, String to, String? promo) {
    if (_plyIndex != _sanMoves.length) _goEnd();
    if (_gameTerminated) return;
    final isCapture = _willBeCapture(from, to);
    final san = _sanFor(from, to, promotion: promo) ?? '$from-$to';
    final ok = game
        .move({'from': from, 'to': to, if (promo != null) 'promotion': promo});
    if (!ok) return;

    _afterHumanMoveCommon(san, isCapture);
    _checkGameOver();
    unawaited(_refreshEvalBar());
    _broadcastClockSnapshot();
  }

  // ================== UI: actions ==================
  Future<void> _makeMove(String from, String to) async {
    if (_gameTerminated) return;
    if (_vsEngine && game.turn != _humanColor) return;
    if (_isSpectator) return;

    _truncateFutureBranch();

    final Map<String, dynamic> params = {'from': from, 'to': to};

    String? promo;
    if (_needsPromotion(from, to)) {
      final color = game.get(from)!.color;
      final choice = await _askPromotionPiece(context, color);
      if (choice == null) return;
      params['promotion'] = choice;
      promo = choice;
    }

    final bool isCapture = _willBeCapture(from, to);
    final String san = _sanFor(from, to, promotion: promo) ?? '$from-$to';

    final bool ok = game.move(params);
    if (!ok) return;

    if (_puzzleRecordingLine) {
      _puzzleCurrentLine.add('$from$to${promo ?? ''}');
      _puzzleDraftPublished = false;
      _refreshPuzzleSettingsOverlay();
    } else if (_showPuzzlePanel &&
        _activePublishedPuzzleTask != null &&
        !_puzzleSettingsIsOpen) {
      _studentPuzzleMoveLine.add('$from$to${promo ?? ''}');
      _puzzleMoveChecked = false;
      _puzzleMoveCorrect = null;
      _studentShowPuzzleAnswer = false;
      _shownSolutionLineIndex = 0;
    }

    _afterHumanMoveCommon(san, isCapture);
    _checkGameOver();
    unawaited(_refreshEvalBar());
    if (_room != null) {
      await _room!.sendMove(from: from, to: to, promotion: promo);
    }

    if (_vsEngine && game.turn != _humanColor && !game.game_over) {
      await _engineMove();
    }
  }

  void _broadcastClockSnapshot() {
    if (_room == null) return;
    _room!.sendCtrl({
      'type': 'clock',
      'w': _whiteMs,
      'b': _blackMs,
      'turn': (game.turn == ch.Color.WHITE) ? 'w' : 'b',
      'ts': DateTime.now().millisecondsSinceEpoch,
      'clientId': _clientId,
      'roomId': _roomId,
    });
  }

  void _broadcastTimeControl() {
    if (_room == null) return;
    _room!.sendCtrl({
      'type': 'tc',
      'm': _tcMinutes,
      'inc': _tcIncrement,
      'rated': _matchRated,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'clientId': _clientId,
      'roomId': _roomId,
    });
  }

  Future<void> _offerDrawOnline() async {
    if (!_inRoom || game.game_over || _isSpectator) return;

    setState(() {
      _drawOfferedByMe = true;
      _drawOfferedToMe = false;
    });

    await _room!.sendDrawOffer(
      fromUserId: Supabase.instance.client.auth.currentUser?.id ?? '',
      fromName: _nickname ?? 'me',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Предложение ничьей отправлено')),
    );
  }

  // Универсальная кнопка "Предложить ничью"
  Future<void> _offerDrawUniversal() async {
    if (!_inRoom || _isSpectator) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Предложение ничьей доступно только в онлайне')),
        );
      }
      return;
    }
    await _offerDrawOnline();
  }

  Future<void> _acceptDrawOnline() async {
    if (!_inRoom || !_drawOfferedToMe) return;

    await _room!.sendDrawAnswer(
      fromUserId: Supabase.instance.client.auth.currentUser?.id ?? '',
      fromName: _nickname ?? 'me',
      accepted: true,
    );

    setState(() {
      _drawOfferedByMe = false;
      _drawOfferedToMe = false;
    });

    _finishGameWithResult('1/2-1/2', 'Ничья по соглашению');
  }

  Future<void> _declineDrawOnline() async {
    if (!_inRoom || !_drawOfferedToMe) return;

    await _room!.sendDrawAnswer(
      fromUserId: Supabase.instance.client.auth.currentUser?.id ?? '',
      fromName: _nickname ?? 'me',
      accepted: false,
    );

    setState(() {
      _drawOfferedByMe = false;
      _drawOfferedToMe = false;
    });
  }

  Future<void> _resignOnline() async {
    if (!_inRoom || game.game_over || _isSpectator) return;

    await _room!.sendResign(
      fromUserId: Supabase.instance.client.auth.currentUser?.id ?? '',
      fromName: _nickname ?? 'me',
    );

    final result = (_humanColor == ch.Color.WHITE) ? '0-1' : '1-0';
    _finishGameWithResult(result, 'Сдача');
  }

  void _maybeAskDrawDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false, // чтобы не закрывали тапом по фону
      builder: (ctx) => AlertDialog(
        // <- используем локальный ctx
        title: const Text('Ничья?'),
        content: const Text('Соперник предлагает ничью. Принять?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // <- закрываем ЭТОТ диалог
              _declineDrawOnline();
            },
            child: const Text('Отклонить'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // <- закрываем ЭТОТ диалог
              _acceptDrawOnline();
            },
            child: const Text('Принять'),
          ),
        ],
      ),
    );
  }

  Future<void> _offerRematch() async {
    if (!_inRoom || _isSpectator) return;
    final mode = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Реванш'),
        content: const Text('Как сыграть реванш?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, 'same'),
              child: const Text('Те же цвета')),
          TextButton(
              onPressed: () => Navigator.pop(context, 'flip'),
              child: const Text('Поменять цвета')),
          FilledButton(
              onPressed: () => Navigator.pop(context, 'random'),
              child: const Text('Случайно')),
        ],
      ),
    );
    if (mode == null) return;
    setState(() => _rematchOfferedByMe = true);
    await _room!.sendCtrl({
      'type': 'rematch_offer',
      'mode': mode,
      'from': Supabase.instance.client.auth.currentUser?.id,
      'fromName': _nickname,
      'clientId': _clientId,
      'roomId': _roomId,
    });
  }

  Future<void> _acceptRematch() async {
    if (!_rematchOfferedToMe) return;
    setState(() => _rematchOfferedToMe = false);
    await _room!.sendCtrl({
      'type': 'rematch_accept',
      'mode': 'same',
      'from': Supabase.instance.client.auth.currentUser?.id,
      'fromName': _nickname,
      'clientId': _clientId,
      'roomId': _roomId,
    });
  }

  Future<void> _declineRematch() async {
    if (!_rematchOfferedToMe) return;
    setState(() => _rematchOfferedToMe = false);
    await _room!.sendCtrl({
      'type': 'rematch_decline',
      'from': Supabase.instance.client.auth.currentUser?.id,
      'fromName': _nickname,
      'clientId': _clientId,
      'roomId': _roomId,
    });
  }

  void _maybeAskRematchDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Реванш?'),
        content: const Text('Соперник предлагает реванш. Принять?'),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _declineRematch();
              },
              child: const Text('Отклонить')),
          FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _acceptRematch();
              },
              child: const Text('Принять')),
        ],
      ),
    );
  }

  void _startRematch({required String modeFromOpponent}) {
    String myColor = (_humanColor == ch.Color.WHITE) ? 'white' : 'black';
    if (modeFromOpponent == 'flip') {
      myColor = (myColor == 'white') ? 'black' : 'white';
    } else if (modeFromOpponent == 'random') {
      myColor = (math.Random().nextBool()) ? 'white' : 'black';
    }
    setState(() {
      _humanColor = (myColor == 'white') ? ch.Color.WHITE : ch.Color.BLACK;
    });

    game.reset();
    _fenController.text = game.fen;
    _sanMoves..clear();
    _fens
      ..clear()
      ..add(game.fen);
    _plyIndex = 0;
    _resetClocks();

    _broadcastTimeControl();
  }

// === ЛЕВАЯ ПАНЕЛЬ КНОПОК (над Лобби) ===============================
// == ЛЕВЫЕ КНОПКИ: сетка 2×3, без "Редактор" ==
  Widget _LeftUtilityButtons() {
    final bool canVsEngine = !_inRoom;
    final bool canContinueVsEngine = !_inRoom && !_vsEngine;
    final bool canContinueVsHuman = _vsEngine && !_inRoom;

    return GameModePanel(
      leftColWidth: _leftColWidth,
      canVsEngine: canVsEngine,
      canContinueVsEngine: canContinueVsEngine,
      canContinueVsHuman: canContinueVsHuman,
      inRoom: _inRoom,
      syncBoard: _syncBoard,
      vsEngine: _vsEngine,
      humanColor: _humanColor,
      duelDelayCtl: _duelDelayCtl,
      onContinueVsEngine: _continueVsEngine,
      onContinueVsHuman: _continueVsHuman,
      onToggleSyncBoard: _toggleSyncBoard,
      onStartEngineDuel: _startEngineDuel,
      onNewGame: _onNewGameUniversal,
      onHumanColorChanged: (color) {
        setState(() {
          _humanColor = color;
        });
      },
      onEngineDelayChanged: (v) {
        final n = int.tryParse(v);
        if (n != null) _engineDuelDelayMs = n;
      },
    );
  }

// Компактный переключатель цвета (Белые/Чёрные) в одну ячейку сетки

// Компактное поле "Задержка, мс" (для дуэли движков)

// === ПРАВАЯ ПАНЕЛЬ ПОД MOVES (стрелки + действия + анализ) =========

// === ЕДИНЫЙ КОНТЕНТ (адаптив) ==============================================
// === ЕДИНЫЙ КОНТЕНТ (адаптив, без showChat внутри) ===
  Widget _buildMobileMovesAndControls(double width) {
    final gap = 8.0;
    final controlsWidth = (width - gap) * 0.52;
    final movesWidth = width - gap - controlsWidth;
    return SizedBox(
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: controlsWidth,
            height: 470,
            child: RightSidebarPanel(
              plyIndex: _plyIndex,
              sanMoves: _sanMoves,
              onGoStart: _goStart,
              onGoPrev: _goPrev,
              onGoNext: _goNext,
              onGoEnd: _goEnd,
              onResignPressed: _onResignPressed,
              offerDrawUniversal: _offerDrawUniversal,
              loading: _loading,
              onBestMove: () async {
                final fen = _fenController.text.trim().isEmpty
                    ? game.fen
                    : _fenController.text.trim();
                await _fetchUciBestMove(fen);
              },
              gptLoading: _gptLoading,
              explainHere: _explainHere,
              showFenInput: _showFenInput,
              toggleFenInput: () =>
                  setState(() => _showFenInput = !_showFenInput),
              loadingBest: _loadingBest,
              onTakeBestMove: _onTakeBestMove,
              loadingAnalysis: _loadingAnalysis,
              onOpenAnalysis: _onOpenAnalysis,
              openGptPromptDialog: _openGptPromptDialog,
              inRoom: _inRoom,
              sharedControl: _sharedControl,
              editMode: _editMode,
              applyEditor: _applyEditor,
              enterEditor: _enterEditor,
              compact: true,
            ),
          ),
          SizedBox(width: gap),
          MoveListPanel(
            san: _sanMoves,
            currentPly: _plyIndex,
            controller: _movesScroll,
            onCopyPGN: () => unawaited(_copyPgnAndSaveToCabinet()),
            onClear: () {
              setState(() {
                _sanMoves.clear();
                _fens
                  ..clear()
                  ..add(game.fen);
                _plyIndex = 0;
                if (_showPuzzleMoveResultPanel) {
                  _resetStudentPuzzleMoveCheck();
                  _studentShowPuzzleAnswer = false;
                }
              });
            },
            puzzleMoveChecked:
                _showPuzzleMoveResultPanel ? _puzzleMoveChecked : false,
            puzzleMoveCorrect:
                _showPuzzleMoveResultPanel ? _puzzleMoveCorrect : null,
            showPuzzleCorrectAnswer:
                _showPuzzleMoveResultPanel && _studentShowPuzzleAnswer,
            correctPuzzleLines: _activePuzzleSolutionMoveLines,
            selectedCorrectLineIndex: _shownSolutionLineIndex,
            onPreviousCorrectLine: _openPreviousSolutionLine,
            onNextCorrectLine: _openNextSolutionLine,
            width: movesWidth,
            height: 470,
            compact: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileGameModeIcons(double width) {
    Widget action({
      required String tooltip,
      required Widget icon,
      required VoidCallback? onPressed,
      bool active = false,
    }) {
      return Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 42,
          height: 42,
          child: IconButton(
            onPressed: onPressed,
            icon: IconTheme(
              data: const IconThemeData(size: 19),
              child: icon,
            ),
            color: active ? Colors.lightBlueAccent : Colors.white,
            disabledColor: Colors.white30,
            style: IconButton.styleFrom(
              backgroundColor: active
                  ? Colors.lightBlue.withValues(alpha: 0.18)
                  : const Color(0xFF252B33),
              side: BorderSide(
                color: active ? Colors.lightBlueAccent : Colors.white12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF171B20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          action(
            tooltip: 'Играть с человеком',
            icon: const Icon(Icons.people),
            onPressed: _vsEngine && !_inRoom ? _continueVsHuman : null,
          ),
          action(
            tooltip: 'Играть с компьютером',
            icon: const Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                    left: -9, top: 3, child: Icon(Icons.person, size: 16)),
                Positioned(
                    left: 3,
                    top: 1,
                    child: Icon(Icons.desktop_windows, size: 18)),
              ],
            ),
            onPressed: !_inRoom && !_vsEngine ? _continueVsEngine : null,
          ),
          action(
            tooltip: 'Компьютер против компьютера',
            icon: const Icon(Icons.view_stream_outlined),
            onPressed: !_inRoom ? _startEngineDuel : null,
          ),
          action(
            tooltip: 'Совместный режим',
            icon: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person, size: 14),
                Text('&',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                Icon(Icons.person, size: 14),
              ],
            ),
            active: _syncBoard,
            onPressed: _toggleSyncBoard,
          ),
          action(
            tooltip: _humanColor == ch.Color.WHITE
                ? 'Вы играете белыми'
                : 'Вы играете чёрными',
            icon: const Icon(Icons.contrast),
            onPressed: (!_inRoom && !_vsEngine)
                ? () => setState(() {
                      _humanColor = _humanColor == ch.Color.WHITE
                          ? ch.Color.BLACK
                          : ch.Color.WHITE;
                    })
                : null,
          ),
          action(
            tooltip: 'Новый игрок',
            icon: const Icon(Icons.fiber_new),
            onPressed: _onNewGameUniversal,
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(double boardSize, bool isLogged, bool isMobile) {
    // Десктоп строим в логических размерах 100%, а затем масштабируем целиком.
    // Поэтому вместе с доской пропорционально меняются кнопки, текст, значки,
    // отступы и обе боковые панели. Видеосвязь и игровая логика не затрагиваются.
    final double desktopScale = boardSize / _baseAt100;
    final double logicalBoardSize = _baseAt100;
    final double logicalSidePanelWidth = logicalBoardSize * 0.7 * 1.2;
    const double logicalDesktopGap = 16.0;
    const double logicalCenterExtra = 92.0;
    final double logicalCenterWidth = logicalBoardSize + logicalCenterExtra;
    final double logicalDesktopWidth =
        logicalSidePanelWidth * 2 + logicalCenterWidth + logicalDesktopGap * 2;
    final double actualDesktopWidth = logicalDesktopWidth * desktopScale;
    final double logicalPanelHeight = math.max(
      640.0,
      MediaQuery.of(context).size.height - 96,
    );

    Widget scaledDesktop(Widget child) {
      final scaled = SizedBox(
        width: actualDesktopWidth,
        child: FittedBox(
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: logicalDesktopWidth,
            child: child,
          ),
        ),
      );

      // Сохраняем прежнее поведение увеличения выше 100%:
      // интерфейс можно прокручивать по горизонтали, а не сжимать обратно.
      if (_boardPercent > 100.0) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: scaled,
        );
      }
      return scaled;
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 8,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isMobile) ...[
            if (_mobilePanel == 'lobby') ...[
              LobbyPanel(
                isLoggedIn: isLogged,
                inLobby: _lobby != null,
                online: _lobby?.online ?? const [],
                myId: Supabase.instance.client.auth.currentUser?.id,
                myRating: _myRating,
                onEnterLobby: _enterLobby,
                onLeaveLobby: _leaveLobby,
                onInvite: (id, name) => _invitePlayer(id, name),
              ),
            ] else if (_mobilePanel == 'game') ...[
              SizedBox(
                width: boardSize,
                child: _LeftUtilityButtons(),
              ),
            ] else if (_mobilePanel == 'moves') ...[
              _buildMobileMovesAndControls(boardSize),
            ] else if (_mobilePanel == 'chat') ...[
              _buildChat(
                maxWidth: boardSize,
                height: 420,
              ),
            ] else ...[
              _buildMobileGameModeIcons(boardSize),
              const SizedBox(height: 8),
              _buildLeftColumn(
                boardSize,
                showChat: false,
                showBottomTools: false,
              ),
              const SizedBox(height: 12),
              _buildMobileMovesAndControls(boardSize),
              if (_showLearningPanel || _mobilePanel == 'learning') ...[
                const SizedBox(height: 16),
                LearningPanel(
                  activeAnalysisKey: _learningAnalysisArrowKey,
                  showAnswer: _learningShowAnswer,
                  activeAnalysisSide: _learningAnalysisSide,
                  analysisResults: _learningAnalysisResults,
                  onAnalysisSideToggle: _toggleLearningAnalysisSide,
                  onAnalysisModeChanged: _setLearningAnalysisMode,
                  drawingEnabled: _learningDrawingEnabled,
                  onToggleDrawing: _toggleLearningDrawing,
                  onFinishAnalysis: _finishLearningAnalysisTask,
                  onShowAnswerChanged: _setLearningShowAnswer,
                  onRoleChanged: _handleLearningRoleChanged,
                  onLoadPosition: () {
                    _editMode ? _applyEditor() : _enterEditor();
                  },
                  onToggleSharedMode: _toggleSyncBoard,
                  sharedModeEnabled: _syncBoard,
                  onToggleStudentEvaluation: () =>
                      unawaited(_toggleLearningStudentEvaluation()),
                  studentEvaluationEnabled:
                      _selectedLearningStudentEvaluationEnabled,
                  role: _learningRole,
                  students: _learningStudents,
                  selectedStudentId: _selectedLearningStudentId,
                  selectedVideoStudentIds: _selectedVideoStudentIds,
                  confirmedStudentId: _confirmedLearningStudentId,
                  invitationStatus: _learningInvitationStatus,
                  onAddStudent: _addLearningStudent,
                  onStudentSelected: _selectLearningStudent,
                  onVideoStudentToggled: _toggleVideoLearningStudent,
                  onInviteStudentToGame: _inviteLearningStudentToGame,
                  onInviteSelectedStudent: _inviteSelectedLearningStudent,
                  showAllBoards: _learningShowAllBoards,
                  onToggleBoardsView: _toggleLearningBoardsView,
                  onStudentDoubleTap: _focusLearningStudentBoard,
                  activeBoardStudentId: _learningFocusedStudentId,
                  onlineStudentIds: _learningOnlineStudentIds,
                  connectedGameStudentIds: _learningConnectedGameStudentIds,
                  pendingGameStudentIds: _learningPendingGameStudentIds,
                  onEndStudentGame: _endLearningStudentGame,
                  width: boardSize,
                  height: math.max(
                    640.0,
                    MediaQuery.of(context).size.height - 96,
                  ),
                ),
              ] else if (_showPuzzlePanel || _mobilePanel == 'puzzles') ...[
                const SizedBox(height: 16),
                PuzzleTypesPanel(
                  selectedType: _selectedPuzzleType,
                  onTypeSelected: (type) {
                    setState(() {
                      _selectedPuzzleType = type;
                      _activePublishedPuzzleIndex = -1;
                    });
                  },
                  onOpenTasksTap: _openPublishedPuzzlesFolder,
                  onSettingsTap: _openPuzzleSettings,
                  publishedTasks: _visiblePublishedPuzzleTasks,
                  activeTaskIndex: _activePublishedPuzzleIndex,
                  loadingTasks: _loadingPublishedPuzzleTasks,
                  onTaskSelected: _activatePublishedPuzzle,
                  onPreviousTask: _activatePreviousPublishedPuzzle,
                  onNextTask: _activateNextPublishedPuzzle,
                  activeAnalysisKey: _studentAnalysisArrowKey,
                  showAnswer: _studentShowPuzzleAnswer,
                  activeAnalysisSide: _studentAnalysisSide,
                  analysisResults: _studentAnalysisResults,
                  onAnalysisSideToggle: _toggleStudentAnalysisSide,
                  onAnalysisModeChanged: _setStudentPuzzleAnalysisMode,
                  onFinishAnalysis: _finishStudentPuzzleAnalysisTask,
                  onShowAnswerChanged: _setStudentShowPuzzleAnswer,
                  width: boardSize,
                  height: math.max(
                    640.0,
                    MediaQuery.of(context).size.height - 96,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
          ] else ...[
            // ===== Десктоп: три колонки =====
            // ===== Десктоп: три колонки =====
            scaledDesktop(
              PlayLayout(
                leftWidth: logicalSidePanelWidth,
                centerWidth: logicalCenterWidth,
                rightWidth: logicalSidePanelWidth,
                gap: logicalDesktopGap,
                padding: EdgeInsets.zero,
                left: _showLearningPanel
                    ? LearningPanel(
                        activeAnalysisKey: _learningAnalysisArrowKey,
                        showAnswer: _learningShowAnswer,
                        activeAnalysisSide: _learningAnalysisSide,
                        analysisResults: _learningAnalysisResults,
                        onAnalysisSideToggle: _toggleLearningAnalysisSide,
                        onAnalysisModeChanged: _setLearningAnalysisMode,
                        drawingEnabled: _learningDrawingEnabled,
                        onToggleDrawing: _toggleLearningDrawing,
                        onFinishAnalysis: _finishLearningAnalysisTask,
                        onShowAnswerChanged: _setLearningShowAnswer,
                        onRoleChanged: _handleLearningRoleChanged,
                        onLoadPosition: () {
                          _editMode ? _applyEditor() : _enterEditor();
                        },
                        onToggleSharedMode: _toggleSyncBoard,
                        sharedModeEnabled: _syncBoard,
                        onToggleStudentEvaluation: () =>
                            unawaited(_toggleLearningStudentEvaluation()),
                        studentEvaluationEnabled:
                            _selectedLearningStudentEvaluationEnabled,
                        role: _learningRole,
                        students: _learningStudents,
                        selectedStudentId: _selectedLearningStudentId,
                        selectedVideoStudentIds: _selectedVideoStudentIds,
                        confirmedStudentId: _confirmedLearningStudentId,
                        invitationStatus: _learningInvitationStatus,
                        onAddStudent: _addLearningStudent,
                        onStudentSelected: _selectLearningStudent,
                        onVideoStudentToggled: _toggleVideoLearningStudent,
                        onInviteStudentToGame: _inviteLearningStudentToGame,
                        onInviteSelectedStudent: _inviteSelectedLearningStudent,
                        showAllBoards: _learningShowAllBoards,
                        onToggleBoardsView: _toggleLearningBoardsView,
                        onStudentDoubleTap: _focusLearningStudentBoard,
                        activeBoardStudentId: _learningFocusedStudentId,
                        onlineStudentIds: _learningOnlineStudentIds,
                        connectedGameStudentIds:
                            _learningConnectedGameStudentIds,
                        pendingGameStudentIds: _learningPendingGameStudentIds,
                        onEndStudentGame: _endLearningStudentGame,
                        width: logicalSidePanelWidth,
                        height: logicalPanelHeight,
                      )
                    : _showPuzzlePanel
                        ? PuzzleTypesPanel(
                            selectedType: _selectedPuzzleType,
                            onTypeSelected: (type) {
                              setState(() {
                                _selectedPuzzleType = type;
                                _activePublishedPuzzleIndex = -1;
                              });
                            },
                            onOpenTasksTap: _openPublishedPuzzlesFolder,
                            onSettingsTap: _openPuzzleSettings,
                            publishedTasks: _visiblePublishedPuzzleTasks,
                            activeTaskIndex: _activePublishedPuzzleIndex,
                            loadingTasks: _loadingPublishedPuzzleTasks,
                            onTaskSelected: _activatePublishedPuzzle,
                            onPreviousTask: _activatePreviousPublishedPuzzle,
                            onNextTask: _activateNextPublishedPuzzle,
                            activeAnalysisKey: _studentAnalysisArrowKey,
                            showAnswer: _studentShowPuzzleAnswer,
                            activeAnalysisSide: _studentAnalysisSide,
                            analysisResults: _studentAnalysisResults,
                            onAnalysisSideToggle: _toggleStudentAnalysisSide,
                            onAnalysisModeChanged:
                                _setStudentPuzzleAnalysisMode,
                            onFinishAnalysis: _finishStudentPuzzleAnalysisTask,
                            onShowAnswerChanged: _setStudentShowPuzzleAnswer,
                            width: logicalSidePanelWidth,
                            height: logicalPanelHeight,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _LeftUtilityButtons(),
                              const SizedBox(height: 12),
                              LobbyPanel(
                                isLoggedIn: isLogged,
                                inLobby: _lobby != null,
                                online: _lobby?.online ?? const [],
                                myId: Supabase
                                    .instance.client.auth.currentUser?.id,
                                myRating: _myRating,
                                onEnterLobby: _enterLobby,
                                onLeaveLobby: _leaveLobby,
                                onInvite: (id, name) => _invitePlayer(id, name),
                              ),
                              const SizedBox(height: 12),
                              _buildChat(
                                  maxWidth: logicalSidePanelWidth, height: 220),
                            ],
                          ),
                center: _showLearningPanel &&
                        _learningRole == LearningPanelRole.teacher
                    ? _buildLearningBoardsArea(
                        width: logicalCenterWidth,
                        height: logicalPanelHeight,
                      )
                    : _buildLeftColumn(
                        logicalBoardSize,
                        showChat: false,
                        showBottomTools: false,
                      ),
                right: _buildDesktopRightColumn(logicalSidePanelWidth),
              ),
            ),
            // ⚠️ На десктопе нижние инструменты НЕ выводим, чтобы не было дубля
          ],
        ],
      ),
    );
  }

// --- публичные методы для AppShell ---

  void openBoardTheme() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Тема доски: в разработке')),
    );
  }

  void openGptSettings() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('GPT: настройки в разработке')),
    );
  }

  Future<void> _pickBackgroundImage() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true, // критично для web/desktop
    );
    if (res == null || res.files.isEmpty) return;

    final bytes = res.files.first.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось прочитать файл')),
        );
      }
      return;
    }

    // применяем + сохраняем
    await bgController.setBg(bytes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Фон обновлён')),
      );
    }
  }

// публичный метод, который дёргаем из AppShell:
  void openPickBackground() => _pickBackgroundImage();

  bool _loadingBest = false;
  bool _loadingAnalysis = false;

  Future<void> _onTakeBestMove() async {
    if (_loadingBest) return;
    setState(() => _loadingBest = true);

    try {
      final fen = (_fenController.text.trim().isEmpty)
          ? game.fen
          : _fenController.text.trim();

      final rich = await sf.getAnalysisRaw(
        fen,
        depth: 18,
        multiPv: 1, // один лучший вариант
        maxThinkingTime: 2000,
      );

      if (!mounted) return;

      final txt = (rich['text'] as String?) ?? (rich['uci'] as String?) ?? 'OK';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(txt)));

      // Если хочешь — можешь взять rich['uci'] и сразу применить ход к доске.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Stockfish: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingBest = false);
    }
  }

// ---------- 1) Извлечь краткую выжимку из "богатого" ответа ----------
  String _sfSummaryFromRich(Map<String, dynamic> rich) {
    final depth = rich['depth'] ?? rich['analysisDepth'] ?? rich['d'] ?? '';
    final best = (rich['best'] ?? rich['move'] ?? rich['uci'] ?? '').toString();
    final text = (rich['text'] ?? '').toString();

    // оценка / мат — берём из score/mate/centipawns
    String evalStr = '';
    if (rich['mate'] != null) {
      evalStr = 'mate ${rich['mate']}';
    } else if (rich['score'] is Map) {
      final s = rich['score'] as Map;
      if (s['mate'] != null) {
        evalStr = 'mate ${s['mate']}';
      } else if (s['value'] != null) {
        evalStr = 'cp ${s['value']}';
      }
    } else if (rich['centipawns'] != null) {
      evalStr = 'cp ${rich['centipawns']}';
    } else if (rich['eval'] != null) {
      evalStr = 'eval ${rich['eval']}';
    }

    final winChance =
        rich['winChance'] != null ? 'winChance: ${rich['winChance']}' : '';
    return [
      if (text.isNotEmpty) text,
      if (best.isNotEmpty) 'Best: $best',
      if (evalStr.isNotEmpty) 'Score: $evalStr',
      if (depth.toString().isNotEmpty) 'Depth: $depth',
      if (winChance.isNotEmpty) winChance,
    ].where((s) => s.trim().isNotEmpty).join('\n');
  }

// ---------- 2) Попробовать вытащить несколько PV/продолжений ----------
  List<String> _pvLinesFromRich(Map<String, dynamic> rich) {
    final res = <String>[];

    // Вариант 1: готовый массив линий
    if (rich['lines'] is List) {
      for (final ln in (rich['lines'] as List)) {
        if (ln is Map && ln['pv'] is String) res.add(ln['pv']);
      }
    }

    // Вариант 2: continuation / continuationArr
    if (res.isEmpty && rich['continuation'] is List) {
      final cont = (rich['continuation'] as List).cast<Map>();
      final moves = cont.map((m) => '${m['from']}${m['to']}').join(' ');
      if (moves.isNotEmpty) res.add(moves);
    }
    if (res.isEmpty && rich['continuationArr'] is List) {
      final arr = (rich['continuationArr'] as List).cast<String>();
      if (arr.isNotEmpty) res.add(arr.join(' '));
    }

    // Вариант 3: pv строкой
    if (res.isEmpty &&
        rich['pv'] is String &&
        (rich['pv'] as String).trim().isNotEmpty) {
      res.add(rich['pv'] as String);
    }

    return res.take(3).toList(); // до 3-х линий хватает
  }

// ---------- 3) Сформировать понятный промпт для GPT ----------
  String _buildGptPromptWithStockfish({
    required String fen,
    required Map<String, dynamic> rich,
  }) {
    final side = fen.contains(' w ') ? 'White to move' : 'Black to move';
    final summary = _sfSummaryFromRich(rich);
    final pvs = _pvLinesFromRich(rich);

    final prettyJson = const JsonEncoder.withIndent('  ').convert(rich);

    return '''
You are a strong chess coach. Explain the position for an intermediate player.

FEN: $fen
Side to move: $side

Stockfish summary:
$summary

Top candidate lines (from engine):
${pvs.isEmpty ? '(no PV lines were provided)' : pvs.map((e) => '• $e').join('\n')}

Tasks:
1) Explain the best plan and the main idea behind the best move.
2) Give typical plans for both sides in this structure.
3) Mention tactical motifs or traps to watch out for.
4) Keep it concise and actionable.

(For reference only, raw engine payload below — do NOT just repeat it):
$prettyJson
''';
  }

  double _extractEvalFromRich(Map<String, dynamic> raw) {
    // mate имеет приоритет
    final mate =
        raw['mate'] ?? (raw['score'] is Map ? raw['score']['mate'] : null);
    if (mate is num) {
      if (mate == 0) return 0.0;
      return mate > 0 ? 15.0 : -15.0;
    }

    // обычная оценка
    final dynamic evalRaw = raw['eval'] ??
        raw['centipawns'] ??
        (raw['score'] is Map ? raw['score']['value'] : null);

    if (evalRaw == null) return 0.0;

    if (evalRaw is num) {
      // Если пришли "центопешки" типа 124 -> 1.24
      final double val =
          evalRaw.abs() > 20 ? evalRaw / 100.0 : evalRaw.toDouble();
      return val.clamp(-15.0, 15.0);
    }

    final s = evalRaw.toString().replaceAll(',', '.').trim();
    final parsed = double.tryParse(s);
    if (parsed == null) return 0.0;

    final double val = parsed.abs() > 20 ? parsed / 100.0 : parsed;
    return val.clamp(-15.0, 15.0);
  }

  Future<void> _refreshLearningSessionEval(
    _LearningGameSession session,
  ) async {
    final fen = session.game.fen;
    final requestEpoch = ++session.evalRequestEpoch;
    session.loadingEval = true;
    session.lastEvalFen = fen;

    try {
      final raw = await sf.getAnalysisRaw(
        fen,
        depth: 14,
        multiPv: 1,
        maxThinkingTime: 900,
      );
      final eval = _extractEvalFromRich(raw);

      if (!mounted ||
          requestEpoch != session.evalRequestEpoch ||
          session.game.fen != fen ||
          _learningGameSessions[session.student.id] != session) {
        return;
      }
      setState(() {
        session.engineEval = eval;
      });
    } catch (_) {
      // Оставляем последнюю корректную оценку этой доски.
    } finally {
      if (requestEpoch == session.evalRequestEpoch) {
        session.loadingEval = false;
      }
    }
  }

  Future<void> _refreshEvalBar() async {
    final requestEpoch = ++_evalRequestEpoch;
    _loadingEval = true;

    try {
      final String fen = game.fen;
      _lastEvalScheduledFen = fen;

      final raw = await sf.getAnalysisRaw(
        fen,
        depth: 16,
        multiPv: 1,
        maxThinkingTime: 1200,
      );

      final eval = _extractEvalFromRich(raw);

      if (!mounted || requestEpoch != _evalRequestEpoch || game.fen != fen) {
        return;
      }
      setState(() {
        _engineEval = eval;
      });
    } catch (_) {
      // молча оставляем последнюю оценку
    } finally {
      if (requestEpoch == _evalRequestEpoch) {
        _loadingEval = false;
      }
    }
  }

  Future<void> _onOpenAnalysis() async {
    if (_loadingAnalysis) return;
    setState(() => _loadingAnalysis = true);

    try {
      final String fenInput = _fenController.text.trim();
      final String fen = fenInput.isEmpty ? game.fen : fenInput;

      // 1) БЕРЁМ ПОЛНЫЙ JSON (а не текст!)
      final raw = await sf.getAnalysisRaw(
        fen,
        depth: 20, // можешь поднять до 22–24
        multiPv: 4, // топ-4 линии
        maxThinkingTime: 2500,
      );

      // Keep the evaluation bar synchronized with this exact analysis run.
      // The background bar calculation uses faster settings and may differ.
      final analysisEval = _extractEvalFromRich(raw);
      if (mounted) {
        setState(() => _engineEval = analysisEval);
      }

      // 2) Если есть «человеческий» текст — покажем сверху отдельным блоком
      final String text =
          (raw['text'] is String) ? (raw['text'] as String) : '';

      // 3) Красиво форматируем ВЕСЬ JSON
      const enc = JsonEncoder.withIndent('  ');
      final pretty = enc.convert(raw);

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Stockfish analysis'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (text.trim().isNotEmpty) ...[
                  SelectableText(text, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 12),
                ],
                const SelectableText(
                  'Details (raw):',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  pretty,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stockfish: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingAnalysis = false);
    }
  }

  // ================== BUILD (адаптив) ==================
  @override
  Widget build(BuildContext context) {
    // FEN is the single source of truth for evaluation. This catches every
    // position change, including history navigation, resets, FEN loading,
    // editor changes and remote synchronization.
    final currentFen = game.fen;
    if (_lastEvalScheduledFen != currentFen) {
      _lastEvalScheduledFen = currentFen;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && game.fen == currentFen) {
          unawaited(_refreshEvalBar());
        }
      });
    }

    final media = MediaQuery.of(context);
    final w = media.size.width;
    final h = media.size.height;

    // Телефонный режим: сначала только доска, остальные зоны открываются из меню.
    final bool isMobile = w < 760;
    final bool isLogged = Supabase.instance.client.auth.currentUser != null;

    final double requestedBoardSize = _baseAt100 * (_boardPercent / 100);

    // На десктопе весь трехколоночный интерфейс масштабируется как единое целое.
    // При 100% панели имеют 84% ширины доски: это ровно в 1,2 раза
    // шире прежних панелей по 70% ширины доски.
    final double logicalSidePanelWidth = _baseAt100 * 0.7 * 1.2;
    const double logicalCenterExtra = 92.0;
    const double logicalDesktopGap = 16.0;
    final double logicalDesktopWidth = logicalSidePanelWidth * 2 +
        (_baseAt100 + logicalCenterExtra) +
        logicalDesktopGap * 2;
    const double desktopOuterHorizontalPadding = 16.0;
    final double desktopWidthLimit = math.max(
      240.0,
      _baseAt100 * ((w - desktopOuterHorizontalPadding) / logicalDesktopWidth),
    );

    final double verticalLimit = math.max(240.0, h - 150.0);
    final double automaticFitLimit = isMobile
        ? math.max(240.0, w - 32.0)
        : math.max(240.0, math.min(verticalLimit, desktopWidthLimit));

    // При обычном масштабе сайт автоматически помещается в окно ноутбука.
    // Масштаб выше 100% считается осознанным увеличением пользователя и
    // может включить горизонтальную прокрутку.
    final double boardSize = math.max(
      240.0,
      _boardPercent <= 100.0
          ? math.min(requestedBoardSize, automaticFitLimit)
          : math.min(requestedBoardSize, verticalLimit),
    );

    // твой «core» контент страницы
    final Widget core = SafeArea(
      child: _withAuthOverlay(
        RepaintBoundary(
          child: CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildMainContent(boardSize, isLogged, isMobile),
              ),
            ],
          ),
        ),
      ),
    );

    // Фон + твой контент поверх
    return AnimatedBuilder(
      animation: bgController,
      builder: (context, _) {
        final bytes = _backgroundBytes ??
            bgController.bgBytes; // берем напрямую из контроллера

        return Stack(
          fit: StackFit.expand,
          children: [
            // ↓↓↓ ФОН ПОДО ВСЕМ UI ↓↓↓
            IgnorePointer(
              ignoring: true,
              child: (bytes != null)
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: MemoryImage(bytes),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : const ColoredBox(
                      color: Color(0xFFF3EAF7), // дефолтный светло-фиолетовый
                    ),
            ),
            // ↑↑↑ ФОН ПОДО ВСЕМ UI ↑↑↑

            // сам контент
            core,
          ],
        );
      },
    );
  }

  /// Единый контент страницы (адаптивный для мобильного/десктопа)

  /// Обёртка, которая накладывает форму логина поверх контента
// Положи это внутри _MyHomePageState
  Widget _withAuthOverlay(Widget child) {
    return Stack(
      clipBehavior: Clip.none, // чтобы панель могла выходить за границы
      children: [
        // НИЧЕГО НЕ ПЕРЕКРЫВАЕТ: просто контент
        child,

        // Только когда _authOpen == true — рисуем панель.
        if (_authOpen)
          Positioned(
            top: 12,
            right: 12,
            child: AuthPanel(
              isLogin: _authIsLogin,
              passCtl: _passCtl,
              nickCtl: _nickCtl,
              authError: _authError,
              onClose: () => setState(() => _authOpen = false),
              onToggleMode: () => setState(() => _authIsLogin = !_authIsLogin),
              onSubmit: _submitAuth,
            ),
          ),
      ],
    );
  }

// Палетка фигур + "корзина"
  Widget _editorPalette({
    required bool white, // true = белые, false = чёрные
    required double cellSize, // размер клетки (boardSize / 8)
  }) {
    final codes = white
        ? const ['wK', 'wQ', 'wR', 'wB', 'wN', 'wP']
        : const ['bK', 'bQ', 'bR', 'bB', 'bN', 'bP'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          // сами фигуры
          for (final code in codes) ...[
            Draggable<String>(
              data: code,
              feedback: Material(
                color: Colors.transparent,
                child: SvgPicture.asset(_assetFor(code),
                    width: cellSize * 0.9, height: cellSize * 0.9),
              ),
              childWhenDragging: const SizedBox(width: 8, height: 8),
              child: SvgPicture.asset(_assetFor(code),
                  width: cellSize * 0.9, height: cellSize * 0.9),
            ),
            const SizedBox(width: 8),
          ],

          const Spacer(),

          // "корзина" — перетащи сюда с доски чтобы удалить
          DragTarget<String>(
            onWillAccept: (_) =>
                _dragFromSquare != null, // принимаем только "с доски"
            onAccept: (_) {
              if (_dragFromSquare != null) {
                final r0 = _rankIndex(_dragFromSquare!);
                final f0 = _fileIndex(_dragFromSquare!);
                setState(() => _editBoard[r0][f0] = '.');
                _dragFromSquare = null;
              }
            },
            builder: (_, __, ___) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black26),
              ),
              child: const Row(
                children: [
                  Icon(Icons.delete_forever, size: 22),
                  SizedBox(width: 6),
                  Text('Удалить', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBody(double boardSize, bool isLogged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ← панель с кнопками вернулась
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: _buildTopBar(),
        ),
        const SizedBox(height: 10),

        // основной контент как и был: доска + ходы + лобби
        Expanded(
          child: // Десктопная раскладка — три колонки (Лобби • Доска • Ходы+управление)
              Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1) ЛОББИ СЛЕВА
              LobbyPanel(
                isLoggedIn: isLogged,
                inLobby: _lobby != null,
                online: _lobby?.online ?? const [],
                myId: Supabase.instance.client.auth.currentUser?.id,
                myRating: _myRating,
                onEnterLobby: _enterLobby,
                onLeaveLobby: _leaveLobby,
                onInvite: (id, name) => _invitePlayer(id, name),
              ),

              const SizedBox(width: 24),

              // 2) ДОСКА ПО ЦЕНТРУ
              _buildLeftColumn(boardSize, showBottomTools: false),

              const SizedBox(width: 24),

              RightSidebarPanel(
                plyIndex: _plyIndex,
                sanMoves: _sanMoves,
                onGoStart: _goStart,
                onGoPrev: _goPrev,
                onGoNext: _goNext,
                onGoEnd: _goEnd,
                onResignPressed: _onResignPressed,
                offerDrawUniversal: _offerDrawUniversal,
                loading: _loading,
                onBestMove: () async {
                  final fen = _fenController.text.trim().isEmpty
                      ? game.fen
                      : _fenController.text.trim();
                  await _fetchUciBestMove(fen);
                },
                gptLoading: _gptLoading,
                editMode: _editMode,
                applyEditor: _applyEditor,
                enterEditor: _enterEditor,
                explainHere: _explainHere,
                showFenInput: _showFenInput,
                toggleFenInput: () =>
                    setState(() => _showFenInput = !_showFenInput),
                loadingBest: _loadingBest,
                onTakeBestMove: _onTakeBestMove,
                loadingAnalysis: _loadingAnalysis,
                onOpenAnalysis: _onOpenAnalysis,
                openGptPromptDialog: _openGptPromptDialog,
                inRoom: _inRoom,
                sharedControl: _sharedControl,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBody(double boardSize, bool isLogged) {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;

    Future<void> _pickTimeControl() async {
      final res = await showDialog<_TcChoice>(
        context: context,
        builder: (_) => _TcDialog(
          initialMinutes: _tcMinutes,
          initialIncrement: _tcIncrement,
          initialRated: _inRoom ? _matchRated : _rated,
        ),
      );
      if (res != null) {
        _applyTimeControl(
          minutes: res.minutes,
          increment: res.increment,
          rated: res.rated,
          broadcast: _inRoom,
        );
      }
    }

    Widget _icon(String label, IconData icon, VoidCallback? onTap,
        {bool active = false}) {
      final color = active ? Theme.of(context).colorScheme.primary : null;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: label,
            onPressed: onTap,
            icon: Icon(icon, color: color),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            splashRadius: 22,
          ),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );
    }

    // высота области с вкладками под доской (адаптивно)
    final vh = MediaQuery.of(context).size.height;
    final double tabsHeight = (vh * 0.55).clamp(360.0, 620.0);

    return DefaultTabController(
      length: 3,
      // 🔴 Убрали SingleChildScrollView — ставим просто Padding
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------- Ряд иконок ----------
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                _icon('Новая', Icons.fiber_new, _onNewGameUniversal),
                _icon(
                  'Сдаться',
                  Icons.flag,
                  (!_inRoom && !game.game_over && !_gameTerminated)
                      ? _resignOffline
                      : null,
                ),
                _icon('ИИ', Icons.smart_toy,
                    (_inRoom) ? null : _startNewGameVsEngine),
                _icon('С человеком', Icons.group,
                    (_vsEngine && !_inRoom) ? _continueVsHuman : null),
                _icon('Продолжить', Icons.play_circle,
                    (!_inRoom && !_vsEngine) ? _continueVsEngine : null),
                _icon(
                  _syncBoard ? 'Совместный (вкл)' : 'Совместный',
                  Icons.sync,
                  _inRoom ? _toggleSyncBoard : null,
                  active: _syncBoard,
                ),
                _icon('Контроль', Icons.timer, _pickTimeControl),
                _icon(
                  'Рейтинг',
                  Icons.emoji_events,
                  _inRoom ? null : () => setState(() => _rated = !_rated),
                  active: _inRoom ? _matchRated : _rated,
                ),
                _icon(
                  _editMode ? 'Редактор (вкл)' : 'Редактор',
                  Icons.edit,
                  (_inRoom && !_sharedControl)
                      ? null
                      : (_editMode ? _applyEditor : _enterEditor),
                  active: _editMode,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ---------- Доска (часы + чат внутри) ----------
            _buildLeftColumn(boardSize, showBottomTools: false),

            const SizedBox(height: 10),

            // ---------- Кнопка «В лобби / Выйти» ----------
            SizedBox(
              height: 44,
              child: FilledButton.tonal(
                onPressed: () async {
                  if (!isLoggedIn) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Сначала войдите в аккаунт')),
                    );
                    return;
                  }
                  if (_lobby == null) {
                    await _enterLobby();
                  } else {
                    await _leaveLobby();
                  }
                  setState(() {});
                },
                child: Text(
                    (_lobby == null) ? 'В контакты' : 'Выйти из контактов'),
              ),
            ),

            const SizedBox(height: 12),

            // ---------- Вкладки ----------
            const TabBar(
              labelPadding: EdgeInsets.symmetric(horizontal: 8),
              tabs: [
                Tab(icon: Icon(Icons.sports_esports), text: 'Игра'),
                Tab(icon: Icon(Icons.list_alt), text: 'Ходы'),
                Tab(icon: Icon(Icons.people_alt), text: 'Контакты'),
              ],
            ),

            // ограничиваем высоту: всё остальное прокручивается сверху
            SizedBox(
              height: tabsHeight,
              child: TabBarView(
                children: [
                  // === ТАБ 1: Игра — инструменты (FEN/BestMove) ===
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
                    child: _buildBottomTools(),
                  ),

                  // === ТАБ 2: Ходы ===
                  Center(
                    child: SizedBox(
                      width: 320,
                      height: tabsHeight - 20,
                      child: MoveListPanel(
                        san: _sanMoves,
                        currentPly: _plyIndex,
                        controller: _movesScroll,
                        onCopyPGN: () => unawaited(_copyPgnAndSaveToCabinet()),
                        onClear: () {
                          setState(() {
                            _sanMoves.clear();
                            _fens
                              ..clear()
                              ..add(game.fen);
                            _plyIndex = 0;
                            if (_showPuzzleMoveResultPanel) {
                              _resetStudentPuzzleMoveCheck();
                              _studentShowPuzzleAnswer = false;
                            }
                          });
                        },
                        puzzleMoveChecked: _showPuzzleMoveResultPanel
                            ? _puzzleMoveChecked
                            : false,
                        puzzleMoveCorrect: _showPuzzleMoveResultPanel
                            ? _puzzleMoveCorrect
                            : null,
                        showPuzzleCorrectAnswer: _showPuzzleMoveResultPanel &&
                            _studentShowPuzzleAnswer,
                        correctPuzzleLines: _activePuzzleSolutionMoveLines,
                        selectedCorrectLineIndex: _shownSolutionLineIndex,
                        onPreviousCorrectLine: _openPreviousSolutionLine,
                        onNextCorrectLine: _openNextSolutionLine,
                      ),
                    ),
                  ),

                  // === ТАБ 3: Лобби ===
                  Center(
                    child: SizedBox(
                      width: 320,
                      height: tabsHeight - 20,
                      child: LobbyPanel(
                        isLoggedIn: isLoggedIn,
                        inLobby: _lobby != null,
                        online: _lobby?.online ?? const [],
                        myId: Supabase.instance.client.auth.currentUser?.id,
                        myRating: _myRating,
                        onEnterLobby: _enterLobby,
                        onLeaveLobby: _leaveLobby,
                        onInvite: (id, name) => _invitePlayer(id, name),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// === НАСТРОЙКИ: выбор фона/темы/параметров GPT ===

  Future<void> _openSettingsSheet() async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: false,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            children: [
              const ListTile(
                title: Text('Настройки',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.image), // было Icons.chess — заменили
                title: const Text('Тема фона'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickBackgroundImage();
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.grid_on), // было Icons.chess — заменили
                title: const Text('Тема доски'),
                subtitle: const Text('Цвета клеток и координат'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBoardThemeDialog(); // ваша существующая/заглушка
                },
              ),
              ListTile(
                leading: const Icon(Icons.psychology),
                title: const Text('Настройка GPT'),
                subtitle: const Text('Шаблон запроса и поведение'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showGptSettingsDialog(); // ваша существующая/заглушка
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBoardThemeDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Тема доски'),
        content: const Text('Здесь будет настройка цветов доски/координат.\n'
            'Пока заглушка, чтобы ничего не сломать.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showGptSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Настройка GPT'),
        content: const Text(
            'Здесь будет настройка шаблона запроса и дополнительных опций.\n'
            'Пока заглушка, чтобы ничего не сломать.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _openMainMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scroll) {
            Widget item(IconData icon, String title, VoidCallback onTap) {
              return ListTile(
                leading: Icon(icon),
                title: Text(title),
                onTap: () {
                  Navigator.pop(ctx);
                  onTap();
                },
              );
            }

            void notImpl(String what) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$what (в разработке)')),
              );
            }

            return ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              children: [
                const ListTile(
                  title: Text('Меню',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const Divider(),

                item(Icons.videogame_asset, 'Играть', () => notImpl('Играть')),
                item(Icons.school, 'Учиться', openLearningPanel),

                item(Icons.task_alt, 'Задачи', () => notImpl('Задачи')),
                item(Icons.grid_3x3, '2×2', () => notImpl('2×2')),
                item(Icons.emoji_events, 'Турниры', () => notImpl('Турниры')),

                item(Icons.forum, 'Настройка', () => notImpl('Настройка')),

                const Divider(),
                // Аккаунт (по желанию)
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Выйти из аккаунта'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _logout();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------- UI parts ----------
// === ШАПКА (показываем ТОЛЬКО на мобилке, чтобы не было дублей на десктопе) ===
// === ШАПКА (скрываем на десктопе, показываем на мобилке) ===
  Widget _buildTopBar() {
    final media = MediaQuery.of(context);
    final bool isMobile = media.size.width < 900;

    // на десктопе не показываем (чтобы не дублировать кнопки из колонок)
    if (!isMobile) return const SizedBox.shrink();

    // на мобильном показываем вашу прежнюю шапку (кнопки/селекторы)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          // ↓↓↓ Подставьте сюда ваши готовые виджеты из шапки
          // (цвет, старт/новая, редактор и т.п.) — те, что уже были у вас.
          // Пример (если у вас уже были эти билдеры):
          // _buildColorSelector(),
          // _buildPlayButtons(),
          // _buildEditorButton(),
        ],
      ),
    );
  }

  Widget _buildEngineDuelDelayField() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 130,
        child: TextField(
          controller: _duelDelayCtl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Задержка, мс',
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          ),
          onChanged: (v) {
            final parsed = int.tryParse(v);
            setState(() {
              _engineDuelDelayMs = (parsed ?? 2000).clamp(100, 60000);
            });
          },
        ),
      ),
    );
  }

  Widget _buildLeftColumn(
    double boardSize, {
    bool showChat = true,
    bool showBottomTools = true,
  }) {
    // Ширина «коробки» под доску: сама доска + подписи по 18px слева/снизу
    // (см. m=18 в _buildBoardWithCoords). Делаем одинаковую ширину для ВСЕГО столбца.
    final double totalSize = boardSize + 36.0;
    final cell = boardSize / 8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center, // <-- было start
      children: [
        _buildClockRow(playerIsTop: true, maxWidth: totalSize),
        const SizedBox(height: 6),

        if (_editMode)
          ConstrainedBox(
            // палетка не шире totalSize
            constraints: BoxConstraints(maxWidth: totalSize),
            child:
                _editorPalette(white: false, cellSize: cell), // ЧЁРНЫЕ СВЕРХУ
          ),

        // Доску тоже жёстко ограничим одной шириной, внутри — она уже центрирована
        SizedBox(
          width: totalSize + 56,
          child: RepaintBoundary(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double w = constraints.maxWidth;
                if (!w.isFinite || w <= 0) {
                  w = MediaQuery.of(context).size.width;
                }

                const double m = 18.0;
                final double rawInner = (w - m * 2 - 56).clamp(120.0, w);
                final double cell = (rawInner / 8).floorToDouble();
                final double boardSize = cell * 8;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBoardWithCoords(boardSize),
                    if (!_studentLearningRoomActive ||
                        _learningStudentEvaluationEnabled) ...[
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: SizedBox(
                          width: 36,
                          height: boardSize,
                          child: EvalBar(
                            eval: _engineEval,
                            flipped: _isFlipped,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),

// --- Кнопки под доской: Введите FEN • Взять лучший ход • Объяснить позицию

        if (showBottomTools) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: totalSize),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          key: const Key('btnBestMove_bottom'),
                          onPressed: _loadingBest ? null : _onTakeBestMove,
                          icon: _loadingBest
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.flash_on),
                          label: const Text('Взять лучший ход'),
                        ),
                        OutlinedButton.icon(
                          key: const Key('btnAnalysis'),
                          onPressed: _loadingAnalysis ? null : _onOpenAnalysis,
                          icon: _loadingAnalysis
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.analytics),
                          label: const Text('Stockfish Analysis'),
                        ),
                      ],
                    ),

                    FilledButton.icon(
                      onPressed:
                          _gptLoading ? null : _explainHere, // без доп. текста
                      icon: _gptLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.psychology),
                      label: Text(_gptLoading
                          ? 'Запрос к GPT...'
                          : 'Объяснить позицию'),
                    ),
                    // >>> НОВАЯ КНОПКА С ДИАЛОГОМ ВОПРОСА
                    FilledButton.icon(
                      onPressed: _gptLoading ? null : _openGptPromptDialog,
                      icon: const Icon(Icons.question_answer),
                      label: const Text('С вопросом…'),
                    ),
                  ],
                ),

                // Выезжающее поле ввода FEN
                AnimatedCrossFade(
                  crossFadeState: _showFenInput
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  duration: const Duration(milliseconds: 200),
                  firstChild: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    // 👇 мы просто делаем поле невидимым, без рамки и надписей
                    child: TextField(
                      controller: _fenController,
                      decoration: const InputDecoration(
                        border: InputBorder.none, // убрали рамку
                        labelText: '', // убрали надпись
                        hintText: '', // убрали placeholder
                        isDense: true,
                      ),
                      style: const TextStyle(
                          fontSize: 0), // 👈 текст не отображается
                      cursorColor: Colors.transparent, // 👈 курсор невидим
                      enableInteractiveSelection: false, // 👈 нельзя выделить
                      onSubmitted: (v) {
                        final ok =
                            game.load(v.trim().isEmpty ? game.fen : v.trim());
                        if (ok) {
                          setState(() {
                            _selectedSquare = null;
                            _legalTargets.clear();
                            _captureTargets.clear();
                            _sanMoves.clear();
                            _fens
                              ..clear()
                              ..add(game.fen);
                            _plyIndex = 0;
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Некорректный FEN: ${v.trim()}')),
                          );
                        }
                      },
                    ),
                  ),
                  secondChild: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],

        if (_editMode)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: totalSize),
            child: _editorPalette(white: true, cellSize: cell), // БЕЛЫЕ СНИЗУ
          ),

        const SizedBox(height: 20),
        _buildClockRow(playerIsTop: false, maxWidth: totalSize),
        if (showChat) ...[
          const SizedBox(height: 12),
          _buildChat(maxWidth: totalSize),
        ],
      ],
    );
  }

  Widget _deleteZone({required Widget child}) {
    return DragTarget<String>(
      onWillAccept: (_) => _editMode, // только в редакторе
      onAccept: (code) {
        // Удаляем фигуру из исходной клетки, если тянули с доски
        final from = _dragFromSquare;
        if (from != null) {
          final ri = _rankIndex(from);
          final fi = _fileIndex(from);
          setState(() {
            _editBoard[ri][fi] = '.';
          });
        }
        _dragFromSquare = null;
      },
      builder: (_, __, ___) => child,
    );
  }

  Widget _buildEditorToolbar() {
    // Кнопка-клетка палетки
    Widget paletteItem(String code) {
      final sz = 38.0;
      return Opacity(
        opacity: 1,
        child: Draggable<String>(
          data: code, // тащим КОД фигуры 'wK'/'bQ'...
          onDragStarted: () => _dragFromSquare = null, // тянем из палетки
          feedback: Material(
            color: Colors.transparent,
            child: SvgPicture.asset(_assetFor(code), width: sz, height: sz),
          ),
          childWhenDragging: SvgPicture.asset(_assetFor(code),
              width: sz, height: sz, color: Colors.black26),
          child: SvgPicture.asset(_assetFor(code), width: sz, height: sz),
        ),
      );
    }

    // Ряд палетки
    Widget row(List<String> codes) => Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: codes.map(paletteItem).toList(),
        );

    // «Корзина»: перетащи сюда фигуру С ДОСКИ, чтобы удалить
    final trash = DragTarget<String>(
      onWillAccept: (_) => true,
      onAccept: (data) {
        if (_dragFromSquare != null) {
          final ri = _rankIndex(_dragFromSquare!);
          final fi = _fileIndex(_dragFromSquare!);
          setState(() => _editBoard[ri][fi] = '.');
        }
        _dragFromSquare = null;
      },
      builder: (context, _, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline),
            SizedBox(width: 8),
            Text('Корзина (перетащите сюда с доски)'),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Строка управления (очистить/стартовая/ход/рокировки)
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    for (int r = 0; r < 8; r++) {
                      for (int c = 0; c < 8; c++) _editBoard[r][c] = '.';
                    }
                  });
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Очистить доску'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _editBoard = _fenToBoard(
                      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
                    );
                    _editTurn = ch.Color.WHITE;
                    _castleK = _castleQ = _castlek = _castleq = true;
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Стартовая'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Ход / рокировки
        Row(
          children: [
            const Text('Ход:'),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Белые'),
              selected: _editTurn == ch.Color.WHITE,
              onSelected: (_) => setState(() => _editTurn = ch.Color.WHITE),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Чёрные'),
              selected: _editTurn == ch.Color.BLACK,
              onSelected: (_) => setState(() => _editTurn = ch.Color.BLACK),
            ),
            const Spacer(),
            FilterChip(
                label: const Text('K'),
                selected: _castleK,
                onSelected: (v) => setState(() => _castleK = v)),
            const SizedBox(width: 6),
            FilterChip(
                label: const Text('Q'),
                selected: _castleQ,
                onSelected: (v) => setState(() => _castleQ = v)),
            const SizedBox(width: 6),
            FilterChip(
                label: const Text('k'),
                selected: _castlek,
                onSelected: (v) => setState(() => _castlek = v)),
            const SizedBox(width: 6),
            FilterChip(
                label: const Text('q'),
                selected: _castleq,
                onSelected: (v) => setState(() => _castleq = v)),
          ],
        ),
        const SizedBox(height: 10),

        // ПАЛЕТКИ
        const Text('Белые', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        row(const ['wK', 'wQ', 'wR', 'wB', 'wN', 'wP']),
        const SizedBox(height: 10),
        const Text('Чёрные', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        row(const ['bK', 'bQ', 'bR', 'bB', 'bN', 'bP']),
        const SizedBox(height: 12),

        // КНОПКИ Применить/Отмена + КОРЗИНА справа
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _applyEditor,
                icon: const Icon(Icons.check),
                label: const Text('Применить'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: !_gameTerminated ? _onResignPressed : null,
                icon: const Icon(Icons.flag),
                label: const Text('Сдаться'),
              ),
            ),
            const SizedBox(width: 12),
            trash,
          ],
        ),
      ],
    );
  }

  Widget _buildClockRow({required bool playerIsTop, double maxWidth = 560}) {
    final name =
        playerIsTop ? (_opponentName ?? 'opponent') : (_nickname ?? 'me');
    final rating = playerIsTop ? _oppRating : _myRating;
    final isMyRow = !playerIsTop;

    final ms = (playerIsTop) ? _blackMsIfTop() : _whiteMsIfBottom();

    final active = _inRoom &&
        ((game.turn == (_humanColor)) == isMyRow) &&
        !_isSpectator &&
        !game.game_over &&
        !_gameTerminated;

    final borderColor = active ? AppColors.borderBright : AppColors.borderSoft;
    final glowColor =
        active ? AppColors.accentGlowSoft : const Color(0x00000000);
    final iconColor = active ? AppColors.accent : AppColors.textDim;
    final textColor = active ? AppColors.text : AppColors.text;
    final timeColor = active ? AppColors.accent : AppColors.text;
    final showLearningStudentReset = !playerIsTop && _studentLearningRoomActive;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppDecorations.panelGradient,
                borderRadius: AppRadius.r10,
                border: Border.all(
                  color: borderColor,
                  width: active ? 1.2 : 1,
                ),
                boxShadow: [
                  const BoxShadow(
                    color: Color(0x77000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                  if (active)
                    BoxShadow(
                      color: glowColor,
                      blurRadius: 14,
                    ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    playerIsTop ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: iconColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$name  ($rating)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (showLearningStudentReset) ...[
                    Tooltip(
                      message: 'Расставить позицию заново',
                      child: IconButton(
                        onPressed: () => unawaited(
                          _confirmResetLearningStudentPosition(),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 30,
                          height: 30,
                        ),
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        icon: const Icon(Icons.restart_alt),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ] else
                    const SizedBox(width: 12),
                  Text(
                    _fmtMs(ms),
                    style: AppTextStyles.body.copyWith(
                      color: timeColor,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _whiteMsIfBottom() =>
      (_humanColor == ch.Color.WHITE) ? _whiteMs : _blackMs;
  int _blackMsIfTop() => (_humanColor == ch.Color.WHITE) ? _blackMs : _whiteMs;

  Widget _buildChat({double maxWidth = 560, double height = 220}) {
    return RoomChatPanel(
      roomId: _roomId,
      inRoom: _inRoom,
      messages: _chat
          .map((m) => RoomChatItem(
                from: m.from,
                text: m.text,
                mine: m.mine,
              ))
          .toList(),
      chatController: _chatCtl,
      onSend: _sendChat,
      onSpectatorPressed: () async {
        final id = await showDialog<String>(
          context: context,
          builder: (_) =>
              _PromptDialog(title: 'Войти как зритель', label: 'roomId'),
        );
        if (id == null || id.trim().isEmpty) return;

        final supa = Supabase.instance.client;
        final me = supa.auth.currentUser;
        if (me == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Сначала войдите в аккаунт')),
          );
          return;
        }

        await _openRoom(
          id.trim(),
          opponentId: _opponentId ?? 'unknown',
          opponentName: _opponentName ?? 'opponent',
          myColor: (_humanColor == ch.Color.WHITE) ? 'white' : 'black',
          spectator: true,
        );
      },
      maxWidth: maxWidth,
      height: height,
    );
  }

  void _sendChat() {
    if (!_inRoom || _room == null) return;
    final text = _chatCtl.text.trim();
    if (text.isEmpty) return;

    final meId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final meName = _nickname ?? 'me';

    setState(() => _chat.add(_ChatMsg(from: meName, text: text, mine: true)));
    _chatCtl.clear();

    _room!.sendChat(text: text, fromName: meName, from: meId);
  }

  Future<void> _startFreshGame() async {
    if (_inRoom) {
      await _leaveRoom();
    }
    _resetBoardToInitial();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Новая партия: можно выбрать соперника или ИИ')),
      );
    }
  }

  Widget _buildBottomTools() {
    return Column(
      children: [
        // Поле ввода FEN и его рамку/подпись УДАЛИЛИ
        // (оставляем просто небольшой отступ, чтобы верстка не «прыгала»)
        const SizedBox(height: 0),

        if (_loading)
          const CircularProgressIndicator()
        else if (_result != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SelectableText(
              _result!,
              style: const TextStyle(fontSize: 14),
            ),
          )
        else
          const SizedBox
              .shrink(), // убрали текст "Enter a FEN and press the button."

        const SizedBox(height: 24),
      ],
    );
  }

  // ---- Chessboard ----
// ---- Chessboard ----
  Widget _buildBoardWithCoords(double boardSize) {
    const double m = 18;
    const double mb = 26;

    final files = _isFlipped
        ? ['H', 'G', 'F', 'E', 'D', 'C', 'B', 'A']
        : ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    final ranks = _isFlipped
        ? ['1', '2', '3', '4', '5', '6', '7', '8']
        : ['8', '7', '6', '5', '4', '3', '2', '1'];

    final labelStyle = TextStyle(
      fontSize: math.max(7, boardSize / 48),
      color: AppColors.text,
      fontWeight: FontWeight.w700,
    );

    final double totalW = boardSize + m * 2;
    final double totalH = boardSize + m + mb;

    return SizedBox(
      width: totalW,
      height: totalH,
      child: Container(
        decoration: AppDecorations.card(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: m,
              top: m,
              width: boardSize,
              height: boardSize,
              child: _buildChessBoardGrid(boardSize),
            ),

            // Стрелки рисуются отдельным слоем ПОВЕРХ настоящей доски.
            Positioned(
              left: m,
              top: m,
              width: boardSize,
              height: boardSize,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PuzzleAnalysisArrowPainter(
                    arrows: _visiblePuzzleBoardArrows,
                    boardSize: boardSize,
                    centerForSquare: (square) =>
                        _boardCenterForSquare(square, boardSize),
                    previewFrom: _currentAnalysisPreviewFrom,
                    previewTo: _currentAnalysisPreviewTo,
                    previewColor: _puzzleArrowDrawMode
                        ? _analysisArrowColor(_effectivePuzzleArrowKey)
                        : null,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),

            // В режиме анализа этот слой превращает доску в рисовалку.
            // Он стоит самым верхним слоем над клетками и фигурами, поэтому ходы блокируются.
            if (_puzzleArrowDrawMode)
              Positioned(
                left: m,
                top: m,
                width: boardSize,
                height: boardSize,
                child: MouseRegion(
                  cursor: SystemMouseCursors.precise,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) {
                      if (_isSecondaryMouseButton(event)) {
                        _removePuzzleAnalysisElementAt(
                          event.localPosition,
                          boardSize,
                        );
                        return;
                      }

                      _startPuzzleAnalysisBoardDrag(
                        event.localPosition,
                        boardSize,
                      );
                    },
                    onPointerMove: (event) {
                      if (_isSecondaryMouseButton(event)) return;

                      _updatePuzzleAnalysisBoardDrag(
                        event.localPosition,
                        boardSize,
                      );
                    },
                    onPointerUp: (event) {
                      if (_isSecondaryMouseButton(event)) return;

                      _finishPuzzleAnalysisBoardDrag(
                        event.localPosition,
                        boardSize,
                      );
                    },
                    onPointerCancel: (_) {
                      setState(() {
                        if (_puzzleSettingsIsOpen) {
                          _pendingAnalysisArrowFrom = null;
                          _analysisPointerPosition = null;
                        } else if (_showLearningPanel) {
                          _learningPendingAnalysisArrowFrom = null;
                          _learningAnalysisPointerPosition = null;
                        } else {
                          _studentPendingAnalysisArrowFrom = null;
                          _studentAnalysisPointerPosition = null;
                        }
                      });
                    },
                    child: Container(
                      width: boardSize,
                      height: boardSize,
                      color: const Color(0x01000000),
                    ),
                  ),
                ),
              ),

            Positioned(
              left: m - 10,
              top: m + boardSize + 2,
              child: IgnorePointer(
                child: Container(
                  width: boardSize + 20,
                  height: mb - 4,
                  decoration: AppDecorations.card(),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: m,
              width: m,
              height: boardSize,
              child: _editMode
                  ? _deleteZone(
                      child: Column(
                        children: List.generate(
                          8,
                          (i) => SizedBox(
                            height: boardSize / 8,
                            child: Align(
                              alignment: Alignment.center,
                              child: Text(ranks[i], style: labelStyle),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: List.generate(
                        8,
                        (i) => SizedBox(
                          height: boardSize / 8,
                          child: Align(
                            alignment: Alignment.center,
                            child: Text(ranks[i], style: labelStyle),
                          ),
                        ),
                      ),
                    ),
            ),
            Positioned(
              left: m,
              top: m + boardSize,
              width: boardSize,
              height: mb,
              child: _editMode
                  ? _deleteZone(
                      child: Row(
                        children: List.generate(
                          8,
                          (i) => SizedBox(
                            width: boardSize / 8,
                            child: Center(
                              child: Text(files[i], style: labelStyle),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: List.generate(
                        8,
                        (i) => SizedBox(
                          width: boardSize / 8,
                          child: Center(
                            child: Text(files[i], style: labelStyle),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPuzzleAnalysisBoardOverlay(double boardSize) {
    // Старый метод оставлен как заглушка, чтобы не ломать возможные ссылки.
    return const SizedBox.shrink();
  }

  Widget _buildChessBoardGrid(double boardSize) {
    return AnimatedBuilder(
      animation: widget.boardTheme,
      builder: (context, _) {
        try {
          final double cell = boardSize / 8;
          final double pieceSize = cell * 0.85;

          final lightSquareColor = widget.boardTheme.lightSquare;
          final darkSquareColor = widget.boardTheme.darkSquare;

          return SizedBox(
            width: boardSize,
            height: boardSize,
            child: Stack(
              children: [
                GridView.builder(
                  padding: EdgeInsets.zero, // ✅ без внутренних отступов
                  clipBehavior:
                      Clip.hardEdge, // ✅ обрезка "лишнего" за границей
                  physics: const NeverScrollableScrollPhysics(),
                  primary: false, // ← добавили
                  shrinkWrap: true, // ← добавили

                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: 64,
                  itemBuilder: (context, index) {
                    final square = _displayIndexToSquare(index);
                    final row = index ~/ 8;
                    final col = index % 8;
                    final isWhiteSquare = (row + col) % 2 == 0;

                    final editing = _editMode;

                    // данные для игры
                    final piece = editing ? null : game.get(square);
                    final isSelected = !editing && _selectedSquare == square;
                    final isLegal = !editing && _legalTargets.contains(square);
                    final isCapture =
                        !editing && _captureTargets.contains(square);

                    // данные для редактора
                    final fenChar = editing
                        ? _editBoard[_rankIndex(square)][_fileIndex(square)]
                        : '.';
                    final unicode = editing ? _unicodeForFen(fenChar) : null;

                    // ----- РЕЖИМ РЕДАКТОРА
                    // ----- РЕЖИМ РЕДАКТОРА (DnD как в lichess)
// ----- РЕЖИМ РЕДАКТОРА (DnD как в lichess)
                    // ----- РЕЖИМ РЕДАКТОРА
                    // ----- РЕЖИМ РЕДАКТОРА (ПОЛНАЯ ЗАМЕНА БЛОКА, КОТОРЫЙ НАЧИНАЕТСЯ С if (editing)) -----
                    if (editing) {
                      // каждая клетка — это DragTarget, чтобы принимать перетаскиваемые фигуры
                      return DragTarget<String>(
                        onWillAccept: (data) =>
                            data !=
                            null, // принимаем любой код фигуры ('wK', 'bQ' и т.п.)
                        onAccept: (pieceCode) {
                          setState(() {
                            // ставим фигуру на цель
                            final ri = _rankIndex(square);
                            final fi = _fileIndex(square);
                            _editBoard[ri][fi] = _fenFromPieceCode(pieceCode);

                            // если тащили С ДОСКИ — очистим исходную клетку
                            if (_dragFromSquare != null) {
                              final sri = _rankIndex(_dragFromSquare!);
                              final sfi = _fileIndex(_dragFromSquare!);
                              _editBoard[sri][sfi] = '.';
                              _dragFromSquare = null;
                            }
                          });
                        },
                        builder: (context, candidate, rejected) {
                          final ri = _rankIndex(square);
                          final fi = _fileIndex(square);
                          final fenChar =
                              _editBoard[ri][fi]; // 'K','p','.' и т.п.
                          final pieceCode =
                              _pieceCodeFromFen(fenChar); // 'wK','bP' или null

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _onSquareEdit(
                                square), // тап по клетке — быстрый выбор фигуры
                            child: Container(
                              decoration: BoxDecoration(
                                color: isWhiteSquare
                                    ? lightSquareColor
                                    : darkSquareColor,
                                border:
                                    Border.all(color: Colors.black12, width: 1),
                              ),
                              child: Center(
                                  // если клетка пустая — ничего не рисуем
                                  child: (pieceCode == null)
                                      ? const SizedBox.shrink()
                                      : Draggable<String>(
                                          data: pieceCode,
                                          onDragStarted: () =>
                                              _dragFromSquare = square,
                                          onDragCompleted: () =>
                                              _dragFromSquare = null,

                                          // БЫЛО:
                                          // onDraggableCanceled: (_, __) => _dragFromSquare = null,

                                          // СТАЛО: если дроп «в молоко» — удаляем фигуру из исходной клетки
                                          onDraggableCanceled: (_, __) {
                                            if (_dragFromSquare != null) {
                                              final sri =
                                                  _rankIndex(_dragFromSquare!);
                                              final sfi =
                                                  _fileIndex(_dragFromSquare!);
                                              setState(() {
                                                _editBoard[sri][sfi] =
                                                    '.'; // удалить фигуру из исходной клетки
                                              });
                                              _dragFromSquare = null;
                                            }
                                          },

                                          feedback: Material(
                                            color: Colors.transparent,
                                            child: SvgPicture.asset(
                                              _assetFor(pieceCode),
                                              width: pieceSize,
                                              height: pieceSize,
                                            ),
                                          ),
                                          childWhenDragging:
                                              const SizedBox.shrink(),
                                          child: SvgPicture.asset(
                                            _assetFor(pieceCode),
                                            width: pieceSize,
                                            height: pieceSize,
                                          ),
                                        )),
                            ),
                          );
                        },
                      );
                    }

                    // ----- ОБЫЧНАЯ ИГРА
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) {
                        if (_puzzleArrowDrawMode) return;
                        if (!_myTurnNow() || _isSpectator) return;
                        final p = game.get(square);
                        if (p != null &&
                            (p.color == game.turn || _sharedControl))
                          _computeLegalTargets(square);
                      },
                      onTap: () {
                        if (_handlePuzzleAnalysisSquareTap(square)) return;
                        if (!_myTurnNow() || _isSpectator) return;
                        if (_selectedSquare == null) return;

                        if (_legalTargets.contains(square)) {
                          _makeMove(_selectedSquare!, square);
                          return;
                        }

                        final pHere = game.get(square);
                        final pSel = _selectedSquare != null
                            ? game.get(_selectedSquare!)
                            : null;
                        if (pHere != null &&
                            pSel != null &&
                            pHere.color == pSel.color) {
                          _computeLegalTargets(square);
                          return;
                        }

                        if (square == _selectedSquare) return;

                        setState(() {
                          _selectedSquare = null;
                          _legalTargets.clear();
                          _captureTargets.clear();
                        });
                      },
                      onSecondaryTap: () {
                        if (_puzzleArrowDrawMode) {
                          setState(() {
                            if (_puzzleSettingsIsOpen) {
                              _pendingAnalysisArrowFrom = null;
                              _analysisPointerPosition = null;
                            } else if (_showLearningPanel) {
                              _learningPendingAnalysisArrowFrom = null;
                              _learningAnalysisPointerPosition = null;
                            } else {
                              _studentPendingAnalysisArrowFrom = null;
                              _studentAnalysisPointerPosition = null;
                            }
                          });
                          return;
                        }
                        if (!_myTurnNow() || _isSpectator) return;
                        setState(() {
                          _selectedSquare = null;
                          _legalTargets.clear();
                          _captureTargets.clear();
                        });
                      },
                      child: DragTarget<int>(
                        onAccept: (fromIndex) {
                          if (!_myTurnNow() || _isSpectator) return;
                          final from = _displayIndexToSquare(fromIndex);
                          final to = square;
                          _makeMove(from, to);
                        },
                        builder: (context, _, __) => Container(
                          decoration: BoxDecoration(
                            color: isWhiteSquare
                                ? lightSquareColor
                                : darkSquareColor,
                            border: Border.all(
                              color: isSelected ? Colors.amber : Colors.black12,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (isLegal && !isCapture)
                                IgnorePointer(
                                  child: Center(
                                    child: Container(
                                      width: cell * 0.3,
                                      height: cell * 0.3,
                                      decoration: const BoxDecoration(
                                        color: Color(0x5500FF00),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              if (isCapture)
                                IgnorePointer(
                                  child: Center(
                                    child: Container(
                                      width: cell * 0.75,
                                      height: cell * 0.75,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.redAccent, width: 3),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              if (piece != null)
                                Center(
                                  child: Draggable<int>(
                                    data: index,
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: SvgPicture.asset(
                                        _assetFor(_codeFor(piece)),
                                        width: pieceSize,
                                        height: pieceSize,
                                      ),
                                    ),
                                    childWhenDragging: const SizedBox.shrink(),
                                    child: SvgPicture.asset(
                                      _assetFor(_codeFor(piece)),
                                      width: pieceSize,
                                      height: pieceSize,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _PuzzleAnalysisArrowPainter(
                        arrows: _visiblePuzzleBoardArrows,
                        boardSize: boardSize,
                        centerForSquare: (square) =>
                            _boardCenterForSquare(square, boardSize),
                        previewFrom: _currentAnalysisPreviewFrom,
                        previewTo: _currentAnalysisPreviewTo,
                        previewColor: _puzzleArrowDrawMode
                            ? _analysisArrowColor(_effectivePuzzleArrowKey)
                            : null,
                      ),
                    ),
                  ),
                ),
                if (_puzzleArrowDrawMode)
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        if (_isSecondaryMouseButton(event)) {
                          _removePuzzleAnalysisElementAt(
                            event.localPosition,
                            boardSize,
                          );
                          return;
                        }

                        _startPuzzleAnalysisBoardDrag(
                          event.localPosition,
                          boardSize,
                        );
                      },
                      onPointerMove: (event) {
                        if (_isSecondaryMouseButton(event)) return;

                        _updatePuzzleAnalysisBoardDrag(
                          event.localPosition,
                          boardSize,
                        );
                      },
                      onPointerUp: (event) {
                        if (_isSecondaryMouseButton(event)) return;

                        _finishPuzzleAnalysisBoardDrag(
                          event.localPosition,
                          boardSize,
                        );
                      },
                      onPointerCancel: (_) {
                        setState(() {
                          if (_puzzleSettingsIsOpen) {
                            _pendingAnalysisArrowFrom = null;
                            _analysisPointerPosition = null;
                          } else if (_showLearningPanel) {
                            _learningPendingAnalysisArrowFrom = null;
                            _learningAnalysisPointerPosition = null;
                          } else {
                            _studentPendingAnalysisArrowFrom = null;
                            _studentAnalysisPointerPosition = null;
                          }
                        });
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          );
        } catch (e) {
          return Container(
            width: boardSize,
            height: boardSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              border: Border.all(color: const Color(0xFFD32F2F), width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Ошибка рендера доски: $e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFD32F2F)),
            ),
          );
        }
      },
    );
  }

  void _resetBoardToInitial() {
    game.reset();
    _fenController.text = game.fen;

    _sanMoves.clear();
    _fens
      ..clear()
      ..add(game.fen);
    _plyIndex = 0;

    _selectedSquare = null;
    _legalTargets.clear();
    _captureTargets.clear();

    _result = null;

    _drawOfferedByMe = false;
    _drawOfferedToMe = false;
    _rematchOfferedByMe = false;
    _rematchOfferedToMe = false;

    _stopTick();
    _resetClocks();
    _gameTerminated = false;
    unawaited(_refreshEvalBar());
  }

  Future<void> _onNewGameUniversal() async {
    // ← деактивируем Совместный режим и общий редактор
    final wasSync = _syncBoard;
    setState(() {
      _syncBoard = false; // тумблер совместного режима = выкл
      _sharedControl = false; // общий контроль = выкл
      _syncEditor = false; // синхрон редактора = выкл
      _editMode = false; // сам редактор выключим локально
    });
    if (wasSync) {
      _syncSendEditMode(
          false); // сообщаем второму, что редактор (если был) выключен
    }

    // Онлайн (игра в комнате Supabase)
    if (_inRoom) {
      await _startNewGameFresh();
      return;
    }

    // Против ИИ
    if (_vsEngine == true) {
      await _startNewGameVsEngine();
      return;
    }

    // Локально (человек-человек на одном устройстве)
    _startLocalHumanGame();
  }

  Future<bool> _confirmResign() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Сдаться?'),
            content: const Text(
                'Подтвердите, что вы хотите завершить партию сдачей.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('Сдаться'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showEndDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Единая кнопка «Сдаться» — показывает диалог и вызывает нужную реализацию
  Future<void> _onResignPressed() async {
    if (_gameTerminated) return;
    final ok = await _confirmResign();
    if (!ok) return;

    if (_inRoom) {
      await _resignOnline(); // твой онлайн-метод
      await _showEndDialog(
        title: 'Партия завершена',
        message: 'Вы сдались в онлайне.',
      );
    } else if (_vsEngine) {
      // против ИИ
      setState(() {
        _result = 'Вы сдались (ИИ победил)';
        _gameTerminated = true;
        _selectedSquare = null;
        _legalTargets.clear();
        _captureTargets.clear();
      });
      await _showEndDialog(
        title: 'Партия завершена',
        message: 'Вы сдались. Победил ИИ.',
      );
    } else {
      // локальная игра человек-человек
      await _resignOffline(); // уже покажет диалог внутри
    }
  }

  void _startLocalHumanGame() {
    setState(() {
      // важно: явно выключаем режим ИИ/онлайна
      _vsEngine = false;

      game.reset();
      _fenController.text = game.fen;

      _sanMoves.clear();
      _fens
        ..clear()
        ..add(game.fen);
      _plyIndex = 0;

      _selectedSquare = null;
      _legalTargets.clear();
      _captureTargets.clear();

      _result = null;
      _gameTerminated = false;

      _stopTick();
      _resetClocks();
    });
    unawaited(_refreshEvalBar());
  }

  Future<void> _resignOffline() async {
    if (game.game_over || _gameTerminated) return;

    final bool iPlayWhite = (_humanColor == ch.Color.WHITE);
    final String result =
        iPlayWhite ? '0-1 (resignation)' : '1-0 (resignation)';

    _stopTick();
    _resetClocks();

    setState(() {
      _result = result;
      _gameTerminated = true;
      _selectedSquare = null;
      _legalTargets.clear();
      _captureTargets.clear();
    });

    await _showEndDialog(
      title: 'Партия завершена',
      message: 'Вы сдались. Результат: $result',
    );
  }

  void _resignUniversal() {
    if (_inRoom) {
      // Сдаёмся онлайн
      _resignOnline();
    } else if (_vsEngine) {
      // Сдаёмся против ИИ
      setState(() {
        _result = 'Вы сдались (ИИ победил)';
        _gameTerminated = true;
      });
    } else {
      // Локальная игра (два игрока на одном устройстве)
      setState(() {
        _result = 'Игрок сдался';
        _gameTerminated = true;
      });
    }
  }

  Future<void> _startNewGameFresh() async {
    if (_inRoom) {
      await _leaveRoom();
    }
    _resetBoardToInitial();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Новый игрок: выберите соперника в контактах или начните с ИИ')),
      );
    }
  }

  void _computeLegalTargets(String fromSquare) {
    final Set<String> legal = {};
    final Set<String> caps = {};
    try {
      final moves = game.moves({'square': fromSquare, 'verbose': true});
      for (final m in moves) {
        final to = (m['to'] ?? '') as String;
        if (to.isEmpty) continue;
        legal.add(to);
        final flags = (m['flags'] as String?) ?? '';
        if (flags.contains('c') || flags.contains('e') || m['captured'] != null)
          caps.add(to);
      }
    } catch (_) {}
    setState(() {
      _selectedSquare = fromSquare;
      _legalTargets = legal;
      _captureTargets = caps;
    });
  }

  Future<void> _startEngineDuel() async {
    if (_engineDuel) return;

    setState(() {
      _engineDuel = true;
      _vsEngine = true; // движок активен
      _gameTerminated = false;
    });

    // Полностью свежая партия
    game.reset();
    _fenController.text = game.fen;
    _sanMoves.clear();
    _fens
      ..clear()
      ..add(game.fen);
    _plyIndex = 0;
    _selectedSquare = null;
    _legalTargets.clear();
    _captureTargets.clear();
    unawaited(_refreshEvalBar());
    // Автоигра: по одному ходу каждые 2 секунды
    while (mounted && _engineDuel && !_gameTerminated) {
      await Future.delayed(Duration(milliseconds: _engineDuelDelayMs));
      if (!_engineDuel || _gameTerminated) break;

      // твой существующий метод: делает ход за ту сторону, чей сейчас ход
      await _engineMove();

      if (_gameTerminated) break;
    }
  }

  void _stopEngineDuel() {
    if (!_engineDuel) return;
    setState(() => _engineDuel = false);
  }

  // ===== VS ENGINE quick start =====
  Future<void> _startNewGameVsEngine() async {
    setState(() {
      _vsEngine = true;
      _engineThinking = false;
      game.reset();
      _fenController.text = game.fen;

      _sanMoves.clear();
      _fens
        ..clear()
        ..add(game.fen);
      _plyIndex = 0;

      _selectedSquare = null;
      _legalTargets.clear();
      _captureTargets.clear();
      _gameTerminated = false;
    });

    unawaited(_refreshEvalBar());

    if (_humanColor == ch.Color.BLACK) {
      await _engineMove();
    }
  }

  void _enterEditor() {
    final parts = game.fen.split(' ');
    final cr = parts.length > 2 ? parts[2] : '-';
    setState(() {
      _editMode = true;
      _editBoard = _fenToBoard(game.fen);
      _editTurn = (parts.length > 1 && parts[1] == 'b')
          ? ch.Color.BLACK
          : ch.Color.WHITE;
      _castleK = cr.contains('K');
      _castleQ = cr.contains('Q');
      _castlek = cr.contains('k');
      _castleq = cr.contains('q');

      // ВАЖНО: именно поле класса, а не локальная переменная!
      _dragFromSquare = null;
    });

    // ← СИНХРОН РЕДАКТОРА (только когда включён «Совместный режим»)
    _syncSendEditMode(true); // сообщаем второму, что редактор включён
    _syncSendEditFen(); // отправляем текущую сетку редактора
  }

  void _applyEditor() {
    final fen = _boardToFen();
    final ok = game.load(fen);

    if (ok) {
      setState(() {
        _fenController.text = game.fen;
        _sanMoves.clear();
        _fens
          ..clear()
          ..add(game.fen);
        _plyIndex = 0;
        _selectedSquare = null;
        _legalTargets.clear();
        _captureTargets.clear();
        _result = null;
        _editMode = false;
      });

      // ← ВНЕ setState: синхрон для совместного режима
      _syncSendFen(); // разослать итоговую позицию
      _syncSendEditMode(false); // выключить редактор у обоих

      unawaited(_refreshEvalBar());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Позиция применена')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Некорректный FEN: $fen')),
      );
    }
  }

  Future<void> _onSquareEdit(String square) async {
    if (!_editMode) return;
    final ri = _rankIndex(square);
    final fi = _fileIndex(square);

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) {
        Widget cell(String label, String fenChar) => InkWell(
              onTap: () => Navigator.pop(context, fenChar),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(label, style: const TextStyle(fontSize: 28)),
              ),
            );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Выберите фигуру',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    cell('♔', 'K'), cell('♕', 'Q'), cell('♖', 'R'),
                    cell('♗', 'B'), cell('♘', 'N'), cell('♙', 'P'),
                    cell('♚', 'k'), cell('♛', 'q'), cell('♜', 'r'),
                    cell('♝', 'b'), cell('♞', 'n'), cell('♟', 'p'),
                    cell('Пусто', '.'), // удалить
                  ]),
              const SizedBox(height: 8),
            ]),
          ),
        );
      },
    );

    if (choice == null) return;
    setState(() => _editBoard[ri][fi] = choice);

    // ← Живое превью партнёру (в совместном режиме)
    _syncSendEditFen();
  }
}

// ---------- Small models / widgets ----------
class _ChatMsg {
  _ChatMsg({required this.from, required this.text, required this.mine});
  final String from;
  final String text;
  final bool mine;
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({required this.title, required this.label});
  final String title;
  final String label;
  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  final ctl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
          controller: ctl,
          decoration: InputDecoration(labelText: widget.label)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
            onPressed: () => Navigator.pop(context, ctl.text.trim()),
            child: const Text('OK')),
      ],
    );
  }
}

// ---- Time control dialog ----
class _TcChoice {
  final int minutes;
  final int increment;
  final bool rated;
  const _TcChoice(
      {required this.minutes, required this.increment, required this.rated});
}

class _TcDialog extends StatefulWidget {
  final int initialMinutes;
  final int initialIncrement;
  final bool initialRated;

  const _TcDialog({
    Key? key,
    required this.initialMinutes,
    required this.initialIncrement,
    required this.initialRated,
  }) : super(key: key);

  @override
  State<_TcDialog> createState() => _TcDialogState();
}

class _TcDialogState extends State<_TcDialog> {
  late int _minutes;
  late int _increment;
  late bool _rated;
  late bool _noTime; // ← «Без контроля времени»

  @override
  void initState() {
    super.initState();

    _minutes = widget.initialMinutes;
    _increment = widget.initialIncrement;
    _rated = widget.initialRated;
    _noTime = (_minutes == 0 && _increment == 0);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Сменить контроль'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            value: _noTime,
            onChanged: (v) => setState(() {
              _noTime = v ?? false;
              if (_noTime) _rated = false;
            }),
            title: const Text('Без контроля времени'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 8),
          TextField(
            enabled: !_noTime,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Минуты'),
            controller: TextEditingController(text: _minutes.toString()),
            onChanged: (s) {
              final v = int.tryParse(s) ?? _minutes;
              _minutes = v.clamp(0, 180);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            enabled: !_noTime,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Прибавка (сек)'),
            controller: TextEditingController(text: _increment.toString()),
            onChanged: (s) {
              final v = int.tryParse(s) ?? _increment;
              _increment = v.clamp(0, 60);
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _rated,
            onChanged: _noTime ? null : (v) => setState(() => _rated = v),
            title: const Text('Рейтинговая'),
            contentPadding: EdgeInsets.zero,
          )
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final noTime = _noTime;
            final res = _TcChoice(
              minutes: noTime ? 0 : _minutes,
              increment: noTime ? 0 : _increment,
              rated: noTime ? false : _rated,
            );
            Navigator.pop(context, res);
          },
          child: const Text('ОК'),
        ),
      ],
    );
  }
}

// ---- Move list panel ----

// ---------- Lobby UI ----------
// ---------- Lobby UI ----------

// ---------- AUTH UI widgets ----------

class _GptExplainSheet extends StatelessWidget {
  const _GptExplainSheet({required this.data});
  final Map<String, dynamic> data;

  String _renderText(Map<String, dynamic> d) {
    final t = d['text'];
    if (t is String && t.trim().isNotEmpty) return t.trim();

    final j = d['json'];
    if (j != null) {
      try {
        return const JsonEncoder.withIndent('  ').convert(j);
      } catch (_) {
        return j.toString();
      }
    }

    try {
      return const JsonEncoder.withIndent('  ').convert(d);
    } catch (_) {
      return d.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _renderText(data);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.travel_explore, size: 18),
                const SizedBox(width: 8),
                const Text('Объяснение позиции (GPT)',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  text.isEmpty ? 'Нет данных.' : text,
                  style: const TextStyle(fontSize: 14, height: 1.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PuzzleBoardArrow {
  const _PuzzleBoardArrow({
    required this.from,
    required this.to,
    required this.kind,
    required this.color,
    this.isCircle = false,
    this.side = 'white',
  });

  final String from;
  final String to;
  final String kind;
  final Color color;
  final bool isCircle;
  final String side;
}

class _PuzzleAnalysisArrowPainter extends CustomPainter {
  const _PuzzleAnalysisArrowPainter({
    required this.arrows,
    required this.boardSize,
    required this.centerForSquare,
    this.previewFrom,
    this.previewTo,
    this.previewColor,
  });

  final List<_PuzzleBoardArrow> arrows;
  final double boardSize;
  final Offset Function(String square) centerForSquare;
  final String? previewFrom;
  final Offset? previewTo;
  final Color? previewColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final arrow in arrows) {
      if (arrow.isCircle || arrow.from == arrow.to) {
        _drawCircle(
          canvas: canvas,
          center: centerForSquare(arrow.from),
          color: arrow.color,
        );
      } else {
        _drawArrow(
          canvas: canvas,
          from: centerForSquare(arrow.from),
          to: centerForSquare(arrow.to),
          color: arrow.color,
        );
      }
    }

    final fromSquare = previewFrom;
    final toPoint = previewTo;
    final color = previewColor;
    if (fromSquare != null && toPoint != null && color != null) {
      _drawArrow(
        canvas: canvas,
        from: centerForSquare(fromSquare),
        to: toPoint,
        color: color,
        preview: true,
      );
    }
  }

  void _drawCircle({
    required Canvas canvas,
    required Offset center,
    required Color color,
  }) {
    final radius = (boardSize / 8) * 0.31;
    final paint = Paint()
      ..color = color.withOpacity(0.62)
      ..strokeWidth = (boardSize / 8) * 0.10
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, paint);
  }

  void _drawArrow({
    required Canvas canvas,
    required Offset from,
    required Offset to,
    required Color color,
    bool preview = false,
  }) {
    final vector = to - from;
    if (vector.distance < 2) return;

    final unit = vector / vector.distance;
    final shortenedTo = to - unit * (boardSize / 36);
    final opacity = preview ? 0.36 : 0.52;
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..strokeWidth = (boardSize / 8) * 0.14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(from, shortenedTo, paint);

    final headLength = (boardSize / 8) * 0.34;
    final headWidth = (boardSize / 8) * 0.22;
    final base = shortenedTo - unit * headLength;
    final normal = Offset(-unit.dy, unit.dx);
    final path = Path()
      ..moveTo(shortenedTo.dx, shortenedTo.dy)
      ..lineTo((base + normal * headWidth).dx, (base + normal * headWidth).dy)
      ..lineTo((base - normal * headWidth).dx, (base - normal * headWidth).dy)
      ..close();

    final headPaint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, headPaint);
  }

  @override
  bool shouldRepaint(covariant _PuzzleAnalysisArrowPainter oldDelegate) => true;
}
