// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../localization/makechess_localization.dart';
/// Один видеопоток видеокласса.
///
/// Этот объект используется одновременно:
/// - плавающими окнами видеосвязи;
/// - встроенными окнами в учительской компоновке.
class ClassroomVideoFeed {
  const ClassroomVideoFeed({
    required this.peerId,
    required this.title,
    required this.renderer,
    this.local = false,
    this.waitingForVideo = false,
  });

  final String peerId;
  final String title;
  final RTCVideoRenderer renderer;
  final bool local;
  final bool waitingForVideo;

  bool get hasVideo =>
      renderer.srcObject?.getVideoTracks().isNotEmpty ?? false;
}

/// Видеослой класса «учитель ↔ ученики».
///
/// Важно: старый рабочий механизм ожидания Overlay сохранён полностью.
/// Видеопоток может прийти раньше, чем Flutter успеет построить окно. В таком
/// случае он сохраняется в очереди и показывается после готовности Overlay.
///
/// Класс реализует [Listenable] вручную, а не наследуется от ChangeNotifier.
/// Это сохраняет рабочий асинхронный метод [dispose], который вызывается через
/// `await ClassroomOverlay.instance.dispose()`.
class ClassroomOverlay implements Listenable {
  ClassroomOverlay._();

  static final ClassroomOverlay instance = ClassroomOverlay._();

  final ChangeNotifier _changes = ChangeNotifier();

  OverlayEntry? _entry;
  _OverlayState? _state;
  Completer<void>? _ready;

  ({RTCVideoRenderer renderer, String label})? _pendingLocal;

  final Map<
      String,
      ({
        RTCVideoRenderer renderer,
        String title,
        bool waitingForVideo,
      })> _pendingRemotes = <
      String,
      ({
        RTCVideoRenderer renderer,
        String title,
        bool waitingForVideo,
      })>{};

  ClassroomVideoFeed? _localFeed;
  final Map<String, ClassroomVideoFeed> _remoteFeeds =
      <String, ClassroomVideoFeed>{};

  bool _dockAllRemotes = false;
  Set<String> _dockedRemoteIds = <String>{};

  // В режимах с одним встроенным видео остальные ученические потоки
  // продолжают работать, но не рисуются плавающими окнами. Локальное
  // видео учителя этим флагом никогда не скрывается.
  bool _hideUndockedRemotes = false;

  @override
  void addListener(VoidCallback listener) {
    _changes.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _changes.removeListener(listener);
  }

  void _notifyChanged() {
    _changes.notifyListeners();
    _entry?.markNeedsBuild();
  }

  ClassroomVideoFeed? get localFeed => _localFeed;

  Map<String, ClassroomVideoFeed> get remoteFeeds =>
      Map<String, ClassroomVideoFeed>.unmodifiable(_remoteFeeds);

  ClassroomVideoFeed? remoteFeedFor(String peerId) {
    final id = peerId.trim();
    if (id.isEmpty) return null;
    return _remoteFeeds[id];
  }

  bool get docksAllRemotes => _dockAllRemotes;

  Set<String> get dockedRemoteIds =>
      Set<String>.unmodifiable(_dockedRemoteIds);

  bool get hidesUndockedRemotes => _hideUndockedRemotes;

  bool isRemoteDocked(String peerId) {
    final id = peerId.trim();
    if (id.isEmpty) return false;
    return _dockAllRemotes || _dockedRemoteIds.contains(id);
  }

  /// Управляет только удалёнными видео учеников. Локальное видео учителя
  /// всегда остаётся отдельным плавающим окном.
  ///
  /// [dockAll] используется для режимов «видео над досками» и «все видео».
  /// [peerIds] используется для режимов, где в интерфейс встраивается только
  /// видео выбранного ученика.
  ///
  /// Если [hideUndocked] включён, остальные ученические видеопотоки остаются
  /// подключёнными, но не создают плавающих окон. Это нужно для компоновок
  /// «одно видео + 8 досок» и «одно видео + одна доска».
  void setRemoteDocking({
    required bool dockAll,
    Set<String> peerIds = const <String>{},
    bool hideUndocked = false,
  }) {
    final normalized = peerIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (_dockAllRemotes == dockAll &&
        _hideUndockedRemotes == hideUndocked &&
        _dockedRemoteIds.length == normalized.length &&
        _dockedRemoteIds.containsAll(normalized)) {
      return;
    }
    _dockAllRemotes = dockAll;
    _dockedRemoteIds = normalized;
    _hideUndockedRemotes = hideUndocked;
    _notifyChanged();
  }

