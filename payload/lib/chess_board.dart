// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as ch;

import 'ui/app_controls.dart';

import 'localization/makechess_localization.dart';
class ChessBoard extends StatefulWidget {
  const ChessBoard({super.key});

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {
  // --------- состояние партии ----------
  final ch.Chess game = ch.Chess();
  String? selectedSquare;
  final List<String> moveHistory = [];

  // ===== ХЕЛПЕР ДЛЯ ПЛОТНЫХ "ПИЛЮЛЬ" =====
  ButtonStyle _pillStyle(BuildContext context) {
    return AppControls.pillButton();
  }

  Widget _pill(String label, IconData icon, VoidCallback? onPressed) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: MakeChessLocalizedText(label),
      style: _pillStyle(context),
    );
  }

  // ---------- PROMOTION DIALOG ----------
  Future<String?> _pickPromotionPiece(BuildContext context) {
    Widget btn(String label, String code, String glyph) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context, rootNavigator: true).pop(code),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MakeChessLocalizedText(glyph, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              MakeChessLocalizedText(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MakeChessLocalizedText(
                'Выберите фигуру для превращения',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  btn('Ферзь', 'q', '♛'),
                  btn('Ладья', 'r', '♜'),
                  btn('Слон', 'b', '♝'),
                  btn('Конь', 'n', '♞'),
                ],
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogCtx, rootNavigator: true).pop(null),
                child: const MakeChessLocalizedText('Отмена'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- базовые действия ----------
  void undoMove() {
    if (moveHistory.isNotEmpty) {
      setState(() {
        game.load(moveHistory.removeLast());
        selectedSquare = null;
      });
    }
  }

  Future<void> onTapSquare(String square) async {
    if (selectedSquare == null) {
      setState(() => selectedSquare = square);
      return;
    }

    final from = selectedSquare!;
    final to = square;

    // Проверка легальности хода
    final legalMoves = game.moves({'square': from});
    if (!legalMoves.any((m) => m.contains(to))) {
      setState(() => selectedSquare = null);
      return;
    }

    // Поддержка промо
    final piece = game.get(from);
    final bool isPawn = piece?.type == ch.PieceType.PAWN;
    final bool isWhite = piece?.color == ch.Color.WHITE;
    final int rankTo = int.tryParse(to.substring(1, 2)) ?? 0;
    final bool willPromote =
        isPawn && ((isWhite && rankTo == 8) || (!isWhite && rankTo == 1));

    String? promo;
    if (willPromote) {
      promo = await _pickPromotionPiece(context);
      if (promo == null) {
        setState(() => selectedSquare = null);
        return;
      }
    }

    // Сохраняем позицию для undo
    moveHistory.add(game.fen);

    // Ход (с учётом промо)
    final move = <String, dynamic>{
      'from': from,
      'to': to,
      if (promo != null) 'promotion': promo,
    };

    final result = game.move(move);
    if (result == null || result == false) {
      if (moveHistory.isNotEmpty) moveHistory.removeLast();
      setState(() => selectedSquare = null);
      return;
    }

    setState(() => selectedSquare = null);

    // Здесь можно вызывать движок, если нужно.
    // Я оставил пусто, чтобы файл собирался без внешних импортов.
  }

  Widget buildSquare(int index) {
    final file = index % 8;
    final rank = 7 - index ~/ 8;
    final square = '${'abcdefgh'[file]}${rank + 1}';
    final piece = game.get(square);
    final isSelected = square == selectedSquare;

    Color color = (file + rank) % 2 == 0 ? Colors.brown[300]! : Colors.white;
    if (isSelected) color = Colors.yellow;

    return GestureDetector(
      onTap: () => onTapSquare(square),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.black12),
        ),
        child: piece != null
            ? Center(
                child: MakeChessLocalizedText(
                  piece.color == ch.Color.WHITE
                      ? piece.type.name.toUpperCase()
                      : piece.type.name,
                  style: const TextStyle(fontSize: 28),
                ),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: GridView.builder(
              itemCount: 64,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
              ),
              itemBuilder: (context, index) => buildSquare(index),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ===== КНОПКИ-ПИЛЮЛИ ПОД ДОСКОЙ (НЕПРОЗРАЧНЫЕ) =====
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _pill('Сдаться', Icons.flag, undoMove), // пример
            _pill('Предложить ничью', Icons.handshake,
                () {}), // TODO: подставь свои обработчики
            _pill('Взять лучший ход', Icons.auto_awesome, () {}),
            _pill('Объяснить позицию', Icons.psychology, () {}),
            _pill('Ввести FEN', Icons.input, () {}),
            _pill('Stockfish Analysis', Icons.bolt, () {}),
            _pill('Редактор', Icons.edit, () {}),
          ],
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}
