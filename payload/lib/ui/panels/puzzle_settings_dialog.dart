// MAKECHESS_REMAINING_UI_V6_20260807
// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
// MAKECHESS_BIG_LOCALIZATION_STAGE_V4_20260807
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_style.dart';
import 'puzzle_file_saver.dart';
import 'puzzle_task.dart';
import '../../localization/makechess_localization.dart';

class PuzzleSettingsDialog extends StatefulWidget {
  const PuzzleSettingsDialog({
    super.key,
    required this.selectedTypeTitle,
    required this.taskTitle,
    required this.taskNumber,
    required this.taskTypeTitle,
    required this.currentFen,
    required this.startFen,
    required this.savedLines,
    required this.currentLine,
    required this.isRecordingLine,
    required this.isPublished,
    required this.activeAnalysisKey,
    required this.showAnswer,
    required this.analysisCounts,
    required this.activeAnalysisSide,
    required this.onAnalysisSideToggle,
    required this.buildPuzzle,
    required this.onTaskTitleChanged,
    required this.onTaskNumberChanged,
    required this.onTaskTypeTitleChanged,
    required this.onSetInitialPosition,
    required this.onStartRecordingLine,
    required this.onFinishRecordingLine,
    required this.onClearDraft,
    required this.onNewTask,
    required this.onPublished,
    required this.onAnalysisModeChanged,
    required this.drawingEnabled,
    required this.onToggleDrawing,
    required this.onFinishAnalysis,
    required this.onShowAnswerChanged,
    required this.onClearAnalysisElements,
    required this.onClose,
  });

  final String selectedTypeTitle;
  final String taskTitle;
  final int taskNumber;
  final String taskTypeTitle;
  final String currentFen;
  final String? startFen;
  final List<List<String>> savedLines;
  final List<String> currentLine;
  final bool isRecordingLine;
  final bool isPublished;
  final String? activeAnalysisKey;
  final bool showAnswer;
  final Map<String, Map<String, int>> analysisCounts;
  final String activeAnalysisSide;
  final VoidCallback onAnalysisSideToggle;

  final PuzzleTask Function({
    required String title,
    required int number,
    required String typeTitle,
  }) buildPuzzle;

  final ValueChanged<String> onTaskTitleChanged;
  final ValueChanged<int> onTaskNumberChanged;
  final ValueChanged<String> onTaskTypeTitleChanged;
  final VoidCallback onSetInitialPosition;
  final VoidCallback onStartRecordingLine;
  final VoidCallback onFinishRecordingLine;
  final VoidCallback onClearDraft;
  final VoidCallback onNewTask;
  final VoidCallback onPublished;
  final ValueChanged<String?> onAnalysisModeChanged;
  final bool drawingEnabled;
  final VoidCallback onToggleDrawing;
  final VoidCallback onFinishAnalysis;
  final ValueChanged<bool> onShowAnswerChanged;
  final VoidCallback onClearAnalysisElements;
  final VoidCallback onClose;

  @override
  State<PuzzleSettingsDialog> createState() => _PuzzleSettingsDialogState();
}

class _PuzzleSettingsDialogState extends State<PuzzleSettingsDialog> {
  bool _networkSaving = false;
  bool _publishing = false;
  bool _loadingSaved = false;
  bool _minimized = false;
  bool _wasAutoSized = false;

  late final TextEditingController _titleCtl;
  late final TextEditingController _numberCtl;
  late String _typeTitle;

  String? _folderName;
  List<PuzzleSavedFile> _savedFiles = const [];

  double _left = 16;
  double _top = 72;
  double _width = 560;
  double _height = 760;

  static const double _minWidth = 420;
  static const double _minHeight = 520;
  static const double _minimizedWidth = 240;
  static const double _minimizedHeight = 40;

  static const List<String> _taskTypes = [
    'Задачи на зевки',
    'Мат',
    'Найти лучший ход',
  ];

