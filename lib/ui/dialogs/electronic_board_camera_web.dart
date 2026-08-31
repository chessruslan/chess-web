import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;

import 'electronic_board_optics.dart';

class ElectronicBoardCameraView extends StatefulWidget {
  const ElectronicBoardCameraView({
    super.key,
    required this.active,
    required this.onRunningChanged,
    required this.onStatusChanged,
    required this.onFailed,
    required this.onAspectRatioChanged,
    this.scanRegions = const <ElectronicBoardScanRegion>[],
    this.onBrightnessFrame,
    this.selectedRegionId,
    this.calibrationEnabled = false,
    this.calibrationBackgroundColor = 0xFF050708,
    this.calibrationMarks = const <ElectronicBoardCalibrationMark>[],
    this.calibrationReferenceWidth = 1,
    this.calibrationReferenceHeight = 1,
  });

  final bool active;
  final ValueChanged<bool> onRunningChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onFailed;
  final ValueChanged<double?> onAspectRatioChanged;
  final List<ElectronicBoardScanRegion> scanRegions;
  final ValueChanged<ElectronicBoardBrightnessFrame>? onBrightnessFrame;
  final String? selectedRegionId;
  final bool calibrationEnabled;
  final int calibrationBackgroundColor;
  final List<ElectronicBoardCalibrationMark> calibrationMarks;
  final double calibrationReferenceWidth;
  final double calibrationReferenceHeight;

  @override
  State<ElectronicBoardCameraView> createState() =>
      _ElectronicBoardCameraViewState();
}

