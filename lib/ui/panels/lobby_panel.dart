import 'package:flutter/material.dart';

import '../../features/call/room_selection.dart';
import '../app_controls.dart';
import '../app_style.dart';

class LobbyPanel extends StatefulWidget {
  const LobbyPanel({
    required this.isLoggedIn,
    required this.inLobby,
    required this.online,
    required this.onEnterLobby,
    required this.onLeaveLobby,
    required this.onInvite,
    this.myId,
    required this.myRating,
    super.key,
  });

  final bool isLoggedIn;
  final bool inLobby;
  final List<Map<String, String>> online;
  final Future<void> Function() onEnterLobby;
  final Future<void> Function() onLeaveLobby;
  final void Function(String id, String name) onInvite;
  final String? myId;
  final int myRating;

  @override
  State<LobbyPanel> createState() => _LobbyPanelState();
}

class _LobbyPanelState extends State<LobbyPanel> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 480,
      child: DecoratedBox(
        decoration: AppControls.panelDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'Контакты',
                    style: AppControls.sectionTitle,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: RoomSelection.instance,
                      builder: (context, _) {
                        final room = RoomSelection.instance.room ?? '';
                        return SizedBox(
                          height: 32,
                          child: TextField(
                            controller: TextEditingController(text: room),
                            readOnly: true,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.text,
                            ),
                            decoration: AppControls.input(
                              dense: true,
                              labelText: 'Room ID',
                              prefixIcon:
                                  const Icon(Icons.meeting_room, size: 18),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!widget.inLobby)
                    FilledButton(
                      style: AppControls.pillButton(),
                      onPressed: widget.isLoggedIn ? widget.onEnterLobby : null,
                      child: const Text('Войти'),
                    )
                  else
                    OutlinedButton(
                      style: AppControls.outlinedPill(),
                      onPressed: widget.onLeaveLobby,
                      child: const Text('Выйти'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: widget.inLobby
                    ? (widget.online.isEmpty
                        ? const Center(
                            child: Text(
                              'Онлайн никого 😴',
                              style: AppControls.muted,
                            ),
                          )
                        : ListView.separated(
                            itemCount: widget.online.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 8,
                              color: AppColors.borderSoft.withOpacity(0.8),
                            ),
                            itemBuilder: (_, i) {
                              final u = widget.online[i];
                              final isMe = (u['id'] == widget.myId);

                              final title = isMe
                                  ? '${u['username'] ?? 'player'} (вы)'
                                  : (u['username'] ?? 'player');

                              final subtitle =
                                  'Рейт: ${isMe ? widget.myRating : (u['rating'] ?? '—')}';

                              final isSelected = (RoomSelection.instance.room
                                          ?.trim()
                                          .toLowerCase() ==
                                      (u['username'] ?? '')
                                          .trim()
                                          .toLowerCase()) ||
                                  _hoverIndex == i;

                              final tile = ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: const Color(0x14FFFFFF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppRadius.r12,
                                ),
                                leading: const Icon(
                                  Icons.person,
                                  color: AppColors.textDim,
                                ),
                                title: Text(
                                  title,
                                  style: const TextStyle(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  subtitle,
                                  style: AppTextStyles.muted,
                                ),
                                onTap: () {
                                  final name = (u['username'] ?? 'player');
                                  RoomSelection.instance.setRoom(name);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Room ID: $name выбран'),
                                    ),
                                  );
                                  setState(() {});
                                },
                                trailing: FilledButton(
                                  style: AppControls.pillButton(compact: true),
                                  onPressed: isMe
                                      ? null
                                      : () => widget.onInvite(
                                            u['id']!,
                                            u['username'] ?? 'player',
                                          ),
                                  child: const Text('Играть'),
                                ),
                              );

                              return MouseRegion(
                                onEnter: (_) => setState(() => _hoverIndex = i),
                                onExit: (_) =>
                                    setState(() => _hoverIndex = null),
                                child: tile,
                              );
                            },
                          ))
                    : const Center(
                        child: Text(
                          'Откройте контакты, чтобы видеть игроков',
                          style: AppControls.muted,
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                'Онлайн: ${widget.inLobby ? widget.online.length : 0}',
                textAlign: TextAlign.right,
                style: AppControls.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
