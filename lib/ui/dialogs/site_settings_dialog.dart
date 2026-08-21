// MAKECHESS_ADMIN_DIRECT_MESSAGES_V8_5_20260808
// MAKECHESS_ADMIN_CASES_V8_1_20260808
// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
// MAKECHESS_BIG_LOCALIZATION_STAGE_V4_20260807
import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/bg_controller.dart';
import '../../services/lobby_store.dart';
import '../../services/site_design_controller.dart';
import '../../services/teacher_account_store.dart';
import '../app_style.dart';
import '../messages/general_messages_dialog.dart';
import '../board_theme_controller.dart';
import 'board_theme_picker_dialog.dart';
import 'admin_management_panel.dart';
import 'electronic_board_calibration_panel.dart';
import '../../localization/makechess_localization.dart';

Future<void> showSiteSettingsDialog(
  BuildContext context, {
  required BoardThemeController boardTheme,
  AdminCaseNavigationRequest? initialAdminCase,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SiteSettingsDialog(
      boardTheme: boardTheme,
      initialAdminCase: initialAdminCase,
    ),
  );
}

class _SiteSettingsDialog extends StatefulWidget {
  const _SiteSettingsDialog({
    required this.boardTheme,
    this.initialAdminCase,
  });

  final BoardThemeController boardTheme;
  final AdminCaseNavigationRequest? initialAdminCase;

  @override
  State<_SiteSettingsDialog> createState() => _SiteSettingsDialogState();
}

class _SiteSettingsDialogState extends State<_SiteSettingsDialog> {
  final _password = TextEditingController();
  final _message = TextEditingController();
  final _rules = TextEditingController(
    text:
        'Уважайте соперника.\nНе используйте подсказки во время рейтинговой партии.\nСоблюдайте правила честной игры.',
  );

  bool _authorized = false;
  bool _hidePassword = true;
  int _section = 0;
  AdminCaseNavigationRequest? _adminCaseRequest;
  String? _error;
  final Set<String> _blocked = <String>{};
  bool _allowVideo = true;
  bool _allowChat = true;
  bool _allowGuests = true;
  String _adminCredential = 'makechess-admin';
  late SiteDesignSettings _designDraft = SiteDesignController.instance.defaults;
  bool _savingDesign = false;

  @override
  void initState() {
    super.initState();
    _adminCaseRequest = widget.initialAdminCase;
    unawaited(refreshMakeChessAdminReplyUnreadCount());
  }

  @override
  void dispose() {
    _password.dispose();
    _message.dispose();
    _rules.dispose();
    super.dispose();
  }

