// lib/features/call/video_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../services/webrtc_service.dart';
import '../../services/webrtc_service.dart'; // <-- твой сервис




/// Обёртка над WebRTCService для видеозвонка:
/// - хранит тумблеры микрофона/камеры/динамика
/// - переключение фронт/тыл (мобильные)
/// - делегирует низкоуровневые операции в WebRTCService
class VideoService {
  final WebRTCService _rtc = WebRTCService();

  // Стейты для UI (если удобно подписываться)
  final ValueNotifier<bool> micOn = ValueNotifier<bool>(true);
  final ValueNotifier<bool> camOn = ValueNotifier<bool>(true);
  final ValueNotifier<bool> speakerOn = ValueNotifier<bool>(true);
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  RTCVideoRenderer get localRenderer => _rtc.localRenderer;
  RTCVideoRenderer get remoteRenderer => _rtc.remoteRenderer;
  MediaStream? get localStream => _rtc.localStream;
  RTCPeerConnection? get pc => _rtc.pc;

  // ---------- Лайф-цикл ----------

  Future<void> init({required bool withVideo}) async {
    await _rtc.initRenderers();
    await _rtc.getUserMedia(video: withVideo);
    micOn.value = true;
    camOn.value = withVideo;
  }

  Future<void> dispose() async {
    await _rtc.dispose();
  }

  // ---------- Peer / SDP / ICE ----------

  Future<void> createPeer({
    required void Function(RTCIceCandidate) onLocalIce,
    required void Function(MediaStream) onRemoteStream,
  }) =>
      _rtc.createPeer(onLocalIce: onLocalIce, onRemoteStream: onRemoteStream);

  Future<RTCSessionDescription> createOffer() =>
      _rtc.createOffer(wantVideo: true);

  Future<RTCSessionDescription> createAnswer() =>
      _rtc.createAnswer(wantVideo: true);

  Future<void> setRemoteDescription(String sdp, String type) =>
      _rtc.setRemoteDescription(sdp, type);

  Future<void> addCandidate(RTCIceCandidate c) => _rtc.addCandidate(c);

  // ---------- Управление устройствами ----------

  Future<void> setMicEnabled(bool enabled) async {
    await _rtc.setMicEnabled(enabled);
    micOn.value = enabled;
  }

  Future<void> toggleMic() => setMicEnabled(!micOn.value);

  Future<void> setCamEnabled(bool enabled) async {
    await _rtc.setCamEnabled(enabled);
    camOn.value = enabled;
  }

  Future<void> toggleCam() => setCamEnabled(!camOn.value);

  /// Переключение фронтальная/тыловая (ТОЛЬКО Android/iOS).
  /// На web это не поддерживается Helper.switchCamera.
  Future<void> switchCamera() async {
    if (kIsWeb) {
      lastError.value = 'Switch camera не поддерживается в Web.';
      return;
    }
    try {
      final stream = _rtc.localStream;
      if (stream == null) {
        lastError.value = 'Нет локального видеопотока';
        return;
      }
      final tracks = stream.getVideoTracks();
      if (tracks.isEmpty) {
        lastError.value = 'VideoTracks пуст';
        return;
      }
      final MediaStreamTrack track = tracks.first; // <-- НЕ nullable
      await Helper.switchCamera(track);
    } catch (e) {
      lastError.value = 'Switch camera error: $e';
    }
  }

  /// Вывод в динамик (Android/iOS). На web игнорируется.
  Future<void> setSpeakerEnabled(bool enabled) async {
    if (!kIsWeb) {
      try {
        await Helper.setSpeakerphoneOn(enabled);
        speakerOn.value = enabled;
      } catch (e) {
        lastError.value = 'Audio route error: $e';
      }
    }
  }
}
