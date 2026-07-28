import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../profile/personal_cabinet_store.dart';
import '../app_style.dart';

enum _CabinetSection {
  training,
  blog,
  settings,
  classic,
  rapid,
  blitz,
  puzzles,
  twoByTwo,
  tournaments,
  communities,
}

extension on _CabinetSection {
  String get title {
    switch (this) {
      case _CabinetSection.training:
        return 'Обучение';
      case _CabinetSection.blog:
        return 'Блог';
      case _CabinetSection.settings:
        return 'Настройки';
      case _CabinetSection.classic:
        return 'Классика';
      case _CabinetSection.rapid:
        return 'Рапид';
      case _CabinetSection.blitz:
        return 'Блиц';
      case _CabinetSection.puzzles:
        return 'Задачи';
      case _CabinetSection.twoByTwo:
        return '2×2';
      case _CabinetSection.tournaments:
        return 'Турниры';
      case _CabinetSection.communities:
        return 'Сообщества';
    }
  }

  IconData get icon {
    switch (this) {
      case _CabinetSection.training:
        return Icons.school;
      case _CabinetSection.blog:
        return Icons.article_outlined;
      case _CabinetSection.settings:
        return Icons.tune;
      case _CabinetSection.classic:
        return Icons.hourglass_bottom;
      case _CabinetSection.rapid:
        return Icons.timer_outlined;
      case _CabinetSection.blitz:
        return Icons.bolt;
      case _CabinetSection.puzzles:
        return Icons.extension;
      case _CabinetSection.twoByTwo:
        return Icons.grid_3x3;
      case _CabinetSection.tournaments:
        return Icons.emoji_events;
      case _CabinetSection.communities:
        return Icons.groups_2;
    }
  }

  CabinetGameType? get gameType {
    switch (this) {
      case _CabinetSection.classic:
        return CabinetGameType.classic;
      case _CabinetSection.rapid:
        return CabinetGameType.rapid;
      case _CabinetSection.blitz:
        return CabinetGameType.blitz;
      case _CabinetSection.puzzles:
        return CabinetGameType.puzzles;
      case _CabinetSection.twoByTwo:
        return CabinetGameType.twoByTwo;
      default:
        return null;
    }
  }
}

Future<void> showPersonalCabinetDialog(
  BuildContext context, {
  required String userId,
  required String initialNickname,
  int initialClassicRating = 1200,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PersonalCabinetDialog(
      userId: userId,
      initialNickname: initialNickname,
      initialClassicRating: initialClassicRating,
    ),
  );
}

class _PersonalCabinetDialog extends StatefulWidget {
  const _PersonalCabinetDialog({
    required this.userId,
    required this.initialNickname,
    required this.initialClassicRating,
  });

  final String userId;
  final String initialNickname;
  final int initialClassicRating;

  @override
  State<_PersonalCabinetDialog> createState() =>
      _PersonalCabinetDialogState();
}

class _PersonalCabinetDialogState extends State<_PersonalCabinetDialog> {
  final PersonalCabinetStore _store = PersonalCabinetStore.instance;