  @override
  void initState() {
    super.initState();
    _titleCtl = TextEditingController(text: widget.taskTitle);
    _numberCtl = TextEditingController(text: widget.taskNumber.toString());
    _typeTitle = _taskTypes.contains(widget.taskTypeTitle)
        ? widget.taskTypeTitle
        : (_taskTypes.contains(widget.selectedTypeTitle)
            ? widget.selectedTypeTitle
            : _taskTypes.first);
    _refreshFolderInfoAndSavedTasks();
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _numberCtl.dispose();
    super.dispose();
  }

  int get _taskNumber {
    final parsed = int.tryParse(_numberCtl.text.trim()) ?? 1;
    return parsed < 1 ? 1 : parsed;
  }

  String get _taskTitle {
    final text = _titleCtl.text.trim();
    return text.isEmpty ? 'Новая задача' : text;
  }

  bool get _hasUnpublishedData {
    if (widget.isPublished) return false;
    if ((widget.startFen ?? '').trim().isNotEmpty) return true;
    if (widget.savedLines.isNotEmpty) return true;
    if (widget.currentLine.isNotEmpty) return true;
    if (_taskTitle != 'Новая задача') return true;
    return false;
  }

  PuzzleTask _buildCurrentPuzzle() {
    return widget.buildPuzzle(
      title: _taskTitle,
      number: _taskNumber,
      typeTitle: _typeTitle,
    );
  }

