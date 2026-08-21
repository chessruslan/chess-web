import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'services/stockfish/stockfish_service.dart';

const String _startFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

const int _bridgePort = 17891;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final startMinimized =
      args.contains('--bridge') || args.contains('--minimized');

  const windowOptions = WindowOptions(
    size: Size(1180, 860),
    minimumSize: Size(760, 560),
    center: true,
    title: 'MakeChess — Local Stockfish',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    if (startMinimized) {
      await windowManager.minimize();
    } else {
      await windowManager.focus();
    }
  });

  final requestedFen = _fenFromArgs(args);

  runApp(
    MakeChessStockfishApp(
      initialFen: requestedFen ?? _startFen,
      autoAnalyze: requestedFen != null,
      startAsBridge: startMinimized,
    ),
  );
}

String? _fenFromArgs(List<String> args) {
  for (final raw in args) {
    final value = raw.trim();
    if (value.startsWith('--fen=')) {
      final fen = Uri.decodeComponent(value.substring('--fen='.length)).trim();
      if (fen.isNotEmpty) return fen;
    }
  }
  return null;
}

class MakeChessStockfishApp extends StatelessWidget {
  const MakeChessStockfishApp({
    super.key,
    required this.initialFen,
    required this.autoAnalyze,
    required this.startAsBridge,
  });

  final String initialFen;
  final bool autoAnalyze;
  final bool startAsBridge;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MakeChess — Local Stockfish',
      theme: ThemeData.dark(useMaterial3: true),
      home: StockfishPage(
        initialFen: initialFen,
        autoAnalyze: autoAnalyze,
        startAsBridge: startAsBridge,
      ),
    );
  }
}

class StockfishPage extends StatefulWidget {
  const StockfishPage({
    super.key,
    required this.initialFen,
    required this.autoAnalyze,
    required this.startAsBridge,
  });

  final String initialFen;
  final bool autoAnalyze;
  final bool startAsBridge;

  @override
  State<StockfishPage> createState() => _StockfishPageState();
}

