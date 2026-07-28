import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'video_window.dart';

/// Синглтон, который держит OverlayEntry с двумя плавающими окнами видео.
class VideoOverlay {
  VideoOverlay._();
  static final VideoOverlay instance = VideoOverlay._();

  OverlayEntry? _entry;
  BuildContext? _host;

  RTCVideoRenderer? _boundLocal;
  RTCVideoRenderer? _boundRemote;

  String _localTitle = 'Моё видео';
  String _remoteTitle = 'Удалённое видео';

  // Подключаемся к Overlay из корневого виджета (AppShell).
  void attach(BuildContext context) {
    if (_entry != null) return;
    _host = context;

    _entry = OverlayEntry(
      builder: (_) => _OverlayContent(
        localTitle: _localTitle,
        remoteTitle: _remoteTitle,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void detach() {
    _entry?.remove();
    _entry = null;
    _host = null;
  }

  void bindRenderers({
    required RTCVideoRenderer local,
    required RTCVideoRenderer remote,
  }) {
    _boundLocal = local;
    _boundRemote = remote;
    _markNeedsBuild();
  }

  void unbindRenderers() {
    _boundLocal = null;
    _boundRemote = null;
    _markNeedsBuild();
  }

  set titles((String, String) pair) {
    _localTitle = pair.$1;
    _remoteTitle = pair.$2;
    _markNeedsBuild();
  }

  RTCVideoRenderer? get boundLocal => _boundLocal;
  RTCVideoRenderer? get boundRemote => _boundRemote;

  void _markNeedsBuild() {
    _entry?.markNeedsBuild();
  }
}

class _OverlayContent extends StatefulWidget {
  const _OverlayContent({
    required this.localTitle,
    required this.remoteTitle,
  });

  final String localTitle;
  final String remoteTitle;

  @override
  State<_OverlayContent> createState() => _OverlayContentState();
}

class _OverlayContentState extends State<_OverlayContent> {
  @override
  Widget build(BuildContext context) {
    final localR = VideoOverlay.instance.boundLocal;
    final remoteR = VideoOverlay.instance.boundRemote;

    final hasLocal = localR?.srcObject != null;
    final hasRemote = remoteR?.srcObject != null;

    if (!hasLocal && !hasRemote) return const SizedBox.shrink();

    return IgnorePointer(
      // окна должны реагировать на мышь
      ignoring: false,
      child: Stack(
        children: [
          if (hasRemote)
            VideoWindow(
              key: const ValueKey('remote_window'),
              title: widget.remoteTitle,
              renderer: remoteR!,
              mirror: false,
              initialLeft: 680,
              initialTop: 110,
              initialWidth: 420,
              initialHeight: 300,
            ),
          if (hasLocal)
            VideoWindow(
              key: const ValueKey('local_window'),
              title: widget.localTitle,
              renderer: localR!,
              mirror: true,
              initialLeft: 980,
              initialTop: 430,
              initialWidth: 320,
              initialHeight: 220,
            ),
        ],
      ),
    );
  }
}
