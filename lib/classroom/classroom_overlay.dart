import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Независимые плавающие окна видеокласса поверх сайта.
///
/// Каждый ученик получает собственное окно. Окна можно:
/// - перетаскивать мышкой за верхнюю полосу;
/// - менять по размеру за правый нижний угол;
/// - накладывать друг на друга независимо от шахматной доски и панелей сайта.
class ClassroomOverlay {
  ClassroomOverlay._();
  static final ClassroomOverlay instance = ClassroomOverlay._();

  static const String _localWindowId = '__classroom_local__';

  OverlayEntry? _entry;
  _OverlayState? _state;

  RTCVideoRenderer? _local;
  String _localTitle = 'Вы';
  final Map<String, _RemoteVideoEntry> _remotes =
      <String, _RemoteVideoEntry>{};
  final List<String> _zOrder = <String>[];

  void attach(BuildContext context) {
    if (_entry != null) return;
    _entry = OverlayEntry(
      builder: (_) => _Overlay(owner: this),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void _register(_OverlayState state) {
    _state = state;
    state.refresh();
  }

  void _unregister(_OverlayState state) {
    if (identical(_state, state)) _state = null;
  }

  void _notify() {
    _state?.refresh();
    _entry?.markNeedsBuild();
  }

  void _ensureWindowInOrder(String id) {
    if (!_zOrder.contains(id)) _zOrder.add(id);
  }

  void bringToFront(String id) {
    if (_zOrder.isNotEmpty && _zOrder.last == id) return;
    if (!_zOrder.remove(id)) return;
    _zOrder.add(id);
    _notify();
  }

  Future<void> dispose() async {
    _local = null;
    _remotes.clear();
    _zOrder.clear();
    _state?.refresh();
    _entry?.remove();
    _entry = null;
    _state = null;
  }

  Future<void> showLocal(
    RTCVideoRenderer renderer, {
    String label = 'Вы',
  }) async {
    _local = renderer;
    _localTitle = label;
    _ensureWindowInOrder(_localWindowId);
    _notify();
  }

  Future<void> addRemote(
    String peerId,
    String title,
    RTCVideoRenderer renderer, {
    bool waitingForVideo = false,
  }) async {
    _remotes[peerId] = _RemoteVideoEntry(
      renderer: renderer,
      title: title,
      waitingForVideo: waitingForVideo,
    );
    _ensureWindowInOrder(peerId);
    _notify();
  }

  Future<void> removeRemote(String peerId) async {
    _remotes.remove(peerId);
    _zOrder.remove(peerId);
    _notify();
  }
}

class _RemoteVideoEntry {
  const _RemoteVideoEntry({
    required this.renderer,
    required this.title,
    required this.waitingForVideo,
  });

  final RTCVideoRenderer renderer;
  final String title;
  final bool waitingForVideo;
}

class _Overlay extends StatefulWidget {
  const _Overlay({required this.owner});

  final ClassroomOverlay owner;

  @override
  State<_Overlay> createState() => _OverlayState();
}

class _OverlayState extends State<_Overlay> {
  @override
  void initState() {
    super.initState();
    widget.owner._register(this);
  }

  @override
  void dispose() {
    widget.owner._unregister(this);
    super.dispose();
  }

  void refresh() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.owner;
    final local = owner._local;
    final remotes = Map<String, _RemoteVideoEntry>.from(owner._remotes);
    final order = List<String>.from(owner._zOrder);

    return IgnorePointer(
      ignoring: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          final remoteIds = remotes.keys.toList(growable: false);
          final children = <Widget>[];

          for (final id in order) {
            if (id == ClassroomOverlay._localWindowId) {
              if (local == null) continue;
              children.add(
                _FloatingVideoWindow(
                  key: const ValueKey(ClassroomOverlay._localWindowId),
                  windowId: ClassroomOverlay._localWindowId,
                  title: owner._localTitle,
                  renderer: local,
                  local: true,
                  waitingForVideo: false,
                  screenSize: screenSize,
                  initialLeft: math.max(10.0, screenSize.width - 250.0),
                  initialTop: math.max(72.0, screenSize.height - 180.0),
                  initialWidth: 230.0,
                  initialHeight: 150.0,
                  onActivate: owner.bringToFront,
                ),
              );
              continue;
            }

            final entry = remotes[id];
            if (entry == null) continue;
            final index = remoteIds.indexOf(id);
            final column = index % 4;
            final row = index ~/ 4;
            children.add(
              _FloatingVideoWindow(
                key: ValueKey(id),
                windowId: id,
                title: entry.title,
                renderer: entry.renderer,
                waitingForVideo: entry.waitingForVideo,
                screenSize: screenSize,
                initialLeft: 10.0 + column * 34.0,
                initialTop: 76.0 + row * 34.0,
                initialWidth: screenSize.width < 760 ? 300.0 : 400.0,
                initialHeight: screenSize.width < 760 ? 200.0 : 250.0,
                onActivate: owner.bringToFront,
              ),
            );
          }

          return Stack(children: children);
        },
      ),
    );
  }
}

