MAKECHESS V8.3.1

Исправляет одну точечную ошибку V8.3:
переменная _archiveDeleteConfirmId была объявлена в _AdminManagementPanelState,
а используется в _AdminArchivePanelState.

V8.3.1:
- удаляет объявление из неправильного класса;
- добавляет его в _AdminArchivePanelState;
- запускает dart format;
- проверяет, что поле находится именно в правильном классе;
- при ошибке восстанавливает резервную копию.

Команда:
  .\INSTALL_MAKECHESS_ADMIN_DELETE_FIELD_FIX_V8_3_1.cmd