class _ElectronicBoardCameraViewState
    extends State<ElectronicBoardCameraView> {
  late final String _viewType;
  late final html.VideoElement _video;
  html.MediaStream? _stream;
  bool _starting = false;
  Timer? _scanTimer;
  final html.CanvasElement _scanCanvas = html.CanvasElement();
  final html.CanvasElement _detailCanvas = html.CanvasElement();

  @override
  void initState() {
    super.initState();

    _viewType =
        'makechess-electronic-board-camera-${identityHashCode(this)}';

    _video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..controls = false;

    _video
      ..setAttribute('playsinline', 'true')
      ..setAttribute('aria-label', 'MakeChess electronic board camera');

    _video.style
      ..width = '100%'
      ..height = '100%'
      ..display = 'block'
      ..objectFit = 'contain'
      ..objectPosition = 'center top'
      ..backgroundColor = '#050708'
      ..pointerEvents = 'none';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId, {Object? params}) => _video,
    );

    if (widget.active) {
      unawaited(_startCamera());
    } else if (widget.calibrationEnabled) {
      _startScanner();
    }
  }

  @override
  void didUpdateWidget(covariant ElectronicBoardCameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        unawaited(_startCamera());
      } else {
        _stopCamera(reportStatus: true);
      }
    }
    if (oldWidget.calibrationEnabled != widget.calibrationEnabled) {
      if (widget.calibrationEnabled) {
        _startScanner();
      } else if (_stream == null) {
        _scanTimer?.cancel();
        _scanTimer = null;
      }
    }
  }

  Future<void> _startCamera() async {
    if (_starting || _stream != null) return;
    _starting = true;
    widget.onStatusChanged('Запрашиваем доступ к камере...');

    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw StateError('MediaDevices unavailable');
      }

      final stream = await mediaDevices.getUserMedia(<String, dynamic>{
        'video': true,
        'audio': false,
      });

      if (!mounted || !widget.active) {
        for (final track in stream.getTracks()) {
          track.stop();
        }
        return;
      }

      _stream = stream;
      _video.srcObject = stream;
      await _video.play();

      final width = _video.videoWidth;
      final height = _video.videoHeight;
      if (width > 0 && height > 0) {
        widget.onAspectRatioChanged(width / height);
      }

      if (!mounted) return;
      widget.onRunningChanged(true);
      _startScanner();
      widget.onStatusChanged('Камера подключена');
    } catch (_) {
      _stopCamera(reportStatus: false);
      if (!mounted) return;
      widget.onRunningChanged(false);
      widget.onStatusChanged('Не удалось открыть камеру');
      widget.onFailed();
    } finally {
      _starting = false;
    }
  }

  void _stopCamera({required bool reportStatus}) {
    _scanTimer?.cancel();
    _scanTimer = null;
    final stream = _stream;
    _stream = null;

    if (stream != null) {
      for (final track in stream.getTracks()) {
        track.stop();
      }
    }

    _video.pause();
    _video.srcObject = null;
    widget.onAspectRatioChanged(null);

    if (mounted) {
      widget.onRunningChanged(false);
      if (reportStatus) {
        widget.onStatusChanged('Камера выключена');
      }
    }
    if (widget.calibrationEnabled) _startScanner();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    final stream = _stream;
    _stream = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        track.stop();
      }
    }
    _video.pause();
    _video.srcObject = null;
    widget.onAspectRatioChanged(null);
    super.dispose();
  }

  void _startScanner() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(
      const Duration(milliseconds: 160),
      (_) => _scanBrightness(),
    );
  }

  void _scanBrightness() {
    final hasCamera =
        _stream != null && _video.videoWidth > 0 && _video.videoHeight > 0;
    if (!hasCamera && !widget.calibrationEnabled) return;
    final callback = widget.onBrightnessFrame;
    final regions = widget.scanRegions;
    if (callback == null || regions.isEmpty) return;

    const targetWidth = 320;
    final sourceWidth = hasCamera
        ? _video.videoWidth.toDouble()
        : math.max(1, widget.calibrationReferenceWidth);
    final sourceHeight = hasCamera
        ? _video.videoHeight.toDouble()
        : math.max(1, widget.calibrationReferenceHeight);
    final targetHeight = (targetWidth * sourceHeight / sourceWidth).round();
    if (targetHeight <= 0) return;
    _scanCanvas
      ..width = targetWidth
      ..height = targetHeight;
    final context = _scanCanvas.context2D;
    if (hasCamera) {
      context.drawImageScaled(_video, 0, 0, targetWidth, targetHeight);
    } else {
      context
        ..fillStyle = '#050708'
        ..fillRect(0, 0, targetWidth, targetHeight);
    }
    _drawCalibrationLayer(
      context,
      fullWidth: targetWidth.toDouble(),
      fullHeight: targetHeight.toDouble(),
      scale: targetWidth / math.max(1, widget.calibrationReferenceWidth),
    );

    final values = <String, double>{};
    for (final region in regions) {
      final left = (region.left.clamp(0.0, 1.0) * targetWidth).floor();
      final top = (region.top.clamp(0.0, 1.0) * targetHeight).floor();
      final right = ((region.left + region.width).clamp(0.0, 1.0) *
              targetWidth)
          .ceil();
      final bottom = ((region.top + region.height).clamp(0.0, 1.0) *
              targetHeight)
          .ceil();
      final width = right - left;
      final height = bottom - top;
      if (width < 1 || height < 1) continue;
      final pixels = context.getImageData(left, top, width, height).data;
      var luminance = 0.0;
      var count = 0;
      for (var offset = 0; offset + 2 < pixels.length; offset += 16) {
        luminance += pixels[offset] * .2126 +
            pixels[offset + 1] * .7152 +
            pixels[offset + 2] * .0722;
        count++;
      }
      if (count > 0) values[region.id] = luminance / count;
    }
    if (values.isNotEmpty) {
      ElectronicBoardCellBrightness? selectedCell;
      final selectedId = widget.selectedRegionId;
      if (selectedId != null) {
        for (final region in regions) {
          if (region.id == selectedId) {
            selectedCell = _measureSelectedCell(region);
            break;
          }
        }
      }
      callback(ElectronicBoardBrightnessFrame(
        values: values,
        capturedAt: DateTime.now(),
        selectedCell: selectedCell,
      ));
    }
  }

  ElectronicBoardCellBrightness? _measureSelectedCell(
    ElectronicBoardScanRegion region,
  ) {
    final hasCamera =
        _stream != null && _video.videoWidth > 0 && _video.videoHeight > 0;
    final videoWidth = hasCamera
        ? _video.videoWidth
        : math.max(1, widget.calibrationReferenceWidth).round();
    final videoHeight = hasCamera
        ? _video.videoHeight
        : math.max(1, widget.calibrationReferenceHeight).round();
    final sourceLeft =
        (region.left.clamp(0.0, 1.0) * videoWidth).floor();
    final sourceTop = (region.top.clamp(0.0, 1.0) * videoHeight).floor();
    final sourceRight = ((region.left + region.width).clamp(0.0, 1.0) *
            videoWidth)
        .ceil();
    final sourceBottom = ((region.top + region.height).clamp(0.0, 1.0) *
            videoHeight)
        .ceil();
    final width = sourceRight - sourceLeft;
    final height = sourceBottom - sourceTop;
    if (width < 1 || height < 1) return null;

    _detailCanvas
      ..width = width
      ..height = height;
    final context = _detailCanvas.context2D;
    if (hasCamera) {
      context.drawImageScaledFromSource(
        _video,
        sourceLeft,
        sourceTop,
        width,
        height,
        0,
        0,
        width,
        height,
      );
    }
    _drawCalibrationLayer(
      context,
      fullWidth: videoWidth.toDouble(),
      fullHeight: videoHeight.toDouble(),
      offsetX: -sourceLeft.toDouble(),
      offsetY: -sourceTop.toDouble(),
      scale: videoWidth / math.max(1, widget.calibrationReferenceWidth),
      fillWidth: width.toDouble(),
      fillHeight: height.toDouble(),
    );
    final pixels = context.getImageData(0, 0, width, height).data;
    if (pixels.isEmpty) return null;

    final luminance = List<double>.filled(width * height, 0);
    final histogram = List<int>.filled(256, 0);
    var sum = 0.0;
    var sumSquares = 0.0;
    var minimum = 255.0;
    var maximum = -1.0;
    var maximumX = 0;
    var maximumY = 0;
    for (var pixelIndex = 0; pixelIndex < luminance.length; pixelIndex++) {
      final offset = pixelIndex * 4;
      final value = pixels[offset] * .2126 +
          pixels[offset + 1] * .7152 +
          pixels[offset + 2] * .0722;
      luminance[pixelIndex] = value;
      histogram[value.round().clamp(0, 255).toInt()]++;
      sum += value;
      sumSquares += value * value;
      if (value < minimum) minimum = value;
      if (value > maximum) {
        maximum = value;
        maximumX = pixelIndex % width;
        maximumY = pixelIndex ~/ width;
      }
    }
    final count = luminance.length;
    final average = sum / count;
    final variance = math.max(0.0, sumSquares / count - average * average);
    final percentileTarget = (count * .95).ceil();
    var accumulated = 0;
    var percentile95 = 255.0;
    for (var value = 0; value < histogram.length; value++) {
      accumulated += histogram[value];
      if (accumulated >= percentileTarget) {
        percentile95 = value.toDouble();
        break;
      }
    }

    const radii = <int>[1, 2, 3, 4, 6, 8, 12, 16];
    final radialAverages = <int, double>{};
    final horizontalAverages = <int, double>{};
    final verticalAverages = <int, double>{};
    final leftAverages = <int, double>{};
    final rightAverages = <int, double>{};
    final upAverages = <int, double>{};
    final downAverages = <int, double>{};
    for (final radius in radii) {
      var radialSum = 0.0;
      var radialCount = 0;
      final radiusSquared = radius * radius;
      final minX = math.max(0, maximumX - radius).toInt();
      final maxX = math.min(width - 1, maximumX + radius).toInt();
      final minY = math.max(0, maximumY - radius).toInt();
      final maxY = math.min(height - 1, maximumY + radius).toInt();
      for (var y = minY; y <= maxY; y++) {
        for (var x = minX; x <= maxX; x++) {
          final dx = x - maximumX;
          final dy = y - maximumY;
          if (dx * dx + dy * dy > radiusSquared) continue;
          radialSum += luminance[y * width + x];
          radialCount++;
        }
      }
      if (radialCount > 0) {
        radialAverages[radius] = radialSum / radialCount;
      }
      var horizontalSum = 0.0;
      var horizontalCount = 0;
      for (var x = minX; x <= maxX; x++) {
        horizontalSum += luminance[maximumY * width + x];
        horizontalCount++;
      }
      var verticalSum = 0.0;
      var verticalCount = 0;
      for (var y = minY; y <= maxY; y++) {
        verticalSum += luminance[y * width + maximumX];
        verticalCount++;
      }
      if (horizontalCount > 0) {
        horizontalAverages[radius] = horizontalSum / horizontalCount;
      }
      if (verticalCount > 0) {
        verticalAverages[radius] = verticalSum / verticalCount;
      }
      double lineAverage(int fromX, int toX, int fromY, int toY) {
        var lineSum = 0.0;
        var lineCount = 0;
        for (var y = fromY; y <= toY; y++) {
          for (var x = fromX; x <= toX; x++) {
            lineSum += luminance[y * width + x];
            lineCount++;
          }
        }
        return lineCount == 0 ? 0 : lineSum / lineCount;
      }
      leftAverages[radius] =
          lineAverage(minX, maximumX, maximumY, maximumY);
      rightAverages[radius] =
          lineAverage(maximumX, maxX, maximumY, maximumY);
      upAverages[radius] =
          lineAverage(maximumX, maximumX, minY, maximumY);
      downAverages[radius] =
          lineAverage(maximumX, maximumX, maximumY, maxY);
    }

    final absoluteHistogram = List<double>.generate(8, (index) {
      var binCount = 0;
      final from = index * 32;
      final to = math.min(255, from + 31).toInt();
      for (var value = from; value <= to; value++) {
        binCount += histogram[value];
      }
      return binCount * 100 / count;
    });
    final relativeBrightnessShares = <int, double>{};
    for (final percent in const <int>[90, 75, 50, 25]) {
      final limit = maximum * percent / 100;
      var matching = 0;
      for (final value in luminance) {
        if (value >= limit) matching++;
      }
      relativeBrightnessShares[percent] = matching * 100 / count;
    }

    final peakCandidates = <ElectronicBoardBrightnessPeak>[];
    final peakFloor = math.max(percentile95, maximum * .60);
    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        final value = luminance[y * width + x];
        if (value < peakFloor) continue;
        var localMaximum = true;
        for (var dy = -1; dy <= 1 && localMaximum; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            if (luminance[(y + dy) * width + x + dx] > value) {
              localMaximum = false;
              break;
            }
          }
        }
        if (!localMaximum) continue;
        var neighborhoodSum = 0.0;
        var neighborhoodCount = 0;
        for (var ny = math.max(0, y - 2).toInt();
            ny <= math.min(height - 1, y + 2);
            ny++) {
          for (var nx = math.max(0, x - 2).toInt();
              nx <= math.min(width - 1, x + 2);
              nx++) {
            neighborhoodSum += luminance[ny * width + nx];
            neighborhoodCount++;
          }
        }
        peakCandidates.add(ElectronicBoardBrightnessPeak(
          x: x,
          y: y,
          value: value,
          neighborhoodAverage: neighborhoodSum / neighborhoodCount,
        ));
      }
    }
    peakCandidates.sort((a, b) => b.value.compareTo(a.value));
    final peaks = <ElectronicBoardBrightnessPeak>[];
    for (final candidate in peakCandidates) {
      final separated = peaks.every((peak) {
        final dx = peak.x - candidate.x;
        final dy = peak.y - candidate.y;
        return dx * dx + dy * dy >= 16;
      });
      if (separated) peaks.add(candidate);
      if (peaks.length == 8) break;
    }

    const heatmapWidth = 16;
    const heatmapHeight = 12;
    final heatmap = <double>[];
    for (var mapY = 0; mapY < heatmapHeight; mapY++) {
      final fromY = mapY * height ~/ heatmapHeight;
      final toY = math.max(fromY + 1, (mapY + 1) * height ~/ heatmapHeight);
      for (var mapX = 0; mapX < heatmapWidth; mapX++) {
        final fromX = mapX * width ~/ heatmapWidth;
        final toX = math.max(fromX + 1, (mapX + 1) * width ~/ heatmapWidth);
        var mapSum = 0.0;
        var mapCount = 0;
        for (var y = fromY; y < math.min(toY, height); y++) {
          for (var x = fromX; x < math.min(toX, width); x++) {
            mapSum += luminance[y * width + x];
            mapCount++;
          }
        }
        heatmap.add(mapCount == 0 ? 0 : mapSum / mapCount);
      }
    }
    return ElectronicBoardCellBrightness(
      id: region.id,
      width: width,
      height: height,
      average: average,
      minimum: minimum,
      maximum: maximum,
      percentile95: percentile95,
      standardDeviation: math.sqrt(variance),
      maximumX: maximumX,
      maximumY: maximumY,
      radialAverages: radialAverages,
      horizontalAverages: horizontalAverages,
      verticalAverages: verticalAverages,
      leftAverages: leftAverages,
      rightAverages: rightAverages,
      upAverages: upAverages,
      downAverages: downAverages,
      absoluteHistogram: absoluteHistogram,
      relativeBrightnessShares: relativeBrightnessShares,
      peaks: peaks,
      heatmapWidth: heatmapWidth,
      heatmapHeight: heatmapHeight,
      heatmap: heatmap,
    );
  }

  void _drawCalibrationLayer(
    html.CanvasRenderingContext2D context, {
    required double fullWidth,
    required double fullHeight,
    required double scale,
    double offsetX = 0,
    double offsetY = 0,
    double? fillWidth,
    double? fillHeight,
  }) {
    if (!widget.calibrationEnabled) return;
    context
      ..fillStyle = _cssColor(widget.calibrationBackgroundColor)
      ..fillRect(0, 0, fillWidth ?? fullWidth, fillHeight ?? fullHeight);
    for (final mark in widget.calibrationMarks) {
      if (mark.points.isEmpty ||
          mark.tool == ElectronicBoardCalibrationTool.fill) continue;
      context
        ..fillStyle = _cssColor(mark.colorValue)
        ..strokeStyle = _cssColor(mark.colorValue)
        ..lineWidth = math.max(1, mark.size * scale)
        ..lineCap = 'round'
        ..lineJoin = 'round';
      double x(ElectronicBoardCalibrationPoint point) =>
          point.x * fullWidth + offsetX;
      double y(ElectronicBoardCalibrationPoint point) =>
          point.y * fullHeight + offsetY;
      if (mark.tool == ElectronicBoardCalibrationTool.point) {
        final point = mark.points.first;
        context
          ..beginPath()
          ..arc(x(point), y(point), mark.size * scale / 2, 0, math.pi * 2)
          ..fill();
      } else {
        context
          ..beginPath()
          ..moveTo(x(mark.points.first), y(mark.points.first));
        for (final point in mark.points.skip(1)) {
          context.lineTo(x(point), y(point));
        }
        context.stroke();
      }
    }
  }

  String _cssColor(int value) =>
      '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF050708),
      child: HtmlElementView(
        viewType: _viewType,
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      ),
    );
  }
}