class _StockfishPageState extends State<StockfishPage>
    with WindowListener {
  late final TextEditingController _fen;
  final StockfishService _stockfish = StockfishService();

  late final Future<void> _engineReady;

  HttpServer? _bridgeServer;
  StreamSubscription<HttpRequest>? _bridgeSubscription;

  // One local Stockfish process serves the whole site. Requests are queued so
  // eval bar, trainers and move generation can never corrupt each other.
  Future<void> _analysisQueue = Future<void>.value();
  int _pendingAnalyses = 0;

  bool _starting = true;
  bool _analyzing = false;
  bool _bridgeReady = false;
  String _status = 'Запуск Stockfish...';
  String _result = '';
  double _depth = 18;

  @override
  void initState() {
    super.initState();

    _fen = TextEditingController(text: widget.initialFen);

    windowManager.addListener(this);
    unawaited(windowManager.setPreventClose(true));

    _engineReady = _startEngine();
    unawaited(_startLocalBridge());

    if (widget.autoAnalyze) {
      unawaited(_analyzeAfterEngineReady());
    }
  }

  Future<void> _startEngine() async {
    try {
      await _stockfish.start();
      if (!mounted) return;

      setState(() {
        _starting = false;
        _status = widget.autoAnalyze
            ? 'Позиция получена — запускаю локальный анализ'
            : 'Stockfish работает локально';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _starting = false;
        _status = 'Ошибка запуска Stockfish';
        _result = '$e';
      });

      rethrow;
    }
  }

  Future<void> _analyzeAfterEngineReady() async {
    try {
      await _engineReady;
      await _analyze();
    } catch (_) {}
  }

  bool _originAllowed(String? origin) {
    if (origin == null || origin.isEmpty) return true;

    final normalized = origin.toLowerCase();

    if (normalized == 'https://makechess.com' ||
        normalized == 'https://www.makechess.com') {
      return true;
    }

    if (normalized.startsWith('http://localhost:') ||
        normalized.startsWith('https://localhost:') ||
        normalized.startsWith('http://127.0.0.1:') ||
        normalized.startsWith('https://127.0.0.1:')) {
      return true;
    }

    return false;
  }

  void _applyCors(HttpRequest request) {
    final origin = request.headers.value('origin');

    if (origin != null && _originAllowed(origin)) {
      request.response.headers.set('Access-Control-Allow-Origin', origin);
      request.response.headers.set('Vary', 'Origin');
    }

    request.response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, OPTIONS',
    );
    request.response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type',
    );

    // Совместимость со старыми/переходными версиями Private Network Access.
    request.response.headers.set(
      'Access-Control-Allow-Private-Network',
      'true',
    );

    request.response.headers.set(
      'Cache-Control',
      'no-store',
    );
  }

  Future<void> _startLocalBridge() async {
    try {
      final server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        _bridgePort,
        shared: false,
      );

      _bridgeServer = server;

      _bridgeSubscription = server.listen(
        (request) => unawaited(_handleBridgeRequest(request)),
        onError: (Object error, StackTrace stackTrace) {
          if (!mounted) return;
          setState(() {
            _bridgeReady = false;
            _status = 'Ошибка локального моста: $error';
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _bridgeReady = true;
        if (!_starting) {
          _status = 'Stockfish работает локально · глобальный мост 127.0.0.1:$_bridgePort';
        }
      });
    } on SocketException catch (e) {
      if (!mounted) return;

      setState(() {
        _bridgeReady = false;
        _status =
            'Локальный мост уже занят или недоступен: ${e.message}';
      });
    }
  }

  int _queryInt(
    HttpRequest request,
    String name,
    int fallback, {
    required int min,
    required int max,
  }) {
    final raw = request.uri.queryParameters[name];
    final parsed = int.tryParse(raw ?? '');
    return (parsed ?? fallback).clamp(min, max).toInt();
  }

  List<String> _querySearchMoves(HttpRequest request) {
    final raw = request.uri.queryParameters['searchmoves']?.trim() ?? '';
    if (raw.isEmpty) return const <String>[];
    final rx = RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$', caseSensitive: false);
    return raw
        .split(RegExp(r'[\s,;]+'))
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty && rx.hasMatch(value))
        .toList(growable: false);
  }

  Future<StockfishAnalysisResult> _enqueueEngineAnalysis(
    String fen, {
    required int depth,
    required int multiPv,
    required Duration timeout,
    int? maxThinkingTimeMs,
    List<String> searchMoves = const <String>[],
  }) {
    final completer = Completer<StockfishAnalysisResult>();
    _pendingAnalyses++;

    _analysisQueue = _analysisQueue
        .catchError((Object _) {})
        .then<void>((_) async {
      try {
        await _engineReady;
        final result = await _stockfish.analyzeFen(
          fen,
          depth: depth,
          multiPv: multiPv,
          timeout: timeout,
          maxThinkingTimeMs: maxThinkingTimeMs,
          searchMoves: searchMoves,
        );
        if (!completer.isCompleted) completer.complete(result);
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      } finally {
        _pendingAnalyses--;
      }
    });

    return completer.future;
  }

  Map<String, dynamic> _apiPayload(
    String fen,
    StockfishAnalysisResult result,
  ) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    final whiteToMove = parts.length < 2 || parts[1].toLowerCase() != 'b';

    Map<String, dynamic> linePayload(StockfishInfo line) {
      final whiteCp = line.scoreCp == null
          ? null
          : (whiteToMove ? line.scoreCp! : -line.scoreCp!);
      final whiteMate = line.mateIn == null
          ? null
          : (whiteToMove ? line.mateIn! : -line.mateIn!);
      final move = line.pv.isEmpty ? result.bestMove : line.pv.first;
      final score = <String, dynamic>{'pov': 'white'};
      if (whiteCp != null) {
        score['cp'] = whiteCp;
        score['value'] = whiteCp / 100.0;
      }
      if (whiteMate != null) score['mate'] = whiteMate;

      return <String, dynamic>{
        'move': move,
        'uci': move,
        'bestMove': move,
        'depth': line.depth,
        'multiPv': line.multiPv,
        if (whiteCp != null) 'eval': whiteCp / 100.0,
        if (whiteCp != null) 'centipawns': whiteCp.toString(),
        if (whiteCp != null) 'cp': whiteCp,
        if (whiteMate != null) 'mate': whiteMate,
        'score': score,
        'pov': 'white',
        'pv': line.pv.join(' '),
        'line': line.pv,
        if (line.nodes != null) 'nodes': line.nodes,
        if (line.nps != null) 'nps': line.nps,
      };
    }

    final variants = result.lines.map(linePayload).toList(growable: false);
    final principal = variants.isEmpty ? null : variants.first;
    final principalLine = result.lines.isEmpty ? null : result.lines.first;
    final evalText = principal == null
        ? '—'
        : principal['mate'] != null
            ? 'mate ${principal['mate']}'
            : '${principal['eval'] ?? '—'}';

    return <String, dynamic>{
      'source': 'local',
      'local': true,
      'type': 'bestmove',
      'fen': fen,
      'turn': whiteToMove ? 'w' : 'b',
      'color': whiteToMove ? 'w' : 'b',
      'move': result.bestMove,
      'uci': result.bestMove,
      'bestMove': result.bestMove,
      if (result.ponderMove != null) 'ponder': result.ponderMove,
      if (principal != null) 'depth': principal['depth'],
      if (principal != null && principal['eval'] != null)
        'eval': principal['eval'],
      if (principal != null && principal['centipawns'] != null)
        'centipawns': principal['centipawns'],
      if (principal != null && principal['mate'] != null)
        'mate': principal['mate'],
      if (principal != null) 'score': principal['score'],
      if (principalLine != null) 'pv': principalLine.pv.join(' '),
      if (principalLine != null) 'continuationArr': principalLine.pv,
      'variants': variants,
      'text': 'Локальный Stockfish: лучший ход ${result.bestMove}; '
          'оценка $evalText; '
          'глубина ${principal?['depth'] ?? '—'}.',
    };
  }

  Future<void> _handleBridgeRequest(HttpRequest request) async {
    final origin = request.headers.value('origin');

    if (!_originAllowed(origin)) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }

    _applyCors(request);

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    if (request.method != 'GET') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }

    if (request.uri.path == '/health') {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'ok': true,
          'stockfish': _stockfish.isRunning,
          'analyzing': _analyzing || _pendingAnalyses > 0,
          'pending': _pendingAnalyses,
          'port': _bridgePort,
          'mode': 'global-switch-v4',
        }),
      );
      await request.response.close();
      return;
    }

    if (request.uri.path != '/analyze') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final fen = request.uri.queryParameters['fen']?.trim();
    if (fen == null || fen.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, Object?>{
        'error': 'Missing fen',
      }));
      await request.response.close();
      return;
    }

    final depth = _queryInt(request, 'depth', 18, min: 1, max: 99);
    final variants = _queryInt(request, 'variants', 1, min: 1, max: 10);
    final maxThinkingTime = _queryInt(
      request,
      'maxThinkingTime',
      2500,
      min: 50,
      max: 120000,
    );
    final searchMoves = _querySearchMoves(request);

    try {
      final result = await _enqueueEngineAnalysis(
        fen,
        depth: depth,
        multiPv: variants,
        maxThinkingTimeMs: maxThinkingTime,
        searchMoves: searchMoves,
        timeout: Duration(milliseconds: maxThinkingTime + 15000),
      );

      if (mounted) {
        _fen.value = TextEditingValue(
          text: fen,
          selection: TextSelection.collapsed(offset: fen.length),
        );
        setState(() {
          _status = 'Фоновый запрос MakeChess выполнен локально';
        });
      }

      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_apiPayload(fen, result)));
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, Object?>{
        'error': '$e',
        'source': 'local',
      }));
    }

    await request.response.close();
  }



  Future<void> _analyze() async {
    if (_analyzing) {
      await _stockfish.stop();
      if (mounted) {
        setState(() => _analyzing = false);
      }
    }

    if (_starting || !_stockfish.isRunning) return;

    setState(() {
      _analyzing = true;
      _result = '';
      _status = 'Анализ...';
    });

    try {
      final result = await _enqueueEngineAnalysis(
        _fen.text,
        depth: _depth.round(),
        multiPv: 3,
        timeout: const Duration(seconds: 60),
      );

      final buffer = StringBuffer()
        ..writeln('Лучший ход: ${result.bestMove}')
        ..writeln();

      for (final line in result.lines) {
        buffer
          ..writeln(
            'PV${line.multiPv}   depth ${line.depth}   '
            'оценка ${line.scoreText}',
          )
          ..writeln(line.pv.take(18).join(' '))
          ..writeln();
      }

      if (!mounted) return;

      setState(() {
        _result = buffer.toString();
        _status =
            'Готово — анализ выполнен локально, интернет не использовался';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _result = '$e';
        _status = 'Ошибка анализа';
      });
    } finally {
      if (mounted) {
        setState(() => _analyzing = false);
      }
    }
  }

  Future<void> _quitApplication() async {
    try {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } catch (_) {
      exit(0);
    }
  }

  @override
  void onWindowClose() {
    unawaited(windowManager.minimize());
  }

  @override
  void dispose() {
    windowManager.removeListener(this);

    _bridgeSubscription?.cancel();
    _bridgeServer?.close(force: true);

    _fen.dispose();
    _stockfish.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MakeChess — локальный Stockfish'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: Text(
                _bridgeReady
                    ? 'Мост: готов'
                    : 'Мост: не запущен',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _bridgeReady
                      ? Colors.greenAccent
                      : Colors.orangeAccent,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Полностью закрыть локальный модуль',
            onPressed: _quitApplication,
            icon: const Icon(Icons.power_settings_new),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          _stockfish.isRunning
                              ? Icons.check_circle
                              : Icons.error_outline,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _status,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _fen,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'FEN',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Глубина: ${_depth.round()}'),
                    Expanded(
                      child: Slider(
                        value: _depth,
                        min: 6,
                        max: 30,
                        divisions: 24,
                        onChanged: _analyzing
                            ? null
                            : (value) => setState(() => _depth = value),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed:
                          _stockfish.isRunning && !_starting ? _analyze : null,
                      icon: _analyzing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.psychology_alt_outlined),
                      label: const Text('Анализировать'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _result.isEmpty
                              ? 'Здесь появится анализ Stockfish.'
                              : _result,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
