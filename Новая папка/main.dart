// main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:html' as html;
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
import 'landing_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart' as rt;
import 'ui/common_top_bar.dart';
import 'package:uuid/uuid.dart';
import 'secrets.dart'; // supabaseUrl / supabaseAnonKey
import 'ui/app_shell.dart';
import 'package:flutter/material.dart';
import 'ui/app_shell.dart';
import 'main.dart' show MyHomePage; // или твой путь к MyHomePage

// ---------- Одноразовое удаление старого Service Worker и кэшей ----------
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'secrets.dart'; // где лежат supabaseUrl/supabaseAnonKey
import 'ui/app_shell.dart';
import 'landing_page.dart'; // если нужно MyHomePage оттуда
import 'services/lobby_store.dart'; // путь от lib/

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
// === НАСТРОЙКИ И ФОН ===
//import 'dart:html' as html;
//import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
//import 'package:flutter/material.dart';

// Глобально убираем bounce/overscroll и даём нормальный drag мышью/тачем.
class _NoBounceScrollBehavior extends MaterialScrollBehavior {
  const _NoBounceScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Clamping вместо Bouncing — без «резинового» подскока
    return const ClampingScrollPhysics();
  }
}
);
    }
  }

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
  }

  void _setPly(int n) {
    _plyIndex = n.clamp(0, _sanMoves.length);
    _resetToFen(_fens[_plyIndex]);
    setState(() {});
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
    _broadcastClockSnapshot();
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
    setState(() {
      _tcMinutes = minutes;
      _tcIncrement = increment;
      _rated = rated;
      _matchRated = rated;
    });

    _resetClocks();
    if (broadcast) _broadcastTimeControl();
    _broadcastClockSnapshot();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Контроль: $minutes+${increment}${rated ? " (рейтинговая)" : ""}')),
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

  Future<void> _enterLobby() async {
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

      lobby.onInvite =
          (roomId, fromId, fromName, inviterColor, m, inc, rated) async {
        if (_inviteDialogOpen) return;
        _inviteDialogOpen = true;

        try {
          final ok = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogCtx) => AlertDialog(
              title: const Text('Вызов на игру'),
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
            );
          }
        } finally {
          _inviteDialogOpen = false;
        }
      };

      lobby.onAccept = (roomId, fromId, fromName, acceptorColor) {
        final myColor = _opposite(acceptorColor);
        _openRoom(roomId,
            opponentId: fromId,
            opponentName: fromName,
            myColor: myColor,
            spectator: false);
      };

      _lobby = lobby;
    }

    await _lobby!.connect();

    // Сразу после подключения синхронизируем текущий список в шину
    _syncLobbyStoreFromOnline(); // <<< добавили

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Вы в лобби')));
    }
  }

  Future<void> _leaveLobby() async {
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
    await _lobby!.connect();
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

  Future<void> _openRoom(
    String roomId, {
    required String opponentId,
    required String opponentName,
    required String myColor, // 'white' | 'black'
    required bool spectator,
  }) async {
    _room?.disconnect();
    final supa = Supabase.instance.client;

    _room = RoomService(supa, roomId: roomId);

    _room!.onMove = (m) {
      final rid = m['roomId'] as String?;
      if (rid != null && _roomId != null && rid != _roomId) return;
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
      _chat.clear();
      _drawOfferedByMe = _drawOfferedToMe = false;
      _rematchOfferedByMe = _rematchOfferedToMe = false;
      _gameTerminated = false;
    });

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

    html.window.localStorage[_LS_ROOM] = jsonEncode({
      'roomId': roomId,
      'opponentId': opponentId,
      'opponentName': _opponentName,
      'myColor': (myColor.toLowerCase()),
      'spectator': spectator,
    });

    _broadcastTimeControl();

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
    _stopTick();
    setState(() {
      _room = null;
      _roomId = null;
      _opponentId = null;
      _opponentName = null;
      _isSpectator = false;
    });

    _matchRated = _rated;
    html.window.localStorage.remove(_LS_ROOM);
  }

  Future<void> _tryRestoreRoom() async {
    final s = html.window.localStorage[_LS_ROOM];
    if (s == null) return;
    try {
      final map = jsonDecode(s) as Map<String, dynamic>;
      final roomId = map['roomId'] as String?;
      final oppId = map['opponentId'] as String?;
      final oppName = map['opponentName'] as String? ?? 'opponent';
      final myColor = map['myColor'] as String? ?? 'white';
      final spectator = (map['spectator'] as bool?) ?? false;
      if (roomId != null && oppId != null) {
        final supa = Supabase.instance.client;
        if (supa.auth.currentUser == null) return;
        await _openRoom(roomId,
            opponentId: oppId,
            opponentName: oppName,
            myColor: myColor,
            spectator: spectator);
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

    html.window.localStorage.remove(_LS_ROOM);
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

    _afterHumanMoveCommon(san, isCapture);
    _checkGameOver();

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
      builder: (_) => AlertDialog(
        title: const Text('Ничья?'),
        content: const Text('Соперник предлагает ничью. Принять?'),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _declineDrawOnline();
              },
              child: const Text('Отклонить')),
          FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _acceptDrawOnline();
              },
              child: const Text('Принять')),
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

