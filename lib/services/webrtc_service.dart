// lib/services/webrtc_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Вставь сюда свои креды для TURN (Twilio/coturn).
/// Если пока тестируешь без кредов — оставь пустыми, но тогда relay работать не будет.
const String kTurnUsername = 'makechess';
const String kTurnCredential = 'MakechessRelay2026Strong';

/// Включить для отладки «первого» коннекта.
/// Когда true — используем только TURN (iceTransportPolicy=relay).
const bool forceRelayForDebug = false;

class WebRTCService {
  RTCPeerConnection? pc;
  MediaStream? localStream;

  // senders от addTrack
  RTCRtpSender? _audioSender;
  RTCRtpSender? _videoSender;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool _renderersInitialized = false;

  // Храним последний собранный удалённый поток (для «ручной» склейки)
  MediaStream? _forcedRemote;

  // ==== УСТОЙЧИВОСТЬ ПЕРВОГО КОННЕКТА ====
  // Буфер входящих remote ICE до момента, когда удалённый SDP применён
  final List<RTCIceCandidate> _remoteIceBuffer = [];
  bool _remoteSdpSet = false;

  // Одноразовый таймер «подтолкнуть» первый коннект (ICE-restart)
  Timer? _firstConnectKickTimer;

  Future<void> initRenderers() async {
    if (_renderersInitialized) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _renderersInitialized = true;
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

    try {
      localStream = await navigator.mediaDevices.getUserMedia(constraints);
    } catch (firstError) {
      if (!video) rethrow;

      // Some Windows/Chrome configurations temporarily report NotFoundError
      // for the combined camera+microphone request. Retry once with generic
      // constraints, then keep video working even when no microphone exists.
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': true,
        });
      } catch (_) {
        try {
          localStream = await navigator.mediaDevices.getUserMedia({
            'audio': false,
            'video': true,
          });
        } catch (_) {
          final devices = await navigator.mediaDevices.enumerateDevices();
          final cameras = devices.where((d) => d.kind == 'videoinput').length;
          final microphones =
              devices.where((d) => d.kind == 'audioinput').length;
          throw Exception(
            'Камера недоступна: браузер обнаружил камер: $cameras, '
            'микрофонов: $microphones. Исходная ошибка: $firstError',
          );
        }
      }
    }
    localRenderer.srcObject = localStream;

    if (kDebugMode) {
      final a = localStream?.getAudioTracks().length ?? 0;
      final v = localStream?.getVideoTracks().length ?? 0;
      print('[GUM] local tracks -> audio:$a video:$v');
    }
  }

  /// Пересоздание ТОЛЬКО PeerConnection (без трогания рендереров и localStream).
  Future<void> _disposePeerOnly() async {
    _firstConnectKickTimer?.cancel();
    _firstConnectKickTimer = null;

    _remoteIceBuffer.clear();
    _remoteSdpSet = false;

    try {
      await pc?.close();
      await pc?.dispose();
    } catch (_) {}
    pc = null;

    _audioSender = null;
    _videoSender = null;

    // Не трогаем: localStream, localRenderer, remoteRenderer, _forcedRemote
  }

  Future<void> createPeer({
    required void Function(RTCIceCandidate c) onLocalIce,
    required void Function(MediaStream stream) onRemoteStream,
    List<Map<String, dynamic>>? iceServers,
  }) async {
    // На всякий случай: перед каждым звонком пересоздаём PC => чистое состояние
    if (pc != null) {
      if (kDebugMode) print('[PC] recreate before new call');
      await _disposePeerOnly();
    }

    // --- ICE servers: STUN + TURN (udp/tcp/tls:443) ---
    final List<Map<String, dynamic>> servers = [
      {'urls': 'stun:stun.l.google.com:19302'},
      if (kTurnUsername.isNotEmpty && kTurnCredential.isNotEmpty) ...[
        {
          // Twilio Network Traversal пример
          'urls': [
            'turn:111.88.227.25:3478?transport=udp',
            'turn:111.88.227.25:3478?transport=tcp',
          ],
          'username': kTurnUsername,
          'credential': kTurnCredential,
        },
        // // Пример для своего coturn
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
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'iceServers': iceServers ?? servers,
      if (forceRelayForDebug) 'iceTransportPolicy': 'relay', // ← только TURN
    };

    pc = await createPeerConnection(config);

    // ==== CALLBACKS ====

    // Локальные ICE наружу
    pc!.onIceCandidate = (c) {
      if (c.candidate != null) onLocalIce(c);
    };

    // Состояние коннекта: подстрахуем «первый» call
    pc!.onConnectionState = (state) async {
      if (kDebugMode) print('[PC] connectionState = $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        try {
          if (kDebugMode) print('[PC] restarting ICE (failed)');
          await pc?.restartIce();
        } catch (e) {
          if (kDebugMode) print('[PC] restartIce error: $e');
        }
      }
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _firstConnectKickTimer?.cancel();
        _firstConnectKickTimer = null;
      }
    };

    // Unified-Plan
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

  // ====== SDP / OFFER / ANSWER ======

  Future<RTCSessionDescription> createOffer({required bool wantVideo}) async {
    final offer = await pc!.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 1,
    });
    await pc!.setLocalDescription(offer);

    // Подстраховка «первого вызова»: если быстро не соединились — перезапуск ICE
    _armFirstConnectKick();

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

    // Подстраховка «первого вызова»
    _armFirstConnectKick();

    if (kDebugMode) {
      print('[SDP][ANSWER] len=${answer.sdp?.length ?? 0}');
    }
    return answer;
  }

  // Применение чужого SDP: отмечаем флаг и заливаем отложенные ICE
  Future<void> setRemoteDescription(String sdp, String type) async {
    await pc!.setRemoteDescription(RTCSessionDescription(sdp, type));
    _remoteSdpSet = true;

    // Применяем накопленные кандидаты
    for (final c in List<RTCIceCandidate>.from(_remoteIceBuffer)) {
      try {
        await pc?.addCandidate(c);
      } catch (e) {
        if (kDebugMode) print('[ICE][flush] addCandidate error: $e');
      }
    }
    _remoteIceBuffer.clear();
  }

  // Добавление ICE: либо сразу в PC, либо буферим до setRemoteDescription
  Future<void> addCandidate(RTCIceCandidate c) async {
    if (_remoteSdpSet) {
      try {
        await pc?.addCandidate(c);
      } catch (e) {
        if (kDebugMode) print('[ICE] addCandidate error: $e');
      }
    } else {
      _remoteIceBuffer.add(c);
      if (kDebugMode) print('[ICE] buffered (${_remoteIceBuffer.length})');
    }
  }

  // ====== MEDIA TOGGLES ======

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

  // ====== CLEANUP ======

  Future<void> dispose() async {
    _firstConnectKickTimer?.cancel();
    _firstConnectKickTimer = null;

    _remoteIceBuffer.clear();
    _remoteSdpSet = false;

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
    _renderersInitialized = false;

    _audioSender = null;
    _videoSender = null;

    try {
      await _forcedRemote?.dispose();
    } catch (_) {}
    _forcedRemote = null;
  }

  // ====== ВНУТРЕННЕЕ: таймер для первого коннекта ======

  void _armFirstConnectKick() {
    _firstConnectKickTimer?.cancel();
    _firstConnectKickTimer = Timer(const Duration(seconds: 8), () async {
      final st = pc?.connectionState;
      if (kDebugMode) print('[PC] firstConnectKick check => $st');
      if (st != RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
          st != RTCPeerConnectionState.RTCPeerConnectionStateConnecting) {
        try {
          if (kDebugMode) print('[PC] firstConnectKick -> restartIce()');
          await pc?.restartIce();
        } catch (e) {
          if (kDebugMode) print('[PC] kick restartIce error: $e');
        }
      }
    });
  }
}