  void _login() {
    if (_password.text == 'makechess-admin') {
      setState(() {
        _authorized = true;
        _adminCredential = _password.text;
        _designDraft = SiteDesignController.instance.defaults;
        _error = null;
        if (_adminCaseRequest != null) {
          _section = _sectionForTargetKind(_adminCaseRequest!.targetKind);
        }
      });
    } else {
      setState(() => _error = 'Неверный пароль администратора');
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final siteTheme = base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.accent,
        secondary: AppColors.accentSoft,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.appBgSoft,
        labelStyle: AppTextStyles.bodyDim,
        hintStyle: AppTextStyles.caption,
        prefixIconColor: AppColors.textDim,
        suffixIconColor: AppColors.textDim,
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.r10,
          borderSide: const BorderSide(color: AppColors.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.r10,
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.r10,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(AppColors.text),
          backgroundColor: const WidgetStatePropertyAll(AppColors.surfaceSoft),
          overlayColor: const WidgetStatePropertyAll(AppColors.accentGlowSoft),
          side: WidgetStatePropertyAll(
            BorderSide(color: AppColors.accent.withOpacity(.7)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.r10),
          ),
          elevation: const WidgetStatePropertyAll(4),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(AppColors.text),
          backgroundColor: const WidgetStatePropertyAll(AppColors.appBgSoft),
          overlayColor: const WidgetStatePropertyAll(AppColors.accentGlowSoft),
          side: WidgetStatePropertyAll(
            BorderSide(color: AppColors.accent.withOpacity(.55)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.r10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(AppColors.accent),
          overlayColor: const WidgetStatePropertyAll(AppColors.accentGlowSoft),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.r8),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.text
              : AppColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accentDeep
              : AppColors.appBg,
        ),
      ),
    );

    return Theme(
      data: siteTheme,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: _authorized ? 1280 : 440,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height - 40,
          ),
          decoration: BoxDecoration(
            gradient: AppDecorations.panelGradient,
            borderRadius: AppRadius.r16,
            border: Border.all(color: AppColors.accent.withOpacity(.55)),
            boxShadow: const [
              BoxShadow(color: AppColors.accentGlow, blurRadius: 28),
              BoxShadow(
                  color: Colors.black54, blurRadius: 24, offset: Offset(0, 10)),
            ],
          ),
          child: _authorized ? _adminPanel() : _loginPanel(),
        ),
      ),
    );
  }

  Widget _header(String title, {String? subtitle}) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 12, 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.accentGlowSoft,
                borderRadius: AppRadius.r12,
                border: Border.all(color: AppColors.accent.withOpacity(.5)),
              ),
              child: const Icon(Icons.admin_panel_settings,
                  color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MakeChessLocalizedText(title,
                      style: AppTextStyles.sectionTitle),
                  if (subtitle != null)
                    MakeChessLocalizedText(subtitle,
                        style: AppTextStyles.caption),
                ],
              ),
            ),
            IconButton(
              tooltip: MakeChessLocalization.phrase('Закрыть'),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: AppColors.text),
            ),
          ],
        ),
      );

  Widget _loginPanel() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header('Настройка сайта', subtitle: 'Вход для администратора'),
          const Divider(height: 1, color: AppColors.borderSoft),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _password,
                  obscureText: _hidePassword,
                  onSubmitted: (_) => _login(),
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    labelText:
                        MakeChessLocalization.phrase('Пароль администратора'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(_hidePassword
                          ? Icons.visibility
                          : Icons.visibility_off),
                    ),
                    errorText: _error,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _login,
                  icon: const Icon(Icons.login),
                  label: const MakeChessLocalizedText('Войти'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _authorized = true;
                    _adminCredential = 'makechess-admin';
                    _designDraft = SiteDesignController.instance.defaults;
                  }),
                  icon: const Icon(Icons.construction),
                  label:
                      const MakeChessLocalizedText('Временный вход без пароля'),
                ),
                const SizedBox(height: 10),
                const MakeChessLocalizedText(
                  'Режим разработки. Кнопка будет удалена перед запуском административного доступа.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      );

  int _sectionForTargetKind(String kind) => switch (kind) {
        'school' => 4,
        'teacher' => 5,
        'tournament' => 6,
        _ => 3,
      };

  AdminEntityKind _entityKindForSection(int section) => switch (section) {
        4 => AdminEntityKind.school,
        5 => AdminEntityKind.teacher,
        6 => AdminEntityKind.tournament,
        _ => AdminEntityKind.player,
      };

  void _openAdminCase(AdminCaseNavigationRequest request) {
    setState(() {
      _adminCaseRequest = request;
      _section = _sectionForTargetKind(request.targetKind);
    });
  }

  Widget _adminPanelForSection(int section) {
    final request = _adminCaseRequest;
    final expectedKind = _entityKindForSection(section);
    final requestMatches =
        request != null && _sectionForTargetKind(request.targetKind) == section;
    return AdminManagementPanel(
      key: ValueKey<String>(
        requestMatches
            ? '${request!.targetKind}:${request.targetId}:${request.caseId}'
            : '${expectedKind.name}:normal',
      ),
      kind: expectedKind,
      initialTargetId: requestMatches ? request!.targetId : null,
      initialCaseId: requestMatches ? request!.caseId : null,
    );
  }

  Widget _adminPanel() => Column(
        children: [
          _header(
            MakeChessLocalization.phrase('Настройка сайта'),
            subtitle:
                MakeChessLocalization.phrase('Панель управления Makechess'),
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          AdminReminderBar(
            onOpen: () => setState(() => _section = 3),
          ),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _nav(0, Icons.dashboard_outlined, 'Обзор'),
                      _nav(1, Icons.palette_outlined, 'Дизайн сайта'),
                      _nav(2, Icons.workspace_premium_outlined, 'Тарифы'),
                      _nav(3, Icons.people_outline, 'Игроки'),
                      _nav(4, Icons.school_outlined, 'Школы'),
                      _nav(5, Icons.co_present_outlined, 'Учителя'),
                      _nav(6, Icons.emoji_events_outlined, 'Турниры'),
                      _nav(11, Icons.sensors_outlined, 'Электронная доска'),
                      _nav(7, Icons.policy_outlined, 'Разрешения'),
                      _nav(8, Icons.gavel_outlined, 'Правила сайта'),
                      ValueListenableBuilder<int>(
                        valueListenable: makechessAdminReplyUnreadCount,
                        builder: (_, count, __) => _nav(
                          9,
                          Icons.campaign_outlined,
                          'Сообщения',
                          badgeCount: count,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Divider(height: 1, color: AppColors.borderSoft),
                      ),
                      _nav(10, Icons.archive_outlined, 'Архив'),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, color: AppColors.borderSoft),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: _sectionBody(),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _nav(
    int index,
    IconData icon,
    String label, {
    int badgeCount = 0,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: InkWell(
          onTap: () => setState(() => _section = index),
          borderRadius: AppRadius.r10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: AppDecorations.neoButton(active: _section == index),
            child: Row(
              children: [
                Icon(icon,
                    size: 20,
                    color: _section == index
                        ? AppColors.accent
                        : AppColors.textDim),
                const SizedBox(width: 10),
                Expanded(
                  child: MakeChessLocalizedText(
                    label,
                    style: AppTextStyles.buttonCompact,
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  Widget _sectionBody() {
    switch (_section) {
      case 1:
        return _siteDesign();
      case 2:
        return _tariffs();
      case 3:
        return _adminPanelForSection(3);
      case 4:
        return _adminPanelForSection(4);
      case 5:
        return _adminPanelForSection(5);
      case 6:
        return _adminPanelForSection(6);
      case 7:
        return _permissions();
      case 8:
        return _rulesPanel();
      case 9:
        return _messages();
      case 10:
        return const AdminArchivePanel();
      case 11:
        return const ElectronicBoardCalibrationPanel();
      default:
        return _overview();
    }
  }

  Widget _title(String text, String hint) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MakeChessLocalizedText(text, style: AppTextStyles.sectionTitle),
          const SizedBox(height: 4),
          MakeChessLocalizedText(hint, style: AppTextStyles.bodyDim),
          const SizedBox(height: 18),
        ],
      );

  Widget _overview() => ListView(
        children: [
          _title('Обзор', 'Основные показатели и быстрые действия'),
          ValueListenableBuilder<List<LobbyUser>>(
            valueListenable: LobbyStore.instance.users,
            builder: (_, users, __) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric('Сейчас онлайн', '${users.length}', Icons.people,
                    AppColors.success),
                _metric('Заблокировано', '${_blocked.length}', Icons.block,
                    AppColors.danger),
                _metric('Активных тарифов', '3', Icons.workspace_premium,
                    AppColors.warning),
                _metric('Состояние', 'Работает', Icons.check_circle,
                    AppColors.accent),
              ],
            ),
          ),
        ],
      );

  Widget _metric(String label, String value, IconData icon, Color color) =>
      Container(
        width: 205,
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color),
          const SizedBox(height: 14),
          MakeChessLocalizedText(value,
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 24)),
          MakeChessLocalizedText(label, style: AppTextStyles.caption),
        ]),
      );

  Widget _siteDesign() => ListView(
        children: [
          _title(
            'Дизайн сайта',
            'Настройки по умолчанию. Личные настройки игрока имеют приоритет.',
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _designButton(
                Icons.wallpaper,
                'Тема фона',
                _designDraft.backgroundBase64 == null
                    ? 'Стандартный фон'
                    : 'Своё изображение',
                _pickDefaultBackground,
              ),
              _designButton(
                Icons.dashboard_customize,
                'Тема доски',
                'Цвет светлых и тёмных клеток',
                _pickDefaultBoard,
              ),
              _designButton(
                Icons.extension_outlined,
                'Тема фигур',
                _designDraft.piecesTheme,
                () => _choosePreset(
                  title: 'Тема фигур',
                  current: _designDraft.piecesTheme,
                  values: const ['Классические'],
                  apply: (value) =>
                      _designDraft = _designDraft.copyWith(piecesTheme: value),
                ),
              ),
              _designButton(
                Icons.smart_button_outlined,
                'Тема кнопок',
                _designDraft.buttonsTheme,
                () => _choosePreset(
                  title: 'Тема кнопок',
                  current: _designDraft.buttonsTheme,
                  values: const ['Графит и неон', 'Тёплое дерево', 'Светлая'],
                  apply: (value) =>
                      _designDraft = _designDraft.copyWith(buttonsTheme: value),
                ),
              ),
              _designButton(
                Icons.input_outlined,
                'Тема полей',
                _designDraft.fieldsTheme,
                () => _choosePreset(
                  title: 'Тема полей',
                  current: _designDraft.fieldsTheme,
                  values: const ['Тёмные', 'Светлые'],
                  apply: (value) =>
                      _designDraft = _designDraft.copyWith(fieldsTheme: value),
                ),
              ),
              _designButton(
                Icons.border_style,
                'Тема рамок',
                _designDraft.bordersTheme,
                () => _choosePreset(
                  title: 'Тема рамок',
                  current: _designDraft.bordersTheme,
                  values: const ['Голубое свечение', 'Строгие', 'Мягкие'],
                  apply: (value) =>
                      _designDraft = _designDraft.copyWith(bordersTheme: value),
                ),
              ),
              _designButton(
                Icons.font_download_outlined,
                'Шрифты',
                _designDraft.fontTheme,
                () => _choosePreset(
                  title: 'Шрифты',
                  current: _designDraft.fontTheme,
                  values: const ['Системный', 'Roboto', 'Serif', 'Monospace'],
                  apply: (value) =>
                      _designDraft = _designDraft.copyWith(fontTheme: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppDecorations.card(highlighted: true),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.accent),
                SizedBox(width: 10),
                Expanded(
                  child: MakeChessLocalizedText(
                    'Эти значения увидят новые игроки и игроки без личной темы. '
                    'Настройки, выбранные самим игроком, не перезаписываются.',
                    style: AppTextStyles.bodyDim,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _savingDesign ? null : _saveDefaultDesign,
              icon: _savingDesign
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: MakeChessLocalizedText(
                _savingDesign ? 'Сохранение…' : 'Сохранить дизайн по умолчанию',
              ),
            ),
          ),
        ],
      );

  Widget _designButton(
    IconData icon,
    String title,
    String value,
    VoidCallback onTap,
  ) =>
      SizedBox(
        width: 210,
        height: 112,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.r12,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: AppDecorations.neoButton(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.accent),
                const Spacer(),
                MakeChessLocalizedText(title, style: AppTextStyles.button),
                const SizedBox(height: 2),
                MakeChessLocalizedText(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _pickDefaultBackground() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    if (bytes.length > 5 * 1024 * 1024) {
      _saved('Файл слишком большой. Максимальный размер — 5 МБ.');
      return;
    }
    setState(() {
      _designDraft = _designDraft.copyWith(
        backgroundBase64: base64Encode(bytes),
      );
    });
  }

  Future<void> _pickDefaultBoard() async {
    final result = await showBoardThemePickerDialog(
      context,
      initialLight: Color(_designDraft.boardLight),
      initialDark: Color(_designDraft.boardDark),
      extendedPalette: true,
    );
    if (result == null) return;
    setState(() {
      _designDraft = _designDraft.copyWith(
        boardLight: result.$1.value,
        boardDark: result.$2.value,
      );
    });
  }

  Future<void> _choosePreset({
    required String title,
    required String current,
    required List<String> values,
    required ValueChanged<String> apply,
  }) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: AppColors.surface,
        title: MakeChessLocalizedText(title, style: AppTextStyles.sectionTitle),
        children: [
          for (final value in values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, value),
              child: Row(
                children: [
                  Icon(
                    value == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 10),
                  MakeChessLocalizedText(value, style: AppTextStyles.body),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null) return;
    setState(() => apply(selected));
  }

  Future<void> _saveDefaultDesign() async {
    setState(() => _savingDesign = true);
    try {
      await SiteDesignController.instance.saveDefaults(
        settings: _designDraft,
        adminPassword: _adminCredential,
        boardTheme: widget.boardTheme,
        background: BgController.instance,
      );
      _saved('Дизайн сайта по умолчанию сохранён');
    } catch (error) {
      _saved('Не удалось сохранить дизайн: $error');
    } finally {
      if (mounted) setState(() => _savingDesign = false);
    }
  }

  Widget _tariffs() => ListView(
        children: [
          _title('Тарифы', 'Первичная настройка доступных планов'),
          for (final item in const [
            ('Бесплатный', '0 ₽', 'Игра, чат и базовый анализ'),
            ('Pro', '499 ₽', 'Расширенный анализ и видеосвязь'),
            ('Premium', '999 ₽', 'Все возможности без ограничений'),
          ])
            _card(ListTile(
              leading:
                  const Icon(Icons.workspace_premium, color: AppColors.warning),
              title: MakeChessLocalizedText(item.$1,
                  style: AppTextStyles.panelTitle),
              subtitle:
                  MakeChessLocalizedText(item.$3, style: AppTextStyles.caption),
              trailing:
                  MakeChessLocalizedText(item.$2, style: AppTextStyles.button),
            )),
        ],
      );

  Widget _players() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Игроки', 'Игроки, находящиеся сейчас в контактах'),
          Expanded(
            child: ValueListenableBuilder<List<LobbyUser>>(
              valueListenable: LobbyStore.instance.users,
              builder: (_, users, __) {
                if (users.isEmpty)
                  return const Center(
                      child: MakeChessLocalizedText('Сейчас нет игроков онлайн',
                          style: AppTextStyles.bodyDim));
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (_, i) {
                    final user = users[i];
                    final blocked = _blocked.contains(user.id);
                    return _card(ListTile(
                      leading: CircleAvatar(
                          child: MakeChessLocalizedText(
                              user.username.substring(0, 1).toUpperCase())),
                      title: MakeChessLocalizedText(user.username,
                          style: AppTextStyles.body),
                      subtitle: MakeChessLocalizedText(
                          user.isMe ? 'Текущий пользователь' : 'Онлайн',
                          style: AppTextStyles.caption),
                      trailing: TextButton.icon(
                        onPressed: user.isMe
                            ? null
                            : () => setState(() => blocked
                                ? _blocked.remove(user.id)
                                : _blocked.add(user.id)),
                        icon: Icon(blocked ? Icons.lock_open : Icons.block),
                        label: MakeChessLocalizedText(
                            blocked ? 'Разблокировать' : 'Заблокировать'),
                      ),
                    ));
                  },
                );
              },
            ),
          ),
        ],
      );

  Widget _permissions() => ListView(
        children: [
          _title('Разрешения', 'Общие возможности пользователей сайта'),
          _switch('Видеосвязь', 'Разрешить видеовызовы между игроками',
              _allowVideo, (v) => setState(() => _allowVideo = v)),
          _switch('Чат', 'Разрешить сообщения во время игры', _allowChat,
              (v) => setState(() => _allowChat = v)),
          _switch('Гостевой доступ', 'Разрешить игру без регистрации',
              _allowGuests, (v) => setState(() => _allowGuests = v)),
        ],
      );

  Widget _switch(String title, String subtitle, bool value,
          ValueChanged<bool> onChanged) =>
      _card(SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.accent,
        title: MakeChessLocalizedText(title, style: AppTextStyles.body),
        subtitle:
            MakeChessLocalizedText(subtitle, style: AppTextStyles.caption),
      ));

  Widget _rulesPanel() => ListView(
        children: [
          _title('Правила сайта', 'Текст правил для пользователей Makechess'),
          TextField(
              controller: _rules,
              maxLines: 12,
              style: AppTextStyles.body,
              decoration: InputDecoration(border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
                onPressed: () => _saved('Правила сохранены в черновик'),
                icon: const Icon(Icons.save),
                label: const MakeChessLocalizedText('Сохранить')),
          ),
        ],
      );

  Widget _messages() => AdminRepliesInbox(
        onOpen: _openAdminCase,
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _AdminDirectMessageComposer(),
            const SizedBox(height: 18),
            const Divider(color: AppColors.borderSoft),
            const SizedBox(height: 14),
            _title('Объявление для всех игроков', 'Общее сообщение сайта'),
            TextField(
              controller: _message,
              minLines: 4,
              maxLines: 8,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                labelText: MakeChessLocalization.phrase('Текст сообщения'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _message.text.trim().isEmpty
                    ? () => _saved('Введите текст сообщения')
                    : () => _saved('Сообщение подготовлено к отправке'),
                icon: const Icon(Icons.send),
                label: const MakeChessLocalizedText('Отправить всем'),
              ),
            ),
          ],
        ),
      );

  Widget _card(Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: AppDecorations.card(),
        child: child,
      );

  void _saved(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: MakeChessLocalizedText(text)));
}