// === ПРАВАЯ КОЛОНКА: Moves + стрелки + кнопки ===
  Widget _RightColumn(double boardSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // список ходов (высота ≈ как у доски)
        _MoveListPanel(
          san: _sanMoves,
          currentPly: _plyIndex,
          controller: _movesScroll,
          height: math.max(380, boardSize),
          onCopyPGN: () {
            final rows = _rowsFromSan(_sanMoves);
            Clipboard.setData(ClipboardData(text: rows.join(' ')));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PGN скопирован')),
            );
          },
          onClear: () {
            setState(() {
              _sanMoves.clear();
              _fens
                ..clear()
                ..add(game.fen);
              _plyIndex = 0;
            });
          },
        ),

        const SizedBox(height: 10),

        // стрелки навигации по истории
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: 'В начало',
              onPressed: _plyIndex > 0 ? _goStart : null,
              icon: const Icon(Icons.first_page),
            ),
            IconButton(
              tooltip: 'Назад',
              onPressed: _plyIndex > 0 ? _goPrev : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Вперёд',
              onPressed: _plyIndex < _sanMoves.length ? _goNext : null,
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              tooltip: 'В конец',
              onPressed: _plyIndex < _sanMoves.length ? _goEnd : null,
              icon: const Icon(Icons.last_page),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ряд: Сдаться  |  Предложить ничью
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _onResignPressed,
                icon: const Icon(Icons.flag),
                label: const Text('Сдаться'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _offerDrawUniversal,
                icon: const Icon(Icons.handshake_outlined),
                label: const Text('Предложить ничью'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ряд: Взять лучший ход | Объяснить позицию
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _loading
                    ? null
                    : () async {
                        setState(() => _loading = true);
                        final fen = _fenController.text.trim().isEmpty
                            ? game.fen
                            : _fenController.text.trim();
                        final uci = await _fetchUciBestMove(fen);
                        setState(() => _loading = false);
                        if (!mounted) return;
                        if (uci != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Лучший ход (UCI): $uci')),
                          );
                        }
                      },
                child: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Взять лучший ход'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: _gptLoading ? null : _explainHere,
                icon: _gptLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.psychology),
                label:
                    Text(_gptLoading ? 'Запрос к GPT...' : 'Объяснить позицию'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ряд: Введите FEN | Stockfish Analysis
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _showFenInput = !_showFenInput),
                child: const Text('Введите FEN'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _loading
                    ? null
                    : () async {
                        setState(() => _loading = true);
                        final uci = await _fetchUciBestMove(
                          _fenController.text.trim().isEmpty
                              ? game.fen
                              : _fenController.text.trim(),
                        );
                        setState(() => _loading = false);
                        if (!mounted) return;
                        if (uci != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Stockfish: $uci')),
                          );
                        }
                      },
                child: const Text('Stockfish Analysis'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // одиночная кнопка: Редактор
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed:
                _inRoom ? null : (_editMode ? _applyEditor : _enterEditor),
            child: Text(_editMode ? 'Выйти из редактора' : 'Редактор'),
          ),
        ),
      ],
    );
  }

// === ЛЕВАЯ ПАНЕЛЬ КНОПОК (над Лобби) ===============================
// == ЛЕВЫЕ КНОПКИ: сетка 2×3, без "Редактор" ==
  Widget _LeftUtilityButtons() {
    final bool canVsEngine = !_inRoom;
    final bool canContinueVsEngine = !_inRoom && !_vsEngine;
    final bool canContinueVsHuman = _vsEngine && !_inRoom;

    // ширина одной ячейки в 2-колоночной сетке
    final double cellW =
        (_leftColWidth - 12) / 2; // 12 = промежуток между колонками

    Widget cell(Widget child) => SizedBox(width: cellW, child: child);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 12, // горизонтальный зазор между колонками
        runSpacing: 10, // вертикальный зазор между рядами
        children: [
          // ряд 1
          cell(FilledButton.tonalIcon(
            onPressed: canContinueVsEngine ? _continueVsEngine : null,
            icon: const Icon(Icons.smart_toy),
            label: const Text('Продолжить с компьютером'),
          )),
          cell(FilledButton.tonalIcon(
            onPressed: canContinueVsHuman ? _continueVsHuman : null,
            icon: const Icon(Icons.group),
            label: const Text('С человеком'),
          )),

          // ряд 2
          cell(FilledButton.tonalIcon(
            onPressed: canVsEngine ? _startEngineDuel : null,
            icon: const Icon(Icons.auto_awesome_motion),
            label: const Text('Компьютер vs Компьютер'),
          )),
          cell(_buildEngineDelayFieldCompact(cellW)),

          // ряд 3
          cell(_buildColorSelectorCompact(cellW)),
          cell(FilledButton.icon(
            onPressed: _onNewGameUniversal,
            icon: const Icon(Icons.fiber_new),
            label: const Text('Новая игра'),
          )),
        ],
      ),
    );
  }

