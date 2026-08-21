// MAKECHESS_BIG_LOCALIZATION_STAGE_V4_20260807
import 'dart:async';
import 'package:flutter/material.dart';

import 'app_style.dart';
import '../localization/makechess_localization.dart';

const List<String> kSupportedLanguageCodes = kMakeChessSupportedLanguageCodes;

const Map<String, String> kLanguageLabels = kMakeChessLanguageLabels;

const Map<String, String> kLanguageFlags = kMakeChessLanguageFlags;

final ValueNotifier<String> makechessLearningTopBarLabel =
    ValueNotifier<String>('Учиться');

String _makechessCoreLearningLabel(String value) {
  final raw = value.trim();
  if (raw.isEmpty || raw == 'Учиться') {
    return MakeChessLocalization.text(MakeChessTextKey.learn);
  }
  const teacherPrefix = 'Учитель: ';
  if (raw.startsWith(teacherPrefix)) {
    return MakeChessLocalization.text(
      MakeChessTextKey.teacherWithName,
      params: <String, Object?>{'name': raw.substring(teacherPrefix.length)},
    );
  }
  const studentPrefix = 'Ученик: ';
  if (raw.startsWith(studentPrefix)) {
    return MakeChessLocalization.text(
      MakeChessTextKey.studentWithName,
      params: <String, Object?>{'name': raw.substring(studentPrefix.length)},
    );
  }
  return raw;
}

class CommonTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onTitleTap;

  final VoidCallback? onPlayHere;
  final VoidCallback? onAutomaticSearch;
  final VoidCallback? onSearchFromList;

  final VoidCallback? onLearn;
  final VoidCallback? onTeacherAvatar;
  final VoidCallback? onLearnAsTeacher;
  final VoidCallback? onLearnAsStudent;
  final VoidCallback? onSchool;
  final VoidCallback? onPuzzles;
  final VoidCallback? onTeams;
  final VoidCallback? onTournaments;
  final VoidCallback? onWatch;
  final VoidCallback? onCommunity;

  final VoidCallback? onOpenLobby;
  final VoidCallback? onOpenGameSettings;
  final VoidCallback? onOpenMoves;
  final VoidCallback? onOpenChat;

  final VoidCallback? onBackgroundTheme;
  final VoidCallback? onBoardTheme;
  final VoidCallback? onGptSettings;
  final VoidCallback? onSiteSettings;
  final VoidCallback? onMessages;
  final int unreadMessages;
  final VoidCallback? onPersonalCabinet;

  final VoidCallback? onVoiceCall;
  final VoidCallback? onVideoCall;
  final VoidCallback? onHangup;

  final VoidCallback? onLoginTap;

  final bool showScale;
  final double? scalePercent;
  final VoidCallback? onScaleMinus;
  final VoidCallback? onScalePlus;
  final VoidCallback? onScaleReset;

  final bool hasIncomingCall;
  final String? incomingFrom;
  final VoidCallback? onAcceptCall;
  final VoidCallback? onDeclineCall;
  final bool blink;

  final String currentLanguage;
  final ValueChanged<String>? onLanguageChanged;

  const CommonTopBar({
    super.key,
    this.onTitleTap,
    this.onPlayHere,
    this.onAutomaticSearch,
    this.onSearchFromList,
    this.onLearn,
    this.onTeacherAvatar,
    this.onLearnAsTeacher,
    this.onLearnAsStudent,
    this.onSchool,
    this.onPuzzles,
    this.onTeams,
    this.onTournaments,
    this.onWatch,
    this.onCommunity,
    this.onOpenLobby,
    this.onOpenGameSettings,
    this.onOpenMoves,
    this.onOpenChat,
    this.onBackgroundTheme,
    this.onBoardTheme,
    this.onGptSettings,
    this.onSiteSettings,
    this.onMessages,
    this.unreadMessages = 0,
    this.onPersonalCabinet,
    this.onVoiceCall,
    this.onVideoCall,
    this.onHangup,
    this.onLoginTap,
    this.showScale = true,
    this.scalePercent,
    this.onScaleMinus,
    this.onScalePlus,
    this.onScaleReset,
    this.hasIncomingCall = false,
    this.incomingFrom,
    this.onAcceptCall,
    this.onDeclineCall,
    this.blink = true,
    this.currentLanguage = 'RU',
    this.onLanguageChanged,
  });

  @override
  Size get preferredSize => const Size.fromHeight(62);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool mobile = constraints.maxWidth < 760;
        if (mobile) return _buildMobile(context);
        return _buildDesktop(context, constraints.maxWidth);
      },
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Container(
      height: preferredSize.height,
      decoration: AppDecorations.topBar(),
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 3),
      child: Column(
        children: [
          InkWell(
            onTap: onTitleTap,
            borderRadius: AppRadius.r8,
            child: Text(
              'Makechess',
              style: AppTextStyles.topBarTitle.copyWith(fontSize: 14),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PlayMenuButton(
                    compact: true,
                    onPlayHere: onPlayHere,
                    onAutomaticSearch: onAutomaticSearch,
                    onSearchFromList: onSearchFromList,
                    onTeams: onTeams,
                  ),
                  const SizedBox(width: 4),
                  _NeoTopButton(
                    label:
                        MakeChessLocalization.text(MakeChessTextKey.contacts),
                    icon: Icons.people_alt,
                    onTap: onOpenLobby,
                    compact: true,
                  ),
                  const SizedBox(width: 4),
                  _NeoTopButton(
                    label: MakeChessLocalization.text(MakeChessTextKey.video),
                    icon: Icons.videocam,
                    onTap: onVideoCall,
                    compact: true,
                  ),
                  const SizedBox(width: 4),
                  _NeoTopButton(
                    label: MakeChessLocalization.text(MakeChessTextKey.hangUp),
                    icon: Icons.call_end,
                    onTap: onHangup,
                    danger: true,
                    compact: true,
                  ),
                  const SizedBox(width: 4),
                  _NeoTopButton(
                    label: MakeChessLocalization.text(MakeChessTextKey.login),
                    icon: Icons.person,
                    onTap: onLoginTap,
                    compact: true,
                  ),
                  const SizedBox(width: 4),
                  _MobileHamburgerButton(
                    hasIncomingCall: hasIncomingCall,
                    incomingFrom: incomingFrom,
                    onAcceptCall: onAcceptCall,
                    onDeclineCall: onDeclineCall,
                    onVoiceCall: onVoiceCall,
                    onLearn: onLearn,
                    onTeacherAvatar: onTeacherAvatar,
                    onLearnAsTeacher: onLearnAsTeacher,
                    onLearnAsStudent: onLearnAsStudent,
                    onSchool: onSchool,
                    onPuzzles: onPuzzles,
                    onOpenLobby: onOpenLobby,
                    onOpenGameSettings: onOpenGameSettings,
                    onOpenMoves: onOpenMoves,
                    onOpenChat: onOpenChat,
                    onTeams: onTeams,
                    onTournaments: onTournaments,
                    onWatch: onWatch,
                    onCommunity: onCommunity,
                    onBackgroundTheme: onBackgroundTheme,
                    onBoardTheme: onBoardTheme,
                    onGptSettings: onGptSettings,
                    onMessages: onMessages,
                    unreadMessages: unreadMessages,
                    onPersonalCabinet: onPersonalCabinet,
                    currentLanguage: currentLanguage,
                    onLanguageChanged: onLanguageChanged,
                    showScale: showScale,
                    scalePercent: scalePercent,
                    onScaleMinus: onScaleMinus,
                    onScalePlus: onScalePlus,
                    onScaleReset: onScaleReset,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktop(BuildContext context, double width) {
    final compact = width < 1500;
    final veryCompact = width < 1180;
    final menuGap = compact ? 3.0 : 6.0;
    final actionGap = compact ? 3.0 : 6.0;

    Widget gap(double value) => SizedBox(width: value);

    final navigation = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlayMenuButton(
            compact: compact,
            onPlayHere: onPlayHere,
            onAutomaticSearch: onAutomaticSearch,
            onSearchFromList: onSearchFromList,
            onTeams: onTeams,
          ),
          gap(menuGap),
          _LearnMenuButton(
            compact: compact,
            onTeacherAvatar: onTeacherAvatar,
            onLearnAsTeacher: onLearnAsTeacher,
            onLearnAsStudent: onLearnAsStudent,
            onSchool: onSchool ?? onLearn,
          ),
          gap(menuGap),
          _TopMenuText(
              label: MakeChessLocalization.text(MakeChessTextKey.puzzles),
              onTap: onPuzzles,
              compact: compact),
          gap(menuGap),
          _TopMenuText(
            label: MakeChessLocalization.text(MakeChessTextKey.tournaments),
            onTap: onTournaments,
            compact: compact,
          ),
          gap(menuGap),
          _TopMenuText(
            label: MakeChessLocalization.text(MakeChessTextKey.community),
            onTap: onCommunity,
            compact: compact,
          ),
          gap(menuGap),
          _SettingsMenu(
            onBackgroundTheme: onBackgroundTheme,
            onBoardTheme: onBoardTheme,
            onGptSettings: onGptSettings,
            onSiteSettings: onSiteSettings,
            compact: compact,
          ),
          gap(menuGap),
          _TopMenuText(
            label: MakeChessLocalization.text(MakeChessTextKey.messages),
            onTap: onMessages,
            compact: compact,
            badgeCount: unreadMessages,
          ),
          gap(menuGap),
          _TopMenuText(
            label: compact
                ? MakeChessLocalization.text(MakeChessTextKey.cabinet)
                : MakeChessLocalization.text(MakeChessTextKey.personalCabinet),
            onTap: onPersonalCabinet,
            compact: compact,
          ),
        ],
      ),
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IncomingCallNeoButton(
          enabled: hasIncomingCall && onAcceptCall != null,
          from: incomingFrom,
          blink: blink,
          onAccept: onAcceptCall,
          onDecline: onDeclineCall,
        ),
        gap(actionGap),
        _NeoTopButton(
          label: MakeChessLocalization.text(MakeChessTextKey.audio),
          icon: Icons.call,
          onTap: onVoiceCall,
          compact: compact,
          iconOnly: veryCompact,
        ),
        gap(actionGap),
        _NeoTopButton(
          label: MakeChessLocalization.text(MakeChessTextKey.video),
          icon: Icons.videocam,
          onTap: onVideoCall,
          compact: compact,
          iconOnly: veryCompact,
        ),
        gap(actionGap),
        _NeoTopButton(
          label: MakeChessLocalization.text(MakeChessTextKey.hangUp),
          icon: Icons.call_end,
          onTap: onHangup,
          danger: true,
          compact: compact,
          iconOnly: veryCompact,
        ),
        gap(actionGap),
        _LanguageSwitcher(
          value: currentLanguage,
          onChanged: onLanguageChanged,
          compact: compact,
        ),
        if (showScale && !veryCompact) ...[
          gap(actionGap),
          SizedBox(
            width: compact ? 112 : 132,
            child: Align(
              alignment: Alignment.center,
              child: _ScaleControl(
                percent: (scalePercent ?? 100).toInt(),
                onMinus: onScaleMinus,
                onPlus: onScalePlus,
                onReset: onScaleReset,
                compact: compact,
              ),
            ),
          ),
        ],
        gap(actionGap),
        _NeoTopButton(
          label: MakeChessLocalization.text(MakeChessTextKey.login),
          icon: Icons.person,
          onTap: onLoginTap,
          compact: true,
          iconOnly: veryCompact,
        ),
      ],
    );

    return Container(
      height: preferredSize.height,
      decoration: AppDecorations.topBar(),
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
      child: Row(
        children: [
          InkWell(
            onTap: onTitleTap,
            borderRadius: AppRadius.r8,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                'Makechess',
                style: compact
                    ? AppTextStyles.topBarTitle.copyWith(fontSize: 17)
                    : AppTextStyles.topBarTitle,
              ),
            ),
          ),
          SizedBox(width: compact ? 6 : 10),
          Expanded(child: navigation),
          SizedBox(width: compact ? 6 : 10),
          actions,
        ],
      ),
    );
  }
}

