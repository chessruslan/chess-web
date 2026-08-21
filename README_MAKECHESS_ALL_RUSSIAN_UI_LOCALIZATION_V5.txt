MAKECHESS — ALL RUSSIAN UI LOCALIZATION V5.1

V5 itself reached dart format successfully for all 40 target files.
The rollback happened only because the installer checked a class name that
does not exist in the user's exact current teacher_assignment_dialog.dart.

Wrong V5 guard:
  class TeacherAssignmentDialog

Actual current entry point:
  showTeacherAssignmentBuilderDialog

V5.1 changes ONLY that installer guard.
The 40 payload Dart files and all translation work are exactly the same as V5.

The remaining functional guards were checked against the exact V5 payload:
all of them match. The V5 UI marker count is 39/39 as expected.

Run:
  .\INSTALL_MAKECHESS_ALL_RUSSIAN_UI_LOCALIZATION_V5_1.cmd

After DONE:
  .\PUBLISH_MAKECHESS.cmd
