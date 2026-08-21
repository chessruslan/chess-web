// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../services/lobby_store.dart';
import 'ring_service.dart';
import 'voice_service.dart';
import 'video_overlay.dart';
import 'room_selection.dart';

import '../../localization/makechess_localization.dart';

class CallOverlay extends StatefulWidget {
  final String? initialRoomId;
  final bool audioOnly;
  final bool autoJoin;

  const CallOverlay({
    super.key,
    this.initialRoomId,
    this.audioOnly = false,
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
  bool _roomWasSetByUser = false;
  int? _hoverIndex; // ✅ Добавлено
  @override
  void initState() {
    super.initState();

    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final me = LobbyStore.instance.users.value.firstWhere(
      (u) => u.isMe || u.id == myId,
      orElse: () =>
          LobbyUser(id: myId, username: const Uuid().v4().substring(0, 8)),
    );

    if ((widget.initialRoomId ?? '').trim().isNotEmpty) {
      _roomCtrl.text = widget.initialRoomId!.trim();
      RoomSelection.instance.setRoom(_roomCtrl.text);
      _roomWasSetByUser = true;
    } else {
      _roomCtrl.text = me.username;
      RoomSelection.instance.setRoom(me.username);
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
    // ВАЖНО: звонок/плавающие окна не трогаем здесь
    super.dispose();
  }

  // ----- helpers -----

  void _setRoomId(String value, {bool fromUserAction = false}) {
    final v = value.trim();
    if (v.isEmpty) return;
    _roomCtrl.value = _roomCtrl.value.copyWith(
      text: v,
      selection: TextSelection.collapsed(offset: v.length),
      composing: TextRange.empty,
    );
    RoomSelection.instance.setRoom(v); // ← синк в общий буфер
    if (fromUserAction) _roomWasSetByUser = true;
    setState(() {});
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: MakeChessLocalizedText(msg)));
  }

  // ----- действия (локальные, если пользуешься этим окном) -----

  Future<void> _create() async {
    final room = _roomCtrl.text.trim();
    if (room.isEmpty) return _toast('Room ID пуст');
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
    if (room.isEmpty) return _toast('Room ID пуст');
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

  // ----- UI -----

  @override
  Widget build(BuildContext context) {
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
                  Expanded(child: _buildRightPanel()),
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
            decoration: InputDecoration(
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
              if (v.trim().isNotEmpty) {
                RoomSelection.instance.setRoom(v);
                _roomWasSetByUser = true;
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
            onPressed: _create, child: const MakeChessLocalizedText('Создать')),
        const SizedBox(width: 8),
        FilledButton.tonal(
            onPressed: _join,
            child: const MakeChessLocalizedText('Присоединиться')),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close, color: Colors.white70),
          tooltip: MakeChessLocalization.phrase('Закрыть'),
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
          // ===== Заголовок + поле Room ID =====
          Row(
            children: [
              const MakeChessLocalizedText(
                'Контакты',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(width: 12),
              // Поле Room ID: всегда видно, readOnly, автообновление
              Expanded(
                child: AnimatedBuilder(
                  animation: RoomSelection.instance,
                  builder: (context, _) {
                    // синхронизируем текст контроллера для показа
                    final val = RoomSelection.instance.room ?? '';
                    if (_roomCtrl.text != val) {
                      _roomCtrl.text = val;
                    }
                    return SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _roomCtrl,
                        readOnly: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Room ID',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white12,
                          prefixIcon: const Icon(Icons.meeting_room,
                              size: 18, color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Colors.white24, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Colors.white24, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Colors.white70, width: 1),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ===== Список игроков =====
          Expanded(
            child: AnimatedBuilder(
              animation: LobbyStore.instance.users,
              builder: (_, __) {
                final users = LobbyStore.instance.users.value;
                if (users.isEmpty) {
                  return const Center(
                    child: MakeChessLocalizedText(
                      'Пока никого нет',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white12, height: 8),
                  itemBuilder: (ctx, i) {
                    final u = users[i];

                    // выбранная строка — если сохранён наш выбор, или RoomSelection совпадает
                    final isSelected = (_selected?.id == u.id) ||
                        (RoomSelection.instance.room?.trim().toLowerCase() ==
                            u.username.trim().toLowerCase());
                    final isHovered = _hoverIndex == i;

                    final tile = ListTile(
                      dense: true,
                      selected: isSelected || isHovered,
                      selectedTileColor: Colors.white10,
                      tileColor: isHovered
                          ? Colors.white10
                          : null, // подсветка наведения
                      title: MakeChessLocalizedText(
                        u.username,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: u.rating == null
                          ? null
                          : MakeChessLocalizedText('Рейт: ${u.rating}',
                              style: const TextStyle(color: Colors.white54)),
                      onTap: () {
                        RoomSelection.instance.setRoom(u.username);
                        setState(() => _selected = u);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: MakeChessLocalizedText(
                                  'Room ID: ${u.username} выбран')),
                        );
                      },
                      trailing: TextButton(
                        onPressed: () {
                          // оставь здесь свою игровую логику «Вызвать» (матч), если нужна
                        },
                        child: const MakeChessLocalizedText('Вызвать'),
                      ),
                    );

                    return MouseRegion(
                      onEnter: (_) => setState(() => _hoverIndex = i),
                      onExit: (_) => setState(() => _hoverIndex = null),
                      child: tile,
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

  Widget _buildRightPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: const Center(
        child: MakeChessLocalizedText(
          'Видео выводится в плавающих окнах',
          style: TextStyle(color: Colors.white54),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        // Кнопки микрофона/камеры можно добавить при желании (не обязательны для твоей схемы).
      ],
    );
  }
}
