import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../platform/web_compat.dart';
import '../secrets.dart';

class LichessConnection {
  const LichessConnection({required this.connected, this.username});

  final bool connected;
  final String? username;
}

class LichessPlayGuard extends ChangeNotifier {
  LichessPlayGuard._();

  static final LichessPlayGuard instance = LichessPlayGuard._();

  bool _active = false;
  bool get active => _active;

  void setActive(bool value) {
    if (_active == value) return;
    _active = value;
    notifyListeners();
  }
}

class LichessService {
  LichessService._();

  static final LichessService instance = LichessService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final response = await _client.functions.invoke('lichess', body: body);
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Lichess: ошибка ${response.status}');
    }
    final data = response.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<LichessConnection> status() async {
    if (_client.auth.currentUser == null) {
      return const LichessConnection(connected: false);
    }
    final data = await _invoke(<String, dynamic>{'action': 'status'});
    return LichessConnection(
      connected: data['connected'] == true,
      username: data['username']?.toString(),
    );
  }

  Future<void> connect() async {
    if (_client.auth.currentUser == null) {
      throw StateError('Сначала войдите в аккаунт MakeChess');
    }
    final data = await _invoke(<String, dynamic>{
      'action': 'start',
      'returnUrl': currentPageUrl(),
    });
    final url = data['authorizationUrl']?.toString() ?? '';
    if (url.isEmpty) throw StateError('Lichess не вернул адрес подключения');
    navigateToUrl(url);
  }

  Future<void> disconnect() async {
    await LichessSessionController.instance.stop();
    await _invoke(<String, dynamic>{'action': 'disconnect'});
    LichessPlayGuard.instance.setActive(false);
  }

  Future<void> startSeek({required int minutes, required int increment}) async {
    LichessPlayGuard.instance.setActive(true);
    try {
      await _invoke(<String, dynamic>{
        'action': 'seek',
        'minutes': minutes,
        'increment': increment,
        'rated': false,
      });
    } catch (_) {
      LichessPlayGuard.instance.setActive(false);
      rethrow;
    }
  }

  Future<void> sendMove(String gameId, String uci) => _invoke(<String, dynamic>{
        'action': 'move',
        'gameId': gameId,
        'move': uci,
      });

  Future<void> resign(String gameId) =>
      _invoke(<String, dynamic>{'action': 'resign', 'gameId': gameId});

  Future<void> offerDraw(String gameId) => _invoke(<String, dynamic>{
        'action': 'draw',
        'gameId': gameId,
        'accept': true,
      });
}

class LichessGameSnapshot {
  const LichessGameSnapshot({
    required this.gameId,
    required this.moves,
    required this.status,
    required this.whiteMs,
    required this.blackMs,
    this.initialFen,
    this.myColor,
    this.whiteName,
    this.blackName,
    this.winner,
  });

  final String gameId;
  final List<String> moves;
  final String status;
  final int whiteMs;
  final int blackMs;
  final String? initialFen;
  final String? myColor;
  final String? whiteName;
  final String? blackName;
  final String? winner;

  bool get finished => !const <String>{'created', 'started'}.contains(status);
}

class LichessSessionController extends ChangeNotifier {
  LichessSessionController._();

  static final LichessSessionController instance = LichessSessionController._();

  LichessGameSnapshot? snapshot;
  String? error;
  bool searching = false;
  http.Client? _client;
  int _generation = 0;

  Map<String, String> _headers() {
    final token =
        Supabase.instance.client.auth.currentSession?.accessToken ?? '';
    return <String, String>{
      'authorization': 'Bearer $token',
      'apikey': supabaseAnonKey,
      'content-type': 'application/json',
      'accept': 'application/x-ndjson',
    };
  }

  Uri _uri(String action, [Map<String, String>? extra]) => Uri.parse(
        '$supabaseUrl/functions/v1/lichess',
      ).replace(queryParameters: <String, String>{'action': action, ...?extra});

