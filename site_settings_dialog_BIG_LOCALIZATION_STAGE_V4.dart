// MAKECHESS_BIG_LOCALIZATION_STAGE_V4_20260807
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/bg_controller.dart';
import '../../services/lobby_store.dart';
import '../../services/site_design_controller.dart';
import '../app_style.dart';
import '../board_theme_controller.dart';
import 'board_theme_picker_dialog.dart';
import '../../localization/makechess_localization.dart';

Future<void> showSiteSettingsDialog(
  BuildContext context, {
  required BoardThemeController boardTheme,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SiteSettingsDialog(boardTheme: boardTheme),
  );
}

class _SiteSettingsDialog extends StatefulWidget {
  const _SiteSettingsDialog({required this.boardTheme});

  final BoardThemeController boardTheme;

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
  String? _error;
  final Set<String> _blocked = <String>{};
  bool _allowVideo = true;
  bool _allowChat = true;
  bool _allowGuests = true;
  String _adminCredential = 'makechess-admin';
  late SiteDesignSettings _designDraft = SiteDesignController.instance.defaults;
  bool _savingDesign = false;

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
          width: _authorized ? 980 : 440,
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
                  MakeChessLocalizedText(title, style: AppTextStyles.sectionTitle),
                  if (subtitle != null)
                    MakeChessLocalizedText(subtitle, style: AppTextStyles.caption),
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
                    labelText: MakeChessLocalization.phrase('Пароль администратора'),
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
                  label: const MakeChessLocalizedText('Временный вход без пароля'),
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

  Widget _adminPanel() => Column(
        children: [
          _header('Настройка сайта', subtitle: 'Панель управления Makechess'),
          const Divider(height: 1, color: AppColors.borderSoft),
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
                      _nav(4, Icons.policy_outlined, 'Разрешения'),
                      _nav(5, Icons.gavel_outlined, 'Правила сайта'),
                      _nav(6, Icons.campaign_outlined, 'Сообщения'),
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

  Widget _nav(int index, IconData icon, String label) => Padding(
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
                MakeChessLocalizedText(label, style: AppTextStyles.buttonCompact),
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
        return _players();
      case 4:
        return _permissions();
      case 5:
        return _rulesPanel();
      case 6:
        return _messages();
      default:
        return _overview();
    }
  }

  Widget _title(String text, String hint) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: AppTextStyles.sectionTitle),
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
          Text(value, style: AppTextStyles.sectionTitle.copyWith(fontSize: 24)),
          Text(label, style: AppTextStyles.caption),
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
              label: Text(
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
                Text(title, style: AppTextStyles.button),
                const SizedBox(height: 2),
                Text(
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
                  Text(value, style: AppTextStyles.body),
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
              title: MakeChessLocalizedText(item.$1, style: AppTextStyles.panelTitle),
              subtitle: MakeChessLocalizedText(item.$3, style: AppTextStyles.caption),
              trailing: MakeChessLocalizedText(item.$2, style: AppTextStyles.button),
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
                          child: Text(
                              user.username.substring(0, 1).toUpperCase())),
                      title: Text(user.username, style: AppTextStyles.body),
                      subtitle: Text(
                          user.isMe ? 'Текущий пользователь' : 'Онлайн',
                          style: AppTextStyles.caption),
                      trailing: TextButton.icon(
                        onPressed: user.isMe
                            ? null
                            : () => setState(() => blocked
                                ? _blocked.remove(user.id)
                                : _blocked.add(user.id)),
                        icon: Icon(blocked ? Icons.lock_open : Icons.block),
                        label:
                            Text(blocked ? 'Разблокировать' : 'Заблокировать'),
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
        title: Text(title, style: AppTextStyles.body),
        subtitle: MakeChessLocalizedText(subtitle, style: AppTextStyles.caption),
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

  Widget _messages() => ListView(
        children: [
          _title('Сообщения', 'Объявление для всех игроков'),
          TextField(
              controller: _message,
              minLines: 4,
              maxLines: 8,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                  labelText: MakeChessLocalization.phrase('Текст сообщения'), border: OutlineInputBorder())),
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
      );

  Widget _card(Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: AppDecorations.card(),
        child: child,
      );

  void _saved(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