  /// Совместимость с предыдущими версиями main.dart.
  /// true — встроить все удалённые видео учеников;
  /// false — вернуть их в плавающие окна.
  /// Локальное видео учителя этот метод не затрагивает.
  void setDocked(bool value) {
    setRemoteDocking(
      dockAll: value,
      hideUndocked: value,
    );
  }

  void showAllRemotesFloating() {
    setRemoteDocking(
      dockAll: false,
      hideUndocked: false,
    );
  }

  Future<void> attach(BuildContext context) async {
    final current = _entry;

    if (current != null && current.mounted && _state != null) {
      _flushPending();
      return;
    }

    // Если OverlayEntry уже вставлен, но его State ещё строится, сначала ждём
    // завершения текущего построения. Так не создаётся второй видеослой.
    if (current != null && current.mounted && _state == null) {
      final ready = _ready;
      if (ready != null && !ready.isCompleted) {
        try {
          await ready.future.timeout(const Duration(seconds: 2));
        } catch (_) {
          // Ниже старый неготовый слой будет удалён и создан заново.
        }
      }

      if (_state != null) {
        _flushPending();
        return;
      }

      if (current.mounted) {
        current.remove();
      }
    }

    // Старый объект мог пережить перестройку интерфейса, хотя его OverlayEntry
    // уже был снят. Удаляем такую «мёртвую» ссылку и создаём окно заново.
    _entry = null;
    _state = null;
    _ready = Completer<void>();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      _ready = null;
      throw StateError('Корневой Overlay для видеокласса не найден');
    }

    final entry = OverlayEntry(
      builder: (_) => _Overlay(
        host: (state) {
          _state = state;

          final ready = _ready;
          if (ready != null && !ready.isCompleted) {
            ready.complete();
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _flushPending();
          });
        },
      ),
    );

    _entry = entry;
    overlay.insert(entry);

    final ready = _ready;
    if (_state == null && ready != null && !ready.isCompleted) {
      await ready.future.timeout(const Duration(seconds: 2));
    }

    _flushPending();
  }

  void _flushPending() {
    final state = _state;
    if (state == null || !state.mounted) return;

    final local = _pendingLocal;
    if (local != null) {
      _pendingLocal = null;
      state.showLocal(
        local.renderer,
        label: local.label,
      );
    }

    final remotes = Map<
        String,
        ({
          RTCVideoRenderer renderer,
          String title,
          bool waitingForVideo,
        })>.from(_pendingRemotes);

    _pendingRemotes.clear();

    for (final entry in remotes.entries) {
      state.addRemote(
        entry.key,
        entry.value.title,
        entry.value.renderer,
        waitingForVideo: entry.value.waitingForVideo,
      );
    }
  }

  Future<void> dispose() async {
    _pendingLocal = null;
    _pendingRemotes.clear();

    _localFeed = null;
    _remoteFeeds.clear();
    _dockAllRemotes = false;
    _dockedRemoteIds = <String>{};
    _hideUndockedRemotes = false;
    _notifyChanged();

    final state = _state;
    _state = null;
    if (state != null && state.mounted) {
      state.clear();
    }

    final current = _entry;
    _entry = null;
    _ready = null;

    if (current != null && current.mounted) {
      current.remove();
    }
  }

  Future<void> showLocal(
    RTCVideoRenderer renderer, {
    String label = 'Вы',
  }) async {
    final normalizedLabel = label.trim().isEmpty ? 'Вы' : label.trim();

    _localFeed = ClassroomVideoFeed(
      peerId: '__local__',
      title: normalizedLabel,
      renderer: renderer,
      local: true,
    );

    _pendingLocal = (
      renderer: renderer,
      label: normalizedLabel,
    );

    _notifyChanged();
    _flushPending();
  }

  Future<void> addRemote(
    String peerId,
    String title,
    RTCVideoRenderer renderer, {
    bool waitingForVideo = false,
  }) async {
    final id = peerId.trim();
    if (id.isEmpty) return;

    final normalizedTitle = title.trim().isEmpty ? 'Ученик' : title.trim();

    _remoteFeeds[id] = ClassroomVideoFeed(
      peerId: id,
      title: normalizedTitle,
      renderer: renderer,
      waitingForVideo: waitingForVideo,
    );

    _pendingRemotes[id] = (
      renderer: renderer,
      title: normalizedTitle,
      waitingForVideo: waitingForVideo,
    );

    _notifyChanged();
    _flushPending();
  }

  Future<void> removeRemote(String peerId) async {
    final id = peerId.trim();
    if (id.isEmpty) return;

    _pendingRemotes.remove(id);
    final removed = _remoteFeeds.remove(id);

    final state = _state;
    if (state != null && state.mounted) {
      state.removeRemote(id);
    }

    if (removed != null) {
      _notifyChanged();
    }
  }
}