  Future<void> startSearch(
      {required int minutes, required int increment}) async {
    await stop(clearGuard: false);
    final generation = ++_generation;
    searching = true;
    error = null;
    LichessPlayGuard.instance.setActive(true);
    notifyListeners();
    final client = http.Client();
    _client = client;
    try {
      final request = http.Request('POST', _uri('seek'))
        ..headers.addAll(_headers())
        ..body = jsonEncode(<String, dynamic>{
          'action': 'seek',
          'minutes': minutes,
          'increment': increment,
          'rated': false,
        });
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(await response.stream.bytesToString());
      }
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (generation != _generation || line.trim().isEmpty) continue;
        final data = jsonDecode(line) as Map<String, dynamic>;
        final id = _extractGameId(data);
        if (id != null) {
          searching = false;
          notifyListeners();
          await watchGame(id, generation: generation);
          return;
        }
      }
    } catch (e) {
      if (generation == _generation) {
        searching = false;
        error = '$e';
        LichessPlayGuard.instance.setActive(false);
        notifyListeners();
      }
    }
  }

  String? _extractGameId(Map<String, dynamic> data) {
    final direct = data['id'] ?? data['gameId'];
    if (direct != null && '$direct'.isNotEmpty) return '$direct';
    final game = data['game'];
    if (game is Map && game['id'] != null) return '${game['id']}';
    final full = data['gameFull'];
    if (full is Map && full['id'] != null) return '${full['id']}';
    return null;
  }

  Future<void> watchGame(String gameId, {int? generation}) async {
    final activeGeneration = generation ?? ++_generation;
    _client?.close();
    final client = http.Client();
    _client = client;
    LichessPlayGuard.instance.setActive(true);
    try {
      final request = http.Request(
        'GET',
        _uri('gameStream', <String, String>{'gameId': gameId}),
      )..headers.addAll(_headers());
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(await response.stream.bytesToString());
      }
      Map<String, dynamic>? gameFull;
      final connected = await LichessService.instance.status();
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (activeGeneration != _generation || line.trim().isEmpty) continue;
        final data = jsonDecode(line) as Map<String, dynamic>;
        if (data['type'] == 'gameFull') gameFull = data;
        final state = data['type'] == 'gameFull' ? data['state'] : data;
        if (state is! Map) continue;
        final me = Supabase.instance.client.auth.currentUser?.id;
        final white = gameFull?['white'];
        final black = gameFull?['black'];
        String? myColor;
        if (white is Map && '${white['id']}' == me) myColor = 'white';
        if (black is Map && '${black['id']}' == me) myColor = 'black';
        // Lichess ids are not MakeChess ids; account endpoint username is used as fallback.
        if (white is Map &&
            '${white['name'] ?? white['id']}'.toLowerCase() ==
                connected.username?.toLowerCase()) {
          myColor = 'white';
        }
        if (black is Map &&
            '${black['name'] ?? black['id']}'.toLowerCase() ==
                connected.username?.toLowerCase()) {
          myColor = 'black';
        }
        snapshot = LichessGameSnapshot(
          gameId: gameId,
          moves: '${state['moves'] ?? ''}'.trim().isEmpty
              ? const <String>[]
              : '${state['moves']}'.trim().split(RegExp(r'\s+')),
          status: '${state['status'] ?? 'started'}',
          whiteMs: (state['wtime'] as num?)?.toInt() ?? 0,
          blackMs: (state['btime'] as num?)?.toInt() ?? 0,
          initialFen: gameFull?['initialFen']?.toString(),
          myColor: myColor,
          whiteName: white is Map
              ? '${white['name'] ?? white['id'] ?? 'White'}'
              : null,
          blackName: black is Map
              ? '${black['name'] ?? black['id'] ?? 'Black'}'
              : null,
          winner: state['winner']?.toString(),
        );
        error = null;
        notifyListeners();
        if (snapshot!.finished) {
          LichessPlayGuard.instance.setActive(false);
          return;
        }
      }
      if (activeGeneration == _generation && snapshot?.finished == false) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (activeGeneration == _generation) {
          await watchGame(gameId, generation: activeGeneration);
        }
      }
    } catch (e) {
      if (activeGeneration == _generation) {
        error = '$e';
        notifyListeners();
        if (snapshot?.finished == false) {
          await Future<void>.delayed(const Duration(seconds: 2));
          if (activeGeneration == _generation) {
            error = null;
            await watchGame(gameId, generation: activeGeneration);
          }
        }
      }
    }
  }

  Future<void> restoreActiveGame() async {
    if (snapshot != null || searching) return;
    if (Supabase.instance.client.auth.currentUser == null) return;
    final generation = ++_generation;
    final client = http.Client();
    _client = client;
    try {
      final request = http.Request('GET', _uri('events'))
        ..headers.addAll(_headers());
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (generation != _generation || line.trim().isEmpty) continue;
        final data = jsonDecode(line) as Map<String, dynamic>;
        if (data['type'] != 'gameStart') continue;
        final id = _extractGameId(data);
        if (id == null) continue;
        client.close();
        await watchGame(id, generation: generation);
        return;
      }
    } catch (_) {
      // No active Lichess game is a normal state.
    }
  }

  Future<void> sendMove(String uci) async {
    final current = snapshot;
    if (current == null) throw StateError('Нет активной партии Lichess');
    await LichessService.instance.sendMove(current.gameId, uci);
  }

  Future<void> resign() async {
    final current = snapshot;
    if (current != null) await LichessService.instance.resign(current.gameId);
  }

  Future<void> offerDraw() async {
    final current = snapshot;
    if (current != null) {
      await LichessService.instance.offerDraw(current.gameId);
    }
  }

  Future<void> stop({bool clearGuard = true}) async {
    _generation++;
    _client?.close();
    _client = null;
    searching = false;
    snapshot = null;
    if (clearGuard) LichessPlayGuard.instance.setActive(false);
    notifyListeners();
  }
}