class _AdminDirectRecipient {
  const _AdminDirectRecipient({
    required this.targetId,
    required this.recipientId,
    required this.targetKind,
    required this.name,
    required this.subtitle,
  });

  final String targetId;
  final String recipientId;
  final String targetKind;
  final String name;
  final String subtitle;

  bool get canReceive => recipientId.trim().isNotEmpty;
}

class _AdminDirectMessageComposer extends StatefulWidget {
  const _AdminDirectMessageComposer();

  @override
  State<_AdminDirectMessageComposer> createState() =>
      _AdminDirectMessageComposerState();
}

class _AdminDirectMessageComposerState
    extends State<_AdminDirectMessageComposer> {
  final TextEditingController _userSearch = TextEditingController();
  final TextEditingController _teacherSchoolSearch = TextEditingController();
  final TextEditingController _message = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  List<_AdminDirectRecipient> _users = <_AdminDirectRecipient>[];
  List<_AdminDirectRecipient> _teachersAndSchools = <_AdminDirectRecipient>[];
  _AdminDirectRecipient? _selected;

  String _t(
    String source, {
    Map<String, Object?> params = const <String, Object?>{},
  }) =>
      MakeChessLocalization.phrase(source, params: params);

  @override
  void initState() {
    super.initState();
    _loadRecipients();
  }

  @override
  void dispose() {
    _userSearch.dispose();
    _teacherSchoolSearch.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadRecipients() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        Supabase.instance.client.from('profiles').select(),
        TeacherAccountStore.instance.loadAccounts(),
      ]);

      final rawProfiles = results[0];
      final profiles = rawProfiles is List ? rawProfiles : const <dynamic>[];
      final users = <_AdminDirectRecipient>[];

      for (final item in profiles.whereType<Map>()) {
        final row = Map<String, dynamic>.from(item);
        final id = '${row['id'] ?? ''}'.trim();
        if (id.isEmpty) continue;

        final name =
            '${row['nickname'] ?? row['name'] ?? row['email'] ?? id}'.trim();
        final rating = '${row['rating'] ?? ''}'.trim();
        final country = '${row['country'] ?? ''}'.trim();
        final subtitle = <String>[
          if (rating.isNotEmpty) '${_t('Рейтинг')}: $rating',
          if (country.isNotEmpty) country,
        ].join(' • ');

        users.add(
          _AdminDirectRecipient(
            targetId: id,
            recipientId: id,
            targetKind: 'player',
            name: name.isEmpty ? id : name,
            subtitle: subtitle,
          ),
        );
      }

      final teacherSchool = <_AdminDirectRecipient>[];
      final seen = <String>{};
      final accounts =
          results[1] is List ? results[1] as List : const <dynamic>[];

      for (final dynamic account in accounts) {
        final accountId = '${account.id}'.trim();
        final schoolName = '${account.schoolName}'.trim();
        final login = '${account.login}'.trim();
        final ownerUserId = '${account.ownerUserId}'.trim();

        if (login.isNotEmpty) {
          final key = 'teacher:$ownerUserId:$login';
          if (seen.add(key)) {
            teacherSchool.add(
              _AdminDirectRecipient(
                targetId: ownerUserId.isEmpty ? accountId : ownerUserId,
                recipientId: ownerUserId,
                targetKind: 'teacher',
                name: login,
                subtitle: '${_t('Учитель')} • ${_t('Школа')}: '
                    '${schoolName.isEmpty ? '—' : schoolName}',
              ),
            );
          }
        }

        if (schoolName.isNotEmpty) {
          final key = 'school:$accountId:$schoolName';
          if (seen.add(key)) {
            teacherSchool.add(
              _AdminDirectRecipient(
                targetId: accountId,
                recipientId: ownerUserId,
                targetKind: 'school',
                name: schoolName,
                subtitle: '${_t('Школа')} • ${_t('Учитель')}: '
                    '${login.isEmpty ? '—' : login}',
              ),
            );
          }
        }
      }

      users.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      teacherSchool.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      if (!mounted) return;
      setState(() {
        _users = users;
        _teachersAndSchools = teacherSchool;
        _loading = false;

        final selected = _selected;
        if (selected != null) {
          final all = <_AdminDirectRecipient>[
            ...users,
            ...teacherSchool,
          ];
          final matches = all.where(
            (item) =>
                item.targetKind == selected.targetKind &&
                item.targetId == selected.targetId,
          );
          _selected = matches.isEmpty ? null : matches.first;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Не удалось загрузить список получателей: {error}',
              params: <String, Object?>{'error': '$error'},
            ),
          ),
        ),
      );
    }
  }

  List<_AdminDirectRecipient> _filtered(
    List<_AdminDirectRecipient> source,
    String query,
  ) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return source;
    return source
        .where(
          (item) =>
              item.name.toLowerCase().contains(needle) ||
              item.subtitle.toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  Future<void> _send() async {
    final recipient = _selected;
    final body = _message.text.trim();
    if (recipient == null || body.isEmpty || _sending) return;

    if (!recipient.canReceive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('У выбранного получателя нет связанного аккаунта'),
          ),
        ),
      );
      return;
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || user.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Для отправки сообщения требуется вход администратора'),
          ),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await MakeChessMessageRealtimeService.instance.start(client);
      await MakeChessMessageRealtimeService.instance.send(
        MakeChessMessage(
          id: 'admin_direct_${DateTime.now().microsecondsSinceEpoch}',
          recipientId: recipient.recipientId,
          senderId: user.id,
          senderName: _t('Администратор MakeChess'),
          category: 'admin_direct',
          title: 'Личное сообщение администрации',
          body: body,
          createdAt: DateTime.now(),
          metadata: <String, dynamic>{
            'targetKind': recipient.targetKind,
            'targetId': recipient.targetId,
            'recipientName': recipient.name,
            'adminDirect': true,
          },
        ),
      );

      if (!mounted) return;
      _message.clear();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Личное сообщение отправлено'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Не удалось отправить личное сообщение: {error}',
              params: <String, Object?>{'error': '$error'},
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _recipientSearch({
    required String title,
    required String hint,
    required TextEditingController controller,
    required List<_AdminDirectRecipient> items,
  }) {
    final filtered = _filtered(items, controller.text);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: AppTextStyles.button),
              ),
              Text(
                _t(
                  'Найдено: {count}',
                  params: <String, Object?>{'count': filtered.length},
                ),
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: hint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _t('Ничего не найдено'),
                      style: AppTextStyles.bodyDim,
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = filtered[index];
                      final selected =
                          _selected?.targetKind == item.targetKind &&
                              _selected?.targetId == item.targetId;

                      return ListTile(
                        dense: true,
                        enabled: item.canReceive,
                        selected: selected,
                        onTap: item.canReceive
                            ? () => setState(() => _selected = item)
                            : null,
                        leading: Icon(
                          item.targetKind == 'player'
                              ? Icons.person_outline
                              : item.targetKind == 'teacher'
                                  ? Icons.co_present_outlined
                                  : Icons.school_outlined,
                          color:
                              selected ? AppColors.accent : AppColors.textDim,
                        ),
                        title: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body,
                        ),
                        subtitle: Text(
                          item.canReceive
                              ? item.subtitle
                              : '${item.subtitle} • '
                                  '${_t('Нет связанного аккаунта')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption,
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.accent,
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final canSend =
        selected != null && _message.text.trim().isNotEmpty && !_sending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.mail_outline,
              color: AppColors.accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _t('Личное сообщение'),
                style: AppTextStyles.sectionTitle,
              ),
            ),
            IconButton(
              tooltip: _t('Обновить списки'),
              onPressed: _loading ? null : _loadRecipients,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _t(
            'Выберите одного зарегистрированного пользователя, учителя или школу.',
          ),
          style: AppTextStyles.bodyDim,
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final userSearch = _recipientSearch(
                title: _t('Все зарегистрированные пользователи'),
                hint: _t('Поиск пользователя'),
                controller: _userSearch,
                items: _users,
              );
              final teacherSchoolSearch = _recipientSearch(
                title: _t('Все зарегистрированные учителя и школы'),
                hint: _t('Поиск учителя или школы'),
                controller: _teacherSchoolSearch,
                items: _teachersAndSchools,
              );

              if (constraints.maxWidth < 760) {
                return Column(
                  children: [
                    userSearch,
                    const SizedBox(height: 10),
                    teacherSchoolSearch,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: userSearch),
                  const SizedBox(width: 10),
                  Expanded(child: teacherSchoolSearch),
                ],
              );
            },
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: AppDecorations.card(highlighted: selected != null),
          child: Row(
            children: [
              const Icon(Icons.alternate_email, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: selected == null
                    ? Text(
                        _t('Получатель не выбран'),
                        style: AppTextStyles.bodyDim,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_t('Выбранный получатель')}: ${selected.name}',
                            style: AppTextStyles.body,
                          ),
                          if (selected.subtitle.trim().isNotEmpty)
                            Text(
                              selected.subtitle,
                              style: AppTextStyles.caption,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _message,
          minLines: 4,
          maxLines: 8,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: _t('Текст личного сообщения'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: canSend ? _send : null,
            icon: _sending
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_t('Отправить выбранному')),
          ),
        ),
      ],
    );
  }
}