class _FloatingVideoWindow extends StatefulWidget {
  const _FloatingVideoWindow({
    super.key,
    required this.windowId,
    required this.title,
    required this.renderer,
    required this.screenSize,
    required this.initialLeft,
    required this.initialTop,
    required this.initialWidth,
    required this.initialHeight,
    required this.onActivate,
    this.local = false,
    this.waitingForVideo = false,
  });

  final String windowId;
  final String title;
  final RTCVideoRenderer renderer;
  final Size screenSize;
  final double initialLeft;
  final double initialTop;
  final double initialWidth;
  final double initialHeight;
  final ValueChanged<String> onActivate;
  final bool local;
  final bool waitingForVideo;

  @override
  State<_FloatingVideoWindow> createState() => _FloatingVideoWindowState();
}

class _FloatingVideoWindowState extends State<_FloatingVideoWindow> {
  static const double _titleHeight = 34;
  static const double _minWidth = 210;
  static const double _minHeight = 140;
  static const double _edge = 8;
  static const double _topLimit = 66;

  late double _left;
  late double _top;
  late double _width;
  late double _height;

  @override
  void initState() {
    super.initState();
    _left = widget.initialLeft;
    _top = widget.initialTop;
    _width = widget.initialWidth;
    _height = widget.initialHeight;
  }

  double _clampDouble(double value, double minimum, double maximum) {
    if (maximum < minimum) return minimum;
    return value.clamp(minimum, maximum).toDouble();
  }

  void _moveBy(Offset delta) {
    widget.onActivate(widget.windowId);
    setState(() {
      final maxLeft = math.max(_edge, widget.screenSize.width - _width - _edge);
      final maxTop = math.max(
        _topLimit,
        widget.screenSize.height - _height - _edge,
      );
      _left = _clampDouble(_left + delta.dx, _edge, maxLeft);
      _top = _clampDouble(_top + delta.dy, _topLimit, maxTop);
    });
  }

  void _resizeBy(Offset delta) {
    widget.onActivate(widget.windowId);
    setState(() {
      final maxWidth = math.max(
        _minWidth,
        widget.screenSize.width - _left - _edge,
      );
      final maxHeight = math.max(
        _minHeight,
        widget.screenSize.height - _top - _edge,
      );
      _width = _clampDouble(_width + delta.dx, _minWidth, maxWidth);
      _height = _clampDouble(_height + delta.dy, _minHeight, maxHeight);
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = math.max(
      _minWidth,
      widget.screenSize.width - _left - _edge,
    );
    final maxHeight = math.max(
      _minHeight,
      widget.screenSize.height - _top - _edge,
    );
    final width = _clampDouble(_width, _minWidth, maxWidth);
    final height = _clampDouble(_height, _minHeight, maxHeight);
    final maxLeft = math.max(_edge, widget.screenSize.width - width - _edge);
    final maxTop = math.max(
      _topLimit,
      widget.screenSize.height - height - _edge,
    );
    final left = _clampDouble(_left, _edge, maxLeft);
    final top = _clampDouble(_top, _topLimit, maxTop);

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        elevation: 18,
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => widget.onActivate(widget.windowId),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.local
                    ? const Color(0xFF58D7FF)
                    : Colors.white38,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    top: _titleHeight,
                    child: ColoredBox(
                      color: Colors.black,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RTCVideoView(
                            widget.renderer,
                            mirror: widget.local,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          ),
                          if (widget.waitingForVideo)
                            const ColoredBox(
                              color: Color(0xAA000000),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      color: Color(0xFF58D7FF),
                                      strokeWidth: 3,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Подключаем видео…',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.move,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (_) =>
                            widget.onActivate(widget.windowId),
                        onPanUpdate: (details) => _moveBy(details.delta),
                        child: Container(
                          height: _titleHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xEE171C24),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.local
                                    ? Icons.person
                                    : Icons.videocam_rounded,
                                color: widget.local
                                    ? const Color(0xFF58D7FF)
                                    : Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.open_with_rounded,
                                color: Colors.white38,
                                size: 15,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeDownRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (_) =>
                            widget.onActivate(widget.windowId),
                        onPanUpdate: (details) => _resizeBy(details.delta),
                        child: Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.bottomRight,
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.transparent, Colors.black54],
                            ),
                          ),
                          child: const Icon(
                            Icons.drag_handle,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