  CabinetProfile? _profile;
  List<CabinetGameRecord> _games = <CabinetGameRecord>[];
  _CabinetSection _section = _CabinetSection.classic;
  bool _loading = true;
  bool _savingSettings = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _store.loadProfile(
        userId: widget.userId,
        initialNickname: widget.initialNickname,
        initialClassicRating: widget.initialClassicRating,
      );
      final games = await _store.loadGames(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _games = games;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть личный кабинет: $error')),
      );
    }
  }

  Future<void> _editProfile() async {
    final profile = _profile;
    if (profile == null) return;
    final edited = await showDialog<CabinetProfile>(
      context: context,
      builder: (_) => _EditCabinetProfileDialog(profile: profile),
    );
    if (edited == null) return;
    await _store.saveProfile(edited);
    if (!mounted) return;
    setState(() => _profile = edited);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Личные данные сохранены локально')),
    );
  }

  Future<void> _setProfile(CabinetProfile profile) async {
    if (_savingSettings) return;
    setState(() {
      _savingSettings = true;
      _profile = profile;
    });
    try {
      await _store.saveProfile(profile);
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  Future<void> _deleteGame(CabinetGameRecord game) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Удалить партию?'),
            content: Text(
              '${game.whiteName} — ${game.blackName}\n'
              '${game.type.title} · ${game.timeControl}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    await _store.deleteGame(userId: widget.userId, gameId: game.id);
    if (!mounted) return;
    setState(() => _games.removeWhere((item) => item.id == game.id));
  }

  Future<void> _copyGame(CabinetGameRecord game) async {
    await Clipboard.setData(ClipboardData(text: game.pgn));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PGN скопирован')),
    );
  }

  Future<void> _showGame(CabinetGameRecord game) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          '${game.whiteName} — ${game.blackName}',
          style: AppTextStyles.sectionTitle,
        ),
        content: SizedBox(
          width: 760,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${game.type.title} · ${game.timeControl} · ${game.result}',
                style: AppTextStyles.bodyDim,
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 420),
                padding: const EdgeInsets.all(14),
                decoration: AppDecorations.card(),
                child: SingleChildScrollView(
                  child: SelectableText(game.pgn, style: AppTextStyles.mono),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _copyGame(game),
            icon: const Icon(Icons.copy),
            label: const Text('Скопировать PGN'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final width = (media.width - 36).clamp(760.0, 1240.0).toDouble();
    final height = (media.height - 36).clamp(620.0, 860.0).toDouble();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(18),
      child: Container(
        width: width,
        height: height,
        decoration: AppDecorations.panel(bright: true),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _profile == null
                ? _buildLoadError()
                : Column(
                    children: [
                      _buildTitleBar(),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildProfileHeader(_profile!),
                              const SizedBox(height: 14),
                              _buildRatings(_profile!),
                              const SizedBox(height: 14),
                              _buildSectionButtons(),
                              const SizedBox(height: 14),
                              _buildSectionContent(_profile!),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const SizedBox(height: 12),
          const Text('Личный кабинет не загрузился',
              style: AppTextStyles.sectionTitle),
          const SizedBox(height: 12),
          FilledButton(onPressed: _load, child: const Text('Повторить')),
        ],
      ),
    );
  }

  Widget _buildTitleBar() {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1D2229),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_circle, color: AppColors.accent),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Личный кабинет', style: AppTextStyles.sectionTitle),
          ),
          Text(
            'Данные пока сохраняются в этом браузере',
            style: AppTextStyles.caption.copyWith(color: AppColors.warning),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Закрыть',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: AppColors.text),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(CabinetProfile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(highlighted: true),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfilePhoto(profile: profile, size: 104),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.fullName, style: AppTextStyles.sectionTitle),
                const SizedBox(height: 3),
                Text('@${profile.nickname}', style: AppTextStyles.bodyDim),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _info(Icons.workspace_premium, profile.chessTitle,
                        empty: 'Шахматное звание не указано'),
                    _info(Icons.location_on_outlined,
                        <String>[profile.city, profile.country]
                            .where((value) => value.trim().isNotEmpty)
                            .join(', '),
                        empty: 'Город не указан'),
                    _info(Icons.groups_outlined, profile.club,
                        empty: 'Клуб не указан'),
                    _info(
                      Icons.calendar_month,
                      'В MakeChess с ${_formatMonthYear(profile.createdAt)}',
                    ),
                  ],
                ),
                if (profile.about.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(profile.about, style: AppTextStyles.body),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _editProfile,
            icon: const Icon(Icons.edit),
            label: const Text('Редактировать'),
          ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String text, {String? empty}) {
    final value = text.trim().isEmpty ? (empty ?? 'Не указано') : text.trim();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textDim),
        const SizedBox(width: 5),
        Text(value, style: AppTextStyles.caption),
      ],
    );
  }

  Widget _buildRatings(CabinetProfile profile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final cardWidth = ((constraints.maxWidth - gap * 4) / 5)
            .clamp(132.0, 240.0)
            .toDouble();
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: CabinetGameType.values.map((type) {
            final count = _games.where((game) => game.type == type).length;
            return SizedBox(
              width: cardWidth,
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: AppDecorations.card(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.title, style: AppTextStyles.caption),
                    const SizedBox(height: 5),
                    Text(
                      '${profile.ratingFor(type)}',
                      style: AppTextStyles.sectionTitle.copyWith(
                        fontSize: 23,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text('$count сохранённых партий',
                        style: AppTextStyles.caption),
                  ],
                ),
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }

  Widget _buildSectionButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _CabinetSection.values.map((section) {
        final selected = section == _section;
        return FilledButton.tonalIcon(
          onPressed: () => setState(() => _section = section),
          icon: Icon(section.icon, size: 18),
          label: Text(section.title),
          style: FilledButton.styleFrom(
            backgroundColor:
                selected ? AppColors.accentDeep : AppColors.surfaceSoft,
            foregroundColor: AppColors.text,
            side: BorderSide(
              color: selected ? AppColors.accent : AppColors.borderSoft,
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildSectionContent(CabinetProfile profile) {
    final gameType = _section.gameType;
    if (gameType != null) return _buildGamesSection(gameType);

    switch (_section) {
      case _CabinetSection.settings:
        return _buildSettings(profile);
      case _CabinetSection.training:
        return _placeholder(
          icon: Icons.school,
          title: 'Обучение',
          text:
              'Здесь будут уроки, домашние задания, учителя, ученики, грамоты и дипломы. '
              'Структура уже отделена от архива партий и позже будет подключена к базе.',
        );
      case _CabinetSection.blog:
        return _placeholder(
          icon: Icons.article_outlined,
          title: 'Блог',
          text:
              'Здесь будут статьи, разборы партий, учебные материалы и черновики пользователя.',
        );
      case _CabinetSection.tournaments:
        return _placeholder(
          icon: Icons.emoji_events,
          title: 'Турниры',
          text:
              'Здесь появятся текущие и завершённые турниры, регистрации, результаты и занятые места.',
        );
      case _CabinetSection.communities:
        return _placeholder(
          icon: Icons.groups_2,
          title: 'Сообщества',
          text:
              'Здесь будут клубы, школы, команды, подписки и приглашения в сообщества.',
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGamesSection(CabinetGameType type) {
    final games = _games.where((game) => game.type == type).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_section.icon, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${type.title}: сохранённые партии',
                  style: AppTextStyles.panelTitle,
                ),
              ),
              Text('${games.length}', style: AppTextStyles.bodyDim),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Партия добавляется сюда при нажатии «Скопировать PGN». '
            'Сейчас хранится только текст PGN и короткие данные о партии.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          if (games.isEmpty)
            _emptyArchive(type)
          else
            ...games.map(_gameCard),
        ],
      ),
    );
  }

  Widget _emptyArchive(CabinetGameType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.r12,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 40, color: AppColors.textDim),
          const SizedBox(height: 8),
          Text('В разделе «${type.title}» пока нет партий',
              style: AppTextStyles.body),
          const SizedBox(height: 4),
          const Text(
            'Откройте список ходов и нажмите «Скопировать PGN».',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _gameCard(CabinetGameRecord game) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.r12,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: AppRadius.r10,
            ),
            child: Text(
              game.result,
              textAlign: TextAlign.center,
              style: AppTextStyles.button.copyWith(color: AppColors.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${game.whiteName} — ${game.blackName}',
                    style: AppTextStyles.button),
                const SizedBox(height: 4),
                Text(
                  '${_formatDateTime(game.savedAt)} · ${game.timeControl} · ${game.source}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _showGame(game),
            icon: const Icon(Icons.open_in_new, size: 17),
            label: const Text('Открыть'),
          ),
          TextButton.icon(
            onPressed: () => _copyGame(game),
            icon: const Icon(Icons.copy, size: 17),
            label: const Text('PGN'),
          ),
          IconButton(
            tooltip: 'Удалить',
            onPressed: () => _deleteGame(game),
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          ),
        ],
      ),
    );
  }

  Widget _buildSettings(CabinetProfile profile) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Настройки личного кабинета',
              style: AppTextStyles.panelTitle),
          const SizedBox(height: 8),
          _settingSwitch(
            title: 'Показывать профиль другим пользователям',
            subtitle: 'Позже этот параметр будет применяться на сервере.',
            value: profile.profileVisible,
            onChanged: (value) =>
                _setProfile(profile.copyWith(profileVisible: value)),
          ),
          _settingSwitch(
            title: 'Разрешать приглашения в игру',
            subtitle: 'Подготовлено для будущей серверной настройки.',
            value: profile.gameInvitesEnabled,
            onChanged: (value) =>
                _setProfile(profile.copyWith(gameInvitesEnabled: value)),
          ),
          _settingSwitch(
            title: 'Разрешать видеовызовы',
            subtitle: 'Позже будет связано с адресной видеосвязью.',
            value: profile.videoCallsEnabled,
            onChanged: (value) =>
                _setProfile(profile.copyWith(videoCallsEnabled: value)),
          ),
          _settingSwitch(
            title: 'Уведомления',
            subtitle: 'Игры, уроки, турниры и сообщения.',
            value: profile.notificationsEnabled,
            onChanged: (value) =>
                _setProfile(profile.copyWith(notificationsEnabled: value)),
          ),
          if (_savingSettings)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _settingSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: AppTextStyles.body),
      subtitle: Text(subtitle, style: AppTextStyles.caption),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _placeholder({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.accent),
          const SizedBox(height: 12),
          Text(title, style: AppTextStyles.sectionTitle),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyDim,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Этот раздел создан в интерфейсе. Данные подключим к базе следующим этапом.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({required this.profile, required this.size});

  final CabinetProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    final raw = profile.photoBase64;
    if (raw != null && raw.isNotEmpty) {
      try {
        image = MemoryImage(base64Decode(raw));
      } catch (_) {}
    }

    final initial = profile.nickname.trim().isEmpty
        ? '?'
        : profile.nickname.trim().characters.first.toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceSoft,
        border: Border.all(color: AppColors.accent, width: 2),
        image: image == null
            ? null
            : DecorationImage(image: image, fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: image == null
          ? Text(
              initial,
              style: AppTextStyles.sectionTitle.copyWith(fontSize: size * 0.38),
            )
          : null,
    );
  }
}

