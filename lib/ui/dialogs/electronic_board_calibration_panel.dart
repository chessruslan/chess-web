import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../localization/makechess_localization.dart';
import '../app_style.dart';
import 'electronic_board_camera.dart';
import 'electronic_board_floating_board.dart';
import 'electronic_board_optics.dart';

class ElectronicBoardCalibrationPanel extends StatefulWidget {
  const ElectronicBoardCalibrationPanel({super.key});

  @override
  State<ElectronicBoardCalibrationPanel> createState() =>
      _ElectronicBoardCalibrationPanelState();
}

class _ElectronicBoardCalibrationPanelState
    extends State<ElectronicBoardCalibrationPanel> {
  static const String _storageKey = 'makechess_optical_board_calibration_v1';
  final TextEditingController _rowsController = TextEditingController(text: '8');
  final TextEditingController _columnsController =
      TextEditingController(text: '16');
  final TextEditingController _leftController = TextEditingController(text: '0');
  final TextEditingController _topController = TextEditingController(text: '0');
  final TextEditingController _cellWidthController =
      TextEditingController(text: '50');
  final TextEditingController _cellHeightController =
      TextEditingController(text: '38');
  final TextEditingController _gridEditorController = TextEditingController();
  final FocusNode _gridEditorFocus = FocusNode();

  int _rows = 8;
  int _columns = 16;
  double _left = 0;
  double _top = 0;
  double _cellWidth = 50;
  double _cellHeight = 38;

  bool _cameraRequested = false;
  bool _cameraRunning = false;
  String _cameraStatus = 'Камера выключена';
  double _cameraAspectRatio = 4 / 3;
  bool _calibrationLayerEnabled = false;
  bool _gridEnabled = true;
  ElectronicBoardCalibrationTool _calibrationTool =
      ElectronicBoardCalibrationTool.point;
  int _calibrationBackgroundColor = 0xFF050708;
  int _calibrationDrawColor = 0xFFFFF176;
  double _calibrationPointSize = 18;
  double _calibrationLineWidth = 8;
  final List<ElectronicBoardCalibrationMark> _calibrationMarks = [];
  List<ElectronicBoardCalibrationPoint>? _activeLine;

  String? _selectedCellId;
  final Map<String, String> _boardSquares = <String, String>{};
  final Map<String, double> _brightness = <String, double>{};
  final Map<String, double> _thresholds = <String, double>{};
  final Map<String, bool> _occupied = <String, bool>{};
  final Map<String, bool> _pendingStates = <String, bool>{};
  final Map<String, DateTime> _pendingSince = <String, DateTime>{};
  ElectronicBoardCellBrightness? _selectedCellBrightness;
  String? _draftThresholdCellId;
  double? _draftThreshold;
  String? _lastSavedThresholdCellId;
  Timer? _saveTimer;
  final GlobalKey<ElectronicBoardFloatingBoardState> _floatingBoardKey =
      GlobalKey<ElectronicBoardFloatingBoardState>();
  OverlayEntry? _floatingBoardEntry;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCalibration());
  }

  @override
  void dispose() {
    _floatingBoardEntry?.remove();
    _floatingBoardEntry = null;
    _saveTimer?.cancel();
    _rowsController.dispose();
    _columnsController.dispose();
    _leftController.dispose();
    _topController.dispose();
    _cellWidthController.dispose();
    _cellHeightController.dispose();
    _gridEditorController.dispose();
    _gridEditorFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCalibration() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw);
      if (data is! Map || !mounted) return;
      double number(Object? value, double fallback) =>
          value is num ? value.toDouble() : fallback;
      Map<String, double> numberMap(Object? value) => value is Map
          ? value.map((key, item) =>
              MapEntry('$key', number(item, 0).clamp(0, 255).toDouble()))
          : <String, double>{};
      setState(() {
        _rows = number(data['rows'], _rows.toDouble())
            .round()
            .clamp(1, 64)
            .toInt();
        _columns = number(data['columns'], _columns.toDouble())
            .round()
            .clamp(1, 64)
            .toInt();
        _left = number(data['left'], _left);
        _top = number(data['top'], _top);
        _cellWidth = number(data['cellWidth'], _cellWidth);
        _cellHeight = number(data['cellHeight'], _cellHeight);
        final mappings = data['boardSquares'];
        if (mappings is Map) {
          _boardSquares
            ..clear()
            ..addAll(mappings.map((key, value) => MapEntry('$key', '$value')));
        }
        _thresholds
          ..clear()
          ..addAll(numberMap(data['thresholds']));
        _calibrationBackgroundColor =
            number(data['calibrationBackgroundColor'],
                    _calibrationBackgroundColor.toDouble())
                .toInt();
        final rawMarks = data['calibrationMarks'];
        if (rawMarks is List) {
          _calibrationMarks
            ..clear()
            ..addAll(rawMarks
                .map(ElectronicBoardCalibrationMark.fromJson)
                .whereType<ElectronicBoardCalibrationMark>());
        }
        _syncGridControllers();
      });
    } catch (_) {
      // A damaged local profile must not prevent opening the calibration UI.
    }
  }

  void _syncGridControllers() {
    _rowsController.text = '$_rows';
    _columnsController.text = '$_columns';
    _leftController.text = _formatNumber(_left);
    _topController.text = _formatNumber(_top);
    _cellWidthController.text = _formatNumber(_cellWidth);
    _cellHeightController.text = _formatNumber(_cellHeight);
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_saveCalibration()),
    );
  }

  Future<void> _saveCalibration() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(<String, dynamic>{
        'version': 2,
        'rows': _rows,
        'columns': _columns,
        'left': _left,
        'top': _top,
        'cellWidth': _cellWidth,
        'cellHeight': _cellHeight,
        'boardSquares': _boardSquares,
        'thresholds': _thresholds,
        'calibrationBackgroundColor': _calibrationBackgroundColor,
        'calibrationMarks':
            _calibrationMarks.map((mark) => mark.toJson()).toList(),
      }),
    );
  }

  String _cellId(int row, int column) => 'V${row + 1}S${column + 1}';

  String _normalizedSquare(String value) => value.trim().toUpperCase();

  bool _isValidSquare(String value) =>
      value.isEmpty || RegExp(r'^[A-H][1-8]$').hasMatch(value);

  void _applyGrid() {
    final rows = int.tryParse(_rowsController.text.trim()) ?? _rows;
    final columns = int.tryParse(_columnsController.text.trim()) ?? _columns;
    final left = double.tryParse(_leftController.text.trim()) ?? _left;
    final top = double.tryParse(_topController.text.trim()) ?? _top;
    final cellWidth =
        double.tryParse(_cellWidthController.text.trim()) ?? _cellWidth;
    final cellHeight =
        double.tryParse(_cellHeightController.text.trim()) ?? _cellHeight;

    setState(() {
      _rows = rows.clamp(1, 64).toInt();
      _columns = columns.clamp(1, 64).toInt();
      _left = left.clamp(-4000, 4000).toDouble();
      _top = top.clamp(-4000, 4000).toDouble();
      _cellWidth = cellWidth.clamp(8, 400).toDouble();
      _cellHeight = cellHeight.clamp(8, 400).toDouble();

      _rowsController.text = '$_rows';
      _columnsController.text = '$_columns';
      _leftController.text = _formatNumber(_left);
      _topController.text = _formatNumber(_top);
      _cellWidthController.text = _formatNumber(_cellWidth);
      _cellHeightController.text = _formatNumber(_cellHeight);

      if (_selectedCellId != null && !_visibleCellIds.contains(_selectedCellId)) {
        _selectedCellId = null;
        _draftThresholdCellId = null;
        _draftThreshold = null;
        _gridEditorController.clear();
      }
    });
    _scheduleSave();
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  Set<String> get _visibleCellIds => <String>{
        for (var row = 0; row < _rows; row++)
          for (var column = 0; column < _columns; column++)
            _cellId(row, column),
      };

  void _toggleCamera() {
    setState(() {
      _cameraRequested = !_cameraRequested;
      if (_cameraRequested) {
        _cameraStatus = 'Запрашиваем доступ к камере...';
      } else {
        _cameraRunning = false;
        _cameraStatus = 'Камера выключена';
      }
    });
  }

  void _onCameraRunningChanged(bool running) {
    if (!mounted) return;
    setState(() {
      _cameraRunning = running;
      if (running) {
        _cameraStatus = 'Камера подключена';
      } else if (!_cameraRequested) {
        _cameraStatus = 'Камера выключена';
      }
    });
  }

  void _onCameraStatusChanged(String status) {
    if (!mounted) return;
    setState(() => _cameraStatus = status);
  }

  void _onCameraAspectRatioChanged(double? ratio) {
    if (!mounted) return;
    if (ratio == null || ratio <= 0) return;
    setState(() {
      _cameraAspectRatio = ratio;
    });
  }

  void _onCameraFailed() {
    if (!mounted) return;
    setState(() {
      _cameraRequested = false;
      _cameraRunning = false;
    });
  }

  void _selectCell(String id, {bool focusGridEditor = true}) {
    setState(() {
      _selectedCellId = id;
      _selectedCellBrightness = null;
      _draftThresholdCellId = id;
      _draftThreshold = _thresholds[id] ?? 128;
      _lastSavedThresholdCellId = null;
      _gridEditorController.text = _boardSquares[id] ?? '';
      _gridEditorController.selection = TextSelection.fromPosition(
        TextPosition(offset: _gridEditorController.text.length),
      );
    });
    if (focusGridEditor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _gridEditorFocus.requestFocus();
      });
    }
  }

  void _setSquare(String id, String value) {
    final normalized = _normalizedSquare(value);
    if (!_isValidSquare(normalized)) return;
    setState(() {
      if (normalized.isEmpty) {
        _boardSquares.remove(id);
      } else {
        _boardSquares[id] = normalized;
      }
      if (_selectedCellId == id && _gridEditorController.text != normalized) {
        _gridEditorController.text = normalized;
        _gridEditorController.selection = TextSelection.fromPosition(
          TextPosition(offset: normalized.length),
        );
      }
    });
    _scheduleSave();
  }

  void _clearMappings() {
    setState(() {
      _boardSquares.clear();
      _selectedCellId = null;
      _draftThresholdCellId = null;
      _draftThreshold = null;
      _gridEditorController.clear();
    });
    _scheduleSave();
  }

  List<ElectronicBoardScanRegion> _scanRegions({
    required double viewportWidth,
    required double videoHeight,
  }) {
    if (viewportWidth <= 0 || videoHeight <= 0) {
      return const <ElectronicBoardScanRegion>[];
    }
    return <ElectronicBoardScanRegion>[
      for (var row = 0; row < _rows; row++)
        for (var column = 0; column < _columns; column++)
          ElectronicBoardScanRegion(
            id: _cellId(row, column),
            left: (_left + column * _cellWidth) / viewportWidth,
            top: (_top + row * _cellHeight) / videoHeight,
            width: _cellWidth / viewportWidth,
            height: _cellHeight / videoHeight,
          ),
    ];
  }

  void _onBrightnessFrame(ElectronicBoardBrightnessFrame frame) {
    if (!mounted) return;
    final now = frame.capturedAt;
    var stateChanged = false;
    for (final entry in frame.values.entries) {
      final id = entry.key;
      final value = entry.value;
      _brightness[id] = value;
      final threshold = _draftThresholdCellId == id
          ? (_draftThreshold ?? _thresholds[id] ?? 128)
          : (_thresholds[id] ?? 128);
      final previous = _occupied[id];
      final detected = value < threshold;
      if (detected == previous) {
        _pendingStates.remove(id);
        _pendingSince.remove(id);
        continue;
      }
      if (_pendingStates[id] != detected) {
        _pendingStates[id] = detected;
        _pendingSince[id] = now;
        continue;
      }
      final since = _pendingSince[id];
      if (since != null && now.difference(since).inMilliseconds >= 320) {
        _occupied[id] = detected;
        _pendingStates.remove(id);
        _pendingSince.remove(id);
        stateChanged = true;
      }
    }
    final details = frame.selectedCell;
    if (details != null && details.id == _selectedCellId) {
      _selectedCellBrightness = details;
    }
    // Brightness values are diagnostic and should remain visibly live.
    setState(() {});
    _updateFloatingBoard();
    if (stateChanged) _scheduleSave();
  }

  bool get _allBoardSquaresMapped {
    final mapped = _boardSquares.entries
        .where((entry) => _visibleCellIds.contains(entry.key))
        .map((entry) => entry.value.toLowerCase())
        .where((square) => RegExp(r'^[a-h][1-8]$').hasMatch(square))
        .toSet();
    return mapped.length == 64;
  }

  void _updateFloatingBoard() {
    final occupiedSquares = <String>{};
    final brightnessBySquare = <String, double>{};
    for (final entry in _boardSquares.entries) {
      final square = entry.value.toLowerCase();
      if (!RegExp(r'^[a-h][1-8]$').hasMatch(square)) continue;
      if (_occupied[entry.key] == true) occupiedSquares.add(square);
      final brightness = _brightness[entry.key];
      if (brightness != null) brightnessBySquare[square] = brightness;
    }
    _floatingBoardKey.currentState?.updateOpticalPosition(
      occupiedSquares: occupiedSquares,
      brightnessBySquare: brightnessBySquare,
      allSquaresMapped: _allBoardSquaresMapped,
    );
  }

  void _toggleFloatingBoard() {
    final current = _floatingBoardEntry;
    if (current != null) {
      current.remove();
      _floatingBoardEntry = null;
      if (mounted) setState(() {});
      return;
    }
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => ElectronicBoardFloatingBoard(
        key: _floatingBoardKey,
        onClose: () {
          if (_floatingBoardEntry != entry) return;
          entry.remove();
          _floatingBoardEntry = null;
          if (mounted) setState(() {});
        },
      ),
    );
    _floatingBoardEntry = entry;
    overlay.insert(entry);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFloatingBoard());
  }

  void _setThreshold(String id, double value) {
    if (_selectedCellId != id) return;
    setState(() {
      _draftThresholdCellId = id;
      _draftThreshold = value;
      _lastSavedThresholdCellId = null;
    });
  }

  void _saveSelectedThreshold() {
    final id = _selectedCellId;
    final value = _draftThreshold;
    if (id == null || value == null) return;
    setState(() {
      _thresholds[id] = value;
      _lastSavedThresholdCellId = id;
    });
    _scheduleSave();
  }

  @override
  Widget build(BuildContext context) {
    final total = _rows * _columns;
    final assigned = _boardSquares.entries
        .where((entry) => _visibleCellIds.contains(entry.key))
        .length;

    return ListView(
      children: [
        _header(),
        const SizedBox(height: 16),
        _controls(),
        const SizedBox(height: 16),
        _opticsSettingsPanel(),
        const SizedBox(height: 16),
        _cameraAndGrid(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: MakeChessLocalizedText(
                'Сопоставления ячеек',
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 17),
              ),
            ),
            Text(
              '${MakeChessLocalization.phrase('Назначено')}: $assigned / $total',
              style: AppTextStyles.caption,
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _boardSquares.isEmpty ? null : _clearMappings,
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const MakeChessLocalizedText('Очистить сопоставления'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _mappingList(),
      ],
    );
  }

  Widget _header() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.accentGlowSoft,
                  borderRadius: AppRadius.r10,
                  border: Border.all(color: AppColors.accent.withOpacity(.55)),
                ),
                child: const Icon(
                  Icons.sensors_outlined,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MakeChessLocalizedText(
                  'Электронная доска',
                  style: AppTextStyles.sectionTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          MakeChessLocalizedText(
            'Настройка соответствия световых каналов клеткам шахматной доски.',
            style: AppTextStyles.bodyDim,
          ),
        ],
      );

  Widget _controls() => Container(
        padding: const EdgeInsets.all(14),
        decoration: AppDecorations.card(),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _numberField(
              width: 145,
              controller: _rowsController,
              label: 'V — ${MakeChessLocalization.phrase('Количество строк')}',
            ),
            _numberField(
              width: 165,
              controller: _columnsController,
              label: 'S — ${MakeChessLocalization.phrase('Количество столбцов')}',
            ),
            _numberField(
              width: 160,
              controller: _cellWidthController,
              label: MakeChessLocalization.phrase('Ширина ячейки'),
              suffix: 'px',
              decimal: true,
            ),
            _numberField(
              width: 160,
              controller: _cellHeightController,
              label: MakeChessLocalization.phrase('Высота ячейки'),
              suffix: 'px',
              decimal: true,
            ),
            _numberField(
              width: 175,
              controller: _leftController,
              label:
                  'L — ${MakeChessLocalization.phrase('Смещение по горизонтали')}',
              suffix: 'px',
              decimal: true,
            ),
            _numberField(
              width: 175,
              controller: _topController,
              label:
                  'R — ${MakeChessLocalization.phrase('Смещение по вертикали')}',
              suffix: 'px',
              decimal: true,
            ),
            FilledButton.icon(
              onPressed: _applyGrid,
              icon: const Icon(Icons.grid_4x4_outlined),
              label: const MakeChessLocalizedText('Применить сетку'),
            ),
          ],
        ),
      );

  Widget _numberField({
    required double width,
    required TextEditingController controller,
    required String label,
    String? suffix,
    bool decimal = false,
  }) =>
      SizedBox(
        width: width,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(
            signed: decimal,
            decimal: decimal,
          ),
          onSubmitted: (_) => _applyGrid(),
          decoration: InputDecoration(
            labelText: label,
            suffixText: suffix,
            isDense: true,
          ),
        ),
      );

  Widget _cameraAndGrid() => Container(
        padding: const EdgeInsets.all(12),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(
                  Icons.videocam_outlined,
                  size: 18,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                MakeChessLocalizedText(
                  'Изображение камеры',
                  style: AppTextStyles.buttonCompact,
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _toggleCamera,
                  icon: Icon(
                    _cameraRequested
                        ? Icons.videocam_off_outlined
                        : Icons.videocam_outlined,
                    size: 18,
                  ),
                  label: MakeChessLocalizedText(
                    _cameraRequested ? 'Выключить камеру' : 'Камера',
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () {
                    setState(() {
                      _calibrationLayerEnabled = !_calibrationLayerEnabled;
                      if (_calibrationLayerEnabled) _gridEnabled = false;
                    });
                  },
                  icon: Icon(
                    _calibrationLayerEnabled
                        ? Icons.layers_clear_outlined
                        : Icons.layers_outlined,
                    size: 18,
                  ),
                  label: const Text('Калибровочная подложка'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () => setState(() => _gridEnabled = !_gridEnabled),
                  icon: Icon(
                    _gridEnabled ? Icons.grid_off_outlined : Icons.grid_on,
                    size: 18,
                  ),
                  label: Text(
                    _gridEnabled ? 'Отключить сетку' : 'Включить сетку',
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _toggleFloatingBoard,
                  icon: Icon(
                    _floatingBoardEntry == null
                        ? Icons.grid_view_rounded
                        : Icons.close_fullscreen,
                    size: 18,
                  ),
                  label: Text(
                    _floatingBoardEntry == null ? 'Доска' : 'Закрыть доску',
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 190,
                  child: MakeChessLocalizedText(
                    _cameraStatus,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: _cameraRunning
                          ? Colors.greenAccent
                          : AppColors.textDim,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${MakeChessLocalization.phrase('Размер сетки')}: '
                  '${_formatNumber(_cellWidth * _columns)} × '
                  '${_formatNumber(_cellHeight * _rows)} px',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _calibrationToolbar(),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final viewportWidth = math.max(320.0, constraints.maxWidth);
                final viewportHeight = math.max(
                  260.0,
                  math.min(760.0, viewportWidth / _cameraAspectRatio),
                );
                final videoHeight = viewportWidth / _cameraAspectRatio;
                final gridWidth = _cellWidth * _columns;
                final gridHeight = _cellHeight * _rows;

                return ClipRRect(
                  borderRadius: AppRadius.r10,
                  child: SizedBox(
                    height: viewportHeight,
                    width: double.infinity,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ElectronicBoardCameraView(
                              active: _cameraRequested,
                              onRunningChanged: _onCameraRunningChanged,
                              onStatusChanged: _onCameraStatusChanged,
                              onFailed: _onCameraFailed,
                              onAspectRatioChanged: _onCameraAspectRatioChanged,
                              scanRegions: _scanRegions(
                                viewportWidth: viewportWidth,
                                videoHeight: _calibrationLayerEnabled
                                    ? viewportHeight
                                    : videoHeight,
                              ),
                              onBrightnessFrame: _onBrightnessFrame,
                              selectedRegionId: _selectedCellId,
                              calibrationEnabled: _calibrationLayerEnabled,
                              calibrationBackgroundColor:
                                  _calibrationBackgroundColor,
                              calibrationMarks: _calibrationMarks,
                              calibrationReferenceWidth: viewportWidth,
                              calibrationReferenceHeight: viewportHeight,
                            ),
                          ),
                        ),
                        if (!_cameraRunning)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: ColoredBox(
                                color: const Color(0xFF050708).withOpacity(.72),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _cameraRequested
                                            ? Icons.hourglass_top
                                            : Icons.videocam_off_outlined,
                                        color: Colors.white24,
                                        size: 42,
                                      ),
                                      const SizedBox(height: 8),
                                      MakeChessLocalizedText(
                                        _cameraStatus,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_calibrationLayerEnabled)
                          Positioned.fill(
                            child: IgnorePointer(
                              ignoring: _gridEnabled,
                              child: _calibrationDrawingLayer(
                                viewportWidth,
                                viewportHeight,
                              ),
                            ),
                          ),
                        Positioned(
                          left: _left,
                          top: _top,
                          width: gridWidth,
                          height: gridHeight,
                          child: IgnorePointer(
                            ignoring: !_gridEnabled,
                            child: _grid(_cellWidth, _cellHeight),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: MakeChessLocalizedText(
                    'По ширине отображается весь кадр камеры. Если высота больше, область просто становится выше.',
                    style: AppTextStyles.caption,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'L=${_formatNumber(_left)}  '
                  'R=${_formatNumber(_top)}  '
                  'W=${_formatNumber(_cellWidth)}  '
                  'H=${_formatNumber(_cellHeight)}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ],
        ),
      );

  Widget _calibrationToolbar() {
    final enabled = _calibrationLayerEnabled && !_gridEnabled;
    const colors = <int>[
      0xFF050708,
      0xFF303030,
      0xFFFFFFFF,
      0xFFFFF176,
      0xFFFF9800,
      0xFFF44336,
      0xFF4FC3F7,
      0xFF00E676,
    ];
    return Opacity(
      opacity: enabled ? 1 : .52,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            _calibrationLayerEnabled
                ? (_gridEnabled
                    ? 'Подложка: тестирование сеткой'
                    : 'Подложка: режим рисования')
                : 'Подложка выключена',
            style: AppTextStyles.caption,
          ),
          ChoiceChip(
            selected: _calibrationTool == ElectronicBoardCalibrationTool.fill,
            onSelected: enabled
                ? (_) => setState(() =>
                    _calibrationTool = ElectronicBoardCalibrationTool.fill)
                : null,
            avatar: const Icon(Icons.format_color_fill, size: 17),
            label: const Text('Заливка'),
          ),
          ChoiceChip(
            selected:
                _calibrationTool == ElectronicBoardCalibrationTool.point,
            onSelected: enabled
                ? (_) => setState(() =>
                    _calibrationTool = ElectronicBoardCalibrationTool.point)
                : null,
            avatar: const Icon(Icons.circle, size: 14),
            label: const Text('Точка'),
          ),
          ChoiceChip(
            selected: _calibrationTool == ElectronicBoardCalibrationTool.line,
            onSelected: enabled
                ? (_) => setState(() =>
                    _calibrationTool = ElectronicBoardCalibrationTool.line)
                : null,
            avatar: const Icon(Icons.horizontal_rule, size: 17),
            label: const Text('Линия'),
          ),
          const Text('Цвет:', style: TextStyle(fontSize: 12)),
          for (final color in colors)
            InkWell(
              onTap: enabled
                  ? () => setState(() => _calibrationDrawColor = color)
                  : null,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: Color(color),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _calibrationDrawColor == color
                        ? AppColors.accent
                        : Colors.white38,
                    width: _calibrationDrawColor == color ? 3 : 1,
                  ),
                ),
              ),
            ),
          SizedBox(
            width: 210,
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  child: Text(
                    _calibrationTool == ElectronicBoardCalibrationTool.line
                        ? 'Ширина'
                        : 'Размер',
                    style: AppTextStyles.caption,
                  ),
                ),
                Expanded(
                  child: Slider(
                    min: 1,
                    max: 100,
                    value: (_calibrationTool ==
                                ElectronicBoardCalibrationTool.line
                            ? _calibrationLineWidth
                            : _calibrationPointSize)
                        .clamp(1, 100)
                        .toDouble(),
                    onChanged: !enabled ||
                            _calibrationTool ==
                                ElectronicBoardCalibrationTool.fill
                        ? null
                        : (value) => setState(() {
                              if (_calibrationTool ==
                                  ElectronicBoardCalibrationTool.line) {
                                _calibrationLineWidth = value;
                              } else {
                                _calibrationPointSize = value;
                              }
                            }),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Отменить последний элемент',
            onPressed: enabled && _calibrationMarks.isNotEmpty
                ? () {
                    setState(() => _calibrationMarks.removeLast());
                    _scheduleSave();
                  }
                : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Очистить подложку',
            onPressed: enabled && _calibrationMarks.isNotEmpty
                ? () {
                    setState(_calibrationMarks.clear);
                    _scheduleSave();
                  }
                : null,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
    );
  }

  Widget _calibrationDrawingLayer(double width, double height) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final point = _normalizedCalibrationPoint(details.localPosition,
              width: width, height: height);
          setState(() {
            if (_calibrationTool == ElectronicBoardCalibrationTool.fill) {
              _calibrationBackgroundColor = _calibrationDrawColor;
            } else if (_calibrationTool ==
                ElectronicBoardCalibrationTool.point) {
              _calibrationMarks.add(ElectronicBoardCalibrationMark(
                tool: ElectronicBoardCalibrationTool.point,
                colorValue: _calibrationDrawColor,
                size: _calibrationPointSize,
                points: <ElectronicBoardCalibrationPoint>[point],
              ));
            }
          });
          _scheduleSave();
        },
        onPanStart: _calibrationTool == ElectronicBoardCalibrationTool.line
            ? (details) => setState(() {
                  _activeLine = <ElectronicBoardCalibrationPoint>[
                    _normalizedCalibrationPoint(details.localPosition,
                        width: width, height: height),
                  ];
                })
            : null,
        onPanUpdate: _calibrationTool == ElectronicBoardCalibrationTool.line
            ? (details) => setState(() {
                  _activeLine?.add(_normalizedCalibrationPoint(
                    details.localPosition,
                    width: width,
                    height: height,
                  ));
                })
            : null,
        onPanEnd: _calibrationTool == ElectronicBoardCalibrationTool.line
            ? (_) {
                final points = _activeLine;
                setState(() {
                  if (points != null && points.length > 1) {
                    _calibrationMarks.add(ElectronicBoardCalibrationMark(
                      tool: ElectronicBoardCalibrationTool.line,
                      colorValue: _calibrationDrawColor,
                      size: _calibrationLineWidth,
                      points: List<ElectronicBoardCalibrationPoint>.from(
                          points),
                    ));
                  }
                  _activeLine = null;
                });
                _scheduleSave();
              }
            : null,
        child: CustomPaint(
          painter: _CalibrationLayerPainter(
            backgroundColor: Color(_calibrationBackgroundColor),
            marks: _calibrationMarks,
            activeLine: _activeLine,
            activeColor: Color(_calibrationDrawColor),
            activeLineWidth: _calibrationLineWidth,
          ),
          child: const SizedBox.expand(),
        ),
      );

  ElectronicBoardCalibrationPoint _normalizedCalibrationPoint(
    Offset point, {
    required double width,
    required double height,
  }) =>
      ElectronicBoardCalibrationPoint(
        (point.dx / width).clamp(0, 1).toDouble(),
        (point.dy / height).clamp(0, 1).toDouble(),
      );

  Widget _grid(double cellWidth, double cellHeight) => Column(
        children: [
          for (var row = 0; row < _rows; row++)
            Row(
              children: [
                for (var column = 0; column < _columns; column++)
                  _gridCell(row, column, cellWidth, cellHeight),
              ],
            ),
        ],
      );

  Widget _gridCell(int row, int column, double width, double height) {
    final id = _cellId(row, column);
    final square = _boardSquares[id] ?? '';
    final selected = _selectedCellId == id;
    final occupied = _occupied[id];
    final brightness = _brightness[id];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectCell(id),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          // The calibration grid is an overlay and must never tint the image
          // that is being measured. Occupancy is shown by text/icons instead.
          color: Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.accent : const Color(0xFFFFE96A),
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: 3,
              top: 2,
              child: Text(
                id,
                style: TextStyle(
                  color: selected ? AppColors.accent : Colors.white60,
                  fontSize: math.max(7.0, math.min(10.0, height * .22)),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Positioned.fill(
              top: math.min(12.0, height * .30),
              child: Center(
                child: selected
                    ? SizedBox(
                        width: math.max(22.0, width - 8),
                        height: math.max(18.0, height - 14),
                        child: TextField(
                          controller: _gridEditorController,
                          focusNode: _gridEditorFocus,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 2,
                          style: TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: math.max(
                              9.0,
                              math.min(14.0, height * .34),
                            ),
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: const InputDecoration(
                            counterText: '',
                            isDense: true,
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                            border: InputBorder.none,
                            filled: false,
                          ),
                          onChanged: (value) => _setSquare(id, value),
                        ),
                      )
                    : Text(
                        square,
                        style: TextStyle(
                          color: square.isEmpty
                              ? Colors.transparent
                              : Colors.cyanAccent,
                          fontSize: math.max(
                            9.0,
                            math.min(14.0, height * .34),
                          ),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            if (brightness != null)
              Positioned(
                right: 2,
                bottom: 1,
                child: Text(
                  brightness.toStringAsFixed(0),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _opticsSettingsPanel() {
    final id = _selectedCellId;
    final square = id == null ? '' : (_boardSquares[id] ?? '');
    final brightness = id == null ? null : _brightness[id];
    final threshold = id == null
        ? 128.0
        : _draftThresholdCellId == id
            ? (_draftThreshold ?? _thresholds[id] ?? 128)
            : (_thresholds[id] ?? 128);
    final occupied = id == null ? null : _occupied[id];
    final details = _selectedCellBrightness?.id == id
        ? _selectedCellBrightness
        : null;
    int? row;
    int? column;
    if (id != null) {
      final match = RegExp(r'^V(\d+)S(\d+)$').firstMatch(id);
      row = int.tryParse(match?.group(1) ?? '');
      column = int.tryParse(match?.group(2) ?? '');
    }
    final x = column == null ? null : _left + (column - 1) * _cellWidth;
    final y = row == null ? null : _top + (row - 1) * _cellHeight;
    String gridArea = '';
    if (row != null && column != null) {
      final vertical = row <= _rows / 3
          ? 'верхняя часть'
          : row > _rows * 2 / 3
              ? 'нижняя часть'
              : 'середина по вертикали';
      final horizontal = column <= _columns / 3
          ? 'левый край'
          : column > _columns * 2 / 3
              ? 'правый край'
              : 'центр по горизонтали';
      gridArea = '$vertical · $horizontal';
    }
    String boardColor = '';
    if (RegExp(r'^[A-H][1-8]$').hasMatch(square)) {
      final file = square.codeUnitAt(0) - 'A'.codeUnitAt(0);
      final rank = int.parse(square.substring(1));
      boardColor = (file + rank).isOdd ? 'тёмное поле' : 'светлое поле';
    }
    final canSave = id != null && _draftThreshold != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                id == null ? 'Настраиваемая ячейка: не выбрана' : 'Ячейка: $id',
                style: AppTextStyles.buttonCompact
                    .copyWith(color: AppColors.accent),
              ),
              Text(
                row == null
                    ? 'Строка/столбец: —'
                    : 'Строка V$row · столбец S$column',
                style: AppTextStyles.caption,
              ),
              Text(
                x == null
                    ? 'Координаты камеры: —'
                    : 'Камера: x=${_formatNumber(x)}, '
                        'y=${_formatNumber(y!)}, '
                        '${_formatNumber(_cellWidth)}×${_formatNumber(_cellHeight)} px',
                style: AppTextStyles.caption,
              ),
              Text(
                gridArea.isEmpty
                    ? 'Расположение в сетке: —'
                    : 'Расположение: $gridArea',
                style: AppTextStyles.caption,
              ),
              Text(
                square.isEmpty
                    ? 'Поле доски: не назначено'
                    : 'Поле доски: $square · $boardColor',
                style: AppTextStyles.caption.copyWith(
                  color:
                      square.isEmpty ? AppColors.textDim : Colors.cyanAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _brightnessStudy(details),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 112,
                child: Text(
                  'Яркость: ${brightness?.toStringAsFixed(0) ?? '—'}',
                  style: AppTextStyles.caption,
                ),
              ),
              Expanded(
                child: Slider(
                  min: 0,
                  max: 255,
                  divisions: 255,
                  value: threshold.clamp(0, 255).toDouble(),
                  onChanged:
                      id == null ? null : (value) => _setThreshold(id, value),
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  'Порог: ${threshold.toStringAsFixed(0)}',
                  style: AppTextStyles.caption,
                ),
              ),
              Icon(
                occupied == null
                    ? Icons.help_outline
                    : occupied
                        ? Icons.block
                        : Icons.light_mode,
                color: occupied == null
                    ? AppColors.textDim
                    : occupied
                        ? Colors.redAccent
                        : Colors.greenAccent,
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 92,
                child: Text(
                  occupied == null
                      ? 'Нет данных'
                      : occupied
                          ? 'Фигура есть'
                          : 'Свободно',
                  style: AppTextStyles.caption,
                ),
              ),
              FilledButton.icon(
                onPressed: canSave ? _saveSelectedThreshold : null,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Запомнить настройку'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            id == null
                ? 'Выберите ячейку на сетке.'
                : _lastSavedThresholdCellId == id
                    ? 'Настройка $id сохранена: свободно от '
                        '${threshold.toStringAsFixed(0)} до 255; ниже — фигура есть.'
                : 'Свободно: яркость от ${threshold.toStringAsFixed(0)} до 255. '
                    'Ниже ${threshold.toStringAsFixed(0)} — фигура есть. '
                    'После изменения нажмите «Запомнить настройку».',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _brightnessStudy(ElectronicBoardCellBrightness? details) {
    if (details == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.12),
          borderRadius: AppRadius.r10,
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Opacity(
          opacity: .55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Паспорт светового пятна',
                  style: AppTextStyles.buttonCompact),
              const SizedBox(height: 6),
              Text(
                _cameraRunning && _selectedCellId != null
                    ? 'Получаем данные выбранной ячейки…'
                    : 'Выберите ячейку и включите камеру. Все измерения появятся здесь.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 8),
              const Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(label: Text('Средняя / min / max / P95')),
                  Chip(label: Text('Круговой профиль')),
                  Chip(label: Text('Вертикальный профиль ↑↓')),
                  Chip(label: Text('Горизонтальный профиль ←→')),
                  Chip(label: Text('Карта яркости')),
                  Chip(label: Text('Локальные максимумы')),
                  Chip(label: Text('Распределение пикселей')),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.12),
        borderRadius: AppRadius.r10,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 310,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _brightnessMetric('Средняя', details.average),
                _brightnessMetric('Максимальная', details.maximum),
                _brightnessMetric('Минимальная', details.minimum),
                _brightnessMetric('95-й процентиль', details.percentile95),
                _brightnessMetric(
                  'Разброс',
                  details.standardDeviation,
                ),
                _brightnessMetric(
                  'Точка максимума',
                  details.maximum,
                  suffix: '  (${details.maximumX}, ${details.maximumY})',
                ),
              ],
            ),
          ),
          SizedBox(
            width: 180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Максимум и радиусы', style: AppTextStyles.caption),
                const SizedBox(height: 6),
                Center(
                  child: CustomPaint(
                    size: const Size(168, 112),
                    painter: _BrightnessRadiusPainter(details),
                  ),
                ),
                Text(
                  'Область камеры: ${details.width}×${details.height} px',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Средняя яркость вокруг максимума',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 5),
                for (final entry in details.radialAverages.entries)
                  _radialBrightnessBar(entry.key, entry.value),
              ],
            ),
          ),
          SizedBox(
            width: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Профиль светового пятна', style: AppTextStyles.caption),
                const SizedBox(height: 5),
                _profileLegend(),
                for (final radius in details.radialAverages.keys)
                  _profileRow(details, radius),
              ],
            ),
          ),
          SizedBox(
            width: 270,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Карта яркости и максимумы', style: AppTextStyles.caption),
                const SizedBox(height: 6),
                CustomPaint(
                  size: const Size(256, 150),
                  painter: _BrightnessHeatmapPainter(details),
                ),
                const SizedBox(height: 5),
                Text(
                  details.peaks.isEmpty
                      ? 'Локальные максимумы: —'
                      : 'Локальных максимумов: ${details.peaks.length}',
                  style: AppTextStyles.caption,
                ),
                for (var index = 0; index < 4; index++)
                  SizedBox(
                    height: 17,
                    child: index < details.peaks.length
                        ? Text(
                            '${index + 1}. (${details.peaks[index].x}, '
                            '${details.peaks[index].y})  '
                            '${details.peaks[index].value.toStringAsFixed(1)} · '
                            'окрестность ${details.peaks[index].neighborhoodAverage.toStringAsFixed(1)}',
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            softWrap: false,
                            style: AppTextStyles.caption,
                          )
                        : null,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Направления от максимума', style: AppTextStyles.caption),
                const SizedBox(height: 5),
                for (final radius in details.radialAverages.keys)
                  _directionRow(details, radius),
              ],
            ),
          ),
          SizedBox(
            width: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Распределение пикселей', style: AppTextStyles.caption),
                const SizedBox(height: 5),
                for (var index = 0;
                    index < details.absoluteHistogram.length;
                    index++)
                  _percentageBar(
                    '${index * 32}–${math.min(255, index * 32 + 31)}',
                    details.absoluteHistogram[index],
                    Colors.lightBlueAccent,
                  ),
                const SizedBox(height: 5),
                Text('Относительно максимума', style: AppTextStyles.caption),
                for (final entry in details.relativeBrightnessShares.entries)
                  _percentageBar(
                    '≥ ${entry.key}%',
                    entry.value,
                    Colors.amberAccent,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _brightnessMetric(
    String label,
    double value, {
    String suffix = '',
  }) =>
      Container(
        width: 146,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF101A24),
          borderRadius: AppRadius.r10,
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: 2),
            Text(
              '${value.toStringAsFixed(1)}$suffix',
              style: AppTextStyles.buttonCompact.copyWith(
                color: Colors.cyanAccent,
              ),
            ),
          ],
        ),
      );

  Widget _profileLegend() => const Row(
        children: [
          SizedBox(width: 42),
          Expanded(child: Text('круг', style: TextStyle(fontSize: 10, color: Colors.cyanAccent))),
          Expanded(child: Text('гориз.', style: TextStyle(fontSize: 10, color: Colors.amberAccent))),
          Expanded(child: Text('вертик.', style: TextStyle(fontSize: 10, color: Colors.pinkAccent))),
        ],
      );

  Widget _profileRow(ElectronicBoardCellBrightness details, int radius) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            SizedBox(width: 42, child: Text('r=$radius', style: AppTextStyles.caption)),
            _profileValue(details.radialAverages[radius], Colors.cyanAccent),
            _profileValue(details.horizontalAverages[radius], Colors.amberAccent),
            _profileValue(details.verticalAverages[radius], Colors.pinkAccent),
          ],
        ),
      );

  Widget _profileValue(double? value, Color color) => Expanded(
        child: Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                minHeight: 6,
                value: ((value ?? 0) / 255).clamp(0, 1).toDouble(),
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(width: 3),
            SizedBox(
              width: 31,
              child: Text(
                value?.toStringAsFixed(0) ?? '—',
                style: AppTextStyles.caption,
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 5),
          ],
        ),
      );

  Widget _directionRow(ElectronicBoardCellBrightness details, int radius) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            SizedBox(
                width: 38,
                child: Text('r=$radius', style: AppTextStyles.caption)),
            _directionValue('←', details.leftAverages[radius]),
            _directionValue('→', details.rightAverages[radius]),
            _directionValue('↑', details.upAverages[radius]),
            _directionValue('↓', details.downAverages[radius]),
          ],
        ),
      );

  Widget _directionValue(String arrow, double? value) => Expanded(
        child: Text(
          '$arrow ${value?.toStringAsFixed(0) ?? '—'}',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(color: Colors.white70),
        ),
      );

  Widget _percentageBar(String label, double percent, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            SizedBox(width: 54, child: Text(label, style: AppTextStyles.caption)),
            Expanded(
              child: LinearProgressIndicator(
                minHeight: 7,
                value: (percent / 100).clamp(0, 1).toDouble(),
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 48,
              child: Text('${percent.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right, style: AppTextStyles.caption),
            ),
          ],
        ),
      );

  Widget _radialBrightnessBar(int radius, double value) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            SizedBox(
              width: 38,
              child: Text('r=$radius', style: AppTextStyles.caption),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: (value / 255).clamp(0, 1).toDouble(),
                  backgroundColor: Colors.white10,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                ),
              ),
            ),
            const SizedBox(width: 7),
            SizedBox(
              width: 38,
              child: Text(
                value.toStringAsFixed(1),
                textAlign: TextAlign.right,
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      );

  Widget _selectedOpticsEditor() {
    final id = _selectedCellId;
    final square = id == null ? '' : (_boardSquares[id] ?? '');
    final brightness = id == null ? null : _brightness[id];
    final threshold = id == null ? 128.0 : (_thresholds[id] ?? 128);
    final occupied = id == null ? null : _occupied[id];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.card(),
      child: Row(
        children: [
          SizedBox(
            width: 185,
            child: Text(
              id == null ? 'Выберите ячейку' : '$id → ${square.isEmpty ? '—' : square}',
              style: AppTextStyles.buttonCompact,
            ),
          ),
          Text(
            'Яркость: ${brightness?.toStringAsFixed(0) ?? '—'}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Slider(
              min: 0,
              max: 255,
              divisions: 255,
              value: threshold.clamp(0, 255).toDouble(),
              onChanged:
                  id == null ? null : (value) => _setThreshold(id, value),
            ),
          ),
          SizedBox(
            width: 92,
            child: Text(
              'Порог: ${threshold.toStringAsFixed(0)}',
              style: AppTextStyles.caption,
            ),
          ),
          Icon(
            occupied == null
                ? Icons.help_outline
                : occupied
                    ? Icons.block
                    : Icons.light_mode,
            color: occupied == null
                ? AppColors.textDim
                : occupied
                    ? Colors.redAccent
                    : Colors.greenAccent,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 92,
            child: Text(
              occupied == null
                  ? 'Нет данных'
                  : occupied
                      ? 'Фигура есть'
                      : 'Свободно',
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mappingList() {
    final count = _rows * _columns;
    return Container(
      height: 300,
      decoration: AppDecorations.card(),
      child: ListView.separated(
        padding: const EdgeInsets.all(10),
        itemCount: count,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          color: AppColors.borderSoft,
        ),
        itemBuilder: (context, index) {
          final row = index ~/ _columns;
          final column = index % _columns;
          final id = _cellId(row, column);
          final square = _boardSquares[id] ?? '';
          return SizedBox(
            height: 48,
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    id,
                    style: AppTextStyles.buttonCompact.copyWith(
                      color: _selectedCellId == id
                          ? AppColors.accent
                          : AppColors.text,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: AppColors.textDim,
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 150,
                  child: TextFormField(
                    key: ValueKey<String>('mapping-$id-$square'),
                    initialValue: square,
                    maxLength: 2,
                    textCapitalization: TextCapitalization.characters,
                    onTap: () => _selectCell(id, focusGridEditor: false),
                    onChanged: (value) => _setSquare(id, value),
                    decoration: InputDecoration(
                      labelText: MakeChessLocalization.phrase('Адрес клетки'),
                      hintText: 'C3',
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MakeChessLocalizedText(
                    square.isEmpty ? 'Не назначено' : 'Ячейка сетки',
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CalibrationLayerPainter extends CustomPainter {
  const _CalibrationLayerPainter({
    required this.backgroundColor,
    required this.marks,
    required this.activeLine,
    required this.activeColor,
    required this.activeLineWidth,
  });

  final Color backgroundColor;
  final List<ElectronicBoardCalibrationMark> marks;
  final List<ElectronicBoardCalibrationPoint>? activeLine;
  final Color activeColor;
  final double activeLineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    for (final mark in marks) {
      _drawMark(canvas, size, mark);
    }
    final preview = activeLine;
    if (preview != null && preview.isNotEmpty) {
      _drawLine(canvas, size, preview, activeColor, activeLineWidth);
    }
  }

  void _drawMark(
      Canvas canvas, Size size, ElectronicBoardCalibrationMark mark) {
    if (mark.points.isEmpty) return;
    final color = Color(mark.colorValue);
    if (mark.tool == ElectronicBoardCalibrationTool.point) {
      final point = mark.points.first;
      canvas.drawCircle(
        Offset(point.x * size.width, point.y * size.height),
        mark.size / 2,
        Paint()..color = color,
      );
    } else if (mark.tool == ElectronicBoardCalibrationTool.line) {
      _drawLine(canvas, size, mark.points, color, mark.size);
    }
  }

  void _drawLine(
    Canvas canvas,
    Size size,
    List<ElectronicBoardCalibrationPoint> points,
    Color color,
    double width,
  ) {
    if (points.isEmpty) return;
    final path = Path()
      ..moveTo(points.first.x * size.width, points.first.y * size.height);
    for (final point in points.skip(1)) {
      path.lineTo(point.x * size.width, point.y * size.height);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _CalibrationLayerPainter oldDelegate) => true;
}

class _BrightnessRadiusPainter extends CustomPainter {
  const _BrightnessRadiusPainter(this.details);

  final ElectronicBoardCellBrightness details;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(8)),
      Paint()..color = const Color(0xFF071018),
    );
    final scaleX = size.width / math.max(1, details.width);
    final scaleY = size.height / math.max(1, details.height);
    final maximum = Offset(
      (details.maximumX + .5) * scaleX,
      (details.maximumY + .5) * scaleY,
    );
    final rings = details.radialAverages.keys.toList()..sort();
    for (final radius in rings.reversed) {
      final value = details.radialAverages[radius] ?? 0;
      final normalized = (value / 255).clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(
        maximum,
        radius * (scaleX + scaleY) / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Color.lerp(
            Colors.blueGrey,
            Colors.cyanAccent,
            normalized,
          )!
              .withOpacity(.72),
      );
    }
    canvas.drawCircle(
      maximum,
      4,
      Paint()..color = Colors.yellowAccent,
    );
    canvas.drawCircle(
      maximum,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _BrightnessRadiusPainter oldDelegate) =>
      oldDelegate.details != details;
}

class _BrightnessHeatmapPainter extends CustomPainter {
  const _BrightnessHeatmapPainter(this.details);

  final ElectronicBoardCellBrightness details;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      Paint()..color = const Color(0xFF071018),
    );
    if (details.heatmap.isEmpty ||
        details.heatmapWidth <= 0 ||
        details.heatmapHeight <= 0) return;
    final cellWidth = size.width / details.heatmapWidth;
    final cellHeight = size.height / details.heatmapHeight;
    for (var y = 0; y < details.heatmapHeight; y++) {
      for (var x = 0; x < details.heatmapWidth; x++) {
        final value = details.heatmap[y * details.heatmapWidth + x];
        final normalized = (value / 255).clamp(0.0, 1.0).toDouble();
        canvas.drawRect(
          Rect.fromLTWH(x * cellWidth, y * cellHeight, cellWidth + .5,
              cellHeight + .5),
          Paint()
            ..color = Color.lerp(
              const Color(0xFF06101C),
              const Color(0xFFFFF6A0),
              normalized,
            )!,
        );
      }
    }
    final scaleX = size.width / math.max(1, details.width);
    final scaleY = size.height / math.max(1, details.height);
    final axisPaint = Paint()
      ..color = Colors.white.withOpacity(.55)
      ..strokeWidth = 1;
    final maximum = Offset(
      (details.maximumX + .5) * scaleX,
      (details.maximumY + .5) * scaleY,
    );
    canvas.drawLine(Offset(maximum.dx, 0), Offset(maximum.dx, size.height), axisPaint);
    canvas.drawLine(Offset(0, maximum.dy), Offset(size.width, maximum.dy), axisPaint);
    for (var index = 0; index < details.peaks.length; index++) {
      final peak = details.peaks[index];
      final point = Offset((peak.x + .5) * scaleX, (peak.y + .5) * scaleY);
      canvas.drawCircle(
        point,
        index == 0 ? 5 : 3.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = index == 0 ? 2 : 1.2
          ..color = index == 0 ? Colors.yellowAccent : Colors.cyanAccent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BrightnessHeatmapPainter oldDelegate) =>
      oldDelegate.details != details;
}
