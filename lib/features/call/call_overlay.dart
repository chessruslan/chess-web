import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../services/lobby_store.dart';
import 'ring_service.dart';
import 'voice_service.dart';

/// Диалог «звонка» с лобби слева и RoomID сверху.
/// Кнопки: Создать / Присоединиться / Вызвать
class CallOverlay extends StatefulWidget {
  final String? initialRoomId;
  final bool audioOnly; // <-- используем, но см. дефолт ниже
  final bool autoJoin;

  const CallOverlay({
    super.key,
    this.initialRoomId,
    this.audioOnly = false, // <-- БЫЛО true. Теперь по умолчанию ВИДЕО.
    this.autoJoin = false,
  });

  @override
  State<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<CallOverlay> {
  final TextEditingController _roomCtrl = TextEditingController();
  LobbyUser? _selected;

  final VoiceService _voice = VoiceService();

  bool _mediaReady = false;
  bool _busy = false;
  bool _micOn = true;
  bool _camOn = true;

  // если пользователь сам выбрал адресата (или пришёл входящий), мы не перезатираем поле
  bool _roomWasSetByUser = false;

  @override
  void initState() {
    super.initState();
    print(">>> CallOverlay audioOnly = ${widget.audioOnly}");
    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final me = LobbyStore.instance.users.value.firstWhere(
      (u) => u.isMe || u.id == myId,
      orElse: () =>
          LobbyUser(id: myId, username: const Uuid().v4().substring(0, 8)),
    );

    // Если пришёл initialRoomId (входящий вызов/автовызов) — используем его и больше не затираем
    if ((widget.initialRoomId ?? '').trim().isNotEmpty) {
      _roomCtrl.text = widget.initialRoomId!.trim();
      _roomWasSetByUser = true;
    } else {
      // Иначе — свой ID по умолчанию
      _roomCtrl.text = me.username;
    }

    _initMedia();

    if (widget.autoJoin) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _join());
    }
  }

  Future<void> _initMedia() async {
    try {
      await _voice.init(audioOnly: widget.audioOnly);
      if (!mounted) return;
      setState(() {
        _mediaReady = true;
        _micOn = true;
        _camOn = !widget.audioOnly;
      });
    } catch (e) {
      _toast('Не удалось получить доступ к камере/микрофону: $e');
    }
  }

  @override
  void dispose() {
    _roomCtrl.dispose();
    _voice.dispose();
    super.dispose();
  }

  // ------------------- helpers -------------------

  void _setRoomId(String value, {bool fromUserAction = false}) {
    final v = value.trim();
    if (v.isEmpty) return;
    _roomCtrl.value = _roomCtrl.value.copyWith(
      text: v,
      selection: TextSelection.collapsed(offset: v.length),
      composing: TextRange.empty,
    );
    if (fromUserAction) _roomWasSetByUser = true;
    setState(() {});
  }

  // ------------------- ДЕЙСТВИЯ -------------------

  Future<void> _create() async {
    final room = _roomCtrl.text.trim();
    if (room.isEmpty) {
      _toast('Room ID пуст');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _voice.startCall(roomId: room, audioOnly: widget.audioOnly);
      _toast('Комната создана: $room');
    } catch (e) {
      _toast('Ошибка создания: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final room = _roomCtrl.text.trim();
    if (room.isEmpty) {
      _toast('Room ID пуст');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _voice.joinCall(roomId: room, audioOnly: widget.audioOnly);
      _toast('Подключение к комнате: $room ...');
    } catch (e) {
      _toast('Ошибка подключения: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// После «Вызвать»:
  /// 1) выберем room по нику адресата,
  /// 2) отправим инвайт,
  /// 3) сразу создадим комнату.
  Future<void> _callSelected() async {
    final target = _selected;
    if (target == null) {
      _toast('Сначала выбери пользователя в лобби');
      return;
    }

    _setRoomId(target.username, fromUserAction: true);

    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final me = LobbyStore.instance.users.value.firstWhere(
      (u) => u.isMe || u.id == myId,
      orElse: () => LobbyUser(id: myId, username: 'player'),
    );

    try {
      await RingService.instance.sendRing(
        fromId: me.id,
        fromName: me.username,
        toId: target.id,
        toName: target.username,
        roomId: _roomCtrl.text.trim(),
        audioOnly: widget.audioOnly, // здесь остаётся как было
      );

      _toast('Вызов отправлен: ${target.username}');
      await _create();
    } catch (e) {
      _toast('Ошибка вызова: $e');
    }
  }

  Future<void> _toggleMic() async {
    _micOn = !_micOn;
    await _voice.setMicEnabled(_micOn);
    if (mounted) setState(() {});
  }

  Future<void> _toggleCam() async {
    _camOn = !_camOn;
    await _voice.setCamEnabled(_camOn);
    if (mounted) setState(() {});
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ------------------- UI -------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.black87,
      child: SizedBox(
        width: 980,
        height: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(context),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildLobbyList()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildRightPanel(isDark)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _roomCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Room ID',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white70),
              ),
            ),
            onChanged: (v) {
              if (v.trim().isNotEmpty) _roomWasSetByUser = true;
            },
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(onPressed: _create, child: const Text('Создать')),
        const SizedBox(width: 8),
        FilledButton.tonal(
            onPressed: _join, child: const Text('Присоединиться')),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: _callSelected,
          icon: const Icon(Icons.call),
          label: const Text('Вызвать'),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close, color: Colors.white70),
          tooltip: 'Закрыть',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildLobbyList() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Лобби',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedBuilder(
              animation: LobbyStore.instance.users,
              builder: (_, __) {
                final users = LobbyStore.instance.users.value;
                if (users.isEmpty) {
                  return const Center(
                    child: Text('Пока никого нет',
                        style: TextStyle(color: Colors.white54)),
                  );
                }
                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white12, height: 8),
                  itemBuilder: (_, i) {
                    final u = users[i];
                    final sel = _selected?.id == u.id;
                    return ListTile(
                      dense: true,
                      selected: sel,
                      selectedTileColor: Colors.white10,
                      title: Text(u.username,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: u.rating == null
                          ? null
                          : Text('Рейт: ${u.rating}',
                              style: const TextStyle(color: Colors.white54)),
                      onTap: () {
                        setState(() => _selected = u);
                        // ключевая строка: подставляем Room ID выбранного игрока
                        _setRoomId(u.username, fromUserAction: true);
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.call, color: Colors.white70),
                        tooltip: 'Вызвать',
                        onPressed: () {
                          // подставляем и сразу звоним
                          _setRoomId(u.username, fromUserAction: true);
                          _callSelected();
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: _mediaReady
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Превью', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RTCVideoView(_voice.localRenderer, mirror: true),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Удалённое видео',
                    style: TextStyle(color: Colors.white38)),
                const SizedBox(height: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RTCVideoView(_voice.remoteRenderer),
                  ),
                ),
              ],
            )
          : const Center(
              child: Text(
                'Запрашиваем доступ к камере/микрофону…',
                style: TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ),
    );
  }

  Widget _buildBottomBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: _micOn ? 'Выключить микрофон' : 'Включить микрофон',
          onPressed: _toggleMic,
          icon: Icon(_micOn ? Icons.mic : Icons.mic_off, color: Colors.white70),
        ),
        const SizedBox(width: 8),
        if (!widget.audioOnly)
          IconButton(
            tooltip: _camOn ? 'Выключить камеру' : 'Включить камеру',
            onPressed: _toggleCam,
            icon: Icon(_camOn ? Icons.videocam : Icons.videocam_off,
                color: Colors.white70),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}