  String _fileNameFor(PuzzleTask puzzle) {
    final safeTitle = '${puzzle.number}_${puzzle.title}'
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zа-яё0-9]+', caseSensitive: false), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return '${safeTitle.isEmpty ? 'puzzle' : safeTitle}.json';
  }

  void _applyInitialFullColumnSize() {
    if (_wasAutoSized) return;

    final size = MediaQuery.of(context).size;
    _left = 16;
    _top = 72;
    _width = size.width < 1500 ? 520 : 560;
    _height = (size.height - _top - 14).clamp(_minHeight, size.height);
    _wasAutoSized = true;
  }

  void _clampToScreen() {
    final size = MediaQuery.of(context).size;
    final visibleWidth = _minimized ? _minimizedWidth : _width;
    final visibleHeight = _minimized ? _minimizedHeight : _height;

    _left = _left.clamp(
      8,
      (size.width - visibleWidth - 8).clamp(8, double.infinity),
    );
    _top = _top.clamp(
      72,
      (size.height - visibleHeight - 8).clamp(72, double.infinity),
    );
  }

  Future<void> _refreshFolderInfoAndSavedTasks() async {
    setState(() => _loadingSaved = true);
    try {
      final name = await getPuzzleFolderName();
      final files = await loadPuzzleTextFilesFromFolder();
      if (!mounted) return;
      setState(() {
        _folderName = name;
        _savedFiles = files;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _savedFiles = const []);
    } finally {
      if (mounted) setState(() => _loadingSaved = false);
    }
  }

  Future<void> _chooseFolder() async {
    try {
      final name = await choosePuzzleFolder();
      if (!mounted) return;
      setState(() => _folderName = name);
      await _refreshFolderInfoAndSavedTasks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: MakeChessLocalizedText(
                'Папка выбрана: ${name ?? 'без названия'}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: MakeChessLocalizedText('Папка не выбрана: $e')),
      );
    }
  }

  Future<void> _publish() async {
    final puzzle = _buildCurrentPuzzle();
    if (puzzle.startFen.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                MakeChessLocalizedText('Сначала запишите начальную позицию')),
      );
      return;
    }
    if (puzzle.solutionLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                MakeChessLocalizedText('Сначала запишите хотя бы одну ветку')),
      );
      return;
    }

    setState(() => _publishing = true);
    try {
      await publishPuzzleTextFile(
        fileName: _fileNameFor(puzzle),
        content: puzzle.toPrettyJson(),
      );
      widget.onPublished();
      await _refreshFolderInfoAndSavedTasks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: MakeChessLocalizedText(
                'Задача опубликована в выбранную папку')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: MakeChessLocalizedText('Не удалось опубликовать: $e')),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _newTask() async {
    if (_hasUnpublishedData) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const MakeChessLocalizedText('Создать новую задачу?'),
          content: const MakeChessLocalizedText(
            'Текущая задача ещё не опубликована. Если продолжить, данные в шаблоне будут очищены.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const MakeChessLocalizedText('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const MakeChessLocalizedText('Создать новую'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    widget.onNewTask();
    _titleCtl.text = 'Новая задача';
    _numberCtl.text = (_taskNumber + 1).toString();
    widget.onTaskTitleChanged(_titleCtl.text);
    widget.onTaskNumberChanged(_taskNumber);
    setState(() {});
  }

  Future<void> _saveToComputer() async {
    final puzzle = _buildCurrentPuzzle();
    await savePuzzleTextFile(
      fileName: _fileNameFor(puzzle),
      content: puzzle.toPrettyJson(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: MakeChessLocalizedText('Файл задачи скачан на компьютер')),
    );
  }

  Future<void> _saveToNetwork() async {
    setState(() => _networkSaving = true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() => _networkSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: MakeChessLocalizedText('Supabase подключим следующим шагом.'),
      ),
    );
  }

  Future<void> _copyJson() async {
    final json = _buildCurrentPuzzle().toPrettyJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: MakeChessLocalizedText('JSON задачи скопирован')),
    );
  }

  void _maximize() {
    final size = MediaQuery.of(context).size;
    setState(() {
      _left = 16;
      _top = 72;
      _width = size.width < 1500 ? 520 : 560;
      _height = (size.height - _top - 14).clamp(_minHeight, size.height);
    });
  }

  String _savedFileTitle(PuzzleSavedFile file) {
    try {
      final decoded = jsonDecode(file.content);
      if (decoded is Map) {
        final number = decoded['number'];
        final title = '${decoded['title'] ?? file.name}';
        final type = '${decoded['typeTitle'] ?? decoded['type'] ?? ''}';
        return '№$number $title${type.trim().isEmpty ? '' : ' · $type'}';
      }
    } catch (_) {}
    return file.name;
  }

  @override
  Widget build(BuildContext context) {
    _applyInitialFullColumnSize();
    _clampToScreen();

    if (_minimized) {
      return Positioned(
        left: _left,
        top: _top,
        width: _minimizedWidth,
        height: _minimizedHeight,
        child: Material(
          color: Colors.transparent,
          child: _WindowFrame(
            child: _Header(
              title: 'Настройка задач',
              subtitle: _typeTitle,
              onDrag: (delta) {
                setState(() {
                  _left += delta.dx;
                  _top += delta.dy;
                });
              },
              onMinimize: () => setState(() => _minimized = false),
              onMaximize: _maximize,
              onClose: widget.onClose,
              minimized: true,
            ),
          ),
        ),
      );
    }

    final startFen = widget.startFen;
    final hasStart = startFen != null && startFen.trim().isNotEmpty;

    return Positioned(
      left: _left,
      top: _top,
      width: _width,
      height: _height,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            _WindowFrame(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    title: 'Настройка задач',
                    subtitle: '$_typeTitle №$_taskNumber — $_taskTitle',
                    onDrag: (delta) {
                      setState(() {
                        _left += delta.dx;
                        _top += delta.dy;
                      });
                    },
                    onMinimize: () => setState(() => _minimized = true),
                    onMaximize: _maximize,
                    onClose: widget.onClose,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _NeoSmallButton(
                          text: 'Новая задача',
                          icon: Icons.add,
                          onTap: _newTask,
                        ),
                        _NeoSmallButton(
                          text: 'Опубликовать',
                          icon: Icons.publish,
                          iconWidget: _publishing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                          onTap: _publishing ? null : _publish,
                        ),
                        _NeoSmallButton(
                          text: 'Скачать',
                          icon: Icons.download,
                          onTap: _saveToComputer,
                        ),
                        _NeoSmallButton(
                          text: 'Выбрать папку',
                          icon: Icons.folder_open,
                          onTap: _chooseFolder,
                        ),
                        _NeoSmallButton(
                          text: 'В сети',
                          icon: Icons.cloud_upload,
                          onTap: _networkSaving ? null : _saveToNetwork,
                        ),
                        _NeoSmallButton(
                          text: 'JSON',
                          icon: Icons.copy,
                          onTap: _copyJson,
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Divider(color: AppColors.borderSoft, height: 1),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TaskMetaBlock(
                            titleController: _titleCtl,
                            numberController: _numberCtl,
                            typeTitle: _typeTitle,
                            types: _taskTypes,
                            onTitleChanged: (value) {
                              widget.onTaskTitleChanged(value);
                              setState(() {});
                            },
                            onNumberChanged: (value) {
                              final n = int.tryParse(value.trim()) ?? 1;
                              widget.onTaskNumberChanged(n < 1 ? 1 : n);
                              setState(() {});
                            },
                            onTypeChanged: (value) {
                              if (value == null) return;
                              setState(() => _typeTitle = value);
                              widget.onTaskTypeTitleChanged(value);
                            },
                          ),
                          const SizedBox(height: 12),
                          _FenBlock(
                            title: hasStart
                                ? 'Начальная позиция задачи'
                                : 'Начальная позиция ещё не записана',
                            fen: hasStart ? startFen : widget.currentFen,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _NeoSmallButton(
                                text: 'Записать позицию',
                                icon: Icons.flag,
                                onTap: widget.onSetInitialPosition,
                              ),
                              _NeoSmallButton(
                                text: widget.isRecordingLine
                                    ? 'Идёт запись'
                                    : 'Начать ветку',
                                icon: Icons.fiber_manual_record,
                                onTap: widget.onStartRecordingLine,
                              ),
                              _NeoSmallButton(
                                text: 'Записать ветку',
                                icon: Icons.playlist_add_check,
                                onTap: widget.onFinishRecordingLine,
                              ),
                              _NeoSmallButton(
                                text: 'Очистить',
                                icon: Icons.delete_outline,
                                onTap: widget.onClearDraft,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 170,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _LinesBlock(
                                    title: 'Записанные ветки',
                                    lines: widget.savedLines,
                                    emptyText: 'Пока нет записанных веток.',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _LinesBlock(
                                    title: 'Текущая ветка',
                                    lines: [widget.currentLine],
                                    emptyText:
                                        'Нажмите «Начать ветку» и сделайте ходы на доске.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _AuthorAnalysisSetupBlock(
                            activeKey: widget.activeAnalysisKey,
                            showAnswer: widget.showAnswer,
                            counts: widget.analysisCounts,
                            activeSide: widget.activeAnalysisSide,
                            onSideToggle: widget.onAnalysisSideToggle,
                            onModeChanged: widget.onAnalysisModeChanged,
                            drawingEnabled: widget.drawingEnabled,
                            onToggleDrawing: widget.onToggleDrawing,
                            onFinish: widget.onFinishAnalysis,
                            onShowAnswerChanged: widget.onShowAnswerChanged,
                            onClear: widget.onClearAnalysisElements,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeDownRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    setState(() {
                      _width = (_width + details.delta.dx).clamp(
                        _minWidth,
                        MediaQuery.of(context).size.width - _left - 8,
                      );
                      _height = (_height + details.delta.dy).clamp(
                        _minHeight,
                        MediaQuery.of(context).size.height - _top - 8,
                      );
                    });
                  },
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Icon(
                        Icons.drag_handle,
                        size: 18,
                        color: AppColors.textDim,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskMetaBlock extends StatelessWidget {
  const _TaskMetaBlock({
    required this.titleController,
    required this.numberController,
    required this.typeTitle,
    required this.types,
    required this.onTitleChanged,
    required this.onNumberChanged,
    required this.onTypeChanged,
  });

  final TextEditingController titleController;
  final TextEditingController numberController;
  final String typeTitle;
  final List<String> types;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onNumberChanged;
  final ValueChanged<String?> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.35),
        borderRadius: AppRadius.r14,
        border: Border.all(color: AppColors.borderSoft),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MakeChessLocalizedText('Данные задачи',
              style: AppTextStyles.panelTitle),
          const SizedBox(height: 10),
          TextField(
            controller: titleController,
            onChanged: onTitleChanged,
            style: AppTextStyles.body,
            decoration: _inputDecoration('Название задачи'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  controller: numberController,
                  onChanged: onNumberChanged,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppTextStyles.body,
                  decoration: _inputDecoration('Номер'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: types.contains(typeTitle) ? typeTitle : types.first,
                  items: types
                      .map(
                        (type) => DropdownMenuItem<String>(
                          value: type,
                          child: MakeChessLocalizedText(type),
                        ),
                      )
                      .toList(),
                  onChanged: onTypeChanged,
                  dropdownColor: AppColors.surface,
                  style: AppTextStyles.body,
                  decoration: _inputDecoration('Тип задачи'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: MakeChessLocalization.phrase(label),
      labelStyle: AppTextStyles.caption,
      isDense: true,
      filled: true,
      fillColor: AppColors.appBgSoft.withOpacity(0.55),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.r10,
        borderSide: const BorderSide(color: AppColors.borderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.r10,
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    );
  }
}

class _FolderBlock extends StatelessWidget {
  const _FolderBlock({
    required this.folderName,
    required this.loading,
    required this.savedFiles,
    required this.titleBuilder,
    required this.onChooseFolder,
    required this.onRefresh,
  });

  final String? folderName;
  final bool loading;
  final List<PuzzleSavedFile> savedFiles;
  final String Function(PuzzleSavedFile file) titleBuilder;
  final VoidCallback onChooseFolder;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.35),
        borderRadius: AppRadius.r14,
        border: Border.all(color: AppColors.borderSoft),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: MakeChessLocalizedText(
                  folderName == null
                      ? 'Папка задач не выбрана'
                      : 'Папка: $folderName',
                  style: AppTextStyles.panelTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: MakeChessLocalization.phrase('Обновить список'),
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, color: AppColors.text),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MakeChessLocalizedText(
            'После выбора папки окно подтянет сохранённые .json задачи.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : savedFiles.isEmpty
                    ? MakeChessLocalizedText('Сохранённых задач пока нет.',
                        style: AppTextStyles.muted)
                    : ListView.separated(
                        itemCount: savedFiles.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: AppColors.borderSoft),
                        itemBuilder: (context, index) {
                          final file = savedFiles[index];
                          return MakeChessLocalizedText(
                            titleBuilder(file),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.mono,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _AuthorAnalysisSetupBlock extends StatefulWidget {
  const _AuthorAnalysisSetupBlock({
    required this.activeKey,
    required this.showAnswer,
    required this.counts,
    required this.activeSide,
    required this.onSideToggle,
    required this.onModeChanged,
    required this.drawingEnabled,
    required this.onToggleDrawing,
    required this.onFinish,
    required this.onShowAnswerChanged,
    required this.onClear,
  });

  final String? activeKey;
  final bool showAnswer;
  final Map<String, Map<String, int>> counts;
  final String activeSide;
  final VoidCallback onSideToggle;
  final ValueChanged<String?> onModeChanged;
  final bool drawingEnabled;
  final VoidCallback onToggleDrawing;
  final VoidCallback onFinish;
  final ValueChanged<bool> onShowAnswerChanged;
  final VoidCallback onClear;

  @override
  State<_AuthorAnalysisSetupBlock> createState() =>
      _AuthorAnalysisSetupBlockState();
}

class _AuthorAnalysisSetupBlockState extends State<_AuthorAnalysisSetupBlock> {
  int _solveSeconds = 60;
  late final TextEditingController _secondsCtl;

  @override
  void initState() {
    super.initState();
    _secondsCtl = TextEditingController(text: _solveSeconds.toString());
  }

  @override
  void dispose() {
    _secondsCtl.dispose();
    super.dispose();
  }

  int get _totalCount {
    var total = 0;
    for (final sideCounts in widget.counts.values) {
      total += sideCounts.values.fold<int>(0, (a, b) => a + b);
    }
    return total;
  }

  void _toggleKey(String key) {
    // Повторное нажатие на ту же кнопку должен обрабатывать родитель:
    // он скрывает/показывает слой, но не удаляет элементы из данных задачи.
    widget.onModeChanged(key);
  }

  void _setSecondsFromText(String value) {
    final parsed = int.tryParse(value.trim());
    setState(() {
      _solveSeconds = parsed == null ? 0 : parsed.clamp(0, 9999).toInt();
    });
  }

  Widget _analysisRow({
    required String leftTitle,
    required String leftKey,
    required Color leftColor,
    required IconData leftIcon,
    required String rightTitle,
    required String rightKey,
    required Color rightColor,
    required IconData rightIcon,
    required Widget sideButton,
  }) {
    return Row(
      children: [
        Expanded(
          child: _AnalysisSetupButton(
            title: leftTitle,
            keyName: leftKey,
            activeKey: widget.activeKey,
            icon: leftIcon,
            iconColor: leftColor,
            onTap: _toggleKey,
            count: widget.counts[widget.activeSide]?[leftKey] ?? 0,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AnalysisSetupButton(
            title: rightTitle,
            keyName: rightKey,
            activeKey: widget.activeKey,
            icon: rightIcon,
            iconColor: rightColor,
            onTap: _toggleKey,
            count: widget.counts[widget.activeSide]?[rightKey] ?? 0,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 104, child: sideButton),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.35),
        borderRadius: AppRadius.r14,
        border: Border.all(color: AppColors.borderSoft),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: MakeChessLocalizedText(
                  'Правильный ответ задачи',
                  style: AppTextStyles.panelTitle,
                ),
              ),
              MakeChessLocalizedText(
                widget.drawingEnabled
                    ? 'рисование включено'
                    : 'рисование выключено',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: _NeoSmallButton(
              text: 'Установить',
              icon: Icons.edit_outlined,
              onTap: widget.onToggleDrawing,
              selected: widget.drawingEnabled,
            ),
          ),
          const SizedBox(height: 8),
          _analysisRow(
            leftTitle: 'Угроза',
            leftKey: 'threat',
            leftColor: const Color(0xFFFF2D2D),
            leftIcon: Icons.arrow_forward,
            rightTitle: 'Связка',
            rightKey: 'pin',
            rightColor: const Color(0xFF6A35FF),
            rightIcon: Icons.arrow_forward,
            sideButton: _NeoSmallButton(
              text: widget.activeSide == 'black' ? 'Чёрные' : 'Белые',
              icon: Icons.swap_horiz,
              onTap: widget.onSideToggle,
            ),
          ),
          const SizedBox(height: 8),
          _analysisRow(
            leftTitle: 'Рентген',
            leftKey: 'xray',
            leftColor: const Color(0xFFFF00C8),
            leftIcon: Icons.arrow_forward,
            rightTitle: 'Слабость',
            rightKey: 'weakness',
            rightColor: const Color(0xFF4CFF2E),
            rightIcon: Icons.circle_outlined,
            sideButton: _NeoSmallButton(
              text: 'Готово',
              icon: Icons.check,
              onTap: widget.onFinish,
            ),
          ),
          const SizedBox(height: 8),
          _analysisRow(
            leftTitle: 'P1',
            leftKey: 'r1',
            leftColor: const Color(0xFFFFB07A),
            leftIcon: Icons.arrow_forward,
            rightTitle: 'P2',
            rightKey: 'r2',
            rightColor: const Color(0xFF0057FF),
            rightIcon: Icons.circle_outlined,
            sideButton: _NeoSmallButton(
              text: 'Показать\nответ',
              icon: Icons.visibility,
              onTap: () => widget.onShowAnswerChanged(!widget.showAnswer),
            ),
          ),
          const SizedBox(height: 8),
          _analysisRow(
            leftTitle: 'P3',
            leftKey: 'r3',
            leftColor: const Color(0xFF40F7F7),
            leftIcon: Icons.arrow_forward,
            rightTitle: 'P4',
            rightKey: 'r4',
            rightColor: const Color(0xFFFF5F93),
            rightIcon: Icons.circle_outlined,
            sideButton: _NeoSmallButton(
              text: 'Очистить',
              icon: Icons.delete_outline,
              onTap: widget.onClear,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _AnalysisCounterBox(counts: widget.counts)),
              const SizedBox(width: 8),
              SizedBox(
                width: 64,
                height: 64,
                child: _TotalAnalysisBox(value: _totalCount),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                height: 64,
                child: _TimeLimitBox(
                  controller: _secondsCtl,
                  onChanged: _setSecondsFromText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalysisSetupButton extends StatefulWidget {
  const _AnalysisSetupButton({
    required this.title,
    required this.keyName,
    required this.activeKey,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    required this.count,
  });

  final String title;
  final String keyName;
  final String? activeKey;
  final IconData icon;
  final Color iconColor;
  final ValueChanged<String> onTap;
  final int count;

  @override
  State<_AnalysisSetupButton> createState() => _AnalysisSetupButtonState();
}

class _AnalysisSetupButtonState extends State<_AnalysisSetupButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.activeKey == widget.keyName;
    final fgColor = selected || _hover ? AppColors.accent : AppColors.text;

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
        onTap: () => widget.onTap(widget.keyName),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: AppDecorations.neoButton(
            active: selected || _hover,
            pressed: _pressed,
            enabled: true,
          ).copyWith(
            border: selected
                ? Border.all(color: AppColors.accent, width: 1.3)
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: MakeChessLocalizedText(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.buttonCompact.copyWith(color: fgColor),
                ),
              ),
              const SizedBox(width: 6),
              MakeChessLocalizedText(
                widget.count > 0 ? '${widget.count}' : '',
                style: AppTextStyles.buttonCompact.copyWith(
                  color: AppColors.text.withOpacity(0.78),
                ),
              ),
              const SizedBox(width: 6),
              Icon(widget.icon, size: 17, color: widget.iconColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalysisCounterBox extends StatelessWidget {
  const _AnalysisCounterBox({required this.counts});

  final Map<String, Map<String, int>> counts;

  @override
  Widget build(BuildContext context) {
    String v(String key) {
      final white = counts['white']?[key] ?? 0;
      final black = counts['black']?[key] ?? 0;
      return 'Б$white Ч$black';
    }

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.78),
        borderRadius: AppRadius.r10,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: DefaultTextStyle(
        style: AppTextStyles.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          height: 1.25,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MakeChessLocalizedText('Угроза   ${v('threat')}'),
                  MakeChessLocalizedText('Рентген  ${v('xray')}'),
                  MakeChessLocalizedText('P1       ${v('r1')}'),
                  MakeChessLocalizedText('P3       ${v('r3')}'),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MakeChessLocalizedText('Связка   ${v('pin')}'),
                  MakeChessLocalizedText('Слабость ${v('weakness')}'),
                  MakeChessLocalizedText('P2       ${v('r2')}'),
                  MakeChessLocalizedText('P4       ${v('r4')}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalAnalysisBox extends StatelessWidget {
  const _TotalAnalysisBox({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFD7FFE1),
        borderRadius: AppRadius.r10,
        border: Border.all(color: const Color(0xFF83E69C)),
      ),
      child: MakeChessLocalizedText(
        '$value',
        style: const TextStyle(
          color: Color(0xFF002DFF),
          fontSize: 31,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TimeLimitBox extends StatelessWidget {
  const _TimeLimitBox({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.78),
        borderRadius: AppRadius.r10,
        border: Border.all(color: AppColors.borderSoft),
      ),
      padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLines: 1,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: AppTextStyles.panelTitle.copyWith(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          MakeChessLocalizedText(
            'Сек',
            style: AppTextStyles.caption.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _NeoSmallButton extends StatefulWidget {
  const _NeoSmallButton({
    required this.text,
    required this.icon,
    required this.onTap,
    this.iconWidget,
    this.selected = false,
  });

  final String text;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? iconWidget;
  final bool selected;

  @override
  State<_NeoSmallButton> createState() => _NeoSmallButtonState();
}

class _NeoSmallButtonState extends State<_NeoSmallButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final active = enabled && (widget.selected || _hover);
    final pressed = enabled && _pressed;
    final fgColor = enabled
        ? (active ? AppColors.accent : AppColors.text)
        : AppColors.text.withOpacity(0.35);

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
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: AppDecorations.neoButton(
            active: active,
            pressed: pressed,
            enabled: enabled,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.iconWidget ?? Icon(widget.icon, size: 16, color: fgColor),
              const SizedBox(width: 8),
              Flexible(
                child: MakeChessLocalizedText(
                  widget.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.buttonCompact.copyWith(color: fgColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onDrag,
    required this.onMinimize,
    required this.onMaximize,
    required this.onClose,
    this.minimized = false,
  });

  final String title;
  final String subtitle;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onMinimize;
  final VoidCallback onMaximize;
  final VoidCallback onClose;
  final bool minimized;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onDrag(details.delta),
        child: Container(
          height: minimized ? 40 : 56,
          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MakeChessLocalizedText(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.sectionTitle,
                    ),
                    if (!minimized)
                      MakeChessLocalizedText(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: minimized
                    ? MakeChessLocalization.phrase('Развернуть')
                    : MakeChessLocalization.phrase('Свернуть'),
                onPressed: onMinimize,
                icon: Icon(
                  minimized ? Icons.open_in_full : Icons.remove,
                  color: AppColors.text,
                ),
              ),
              if (!minimized)
                IconButton(
                  tooltip: MakeChessLocalization.phrase('Увеличить'),
                  onPressed: onMaximize,
                  icon: const Icon(Icons.crop_square, color: AppColors.text),
                ),
              IconButton(
                tooltip: MakeChessLocalization.phrase('Закрыть'),
                onPressed: onClose,
                icon: const Icon(Icons.close, color: AppColors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowFrame extends StatelessWidget {
  const _WindowFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppDecorations.panel().copyWith(
        boxShadow: const [
          BoxShadow(
            color: Color(0xAA000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.r16,
        child: child,
      ),
    );
  }
}

class _FenBlock extends StatelessWidget {
  const _FenBlock({
    required this.title,
    required this.fen,
  });

  final String title;
  final String fen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.35),
        borderRadius: AppRadius.r14,
        border: Border.all(color: AppColors.borderSoft),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MakeChessLocalizedText(title, style: AppTextStyles.panelTitle),
          const SizedBox(height: 8),
          SelectableText(fen, style: AppTextStyles.mono),
        ],
      ),
    );
  }
}

class _LinesBlock extends StatelessWidget {
  const _LinesBlock({
    required this.title,
    required this.lines,
    required this.emptyText,
  });

  final String title;
  final List<List<String>> lines;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final visibleLines = lines.where((line) => line.isNotEmpty).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.35),
        borderRadius: AppRadius.r14,
        border: Border.all(color: AppColors.borderSoft),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MakeChessLocalizedText(title, style: AppTextStyles.panelTitle),
          const SizedBox(height: 8),
          Expanded(
            child: visibleLines.isEmpty
                ? MakeChessLocalizedText(emptyText, style: AppTextStyles.muted)
                : ListView.separated(
                    itemCount: visibleLines.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: AppColors.borderSoft),
                    itemBuilder: (context, index) {
                      final line = visibleLines[index];
                      return SelectableText(
                        '${index + 1}. ${line.join(' ')}',
                        style: AppTextStyles.mono,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
