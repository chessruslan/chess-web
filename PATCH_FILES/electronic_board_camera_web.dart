import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;

class ElectronicBoardCameraView extends StatefulWidget {
  const ElectronicBoardCameraView({
    super.key,
    required this.active,
    required this.onRunningChanged,
    required this.onStatusChanged,
    required this.onFailed,
    required this.onAspectRatioChanged,
  });

  final bool active;
  final ValueChanged<bool> onRunningChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onFailed;
  final ValueChanged<double?> onAspectRatioChanged;

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
    }
  }

  @override
  void didUpdateWidget(covariant ElectronicBoardCameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;

    if (widget.active) {
      unawaited(_startCamera());
    } else {
      _stopCamera(reportStatus: true);
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
  }

  @override
  void dispose() {
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
