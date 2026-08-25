import 'package:flutter/foundation.dart';

@immutable
class ElectronicBoardScanRegion {
  const ElectronicBoardScanRegion({
    required this.id,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String id;
  final double left;
  final double top;
  final double width;
  final double height;
}

@immutable
class ElectronicBoardBrightnessFrame {
  const ElectronicBoardBrightnessFrame({
    required this.values,
    required this.capturedAt,
    this.selectedCell,
  });

  final Map<String, double> values;
  final DateTime capturedAt;
  final ElectronicBoardCellBrightness? selectedCell;
}

@immutable
class ElectronicBoardCellBrightness {
  const ElectronicBoardCellBrightness({
    required this.id,
    required this.width,
    required this.height,
    required this.average,
    required this.minimum,
    required this.maximum,
    required this.percentile95,
    required this.standardDeviation,
    required this.maximumX,
    required this.maximumY,
    required this.radialAverages,
    required this.horizontalAverages,
    required this.verticalAverages,
    required this.leftAverages,
    required this.rightAverages,
    required this.upAverages,
    required this.downAverages,
    required this.absoluteHistogram,
    required this.relativeBrightnessShares,
    required this.peaks,
    required this.heatmapWidth,
    required this.heatmapHeight,
    required this.heatmap,
  });

  final String id;
  final int width;
  final int height;
  final double average;
  final double minimum;
  final double maximum;
  final double percentile95;
  final double standardDeviation;
  final int maximumX;
  final int maximumY;
  final Map<int, double> radialAverages;
  final Map<int, double> horizontalAverages;
  final Map<int, double> verticalAverages;
  final Map<int, double> leftAverages;
  final Map<int, double> rightAverages;
  final Map<int, double> upAverages;
  final Map<int, double> downAverages;

  /// Eight equal brightness ranges: 0-31, 32-63, ... 224-255.
  final List<double> absoluteHistogram;

  /// Shares of pixels whose brightness is at least 90%, 75%, 50% and 25%
  /// of the brightest pixel in this cell.
  final Map<int, double> relativeBrightnessShares;
  final List<ElectronicBoardBrightnessPeak> peaks;
  final int heatmapWidth;
  final int heatmapHeight;
  final List<double> heatmap;
}

@immutable
class ElectronicBoardBrightnessPeak {
  const ElectronicBoardBrightnessPeak({
    required this.x,
    required this.y,
    required this.value,
    required this.neighborhoodAverage,
  });

  final int x;
  final int y;
  final double value;
  final double neighborhoodAverage;
}
