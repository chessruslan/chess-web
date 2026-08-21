// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../localization/makechess_localization.dart';
/// Плавающее окно с возможностью перетаскивания, изменения размеров,
/// сворачивания и закрытия. Содержит RTCVideoView.
class VideoWindow extends StatefulWidget {
  const VideoWindow({
    super.key,
    required this.title,
    required this.renderer,
    this.mirror = false,
    this.initialLeft = 100,
    this.initialTop = 100,
    this.initialWidth = 380,
    this.initialHeight = 240,
    this.onClose,
  });

  final String title;
  final RTCVideoRenderer renderer;
  final bool mirror;

  final double initialLeft;
  final double initialTop;
  final double initialWidth;
  final double initialHeight;

  final VoidCallback? onClose;

  @override
  State<VideoWindow> createState() => _VideoWindowState();
}

class _VideoWindowState extends State<VideoWindow> {
  late double _left = widget.initialLeft;
  late double _top = widget.initialTop;
  late double _width = widget.initialWidth;
  late double _height = widget.initialHeight;

  bool _minimized = false;

  static const double _minW = 240;
  static const double _minH = 160;
  static const double _titleBarH = 32;

  Offset? _dragStart;
  Size? _dragStartSize;

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(12);
    final theme = Theme.of(context);

    Widget body;
    if (_minimized) {
      body = const SizedBox.shrink();
    } else {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(
          color: Colors.black,
          child: RTCVideoView(
            widget.renderer,
            mirror: widget.mirror,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
          ),
        ),
      );
    }

    return Positioned(
      left: _left,
      top: _top,
      width: _width,
      height: _minimized ? _titleBarH + 8 : _height,
      child: Material(
        elevation: 18,
        borderRadius: border,
        clipBehavior: Clip.antiAlias,
        color: theme.colorScheme.surface.withOpacity(0.92),
        child: Stack(
          children: [
            // Контент
            Positioned.fill(
              top: _titleBarH,
              child: body,
            ),
            // Тайтлбар (перетаскивание)
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (d) => _dragStart = d.globalPosition,
              onPanUpdate: (d) {
                if (_dragStart == null) return;
                final delta = d.globalPosition - _dragStart!;
                setState(() {
                  _left += delta.dx;
                  _top += delta.dy;
                });
                _dragStart = d.globalPosition;
              },
              child: Container(
                height: _titleBarH,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.9),
                ),
                child: Row(
                  children: [
                    MakeChessLocalizedText(widget.title, style: theme.textTheme.labelLarge),
                    const Spacer(),
                    IconButton(
                      tooltip: _minimized ? MakeChessLocalization.phrase('Развернуть') : MakeChessLocalization.phrase('Свернуть'),
                      icon:
                          Icon(_minimized ? Icons.crop_square : Icons.minimize),
                      onPressed: () => setState(() => _minimized = !_minimized),
                    ),
                    IconButton(
                      tooltip: MakeChessLocalization.phrase('Закрыть'),
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
            ),
            // Уголок для ресайза
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (d) {
                  _dragStart = d.globalPosition;
                  _dragStartSize = Size(_width, _height);
                },
                onPanUpdate: (d) {
                  if (_dragStart == null || _dragStartSize == null) return;
                  final delta = d.globalPosition - _dragStart!;
                  setState(() {
                    _width = max(_minW, _dragStartSize!.width + delta.dx);
                    _height = max(_minH, _dragStartSize!.height + delta.dy);
                  });
                },
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: Icon(Icons.drag_handle, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
