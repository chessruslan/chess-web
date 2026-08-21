import 'package:flutter/material.dart';

import '../app_style.dart';
import '../../localization/makechess_localization.dart';
import '../../services/lichess_service.dart';
import '../../stockfish_service.dart' as sf;

class RightSidebarPanel extends StatelessWidget {
  final int plyIndex;
  final List<String> sanMoves;
  final VoidCallback onGoStart;
  final VoidCallback onGoPrev;
  final VoidCallback onGoNext;
  final VoidCallback onGoEnd;
  final VoidCallback onResignPressed;
  final VoidCallback offerDrawUniversal;
  final bool loading;
  final Future<void> Function() onBestMove;
  final bool gptLoading;
  final VoidCallback explainHere;
  final bool showFenInput;
  final VoidCallback toggleFenInput;
  final bool loadingBest;
  final VoidCallback onTakeBestMove;
  final bool loadingAnalysis;
  final VoidCallback onOpenAnalysis;
  final VoidCallback openGptPromptDialog;
  final bool inRoom;
  final bool sharedControl;
  final bool editMode;
  final VoidCallback applyEditor;
  final VoidCallback enterEditor;
  final bool compact;

  const RightSidebarPanel({
    super.key,
    required this.plyIndex,
    required this.sanMoves,
    required this.onGoStart,
    required this.onGoPrev,
    required this.onGoNext,
    required this.onGoEnd,
    required this.onResignPressed,
    required this.offerDrawUniversal,
    required this.loading,
    required this.onBestMove,
    required this.gptLoading,
    required this.explainHere,
    required this.showFenInput,
    required this.toggleFenInput,
    required this.loadingBest,
    required this.onTakeBestMove,
    required this.loadingAnalysis,
    required this.onOpenAnalysis,
    required this.openGptPromptDialog,
    required this.inRoom,
    required this.sharedControl,
    required this.editMode,
    required this.applyEditor,
    required this.enterEditor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final assistanceDisabled = LichessPlayGuard.instance.active;
    return DecoratedBox(
      decoration: AppDecorations.panel(),
      child: Padding(
        padding: compact ? const EdgeInsets.all(7) : AppSpacing.panel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              MakeChessLocalization.text(MakeChessTextKey.controls),
              style: compact
                  ? AppTextStyles.panelTitle.copyWith(fontSize: 14)
                  : AppTextStyles.panelTitle,
            ),
            SizedBox(height: compact ? 6 : AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _SidebarIconButton(
                    tooltip:
                        MakeChessLocalization.text(MakeChessTextKey.goStart),
                    icon: Icons.first_page,
                    onTap: plyIndex > 0 ? onGoStart : null,
                  ),
                ),
                SizedBox(width: compact ? 3 : AppSpacing.sm),
                Expanded(
                  child: _SidebarIconButton(
                    tooltip: MakeChessLocalization.text(MakeChessTextKey.back),
                    icon: Icons.chevron_left,
                    onTap: plyIndex > 0 ? onGoPrev : null,
                  ),
                ),
                SizedBox(width: compact ? 3 : AppSpacing.sm),
                Expanded(
                  child: _SidebarIconButton(
                    tooltip:
                        MakeChessLocalization.text(MakeChessTextKey.forward),
                    icon: Icons.chevron_right,
                    onTap: plyIndex < sanMoves.length ? onGoNext : null,
                  ),
                ),
                SizedBox(width: compact ? 3 : AppSpacing.sm),
                Expanded(
                  child: _SidebarIconButton(
                    tooltip: MakeChessLocalization.text(MakeChessTextKey.goEnd),
                    icon: Icons.last_page,
                    onTap: plyIndex < sanMoves.length ? onGoEnd : null,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 5 : AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppNeoButton(
                    text: MakeChessLocalization.text(MakeChessTextKey.resign),
                    icon: Icons.flag,
                    onTap: onResignPressed,
                    danger: true,
                    showIcon: !compact,
                    compact: compact,
                  ),
                ),
                SizedBox(width: compact ? 4 : AppSpacing.sm),
                Expanded(
                  child: AppNeoButton(
                    text: MakeChessLocalization.text(MakeChessTextKey.draw),
                    icon: Icons.handshake_outlined,
                    onTap: offerDrawUniversal,
                    showIcon: !compact,
                    compact: compact,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 5 : AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: sf.localStockfishEnabledNotifier,
                    builder: (context, localEnabled, _) {
                      return ValueListenableBuilder<String>(
                        valueListenable: MakeChessLocalizationController.languageCode,
                        builder: (context, languageCode, _) {
                          return AppNeoButton(
                            text: loading
                                ? MakeChessLocalization.text(
                                    MakeChessTextKey.loading,
                                    languageCode: languageCode,
                                  )
                                : MakeChessLocalization.phrase(
                                    localEnabled
                                        ? 'Локальный Stockfish: ВКЛ'
                                        : 'Локальный Stockfish: ВЫКЛ',
                                    languageCode: languageCode,
                                  ),
                            icon: localEnabled ? Icons.memory : Icons.memory_outlined,
                            onTap: assistanceDisabled || loading
                                ? null
                                : () {
                                    onBestMove();
                                  },
                            showIcon: !compact,
                            compact: compact,
                          );
                        },
                      );
                    },
                  ),
                ),
                SizedBox(width: compact ? 4 : AppSpacing.sm),
                Expanded(
                  child: AppNeoButton(
                    text: gptLoading
                        ? 'GPT...'
                        : MakeChessLocalization.text(MakeChessTextKey.explain),
                    icon: Icons.psychology,
                    onTap:
                        assistanceDisabled || gptLoading ? null : explainHere,
                    showIcon: !compact,
                    compact: compact,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 5 : AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppNeoButton(
                    text: showFenInput
                        ? MakeChessLocalization.text(MakeChessTextKey.hideFen)
                        : MakeChessLocalization.text(MakeChessTextKey.enterFen),
                    icon: Icons.code,
                    onTap: assistanceDisabled ? null : toggleFenInput,
                    showIcon: !compact,
                    compact: compact,
                  ),
                ),
                SizedBox(width: compact ? 4 : AppSpacing.sm),
                Expanded(
                  child: AppNeoButton(
                    text: MakeChessLocalization.text(
                        MakeChessTextKey.withQuestion),
                    icon: Icons.question_answer,
                    onTap: assistanceDisabled || gptLoading
                        ? null
                        : openGptPromptDialog,
                    showIcon: !compact,
                    compact: compact,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 5 : AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppNeoButton(
                    text: loadingBest
                        ? MakeChessLocalization.text(MakeChessTextKey.loading)
                        : MakeChessLocalization.text(MakeChessTextKey.takeMove),
                    icon: Icons.auto_fix_high,
                    onTap: assistanceDisabled || loadingBest
                        ? null
                        : onTakeBestMove,
                    showIcon: !compact,
                    compact: compact,
                  ),
                ),
                SizedBox(width: compact ? 4 : AppSpacing.sm),
                Expanded(
                  child: AppNeoButton(
                    text: loadingAnalysis
                        ? MakeChessLocalization.text(
                            MakeChessTextKey.analysisLoading)
                        : MakeChessLocalization.text(MakeChessTextKey.analysis),
                    icon: Icons.analytics,
                    onTap: assistanceDisabled || loadingAnalysis
                        ? null
                        : onOpenAnalysis,
                    showIcon: !compact,
                    compact: compact,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 5 : AppSpacing.md),
            AppNeoButton(
              text: editMode
                  ? MakeChessLocalization.text(MakeChessTextKey.exitEditor)
                  : MakeChessLocalization.text(MakeChessTextKey.editor),
              icon: Icons.edit,
              onTap: assistanceDisabled || (inRoom && !sharedControl)
                  ? null
                  : (editMode ? applyEditor : enterEditor),
              showIcon: !compact,
              compact: compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  const _SidebarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: AppNeoButton(
        text: '',
        icon: icon,
        onTap: onTap,
      ),
    );
  }
}
