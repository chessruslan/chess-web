// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
// MAKECHESS_TEACHER_ASSIGNMENT_LOCALIZED_V3_20260807
//
// Изолированный интерфейс конструктора заданий учителя.
// Вся дальнейшая работа над окном заданий должна выполняться в этом файле.
// Файл не содержит бизнес-логику назначения ученикам и сохранения в базу.

import 'package:flutter/material.dart';

import '../../localization/makechess_localization.dart';

Future<void> showTeacherAssignmentBuilderDialog(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'teacher-assignment-builder',
    barrierColor: Colors.black.withOpacity(0.48),
    transitionDuration: const Duration(milliseconds: 160),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return const _TeacherAssignmentBuilderOverlay();
    },
  );
}

class _TeacherAssignmentBuilderOverlay extends StatefulWidget {
  const _TeacherAssignmentBuilderOverlay();

  @override
  State<_TeacherAssignmentBuilderOverlay> createState() =>
      _TeacherAssignmentBuilderOverlayState();
}

class _TeacherAssignmentBuilderOverlayState
    extends State<_TeacherAssignmentBuilderOverlay> {
  static const double _screenPadding = 12;
  static const double _minWidth = 820;
  static const double _minHeight = 560;

  final List<_TeacherAssignmentDraft> _assignments =
      List<_TeacherAssignmentDraft>.generate(
    4,
    (index) => _TeacherAssignmentDraft(number: index + 1),
    growable: true,
  );

  final ScrollController _scrollController = ScrollController();

  Offset _position = const Offset(120, 80);
  Size _windowSize = const Size(1000, 720);
  bool _positionInitialized = false;

  int _selectedIndex = 0;
  String _selectedMenuKey = MakeChessTextKey.playGame;
  String? _statusMessage;
  String _languageCode = 'RU';

  static const List<_AssignmentMenuEntry> _menuEntries = [
    _AssignmentMenuEntry(MakeChessTextKey.playGame, Icons.sports_esports),
    _AssignmentMenuEntry(MakeChessTextKey.puzzles, Icons.extension),
    _AssignmentMenuEntry(MakeChessTextKey.trainers, Icons.model_training),
    _AssignmentMenuEntry(MakeChessTextKey.strategy, Icons.psychology_alt),
    _AssignmentMenuEntry(MakeChessTextKey.analysis, Icons.analytics),
    _AssignmentMenuEntry(MakeChessTextKey.more, Icons.more_horiz),
    _AssignmentMenuEntry(MakeChessTextKey.settings, Icons.settings),
  ];

  String _t(
    String key, {
    Map<String, Object?> params = const <String, Object?>{},
  }) {
    return MakeChessLocalization.text(
      key,
      languageCode: _languageCode,
      params: params,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: MakeChessLocalizationController.languageCode,
      builder: (context, languageCode, child) {
        _languageCode =
            MakeChessLocalization.normalizeLanguageCode(languageCode);

        return Directionality(
          textDirection: MakeChessLocalization.textDirection(_languageCode),
          child: Material(
            color: Colors.transparent,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );

                _prepareInitialGeometry(screenSize);
                _keepInsideScreen(screenSize);

                return Stack(
                  children: [
                    Positioned(
                      left: _position.dx,
                      top: _position.dy,
                      width: _windowSize.width,
                      height: _windowSize.height,
                      child: _buildWindow(context, screenSize),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildWindow(BuildContext context, Size screenSize) {
    final selected = _assignments[_selectedIndex];
    final selectedTitle = selected.title.trim();

    return Material(
      color: const Color(0xFF222A35),
      elevation: 28,
      borderRadius: BorderRadius.circular(17),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: const Color(0xFF28C8FF),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.42),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(
                  context: context,
                  screenSize: screenSize,
                  selectedTitle: selectedTitle,
                ),
                _buildMenu(),
                if (_statusMessage != null) _buildStatusMessage(),
                const SizedBox(height: 9),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _buildAssignmentFrames(),
                  ),
                ),
              ],
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: _buildResizeHandle(screenSize),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({
    required BuildContext context,
    required Size screenSize,
    required String selectedTitle,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) {
        setState(() {
          _position += details.delta;
          _keepInsideScreen(screenSize);
        });
      },
      child: Container(
        height: 58,
        padding: const EdgeInsets.only(left: 14, right: 6),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF343D49),
              Color(0xFF252D38),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border(
            bottom: BorderSide(color: Color(0xFF475463)),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.assignment,
              size: 22,
              color: Color(0xFF35CDFF),
            ),
            const SizedBox(width: 10),
            MakeChessLocalizedText(
              _t(MakeChessTextKey.assignment),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (selectedTitle.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: MakeChessLocalizedText(
                  selectedTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB9F0FF),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else
              const Spacer(),
            _buildHeaderActionButton(
              text: _t(MakeChessTextKey.loadAssignment),
              icon: Icons.file_open,
              onTap: () => _showLoadChoice(
                scope: _AssignmentActionScope.wholeWork,
              ),
            ),
            const SizedBox(width: 7),
            _buildHeaderActionButton(
              text: _t(MakeChessTextKey.saveAssignment),
              icon: Icons.save_outlined,
              onTap: () => _showSaveChoice(
                scope: _AssignmentActionScope.wholeWork,
              ),
            ),
            const SizedBox(width: 5),
            TextButton.icon(
              onPressed: () => _renameAssignment(_selectedIndex),
              icon: const Icon(Icons.edit, size: 16),
              label: MakeChessLocalizedText(_t(MakeChessTextKey.name)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB9F0FF),
                visualDensity: VisualDensity.compact,
              ),
            ),
            IconButton(
              tooltip: _t(MakeChessTextKey.close),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.close,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2D3744),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFF5A6878)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            MakeChessLocalizedText(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 0),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final entry in _menuEntries)
            _buildMenuButton(
              text: _t(entry.textKey),
              icon: entry.icon,
              selected: _selectedMenuKey == entry.textKey,
              onTap: () {
                setState(() {
                  _selectedMenuKey = entry.textKey;
                });
              },
            ),
          _buildMenuButton(
            text: _t(MakeChessTextKey.addAssignment),
            icon: Icons.add_box_outlined,
            selected: false,
            highlighted: true,
            onTap: _addAssignment,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton({
    required String text,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    final borderColor = highlighted
        ? const Color(0xFF41D17D)
        : selected
            ? const Color(0xFF35CDFF)
            : const Color(0xFF536170);

    final background = highlighted
        ? const Color(0xFF1E4931)
        : selected
            ? const Color(0xFF124D64)
            : const Color(0xFF2C3541);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.16),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            MakeChessLocalizedText(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF18384A),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFF347994)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              size: 17,
              color: Color(0xFF9DE6FF),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MakeChessLocalizedText(
                _statusMessage!,
                style: const TextStyle(
                  color: Color(0xFFD2F4FF),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: _t(MakeChessTextKey.closeMessage),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  _statusMessage = null;
                });
              },
              icon: const Icon(
                Icons.close,
                size: 17,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentFrames() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final calculatedHeight =
            ((constraints.maxHeight - 24) / 4).clamp(112.0, 185.0).toDouble();

        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: _assignments.length > 4,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.only(right: 4),
            itemCount: _assignments.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildAssignmentFrame(
                assignment: _assignments[index],
                index: index,
                height: calculatedHeight,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAssignmentFrame({
    required _TeacherAssignmentDraft assignment,
    required int index,
    required double height,
  }) {
    final selected = index == _selectedIndex;
    final title = assignment.title.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () async {
        setState(() {
          _selectedIndex = index;
        });

        if (title.isEmpty) {
          await _renameAssignment(index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: height,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF283B4C) : const Color(0xFF1C232D),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? const Color(0xFF35CDFF) : const Color(0xFF566372),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF0F5671)
                        : const Color(0xFF303A46),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: MakeChessLocalizedText(
                    _t(
                      MakeChessTextKey.assignmentNumber,
                      params: <String, Object?>{
                        'number': assignment.number,
                      },
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MakeChessLocalizedText(
                    title.isEmpty ? _t(MakeChessTextKey.noTitle) : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: title.isEmpty
                          ? Colors.white54
                          : const Color(0xFFB9F0FF),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildFrameActionButton(
                  text: _t(MakeChessTextKey.loadAssignment),
                  icon: Icons.file_open,
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                    _showLoadChoice(
                      scope: _AssignmentActionScope.singleAssignment,
                      assignmentIndex: index,
                    );
                  },
                ),
                const SizedBox(width: 7),
                _buildFrameActionButton(
                  text: _t(MakeChessTextKey.saveAssignment),
                  icon: Icons.save_outlined,
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                    _showSaveChoice(
                      scope: _AssignmentActionScope.singleAssignment,
                      assignmentIndex: index,
                    );
                  },
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: _t(MakeChessTextKey.setTitle),
                  onPressed: () => _renameAssignment(index),
                  icon: const Icon(
                    Icons.drive_file_rename_outline,
                    color: Colors.white70,
                    size: 19,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: const Color(0xFF4E5A68),
                  ),
                ),
                child: MakeChessLocalizedText(
                  title.isEmpty
                      ? _t(MakeChessTextKey.clickFrameSetTitle)
                      : _t(MakeChessTextKey.futureContent),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrameActionButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF2D3744),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFF5A6878)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            MakeChessLocalizedText(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResizeHandle(Size screenSize) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) {
        setState(() {
          final maximumWidth = screenSize.width - _position.dx - _screenPadding;
          final maximumHeight =
              screenSize.height - _position.dy - _screenPadding;

          final allowedMaxWidth =
              maximumWidth < _minWidth ? _minWidth : maximumWidth;
          final allowedMaxHeight =
              maximumHeight < _minHeight ? _minHeight : maximumHeight;

          final width = (_windowSize.width + details.delta.dx)
              .clamp(_minWidth, allowedMaxWidth)
              .toDouble();
          final height = (_windowSize.height + details.delta.dy)
              .clamp(_minHeight, allowedMaxHeight)
              .toDouble();

          _windowSize = Size(width, height);
          _keepInsideScreen(screenSize);
        });
      },
      child: const SizedBox(
        width: 30,
        height: 30,
        child: Align(
          alignment: Alignment.bottomRight,
          child: Icon(
            Icons.open_in_full,
            size: 17,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }

  Future<void> _showLoadChoice({
    required _AssignmentActionScope scope,
    int? assignmentIndex,
  }) async {
    final label = _scopeLabel(
      scope: scope,
      assignmentIndex: assignmentIndex,
    );

    final result = await showDialog<_AssignmentLoadSource>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Directionality(
          textDirection: MakeChessLocalization.textDirection(_languageCode),
          child: _AssignmentChoiceDialog<_AssignmentLoadSource>(
            title: _t(MakeChessTextKey.loadAssignment),
            subtitle: label,
            closeText: _t(MakeChessTextKey.close),
            cancelText: _t(MakeChessTextKey.cancel),
            options: <_AssignmentChoiceOption<_AssignmentLoadSource>>[
              _AssignmentChoiceOption<_AssignmentLoadSource>(
                value: _AssignmentLoadSource.computer,
                icon: Icons.computer,
                title: _t(MakeChessTextKey.loadFromComputer),
                description: _t(MakeChessTextKey.loadFromComputerDescription),
              ),
              _AssignmentChoiceOption<_AssignmentLoadSource>(
                value: _AssignmentLoadSource.database,
                icon: Icons.cloud_download_outlined,
                title: _t(MakeChessTextKey.loadFromDatabase),
                description: _t(MakeChessTextKey.loadFromDatabaseDescription),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || result == null) return;

    final sourceText = switch (result) {
      _AssignmentLoadSource.computer => _t(MakeChessTextKey.fromComputer),
      _AssignmentLoadSource.database => _t(MakeChessTextKey.fromDatabase),
    };

    setState(() {
      _statusMessage = _t(
        MakeChessTextKey.loadModeSelected,
        params: <String, Object?>{
          'label': label,
          'source': sourceText,
        },
      );
    });
  }

  Future<void> _showSaveChoice({
    required _AssignmentActionScope scope,
    int? assignmentIndex,
  }) async {
    final label = _scopeLabel(
      scope: scope,
      assignmentIndex: assignmentIndex,
    );

    final result = await showDialog<_AssignmentStorageTarget>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Directionality(
          textDirection: MakeChessLocalization.textDirection(_languageCode),
          child: _AssignmentChoiceDialog<_AssignmentStorageTarget>(
            title: _t(MakeChessTextKey.saveAssignment),
            subtitle: label,
            closeText: _t(MakeChessTextKey.close),
            cancelText: _t(MakeChessTextKey.cancel),
            options: <_AssignmentChoiceOption<_AssignmentStorageTarget>>[
              _AssignmentChoiceOption<_AssignmentStorageTarget>(
                value: _AssignmentStorageTarget.computer,
                icon: Icons.computer,
                title: _t(MakeChessTextKey.saveToComputer),
                description: _t(MakeChessTextKey.saveToComputerDescription),
              ),
              _AssignmentChoiceOption<_AssignmentStorageTarget>(
                value: _AssignmentStorageTarget.database,
                icon: Icons.cloud_upload_outlined,
                title: _t(MakeChessTextKey.saveToDatabase),
                description: _t(MakeChessTextKey.saveToDatabaseDescription),
              ),
              _AssignmentChoiceOption<_AssignmentStorageTarget>(
                value: _AssignmentStorageTarget.computerAndDatabase,
                icon: Icons.cloud_done_outlined,
                title: _t(MakeChessTextKey.saveToBoth),
                description: _t(MakeChessTextKey.saveToBothDescription),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || result == null) return;

    final targetText = switch (result) {
      _AssignmentStorageTarget.computer => _t(MakeChessTextKey.toComputer),
      _AssignmentStorageTarget.database => _t(MakeChessTextKey.toDatabase),
      _AssignmentStorageTarget.computerAndDatabase =>
        _t(MakeChessTextKey.toBoth),
    };

    setState(() {
      _statusMessage = _t(
        MakeChessTextKey.saveModeSelected,
        params: <String, Object?>{
          'label': label,
          'target': targetText,
        },
      );
    });
  }

  String _scopeLabel({
    required _AssignmentActionScope scope,
    int? assignmentIndex,
  }) {
    if (scope == _AssignmentActionScope.wholeWork) {
      return _t(MakeChessTextKey.wholeWork);
    }

    final safeIndex = assignmentIndex ?? _selectedIndex;
    final assignment = _assignments[safeIndex];
    final title = assignment.title.trim();

    if (title.isEmpty) {
      return _t(
        MakeChessTextKey.assignmentNumberOnly,
        params: <String, Object?>{
          'number': assignment.number,
        },
      );
    }

    return _t(
      MakeChessTextKey.assignmentNumberWithTitle,
      params: <String, Object?>{
        'number': assignment.number,
        'title': title,
      },
    );
  }

  Future<void> _renameAssignment(int index) async {
    final current = _assignments[index];
    final controller = TextEditingController(text: current.title);

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF242C37),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(
              color: Color(0xFF35CDFF),
            ),
          ),
          title: MakeChessLocalizedText(
            _t(
              MakeChessTextKey.titleAssignment,
              params: <String, Object?>{
                'number': current.number,
              },
            ),
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 120,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: _t(MakeChessTextKey.enterTitle),
              hintStyle: const TextStyle(color: Colors.white38),
              counterStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1A2029),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF536170),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF35CDFF),
                ),
              ),
            ),
            onSubmitted: (value) {
              Navigator.of(dialogContext).pop(value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: MakeChessLocalizedText(_t(MakeChessTextKey.cancel)),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  controller.text.trim(),
                );
              },
              child: MakeChessLocalizedText(_t(MakeChessTextKey.save)),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || result == null) return;

    setState(() {
      _assignments[index] = current.copyWith(title: result);
      _selectedIndex = index;
    });
  }

  void _addAssignment() {
    setState(() {
      final nextNumber = _assignments.length + 1;
      _assignments.add(
        _TeacherAssignmentDraft(number: nextNumber),
      );
      _selectedIndex = _assignments.length - 1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
      if (mounted) {
        await _renameAssignment(_selectedIndex);
      }
    });
  }

  void _prepareInitialGeometry(Size screenSize) {
    if (_positionInitialized) return;

    final targetWidth = screenSize.width < 1060
        ? screenSize.width - (_screenPadding * 2)
        : 1000.0;
    final targetHeight = screenSize.height < 760
        ? screenSize.height - (_screenPadding * 2)
        : 720.0;

    _windowSize = Size(
      targetWidth < _minWidth ? _minWidth : targetWidth,
      targetHeight < _minHeight ? _minHeight : targetHeight,
    );

    _position = Offset(
      ((screenSize.width - _windowSize.width) / 2)
          .clamp(_screenPadding, screenSize.width)
          .toDouble(),
      ((screenSize.height - _windowSize.height) / 2)
          .clamp(_screenPadding, screenSize.height)
          .toDouble(),
    );

    _positionInitialized = true;
  }

  void _keepInsideScreen(Size screenSize) {
    final maximumLeft = screenSize.width - _windowSize.width - _screenPadding;
    final maximumTop = screenSize.height - _windowSize.height - _screenPadding;

    final safeMaximumLeft =
        maximumLeft < _screenPadding ? _screenPadding : maximumLeft;
    final safeMaximumTop =
        maximumTop < _screenPadding ? _screenPadding : maximumTop;

    _position = Offset(
      _position.dx.clamp(_screenPadding, safeMaximumLeft).toDouble(),
      _position.dy.clamp(_screenPadding, safeMaximumTop).toDouble(),
    );
  }
}

enum _AssignmentActionScope {
  wholeWork,
  singleAssignment,
}

enum _AssignmentLoadSource {
  computer,
  database,
}

enum _AssignmentStorageTarget {
  computer,
  database,
  computerAndDatabase,
}

class _TeacherAssignmentDraft {
  const _TeacherAssignmentDraft({
    required this.number,
    this.title = '',
  });

  final int number;
  final String title;

  _TeacherAssignmentDraft copyWith({
    int? number,
    String? title,
  }) {
    return _TeacherAssignmentDraft(
      number: number ?? this.number,
      title: title ?? this.title,
    );
  }
}

class _AssignmentMenuEntry {
  const _AssignmentMenuEntry(this.textKey, this.icon);

  final String textKey;
  final IconData icon;
}

class _AssignmentChoiceOption<T> {
  const _AssignmentChoiceOption({
    required this.value,
    required this.icon,
    required this.title,
    required this.description,
  });

  final T value;
  final IconData icon;
  final String title;
  final String description;
}

class _AssignmentChoiceDialog<T> extends StatelessWidget {
  const _AssignmentChoiceDialog({
    required this.title,
    required this.subtitle,
    required this.closeText,
    required this.cancelText,
    required this.options,
  });

  final String title;
  final String subtitle;
  final String closeText;
  final String cancelText;
  final List<_AssignmentChoiceOption<T>> options;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF242C37),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF35CDFF)),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 14, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      title: Row(
        children: [
          Expanded(
            child: MakeChessLocalizedText(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: closeText,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white60),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MakeChessLocalizedText(
              subtitle,
              style: const TextStyle(
                color: Color(0xFFB9F0FF),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < options.length; index++) ...[
              _buildOption(context, options[index]),
              if (index != options.length - 1) const SizedBox(height: 9),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: MakeChessLocalizedText(cancelText),
        ),
      ],
    );
  }

  Widget _buildOption(
    BuildContext context,
    _AssignmentChoiceOption<T> option,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).pop(option.value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1B222C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF536170)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF123F52),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2C91B4)),
              ),
              child: Icon(
                option.icon,
                color: const Color(0xFFB9F0FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MakeChessLocalizedText(
                    option.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  MakeChessLocalizedText(
                    option.description,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