class _PlayMenuButton extends StatelessWidget {
  const _PlayMenuButton({
    required this.onPlayHere,
    required this.onAutomaticSearch,
    required this.onSearchFromList,
    required this.onTeams,
    this.compact = false,
  });

  final VoidCallback? onPlayHere;
  final VoidCallback? onAutomaticSearch;
  final VoidCallback? onSearchFromList;
  final VoidCallback? onTeams;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPlayHere != null ||
        onAutomaticSearch != null ||
        onSearchFromList != null ||
        onTeams != null;

    return PopupMenuButton<String>(
      enabled: enabled,
      tooltip: MakeChessLocalization.text(MakeChessTextKey.play),
      color: const Color(0xFF121A26),
      surfaceTintColor: Colors.transparent,
      onSelected: (value) {
        switch (value) {
          case 'here':
            onPlayHere?.call();
            break;
          case 'auto':
            onAutomaticSearch?.call();
            break;
          case 'list':
            onSearchFromList?.call();
            break;
          case 'teams':
            onTeams?.call();
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'here',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.play_arrow, color: AppColors.text),
            title: Text(MakeChessLocalization.text(MakeChessTextKey.playHere),
                style: AppTextStyles.body),
          ),
        ),
        PopupMenuItem<String>(
          value: 'auto',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.radar, color: AppColors.text),
            title: Text(
                MakeChessLocalization.text(MakeChessTextKey.automaticSearch),
                style: AppTextStyles.body),
          ),
        ),
        PopupMenuItem<String>(
          value: 'list',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.people_alt, color: AppColors.text),
            title: Text(
                MakeChessLocalization.text(MakeChessTextKey.searchFromList),
                style: AppTextStyles.body),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'teams',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.grid_3x3, color: AppColors.text),
            title: Text('2×2', style: AppTextStyles.body),
          ),
        ),
      ],
      child: Container(
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 11),
        decoration: AppDecorations.neoButton(enabled: enabled),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(MakeChessLocalization.text(MakeChessTextKey.play),
                style: AppTextStyles.topBarButton),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18, color: AppColors.text),
          ],
        ),
      ),
    );
  }
}