class _EditCabinetProfileDialog extends StatefulWidget {
  const _EditCabinetProfileDialog({required this.profile});

  final CabinetProfile profile;

  @override
  State<_EditCabinetProfileDialog> createState() =>
      _EditCabinetProfileDialogState();
}

class _EditCabinetProfileDialogState
    extends State<_EditCabinetProfileDialog> {
  late final TextEditingController _nickname;
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _city;
  late final TextEditingController _country;
  late final TextEditingController _birthYear;
  late final TextEditingController _chessTitle;
  late final TextEditingController _club;
  late final TextEditingController _about;
  late final TextEditingController _favoriteControl;
  late final TextEditingController _socialLink;

  String? _photoBase64;
  bool _photoRemoved = false;
  bool _pickingPhoto = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nickname = TextEditingController(text: p.nickname);
    _firstName = TextEditingController(text: p.firstName);
    _lastName = TextEditingController(text: p.lastName);
    _city = TextEditingController(text: p.city);
    _country = TextEditingController(text: p.country);
    _birthYear = TextEditingController(text: p.birthYear);
    _chessTitle = TextEditingController(text: p.chessTitle);
    _club = TextEditingController(text: p.club);
    _about = TextEditingController(text: p.about);
    _favoriteControl = TextEditingController(text: p.favoriteControl);
    _socialLink = TextEditingController(text: p.socialLink);
    _photoBase64 = p.photoBase64;
  }

  @override
  void dispose() {
    _nickname.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _city.dispose();
    _country.dispose();
    _birthYear.dispose();
    _chessTitle.dispose();
    _club.dispose();
    _about.dispose();
    _favoriteControl.dispose();
    _socialLink.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return;
      if (file.size > 1500 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Фотография должна быть меньше 1,5 МБ'),
          ),
        );
        return;
      }
      setState(() {
        _photoBase64 = base64Encode(Uint8List.fromList(bytes));
        _photoRemoved = false;
      });
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  CabinetProfile get _previewProfile => widget.profile.copyWith(
        nickname: _nickname.text.trim().isEmpty
            ? widget.profile.nickname
            : _nickname.text.trim(),
        photoBase64: _photoBase64,
        clearPhoto: _photoRemoved,
      );

  void _save() {
    final nickname = _nickname.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите ник')),
      );
      return;
    }

    Navigator.of(context).pop(
      widget.profile.copyWith(
        nickname: nickname,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        city: _city.text.trim(),
        country: _country.text.trim(),
        birthYear: _birthYear.text.trim(),
        chessTitle: _chessTitle.text.trim(),
        club: _club.text.trim(),
        about: _about.text.trim(),
        favoriteControl: _favoriteControl.text.trim(),
        socialLink: _socialLink.text.trim(),
        photoBase64: _photoBase64,
        clearPhoto: _photoRemoved,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Редактировать профиль',
          style: AppTextStyles.sectionTitle),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _ProfilePhoto(profile: _previewProfile, size: 92),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _pickingPhoto ? null : _pickPhoto,
                          icon: const Icon(Icons.add_a_photo),
                          label: Text(_pickingPhoto
                              ? 'Загрузка…'
                              : 'Прикрепить фотографию'),
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _photoBase64 = null;
                            _photoRemoved = true;
                          }),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Убрать фотографию'),
                        ),
                        const Text('До 1,5 МБ. Пока хранится только в браузере.',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _twoFields(
                _field(_nickname, 'Ник *'),
                _field(_chessTitle, 'Шахматный разряд или звание'),
              ),
              const SizedBox(height: 10),
              _twoFields(
                _field(_firstName, 'Имя'),
                _field(_lastName, 'Фамилия'),
              ),
              const SizedBox(height: 10),
              _twoFields(
                _field(_city, 'Город'),
                _field(_country, 'Страна'),
              ),
              const SizedBox(height: 10),
              _twoFields(
                _field(
                  _birthYear,
                  'Год рождения — необязательно',
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                ),
                _field(_club, 'Школа или клуб'),
              ),
              const SizedBox(height: 10),
              _twoFields(
                _field(_favoriteControl, 'Любимый контроль времени'),
                _field(_socialLink, 'Сайт или социальная сеть'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _about,
                minLines: 3,
                maxLines: 5,
                style: AppTextStyles.body,
                decoration: AppInputs.dark(labelText: 'Кратко о себе'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text('Сохранить'),
        ),
      ],
    );
  }

  Widget _twoFields(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: AppTextStyles.body,
      decoration: AppInputs.dark(labelText: label),
    );
  }
}

String _formatDateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year}, '
      '${two(value.hour)}:${two(value.minute)}';
}

String _formatMonthYear(DateTime value) {
  const months = <String>[
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  return '${months[value.month - 1]} ${value.year}';
}
