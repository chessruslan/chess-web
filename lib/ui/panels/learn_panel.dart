import 'package:flutter/material.dart';

import '../app_style.dart';

/// Независимый результат анализа для панели «Учиться».
/// Этот тип специально не зависит от puzzle_types_panel.dart.
class LearningAnalysisResult {
  const LearningAnalysisResult({
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

enum LearningPanelRole {
  none,
  teacher,
  student,
}

/// Реальный зарегистрированный ученик из таблицы public.profiles.
class LearningStudent {
  const LearningStudent({
    required this.id,
    required this.nickname,
  });

  final String id;
  final String nickname;
}

class LearningPanel extends StatefulWidget {
  const LearningPanel({
    super.key,
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
    this.onRoleChanged,
    this.onLoadPosition,
    this.onToggleSharedMode,
    this.sharedModeEnabled = false,
    this.onToggleStudentEvaluation,
    this.studentEvaluationEnabled = false,
    this.role = LearningPanelRole.none,
    this.students = const [],
    this.selectedStudentId,
    this.selectedVideoStudentIds = const <String>{},
    this.confirmedStudentId,
    this.invitationStatus,
    this.onAddStudent,
    this.onStudentSelected,
    this.onVideoStudentToggled,
    this.onInviteStudentToGame,
    this.onInviteSelectedStudent,
    this.showAllBoards = false,
    this.onToggleBoardsView,
    this.onStudentDoubleTap,
    this.activeBoardStudentId,
    this.onlineStudentIds = const <String>{},
    this.connectedGameStudentIds = const <String>{},
    this.pendingGameStudentIds = const <String>{},
    this.onEndStudentGame,
    this.width = 340,
    this.height = 480,
  });

  final String? activeAnalysisKey;
  final bool showAnswer;
  final String activeAnalysisSide;
  final Map<String, LearningAnalysisResult> analysisResults;
  final VoidCallback? onAnalysisSideToggle;
  final ValueChanged<String?>? onAnalysisModeChanged;
  final bool drawingEnabled;
  final VoidCallback? onToggleDrawing;
  final VoidCallback? onFinishAnalysis;
  final ValueChanged<bool>? onShowAnswerChanged;

  final ValueChanged<LearningPanelRole>? onRoleChanged;
  final VoidCallback? onLoadPosition;
  final VoidCallback? onToggleSharedMode;
  final bool sharedModeEnabled;
  final VoidCallback? onToggleStudentEvaluation;
  final bool studentEvaluationEnabled;

  final LearningPanelRole role;
  final List<LearningStudent> students;

  /// Ученик, выделенный кликом в списке.
  final String? selectedStudentId;
  final Set<String> selectedVideoStudentIds;

  /// Ученик, выбор которого подтверждён кнопкой «Выбрать ученика».
  final String? confirmedStudentId;
  final String? invitationStatus;
  final Future<void> Function()? onAddStudent;
  final ValueChanged<String>? onStudentSelected;
  final ValueChanged<String>? onVideoStudentToggled;
  final Future<void> Function(LearningStudent student)? onInviteStudentToGame;
  final Future<void> Function()? onInviteSelectedStudent;

  /// false: одна крупная доска; true: сетка из восьми досок.
  final bool showAllBoards;
  final VoidCallback? onToggleBoardsView;
  final ValueChanged<String>? onStudentDoubleTap;
  final String? activeBoardStudentId;

  /// Ученики, которые сейчас вошли именно через «Войти как ученик».
  final Set<String> onlineStudentIds;

  /// Ученики, с которыми уже установлена учебная игровая сессия.
  final Set<String> connectedGameStudentIds;

  /// Ученики, которым приглашение уже отправлено и ожидается ответ.
  final Set<String> pendingGameStudentIds;

  final Future<void> Function(LearningStudent student)? onEndStudentGame;

  final double width;
  final double height;

  @override
  State<LearningPanel> createState() => _LearningPanelState();
}

class _LearningPanelState extends State<LearningPanel> {
  LearningPanelRole _role = LearningPanelRole.none;
  String? _activeAnalysisKey;
  bool _showAnswer = false;
  bool _finished = false;
  late String _activeAnalysisSide;

  final TextEditingController _statsStudentCtl = TextEditingController();
  final TextEditingController _statsReviewerCtl = TextEditingController();
  final TextEditingController _statsPeriodCtl = TextEditingController();
  final ScrollController _studentsScrollCtl = ScrollController();
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

  @override
  void initState() {
    super.initState();
    _role = widget.role;
    _activeAnalysisKey = widget.activeAnalysisKey;
    _showAnswer = widget.showAnswer;
    _activeAnalysisSide = widget.activeAnalysisSide;
    _syncSelectedStudentToStatistics();
  }

  @override
  void didUpdateWidget(covariant LearningPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeAnalysisKey != widget.activeAnalysisKey) {
      _activeAnalysisKey = widget.activeAnalysisKey;
    }
    if (oldWidget.showAnswer != widget.showAnswer) {
      _showAnswer = widget.showAnswer;
    }
    if (oldWidget.activeAnalysisSide != widget.activeAnalysisSide) {
      _activeAnalysisSide = widget.activeAnalysisSide;
    }
    if (oldWidget.role != widget.role) {
      _role = widget.role;
      _finished = false;
    }
    if (oldWidget.selectedStudentId != widget.selectedStudentId ||
        oldWidget.students != widget.students) {
      _syncSelectedStudentToStatistics();
    }
  }

  void _syncSelectedStudentToStatistics() {
    final selectedId = widget.selectedStudentId;
    if (selectedId == null || selectedId.isEmpty) return;
    for (final student in widget.students) {
      if (student.id == selectedId) {
        _statsStudentCtl.text = student.nickname;
        return;
      }
    }
  }

  @override
  void dispose() {
    _statsStudentCtl.dispose();
    _statsReviewerCtl.dispose();
    _statsPeriodCtl.dispose();
    _studentsScrollCtl.dispose();
    super.dispose();
  }

  void _selectRole(LearningPanelRole role) {
    setState(() {
      _role = role;
      _activeAnalysisKey = null;
      _showAnswer = false;
      _finished = false;
    });
    widget.onRoleChanged?.call(role);
    widget.onAnalysisModeChanged?.call(null);
    widget.onShowAnswerChanged?.call(false);
  }

  void _toggleAnalysisMode(String keyName) {
    final nextKey = _activeAnalysisKey == keyName ? null : keyName;
    setState(() {
      _activeAnalysisKey = nextKey;
      _showAnswer = false;
    });
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

  void _finishAnalysis() {
    setState(() {
      _finished = true;
      _activeAnalysisKey = null;
      _showAnswer = false;
    });
    widget.onFinishAnalysis?.call();
    widget.onShowAnswerChanged?.call(false);
  }

  void _toggleAnswer() {
    final value = !_showAnswer;
    setState(() {
      _showAnswer = value;
      _activeAnalysisKey = null;
    });
    widget.onShowAnswerChanged?.call(value);
    widget.onAnalysisModeChanged?.call(null);
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

  Widget _roleButton({
    required LearningPanelRole role,
    required String text,
    required IconData icon,
  }) {
    return _PanelNeoButton(
      text: text,
      icon: icon,
      compact: true,
      active: _role == role,
      onTap: () => _selectRole(role),
    );
  }

  void _selectStudent(String studentId) {
    widget.onStudentSelected?.call(studentId);
  }

  Widget _studentPicker() {
    final selectedId = widget.selectedStudentId;
    final hasSelection = selectedId != null &&
        selectedId.isNotEmpty &&
        widget.students.any((student) => student.id == selectedId);
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        borderRadius: AppRadius.r12,
        border: Border.all(color: AppColors.borderSoft),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Для видео выбрано: ${widget.selectedVideoStudentIds.length}/8',
            style: AppTextStyles.caption.copyWith(
              color: widget.selectedVideoStudentIds.isEmpty
                  ? AppColors.textDim
                  : AppColors.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: _PanelNeoButton(
                    text: 'Выбрать ученика',
                    icon: Icons.person_add_alt_1,
                    compact: true,
                    onTap: () {
                      widget.onAddStudent?.call();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: _PanelNeoButton(
                    text: widget.showAllBoards
                        ? 'Показать одну доску'
                        : 'Все доски',
                    icon: widget.showAllBoards
                        ? Icons.crop_square
                        : Icons.grid_view_rounded,
                    compact: true,
                    active: widget.showAllBoards,
                    onTap: widget.onToggleBoardsView,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 164,
            child: widget.students.isEmpty
                ? Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard.withOpacity(0.35),
                      borderRadius: AppRadius.r10,
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Text(
                      'Нажмите «Выбрать ученика» и выберите '
                      'зарегистрированного игрока',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.muted,
                    ),
                  )
                : Scrollbar(
                    controller: _studentsScrollCtl,
                    thumbVisibility: widget.students.length > 3,
                    child: ListView.builder(
                      controller: _studentsScrollCtl,
                      padding: EdgeInsets.zero,
                      itemExtent: 52,
                      itemCount: widget.students.length,
                      itemBuilder: (context, index) {
                        final student = widget.students[index];
                        final selected = student.id == selectedId;
                        final selectedForVideo =
                            widget.selectedVideoStudentIds.contains(student.id);
                        final gameConnected =
                            widget.connectedGameStudentIds.contains(student.id);
                        final gamePending =
                            widget.pendingGameStudentIds.contains(student.id);

                        return Padding(
                          padding: const EdgeInsets.only(right: 8, bottom: 4),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _selectStudent(student.id);
                              widget.onVideoStudentToggled?.call(student.id);
                            },
                            onDoubleTap: () {
                              _selectStudent(student.id);
                              widget.onStudentDoubleTap?.call(student.id);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: selected ||
                                        widget.activeBoardStudentId ==
                                            student.id
                                    ? AppColors.accentGlowSoft
                                    : AppColors.surfaceCard.withOpacity(0.35),
                                borderRadius: AppRadius.r8,
                                border: Border.all(
                                  color: selected
                                      ? AppColors.borderBright
                                      : AppColors.borderSoft,
                                  width: selected ? 1.2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selectedForVideo
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    size: 18,
                                    color: selectedForVideo
                                        ? AppColors.accent
                                        : AppColors.textDim,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      student.nickname,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.body.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    height: 30,
                                    child: FilledButton(
                                      onPressed: gameConnected
                                          ? (widget.onEndStudentGame == null
                                              ? null
                                              : () => widget
                                                  .onEndStudentGame!(student))
                                          : (gamePending ||
                                                  widget.onInviteStudentToGame ==
                                                      null
                                              ? null
                                              : () =>
                                                  widget.onInviteStudentToGame!(
                                                      student)),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: Text(
                                        gameConnected
                                            ? 'Закончить'
                                            : (gamePending
                                                ? 'Ждём…'
                                                : 'Играть'),
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
                  ),
          ),
          if (hasSelection) ...[
            const SizedBox(height: 7),
            SizedBox(
              height: 34,
              child: _PanelNeoButton(
                text: widget.selectedVideoStudentIds.contains(selectedId)
                    ? 'Убрать из видеовызова'
                    : 'Добавить в видеовызов',
                icon: Icons.videocam,
                compact: true,
                active: widget.selectedVideoStudentIds.contains(selectedId),
                onTap: () => widget.onVideoStudentToggled?.call(selectedId),
              ),
            ),
          ],
          if ((widget.invitationStatus ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              widget.invitationStatus!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _teacherControls() {
    final selectedId = widget.selectedStudentId;
    final hasSelectedStudent = selectedId != null &&
        selectedId.isNotEmpty &&
        widget.students.any((student) => student.id == selectedId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _studentPicker(),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.22),
            borderRadius: AppRadius.r12,
            border: Border.all(color: AppColors.borderSoft),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: _PanelNeoButton(
                        text: 'Загрузить позицию',
                        icon: Icons.upload_file,
                        compact: true,
                        onTap: widget.onLoadPosition,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: _PanelNeoButton(
                        text: 'Совместный режим',
                        icon: Icons.group_work,
                        compact: true,
                        active: widget.sharedModeEnabled,
                        onTap: widget.onToggleSharedMode,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 42,
                child: _PanelNeoButton(
                  text: widget.studentEvaluationEnabled
                      ? 'Оценка позиции ученику включена'
                      : 'Включить ученику оценку позиции',
                  icon: Icons.analytics,
                  active: widget.studentEvaluationEnabled,
                  onTap: hasSelectedStudent
                      ? widget.onToggleStudentEvaluation
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
              Text('Учиться', style: AppTextStyles.panelTitle),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: _roleButton(
                        role: LearningPanelRole.teacher,
                        text: 'Войти как учитель',
                        icon: Icons.school,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: _roleButton(
                        role: LearningPanelRole.student,
                        text: 'Войти как ученик',
                        icon: Icons.person,
                      ),
                    ),
                  ),
                ],
              ),
              if (_role == LearningPanelRole.teacher) ...[
                const SizedBox(height: 10),
                _teacherControls(),
              ],
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AnalysisBlock(
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
                        onFinish: _finishAnalysis,
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
                Text('Статистика', style: AppTextStyles.panelTitle),
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
                    child: Text(
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
                    child: Text(
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
                    tooltip: 'Закрыть',
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
              child: Text(
                'Средний относительный показатель решений',
                style: AppTextStyles.panelTitle,
              ),
            ),
            Text(
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
                child: Text(
                  'СОПР за период',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
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

  final List<_AnalysisButtonData> analysisButtons;
  final String? activeAnalysisKey;
  final bool showAnswer;
  final String activeAnalysisSide;
  final Map<String, LearningAnalysisResult> analysisResults;
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
                        child: Text(
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
  final Map<String, LearningAnalysisResult> results;

  String _line(String title, String key) {
    final r = results[key] ?? const LearningAnalysisResult();
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
          : Text(
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
  final Map<String, LearningAnalysisResult> results;

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
            child: Text(
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
    this.active = false,
  });

  final String text;
  final IconData icon;
  final VoidCallback? onTap;
  final bool compact;
  final bool active;

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
        ? ((widget.active || _hover) ? AppColors.accent : AppColors.text)
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
            active: (widget.active || _hover) && enabled,
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
                child: Text(
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
