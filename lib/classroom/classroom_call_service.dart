import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/webrtc_service.dart';
import 'classroom_overlay.dart';
import 'classroom_signaling.dart';

/// Видеокласс «учитель ↔ до 8 учеников».
///
/// Рабочая схема:
/// - камера и микрофон открываются один раз;
/// - у учителя отдельное WebRTC-соединение с каждым учеником;
/// - каждый ученик соединён только с учителем;
/// - для каждой пары используется отдельный Supabase Realtime-канал;
/// - порядок переговоров совпадает с рабочим режимом «Играть»:
///   ready -> offer -> answer -> ICE.
class ClassroomCallService {
  ClassroomCallService({
    required this.client,
    required this.signaling,
    required this.classroomId,
    required this.selfId,
    required this.teacherId,
    required this.isTeacher,
    Map<String, String> peerNames = const <String, String>{},
  }) : peerNames = Map<String, String>.from(peerNames);

  final SupabaseClient client;
  final ClassroomSignaling signaling;
  final String classroomId;
  final String selfId;
  final String teacherId;
  final bool isTeacher;
  final Map<String, String> peerNames;

  /// Единственный владелец локальной камеры и микрофона.
  final WebRTCService _media = WebRTCService();

  /// Один независимый peer на каждого ученика.
  final Map<String, _ClassroomPeer> _peers = <String, _ClassroomPeer>{};
  final Map<String, ClassroomPairSignaling> _pairSignals =
      <String, ClassroomPairSignaling>{};
  final Map<String, StreamSubscription<ClassroomPairEvent>> _pairSubs =
      <String, StreamSubscription<ClassroomPairEvent>>{};

  final Map<String, Future<void>> _offerTasks = <String, Future<void>>{};
  final Map<String, String> _lastOffers = <String, String>{};
  final Map<String, String> _lastAnswers = <String, String>{};
  final Map<String, Set<String>> _remoteCandidateFingerprints =
      <String, Set<String>>{};

  bool _started = false;
  bool _stopping = false;

  bool get isActive => _started && !_stopping;

  bool hasTeacherStudent(String studentId) {
    final id = studentId.trim();
    if (!isTeacher || id.isEmpty) return false;
    return _pairSignals.containsKey(id) || _peers.containsKey(id);
  }

  Future<void> addTeacherStudents(Map<String, String> students) async {
    if (!isTeacher) {
      throw StateError('Добавлять учеников может только учитель.');
    }
    if (!isActive) {
      throw StateError('Видеокласс ещё не запущен.');
    }

    for (final entry in students.entries) {
      final studentId = entry.key.trim();
      if (studentId.isEmpty || studentId == selfId) continue;

      final studentName =
          entry.value.trim().isEmpty ? 'Ученик' : entry.value.trim();

      if (hasTeacherStudent(studentId)) {
        peerNames[studentId] = studentName;
        continue;
      }
      if (_pairSignals.length >= 8) {
        throw StateError('К видеоклассу уже добавлено 8 учеников.');
      }

      peerNames[studentId] = studentName;
      try {
        await _startPairChannel(studentId);
      } catch (_) {
        peerNames.remove(studentId);
        rethrow;
      }
    }
  }

