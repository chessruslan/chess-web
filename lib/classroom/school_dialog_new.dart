// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'classroom_signaling.dart';
import 'classroom_call_service.dart';

import '../localization/makechess_localization.dart';

/// Диалог выбора роли + запуск звонка
class SchoolDialogNew extends StatefulWidget {
  const SchoolDialogNew({
    super.key,
    required this.client,
    required this.signaling,
    required this.schoolId,
    required this.teacherId,
  });

  final SupabaseClient client;
  final ClassroomSignaling signaling;
  final String schoolId;
  final String teacherId;

  @override
  State<SchoolDialogNew> createState() => _SchoolDialogState();
}

class _SchoolDialogState extends State<SchoolDialogNew> {
  bool _busy = false;
  String? _classroomId;

  Future<void> _ensureClassroom() async {
    _classroomId ??= await widget.signaling.ensureActiveClassroom(
      schoolId: widget.schoolId,
      teacherId: widget.teacherId,
    );
  }

  Future<void> _startAsTeacher() async {
    setState(() => _busy = true);
    try {
      await _ensureClassroom();
      final call = ClassroomCallService(
        client: widget.client,
        signaling: widget.signaling,
        classroomId: _classroomId!,
        selfId: widget.teacherId,
        teacherId: widget.teacherId,
        isTeacher: true,
      );

      await call.start(context);
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _startAsStudent() async {
    setState(() => _busy = true);
    try {
      await _ensureClassroom();
      final selfId = widget.client.auth.currentUser?.id ??
          'guest_${DateTime.now().millisecondsSinceEpoch}';
      final call = ClassroomCallService(
        client: widget.client,
        signaling: widget.signaling,
        classroomId: _classroomId!,
        selfId: selfId,
        teacherId: widget.teacherId,
        isTeacher: false,
      );
      await call.start(context);
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const MakeChessLocalizedText('Учитель в классе. Ждём учеников…'),
      content: _busy
          ? const Padding(
              padding: EdgeInsets.all(8.0),
              child: MakeChessLocalizedText('Подключаемся…'),
            )
          : const SizedBox.shrink(),
      actions: [
        TextButton(
          onPressed: _busy ? null : _startAsTeacher,
          child: const MakeChessLocalizedText('Войти как учитель'),
        ),
        FilledButton(
          onPressed: _busy ? null : _startAsStudent,
          child: const MakeChessLocalizedText('Войти как ученик'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const MakeChessLocalizedText('Остановить'),
        ),
      ],
    );
  }
}

Future<void> showSchoolDialogNew({
  required BuildContext context,
  required SupabaseClient client,
  required ClassroomSignaling signaling,
  required String schoolId,
  required String teacherId,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => SchoolDialogNew(
      client: client,
      signaling: signaling,
      schoolId: schoolId,
      teacherId: teacherId,
    ),
  );
}
