// lib/services/webrtc_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Вставь сюда свои креды для TURN (Twilio/coturn).
/// Если пока тестируешь без кредов — оставь пустыми, но тогда relay работать не будет.
const String kTurnUsername =
    '<YOUR_TURN_USERNAME>'; // например, Twilio username
const String kTurnCredential =
    '<YOUR_TURN_PASSWORD>'; // например, Twilio credential

class WebRTCService {
  RTCPeerConnection? pc;
  MediaStream? localStream;

  // senders от addTrack
  RTCRtpSender? _audioSender;
  RTCRtpSender? _videoSender;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  // Храним последний собранный удалённый поток (для «ручной» склейки)
  MediaStream? _forcedRemote;

  Future<void> initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    localRenderer.muted = true; // не слышим себя
  }

  Future<void> getUserMedia({required bool video}) async {
    final constraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': video
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
              'frameRate': {'ideal': 30},
            }
          : false,
    };

    localStream = await navigator.mediaDevices.getUserMedia(constraints);
    localRenderer.srcObject = localStream;

    if (kDebugMode) {
      final a = localStream?.getAudioTracks().length ?? 0;
      final v = localStream?.getVideoTracks().length ?? 0;
      print('[GUM] local tracks -> audio:$a video:$v');
    }
  }

  Future<void> createPeer({
    required void Function(RTCIceCandidate c) onLocalIce,
    required void Function(MediaStream stream) onRemoteStream,
    List<Map<String, dynamic>>? iceServers,
  }) async {
    // --- ICE servers: STUN + TURN (udp/tcp/tls:443) ---
    final List<Map<String, dynamic>> servers = [
      // Быстрый прямой путь
      {'urls': 'stun:stun.l.google.com:19302'},

      // TURN (раскомментируй при наличии логина/пароля)
      if (kTurnUsername.isNotEmpty && kTurnCredential.isNotEmpty) ...[
        {
          // Twilio Network Traversal пример
          'urls': [
            'turn:global.turn.twilio.com:3478?transport=udp',
            'turn:global.turn.twilio.com:3478?transport=tcp',
            'turns:global.turn.twilio.com:443?transport=tcp',
          ],
          'username': kTurnUsername,
          'credential': kTurnCredential,
        },

        // Пример для своего coturn (раскомментируй и подставь хост/креды)
        // {
        //   'urls': [
        //     'turn:your.turn.host:3478?transport=udp',
        //     'turn:your.turn.host:3478?transport=tcp',
        //     'turns:your.turn.host:443?transport=tcp',
        //   ],
        //   'username': kTurnUsername,
        //   'credential': kTurnCredential,
        // },
      ],
    ];

    final config = <String, dynamic>{
      'sdpSemantics': 'unified-plan', // важно для Safari/Chromium
      'bundlePolicy': 'max-bundle',
      'iceServers': iceServers ?? servers,
      // 'iceTransportPolicy': 'all', // по умолчанию all
    };

    pc = await createPeerConnection(config);

    // Локальные ICE наружу
    pc!.onIceCandidate = (c) {
      if (c.candidate != null) onLocalIce(c);
    };

    // Основной путь: Unified-Plan
    pc!.onTrack = (evt) async {
      if (kDebugMode) {
        print('[onTrack] kind:${evt.track.kind} streams:${evt.streams.length}');
      }
      if (evt.streams.isNotEmpty) {
        remoteRenderer.srcObject = evt.streams.first;
        onRemoteStream(evt.streams.first);
      } else {
        final ms = await createLocalMediaStream('remote');
        ms.addTrack(evt.track);
        remoteRenderer.srcObject = ms;
        onRemoteStream(ms);
      }
    };

    // Plan-B fallback
    pc!.onAddStream = (stream) {
      if (kDebugMode) {
        print('[onAddStream] id=${stream.id} '
            'a:${stream.getAudioTracks().length} v:${stream.getVideoTracks().length}');
      }
      remoteRenderer.srcObject = stream;
      onRemoteStream(stream);
    };

    // Добавляем локальные треки ТОЛЬКО так — addTrack
    await _attachLocalTracks();

    // (при необходимости) потом можно вызвать forceBindRemoteIfNeeded(),
    // если у стороны не сработал onTrack.
  }

  Future<void> _attachLocalTracks() async {
    final ls = localStream;
    if (pc == null || ls == null) return;

    // audio
    final a = ls.getAudioTracks();
    if (a.isNotEmpty && _audioSender == null) {
      try {
        _audioSender = await pc!.addTrack(a.first, ls);
        if (kDebugMode) print('[attach] audio addTrack OK');
      } catch (e) {
        if (kDebugMode) print('[attach] audio addTrack error: $e');
      }
    }

    // video
    final v = ls.getVideoTracks();
    if (v.isNotEmpty && _videoSender == null) {
      try {
        _videoSender = await pc!.addTrack(v.first, ls);
        if (kDebugMode) print('[attach] video addTrack OK');
      } catch (e) {
        if (kDebugMode) print('[attach] video addTrack error: $e');
      }
    }
  }

  /// Может случиться, что onTrack не вызвался, хотя SDP применён.
  /// Тогда собираем удалённые дорожки вручную из pc.getReceivers().
  Future<void> forceBindRemoteIfNeeded() async {
    if (pc == null) return;

    if (remoteRenderer.srcObject != null) return; // уже есть поток

    final receivers = await pc!.getReceivers();
    final audioTracks = <MediaStreamTrack>[];
    final videoTracks = <MediaStreamTrack>[];

    for (final r in receivers) {
      final t = r.track;
      if (t == null) continue;
      if (t.kind == 'audio') audioTracks.add(t);
      if (t.kind == 'video') videoTracks.add(t);
    }

    if (audioTracks.isEmpty && videoTracks.isEmpty) {
      if (kDebugMode) print('[forceBind] no remote tracks yet');
      return;
    }

    _forcedRemote ??= await createLocalMediaStream('forcedRemote');

    // подчистим старые треки
    for (final t in List<MediaStreamTrack>.from(_forcedRemote!.getTracks())) {
      await _forcedRemote!.removeTrack(t);
      await t.stop();
    }
    for (final t in audioTracks) {
      await _forcedRemote!.addTrack(t);
    }
    for (final t in videoTracks) {
      await _forcedRemote!.addTrack(t);
    }

    remoteRenderer.srcObject = _forcedRemote;
    if (kDebugMode) {
      print('[forceBind] remote bound '
          'a:${audioTracks.length} v:${videoTracks.length}');
    }
  }

  /// На случай пересоздания локалки (камера/мик)
  Future<void> ensureLocalSenders() async => _attachLocalTracks();

  Future<RTCSessionDescription> createOffer({required bool wantVideo}) async {
    final offer = await pc!.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 1,
    });
    await pc!.setLocalDescription(offer);
    if (kDebugMode) {
      print('[SDP][OFFER] len=${offer.sdp?.length ?? 0}');
    }
    return offer;
  }

  Future<RTCSessionDescription> createAnswer({required bool wantVideo}) async {
    final answer = await pc!.createAnswer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 1,
    });
    await pc!.setLocalDescription(answer);
    if (kDebugMode) {
      print('[SDP][ANSWER] len=${answer.sdp?.length ?? 0}');
    }
    return answer;
  }

  Future<void> setRemoteDescription(String sdp, String type) async {
    await pc!.setRemoteDescription(RTCSessionDescription(sdp, type));
  }

  Future<void> addCandidate(RTCIceCandidate c) async {
    await pc?.addCandidate(c);
  }

  Future<void> setMicEnabled(bool enabled) async {
    for (final t in localStream?.getAudioTracks() ?? const []) {
      t.enabled = enabled;
    }
  }

  Future<void> setCamEnabled(bool enabled) async {
    for (final t in localStream?.getVideoTracks() ?? const []) {
      t.enabled = enabled;
    }
  }

  Future<void> dispose() async {
    try {
      for (final t in localStream?.getTracks() ?? const []) {
        await t.stop();
      }
      await localStream?.dispose();
    } catch (_) {}
    localStream = null;

    try {
      await pc?.close();
      await pc?.dispose();
    } catch (_) {}
    pc = null;

    try {
      await localRenderer.dispose();
    } catch (_) {}
    try {
      await remoteRenderer.dispose();
    } catch (_) {}

    _audioSender = null;
    _videoSender = null;

    try {
      await _forcedRemote?.dispose();
    } catch (_) {}
    _forcedRemote = null;
  }
}