class _LearnMenuButton extends StatelessWidget {
  const _LearnMenuButton({
    required this.onTeacherAvatar,
    required this.onLearnAsTeacher,
    required this.onLearnAsStudent,
    required this.onSchool,
    this.compact = false,
  });

  final VoidCallback? onTeacherAvatar;
  final VoidCallback? onLearnAsTeacher;
  final VoidCallback? onLearnAsStudent;
  final VoidCallback? onSchool;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onTeacherAvatar != null ||
        onLearnAsTeacher != null ||
        onLearnAsStudent != null ||
        onSchool != null;

    return PopupMenuButton<String>(
      enabled: enabled,
      tooltip: MakeChessLocalization.phrase('Учиться'),
      color: const Color(0xFF121A26),
      surfaceTintColor: Colors.transparent,
      onSelected: (value) {
        switch (value) {
          case 'avatar':
            onTeacherAvatar?.call();
            break;
          case 'teacher':
            onLearnAsTeacher?.call();
            break;
          case 'student':
            onLearnAsStudent?.call();
            break;
          case 'school':
            onSchool?.call();
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'avatar',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.smart_toy, color: AppColors.text),
            title: Text(
                MakeChessLocalization.text(MakeChessTextKey.teacherAvatar),
                style: AppTextStyles.body),
          ),
        ),
        PopupMenuItem<String>(
          value: 'teacher',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.school_outlined, color: AppColors.text),
            title: Text(
                MakeChessLocalization.text(MakeChessTextKey.loginAsTeacher),
                style: AppTextStyles.body),
          ),
        ),
        PopupMenuItem<String>(
          value: 'student',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.person_outline, color: AppColors.text),
            title: Text(
                MakeChessLocalization.text(MakeChessTextKey.loginAsStudent),
                style: AppTextStyles.body),
          ),
        ),
        PopupMenuItem<String>(
          value: 'school',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.account_balance, color: AppColors.text),
            title: Text(MakeChessLocalization.text(MakeChessTextKey.school),
                style: AppTextStyles.body),
          ),
        ),
      ],
      child: Container(
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 11),
        decoration: AppDecorations.neoButton(enabled: enabled),
        child: ValueListenableBuilder<String>(
          valueListenable: makechessLearningTopBarLabel,
          builder: (context, value, child) {
            final label = _makechessCoreLearningLabel(value);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppTextStyles.topBarButton),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: AppColors.text,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MobileHamburgerButton extends StatelessWidget {
  const _MobileHamburgerButton({
    required this.hasIncomingCall,
    required this.incomingFrom,
    required this.onAcceptCall,
    required this.onDeclineCall,
    required this.onVoiceCall,
    required this.onLearn,
    required this.onTeacherAvatar,
    required this.onLearnAsTeacher,
    required this.onLearnAsStudent,
    required this.onSchool,
    required this.onPuzzles,
    required this.onOpenLobby,
    required this.onOpenGameSettings,
    required this.onOpenMoves,
    required this.onOpenChat,
    required this.onTeams,
    required this.onTournaments,
    required this.onWatch,
    required this.onCommunity,
    required this.onBackgroundTheme,
    required this.onBoardTheme,
    required this.onGptSettings,
    required this.onMessages,
    required this.unreadMessages,
    required this.onPersonalCabinet,
    required this.currentLanguage,
    required this.onLanguageChanged,
    required this.showScale,
    required this.scalePercent,
    required this.onScaleMinus,
    required this.onScalePlus,
    required this.onScaleReset,
  });

  final bool hasIncomingCall;
  final String? incomingFrom;
  final VoidCallback? onAcceptCall;
  final VoidCallback? onDeclineCall;
  final VoidCallback? onVoiceCall;
  final VoidCallback? onLearn;
  final VoidCallback? onTeacherAvatar;
  final VoidCallback? onLearnAsTeacher;
  final VoidCallback? onLearnAsStudent;
  final VoidCallback? onSchool;
  final VoidCallback? onPuzzles;
  final VoidCallback? onOpenLobby;
  final VoidCallback? onOpenGameSettings;
  final VoidCallback? onOpenMoves;
  final VoidCallback? onOpenChat;
  final VoidCallback? onTeams;
  final VoidCallback? onTournaments;
  final VoidCallback? onWatch;
  final VoidCallback? onCommunity;
  final VoidCallback? onBackgroundTheme;
  final VoidCallback? onBoardTheme;
  final VoidCallback? onGptSettings;
  final VoidCallback? onMessages;
  final int unreadMessages;
  final VoidCallback? onPersonalCabinet;
  final String currentLanguage;
  final ValueChanged<String>? onLanguageChanged;
  final bool showScale;
  final double? scalePercent;
  final VoidCallback? onScaleMinus;
  final VoidCallback? onScalePlus;
  final VoidCallback? onScaleReset;

  Future<void> _openMenu(BuildContext context) async {
    void run(BuildContext sheetContext, VoidCallback? callback) {
      Navigator.of(sheetContext).pop();
      callback?.call();
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        Widget item(IconData icon, String title, VoidCallback? callback,
            {int badgeCount = 0}) {
          return ListTile(
            leading: Icon(icon, color: AppColors.text),
            title: Text(title, style: AppTextStyles.body),
            trailing: badgeCount > 0 ? _UnreadBadge(count: badgeCount) : null,
            enabled: callback != null,
            onTap: callback == null ? null : () => run(sheetContext, callback),
          );
        }

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.45,
          maxChildSize: 0.96,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          MakeChessLocalization.text(MakeChessTextKey.menu),
                          style: AppTextStyles.sectionTitle),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close, color: AppColors.text),
                    ),
                  ],
                ),
                if (hasIncomingCall) ...[
                  Container(
                    decoration: AppDecorations.card(highlighted: true),
                    child: Column(
                      children: [
                        ListTile(
                          leading:
                              const Icon(Icons.call, color: AppColors.accent),
                          title: Text(
                            incomingFrom == null || incomingFrom!.trim().isEmpty
                                ? MakeChessLocalization.text(
                                    MakeChessTextKey.incomingCall)
                                : 'Звонит $incomingFrom',
                            style: AppTextStyles.body,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: onDeclineCall == null
                                    ? null
                                    : () => run(sheetContext, onDeclineCall),
                                icon: const Icon(Icons.call_end),
                                label: Text(MakeChessLocalization.text(
                                    MakeChessTextKey.decline)),
                              ),
                            ),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: onAcceptCall == null
                                    ? null
                                    : () => run(sheetContext, onAcceptCall),
                                icon: const Icon(Icons.call),
                                label: Text(MakeChessLocalization.text(
                                    MakeChessTextKey.accept)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                item(
                    Icons.call,
                    MakeChessLocalization.text(MakeChessTextKey.audio),
                    onVoiceCall),
                const Divider(color: AppColors.borderSoft),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
                  child: ValueListenableBuilder<String>(
                    valueListenable: makechessLearningTopBarLabel,
                    builder: (context, value, child) {
                      final label = _makechessCoreLearningLabel(value);
                      return Text(label, style: AppTextStyles.caption);
                    },
                  ),
                ),
                item(
                    Icons.smart_toy,
                    MakeChessLocalization.text(MakeChessTextKey.teacherAvatar),
                    onTeacherAvatar),
                item(
                    Icons.school_outlined,
                    MakeChessLocalization.text(MakeChessTextKey.loginAsTeacher),
                    onLearnAsTeacher),
                item(
                    Icons.person_outline,
                    MakeChessLocalization.text(MakeChessTextKey.loginAsStudent),
                    onLearnAsStudent),
                item(
                    Icons.account_balance,
                    MakeChessLocalization.text(MakeChessTextKey.school),
                    onSchool ?? onLearn),
                item(
                    Icons.task_alt,
                    MakeChessLocalization.text(MakeChessTextKey.puzzles),
                    onPuzzles),
                item(
                    Icons.people_alt,
                    MakeChessLocalization.text(MakeChessTextKey.contacts),
                    onOpenLobby),
                item(
                    Icons.tune,
                    MakeChessLocalization.text(MakeChessTextKey.gameModes),
                    onOpenGameSettings),
                item(
                    Icons.list_alt,
                    MakeChessLocalization.text(
                        MakeChessTextKey.movesAndControls),
                    onOpenMoves),
                item(
                    Icons.chat_bubble_outline,
                    MakeChessLocalization.text(MakeChessTextKey.chat),
                    onOpenChat),
                const Divider(color: AppColors.borderSoft),
                item(Icons.grid_3x3, '2×2', onTeams),
                item(
                    Icons.emoji_events,
                    MakeChessLocalization.text(MakeChessTextKey.tournaments),
                    onTournaments),
                item(
                    Icons.visibility,
                    MakeChessLocalization.text(MakeChessTextKey.watch),
                    onWatch),
                item(
                    Icons.forum,
                    MakeChessLocalization.text(MakeChessTextKey.community),
                    onCommunity),
                const Divider(color: AppColors.borderSoft),
                item(
                    Icons.wallpaper,
                    MakeChessLocalization.text(
                        MakeChessTextKey.backgroundTheme),
                    onBackgroundTheme),
                item(
                    Icons.dashboard_customize,
                    MakeChessLocalization.text(MakeChessTextKey.boardTheme),
                    onBoardTheme),
                item(
                    Icons.smart_toy,
                    MakeChessLocalization.text(MakeChessTextKey.gptSettings),
                    onGptSettings),
                item(
                    Icons.mail_outline,
                    MakeChessLocalization.text(MakeChessTextKey.messages),
                    onMessages,
                    badgeCount: unreadMessages),
                item(
                    Icons.account_circle_outlined,
                    MakeChessLocalization.text(
                        MakeChessTextKey.personalCabinet),
                    onPersonalCabinet),
                const Divider(color: AppColors.borderSoft),
                ListTile(
                  leading: const Icon(Icons.language, color: AppColors.text),
                  title: Text(
                      MakeChessLocalization.text(MakeChessTextKey.language),
                      style: AppTextStyles.body),
                  trailing: DropdownButton<String>(
                    value: currentLanguage.toUpperCase(),
                    dropdownColor: AppColors.surface,
                    style: AppTextStyles.body,
                    items: kSupportedLanguageCodes.map((lang) {
                      return DropdownMenuItem<String>(
                        value: lang,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              kLanguageFlags[lang] ?? '🏳️',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(kLanguageLabels[lang] ?? lang),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: onLanguageChanged == null
                        ? null
                        : (value) {
                            if (value != null) {
                              MakeChessLocalizationController.setLanguage(
                                  value);
                              onLanguageChanged?.call(value);
                            }
                          },
                  ),
                ),
                if (showScale)
                  ListTile(
                    leading: const Icon(Icons.zoom_in, color: AppColors.text),
                    title: Text(
                        MakeChessLocalization.text(MakeChessTextKey.scale),
                        style: AppTextStyles.body),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: onScaleMinus,
                          icon: const Icon(Icons.remove, color: AppColors.text),
                        ),
                        GestureDetector(
                          onDoubleTap: onScaleReset,
                          child: Text(
                            '${(scalePercent ?? 100).toInt()}%',
                            style: AppTextStyles.body,
                          ),
                        ),
                        IconButton(
                          onPressed: onScalePlus,
                          icon: const Icon(Icons.add, color: AppColors.text),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: () => _openMenu(context),
          borderRadius: AppRadius.r10,
          child: Container(
            width: 44,
            height: 38,
            alignment: Alignment.center,
            decoration: AppDecorations.neoButton(active: hasIncomingCall),
            child: const Icon(Icons.menu, color: AppColors.text, size: 26),
          ),
        ),
        if (hasIncomingCall)
          const Positioned(
            right: -1,
            top: -1,
            child: Icon(Icons.circle, color: AppColors.danger, size: 10),
          ),
        if (unreadMessages > 0)
          Positioned(
            right: -7,
            top: -7,
            child: _UnreadBadge(count: unreadMessages),
          ),
      ],
    );
  }
}

class _TopMenuText extends StatefulWidget {
  const _TopMenuText({
    required this.label,
    required this.onTap,
    this.compact = false,
    this.badgeCount = 0,
  });

  final String label;
  final VoidCallback? onTap;
  final bool compact;
  final int badgeCount;

  @override
  State<_TopMenuText> createState() => _TopMenuTextState();
}

class _TopMenuTextState extends State<_TopMenuText> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final active = _hover && enabled;
    final pressed = _pressed && enabled;

    final fgColor = !enabled
        ? AppColors.text.withOpacity(0.35)
        : (active ? AppColors.accent : AppColors.text);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 8 : 11),
          decoration: AppDecorations.neoButton(
            active: active,
            pressed: pressed,
            enabled: enabled,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Text(
                widget.label,
                style: AppTextStyles.topBarButton.copyWith(
                  fontSize: widget.compact ? 12.5 : 13.5,
                  color: fgColor,
                  shadows: active
                      ? const [
                          Shadow(
                            color: AppColors.accentGlow,
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
              if (widget.badgeCount > 0)
                Positioned(
                  right: -10,
                  top: -9,
                  child: _UnreadBadge(count: widget.badgeCount),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SettingsMenu extends StatefulWidget {
  const _SettingsMenu({
    required this.onBackgroundTheme,
    required this.onBoardTheme,
    required this.onGptSettings,
    required this.onSiteSettings,
    this.compact = false,
  });

  final VoidCallback? onBackgroundTheme;
  final VoidCallback? onBoardTheme;
  final VoidCallback? onGptSettings;
  final VoidCallback? onSiteSettings;
  final bool compact;

  @override
  State<_SettingsMenu> createState() => _SettingsMenuState();
}

class _SettingsMenuState extends State<_SettingsMenu> {
  bool _hover = false;
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onBackgroundTheme != null ||
        widget.onBoardTheme != null ||
        widget.onGptSettings != null ||
        widget.onSiteSettings != null;

    final active = (_hover || _menuOpen) && enabled;

    final fgColor = !enabled
        ? AppColors.text.withOpacity(0.35)
        : (active ? AppColors.accent : AppColors.text);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: PopupMenuButton<String>(
        enabled: enabled,
        tooltip: MakeChessLocalization.text(MakeChessTextKey.settings),
        color: const Color(0xFF121A26),
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.accentGlow.withOpacity(0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppColors.accent.withOpacity(0.35),
            width: 1,
          ),
        ),
        onOpened: () {
          if (mounted) setState(() => _menuOpen = true);
        },
        onCanceled: () {
          if (mounted) setState(() => _menuOpen = false);
        },
        onSelected: (value) {
          if (mounted) setState(() => _menuOpen = false);

          switch (value) {
            case 'bg':
              widget.onBackgroundTheme?.call();
              break;
            case 'board':
              widget.onBoardTheme?.call();
              break;
            case 'gpt':
              widget.onGptSettings?.call();
              break;
            case 'site':
              widget.onSiteSettings?.call();
              break;
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem<String>(
            value: 'bg',
            child: Text(
              MakeChessLocalization.text(MakeChessTextKey.backgroundTheme),
              style: AppTextStyles.topBarButton.copyWith(
                color: AppColors.text,
              ),
            ),
          ),
          PopupMenuItem<String>(
            value: 'board',
            child: Text(
              MakeChessLocalization.text(MakeChessTextKey.boardTheme),
              style: AppTextStyles.topBarButton.copyWith(
                color: AppColors.text,
              ),
            ),
          ),
          PopupMenuItem<String>(
            value: 'gpt',
            child: Text(
              MakeChessLocalization.text(MakeChessTextKey.gptSettings),
              style: AppTextStyles.topBarButton.copyWith(
                color: AppColors.text,
              ),
            ),
          ),
          PopupMenuItem<String>(
            value: 'site',
            child: Text(
              MakeChessLocalization.text(MakeChessTextKey.siteSettings),
              style: AppTextStyles.topBarButton.copyWith(
                color: AppColors.text,
              ),
            ),
          ),
        ],
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 8 : 11),
          decoration: AppDecorations.neoButton(
            active: active,
            pressed: _menuOpen,
            enabled: enabled,
          ),
          child: Center(
            child: Text(
              MakeChessLocalization.text(MakeChessTextKey.settings),
              style: AppTextStyles.topBarButton.copyWith(
                fontSize: widget.compact ? 12.5 : 13.5,
                color: fgColor,
                shadows: active
                    ? const [
                        Shadow(
                          color: AppColors.accentGlow,
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NeoTopButton extends StatefulWidget {
  const _NeoTopButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
    this.compact = false,
    this.iconOnly = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;
  final bool compact;
  final bool iconOnly;

  @override
  State<_NeoTopButton> createState() => _NeoTopButtonState();
}

class _NeoTopButtonState extends State<_NeoTopButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final active = _hover && enabled;
    final pressed = _pressed && enabled;

    final fgColor = !enabled
        ? AppColors.text.withOpacity(0.35)
        : (active ? AppColors.accent : AppColors.text);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 32,
          padding: widget.iconOnly
              ? const EdgeInsets.symmetric(horizontal: 7)
              : EdgeInsets.symmetric(horizontal: widget.compact ? 8 : 11),
          decoration: AppDecorations.neoButton(
            active: active,
            pressed: pressed,
            danger: widget.danger,
            enabled: enabled,
          ),
          child: DefaultTextStyle(
            style: AppTextStyles.topBarButton.copyWith(
              color: fgColor,
              shadows: active
                  ? const [
                      Shadow(
                        color: AppColors.accentGlow,
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 18, color: fgColor),
                if (!widget.iconOnly) ...[
                  SizedBox(width: widget.compact ? 6 : 8),
                  Text(
                    widget.label,
                    style: TextStyle(fontSize: widget.compact ? 13 : 14),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageSwitcher extends StatefulWidget {
  const _LanguageSwitcher({
    required this.value,
    this.onChanged,
    this.compact = false,
  });

  final String value;
  final ValueChanged<String>? onChanged;
  final bool compact;

  @override
  State<_LanguageSwitcher> createState() => _LanguageSwitcherState();
}

class _LanguageSwitcherState extends State<_LanguageSwitcher> {
  bool _hover = false;
  bool _menuOpen = false;

  String _flag(String lang) {
    return kLanguageFlags[lang.toUpperCase()] ?? '🏳️';
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.value.toUpperCase();
    final enabled = widget.onChanged != null;
    final active = (_hover || _menuOpen) && enabled;

    final fgColor = !enabled
        ? AppColors.text.withOpacity(0.35)
        : (active ? AppColors.accent : AppColors.text);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: PopupMenuButton<String>(
        enabled: enabled,
        tooltip: MakeChessLocalization.text(MakeChessTextKey.chooseLanguage),
        color: const Color(0xFF121A26),
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.accentGlow.withOpacity(0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppColors.accent.withOpacity(0.35),
            width: 1,
          ),
        ),
        onOpened: () {
          if (mounted) setState(() => _menuOpen = true);
        },
        onCanceled: () {
          if (mounted) setState(() => _menuOpen = false);
        },
        onSelected: (lang) {
          if (mounted) setState(() => _menuOpen = false);
          MakeChessLocalizationController.setLanguage(lang);
          widget.onChanged?.call(lang);
        },
        itemBuilder: (context) => kSupportedLanguageCodes.map((lang) {
          return PopupMenuItem<String>(
            value: lang,
            child: Row(
              children: [
                Text(
                  kLanguageFlags[lang] ?? '🏳️',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  kLanguageLabels[lang] ?? lang,
                  style: AppTextStyles.topBarButton.copyWith(
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 7 : 9),
          decoration: AppDecorations.neoButton(
            active: active,
            pressed: _menuOpen,
            enabled: enabled,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _flag(current),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Text(
                current,
                style: AppTextStyles.topBarButton.copyWith(
                  color: fgColor,
                  shadows: active
                      ? const [
                          Shadow(
                            color: AppColors.accentGlow,
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: fgColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScaleControl extends StatelessWidget {
  const _ScaleControl({
    required this.percent,
    this.onMinus,
    this.onPlus,
    this.onReset,
    this.compact = false,
  });

  final int percent;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final VoidCallback? onReset;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          constraints: BoxConstraints(
            minWidth: compact ? 28 : 32,
            minHeight: 32,
          ),
          padding: EdgeInsets.zero,
          splashRadius: 18,
          tooltip: MakeChessLocalization.text(MakeChessTextKey.decrease),
          icon: const Icon(Icons.remove, size: 18, color: AppColors.text),
          onPressed: onMinus,
        ),
        GestureDetector(
          onDoubleTap: onReset,
          child: Container(
            height: 32,
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
            alignment: Alignment.center,
            decoration: AppDecorations.scaleBox(),
            child: Text(
              '$percent%',
              style: AppTextStyles.scaleText,
            ),
          ),
        ),
        IconButton(
          constraints: BoxConstraints(
            minWidth: compact ? 28 : 32,
            minHeight: 32,
          ),
          padding: EdgeInsets.zero,
          splashRadius: 18,
          tooltip: MakeChessLocalization.text(MakeChessTextKey.increase),
          icon: const Icon(Icons.add, size: 18, color: AppColors.text),
          onPressed: onPlus,
        ),
      ],
    );
  }
}

class _IncomingCallNeoButton extends StatelessWidget {
  const _IncomingCallNeoButton({
    required this.enabled,
    required this.from,
    required this.blink,
    required this.onAccept,
    required this.onDecline,
  });

  final bool enabled;
  final String? from;
  final bool blink;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final text = (from == null || from!.isEmpty)
        ? MakeChessLocalization.text(MakeChessTextKey.acceptCall)
        : MakeChessLocalization.text(MakeChessTextKey.acceptCall);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: enabled ? onAccept : null,
        child: Container(
          height: 34,
          padding: AppSpacing.topBarButtonPadding,
          decoration: AppDecorations.neoButton(
            active: enabled,
            pressed: false,
            danger: false,
            enabled: enabled,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (enabled && blink) ...[
                const _BlinkDot(),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.call, size: 16, color: AppColors.text),
              const SizedBox(width: 8),
              Text(
                text,
                style: AppTextStyles.topBarButton,
              ),
              if (enabled) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDecline,
                  child:
                      const Icon(Icons.close, size: 16, color: AppColors.text),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BlinkDot extends StatefulWidget {
  const _BlinkDot();

  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot> {
  bool _on = true;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) {
        setState(() => _on = !_on);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: _on ? 1 : .2,
      child: const Icon(Icons.circle, size: 10, color: AppColors.accent),
    );
  }
}
