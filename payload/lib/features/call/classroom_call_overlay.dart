// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
// lib/features/call/classroom_call_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../call/voice_service.dart';

import '../../localization/makechess_localization.dart';
/// Простой оверлей «один-на-один».
class ClassroomCallOverlay extends StatefulWidget {
  const ClassroomCallOverlay({
    super.key,
    required this.roomId,
    required this.asTeacher,
  });

  final String roomId;
  final bool asTeacher;

  @override
  State<ClassroomCallOverlay> createState() => _ClassroomCallOverlayState();
}

class _ClassroomCallOverlayState extends State<ClassroomCallOverlay> {
  final VoiceService _voice = VoiceService();
  bool _starting = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      if (widget.asTeacher) {
        await _voice.startCall(roomId: widget.roomId, audioOnly: false);
      } else {
        await _voice.joinCall(roomId: widget.roomId, audioOnly: false);
      }
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  void dispose() {
    _voice.hangup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remote = _voice.remoteRenderer;
    final local = _voice.localRenderer;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 920,
        height: 560,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  MakeChessLocalizedText(
                    widget.asTeacher ? 'Учитель' : 'Ученик',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    tooltip: MakeChessLocalization.phrase('Завершить'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.call_end_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_starting)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Expanded(
                  child: Center(
                    child: MakeChessLocalizedText(
                      'Ошибка видеосвязи:\n$_error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else ...[
                // Удалённое видео крупно
                Expanded(
                  flex: 3,
                  child: _VideoTile(
                    renderer: remote,
                    label: widget.asTeacher ? 'Ученик' : 'Учитель',
                  ),
                ),
                const SizedBox(height: 10),
                // Локальное видео снизу небольшое
                SizedBox(
                  height: 130,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: _VideoTile(
                        renderer: local,
                        label: 'Вы',
                        mirror: true,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({
    required this.renderer,
    required this.label,
    this.mirror = false,
  });

  final RTCVideoRenderer renderer;
  final String label;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..scale(mirror ? -1.0 : 1.0, 1.0, 1.0),
              child: RTCVideoView(
                renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: MakeChessLocalizedText(
                  label,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