class _Overlay extends StatefulWidget {
  const _Overlay({required this.host});

  final void Function(_OverlayState state) host;

  @override
  State<_Overlay> createState() => _OverlayState();
}

class _OverlayState extends State<_Overlay> {
  RTCVideoRenderer? _local;
  String _localTitle = 'Вы';

  final Map<
      String,
      ({
        RTCVideoRenderer renderer,
        String title,
        bool waitingForVideo,
      })> _remotes = <
      String,
      ({
        RTCVideoRenderer renderer,
        String title,
        bool waitingForVideo,
      })>{};

  @override
  void initState() {
    super.initState();
    widget.host(this);
  }

  void showLocal(
    RTCVideoRenderer renderer, {
    required String label,
  }) {
    if (!mounted) return;
    setState(() {
      _local = renderer;
      _localTitle = label;
    });
  }

  void addRemote(
    String peerId,
    String title,
    RTCVideoRenderer renderer, {
    required bool waitingForVideo,
  }) {
    if (!mounted) return;
    setState(() {
      _remotes[peerId] = (
        renderer: renderer,
        title: title,
        waitingForVideo: waitingForVideo,
      );
    });
  }

  void removeRemote(String peerId) {
    if (!mounted) return;
    setState(() {
      _remotes.remove(peerId);
    });
  }

