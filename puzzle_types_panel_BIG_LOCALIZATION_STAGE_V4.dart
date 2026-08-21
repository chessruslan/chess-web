// MAKECHESS_BIG_LOCALIZATION_STAGE_V4_20260807
// MAKECHESS_STUDENT_TRAINING_MENU_V1_20260805
import 'package:flutter/material.dart';

import '../app_style.dart';
import 'puzzle_task.dart';
import '../../localization/makechess_localization.dart';

class PuzzleAnalysisResult {
  const PuzzleAnalysisResult({
    this.whiteCorrect = 0,
    this.whiteTotal = 0,
    this.blackCorrect = 0,
    this.blackTotal = 0,
  });

  final int whiteCorrect;
  final int whiteTotal;
  final int blackCorrect;
  final int blackTotal;
}

enum PuzzleType {
  blunders,
  mate,
  bestMove,
  empty1,
  empty2,
  empty3,
}

extension PuzzleTypeTitle on PuzzleType {
  String get title {
    switch (this) {
      case PuzzleType.blunders:
        return 'Задачи на зевки';
      case PuzzleType.mate:
        return 'Мат';
      case PuzzleType.bestMove:
        return 'Найти лучший ход';
      case PuzzleType.empty1:
      case PuzzleType.empty2:
      case PuzzleType.empty3:
        return '';
    }
  }

  IconData? get icon {
    switch (this) {
      case PuzzleType.blunders:
        return Icons.visibility_off;
      case PuzzleType.mate:
        return Icons.looks_one;
      case PuzzleType.bestMove:
        return Icons.flash_on;
      case PuzzleType.empty1:
      case PuzzleType.empty2:
      case PuzzleType.empty3:
        return null;
    }
  }

  String get description {
    switch (this) {
      case PuzzleType.blunders:
        return 'Задачи на зевки помогают находить грубые ошибки: подвисшие фигуры, потерю материала, незащищённые поля и тактические провалы.';
      case PuzzleType.mate:
        return 'Задачи на мат тренируют поиск форсированной атаки на короля. Позже здесь будут уровни: мат в 1, 2, 3, 4 и 5 ходов.';
      case PuzzleType.bestMove:
        return 'Режим поиска лучшего хода учит выбирать самый сильный ход в позиции с учётом тактики, плана и оценки движка.';
      case PuzzleType.empty1:
      case PuzzleType.empty2:
      case PuzzleType.empty3:
        return 'Выберите тип задачи, чтобы увидеть описание.';
    }
  }
}

class PuzzleTypesPanel extends StatefulWidget {
  const PuzzleTypesPanel({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
    this.onSettingsTap,
    this.onOpenTasksTap,
    this.onOpeningTrainerTap,
    this.openingTrainerActive = false,
    this.publishedTasks = const [],
    this.activeTaskIndex = -1,
    this.loadingTasks = false,
    this.onTaskSelected,
    this.onPreviousTask,
    this.onNextTask,
    this.activeAnalysisKey,
    this.showAnswer = false,
    this.activeAnalysisSide = 'white',
    this.analysisResults = const {},
    this.onAnalysisSideToggle,
    this.onAnalysisModeChanged,
    this.drawingEnabled = false,
    this.onToggleDrawing,
    this.onFinishAnalysis,
    this.onShowAnswerChanged,
    this.width = 340,
    this.height = 480,
  });

  final PuzzleType selectedType;
  final ValueChanged<PuzzleType> onTypeSelected;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onOpenTasksTap;
  final VoidCallback? onOpeningTrainerTap;
  final bool openingTrainerActive;

  final List<PuzzleTask> publishedTasks;
  final int activeTaskIndex;
  final bool loadingTasks;
  final ValueChanged<int>? onTaskSelected;
  final VoidCallback? onPreviousTask;
  final VoidCallback? onNextTask;

  final String? activeAnalysisKey;
  final bool showAnswer;
  final String activeAnalysisSide;
  final Map<String, PuzzleAnalysisResult> analysisResults;
  final VoidCallback? onAnalysisSideToggle;
  final ValueChanged<String?>? onAnalysisModeChanged;
  final bool drawingEnabled;
  final VoidCallback? onToggleDrawing;
  final VoidCallback? onFinishAnalysis;
  final ValueChanged<bool>? onShowAnswerChanged;

  final double width;
  final double height;

  @override
  State<PuzzleTypesPanel> createState() => _PuzzleTypesPanelState();
}

/// Единый блок кнопок «Композиции / Тренажеры».
///
/// Он используется и в панели «Задачи», и в режиме ученика. Поэтому обе
/// панели всегда запускают одну и ту же логику, а не две расходящиеся копии.
class PuzzleTrainingButtons extends StatelessWidget {
  const PuzzleTrainingButtons({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
    this.onOpeningTrainerTap,
    this.openingTrainerActive = false,
    this.compositionsTitle = 'Композиции',
    this.trainerTitle = 'Тренажеры',
    this.onAction,
  });

  final PuzzleType selectedType;
  final ValueChanged<PuzzleType> onTypeSelected;
  final VoidCallback? onOpeningTrainerTap;
  final bool openingTrainerActive;
  final String compositionsTitle;
  final String trainerTitle;

