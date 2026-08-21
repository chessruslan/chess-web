import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../localization/makechess_localization.dart';
import '../app_style.dart';
import 'electronic_board_camera.dart';

class ElectronicBoardCalibrationPanel extends StatefulWidget {
  const ElectronicBoardCalibrationPanel({super.key});

  @override
  State<ElectronicBoardCalibrationPanel> createState() =>
      _ElectronicBoardCalibrationPanelState();
}

class _ElectronicBoardCalibrationPanelState
    extends State<ElectronicBoardCalibrationPanel> {
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

  String? _selectedCellId;
  final Map<String, String> _boardSquares = <String, String>{};

  @override
  void dispose() {
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
        _gridEditorController.clear();
      }
    });
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
  }

  void _clearMappings() {
    setState(() {
      _boardSquares.clear();
      _selectedCellId = null;
      _gridEditorController.clear();
    });
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
            Row(
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
                const SizedBox(width: 12),
                Expanded(
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
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final viewportWidth = math.max(320.0, constraints.maxWidth);
                final viewportHeight = math.max(
                  260.0,
                  math.min(760.0, viewportWidth / _cameraAspectRatio),
                );
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
                          child: ElectronicBoardCameraView(
                            active: _cameraRequested,
                            onRunningChanged: _onCameraRunningChanged,
                            onStatusChanged: _onCameraStatusChanged,
                            onFailed: _onCameraFailed,
                            onAspectRatioChanged: _onCameraAspectRatioChanged,
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
                        Positioned(
                          left: _left,
                          top: _top,
                          width: gridWidth,
                          height: gridHeight,
                          child: _grid(_cellWidth, _cellHeight),
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectCell(id),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withOpacity(.14)
              : Colors.black.withOpacity(.08),
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
          ],
        ),
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
