import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as ch;
import 'stockfish_service.dart';

class ChessBoard extends StatefulWidget {
  const ChessBoard({super.key});

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {
  final ch.Chess game = ch.Chess();
  String? selectedSquare;
  final List<String> moveHistory = [];

  void undoMove() {
    if (moveHistory.isNotEmpty) {
      setState(() {
        game.load(moveHistory.removeLast());
        selectedSquare = null;
      });
    }
  }

  void onTapSquare(String square) async {
    if (selectedSquare == null) {
      setState(() {
        selectedSquare = square;
      });
    } else {
      final move = {'from': selectedSquare!, 'to': square};

      final legalMoves = game.moves({'square': selectedSquare!});
      if (legalMoves.any((m) => m.contains(square))) {
        moveHistory.add(game.fen);
        game.move(move);

        setState(() {
          selectedSquare = null;
        });

        final bestMove = await getBestMove(game.fen);
        game.move(bestMove);

        setState(() {});
      } else {
        setState(() {
          selectedSquare = null;
        });
      }
    }
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
                child: Text(
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
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: undoMove,
          child: const Text('Undo'),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
