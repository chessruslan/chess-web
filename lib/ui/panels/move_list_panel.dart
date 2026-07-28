import 'package:flutter/material.dart';

import '../app_style.dart';

class MoveListPanel extends StatelessWidget {
  const MoveListPanel({
    required this.san,
    required this.currentPly,
    required this.controller,
    required this.onCopyPGN,
    required this.onClear,
    this.puzzleMoveChecked = false,
    this.puzzleMoveCorrect,
    this.showPuzzleCorrectAnswer = false,
    this.correctPuzzleLines = const [],
    this.selectedCorrectLineIndex = 0,
    this.onPreviousCorrectLine,
    this.onNextCorrectLine,
    this.width,
    this.height,
    this.compact = false,
    super.key,
  });

  final List<String> san;
  final int currentPly;
  final ScrollController controller;
  final VoidCallback onCopyPGN;
  final VoidCallback onClear;

  /// Проверка ходов в режиме задач.
  final bool puzzleMoveChecked;
  final bool? puzzleMoveCorrect;
  final bool showPuzzleCorrectAnswer;
  final List<List<String>> correctPuzzleLines;
  final int selectedCorrectLineIndex;
  final VoidCallback? onPreviousCorrectLine;
  final VoidCallback? onNextCorrectLine;

  final double? width;
  final double? height;
  final bool compact;


  String _formatMoveLine(List<String> moves) {
    if (moves.isEmpty) return '—';
    final rows = <String>[];
    for (var i = 0; i < moves.length; i += 2) {
      final moveNo = (i ~/ 2) + 1;
      final white = moves[i];
      final black = i + 1 < moves.length ? moves[i + 1] : '';
      rows.add('$moveNo. $white${black.isEmpty ? '' : ' $black'}');
    }
    return rows.join('  ');
  }

  @override
  Widget build(BuildContext context) {
    final rowsCount = (san.length / 2.0).ceil();
    final w = width ?? 300;
    final h = height ?? 480;

    return SizedBox(
      width: w,
      height: h,
      child: DecoratedBox(
        decoration: AppDecorations.panel(),
        child: Padding(
          padding: EdgeInsets.all(compact ? 7 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Moves',
                style: compact
                    ? AppTextStyles.panelTitle.copyWith(fontSize: 14)
                    : AppTextStyles.panelTitle,
              ),
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
                      final style = AppTextStyles.body.copyWith(
                        color: isFutureRow
                            ? AppColors.textDim.withOpacity(0.55)
                            : AppColors.text,
                        fontWeight: FontWeight.w500,
                      );

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '$moveNo. $white ${black.isEmpty ? '' : black}',
                          style: style,
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (puzzleMoveChecked || showPuzzleCorrectAnswer) ...[
                const SizedBox(height: 8),
                _PuzzleMoveResultBox(
                  checked: puzzleMoveChecked,
                  correct: puzzleMoveCorrect,
                  showAnswer: showPuzzleCorrectAnswer,
                  correctLines: correctPuzzleLines,
                  selectedLineIndex: selectedCorrectLineIndex,
                  onPrevious: onPreviousCorrectLine,
                  onNext: onNextCorrectLine,
                  formatMoveLine: _formatMoveLine,
                ),
              ],
              const SizedBox(height: 10),
              if (compact) ...[
                AppNeoButton(
                  text: 'Скопировать PGN',
                  icon: Icons.copy_all,
                  onTap: san.isEmpty ? null : onCopyPGN,
                  showIcon: false,
                  compact: true,
                ),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 42,
                    child: AppNeoButton(
                      text: '',
                      icon: Icons.delete_outline,
                      onTap: san.isEmpty ? null : onClear,
                      compact: true,
                    ),
                  ),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: AppNeoButton(
                        text: 'Скопировать PGN',
                        icon: Icons.copy_all,
                        onTap: san.isEmpty ? null : onCopyPGN,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 54,
                      child: AppNeoButton(
                        text: '',
                        icon: Icons.delete_outline,
                        onTap: san.isEmpty ? null : onClear,
                      ),
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


class _PuzzleMoveResultBox extends StatelessWidget {
  const _PuzzleMoveResultBox({
    required this.checked,
    required this.correct,
    required this.showAnswer,
    required this.correctLines,
    required this.selectedLineIndex,
    required this.onPrevious,
    required this.onNext,
    required this.formatMoveLine,
  });

  final bool checked;
  final bool? correct;
  final bool showAnswer;
  final List<List<String>> correctLines;
  final int selectedLineIndex;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final String Function(List<String> moves) formatMoveLine;

  @override
  Widget build(BuildContext context) {
    final hasLines = correctLines.isNotEmpty;
    final safeIndex = hasLines
        ? selectedLineIndex.clamp(0, correctLines.length - 1).toInt()
        : 0;
    final answerText = hasLines ? formatMoveLine(correctLines[safeIndex]) : '—';

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.58),
        borderRadius: AppRadius.r12,
        border: Border.all(color: AppColors.borderSoft),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (checked)
            Text(
              correct == true
                  ? 'Ответ по ходам верный'
                  : 'Ответ по ходам неверный',
              style: AppTextStyles.buttonCompact.copyWith(
                color: correct == true
                    ? const Color(0xFF7DFF9A)
                    : const Color(0xFFFF7777),
                fontWeight: FontWeight.w900,
              ),
            ),
          if (showAnswer) ...[
            if (checked) const SizedBox(height: 6),
            Text(
              'Правильный ответ${hasLines ? ' ${safeIndex + 1}/${correctLines.length}' : ''}:',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: AppRadius.r8,
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  answerText,
                  style: AppTextStyles.mono.copyWith(color: AppColors.text),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _TinyAnswerNavButton(
                    icon: Icons.arrow_back,
                    text: 'Назад',
                    onTap: hasLines && correctLines.length > 1
                        ? onPrevious
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TinyAnswerNavButton(
                    icon: Icons.arrow_forward,
                    text: 'Вперёд',
                    onTap: hasLines && correctLines.length > 1
                        ? onNext
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TinyAnswerNavButton extends StatelessWidget {
  const _TinyAnswerNavButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: AppNeoButton(
        text: text,
        icon: icon,
        onTap: onTap,
      ),
    );
  }
}
