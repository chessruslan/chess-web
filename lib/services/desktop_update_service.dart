import 'dart:async';

import 'desktop_update_service_stub.dart'
    if (dart.library.io) 'desktop_update_service_io.dart' as impl;

class DesktopUpdateService {
  DesktopUpdateService._();

  static final DesktopUpdateService instance = DesktopUpdateService._();

  Timer? _timer;
  bool _busy = false;

  void startAutomaticChecks() {
    if (_timer != null) return;
    Future<void>.delayed(const Duration(seconds: 8), _checkSafely);
    _timer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _checkSafely(),
    );
  }

  Future<void> _checkSafely() async {
    if (_busy) return;
    _busy = true;
    try {
      await impl.checkAndInstallIfNeeded();
    } catch (_) {
      // Offline, server errors and partial downloads must never block MakeChess.
    } finally {
      _busy = false;
    }
  }
}
