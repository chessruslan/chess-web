// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'video_window.dart';

import '../../localization/makechess_localization.dart';
/// Глобальный Overlay с двумя плавающими окнами видео (поверх всего).
class VideoOverlay {
  VideoOverlay._();
  static final VideoOverlay instance = VideoOverlay._();

  OverlayEntry? _entry;

  RTCVideoRenderer? _local;
  RTCVideoRenderer? _remote;
  DateTime? _waitingSince;
  bool _expectRemoteVideo = false;
  bool _slowDialogShown = false;
  Future<void> Function()? _onStopWaiting;

  void attach(BuildContext context) {
    if (_entry != null) return;
    _entry = OverlayEntry(builder: (_) => const _OverlayContent());
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void detach() {
    _entry?.remove();
    _entry = null;
  }

  void bindRenderers({
    required RTCVideoRenderer local,
    required RTCVideoRenderer remote,
    bool expectRemoteVideo = true,
    Future<void> Function()? onStopWaiting,
  }) {
    _local = local;
    _remote = remote;
    _expectRemoteVideo = expectRemoteVideo;
    _waitingSince = expectRemoteVideo ? DateTime.now() : null;
    _slowDialogShown = false;
    _onStopWaiting = onStopWaiting;
    _entry?.markNeedsBuild();
  }

  void unbindRenderers() {
    _local = null;
    _remote = null;
    _waitingSince = null;
    _expectRemoteVideo = false;
    _slowDialogShown = false;
    _onStopWaiting = null;
    _entry?.markNeedsBuild();
  }

  RTCVideoRenderer? get local => _local;
  RTCVideoRenderer? get remote => _remote;

  bool get hasRemoteVideo =>
      _remote?.srcObject?.getVideoTracks().isNotEmpty ?? false;

  bool get waitingForRemoteVideo => _expectRemoteVideo && !hasRemoteVideo;

  bool get shouldShowSlowDialog =>
      waitingForRemoteVideo &&
      !_slowDialogShown &&
      _waitingSince != null &&
      DateTime.now().difference(_waitingSince!) >= const Duration(minutes: 1);

  void markSlowDialogShown() => _slowDialogShown = true;

  Future<void> stopWaiting() async => _onStopWaiting?.call();
}

class _OverlayContent extends StatefulWidget {
  const _OverlayContent();

  @override
  State<_OverlayContent> createState() => _OverlayContentState();
}

class _OverlayContentState extends State<_OverlayContent> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // периодическая перерисовка — чтобы окна появлялись сразу после биндинга
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() {});
      if (VideoOverlay.instance.shouldShowSlowDialog) {
        VideoOverlay.instance.markSlowDialogShown();
        WidgetsBinding.instance.addPostFrameCallback((_) => _showSlowDialog());
      }
    });
  }

  Future<void> _showSlowDialog() async {
    if (!mounted || !VideoOverlay.instance.waitingForRemoteVideo) return;
    final stop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const MakeChessLocalizedText('Видео загружается дольше обычного'),
        content: const MakeChessLocalizedText(
          'Вы можете продолжить ожидание или остановить соединение '
          'и попробовать ещё раз либо позже.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const MakeChessLocalizedText('Продолжить ожидание'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const MakeChessLocalizedText('Остановить соединение'),
          ),
        ],
      ),
    );
    if (stop == true) await VideoOverlay.instance.stopWaiting();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final local = VideoOverlay.instance.local;
    final remote = VideoOverlay.instance.remote;
    final waitingForRemote = VideoOverlay.instance.waitingForRemoteVideo;

    return IgnorePointer(
      ignoring: false,
      child: Stack(
        children: [
          if (remote != null)
            VideoWindow(
              key: const ValueKey('remote_window'),
              title: 'Удалённое видео',
              renderer: remote,
              mirror: false,
              initialLeft: 680,
              initialTop: 110,
              initialWidth: 420,
              initialHeight: 300,
              waitingMessage: waitingForRemote
                  ? 'Идёт подключение удалённого видео. Пожалуйста, подождите.'
                  : null,
            ),
          if (local != null)
            VideoWindow(
              key: const ValueKey('local_window'),
              title: 'Моё видео',
              renderer: local,
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