// Компактный переключатель цвета (Белые/Чёрные) в одну ячейку сетки
  Widget _buildColorSelectorCompact(double w) {
    return SizedBox(
      width: w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Вы играете за:', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          ToggleButtons(
            borderRadius: BorderRadius.circular(10),
            isSelected: [
              _humanColor == ch.Color.WHITE,
              _humanColor == ch.Color.BLACK,
            ],
            onPressed: (_vsEngine || _inRoom)
                ? null
                : (i) => setState(() {
                      _humanColor = (i == 0) ? ch.Color.WHITE : ch.Color.BLACK;
                    }),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text('Белые'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text('Чёрные'),
              ),
            ],
          ),
        ],
      ),
    );
  }

// Компактное поле "Задержка, мс" (для дуэли движков)
  Widget _buildEngineDelayFieldCompact(double w) {
    return SizedBox(
      width: w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Задержка, мс', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _duelDelayCtl, // у тебя уже есть этот контроллер
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null) _engineDuelDelayMs = n;
            },
          ),
        ],
      ),
    );
  }

// === ПРАВАЯ ПАНЕЛЬ ПОД MOVES (стрелки + действия + анализ) =========
  Widget _RightUtilityButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Стрелки истории
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: 'В начало',
              onPressed: _plyIndex > 0 ? _goStart : null,
              icon: const Icon(Icons.first_page),
            ),
            IconButton(
              tooltip: 'Назад',
              onPressed: _plyIndex > 0 ? _goPrev : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Вперёд',
              onPressed: _plyIndex < _sanMoves.length ? _goNext : null,
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              tooltip: 'В конец',
              onPressed: _plyIndex < _sanMoves.length ? _goEnd : null,
              icon: const Icon(Icons.last_page),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Сдаться / Предложить ничью
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _onResignPressed,
                icon: const Icon(Icons.flag),
                label: const Text('Сдаться'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (_inRoom && !_isSpectator && !_gameTerminated)
                    ? _offerDrawOnline
                    : null,
                icon: const Icon(Icons.handshake_outlined),
                label: const Text('Предложить ничью'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Блок анализа: как на твоём макете
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _showFenInput = !_showFenInput),
              child: const Text('Введите FEN'),
            ),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      final fenText = _fenController.text.trim().isEmpty
                          ? game.fen
                          : _fenController.text.trim();
                      final uci = await _fetchUciBestMove(fenText);
                      setState(() => _loading = false);
                      if (uci != null && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Лучший ход (UCI): $uci')),
                        );
                      }
                    },
              child: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Взять лучший ход'),
            ),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      final uci =
                          await _fetchUciBestMove(_fenController.text.trim());
                      setState(() => _loading = false);
                      if (uci != null && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Best move (UCI): $uci')),
                        );
                      }
                    },
              child: const Text('Stockfish Analysis'),
            ),
            FilledButton.icon(
              onPressed: _gptLoading ? null : _explainHere, // без доп. текста
              icon: _gptLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.psychology),
              label:
                  Text(_gptLoading ? 'Запрос к GPT...' : 'Объяснить позицию'),
            ),
            // >>> НОВАЯ КНОПКА С ДИАЛОГОМ ВОПРОСА
            FilledButton.icon(
              onPressed: _gptLoading ? null : _openGptPromptDialog,
              icon: const Icon(Icons.question_answer),
              label: const Text('С вопросом…'),
            ),
          ],
        ),
      ],
    );
  }