  void clear() {
    if (!mounted) return;
    setState(() {
      _local = null;
      _remotes.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ClassroomOverlay.instance,
      builder: (context, _) {
        final overlay = ClassroomOverlay.instance;
        final visibleRemotes = overlay.hidesUndockedRemotes
            ? _remotes.entries
                .where((_) => false)
                .toList(growable: false)
            : _remotes.entries
                .where(
                  (entry) => !overlay.isRemoteDocked(entry.key),
                )
                .toList(growable: false);

        // Локальное видео не зависит от компоновки: у учителя оно всегда
        // остаётся плавающим. У ученика сохраняется прежнее плавающее окно.
        if (visibleRemotes.isEmpty && _local == null) {
          return const SizedBox.shrink();
        }

        return IgnorePointer(
          ignoring: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final maxHeight = constraints.maxHeight;
              final remoteWidth = maxWidth < 900 ? 300.0 : 360.0;
              final remoteHeight = remoteWidth * 0.66;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var index = 0;
                      index < visibleRemotes.length;
                      index++)
                    _ClassroomFloatingWindow(
                      key: ValueKey(
                        'classroom_remote_${visibleRemotes[index].key}',
                      ),
                      feed: ClassroomVideoFeed(
                        peerId: visibleRemotes[index].key,
                        title: visibleRemotes[index].value.title,
                        renderer: visibleRemotes[index].value.renderer,
                        waitingForVideo:
                            visibleRemotes[index].value.waitingForVideo,
                      ),
                      initialLeft: 24.0 + (index % 4) * 42.0,
                      initialTop: 92.0 + (index % 4) * 38.0,
                      initialWidth: remoteWidth,
                      initialHeight: remoteHeight,
                      boundaryWidth: maxWidth,
                      boundaryHeight: maxHeight,
                    ),
                  if (_local != null)
                    _ClassroomFloatingWindow(
                      key: const ValueKey('classroom_local_teacher'),
                      feed: ClassroomVideoFeed(
                        peerId: '__local__',
                        title: _localTitle,
                        renderer: _local!,
                        local: true,
                      ),
                      initialLeft: 18.0,
                      initialTop: math.max(92.0, maxHeight - 280.0).toDouble(),
                      initialWidth: maxWidth < 900 ? 260.0 : 320.0,
                      initialHeight: maxWidth < 900 ? 180.0 : 220.0,
                      boundaryWidth: maxWidth,
                      boundaryHeight: maxHeight,
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _ClassroomFloatingWindow extends StatefulWidget {
  const _ClassroomFloatingWindow({
    super.key,
    required this.feed,
    required this.initialLeft,
    required this.initialTop,
    required this.initialWidth,
    required this.initialHeight,
    required this.boundaryWidth,
    required this.boundaryHeight,
  });

  final ClassroomVideoFeed feed;
  final double initialLeft;
  final double initialTop;
  final double initialWidth;
  final double initialHeight;
  final double boundaryWidth;
  final double boundaryHeight;

  @override
  State<_ClassroomFloatingWindow> createState() =>
      _ClassroomFloatingWindowState();
}

class _ClassroomFloatingWindowState
    extends State<_ClassroomFloatingWindow> {
  late double _left = widget.initialLeft;
  late double _top = widget.initialTop;
  late double _width = widget.initialWidth;
  late double _height = widget.initialHeight;
  bool _minimized = false;
  Offset? _dragStart;
  Size? _resizeStart;

  static const double _titleHeight = 34.0;
  static const double _minWidth = 220.0;
  static const double _minHeight = 150.0;

  double _clampLeft(double value) {
    final maximum = math.max(0.0, widget.boundaryWidth - _width);
    return value.clamp(0.0, maximum).toDouble();
  }

  double _clampTop(double value) {
    final visibleHeight = _minimized ? _titleHeight : _height;
    final maximum = math.max(0.0, widget.boundaryHeight - visibleHeight);
    return value.clamp(0.0, maximum).toDouble();
  }

  @override
  void didUpdateWidget(covariant _ClassroomFloatingWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _left = _clampLeft(_left);
    _top = _clampTop(_top);
  }

  @override
  Widget build(BuildContext context) {
    final actualHeight = _minimized ? _titleHeight : _height;
    return Positioned(
      left: _clampLeft(_left),
      top: _clampTop(_top),
      width: _width,
      height: actualHeight,
      child: Material(
        elevation: 18,
        color: const Color(0xFF151C25),
        borderRadius: BorderRadius.circular(11),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (!_minimized)
              Positioned.fill(
                top: _titleHeight,
                child: ClassroomVideoTile(
                  feed: widget.feed,
                  compact: false,
                ),
              ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) {
                _dragStart = details.globalPosition;
              },
              onPanUpdate: (details) {
                final start = _dragStart;
                if (start == null) return;
                final delta = details.globalPosition - start;
                setState(() {
                  _left = _clampLeft(_left + delta.dx);
                  _top = _clampTop(_top + delta.dy);
                });
                _dragStart = details.globalPosition;
              },
              child: Container(
                height: _titleHeight,
                padding: const EdgeInsets.only(left: 10, right: 4),
                color: const Color(0xFF27303B),
                child: Row(
                  children: [
                    Expanded(
                      child: MakeChessLocalizedText(
                        widget.feed.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _minimized ? MakeChessLocalization.phrase('Развернуть') : MakeChessLocalization.phrase('Свернуть'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      onPressed: () {
                        setState(() {
                          _minimized = !_minimized;
                          _top = _clampTop(_top);
                        });
                      },
                      icon: Icon(
                        _minimized ? Icons.crop_square : Icons.minimize,
                        size: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!_minimized)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) {
                    _dragStart = details.globalPosition;
                    _resizeStart = Size(_width, _height);
                  },
                  onPanUpdate: (details) {
                    final start = _dragStart;
                    final size = _resizeStart;
                    if (start == null || size == null) return;
                    final delta = details.globalPosition - start;
                    setState(() {
                      _width = math.max(_minWidth, size.width + delta.dx).toDouble();
                      _height = math.max(_minHeight, size.height + delta.dy).toDouble();
                      _width = math.min(
                        _width,
                        math.max(_minWidth, widget.boundaryWidth - _left),
                      ).toDouble();
                      _height = math.min(
                        _height,
                        math.max(_minHeight, widget.boundaryHeight - _top),
                      ).toDouble();
                    });
                  },
                  child: const SizedBox(
                    width: 26,
                    height: 26,
                    child: Icon(
                      Icons.drag_handle,
                      color: Colors.white70,
                      size: 17,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Универсальная видеоплитка.
///
/// Она используется и внутри плавающего Overlay, и непосредственно в
/// учительской области рядом с соответствующей доской ученика.
class ClassroomVideoTile extends StatelessWidget {
  const ClassroomVideoTile({
    super.key,
    required this.feed,
    this.onTap,
    this.compact = false,
  });

  final ClassroomVideoFeed feed;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final waiting = feed.waitingForVideo && !feed.hasVideo;
    final radius = compact ? 8.0 : 12.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: feed.local ? const Color(0xFF58D7FF) : Colors.white24,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - 1),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RTCVideoView(
                  feed.renderer,
                  mirror: feed.local,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
                if (waiting)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF58D7FF),
                      strokeWidth: 3,
                    ),
                  ),
                Positioned(
                  left: compact ? 5 : 8,
                  right: compact ? 5 : null,
                  bottom: compact ? 5 : 7,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 6 : 8,
                          vertical: compact ? 3 : 4,
                        ),
                        child: MakeChessLocalizedText(
                          feed.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 10 : 12,
                            fontWeight: FontWeight.w700,
                          ),
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
    );
  }
}
