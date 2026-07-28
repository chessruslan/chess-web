import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../services/lobby_store.dart';
import 'ring_service.dart';
import 'voice_service.dart';
import 'video_overlay.dart';

/// Единая точка запуска/завершения звонков без модальных окон.
class CallCoordinator {
  CallCoordinator._();
  static final CallCoordinator instance = CallCoordinator._();

  final VoiceService _voice = VoiceService();
  bool _inCall = false;

  String roomIdFor(String a, String b) {
    final x = [a.trim(), b.trim()]..sort();
    return '${x[0]}__${x[1]}';
  }

  Future<void> _ensureMedia({required bool audioOnly}) async {
    // без проверки initialized — init должен быть идемпотентным
    await _voice.init(audioOnly: audioOnly);
  }

  void _bindOverlay({required bool expectRemoteVideo}) {
    VideoOverlay.instance.bindRenderers(
      local: _voice.localRenderer,
      remote: _voice.remoteRenderer,
      expectRemoteVideo: expectRemoteVideo,
      onStopWaiting: endCall,
    );
  }

  /// Исходящий звонок (вызывается из верхних кнопок «Аудио/Видео»).
  Future<void> startOutgoing(LobbyUser me, LobbyUser target,
      {required bool audioOnly}) async {
    final room = roomIdFor(me.username, target.username);

    try {
      await _ensureMedia(audioOnly: audioOnly);
    } catch (_) {
      if (audioOnly) rethrow;
      await _ensureMedia(audioOnly: true);
    }
    // On Flutter Web RTCVideoView must be created only after its renderer is
    // initialized and srcObject is assigned. Creating it earlier leaves the
    // underlying HTML video element permanently black.
    _bindOverlay(expectRemoteVideo: !audioOnly);

    await RingService.instance.sendRing(
      fromId: me.id,
      fromName: me.username,
      toId: target.id,
      toName: target.username,
      roomId: room,
      audioOnly: audioOnly,
    );

    await _voice.startCall(roomId: room, audioOnly: audioOnly);
    _inCall = true;
  }

  Future<void> hangup() async {
    try {
      await _voice.dispose();
    } catch (_) {}
    // если есть специализированные методы — можешь вызвать их здесь
    // (например: await _voice.stopCall(); или await _voice.endCall();)
  }

  /// Принятие входящего звонка (без модалки).
  Future<void> acceptIncoming(IncomingCall p) async {
    try {
      await _ensureMedia(audioOnly: p.audioOnly);
    } catch (_) {
      if (p.audioOnly) rethrow;
      await _ensureMedia(audioOnly: true);
    }
    _bindOverlay(expectRemoteVideo: !p.audioOnly);
    await _voice.joinCall(roomId: p.roomId, audioOnly: p.audioOnly);
    _inCall = true;
  }

  Future<void> endCall() async {
    try {
      await _voice.dispose();
    } catch (_) {}
    VideoOverlay.instance.unbindRenderers();
    _inCall = false;
  }

  bool get inCall => _inCall;
  RTCVideoRenderer get local => _voice.localRenderer;
  RTCVideoRenderer get remote => _voice.remoteRenderer;
}
