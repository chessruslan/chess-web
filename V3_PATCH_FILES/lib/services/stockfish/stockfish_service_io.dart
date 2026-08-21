import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'stockfish_models.dart';

class StockfishService {
  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;

  final StreamController<String> _lines =
      StreamController<String>.broadcast();

  final List<String> _recentOutput = <String>[];
  final List<String> _recentErrors = <String>[];

  bool get isRunning => _process != null;
  String? executablePath;

  Future<void> start({String? executablePath}) async {
    if (isRunning) return;

    final path = executablePath ?? _findStockfishExecutable();
    final file = File(path);

    if (!await file.exists()) {
      throw StateError(
        'Stockfish не найден.\n'
        'Ожидался файл:\n$path\n\n'
        'Запустите 01_SETUP_WINDOWS_AND_STOCKFISH.cmd.',
      );
    }

    this.executablePath = file.absolute.path;
    _recentOutput.clear();
    _recentErrors.clear();

    final process = await Process.start(
      file.absolute.path,
      const <String>[],
      workingDirectory: file.parent.path,
      runInShell: false,
      mode: ProcessStartMode.normal,
    );

    _process = process;

    _stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      _remember(_recentOutput, line);
      _lines.add(line);
    });

    _stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      _remember(_recentErrors, line);
      if (line.trim().isNotEmpty) {
        stderr.writeln('[Stockfish stderr] $line');
      }
    });

    // Подписываемся ДО отправки команды, чтобы не потерять быстрый ответ.
    final uciOkFuture = _waitForOrExit(
      (line) => line.trim() == 'uciok',
      timeout: const Duration(seconds: 15),
      description: 'uciok',
    );

    await _send('uci');
    await uciOkFuture;

    final readyOkFuture = _waitForOrExit(
      (line) => line.trim() == 'readyok',
      timeout: const Duration(seconds: 15),
      description: 'readyok',
    );

    await _send('isready');
    await readyOkFuture;
  }

  Future<void> newGame() async {
    _requireRunning();

    await _send('ucinewgame');

    final readyOkFuture = _waitForOrExit(
      (line) => line.trim() == 'readyok',
      timeout: const Duration(seconds: 15),
      description: 'readyok after ucinewgame',
    );

    await _send('isready');
    await readyOkFuture;
  }

  Future<void> stop() async {
    if (!isRunning) return;
    await _send('stop');
  }

  Future<StockfishAnalysisResult> analyzeFen(
    String fen, {
    int depth = 16,
    int multiPv = 1,
    Duration timeout = const Duration(seconds: 30),
    int? maxThinkingTimeMs,
    List<String> searchMoves = const <String>[],
  }) async {
    _requireRunning();

    final normalizedFen = fen.trim();
    if (normalizedFen.isEmpty) {
      throw ArgumentError.value(fen, 'fen', 'FEN не должен быть пустым');
    }

    final safeDepth = depth.clamp(1, 99);
    final safeMultiPv = multiPv.clamp(1, 10);

    await _send('stop');

    final readyOkFuture = _waitForOrExit(
      (line) => line.trim() == 'readyok',
      timeout: const Duration(seconds: 15),
      description: 'readyok before analysis',
    );

    await _send('isready');
    await readyOkFuture;

    await _send('setoption name MultiPV value $safeMultiPv');
    await _send('position fen $normalizedFen');

    final latestByMultiPv = <int, StockfishInfo>{};

    late final StreamSubscription<String> infoSubscription;
    infoSubscription = _lines.stream.listen((line) {
      final parsed = _parseInfo(line);
      if (parsed != null) {
        latestByMultiPv[parsed.multiPv] = parsed;
      }
    });

    try {
      final bestMoveFuture = _waitForOrExit(
        (line) => line.startsWith('bestmove '),
        timeout: timeout,
        description: 'bestmove',
      );

      final validSearchMoves = searchMoves
          .map((move) => move.trim().toLowerCase())
          .where(
            (move) => RegExp(
              r'^[a-h][1-8][a-h][1-8][qrbn]?$',
              caseSensitive: false,
            ).hasMatch(move),
          )
          .toList(growable: false);

      final command = StringBuffer('go');
      if (validSearchMoves.isNotEmpty) {
        command.write(' searchmoves ${validSearchMoves.join(' ')}');
      }
      command.write(' depth $safeDepth');
      if (maxThinkingTimeMs != null && maxThinkingTimeMs > 0) {
        final safeMoveTime = maxThinkingTimeMs.clamp(50, 120000);
        command.write(' movetime $safeMoveTime');
      }

      await _send(command.toString());

      final bestMoveLine = await bestMoveFuture;
      final parts = bestMoveLine.trim().split(RegExp(r'\s+'));

      final bestMove = parts.length >= 2 ? parts[1] : '(none)';
      String? ponderMove;

      final ponderIndex = parts.indexOf('ponder');
      if (ponderIndex >= 0 && ponderIndex + 1 < parts.length) {
        ponderMove = parts[ponderIndex + 1];
      }

      final lines = latestByMultiPv.values.toList()
        ..sort((a, b) => a.multiPv.compareTo(b.multiPv));

      return StockfishAnalysisResult(
        bestMove: bestMove,
        ponderMove: ponderMove,
        lines: List<StockfishInfo>.unmodifiable(lines),
      );
    } finally {
      await infoSubscription.cancel();
    }
  }

  Future<void> dispose() async {
    final process = _process;
    if (process == null) return;

    try {
      await _send('quit');
    } catch (_) {}

    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } catch (_) {
      process.kill();
    }

    _process = null;

    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();

    _stdoutSubscription = null;
    _stderrSubscription = null;
  }

  Future<void> _send(String command) async {
    final process = _process;
    if (process == null) {
      throw StateError('Stockfish не запущен.');
    }

    process.stdin.writeln(command);

    // На Windows обязательно принудительно отправляем буфер процессу.
    await process.stdin.flush();
  }

  void _requireRunning() {
    if (_process == null) {
      throw StateError(
        'Stockfish не запущен. Сначала вызовите StockfishService.start().',
      );
    }
  }

  Future<String> _waitForOrExit(
    bool Function(String line) test, {
    required Duration timeout,
    required String description,
  }) async {
    final process = _process;
    if (process == null) {
      throw StateError('Stockfish не запущен.');
    }

    final lineFuture = _lines.stream.firstWhere(test);

    final result = await Future.any<Object>(<Future<Object>>[
      lineFuture.then<Object>((line) => _StockfishLine(line)),
      process.exitCode.then<Object>((code) => _StockfishExit(code)),
    ]).timeout(
      timeout,
      onTimeout: () {
        throw TimeoutException(
          _diagnosticMessage(
            'Stockfish не ответил: ожидалось $description.',
          ),
          timeout,
        );
      },
    );

    if (result is _StockfishExit) {
      _process = null;
      throw StateError(
        _diagnosticMessage(
          'Stockfish завершился до ответа $description. '
          'Код выхода: ${result.code}.',
        ),
      );
    }

    return (result as _StockfishLine).line;
  }

  String _diagnosticMessage(String firstLine) {
    final buffer = StringBuffer(firstLine);

    if (executablePath != null) {
      buffer
        ..writeln()
        ..writeln('EXE: $executablePath');
    }

    if (_recentOutput.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Последний stdout:')
        ..writeln(_recentOutput.join('\n'));
    }

    if (_recentErrors.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Последний stderr:')
        ..writeln(_recentErrors.join('\n'));
    }

    return buffer.toString();
  }

  void _remember(List<String> target, String value) {
    target.add(value);
    const maxLines = 30;
    if (target.length > maxLines) {
      target.removeRange(0, target.length - maxLines);
    }
  }

  StockfishInfo? _parseInfo(String line) {
    if (!line.startsWith('info ')) return null;

    final tokens = line.trim().split(RegExp(r'\s+'));

    int? depth;
    var multiPv = 1;
    int? scoreCp;
    int? mateIn;
    int? nodes;
    int? nps;
    List<String> pv = const <String>[];

    for (var i = 1; i < tokens.length; i++) {
      switch (tokens[i]) {
        case 'depth':
          if (i + 1 < tokens.length) {
            depth = int.tryParse(tokens[++i]);
          }
          break;
        case 'multipv':
          if (i + 1 < tokens.length) {
            multiPv = int.tryParse(tokens[++i]) ?? 1;
          }
          break;
        case 'score':
          if (i + 2 < tokens.length) {
            final kind = tokens[++i];
            final value = int.tryParse(tokens[++i]);
            if (kind == 'cp') scoreCp = value;
            if (kind == 'mate') mateIn = value;
          }
          break;
        case 'nodes':
          if (i + 1 < tokens.length) {
            nodes = int.tryParse(tokens[++i]);
          }
          break;
        case 'nps':
          if (i + 1 < tokens.length) {
            nps = int.tryParse(tokens[++i]);
          }
          break;
        case 'pv':
          pv = tokens.sublist(i + 1);
          i = tokens.length;
          break;
      }
    }

    if (depth == null || pv.isEmpty) return null;

    return StockfishInfo(
      depth: depth,
      multiPv: multiPv,
      pv: List<String>.unmodifiable(pv),
      scoreCp: scoreCp,
      mateIn: mateIn,
      nodes: nodes,
      nps: nps,
    );
  }

  String _findStockfishExecutable() {
    final env = Platform.environment['MAKECHESS_STOCKFISH'];
    if (env != null && env.trim().isNotEmpty) {
      return env.trim();
    }

    final candidates = <File>[
      File(_join(
        Directory.current.path,
        'stockfish',
        'stockfish.exe',
      )),
      File(_join(
        File(Platform.resolvedExecutable).parent.path,
        'stockfish',
        'stockfish.exe',
      )),
      File(_join(
        File(Platform.resolvedExecutable).parent.path,
        'Stockfish',
        'stockfish.exe',
      )),
    ];

    for (final candidate in candidates) {
      if (candidate.existsSync()) {
        return candidate.absolute.path;
      }
    }

    return candidates.first.absolute.path;
  }

  String _join(String a, String b, [String? c]) {
    final separator = Platform.pathSeparator;
    final first = a.endsWith(separator)
        ? a.substring(0, a.length - 1)
        : a;
    final second = b.startsWith(separator) ? b.substring(1) : b;

    if (c == null) {
      return '$first$separator$second';
    }

    final third = c.startsWith(separator) ? c.substring(1) : c;
    return '$first$separator$second$separator$third';
  }
}

class _StockfishLine {
  const _StockfishLine(this.line);
  final String line;
}

class _StockfishExit {
  const _StockfishExit(this.code);
  final int code;
}
