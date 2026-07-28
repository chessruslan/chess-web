import 'package:flutter/material.dart';

import '../app_style.dart';

class RoomChatItem {
  const RoomChatItem({
    required this.from,
    required this.text,
    required this.mine,
  });

  final String from;
  final String text;
  final bool mine;
}

class RoomChatPanel extends StatelessWidget {
  const RoomChatPanel({
    super.key,
    required this.roomId,
    required this.inRoom,
    required this.messages,
    required this.chatController,
    required this.onSend,
    required this.onSpectatorPressed,
    this.maxWidth = 560,
    this.height = 220,
  });

  final String? roomId;
  final bool inRoom;
  final List<RoomChatItem> messages;
  final TextEditingController chatController;
  final VoidCallback onSend;
  final Future<void> Function() onSpectatorPressed;
  final double maxWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'Чат',
                  style: AppTextStyles.panelTitle,
                ),
                const Spacer(),
                if (roomId != null)
                  SelectableText(
                    'Room: ${roomId!.substring(0, 8)}...',
                    style: AppTextStyles.caption,
                  ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: AppButtons.secondary(),
                  onPressed: onSpectatorPressed,
                  icon: const Icon(Icons.visibility),
                  label: const Text('Зритель'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Container(
                decoration: AppDecorations.lightPanel(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  primary: false,
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    final align = m.mine
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start;
                    final bg =
                        m.mine ? Colors.blue.shade50 : Colors.grey.shade200;

                    return Column(
                      crossAxisAlignment: align,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: AppRadius.r10,
                          ),
                          child: Text(
                            m.mine ? m.text : '${m.from}: ${m.text}',
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: chatController,
                    enabled: inRoom,
                    style: const TextStyle(color: AppColors.text),
                    decoration: AppInputs.dark(
                      hintText: 'Сообщение...',
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: AppButtons.primary(),
                  onPressed: onSend,
                  child: const Text('Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}