  /// Служебное событие для будущей статистики ученика.
  /// key — стабильный машинный ключ, title — видимое название.
  final void Function(String key, String title)? onAction;

  void _run(
    String key,
    String title,
    VoidCallback action,
  ) {
    onAction?.call(key, title);
    action();
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  compositionsTitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.panelTitle,
                ),
                const SizedBox(height: 8),
                _PuzzleTypeButton(
                  title: PuzzleType.blunders.title,
                  icon: PuzzleType.blunders.icon,
                  selected: !openingTrainerActive &&
                      selectedType == PuzzleType.blunders,
                  enabled: true,
                  onTap: () => _run(
                    'composition_blunders',
                    PuzzleType.blunders.title,
                    () => onTypeSelected(PuzzleType.blunders),
                  ),
                ),
                const SizedBox(height: 8),
                _PuzzleTypeButton(
                  title: PuzzleType.bestMove.title,
                  icon: PuzzleType.bestMove.icon,
                  selected: !openingTrainerActive &&
                      selectedType == PuzzleType.bestMove,
                  enabled: true,
                  onTap: () => _run(
                    'composition_best_move',
                    PuzzleType.bestMove.title,
                    () => onTypeSelected(PuzzleType.bestMove),
                  ),
                ),
                const SizedBox(height: 8),
                _PuzzleTypeButton(
                  title: PuzzleType.mate.title,
                  icon: PuzzleType.mate.icon,
                  selected:
                      !openingTrainerActive && selectedType == PuzzleType.mate,
                  enabled: true,
                  onTap: () => _run(
                    'composition_mate',
                    PuzzleType.mate.title,
                    () => onTypeSelected(PuzzleType.mate),
                  ),
                ),
                const SizedBox(height: 8),
                _PuzzleTypeButton(
                  title: 'Еще',
                  icon: null,
                  selected: false,
                  enabled: true,
                  onTap: () => _run(
                    'composition_more',
                    'Еще композиции',
                    () {},
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(
            width: 25,
            thickness: 1,
            color: AppColors.borderSoft,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  trainerTitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.panelTitle,
                ),
                const SizedBox(height: 8),
                _PuzzleTypeButton(
                  title: 'Антизевковый',
                  icon: null,
                  selected: false,
                  enabled: true,
                  onTap: () => _run(
                    'trainer_anti_blunder',
                    'Антизевковый',
                    () {},
                  ),
                ),
                const SizedBox(height: 8),
                _PuzzleTypeButton(
                  title: 'Дебютный',
                  icon: Icons.account_tree_outlined,
                  selected: openingTrainerActive,
                  enabled: onOpeningTrainerTap != null,
                  onTap: () => _run(
                    'trainer_opening',
                    'Дебютный',
                    onOpeningTrainerTap ?? () {},
                  ),
                ),
                const SizedBox(height: 8),
                _PuzzleTypeButton(
                  title: 'Эндшпильный',
                  icon: null,
                  selected: false,
                  enabled: true,
                  onTap: () => _run(
                    'trainer_endgame',
                    'Эндшпильный',
                    () {},
                  ),
                ),
                const SizedBox(height: 8),
                _PuzzleTypeButton(
                  title: 'Еще',
                  icon: null,
                  selected: false,
                  enabled: true,
                  onTap: () => _run(
                    'trainer_more',
                    'Еще тренажеры',
                    () {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PuzzleTypesPanelState extends State<PuzzleTypesPanel> {
  String? _activeAnalysisKey;
  bool _showAnswer = false;
  bool _finished = false;
  late String _activeAnalysisSide;

  final TextEditingController _statsStudentCtl = TextEditingController();
  final TextEditingController _statsReviewerCtl = TextEditingController();
  final TextEditingController _statsPeriodCtl = TextEditingController();
  int _activeStatsTab = 0;

  static const List<_AnalysisButtonData> _analysisButtons = [
    _AnalysisButtonData(
      keyName: 'threat',
      title: 'Угроза',
      color: Color(0xFFFF2D2D),
    ),
    _AnalysisButtonData(
      keyName: 'pin',
      title: 'Связка',
      color: Color(0xFF6A35FF),
    ),
    _AnalysisButtonData(
      keyName: 'xray',
      title: 'Рентген',
      color: Color(0xFFFF00C8),
    ),
    _AnalysisButtonData(
      keyName: 'weakness',
      title: 'Слабость',
      color: Color(0xFF4CFF2E),
      circle: true,
    ),
    _AnalysisButtonData(
      keyName: 'r1',
      title: 'P1',
      color: Color(0xFFFFB07A),
    ),
    _AnalysisButtonData(
      keyName: 'r2',
      title: 'P2',
      color: Color(0xFF0057FF),
      circle: true,
    ),
    _AnalysisButtonData(
      keyName: 'r3',
      title: 'P3',
      color: Color(0xFF40F7F7),
    ),
    _AnalysisButtonData(
      keyName: 'r4',
      title: 'P4',
      color: Color(0xFFFF5F93),
      circle: true,
    ),
  ];

  PuzzleTask? get _activeTask {
    if (widget.activeTaskIndex < 0 ||
        widget.activeTaskIndex >= widget.publishedTasks.length) {
      return null;
    }
    return widget.publishedTasks[widget.activeTaskIndex];
  }

  @override
  void initState() {
    super.initState();
    _activeAnalysisKey = widget.activeAnalysisKey;
    _showAnswer = widget.showAnswer;
    _activeAnalysisSide = widget.activeAnalysisSide;
  }

  @override
  void didUpdateWidget(covariant PuzzleTypesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeTaskIndex != widget.activeTaskIndex ||
        oldWidget.selectedType != widget.selectedType) {
      _activeAnalysisKey = widget.activeAnalysisKey;
      _showAnswer = widget.showAnswer;
      _activeAnalysisSide = widget.activeAnalysisSide;
      _finished = false;
      return;
    }
    if (oldWidget.activeAnalysisKey != widget.activeAnalysisKey) {
      _activeAnalysisKey = widget.activeAnalysisKey;
    }
    if (oldWidget.showAnswer != widget.showAnswer) {
      _showAnswer = widget.showAnswer;
    }
    if (oldWidget.activeAnalysisSide != widget.activeAnalysisSide) {
      _activeAnalysisSide = widget.activeAnalysisSide;
    }
  }

  void _toggleAnalysisMode(String keyName) {
    final nextKey = _activeAnalysisKey == keyName ? null : keyName;

    setState(() {
      _activeAnalysisKey = nextKey;
      _showAnswer = false;
    });

    // ВАЖНО: в main.dart нужно передавать именно keyName, а не nextKey.
    // Если передать null при повторном нажатии, main.dart просто выключит
    // режим рисования, но не поймёт, какой слой нужно скрыть.
    // Поэтому повторное нажатие на ту же кнопку работает так:
    // 1) локально кнопка становится неактивной;
    // 2) main.dart получает keyName;
    // 3) main.dart скрывает слой этого типа и выключает режим рисования;
    // 4) фигуры снова можно двигать на доске.
    widget.onShowAnswerChanged?.call(false);
    widget.onAnalysisModeChanged?.call(keyName);
  }

  void _toggleSide() {
    setState(() {
      _activeAnalysisSide = _activeAnalysisSide == 'white' ? 'black' : 'white';
      _activeAnalysisKey = null;
      _showAnswer = false;
    });
    widget.onAnalysisSideToggle?.call();
    widget.onAnalysisModeChanged?.call(null);
    widget.onShowAnswerChanged?.call(false);
  }

  void _finishTask() {
    setState(() {
      _finished = true;
      _activeAnalysisKey = null;
      _showAnswer = false;
    });
    widget.onFinishAnalysis?.call();
    widget.onShowAnswerChanged?.call(false);
  }

  void _toggleAnswer() {
    final nextShowAnswer = !_showAnswer;
    setState(() {
      _showAnswer = nextShowAnswer;
      _activeAnalysisKey = null;
    });

    widget.onShowAnswerChanged?.call(nextShowAnswer);
    widget.onAnalysisModeChanged?.call(null);
  }

  @override
  void dispose() {
    _statsStudentCtl.dispose();
    _statsReviewerCtl.dispose();
    _statsPeriodCtl.dispose();
    super.dispose();
  }

  void _openExpandedStatisticsWindow() {
    var localActiveTab = _activeStatsTab;

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть статистику',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, _, __) {
        final screen = MediaQuery.of(dialogContext).size;
        final width = screen.width < 1200 ? screen.width - 80 : 760.0;
        final height = screen.height < 760 ? screen.height - 170 : 500.0;
        final left = (screen.width - width) / 2;
        final top = screen.height < 760 ? 92.0 : 150.0;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: Material(
                    color: Colors.transparent,
                    child: _ExpandedStatisticsWindow(
                      participantController: _statsStudentCtl,
                      reviewerController: _statsReviewerCtl,
                      periodController: _statsPeriodCtl,
                      activeTab: localActiveTab,
                      onTabChanged: (value) {
                        setDialogState(() => localActiveTab = value);
                        setState(() => _activeStatsTab = value);
                      },
                      onClose: () => Navigator.of(dialogContext).pop(),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTask = _activeTask;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: DecoratedBox(
        decoration: AppDecorations.panel(),
        child: Padding(
          padding: AppSpacing.panel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: MakeChessLocalizedText(
                      'Задачи',
                      style: AppTextStyles.panelTitle,
                    ),
                  ),
                  if (widget.onOpenTasksTap != null) ...[
                    SizedBox(
                      height: 34,
                      child: _PanelNeoButton(
                        text: 'Открыть',
                        icon: Icons.folder_open,
                        onTap: widget.onOpenTasksTap,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (widget.onSettingsTap != null)
                    SizedBox(
                      height: 34,
                      child: _PanelNeoButton(
                        text: 'Настройка',
                        icon: Icons.settings,
                        onTap: widget.onSettingsTap,
                        compact: true,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              PuzzleTrainingButtons(
                selectedType: widget.selectedType,
                onTypeSelected: widget.onTypeSelected,
                onOpeningTrainerTap: widget.onOpeningTrainerTap,
                openingTrainerActive: widget.openingTrainerActive,
              ),
              const SizedBox(height: 10),
              Text(
                widget.selectedType.title.isEmpty
                    ? 'Задачи'
                    : widget.selectedType.title,
                style: AppTextStyles.panelTitle,
              ),
              const SizedBox(height: 6),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard.withOpacity(0.35),
                          borderRadius: AppRadius.r14,
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: SizedBox(
                          height: 82,
                          child: widget.loadingTasks
                              ? const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : widget.publishedTasks.isEmpty
                                  ? MakeChessLocalizedText(
                                      'Пока нет опубликованных задач этого типа.',
                                      style: AppTextStyles.muted,
                                    )
                                  : ListView.separated(
                                      padding: EdgeInsets.zero,
                                      itemCount: widget.publishedTasks.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 6),
                                      itemBuilder: (context, index) {
                                        final task =
                                            widget.publishedTasks[index];
                                        return _PublishedTaskTile(
                                          task: task,
                                          selected:
                                              index == widget.activeTaskIndex,
                                          onTap: () => widget.onTaskSelected
                                              ?.call(index),
                                        );
                                      },
                                    ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: _PanelNeoButton(
                                text: 'Назад',
                                icon: Icons.arrow_back,
                                onTap: widget.publishedTasks.isEmpty
                                    ? null
                                    : widget.onPreviousTask,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: _PanelNeoButton(
                                text: 'Следующая',
                                icon: Icons.arrow_forward,
                                onTap: widget.publishedTasks.isEmpty
                                    ? null
                                    : widget.onNextTask,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _AnalysisBlock(
                        activeTask: activeTask,
                        analysisButtons: _analysisButtons,
                        activeAnalysisKey: _activeAnalysisKey,
                        showAnswer: _showAnswer,
                        activeAnalysisSide: _activeAnalysisSide,
                        analysisResults: widget.analysisResults,
                        finished: _finished,
                        onAnalysisTap: _toggleAnalysisMode,
                        drawingEnabled: widget.drawingEnabled,
                        onToggleDrawing: widget.onToggleDrawing ?? () {},
                        onSideTap: _toggleSide,
                        onFinish: _finishTask,
                        onShowAnswer: _toggleAnswer,
                      ),
                      const SizedBox(height: 8),
                      _StatisticsBlock(
                        participantController: _statsStudentCtl,
                        reviewerController: _statsReviewerCtl,
                        periodController: _statsPeriodCtl,
                        activeTab: _activeStatsTab,
                        onTabChanged: (value) {
                          setState(() => _activeStatsTab = value);
                        },
                        onExpand: _openExpandedStatisticsWindow,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatisticsBlock extends StatelessWidget {
  const _StatisticsBlock({
    required this.participantController,
    required this.reviewerController,
    required this.periodController,
    required this.activeTab,
    required this.onTabChanged,
    required this.onExpand,
  });

  final TextEditingController participantController;
  final TextEditingController reviewerController;
  final TextEditingController periodController;
  final int activeTab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onExpand;

  Widget _buildTabs() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 38,
            child: _StatisticsTabButton(
              text: 'F1',
              color: const Color(0xFF39D7FF),
              active: activeTab == 0,
              onTap: () => onTabChanged(0),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: SizedBox(
            height: 38,
            child: _StatisticsTabButton(
              text: 'F2',
              color: const Color(0xFFFF70F0),
              active: activeTab == 1,
              onTap: () => onTabChanged(1),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: SizedBox(
            height: 38,
            child: _StatisticsTabButton(
              text: 'F3',
              color: const Color(0xFF5DFF42),
              active: activeTab == 2,
              onTap: () => onTabChanged(2),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: SizedBox(
            height: 38,
            child: _StatisticsChartButton(
              active: activeTab == 3,
              onTap: () => onTabChanged(3),
            ),
          ),
        ),
        const SizedBox(width: 5),
        SizedBox(
          width: 34,
          height: 38,
          child: _StatisticsExpandButton(onTap: onExpand),
        ),
      ],
    );
  }

  Widget _buildFields() {
    return Column(
      children: [
        _StatisticsTextField(
          label: 'Участник',
          controller: participantController,
        ),
        const SizedBox(height: 7),
        _StatisticsTextField(
          label: 'Проверяющий',
          controller: reviewerController,
        ),
        const SizedBox(height: 7),
        _StatisticsTextField(
          label: 'Период',
          controller: periodController,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        borderRadius: AppRadius.r12,
        border: Border.all(color: AppColors.borderSoft),
      ),
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MakeChessLocalizedText('Статистика', style: AppTextStyles.panelTitle),
                const SizedBox(height: 7),
                _buildTabs(),
                const SizedBox(height: 8),
                _buildFields(),
                const SizedBox(height: 8),
                _StatisticsResultArea(activeTab: activeTab),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: MakeChessLocalizedText(
                      'Статистика',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.panelTitle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 222,
                    child: _buildTabs(),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 148,
                    child: _buildFields(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatisticsResultArea(activeTab: activeTab),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExpandedStatisticsWindow extends StatelessWidget {
  const _ExpandedStatisticsWindow({
    required this.participantController,
    required this.reviewerController,
    required this.periodController,
    required this.activeTab,
    required this.onTabChanged,
    required this.onClose,
  });

  final TextEditingController participantController;
  final TextEditingController reviewerController;
  final TextEditingController periodController;
  final int activeTab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppDecorations.panel().copyWith(
        boxShadow: const [
          BoxShadow(
            color: Color(0xAA000000),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.r16,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: MakeChessLocalizedText(
                      'Статистика',
                      style: AppTextStyles.panelTitle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 128,
                    child: _StatisticsTextField(
                      label: 'Участник',
                      controller: participantController,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 150,
                    child: _StatisticsTextField(
                      label: 'Проверяющий',
                      controller: reviewerController,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 118,
                    child: _StatisticsTextField(
                      label: 'Период',
                      controller: periodController,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 42,
                    height: 38,
                    child: _StatisticsTabButton(
                      text: 'F1',
                      color: const Color(0xFF39D7FF),
                      active: activeTab == 0,
                      onTap: () => onTabChanged(0),
                    ),
                  ),
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 42,
                    height: 38,
                    child: _StatisticsTabButton(
                      text: 'F2',
                      color: const Color(0xFFFF70F0),
                      active: activeTab == 1,
                      onTap: () => onTabChanged(1),
                    ),
                  ),
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 42,
                    height: 38,
                    child: _StatisticsTabButton(
                      text: 'F3',
                      color: const Color(0xFF5DFF42),
                      active: activeTab == 2,
                      onTap: () => onTabChanged(2),
                    ),
                  ),
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 42,
                    height: 38,
                    child: _StatisticsChartButton(
                      active: activeTab == 3,
                      onTap: () => onTabChanged(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: MakeChessLocalization.phrase('Закрыть'),
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: AppColors.text),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _StatisticsLargeResultArea(activeTab: activeTab),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatisticsLargeResultArea extends StatelessWidget {
  const _StatisticsLargeResultArea({required this.activeTab});

  final int activeTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.35),
        borderRadius: AppRadius.r12,
        border: Border.all(color: AppColors.borderSoft, width: 1.4),
      ),
      child: activeTab == 3
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: _LargeSoprChart(),
            )
          : Center(
              child: Text(
                _expandedPlaceholderText(activeTab),
                textAlign: TextAlign.center,
                style: AppTextStyles.panelTitle.copyWith(
                  color: AppColors.textDim,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );
  }

  static String _expandedPlaceholderText(int index) {
    switch (index) {
      case 0:
        return 'Данные F1';
      case 1:
        return 'Данные F2';
      case 2:
        return 'Данные F3';
      case 3:
        return 'График СОПР';
      default:
        return 'Данные';
    }
  }
}

class _LargeSoprChart extends StatelessWidget {
  const _LargeSoprChart();

  static const List<_SoprPoint> _points = [
    _SoprPoint('01.05', 42),
    _SoprPoint('05.05', 48),
    _SoprPoint('10.05', 53),
    _SoprPoint('15.05', 57),
    _SoprPoint('20.05', 64),
    _SoprPoint('25.05', 68),
    _SoprPoint('30.05', 74),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: MakeChessLocalizedText(
                'Средний относительный показатель решений',
                style: AppTextStyles.panelTitle,
              ),
            ),
            MakeChessLocalizedText(
              'среднее по 10 последним задачам',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textDim,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: CustomPaint(
            painter: _SoprChartPainter(points: _points),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _StatisticsResultArea extends StatelessWidget {
  const _StatisticsResultArea({required this.activeTab});

  final int activeTab;

  static const List<_SoprPoint> _demoPoints = [
    _SoprPoint('01.05', 42),
    _SoprPoint('05.05', 48),
    _SoprPoint('10.05', 53),
    _SoprPoint('15.05', 57),
    _SoprPoint('20.05', 64),
    _SoprPoint('25.05', 68),
    _SoprPoint('30.05', 74),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.35),
        borderRadius: AppRadius.r8,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: activeTab == 3 ? _buildChart() : _buildPlaceholder(activeTab),
    );
  }

  Widget _buildPlaceholder(int index) {
    return Center(
      child: Text(
        _placeholderText(index),
        textAlign: TextAlign.center,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textDim,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildChart() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: MakeChessLocalizedText(
                  'СОПР за период',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              MakeChessLocalizedText(
                'среднее по 10 задачам',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textDim,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Expanded(
            child: CustomPaint(
              painter: _SoprChartPainter(points: _demoPoints),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  String _placeholderText(int index) {
    switch (index) {
      case 0:
        return 'Данные F1';
      case 1:
        return 'Данные F2';
      case 2:
        return 'Данные F3';
      default:
        return 'Данные';
    }
  }
}

class _SoprPoint {
  const _SoprPoint(this.date, this.value);

  final String date;
  final double value;
}

class _SoprChartPainter extends CustomPainter {
  const _SoprChartPainter({required this.points});

  final List<_SoprPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return;

    const leftPad = 28.0;
    const rightPad = 6.0;
    const topPad = 6.0;
    const bottomPad = 18.0;

    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;
    if (chartWidth <= 0 || chartHeight <= 0) return;

    final gridPaint = Paint()
      ..color = AppColors.borderSoft.withOpacity(0.75)
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = AppColors.textDim.withOpacity(0.9)
      ..strokeWidth = 1.2;

    final linePaint = Paint()
      ..color = const Color(0xFFFF006A)
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pointPaint = Paint()
      ..color = const Color(0xFF39D7FF)
      ..style = PaintingStyle.fill;

    final bgPointPaint = Paint()
      ..color = Colors.black.withOpacity(0.45)
      ..style = PaintingStyle.fill;

    final left = leftPad;
    final right = leftPad + chartWidth;
    final top = topPad;
    final bottom = topPad + chartHeight;

    for (final percent in [0, 25, 50, 75, 100]) {
      final y = bottom - chartHeight * (percent / 100.0);
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
      _drawText(
        canvas,
        '$percent',
        Offset(0, y - 6),
        AppColors.textDim,
        9,
        width: leftPad - 4,
        align: TextAlign.right,
      );
    }

    canvas.drawLine(Offset(left, top), Offset(left, bottom), axisPaint);
    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), axisPaint);

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = points.length == 1
          ? left + chartWidth / 2
          : left + chartWidth * (i / (points.length - 1));
      final value = p.value.clamp(0, 100).toDouble();
      final y = bottom - chartHeight * (value / 100.0);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = points.length == 1
          ? left + chartWidth / 2
          : left + chartWidth * (i / (points.length - 1));
      final value = p.value.clamp(0, 100).toDouble();
      final y = bottom - chartHeight * (value / 100.0);
      canvas.drawCircle(Offset(x, y), 4.1, bgPointPaint);
      canvas.drawCircle(Offset(x, y), 2.7, pointPaint);

      if (i == 0 || i == points.length - 1 || i == points.length ~/ 2) {
        _drawText(
          canvas,
          p.date,
          Offset(x - 20, bottom + 4),
          AppColors.textDim,
          9,
          width: 40,
          align: TextAlign.center,
        );
      }
    }

    _drawText(
      canvas,
      '%',
      const Offset(3, 0),
      AppColors.textDim,
      9,
      width: 20,
      align: TextAlign.left,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize, {
    required double width,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: width);

    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SoprChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _StatisticsTextField extends StatelessWidget {
  const _StatisticsTextField({
    required this.label,
    required this.controller,
  });

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 39,
      child: TextField(
        controller: controller,
        style: AppTextStyles.buttonCompact.copyWith(
          color: AppColors.text,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTextStyles.caption.copyWith(
            color: AppColors.textDim,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          isDense: true,
          filled: true,
          fillColor: Colors.black.withOpacity(0.40),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.r8,
            borderSide: const BorderSide(color: AppColors.borderSoft),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.r8,
            borderSide: const BorderSide(color: AppColors.accent),
          ),
        ),
      ),
    );
  }
}

class _StatisticsExpandButton extends StatefulWidget {
  const _StatisticsExpandButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_StatisticsExpandButton> createState() =>
      _StatisticsExpandButtonState();
}

class _StatisticsExpandButtonState extends State<_StatisticsExpandButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 34,
          decoration: AppDecorations.neoButton(
            active: _hover,
            pressed: _pressed,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.open_in_full,
            size: 21,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _StatisticsTabButton extends StatefulWidget {
  const _StatisticsTabButton({
    required this.text,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final String text;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_StatisticsTabButton> createState() => _StatisticsTabButtonState();
}

class _StatisticsTabButtonState extends State<_StatisticsTabButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 34,
          decoration: AppDecorations.neoButton(
            active: widget.active || _hover,
            pressed: _pressed,
          ).copyWith(
            border: widget.active
                ? Border.all(color: AppColors.accent, width: 1.2)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            widget.text,
            style: AppTextStyles.panelTitle.copyWith(
              color: widget.color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatisticsChartButton extends StatefulWidget {
  const _StatisticsChartButton({
    required this.active,
    required this.onTap,
  });

  final bool active;
  final VoidCallback onTap;

  @override
  State<_StatisticsChartButton> createState() => _StatisticsChartButtonState();
}

class _StatisticsChartButtonState extends State<_StatisticsChartButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 34,
          decoration: AppDecorations.neoButton(
            active: widget.active || _hover,
            pressed: _pressed,
          ).copyWith(
            border: widget.active
                ? Border.all(color: AppColors.accent, width: 1.2)
                : null,
          ),
          alignment: Alignment.center,
          child: CustomPaint(
            size: const Size(28, 24),
            painter: _MiniChartPainter(),
          ),
        ),
      ),
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF006A)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(2, size.height - 4)
      ..lineTo(size.width * 0.28, size.height * 0.25)
      ..lineTo(size.width * 0.52, size.height * 0.78)
      ..lineTo(size.width * 0.78, size.height * 0.22)
      ..lineTo(size.width - 2, size.height * 0.58);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AnalysisBlock extends StatelessWidget {
  const _AnalysisBlock({
    required this.activeTask,
    required this.analysisButtons,
    required this.activeAnalysisKey,
    required this.showAnswer,
    required this.activeAnalysisSide,
    required this.analysisResults,
    required this.finished,
    required this.onAnalysisTap,
    required this.drawingEnabled,
    required this.onToggleDrawing,
    required this.onSideTap,
    required this.onFinish,
    required this.onShowAnswer,
  });

  final PuzzleTask? activeTask;
  final List<_AnalysisButtonData> analysisButtons;
  final String? activeAnalysisKey;
  final bool showAnswer;
  final String activeAnalysisSide;
  final Map<String, PuzzleAnalysisResult> analysisResults;
  final bool finished;
  final ValueChanged<String> onAnalysisTap;
  final bool drawingEnabled;
  final VoidCallback onToggleDrawing;
  final VoidCallback onSideTap;
  final VoidCallback onFinish;
  final VoidCallback onShowAnswer;

  Widget _analysisButton(int index) {
    return Expanded(
      child: _AnalysisArrowButton(
        data: analysisButtons[index],
        active: activeAnalysisKey == analysisButtons[index].keyName,
        onTap: () => onAnalysisTap(analysisButtons[index].keyName),
      ),
    );
  }

  Widget _analysisGrid() {
    return Column(
      children: [
        Row(
          children: [
            _analysisButton(0),
            const SizedBox(width: 6),
            _analysisButton(1),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _analysisButton(2),
            const SizedBox(width: 6),
            _analysisButton(3),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _analysisButton(4),
            const SizedBox(width: 6),
            _analysisButton(5),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _analysisButton(6),
            const SizedBox(width: 6),
            _analysisButton(7),
          ],
        ),
      ],
    );
  }

  Widget _sideButton() {
    return _SmallActionButton(
      text: activeAnalysisSide == 'black'
          ? 'Чёрные\nБел/Черн'
          : 'Белые\nБел/Черн',
      onTap: onSideTap,
    );
  }

  Widget _installButton() {
    return _SmallActionButton(
      text: 'Установить',
      onTap: onToggleDrawing,
      active: drawingEnabled,
    );
  }

  Widget _finishButton() {
    return _SmallActionButton(
      text: 'Готово',
      onTap: onFinish,
    );
  }

  Widget _answerButton() {
    return _SmallActionButton(
      text: showAnswer ? 'Скрыть\nответ' : 'Показать\nответ',
      onTap: onShowAnswer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskTitle = activeTask == null
        ? 'Задача не выбрана'
        : '№${activeTask!.number} ${activeTask!.title}';
    final taskType = activeTask?.typeTitle ?? '-';

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        borderRadius: AppRadius.r12,
        border: Border.all(color: AppColors.borderSoft),
      ),
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 330;

          final analysisAndActions = compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _analysisGrid(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(height: 40, child: _installButton()),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: SizedBox(height: 40, child: _sideButton()),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: SizedBox(height: 40, child: _finishButton()),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: SizedBox(height: 40, child: _answerButton()),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _analysisGrid()),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 92,
                      child: Column(
                        children: [
                          SizedBox(height: 34, child: _installButton()),
                          const SizedBox(height: 6),
                          SizedBox(height: 34, child: _sideButton()),
                          const SizedBox(height: 6),
                          SizedBox(height: 34, child: _finishButton()),
                          const SizedBox(height: 6),
                          SizedBox(height: 34, child: _answerButton()),
                        ],
                      ),
                    ),
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      taskTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.buttonCompact,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      taskType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: AppTextStyles.buttonCompact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              analysisAndActions,
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: _StudentResultBox(
                      finished: finished,
                      results: analysisResults,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: _StudentTotalBox(
                      finished: finished,
                      results: analysisResults,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: AppDecorations.buttonGradient,
                        borderRadius: AppRadius.r8,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: MakeChessLocalizedText(
                          '0,0\nсек',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.buttonCompact,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StudentResultBox extends StatelessWidget {
  const _StudentResultBox({
    required this.finished,
    required this.results,
  });

  final bool finished;
  final Map<String, PuzzleAnalysisResult> results;

  String _line(String title, String key) {
    final r = results[key] ?? const PuzzleAnalysisResult();
    return '$title Б${r.whiteCorrect}/${r.whiteTotal} Ч${r.blackCorrect}/${r.blackTotal}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: AppRadius.r8,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: finished
          ? DefaultTextStyle(
              style: AppTextStyles.caption.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
                height: 1.15,
                fontSize: 11,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_line('Угроза', 'threat')),
                        Text(_line('Рентген', 'xray')),
                        Text(_line('P1', 'r1')),
                        Text(_line('P3', 'r3')),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_line('Связка', 'pin')),
                        Text(_line('Слабость', 'weakness')),
                        Text(_line('P2', 'r2')),
                        Text(_line('P4', 'r4')),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : MakeChessLocalizedText(
              'Результат появится после кнопки «Готово»',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

class _StudentTotalBox extends StatelessWidget {
  const _StudentTotalBox({
    required this.finished,
    required this.results,
  });

  final bool finished;
  final Map<String, PuzzleAnalysisResult> results;

  @override
  Widget build(BuildContext context) {
    var correct = 0;
    var total = 0;
    for (final r in results.values) {
      correct += r.whiteCorrect + r.blackCorrect;
      total += r.whiteTotal + r.blackTotal;
    }

    return Container(
      width: 66,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFFDFFFE6),
        borderRadius: AppRadius.r8,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Center(
        child: Text(
          finished ? '$correct/$total' : '-/-',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF188C43),
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ),
    );
  }
}

class _AnalysisButtonData {
  const _AnalysisButtonData({
    required this.keyName,
    required this.title,
    required this.color,
    this.circle = false,
  });

  final String keyName;
  final String title;
  final Color color;
  final bool circle;
}

class _AnalysisArrowButton extends StatelessWidget {
  const _AnalysisArrowButton({
    required this.data,
    required this.active,
    required this.onTap,
  });

  final _AnalysisButtonData data;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: AppDecorations.neoButton(active: active),
        child: Row(
          children: [
            Expanded(
              child: Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.buttonCompact,
              ),
            ),
            Icon(
              data.circle
                  ? Icons.radio_button_unchecked
                  : Icons.arrow_right_alt,
              color: data.color,
              size: data.circle ? 20 : 28,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAnalysisSlot extends StatelessWidget {
  const _EmptyAnalysisSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: AppDecorations.neoButton(enabled: false),
      child: const Center(
        child: Text('-', style: AppTextStyles.buttonCompact),
      ),
    );
  }
}

class _SmallActionButton extends StatefulWidget {
  const _SmallActionButton({
    required this.text,
    required this.onTap,
    this.active = false,
  });

  final String text;
  final VoidCallback onTap;
  final bool active;

  @override
  State<_SmallActionButton> createState() => _SmallActionButtonState();
}

class _SmallActionButtonState extends State<_SmallActionButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: AppDecorations.neoButton(
            active: widget.active || _hover,
            pressed: _pressed,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Center(
            child: MakeChessLocalizedText(
              widget.text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.buttonCompact,
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelNeoButton extends StatefulWidget {
  const _PanelNeoButton({
    required this.text,
    required this.icon,
    required this.onTap,
    this.compact = false,
  });

  final String text;
  final IconData icon;
  final VoidCallback? onTap;
  final bool compact;

  @override
  State<_PanelNeoButton> createState() => _PanelNeoButtonState();
}

class _PanelNeoButtonState extends State<_PanelNeoButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final color = enabled
        ? (_hover ? AppColors.accent : AppColors.text)
        : AppColors.text.withOpacity(0.32);

    return MouseRegion(
      onEnter: enabled ? (_) => setState(() => _hover = true) : null,
      onExit: enabled
          ? (_) => setState(() {
                _hover = false;
                _pressed = false;
              })
          : null,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: widget.compact ? 34 : 38,
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 10 : 12,
            vertical: 0,
          ),
          decoration: AppDecorations.neoButton(
            active: _hover && enabled,
            pressed: _pressed && enabled,
            enabled: enabled,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: widget.compact ? 15 : 16, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: MakeChessLocalizedText(
                  widget.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.buttonCompact.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublishedTaskTile extends StatelessWidget {
  const _PublishedTaskTile({
    required this.task,
    required this.selected,
    required this.onTap,
  });

  final PuzzleTask task;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = '№${task.number} ${task.title}';

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.r10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentGlowSoft
              : AppColors.surfaceSoft.withOpacity(0.35),
          borderRadius: AppRadius.r10,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.borderSoft,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.play_circle_fill : Icons.play_circle_outline,
              size: 18,
              color: selected ? AppColors.accent : AppColors.textDim,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.buttonCompact.copyWith(
                  color: selected ? AppColors.accent : AppColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PuzzleTypeButton extends StatefulWidget {
  const _PuzzleTypeButton({
    required this.title,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final IconData? icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_PuzzleTypeButton> createState() => _PuzzleTypeButtonState();
}

class _PuzzleTypeButtonState extends State<_PuzzleTypeButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && (widget.selected || _hover);
    final fgColor = !widget.enabled
        ? AppColors.text.withOpacity(0.18)
        : active
            ? AppColors.accent
            : AppColors.text;

    return MouseRegion(
      onEnter: widget.enabled ? (_) => setState(() => _hover = true) : null,
      onExit: widget.enabled
          ? (_) => setState(() {
                _hover = false;
                _pressed = false;
              })
          : null,
      child: GestureDetector(
        onTapDown:
            widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp:
            widget.enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel:
            widget.enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: AppDecorations.neoButton(
            active: active,
            pressed: _pressed && widget.enabled,
            enabled: widget.enabled,
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 17, color: fgColor),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: MakeChessLocalizedText(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button.copyWith(
                    color: fgColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
