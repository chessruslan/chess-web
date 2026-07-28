// lib/features/call/schools/learn_sheet.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../classroom/school_dialog_new.dart';
import '../../../classroom/classroom_signaling.dart';

// ✅ Импорт нового диалога школы
import '../../../classroom/school_dialog_new.dart';

Future<void> openLearnSheet(BuildContext ctx) async {
  final sb = Supabase.instance.client;

  return showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx2) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_pin_rounded),
                title: const Text('Школа с реальным учителем'),
onTap: () async {
  Navigator.pop(ctx);                // закрыть лист
  final sb = Supabase.instance.client;

  await showSchoolDialogNew(
    context: ctx,
    client: sb,
    signaling: ClassroomSignaling(sb),
    schoolId: 'demo-school', // временно; можно подставить реальный
    teacherId: sb.auth.currentUser?.id ?? 'teacher_demo',
  );
},

              ),
              const Divider(height: 8),
              ListTile(
                leading: const Icon(Icons.smart_toy),
                title: const Text('Школа с виртуальным учителем (аватар)'),
                onTap: () {
                  Navigator.pop(ctx2);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Скоро 🤖')),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
