import 'dart:convert';
import 'dart:math' as math;

import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

import 'utils.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess API Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Chess API with FEN'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // --------- STATE ----------
  final TextEditingController _fenController = TextEditingController(
    text: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  );
  final ch.Chess game = ch.Chess();
  String? _result;
  bool _loading = false;

  // --- TAP-TO-MOVE state ---
  String? _selectedSquare;
  Set<String> _legalTargets = {};
  Set<String> _captureTargets = {};

  // ----- MOVE LIST (SAN) -----
  final List<String> _sanMoves = [];
  final ScrollController _movesScroll = ScrollController();

  // --------- BOARD SCALE ----------
  static const double _baseAt100 = 480.0; // 100% = 480px
  static const double _minPercent = 50.0;
  static const double _maxPercent = 200.0;
  static const double _stepPercent = 10.0;
  double _boardPercent = 100.0;

  void _bumpZoom(bool increase) {
    final next = _boardPercent + (increase ? _stepPercent : -_stepPercent);
    setState(() {
      _boardPercent = next.clamp(_minPercent, _maxPercent);
    });
  }

  // --------- AUDIO ----------
  final AudioPlayer _player = AudioPlayer();

  Future<void> _playSound({required bool capture}) async {
    try {
      final name = capture ? 'sfx/capture.mp3' : 'sfx/move.mp3';
      await _player.play(AssetSource(name)); // путь относительно assets/
    } catch (_) {}
  }

  @override
  void dispose() {
    _player.dispose();
    _movesScroll.dispose();
    super.dispose();
  }

  // --------- SVG helpers ----------
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

  // ---------- ENGINE ----------
  Future<void> fetchBestMove() async {
    final rawFen = _fenController.text.trim();
    if (rawFen.isEmpty) return;

    final saneFen = sanitizeFenEp(rawFen);
    final fenForApi = stripEpField(saneFen);

    if (fenForApi != rawFen) {
      _fenController.text = fenForApi;
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    final url = Uri.parse('https://chess-api.com/v1');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fen': fenForApi,
          'variants': 3,
          'depth': 18,
          'maxThinkingTime': 2000,
        }),
      );

      if (response.statusCode == 200) {
        final obj = jsonDecode(response.body);
        final pretty = const JsonEncoder.withIndent('  ').convert(obj);
        setState(() => _result = pretty);
      } else {
        setState(
          () => _result = 'Error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      setState(() => _result = 'Exception: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ---------- BOARD HELPERS ----------
  String _indexToSquare(int index) {
    final file = String.fromCharCode('a'.codeUnitAt(0) + (index % 8));
    final rank = 8 - (index ~/ 8);
    return '$file$rank';
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
      builder: (_) => AlertDialog(
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
                onPressed: () => Navigator.of(context).pop(entry.key),
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

  // SAN из verbose-списка ДО выполнения хода
  String? _sanFor(String from, String to, {String? promotion}) {
    try {
      final List<Map<String, dynamic>> ms = List<Map<String, dynamic>>.from(
        game.moves({'square': from, 'verbose': true}),
      );
      for (final m in ms) {
        if (m['to'] == to) {
          final pr = m['promotion'] as String?;
          if (promotion == null || promotion == pr) {
            return m['san'] as String?;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  void _makeMove(String from, String to) async {
    final params = {'from': from, 'to': to};

    String? promo;
    if (_needsPromotion(from, to)) {
      final color = game.get(from)!.color;
      final choice = await _askPromotionPiece(context, color);
      if (choice == null) return; // отменили
      params['promotion'] = choice;
      promo = choice;
    }

    final bool isCapture = _willBeCapture(from, to);
    final san = _sanFor(from, to, promotion: promo) ?? '$from-$to';

    // chess ^0.8.1 → bool
    final bool ok = game.move(params);
    if (!ok) return;

    setState(() {
      _fenController.text = game.fen;

      // запись хода
      _sanMoves.add(san);

      // сброс подсветок
      _selectedSquare = null;
      _legalTargets.clear();
      _captureTargets.clear();
    });

    // автоскролл к последнему ходу
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_movesScroll.hasClients) {
        _movesScroll.animateTo(
          _movesScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    _playSound(capture: isCapture);
    _checkGameOver();
  }

  void _checkGameOver() {
    if (game.in_checkmate) {
      final winner = game.turn == ch.Color.WHITE ? "Чёрные" : "Белые";
      _showGameOverDialog("Мат", "$winner победили!");
      return;
    }
    if (game.in_stalemate) {
      _showGameOverDialog("Пат", "Ничья — патовое положение");
      return;
    }
    if (game.in_threefold_repetition) {
      _showGameOverDialog("Ничья", "Ничья — троекратное повторение позиции");
      return;
    }
    if (game.in_draw) {
      _showGameOverDialog("Ничья", "Игра окончена вничью");
      return;
    }
  }

  void _showGameOverDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  // ====== TAP-TO-MOVE ======
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
        if (flags.contains('c') ||
            flags.contains('e') ||
            m['captured'] != null) {
          caps.add(to);
        }
      }
    } catch (_) {}
    setState(() {
      _selectedSquare = fromSquare;
      _legalTargets = legal;
      _captureTargets = caps;
    });
  }

  // Мгновенная подсветка при нажатии ЛКМ.
  void _onTapDownSquare(String square) {
    final p = game.get(square);
    if (p != null && p.color == game.turn) {
      _computeLegalTargets(square);
    }
  }

  // Завершение клика
  void _onTapSquare(String square) {
    if (_selectedSquare == null) return;

    if (_legalTargets.contains(square)) {
      _makeMove(_selectedSquare!, square);
      return;
    }

    // пере-выбор своей фигуры
    final pHere = game.get(square);
    final pSel = game.get(_selectedSquare!);
    if (pHere != null && pSel != null && pHere.color == pSel.color) {
      _computeLegalTargets(square);
      return;
    }

    // клик по той же клетке — оставляем подсветку
    if (square == _selectedSquare) return;

    // иначе — сброс
    setState(() {
      _selectedSquare = null;
      _legalTargets.clear();
      _captureTargets.clear();
    });
  }

  // ПКМ — быстрый сброс
  void _onSecondaryTapSquare() {
    setState(() {
      _selectedSquare = null;
      _legalTargets.clear();
      _captureTargets.clear();
    });
  }

  // ---------- BOARD UI ----------
  Widget _buildChessBoard(double boardSize) {
    final double cell = boardSize / 8;
    final double pieceSize = cell * 0.85;

    return SizedBox(
      width: boardSize,
      height: boardSize,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
        itemCount: 64,
        itemBuilder: (context, index) {
          final square = _indexToSquare(index);
          final piece = game.get(square);
          final isWhiteSquare = (index ~/ 8 + index % 8) % 2 == 0;

          final bool isSelected = _selectedSquare == square;
          final bool isLegal = _legalTargets.contains(square);
          final bool isCapture = _captureTargets.contains(square);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _onTapDownSquare(square), // сразу показать
            onTap: () => _onTapSquare(square), // завершить действие
            onSecondaryTap: _onSecondaryTapSquare, // ПКМ — сброс
            child: DragTarget<int>(
              onAccept: (fromIndex) {
                final from = _indexToSquare(fromIndex);
                final to = square;
                _makeMove(from, to);
              },
              builder: (context, candidateData, rejectedData) => Container(
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
                    // Подсветки (не мешают мыши)
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
                                color: Colors.redAccent,
                                width: 3,
                              ),
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
  }

  Widget _buildZoomControl() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.zoom_in),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _bumpZoom(false),
                  icon: const Icon(Icons.remove),
                  tooltip: 'Уменьшить',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('Масштаб'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('${_boardPercent.round()} %'),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _bumpZoom(true),
                  icon: const Icon(Icons.add),
                  tooltip: 'Увеличить',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final double desired = _baseAt100 * (_boardPercent / 100.0);
    final sizeLimit = math.min(MediaQuery.of(context).size.width,
            MediaQuery.of(context).size.height) -
        32;
    final double boardSize = desired.clamp(120.0, sizeLimit);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildZoomControl(),
            const SizedBox(height: 8),

            // Доска + панель ходов
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildChessBoard(boardSize),
                  const SizedBox(width: 24),
                  _MoveListPanel(
                    san: _sanMoves,
                    controller: _movesScroll,
                    onCopyPGN: () {
                      final rows = _rowsFromSan(_sanMoves);
                      final pgn = rows.join(' ');
                      Clipboard.setData(ClipboardData(text: pgn));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PGN скопирован')),
                      );
                    },
                    onClear: () => setState(_sanMoves.clear),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- FEN + кнопка API ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _fenController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Enter FEN',
                ),
                onSubmitted: (v) {
                  final ok = game.load(v.trim());
                  if (ok) {
                    setState(() {
                      _selectedSquare = null;
                      _legalTargets.clear();
                      _captureTargets.clear();
                      _sanMoves.clear(); // сброс истории ходов при загрузке FEN
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : fetchBestMove,
              child: const Text('Get Best Move'),
            ),
            const SizedBox(height: 24),

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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Enter a FEN and press the button.'),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Утилита для строки ходов (1. e4 e5)
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
}

// ---- Панель со списком ходов ----
class _MoveListPanel extends StatelessWidget {
  const _MoveListPanel({
    required this.san,
    required this.controller,
    required this.onCopyPGN,
    required this.onClear,
    Key? key,
  }) : super(key: key);

  final List<String> san;
  final ScrollController controller;
  final VoidCallback onCopyPGN;
  final VoidCallback onClear;

  List<String> _rows() {
    final out = <String>[];
    for (int i = 0; i < san.length; i += 2) {
      final n = i ~/ 2 + 1;
      final w = san[i];
      final b = (i + 1 < san.length) ? san[i + 1] : '';
      out.add('$n. $w ${b.isEmpty ? '' : b}');
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
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
              const Text('Moves',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Expanded(
                child: Scrollbar(
                  controller: controller,
                  child: ListView.builder(
                    controller: controller,
                    itemCount: rows.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(rows[i]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: rows.isEmpty ? null : onCopyPGN,
                      child: const Text('Скопировать PGN'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Очистить',
                    onPressed: san.isEmpty ? null : onClear,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