// === ЕДИНЫЙ КОНТЕНТ (адаптив) ==============================================
// === ЕДИНЫЙ КОНТЕНТ (адаптив, без showChat внутри) ===
  Widget _buildMainContent(double boardSize, bool isLogged, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildTopBar(), // шапка (на десктопе скрыта)
          const SizedBox(height: 8),

          if (isMobile) ...[
            // ===== Мобильная раскладка: всё в колонку =====
            _buildLeftColumn(boardSize), // ваша колонка с доской (как была)
            const SizedBox(height: 16),

            _MoveListPanel(
              san: _sanMoves,
              currentPly: _plyIndex,
              controller: _movesScroll,
              onCopyPGN: () {
                final rows = _rowsFromSan(_sanMoves);
                Clipboard.setData(ClipboardData(text: rows.join(' ')));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PGN скопирован')),
                );
              },
              onClear: () {
                setState(() {
                  _sanMoves.clear();
                  _fens
                    ..clear()
                    ..add(game.fen);
                  _plyIndex = 0;
                });
              },
            ),
            const SizedBox(height: 16),

            _LobbyPanel(
              isLoggedIn: isLogged,
              inLobby: _lobby != null,
              online: _lobby?.online ?? const [],
              myId: Supabase.instance.client.auth.currentUser?.id,
              myRating: _myRating,
              onEnterLobby: _enterLobby,
              onLeaveLobby: _leaveLobby,
              onInvite: (id, name) => _invitePlayer(id, name),
            ),

            const SizedBox(height: 16),
            _buildBottomTools(), // нижние инструменты показываем
            const SizedBox(height: 24),
          ] else ...[
            // ===== Десктоп: три колонки =====
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1) ЛЕВАЯ КОЛОНКА — ЛОББИ + ЧАТ
                SizedBox(
                  width: _leftColWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LeftUtilityButtons(), // если есть (ваши кнопки слева)
                      const SizedBox(height: 12),

                      _LobbyPanel(
                        isLoggedIn: isLogged,
                        inLobby: _lobby != null,
                        online: _lobby?.online ?? const [],
                        myId: Supabase.instance.client.auth.currentUser?.id,
                        myRating: _myRating,
                        onEnterLobby: _enterLobby,
                        onLeaveLobby: _leaveLobby,
                        onInvite: (id, name) => _invitePlayer(id, name),
                      ),

                      const SizedBox(height: 12),

                      // ЧАТ слева
                      _buildChat(maxWidth: 320, height: 220),
                    ],
                  ),
                ),

                const SizedBox(width: 24),

                // 2) ЦЕНТР — ДОСКА (как у вас было)
                _buildLeftColumn(
                  boardSize,
                  showChat: false,
                  showBottomTools: false,
                ),

                const SizedBox(width: 24),

                // 3) ПРАВАЯ КОЛОНКА — Moves + стрелки + действия
                SizedBox(
                  width: 320,
                  child: _RightColumn(boardSize),
                ),
              ],
            ),
            // ⚠️ На десктопе нижние инструменты НЕ выводим, чтобы не было дубля
          ],
        ],
      ),
    );
  }

  // ================== BUILD (адаптив) ==================
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final h = media.size.height;
    final bool isMobile = w < 900;
    final bool isLogged = Supabase.instance.client.auth.currentUser != null;

    // размер доски
    final double desired = _baseAt100 * (_boardPercent / 100.0);
    final double sizeLimit = isMobile ? (w - 32) : (math.min(w, h) - 32);
    final double boardSize = desired.clamp(120.0, sizeLimit);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: (_backgroundProvider != null)
            ? BoxDecoration(
                image: DecorationImage(
                  image: _backgroundProvider!,
                  fit: BoxFit.cover,
                ),
              )
            : null,
        child: SafeArea(
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
        ),
      ),
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
            child: _AuthPanel(
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
              _LobbyPanel(
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
              _buildLeftColumn(boardSize),

              const SizedBox(width: 24),

              // 3) ПРАВАЯ КОЛОНКА: ХОДЫ • СТРЕЛКИ • КНОПКИ
              SizedBox(
                width: 300,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MoveListPanel(
                      san: _sanMoves,
                      currentPly: _plyIndex,
                      controller: _movesScroll,
                      onCopyPGN: () {
                        final rows = _rowsFromSan(_sanMoves);
                        Clipboard.setData(ClipboardData(text: rows.join(' ')));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PGN скопирован')),
                        );
                      },
                      onClear: () {
                        setState(() {
                          _sanMoves.clear();
                          _fens
                            ..clear()
                            ..add(game.fen);
                          _plyIndex = 0;
                        });
                      },
                    ),

                    const SizedBox(height: 10),

                    // СТРЕЛКИ НАВИГАЦИИ ПОД СПИСКОМ ХОДОВ
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDFCF9),
                        border: Border.all(
                            color: const Color(0xFF333333), width: 1.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              tooltip: 'В начало',
                              onPressed: _plyIndex > 0 ? _goStart : null,
                              icon: const Icon(Icons.first_page),
                            ),
                            IconButton(
                              tooltip: 'Назад',
                              onPressed: _plyIndex > 0 ? _goPrev : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            IconButton(
                              tooltip: 'Вперёд',
                              onPressed:
                                  _plyIndex < _sanMoves.length ? _goNext : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                            IconButton(
                              tooltip: 'В конец',
                              onPressed:
                                  _plyIndex < _sanMoves.length ? _goEnd : null,
                              icon: const Icon(Icons.last_page),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // КНОПКИ ПОД СТРЕЛКАМИ
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                (_inRoom && !_isSpectator && !_gameTerminated)
                                    ? _offerDrawOnline
                                    : null,
                            icon: const Icon(Icons.handshake_outlined),
                            label: const Text('Предложить ничью'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _onResignPressed,
                            icon: const Icon(Icons.flag),
                            label: const Text('Сдаться'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
                  !_inRoom ? (_editMode ? _applyEditor : _enterEditor) : null,
                  active: _editMode,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ---------- Доска (часы + чат внутри) ----------
            _buildLeftColumn(boardSize),

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
                child: Text((_lobby == null) ? 'В лобби' : 'Выйти из лобби'),
              ),
            ),

            const SizedBox(height: 12),

            // ---------- Вкладки ----------
            const TabBar(
              labelPadding: EdgeInsets.symmetric(horizontal: 8),
              tabs: [
                Tab(icon: Icon(Icons.sports_esports), text: 'Игра'),
                Tab(icon: Icon(Icons.list_alt), text: 'Ходы'),
                Tab(icon: Icon(Icons.people_alt), text: 'Лобби'),
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
                      child: _MoveListPanel(
                        san: _sanMoves,
                        currentPly: _plyIndex,
                        controller: _movesScroll,
                        onCopyPGN: () {
                          final rows = _rowsFromSan(_sanMoves);
                          Clipboard.setData(
                              ClipboardData(text: rows.join(' ')));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('PGN скопирован')),
                          );
                        },
                        onClear: () {
                          setState(() {
                            _sanMoves.clear();
                            _fens
                              ..clear()
                              ..add(game.fen);
                            _plyIndex = 0;
                          });
                        },
                      ),
                    ),
                  ),

                  // === ТАБ 3: Лобби ===
                  Center(
                    child: SizedBox(
                      width: 320,
                      height: tabsHeight - 20,
                      child: _LobbyPanel(
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
                item(Icons.school, 'Учиться', () => notImpl('Учиться')),
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
          width: totalSize,
          child: RepaintBoundary(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // доступная ширина под доску (в этой колонке/контейнере)
                double w = constraints.maxWidth;
                if (!w.isFinite || w <= 0) {
                  w = MediaQuery.of(context).size.width;
                }

                // учтём симметричную рамку m с каждой стороны
                const double m = 18.0;
                final double rawInner = (w - m * 2).clamp(120.0, w);

                // 👇 ключ: размер клетки целым числом пикселей
                final double cell = (rawInner / 8).floorToDouble();
                final double boardSize = cell * 8;

                return _buildBoardWithCoords(boardSize);
              },
            ),
          ),
        ),

// --- Кнопки под доской: Введите FEN • Взять лучший ход • Объяснить позицию
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
                  OutlinedButton(
                    onPressed: () =>
                        setState(() => _showFenInput = !_showFenInput),
                    child: const Text('Введите FEN'),
                  ),
                  ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () async {
                            setState(() => _loading = true);
                            final fenText = _fenController.text.trim().isEmpty
                                ? game.fen
                                : _fenController.text.trim();
                            final uci = await _fetchUciBestMove(fenText);
                            setState(() => _loading = false);
                            if (uci != null && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Лучший ход (UCI): $uci')),
                              );
                            }
                          },
                    child: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Взять лучший ход'),
                  ),
                  ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () async {
                            setState(() => _loading = true);
                            final uci = await _fetchUciBestMove(
                                _fenController.text.trim());
                            setState(() => _loading = false);
                            if (uci != null && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Best move (UCI): $uci')),
                              );
                            }
                          },
                    child: const Text('Stockfish Analysis'),
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
                    label: Text(
                        _gptLoading ? 'Запрос к GPT...' : 'Объяснить позицию'),
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

        if (_editMode)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: totalSize),
            child: _editorPalette(white: true, cellSize: cell), // БЕЛЫЕ СНИЗУ
          ),

        const SizedBox(height: 6),
        _buildClockRow(playerIsTop: false, maxWidth: totalSize),
        const SizedBox(height: 12),
        _buildChat(maxWidth: totalSize), // чат той же ширины
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

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: active ? Colors.green.shade100 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(
                children: [
                  Icon(playerIsTop
                      ? Icons.arrow_drop_up
                      : Icons.arrow_drop_down),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text('$name  ($rating)',
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 12),
                  Text(_fmtMs(ms),
                      style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()])),
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
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Row(
              children: [
                const Text('Чат'),
                const Spacer(),
                if (_roomId != null)
                  SelectableText('Room: ${_roomId!.substring(0, 8)}...',
                      style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final id = await showDialog<String>(
                      context: context,
                      builder: (_) => _PromptDialog(
                          title: 'Войти как зритель', label: 'roomId'),
                    );
                    if (id == null || id.trim().isEmpty) return;
                    final supa = Supabase.instance.client;
                    final me = supa.auth.currentUser;
                    if (me == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Сначала войдите в аккаунт')));
                      return;
                    }
                    await _openRoom(id.trim(),
                        opponentId: _opponentId ?? 'unknown',
                        opponentName: _opponentName ?? 'opponent',
                        myColor:
                            (_humanColor == ch.Color.WHITE) ? 'white' : 'black',
                        spectator: true);
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('Зритель'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFCF9),
                  border:
                      Border.all(color: const Color(0xFF333333), width: 1.0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  primary: false,
                  itemCount: _chat.length,
                  itemBuilder: (_, i) {
                    final m = _chat[i];
                    final align = m.mine
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start;
                    final bg =
                        m.mine ? Colors.blue.shade50 : Colors.grey.shade200;
                    return Column(
                      crossAxisAlignment: align,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(m.mine ? m.text : '${m.from}: ${m.text}'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatCtl,
                    enabled: _inRoom,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      hintText: 'Настройки...',
                    ),
                    onSubmitted: (_) => _sendChat(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _sendChat, child: const Text('Send')),
              ],
            ),
          ],
        ),
      ),
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
    const double m = 18; // толщина поля под подписи
    final files = _isFlipped
        ? ['H', 'G', 'F', 'E', 'D', 'C', 'B', 'A']
        : ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    final ranks = _isFlipped
        ? ['1', '2', '3', '4', '5', '6', '7', '8']
        : ['8', '7', '6', '5', '4', '3', '2', '1'];
    final labelStyle = TextStyle(
      fontSize: math.max(10, boardSize / 32),
      color: Colors.black.withOpacity(0.7),
    );

    // Делаем симметричную рамку: сверху/слева/справа/снизу одинаковый отступ m
    final totalSize = boardSize + m * 2;

    return SizedBox(
      width: totalSize,
      height: totalSize,
      child: Stack(
        children: [
          // Сама доска — со смещением (m, m)
          Positioned(
            left: m,
            top: m,
            child: _buildChessBoardGrid(boardSize),
          ),

          // Ранги слева (внутри рамки), вдоль доски
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

          // Файлы снизу (внутри рамки), вдоль доски
          Positioned(
            left: m,
            top: m + boardSize,
            width: boardSize,
            height: m,
            child: _editMode
                ? _deleteZone(
                    child: Row(
                      children: List.generate(
                        8,
                        (i) => SizedBox(
                          width: boardSize / 8,
                          child:
                              Center(child: Text(files[i], style: labelStyle)),
                        ),
                      ),
                    ),
                  )
                : Row(
                    children: List.generate(
                      8,
                      (i) => SizedBox(
                        width: boardSize / 8,
                        child: Center(child: Text(files[i], style: labelStyle)),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChessBoardGrid(double boardSize) {
    try {
      final double cell = boardSize / 8;
      final double pieceSize = cell * 0.85;

      return SizedBox(
        width: boardSize,
        height: boardSize,
        child: GridView.builder(
          padding: EdgeInsets.zero, // ✅ без внутренних отступов
          clipBehavior: Clip.hardEdge, // ✅ обрезка "лишнего" за границей
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
            final isCapture = !editing && _captureTargets.contains(square);

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
                  final fenChar = _editBoard[ri][fi]; // 'K','p','.' и т.п.
                  final pieceCode =
                      _pieceCodeFromFen(fenChar); // 'wK','bP' или null

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onSquareEdit(
                        square), // тап по клетке — быстрый выбор фигуры
                    child: Container(
                      decoration: BoxDecoration(
                        color: isWhiteSquare
                            ? const Color(0xFFF0D9B5)
                            : const Color(0xFFB58863),
                        border: Border.all(color: Colors.black12, width: 1),
                      ),
                      child: Center(
                          // если клетка пустая — ничего не рисуем
                          child: (pieceCode == null)
                              ? const SizedBox.shrink()
                              : Draggable<String>(
                                  data: pieceCode,
                                  onDragStarted: () => _dragFromSquare = square,
                                  onDragCompleted: () => _dragFromSquare = null,

                                  // БЫЛО:
                                  // onDraggableCanceled: (_, __) => _dragFromSquare = null,

                                  // СТАЛО: если дроп «в молоко» — удаляем фигуру из исходной клетки
                                  onDraggableCanceled: (_, __) {
                                    if (_dragFromSquare != null) {
                                      final sri = _rankIndex(_dragFromSquare!);
                                      final sfi = _fileIndex(_dragFromSquare!);
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
                                  childWhenDragging: const SizedBox.shrink(),
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
                if (!_myTurnNow() || _isSpectator) return;
                final p = game.get(square);
                if (p != null && p.color == game.turn)
                  _computeLegalTargets(square);
              },
              onTap: () {
                if (!_myTurnNow() || _isSpectator) return;
                if (_selectedSquare == null) return;

                if (_legalTargets.contains(square)) {
                  _makeMove(_selectedSquare!, square);
                  return;
                }

                final pHere = game.get(square);
                final pSel =
                    _selectedSquare != null ? game.get(_selectedSquare!) : null;
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
                        ? const Color(0xFFF0D9B5)
                        : const Color(0xFFB58863),
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
  }

  Future<void> _onNewGameUniversal() async {
    // Онлайн (игра в комнате Supabase)
    if (_inRoom) {
      await _startNewGameFresh(); // у тебя уже есть
      return;
    }

    // Против ИИ
    if (_vsEngine == true) {
      await _startNewGameVsEngine(); // у тебя уже есть
      return;
    }

    // Локально (человек-человек на одном устройстве)
    _startLocalHumanGame(); // см. ниже
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
                'Новая игра: выберите соперника в лобби или начните с ИИ')),
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
  }

  void _cancelEditor() {
    setState(() => _editMode = false);
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
  _TcChoice(
      {required this.minutes, required this.increment, required this.rated});
  final int minutes;
  final int increment;
  final bool rated;
}

class _TcDialog extends StatefulWidget {
  const _TcDialog({
    required this.initialMinutes,
    required this.initialIncrement,
    required this.initialRated,
  });
  final int initialMinutes;
  final int initialIncrement;
  final bool initialRated;

  @override
  State<_TcDialog> createState() => _TcDialogState();
}

class _TcDialogState extends State<_TcDialog> {
  late int minutes = widget.initialMinutes;
  late int inc = widget.initialIncrement;
  late bool rated = widget.initialRated;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Сменить контроль'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Text('Минуты:'),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: minutes,
              items: const [1, 2, 3, 5, 10, 15, 30]
                  .map((m) => DropdownMenuItem(value: m, child: Text('$m')))
                  .toList(),
              onChanged: (v) => setState(() => minutes = v ?? minutes),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Инкремент:'),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: inc,
              items: const [0, 1, 2, 3, 5, 10]
                  .map((s) => DropdownMenuItem(value: s, child: Text('+$s')))
                  .toList(),
              onChanged: (v) => setState(() => inc = v ?? inc),
            ),
          ]),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Рейтинговая:'),
              const SizedBox(width: 8),
              Switch(value: rated, onChanged: (v) => setState(() => rated = v)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Смена контроля сбрасывает часы обоих игроков.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
            onPressed: () => Navigator.pop(context,
                _TcChoice(minutes: minutes, increment: inc, rated: rated)),
            child: const Text('Применить')),
      ],
    );
  }
}

// ---- Move list panel ----
class _MoveListPanel extends StatelessWidget {
  const _MoveListPanel({
    required this.san,
    required this.currentPly,
    required this.controller,
    required this.onCopyPGN,
    required this.onClear,
    this.width,
    this.height,
    Key? key,
  }) : super(key: key);

  final List<String> san;
  final int currentPly;
  final ScrollController controller;
  final VoidCallback onCopyPGN;
  final VoidCallback onClear;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final rowsCount = (san.length / 2.0).ceil();
    final w = width ?? 300;
    final h = height ?? 480;
    return SizedBox(
      width: w,
      height: h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFDFCF9),
          border: Border.all(color: const Color(0xFF333333), width: 1.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Moves',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Expanded(
                child: Scrollbar(
                  controller: controller,
                  child: ListView.builder(
                    controller: controller,
                    itemCount: rowsCount,
                    itemBuilder: (_, i) {
                      final moveNo = i + 1;
                      final whiteIndex = i * 2;
                      final blackIndex = whiteIndex + 1;

                      final whiteShown = whiteIndex < currentPly;
                      final blackShown = blackIndex < currentPly;

                      final white = whiteIndex < san.length && whiteShown
                          ? san[whiteIndex]
                          : '';
                      final black = blackIndex < san.length && blackShown
                          ? san[blackIndex]
                          : '';

                      final isFutureRow = whiteIndex >= currentPly;
                      final style = TextStyle(
                          color: isFutureRow
                              ? Colors.black.withOpacity(0.45)
                              : Colors.black);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                            '$moveNo. $white ${black.isEmpty ? '' : black}',
                            style: style),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                        onPressed: san.isEmpty ? null : onCopyPGN,
                        child: const Text('Скопировать PGN')),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                      tooltip: 'Очистить',
                      onPressed: san.isEmpty ? null : onClear,
                      icon: const Icon(Icons.delete_outline)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Lobby UI ----------
// ---------- Lobby UI ----------
class _LobbyPanel extends StatelessWidget {
  const _LobbyPanel({
    required this.isLoggedIn,
    required this.inLobby,
    required this.online,
    required this.onEnterLobby,
    required this.onLeaveLobby,
    required this.onInvite,
    this.myId,
    required this.myRating,
    Key? key,
  }) : super(key: key);

  final bool isLoggedIn;
  final bool inLobby;
  final List<Map<String, String>> online;
  final Future<void> Function() onEnterLobby;
  final Future<void> Function() onLeaveLobby;
  final void Function(String id, String name) onInvite;

  // ← добавили
  final String? myId;
  final int myRating;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 480,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFDFCF9),
          border: Border.all(color: const Color(0xFF333333), width: 1.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                      child: Text('Лобби',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  if (!inLobby)
                    FilledButton.tonal(
                        onPressed: isLoggedIn ? onEnterLobby : null,
                        child: const Text('Войти'))
                  else
                    OutlinedButton(
                        onPressed: onLeaveLobby, child: const Text('Выйти')),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: (inLobby)
                    ? (online.isEmpty
                        ? const Center(child: Text('Онлайн никого 😴'))
                        : ListView.separated(
                            itemCount: online.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 8),
                            itemBuilder: (_, i) {
                              final u = online[i];
                              final bool isMe = (u['id'] == myId);

                              final String title = isMe
                                  ? '${u['username'] ?? 'player'} (вы)'
                                  : (u['username'] ?? 'player');

// если это мы — берём рейтинг из стейта (_myRating), иначе из лобби
                              final String subtitle =
                                  'Рейт: ${isMe ? myRating : (u['rating'] ?? '—')}';

                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.person),
                                title: Text(title),
                                subtitle: Text(
                                  subtitle,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: FilledButton(
                                  onPressed: isMe
                                      ? null
                                      : () => onInvite(
                                          u['id']!, u['username'] ?? 'player'),
                                  child: const Text('Вызвать'),
                                ),
                              );
                            },
                          ))
                    : const Center(
                        child: Text('Войдите в лобби, чтобы видеть игроков')),
              ),
              const SizedBox(height: 8),
              Text('Онлайн: ${inLobby ? online.length : 0}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- AUTH UI widgets ----------
class _AuthButton extends StatelessWidget {
  final String? nickname;
  final bool isLoggedIn;
  final VoidCallback onTap;
  final Future<void> Function() onLogout;

  const _AuthButton(
      {required this.nickname,
      required this.isLoggedIn,
      required this.onTap,
      required this.onLogout});

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) {
      return FilledButton.tonal(
          onPressed: onTap, child: const Text('Вход / Регистрация'));
    }
    return PopupMenuButton<String>(
      tooltip: 'Аккаунт',
      onSelected: (v) async {
        if (v == 'logout') await onLogout();
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
            value: 'nick', enabled: false, child: Text(nickname ?? 'player')),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(value: 'logout', child: Text('Выйти')),
      ],
      child: Chip(
          avatar: const Icon(Icons.person, size: 18),
          label: Text(nickname ?? 'Аккаунт')),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  final bool isLogin;
  final TextEditingController passCtl;
  final TextEditingController nickCtl;
  final String? authError;
  final VoidCallback onClose;
  final VoidCallback onToggleMode;
  final Future<void> Function() onSubmit;

  const _AuthPanel({
    required this.isLogin,
    required this.passCtl,
    required this.nickCtl,
    required this.authError,
    required this.onClose,
    required this.onToggleMode,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final card = ConstrainedBox(
      constraints: const BoxConstraints.tightFor(width: 360),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text('Вход / Регистрация',
                          style: Theme.of(context).textTheme.titleMedium)),
                  IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                      tooltip: 'Закрыть'),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: nickCtl,
                  decoration: const InputDecoration(
                      labelText: 'Ник (a-z, 0-9, _)',
                      border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(
                  controller: passCtl,
                  decoration: const InputDecoration(
                      labelText: 'Пароль (≥ 6 символов)',
                      border: OutlineInputBorder()),
                  obscureText: true),
              const SizedBox(height: 8),
              if (authError != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(authError!,
                        style: const TextStyle(color: Colors.red))),
              FilledButton(
                  onPressed: onSubmit,
                  child: Text(isLogin ? 'Войти' : 'Зарегистрироваться')),
              TextButton(
                  onPressed: onToggleMode,
                  child: Text(
                      isLogin ? 'Нет аккаунта?' : 'У меня уже есть аккаунт')),
              const SizedBox(height: 4),
              const Text(
                  'Вход по нику, e-mail не требуется (Confirm email = OFF).',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );

    return Stack(
      alignment: Alignment.topRight,
      children: [
        IgnorePointer(
          ignoring: true,
          child: Container(
            width: 380,
            height: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    spreadRadius: 2)
              ],
            ),
          ),
        ),
        card,
      ],
    );
  }
}

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
