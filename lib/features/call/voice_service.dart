import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../services/webrtc_service.dart';
import 'supabase_signaling.dart';

class VoiceService {
  final WebRTCService _rtc = WebRTCService();
  final SupabaseSignaling _sig = SupabaseSignaling.instance;

  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);

  Object? _offerSub;
  Object? _answerSub;
  Object? _iceSub;
  Object? _readySub;

  String? _roomId;

  // ICE буфер до remoteDescription
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];

  RTCVideoRenderer get localRenderer => _rtc.localRenderer;
  RTCVideoRenderer get remoteRenderer => _rtc.remoteRenderer;

  Future<void> init({required bool audioOnly}) async {
    await _rtc.initRenderers();
    await _rtc.getUserMedia(video: !audioOnly);
  }

  Future<void> _createPeer() async {
    await _rtc.createPeer(
      onLocalIce: (_) {},
      onRemoteStream: (MediaStream stream) {
        remoteRenderer.srcObject = stream;
        connected.value = true;
      },
    );

    final pc = _rtc.pc;
    if (pc == null) return;

    pc.onIceCandidate = (RTCIceCandidate c) async {
      final rid = _roomId;
      if (rid == null || c.candidate == null) return;
      await _sig.sendIce(
        roomId: rid,
        candidate: {
          'candidate': c.candidate,
          'sdpMid': c.sdpMid,
          'sdpMLineIndex': c.sdpMLineIndex,
        },
      );
    };

    pc.onTrack = (RTCTrackEvent e) async {
      if (kDebugMode) {
        print(
            '[Voice] onTrack kind=${e.track.kind} streams=${e.streams.length}');
      }
      if (e.streams.isNotEmpty) {
        remoteRenderer.srcObject = e.streams.first;
      } else {
        final ms = await createLocalMediaStream('remote');
        ms.addTrack(e.track);
        remoteRenderer.srcObject = ms;
      }
      connected.value = true;
    };
  }

  Future<void> _setRemoteAndFlush(String sdp, String type) async {
    await _rtc.setRemoteDescription(sdp, type);

    // Если по какой-то причине onTrack не сработал — «приклеим» вручную
    // (особенно помогает инициатору после получения answer)
    // Делаем с небольшим ожиданием, чтобы успели появиться receivers.
    try {
      await Future.delayed(const Duration(milliseconds: 120));
      await _rtc.forceBindRemoteIfNeeded();
    } catch (_) {}

    if (_pendingRemoteCandidates.isNotEmpty) {
      for (final c in List<RTCIceCandidate>.from(_pendingRemoteCandidates)) {
        try {
          await _rtc.addCandidate(c);
        } catch (_) {}
      }
      _pendingRemoteCandidates.clear();
    }
  }

  // ----- Caller -----
  Future<void> startCall({
    required String roomId,
    required bool audioOnly,
  }) async {
    _roomId = roomId.trim();

    await init(audioOnly: audioOnly);
    await _createPeer();
    await _rtc.ensureLocalSenders(); // addTrack гарантирован

    // подписки ДО оффера
    _answerSub ??= _sig.onAnswer(_roomId!, (String sdp) async {
      if (kDebugMode) print('[SIG] answer received (${sdp.length})');
      await _setRemoteAndFlush(sdp, 'answer');
    });

    _iceSub ??= _sig.onRemoteIce(_roomId!, (Map<String, dynamic> cand) async {
      try {
        final c = RTCIceCandidate(
          cand['candidate'] as String?,
          cand['sdpMid'] as String?,
          (cand['sdpMLineIndex'] as num?)?.toInt(),
        );
        final hasRemote = await _rtc.pc?.getRemoteDescription() != null;
        if (!hasRemote) {
          _pendingRemoteCandidates.add(c);
        } else {
          await _rtc.addCandidate(c);
        }
      } catch (_) {}
    });

    _readySub ??= _sig.onReady(_roomId!, () async {
      final hasRemote = await _rtc.pc?.getRemoteDescription() != null;
      if (!hasRemote) {
        final offer2 = await _rtc.createOffer(wantVideo: !audioOnly);
        await _sig.sendOffer(roomId: _roomId!, sdp: offer2.sdp ?? '');
        if (kDebugMode) print('[SIG] resent offer on ready');
      }
    });

    // первый оффер
    final offer = await _rtc.createOffer(wantVideo: !audioOnly);
    await _sig.sendOffer(roomId: _roomId!, sdp: offer.sdp ?? '');
    if (kDebugMode) print('[SIG] offer sent (${offer.sdp?.length ?? 0})');
  }

  // ----- Callee -----
  Future<void> joinCall({
    required String roomId,
    required bool audioOnly,
  }) async {
    _roomId = roomId.trim();

    await init(audioOnly: audioOnly);
    await _createPeer();
    await _rtc.ensureLocalSenders();

    _offerSub ??= _sig.onOffer(_roomId!, (String sdp) async {
      if (kDebugMode) print('[SIG] offer received (${sdp.length})');
      await _setRemoteAndFlush(sdp, 'offer');

      final answer = await _rtc.createAnswer(wantVideo: !audioOnly);
      await _sig.sendAnswer(roomId: _roomId!, sdp: answer.sdp ?? '');
      if (kDebugMode) print('[SIG] answer sent (${answer.sdp?.length ?? 0})');
    });

    _iceSub ??= _sig.onRemoteIce(_roomId!, (Map<String, dynamic> cand) async {
      try {
        final c = RTCIceCandidate(
          cand['candidate'] as String?,
          cand['sdpMid'] as String?,
          (cand['sdpMLineIndex'] as num?)?.toInt(),
        );
        final hasRemote = await _rtc.pc?.getRemoteDescription() != null;
        if (!hasRemote) {
          _pendingRemoteCandidates.add(c);
        } else {
          await _rtc.addCandidate(c);
        }
      } catch (_) {}
    });

    await _sig.sendReady(roomId: _roomId!);
  }

  Future<void> setMicEnabled(bool enabled) => _rtc.setMicEnabled(enabled);
  Future<void> setCamEnabled(bool enabled) => _rtc.setCamEnabled(enabled);

  Future<void> _cancel(Object? sub) async {
    if (sub == null) return;
    try {
      if (sub is StreamSubscription) {
        await sub.cancel();
      } else if (sub is supa.RealtimeChannel) {
        await sub.unsubscribe();
      }
    } catch (_) {}
  }

  Future<void> hangup() async {
    await _cancel(_offerSub);
    await _cancel(_answerSub);
    await _cancel(_iceSub);
    await _cancel(_readySub);

    _offerSub = null;
    _answerSub = null;
    _iceSub = null;
    _readySub = null;

    _pendingRemoteCandidates.clear();

    await _sig.leaveRoom(_roomId ?? '');
    await _rtc.dispose();
    connected.value = false;
  }

  Future<void> dispose() => hangup();
}
