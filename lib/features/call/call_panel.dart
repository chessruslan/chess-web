import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/lobby_store.dart';
import 'room_selection.dart';

class CallPanel extends StatefulWidget {
  const CallPanel({super.key});

  @override
  State<CallPanel> createState() => _CallPanelState();
}

class _CallPanelState extends State<CallPanel> {
  String? _selectedName;

  @override
  Widget build(BuildContext context) {
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
          const Text('Контакты',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),

          // Поле Room ID (только отображение выбранного ника)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              _selectedName == null
                  ? 'Room ID: (не выбран)'
                  : 'Room ID: $_selectedName',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 12),

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
                final myId =
                    Supabase.instance.client.auth.currentUser?.id ?? '';

                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white12, height: 8),
                  itemBuilder: (_, i) {
                    final u = users[i];
                    final isMe = u.isMe || u.id == myId;
                    final selected = _selectedName == u.username;

                    return ListTile(
                      dense: true,
                      selected: selected,
                      selectedTileColor: Colors.white10,
                      title: Text(
                        isMe ? '${u.username} (вы)' : u.username,
                        style: TextStyle(
                            color: isMe ? Colors.white54 : Colors.white),
                      ),
                      subtitle: u.rating == null
                          ? null
                          : Text('Рейт: ${u.rating}',
                              style: const TextStyle(color: Colors.white54)),

                      // 👇 КЛИК — ВЫБОР ROOM ID
                      onTap: () {
                        RoomSelection.instance.setRoom(u.username);
                        setState(() => _selectedName = u.username);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Room ID: ${u.username} выбран')),
                        );
                      },

                      // 👇 НЕ ТРОГАЕМ ТВОЮ ИГРОВУЮ КНОПКУ "Вызвать" (оставь свою логику здесь)
                      trailing: TextButton(
                        onPressed: () {
                          // оставь тут свою логику вызова на игру,
                          // мы не вмешиваемся
                        },
                        child: const Text('Вызвать'),
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
}
