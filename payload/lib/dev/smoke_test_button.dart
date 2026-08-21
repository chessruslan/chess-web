// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
// lib/dev/smoke_test_button.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../localization/makechess_localization.dart';
class SmokeTestButton extends StatelessWidget {
  const SmokeTestButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      label: const MakeChessLocalizedText('SMOKE'),
      icon: const Icon(Icons.bolt),
      onPressed: () async {
        final sb = Supabase.instance.client;

        try {
          // 1) Берём ЛЮБОЙ существующий classroom_id (uuid) — нужен из-за FK.
          // Если таблица пустая, выкинем понятную ошибку.
          final rows = await sb
              .from('classrooms')
              .select('id')
              .order('created_at', ascending: false)
              .limit(1);

          if (rows.isEmpty) {
            throw Exception(
              'В таблице classrooms нет ни одной записи. '
              'Сначала создайте класс через диалог «Учиться → школа», '
              'чтобы появился classroom.',
            );
          }

          final classroomId = rows.first['id'] as String;
          final senderId = sb.auth.currentUser?.id ?? 'anon';
          final row = <String, dynamic>{
            'classroom_id': classroomId, // ВАЖНО: существующий UUID!
            'sender_id': senderId,
            'type': 'join',
            // 'receiver_id': null,     // по необходимости
            // 'sdp': null,             // по необходимости
            // 'candidate': null,       // по необходимости
            'created_at': DateTime.now().toUtc().toIso8601String(),
          };

          debugPrint('[SMOKE] insert -> $row');
          await sb.from('classroom_signals').insert(row);
          debugPrint('[SMOKE] OK');

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: MakeChessLocalizedText('SMOKE: добавлена строка в classroom_signals ✅'),
              ),
            );
          }
        } catch (e, st) {
          debugPrint('[SMOKE][ERROR] $e\n$st');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: MakeChessLocalizedText('SMOKE ошибка: $e')),
            );
          }
        }
      },
    );
  }
}