  Future<void> start(BuildContext context) async {
    if (_started) return;
    if (selfId.trim().isEmpty || teacherId.trim().isEmpty) {
      throw StateError('Не определены участники видеокласса.');
    }

    _started = true;
    _stopping = false;

    try {
      ClassroomOverlay.instance.attach(context);

      // Тот же проверенный порядок, что в режиме «Играть».
      await _media.initRenderers();
      await _media.getUserMedia(video: true);
      await ClassroomOverlay.instance.showLocal(
        _media.localRenderer,
        label: isTeacher ? 'Вы (учитель)' : 'Вы (ученик)',
      );

      final peerIds = isTeacher
          ? peerNames.keys
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty && id != selfId)
              .toSet()
              .take(8)
              .toList(growable: false)
          : <String>[teacherId];

      await Future.wait(peerIds.map(_startPairChannel));

      // Ученик объявляет готовность только после полной подписки на свой канал.
      if (!isTeacher) {
        await _announceStudentReady();
      }
    } catch (_) {
      await stop(notifyPeers: false);
      rethrow;
    }
  }

  String _titleFor(String peerId) {
    return peerNames[peerId] ?? (isTeacher ? 'Ученик' : 'Учитель');
  }

  Future<void> _startPairChannel(String peerId) async {
    if (_stopping || _pairSignals.containsKey(peerId)) return;

    final studentId = isTeacher ? peerId : selfId;
    final pair = signaling.openPair(
      classroomId: classroomId,
      teacherId: teacherId,
      studentId: studentId,
      selfId: selfId,
    );

    _pairSignals[peerId] = pair;
    _pairSubs[peerId] = pair.events.listen(
      (event) => unawaited(_onPairEvent(peerId, event)),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          '[CLASSROOM][$selfId][$peerId] pair signaling error: '
          '$error\n$stackTrace',
        );
      },
    );

    try {
      await pair.start();
    } catch (_) {
      await _pairSubs.remove(peerId)?.cancel();
      _pairSignals.remove(peerId);
      await pair.dispose();
      rethrow;
    }
  }

  Future<void> _announceStudentReady() async {
    final pair = _pairSignals[teacherId];
    if (pair == null || _stopping) return;

    // Broadcast не хранится. Повторяем ready, как в рабочем звонке «Играть».
    for (var attempt = 0; attempt < 3 && !_stopping; attempt++) {
      await pair.sendReady();
      if (attempt < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 550));
      }
    }
  }

  Future<void> _onPairEvent(
    String peerId,
    ClassroomPairEvent event,
  ) async {
    if (_stopping || event.fromId != peerId || event.toId != selfId) return;

    try {
      switch (event.type) {
        case ClassroomPairEventType.ready:
          if (isTeacher) await _sendTeacherOffer(peerId);
          break;
        case ClassroomPairEventType.offer:
          if (!isTeacher) await _acceptTeacherOffer(peerId, event);
          break;
        case ClassroomPairEventType.answer:
          if (isTeacher) await _acceptStudentAnswer(peerId, event);
          break;
        case ClassroomPairEventType.candidate:
          await _acceptRemoteCandidate(peerId, event);
          break;
        case ClassroomPairEventType.hangup:
          await _handleRemoteHangup(peerId);
          break;
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[CLASSROOM][$selfId][$peerId] ${event.type.name} failed: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> _sendTeacherOffer(String peerId) async {
    final active = _offerTasks[peerId];
    if (active != null) return active;

    final task = _sendTeacherOfferOnce(peerId);
    _offerTasks[peerId] = task;
    try {
      await task;
    } finally {
      if (identical(_offerTasks[peerId], task)) {
        _offerTasks.remove(peerId);
      }
    }
  }

  Future<void> _sendTeacherOfferOnce(String peerId) async {
    if (!isTeacher || _stopping || !peerNames.containsKey(peerId)) return;

    final pair = _pairSignals[peerId];
    if (pair == null) return;

    final peer = await _ensurePeer(peerId);
    if (await peer.hasRemoteDescription()) return;

    var offer = await peer.localDescription();
    if (offer == null || offer.type != 'offer' || (offer.sdp ?? '').isEmpty) {
      offer = await peer.createOffer();
    }

    final sdp = offer.sdp ?? '';
    if (sdp.isEmpty) throw StateError('Не удалось создать offer видеокласса.');

    // Offer повторяется: ученик мог только что восстановить WebSocket.
    for (var attempt = 0; attempt < 3 && !_stopping; attempt++) {
      await pair.sendOffer(
        sdp: sdp,
        descriptionType: offer.type ?? 'offer',
      );
      await _resendLocalIce(peerId, peer);
      if (attempt < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<void> _acceptTeacherOffer(
    String peerId,
    ClassroomPairEvent event,
  ) async {
    if (isTeacher || peerId != teacherId) return;

    final sdp = event.sdp ?? '';
    if (sdp.isEmpty) return;

    final pair = _pairSignals[peerId];
    if (pair == null) return;
    final peer = await _ensurePeer(peerId);

    // Повтор того же offer: не применяем SDP второй раз, а повторяем answer.
    if (_lastOffers[peerId] == sdp) {
      final existingAnswer = await peer.localDescription();
      if (existingAnswer != null &&
          existingAnswer.type == 'answer' &&
          (existingAnswer.sdp ?? '').isNotEmpty) {
        await pair.sendAnswer(
          sdp: existingAnswer.sdp!,
          descriptionType: existingAnswer.type ?? 'answer',
        );
        await _resendLocalIce(peerId, peer);
      }
      return;
    }

    await peer.setRemoteDescription(
      sdp,
      event.descriptionType ?? 'offer',
    );
    _lastOffers[peerId] = sdp;

    final answer = await peer.createAnswer();
    final answerSdp = answer.sdp ?? '';
    if (answerSdp.isEmpty) {
      throw StateError('Не удалось создать answer видеокласса.');
    }

    for (var attempt = 0; attempt < 3 && !_stopping; attempt++) {
      await pair.sendAnswer(
        sdp: answerSdp,
        descriptionType: answer.type ?? 'answer',
      );
      await _resendLocalIce(peerId, peer);
      if (attempt < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }
    }
  }

  Future<void> _acceptStudentAnswer(
    String peerId,
    ClassroomPairEvent event,
  ) async {
    if (!isTeacher || !peerNames.containsKey(peerId)) return;

    final sdp = event.sdp ?? '';
    if (sdp.isEmpty || _lastAnswers[peerId] == sdp) return;

    final peer = await _ensurePeer(peerId);
    if (await peer.hasRemoteDescription()) {
      _lastAnswers[peerId] = sdp;
      return;
    }

    await peer.setRemoteDescription(
      sdp,
      event.descriptionType ?? 'answer',
    );
    _lastAnswers[peerId] = sdp;
  }

  Future<void> _acceptRemoteCandidate(
    String peerId,
    ClassroomPairEvent event,
  ) async {
    final candidate = event.candidate;
    if (candidate == null || candidate.isEmpty) return;
    if (isTeacher && !peerNames.containsKey(peerId)) return;
    if (!isTeacher && peerId != teacherId) return;

    final fingerprint =
        '$candidate|${event.sdpMid}|${event.sdpMLineIndex ?? -1}';
    final seen = _remoteCandidateFingerprints.putIfAbsent(
      peerId,
      () => <String>{},
    );
    if (!seen.add(fingerprint)) return;

    final peer = await _ensurePeer(peerId);
    await peer.addCandidate(
      RTCIceCandidate(
        candidate,
        event.sdpMid,
        event.sdpMLineIndex,
      ),
    );
  }

  Future<_ClassroomPeer> _ensurePeer(String peerId) async {
    final existing = _peers[peerId];
    if (existing != null) {
      await existing.initialize();
      return existing;
    }

    if (isTeacher && _peers.length >= 8) {
      throw StateError('К видеоклассу уже подключено 8 учеников.');
    }

    final localStream = _media.localStream;
    if (localStream == null) {
      throw StateError('Локальная камера видеокласса не запущена.');
    }

    final peer = _ClassroomPeer(
      peerId: peerId,
      localStream: localStream,
      onLocalIce: (candidate) => _sendIce(peerId, candidate),
      onRendererReady: (renderer) => ClassroomOverlay.instance.addRemote(
        peerId,
        _titleFor(peerId),
        renderer,
        waitingForVideo: true,
      ),
      onRemoteStream: (renderer) => ClassroomOverlay.instance.addRemote(
        peerId,
        _titleFor(peerId),
        renderer,
      ),
    );

    // Сохраняем до await: близкие ICE/SDP не должны создать два peer.
    _peers[peerId] = peer;
    try {
      await peer.initialize();
      return peer;
    } catch (_) {
      _peers.remove(peerId);
      await peer.dispose();
      rethrow;
    }
  }

  Future<void> _sendIce(
    String peerId,
    RTCIceCandidate candidate,
  ) async {
    if (_stopping || candidate.candidate == null) return;
    final pair = _pairSignals[peerId];
    if (pair == null) return;

    try {
      await pair.sendCandidate(
        candidate: candidate.candidate!,
        sdpMid: candidate.sdpMid,
        sdpMLineIndex: candidate.sdpMLineIndex,
      );
    } catch (error) {
      if (kDebugMode && !_stopping) {
        debugPrint('[CLASSROOM][$selfId][$peerId] ICE send failed: $error');
      }
    }
  }

  Future<void> _resendLocalIce(
    String peerId,
    _ClassroomPeer peer,
  ) async {
    final pair = _pairSignals[peerId];
    if (pair == null || _stopping) return;

    for (final candidate in peer.localCandidates) {
      final value = candidate.candidate;
      if (value == null || value.isEmpty) continue;
      await pair.sendCandidate(
        candidate: value,
        sdpMid: candidate.sdpMid,
        sdpMLineIndex: candidate.sdpMLineIndex,
      );
    }
  }

  Future<void> _handleRemoteHangup(String peerId) async {
    if (isTeacher) {
      await _removePeer(peerId, notifyPeer: false);
      return;
    }
    await stop(notifyPeers: false);
  }

  Future<void> _removePeer(
    String peerId, {
    required bool notifyPeer,
  }) async {
    final pair = _pairSignals.remove(peerId);
    if (notifyPeer && pair != null) {
      try {
        await pair.sendHangup();
      } catch (_) {}
    }

    await _pairSubs.remove(peerId)?.cancel();
    await pair?.dispose();

    final peer = _peers.remove(peerId);
    if (peer != null) await peer.dispose();
    await ClassroomOverlay.instance.removeRemote(peerId);

    _offerTasks.remove(peerId);
    _lastOffers.remove(peerId);
    _lastAnswers.remove(peerId);
    _remoteCandidateFingerprints.remove(peerId);
    if (isTeacher) peerNames.remove(peerId);
  }

  /// Завершает видеосвязь только с одним учеником.
  /// Остальные ученики и локальная камера учителя продолжают работать.
  Future<void> stopPeer(String studentId) async {
    if (!isTeacher || _stopping) return;
    final id = studentId.trim();
    if (id.isEmpty || !hasTeacherStudent(id)) return;
    await _removePeer(id, notifyPeer: true);
  }

  Future<void> stop({bool notifyPeers = true}) async {
    if (_stopping) return;
    _stopping = true;
    _started = false;

    final peerIds = <String>{
      ..._pairSignals.keys,
      ..._peers.keys,
    }.toList(growable: false);

    for (final peerId in peerIds) {
      await _removePeer(peerId, notifyPeer: notifyPeers);
    }

    // Только владелец media останавливает общие tracks.
    try {
      await _media.dispose();
    } catch (_) {}
    await ClassroomOverlay.instance.dispose();
  }
}

/// Одно WebRTC-соединение «учитель ↔ конкретный ученик».
///
/// Здесь намеренно повторена важная часть рабочего VoiceService: полученный
/// MediaStream явно назначается remoteRenderer.srcObject. В старом classroom-
/// коде callback получал поток, но игнорировал его — поэтому оба участника
/// видели себя и пустое удалённое окно.
class _ClassroomPeer {
  _ClassroomPeer({
    required this.peerId,
    required this.localStream,
    required this.onLocalIce,
    required this.onRendererReady,
    required this.onRemoteStream,
  });

  final String peerId;
  final MediaStream localStream;
  final Future<void> Function(RTCIceCandidate candidate) onLocalIce;
  final Future<void> Function(RTCVideoRenderer renderer) onRendererReady;
  final Future<void> Function(RTCVideoRenderer renderer) onRemoteStream;

  final WebRTCService _rtc = WebRTCService();
  final List<RTCIceCandidate> _localCandidates = <RTCIceCandidate>[];

  Future<void>? _initializing;
  bool _initialized = false;
  bool _disposed = false;

  List<RTCIceCandidate> get localCandidates =>
      List<RTCIceCandidate>.unmodifiable(_localCandidates);

  Future<void> initialize() async {
    if (_initialized) return;
    final active = _initializing;
    if (active != null) return active;

    final task = _initializeOnce();
    _initializing = task;
    try {
      await task;
    } finally {
      if (identical(_initializing, task)) _initializing = null;
    }
  }

  Future<void> _initializeOnce() async {
    await _rtc.initRenderers();

    // RTCVideoView создаётся до SDP/onTrack — важно для Flutter Web.
    await onRendererReady(_rtc.remoteRenderer);

    _rtc.localStream = localStream;
    await _rtc.createPeer(
      onLocalIce: (candidate) => unawaited(_publishLocalIce(candidate)),
      onRemoteStream: (stream) => unawaited(_bindRemoteStream(stream)),
    );

    final pc = _rtc.pc;
    if (pc == null) throw StateError('PeerConnection видеокласса не создан.');

    // Повторяем страховки рабочего VoiceService.
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      unawaited(_publishLocalIce(candidate));
    };
    pc.onTrack = (RTCTrackEvent event) async {
      if (_disposed) return;
      if (event.streams.isNotEmpty) {
        await _bindRemoteStream(event.streams.first);
        return;
      }

      final stream = await createLocalMediaStream('classroom_remote_$peerId');
      stream.addTrack(event.track);
      await _bindRemoteStream(stream);
    };

    await _rtc.ensureLocalSenders();
    _initialized = true;
  }

  Future<void> _publishLocalIce(RTCIceCandidate candidate) async {
    if (_disposed || candidate.candidate == null) return;
    final fingerprint =
        '${candidate.candidate}|${candidate.sdpMid}|${candidate.sdpMLineIndex}';
    final exists = _localCandidates.any(
      (item) =>
          '${item.candidate}|${item.sdpMid}|${item.sdpMLineIndex}' ==
          fingerprint,
    );
    if (!exists) _localCandidates.add(candidate);
    await onLocalIce(candidate);
  }

  Future<void> _bindRemoteStream(MediaStream stream) async {
    if (_disposed) return;

    // Ключевой ремонт: в рабочем VoiceService поток назначается явно.
    _rtc.remoteRenderer.srcObject = stream;
    await _publishRemoteIfReady();
  }

  Future<RTCSessionDescription> createOffer() {
    return _rtc.createOffer(wantVideo: true);
  }

  Future<RTCSessionDescription> createAnswer() {
    return _rtc.createAnswer(wantVideo: true);
  }

  Future<RTCSessionDescription?> localDescription() async {
    final pc = _rtc.pc;
    if (pc == null) return null;
    return pc.getLocalDescription();
  }

  Future<bool> hasRemoteDescription() async {
    final pc = _rtc.pc;
    if (pc == null) return false;
    return await pc.getRemoteDescription() != null;
  }

  Future<void> setRemoteDescription(String sdp, String type) async {
    if (sdp.isEmpty) throw StateError('Получен пустой SDP видеокласса.');
    await _rtc.setRemoteDescription(sdp, type);

    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _rtc.forceBindRemoteIfNeeded();
    await _publishRemoteIfReady();
  }

  Future<void> addCandidate(RTCIceCandidate candidate) {
    // WebRTCService буферизует ICE до установки remoteDescription.
    return _rtc.addCandidate(candidate);
  }

  Future<void> _publishRemoteIfReady() async {
    if (_disposed) return;
    final stream = _rtc.remoteRenderer.srcObject;
    if (stream == null || stream.getVideoTracks().isEmpty) return;
    await onRemoteStream(_rtc.remoteRenderer);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    // Общий MediaStream принадлежит ClassroomCallService. Отдельный peer не
    // должен остановить камеру для других учеников.
    _rtc.localStream = null;
    await _rtc.dispose();
  }
}
