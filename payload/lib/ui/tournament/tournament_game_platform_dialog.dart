// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:chess/chess.dart' as ch;

import '../app_style.dart';
import '../board_theme_controller.dart';
import '../common_top_bar.dart';
import '../../services/tournament_presence_service.dart';
import '../../services/tournament_storage_service.dart';
import 'tournament_table_editor.dart';

import '../../localization/makechess_localization.dart';
enum TournamentPlatformLayout {
  oneVideoEightBoards,
  videosAboveEightBoards,
  eightBoardsNoVideo,
  oneBoardOneVideo,
  eightVideosOnly,
  oneBoardNoVideo,
  oneBoardTwoVideos,
  twoBoardsFourVideos,
  twoBoardsNoVideo,
}

Future<void> showTournamentGamePlatform({
  required BuildContext context,
  String tournamentName = 'Турнир',
  bool gameActive = false,
  bool playAsBlack = false,
  String opponentName = 'Соперник',
  String tournamentId = '',
  String ownerId = '',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TournamentGamePlatformDialog(
      tournamentName: tournamentName,
      gameActive: gameActive,
      playAsBlack: playAsBlack,
      opponentName: opponentName,
      tournamentId: tournamentId,
      ownerId: ownerId,
    ),
  );
}

class _TournamentGamePlatformDialog extends StatefulWidget {
  const _TournamentGamePlatformDialog({
    required this.tournamentName,
    required this.gameActive,
    required this.playAsBlack,
    required this.opponentName,
    required this.tournamentId,
    required this.ownerId,
  });

  final String tournamentName;
  final bool gameActive;
  final bool playAsBlack;
  final String opponentName;
  final String tournamentId;
  final String ownerId;

  @override
  State<_TournamentGamePlatformDialog> createState() =>
      _TournamentGamePlatformDialogState();
}

class _TournamentGamePlatformDialogState
    extends State<_TournamentGamePlatformDialog> {
  TournamentPlatformLayout _layout = TournamentPlatformLayout.oneBoardOneVideo;
  bool _gameFinished = false;
  bool _sharedAnalysis = false;
  RealtimeChannel? _presenceChannel;
  Set<String> _onlineParticipantIds = <String>{};
  List<Map<String, dynamic>> _tournamentParticipants = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _presenceChannel = TournamentPresenceService.join(
      widget.tournamentId,
      onChanged: (userIds) {
        if (mounted) setState(() => _onlineParticipantIds = userIds);
      },
    );
    _loadTournamentParticipants();
  }

  Future<void> _loadTournamentParticipants() async {
    if (widget.tournamentId.isEmpty || widget.ownerId.isEmpty) return;
    final storage = TournamentStorageService.instance;
    Map<String, dynamic>? table;
    try {
      table = await storage.loadInvitedTournamentTable(
        ownerId: widget.ownerId,
        tournamentId: widget.tournamentId,
      );
    } catch (_) {
      // Список ниже всё равно будет восстановлен из общей записи турнира.
    }
    final participants = <Map<String, dynamic>>[];
    final raw = table?['participants'];
    if (raw is List) {
      participants.addAll(
        raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => '${item['id'] ?? ''}'.trim().isNotEmpty),
      );
    }

    // У приглашённого игрока политика таблицы может ещё не вернуть данные.
    // Общий список текущих турниров является вторым источником участников.
    {
      final tournaments = await storage.loadVisibleTournaments();
      Map<String, dynamic>? tournament;
      for (final item in tournaments) {
        if ('${item['id'] ?? ''}' == widget.tournamentId &&
            '${item['_ownerId'] ?? ''}' == widget.ownerId) {
          tournament = item;
          break;
        }
      }
      final ids = tournament?['participantIds'];
      final names = tournament?['participantNames'];
      if (ids is List) {
        for (final value in ids) {
          final id = '$value'.trim();
          if (id.isEmpty) continue;
          if (!participants.any((participant) => '${participant['id']}' == id)) {
            participants.add(<String, dynamic>{
              'id': id,
              'name': names is Map ? '${names[id] ?? id}' : id,
            });
          }
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _tournamentParticipants = participants;
    });
  }

  @override
  void dispose() {
    TournamentPresenceService.leave(_presenceChannel);
    super.dispose();
  }

  Future<void> _finishGame(String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: MakeChessLocalizedText('$action?'),
        content: MakeChessLocalizedText(
          action == 'Сдаться'
              ? 'Партия будет завершена поражением.'
              : 'Предложение ничьей завершит партию после подтверждения соперником.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const MakeChessLocalizedText('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const MakeChessLocalizedText('Подтвердить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (widget.tournamentId.isNotEmpty && widget.ownerId.isNotEmpty) {
      try {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser?.id;
        final row = await client
            .from('makechess_tournament_games_v1')
            .select('board,white_id,black_id')
            .eq('owner_id', widget.ownerId)
            .eq('tournament_id', widget.tournamentId)
            .or('white_id.eq.$userId,black_id.eq.$userId')
            .limit(1)
            .maybeSingle();
        if (row != null) {
          final board = (row['board'] as num?)?.toInt() ?? 1;
          if (action == 'Сдаться') {
            await client.rpc(
              'finish_makechess_tournament_game_v1',
              params: <String, dynamic>{
                'p_owner_id': widget.ownerId,
                'p_tournament_id': widget.tournamentId,
                'p_board': board,
                'p_result': widget.playAsBlack ? '1-0' : '0-1',
                'p_reason': 'resignation',
              },
            );
          } else {
            final result = await client.rpc(
              'offer_makechess_tournament_draw_v1',
              params: <String, dynamic>{
                'p_owner_id': widget.ownerId,
                'p_tournament_id': widget.tournamentId,
                'p_board': board,
              },
            );
            if ('$result'.contains('offered')) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: MakeChessLocalizedText('Предложение ничьей отправлено')),
                );
              }
              return;
            }
          }
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: MakeChessLocalizedText('Не удалось завершить партию: $error')),
          );
        }
        return;
      }
    }
    if (mounted) {
      setState(() {
        _gameFinished = true;
        _sharedAnalysis = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF08131E),
      child: SafeArea(
        child: Column(
          children: [
            CommonTopBar(
              onTitleTap: _returnToSite,
              onPlayHere: _returnToSite,
              onAutomaticSearch: _returnToSite,
              onSearchFromList: _returnToSite,
              onLearn: _returnToSite,
              onPuzzles: _returnToSite,
              onTeams: _returnToSite,
              onTournaments: _returnToSite,
              onWatch: _returnToSite,
              onCommunity: _returnToSite,
              onMessages: _returnToSite,
              onPersonalCabinet: _returnToSite,
              onLoginTap: _returnToSite,
              showScale: false,
            ),
            _header(),
            _layoutToolbar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _workspace()),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: size.width < 1100 ? 260 : 310,
                      child: _rightSidebar(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _returnToSite() => Navigator.pop(context);

  Future<void> _openLiveTournamentTable() async {
    if (widget.tournamentId.isEmpty || widget.ownerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: MakeChessLocalizedText('Сначала выберите турнир')),
      );
      return;
    }
    final storage = TournamentStorageService.instance;
    Map<String, dynamic>? table;
    try {
      table = await storage.loadInvitedTournamentTable(
        ownerId: widget.ownerId,
        tournamentId: widget.tournamentId,
      );
    } catch (_) {}
    if (!mounted || table == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: MakeChessLocalizedText('Не удалось загрузить турнирную таблицу')),
        );
      }
      return;
    }
    final rawParticipants = table['participants'];
    final participants = rawParticipants is List
        ? rawParticipants
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : <Map<String, dynamic>>[];
    final rawResults = table['results'];
    final results = <String, String>{};
    if (rawResults is Map) {
      results.addAll(
        rawResults.map((key, value) => MapEntry('$key', '$value')),
      );
    }
    await showTournamentTableEditor(
      context: context,
      tournamentId: widget.tournamentId,
      initialName: '${table['name'] ?? widget.tournamentName}',
      initialType: '${table['type'] ?? 'Круговая система'}',
      initialStatus: '${table['status'] ?? 'Текущий турнир'}',
      initialMinutes: int.tryParse('${table['minutes'] ?? ''}') ?? 10,
      initialIncrement: int.tryParse('${table['increment'] ?? ''}') ?? 5,
      initialRounds: int.tryParse('${table['rounds'] ?? ''}') ?? 1,
      initialParticipantNames: participants
          .map((participant) => '${participant['name'] ?? 'Участник'}')
          .toList(growable: false),
      initialParticipantsData: participants,
      initialResults: results,
      maxParticipants: (table['maxParticipants'] as num?)?.toInt(),
      initialJudge: '${table['judge'] ?? ''}',
      initialVenue: '${table['venue'] ?? ''}',
      initialOrganizer: '${table['organizer'] ?? ''}',
      initialStart: '${table['start'] ?? ''}',
      initialEnd: '${table['end'] ?? ''}',
      initialAge: '${table['age'] ?? ''}',
      previewMode: true,
    );
  }

  Widget _header() => Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          color: Color(0xFF152231),
          border: Border(bottom: BorderSide(color: Color(0xFF2B5068))),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.amberAccent),
            const SizedBox(width: 10),
            const MakeChessLocalizedText(
              'Игровая платформа',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: MakeChessLocalizedText(
                widget.tournamentName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60),
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _openLiveTournamentTable,
              icon: const Icon(Icons.table_chart_outlined),
              label: const MakeChessLocalizedText('Открыть турнирную таблицу'),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (_gameFinished ? Colors.green : Colors.orange)
                    .withOpacity(.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      _gameFinished ? Colors.greenAccent : Colors.orangeAccent,
                ),
              ),
              child: MakeChessLocalizedText(
                _gameFinished ? 'Анализ после партии' : 'Партия идёт',
                style: TextStyle(
                  color:
                      _gameFinished ? Colors.greenAccent : Colors.orangeAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: MakeChessLocalization.phrase('Закрыть платформу'),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );

  Widget _layoutToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: const BoxDecoration(
        color: Color(0xFF101C28),
        border: Border(bottom: BorderSide(color: Color(0xFF263C4E))),
      ),
      child: Row(
        children: [
          const MakeChessLocalizedText('Компоновка:', style: TextStyle(color: Colors.white60)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final layout in TournamentPlatformLayout.values) ...[
                    _layoutButton(layout),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: _gameFinished
                ? 'Совместно двигать фигуры и анализировать партию'
                : 'Доступно только после завершения партии',
            child: OutlinedButton.icon(
              onPressed: _gameFinished
                  ? () => setState(() => _sharedAnalysis = !_sharedAnalysis)
                  : null,
              icon: const Icon(Icons.group_work_outlined, size: 18),
              label: MakeChessLocalizedText(
                _sharedAnalysis ? 'Совместный режим: ВКЛ' : 'Совместный режим',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _layoutButton(TournamentPlatformLayout layout) {
    final selected = _layout == layout;
    return Tooltip(
      message: _layoutTitle(layout),
      child: InkWell(
        onTap: () => setState(() => _layout = layout),
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 58,
          height: 36,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected
                ? Colors.cyanAccent.withOpacity(.12)
                : Colors.white.withOpacity(.035),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected ? Colors.cyanAccent : Colors.white24,
              width: selected ? 2 : 1,
            ),
          ),
          child: _layoutDiagram(layout),
        ),
      ),
    );
  }

  Widget _layoutDiagram(TournamentPlatformLayout layout) {
    Widget block(bool video) => Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: video ? const Color(0xFF23516B) : const Color(0xFF8A9299),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Icon(
            video ? Icons.videocam : Icons.grid_on,
            size: 9,
            color: Colors.white,
          ),
        );

    return switch (layout) {
      TournamentPlatformLayout.oneVideoEightBoards => Row(children: [
          Expanded(child: block(true)),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              children: List.generate(8, (_) => block(false)),
            ),
          ),
        ]),
      TournamentPlatformLayout.videosAboveEightBoards => GridView.count(
          crossAxisCount: 4,
          children: List.generate(
            8,
            (_) => Column(children: [
              Expanded(child: block(true)),
              Expanded(child: block(false)),
            ]),
          ),
        ),
      TournamentPlatformLayout.eightBoardsNoVideo => GridView.count(
          crossAxisCount: 4,
          children: List.generate(8, (_) => block(false)),
        ),
      TournamentPlatformLayout.oneBoardOneVideo => Row(children: [
          Expanded(child: block(true)),
          Expanded(child: block(false))
        ]),
      TournamentPlatformLayout.oneBoardTwoVideos => Row(children: [
          Expanded(
            child: Column(children: [
              Expanded(child: block(true)),
              Expanded(child: block(true)),
            ]),
          ),
          Expanded(child: block(false)),
        ]),
      TournamentPlatformLayout.twoBoardsFourVideos => Row(children: [
          Expanded(
            child: Column(
                children:
                    List.generate(4, (_) => Expanded(child: block(true)))),
          ),
          Expanded(
            child: Column(children: [
              Expanded(child: block(false)),
              Expanded(child: block(false)),
            ]),
          ),
        ]),
      TournamentPlatformLayout.twoBoardsNoVideo => Row(children: [
          Expanded(child: block(false)),
          Expanded(child: block(false))
        ]),
      TournamentPlatformLayout.eightVideosOnly => GridView.count(
          crossAxisCount: 4,
          children: List.generate(8, (_) => block(true)),
        ),
      TournamentPlatformLayout.oneBoardNoVideo => block(false),
    };
  }

  Widget _workspace() {
    return switch (_layout) {
      TournamentPlatformLayout.oneVideoEightBoards => Row(children: [
          const Expanded(
            flex: 3,
            child: _TournamentVideo(label: 'Видео ведущего'),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 7, child: _boardGrid(8)),
        ]),
      TournamentPlatformLayout.videosAboveEightBoards => _videoBoardGrid(8),
      TournamentPlatformLayout.eightBoardsNoVideo => _boardGrid(8),
      TournamentPlatformLayout.oneBoardOneVideo => Row(children: [
          const Expanded(child: _TournamentVideo(label: 'Видео соперника')),
          const SizedBox(width: 8),
          Expanded(
            child: _TournamentBoard(
              label: widget.opponentName,
              active: widget.gameActive,
              playAsBlack: widget.playAsBlack,
              tournamentId: widget.tournamentId,
              ownerId: widget.ownerId,
            ),
          ),
        ]),
      TournamentPlatformLayout.oneBoardTwoVideos => Row(children: [
          Expanded(child: _rows(const [true, true])),
          const SizedBox(width: 8),
          const Expanded(child: _TournamentBoard(label: 'Доска 1')),
        ]),
      TournamentPlatformLayout.twoBoardsFourVideos => Row(children: [
          Expanded(child: _rows(const [true, true, true, true])),
          const SizedBox(width: 8),
          Expanded(child: _rows(const [false, false])),
        ]),
      TournamentPlatformLayout.twoBoardsNoVideo =>
        _columns(const [false, false]),
      TournamentPlatformLayout.eightVideosOnly => _videoGrid(8),
      TournamentPlatformLayout.oneBoardNoVideo => Center(
          child: _TournamentBoard(
            label: widget.opponentName,
            active: widget.gameActive,
            playAsBlack: widget.playAsBlack,
            tournamentId: widget.tournamentId,
            ownerId: widget.ownerId,
          ),
        ),
    };
  }

  Widget _boardGrid(int count) => GridView.count(
        crossAxisCount: count <= 4 ? 2 : 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.05,
        children: List.generate(
          count,
          (index) => _TournamentBoard(label: 'Доска ${index + 1}'),
        ),
      );

  Widget _videoGrid(int count) => GridView.count(
        crossAxisCount: count <= 4 ? 2 : 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.25,
        children: List.generate(
          count,
          (index) => _TournamentVideo(label: 'Видео ${index + 1}'),
        ),
      );

  Widget _videoBoardGrid(int count) => GridView.count(
        crossAxisCount: count <= 4 ? 2 : 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: .62,
        children: List.generate(
          count,
          (index) => Column(
            children: [
              Expanded(
                flex: 2,
                child: _TournamentVideo(label: 'Видео ${index + 1}'),
              ),
              const SizedBox(height: 5),
              Expanded(
                flex: 5,
                child: _TournamentBoard(label: 'Доска ${index + 1}'),
              ),
            ],
          ),
        ),
      );

  Widget _columns(List<bool> videoFlags) => Row(
        children: [
          for (var i = 0; i < videoFlags.length; i++) ...[
            Expanded(child: _workspaceTile(videoFlags[i], i)),
            if (i + 1 < videoFlags.length) const SizedBox(width: 8),
          ],
        ],
      );

  Widget _rows(List<bool> videoFlags) => Column(
        children: [
          for (var i = 0; i < videoFlags.length; i++) ...[
            Expanded(child: _workspaceTile(videoFlags[i], i)),
            if (i + 1 < videoFlags.length) const SizedBox(height: 8),
          ],
        ],
      );

  Widget _workspaceTile(bool video, int index) => video
      ? _TournamentVideo(label: 'Видео ${index + 1}')
      : _TournamentBoard(label: 'Доска ${index + 1}');

  Widget _rightSidebar() => Column(
        children: [
          _readinessPanel(),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: AppDecorations.panel(),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MakeChessLocalizedText('Ходы', style: AppTextStyles.panelTitle),
                  SizedBox(height: 10),
                  Expanded(
                    child: Center(
                      child: MakeChessLocalizedText(
                        'Партия ещё не начата',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _controls(),
        ],
      );

  Widget _readinessPanel() => Container(
        constraints: const BoxConstraints(maxHeight: 210),
        padding: const EdgeInsets.all(10),
        decoration: AppDecorations.panel(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MakeChessLocalizedText('Готовность участников',
                style: AppTextStyles.panelTitle),
            const SizedBox(height: 7),
            if (_tournamentParticipants.isEmpty)
              const MakeChessLocalizedText('Список участников загружается…',
                  style: TextStyle(color: Colors.white38))
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _tournamentParticipants.length,
                  itemBuilder: (_, index) {
                    final participant = _tournamentParticipants[index];
                    final id = '${participant['id'] ?? ''}';
                    final ready = _onlineParticipantIds.contains(id);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(
                            ready ? Icons.check_circle : Icons.cancel,
                            color:
                                ready ? Colors.greenAccent : Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: MakeChessLocalizedText(
                              '${participant['name'] ?? 'Участник'}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );

  Widget _controls() {
    Widget button(String text, IconData icon, VoidCallback? onPressed,
        {bool danger = false}) {
      return Expanded(
        child: AppNeoButton(
          text: text,
          icon: icon,
          onTap: onPressed,
          danger: danger,
          compact: true,
        ),
      );
    }

    final analysisAction = _gameFinished
        ? () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: MakeChessLocalizedText('Инструмент анализа открыт')),
            )
        : null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: AppDecorations.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MakeChessLocalizedText(
            _gameFinished ? 'Анализ партии' : 'Управление партией',
            style: AppTextStyles.panelTitle,
          ),
          const SizedBox(height: 8),
          Row(children: [
            button('Сдаться', Icons.flag,
                _gameFinished ? null : () => _finishGame('Сдаться'),
                danger: true),
            const SizedBox(width: 5),
            button('Ничья', Icons.handshake_outlined,
                _gameFinished ? null : () => _finishGame('Ничья')),
          ]),
          const SizedBox(height: 5),
          Row(children: [
            button('◀', Icons.chevron_left, analysisAction),
            const SizedBox(width: 5),
            button('▶', Icons.chevron_right, analysisAction),
          ]),
          const SizedBox(height: 5),
          Row(children: [
            button('Лучший ход', Icons.flash_on, analysisAction),
            const SizedBox(width: 5),
            button('Объяснить', Icons.psychology, analysisAction),
          ]),
          const SizedBox(height: 5),
          Row(children: [
            button('Введите FEN', Icons.code, analysisAction),
            const SizedBox(width: 5),
            button('Analysis', Icons.analytics, analysisAction),
          ]),
          const SizedBox(height: 5),
          AppNeoButton(
            text: 'Редактор',
            icon: Icons.edit,
            onTap: analysisAction,
            compact: true,
          ),
        ],
      ),
    );
  }

  String _layoutTitle(TournamentPlatformLayout layout) => switch (layout) {
        TournamentPlatformLayout.oneVideoEightBoards =>
          'Одно видео слева, восемь досок справа',
        TournamentPlatformLayout.videosAboveEightBoards =>
          'Видео каждого игрока над его доской',
        TournamentPlatformLayout.eightBoardsNoVideo => 'Только восемь досок',
        TournamentPlatformLayout.oneBoardOneVideo => 'Одна доска, одно видео',
        TournamentPlatformLayout.eightVideosOnly => 'Все восемь видео',
        TournamentPlatformLayout.oneBoardNoVideo => 'Одна доска по центру',
        TournamentPlatformLayout.oneBoardTwoVideos => 'Одна доска, два видео',
        TournamentPlatformLayout.twoBoardsFourVideos =>
          'Две доски, четыре видео',
        TournamentPlatformLayout.twoBoardsNoVideo => 'Две доски без видео',
      };
}

class _TournamentVideo extends StatelessWidget {
  const _TournamentVideo({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0C1823),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.cyanAccent.withOpacity(.45)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined,
                  size: 34, color: Colors.white38),
              const SizedBox(height: 8),
              MakeChessLocalizedText(label, style: const TextStyle(color: Colors.white60)),
              const MakeChessLocalizedText('Видео не подключено',
                  style: TextStyle(color: Colors.white30, fontSize: 12)),
            ],
          ),
        ),
      );
}

class _TournamentBoard extends StatefulWidget {
  const _TournamentBoard({
    required this.label,
    this.active = false,
    this.playAsBlack = false,
    this.tournamentId = '',
    this.ownerId = '',
  });

  final String label;
  final bool active;
  final bool playAsBlack;
  final String tournamentId;
  final String ownerId;

  @override
  State<_TournamentBoard> createState() => _TournamentBoardState();
}

class _TournamentBoardState extends State<_TournamentBoard> {
  final BoardThemeController _theme = BoardThemeController();
  final ch.Chess _game = ch.Chess();
  RealtimeChannel? _gameChannel;
  String? _selectedSquare;
  int _version = 0;
  int _boardNumber = 1;
  String _turn = 'w';
  String _gameStatus = 'waiting';
  bool _networkReady = false;
  Timer? _clockTicker;
  int _whiteMs = 300000;
  int _blackMs = 300000;
  DateTime? _activeSince;
  bool _timeoutSubmitting = false;

  static const _pieces = <String?>[
    'bR',
    'bN',
    'bB',
    'bQ',
    'bK',
    'bB',
    'bN',
    'bR',
    'bP',
    'bP',
    'bP',
    'bP',
    'bP',
    'bP',
    'bP',
    'bP',
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    'wP',
    'wP',
    'wP',
    'wP',
    'wP',
    'wP',
    'wP',
    'wP',
    'wR',
    'wN',
    'wB',
    'wQ',
    'wK',
    'wB',
    'wN',
    'wR',
  ];

  @override
  void initState() {
    super.initState();
    _theme.load();
    _loadNetworkGame();
    _clockTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || !_networkReady || _gameStatus != 'running') return;
      setState(() {});
      _submitTimeoutIfNeeded();
    });
  }

  Future<void> _loadNetworkGame() async {
    if (widget.tournamentId.isEmpty || widget.ownerId.isEmpty) return;
    final client = Supabase.instance.client;
    final row = await client
        .from('makechess_tournament_games_v1')
        .select()
        .eq('owner_id', widget.ownerId)
        .eq('tournament_id', widget.tournamentId)
        .or('white_id.eq.${client.auth.currentUser?.id},black_id.eq.${client.auth.currentUser?.id}')
        .limit(1)
        .maybeSingle();
    if (row == null) return;
    _applyNetworkRow(Map<String, dynamic>.from(row));
    _gameChannel ??= client.channel(
      'makechess:tournament-game:${widget.ownerId}:${widget.tournamentId}:v1',
    )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'makechess_tournament_games_v1',
        callback: (payload) {
          final data = payload.newRecord;
          if ('${data['owner_id'] ?? ''}' != widget.ownerId ||
              '${data['tournament_id'] ?? ''}' != widget.tournamentId ||
              (data['board'] as num?)?.toInt() != _boardNumber) return;
          _applyNetworkRow(Map<String, dynamic>.from(data));
        },
      )
      ..subscribe();
  }

  void _applyNetworkRow(Map<String, dynamic> row) {
    final fen = '${row['fen'] ?? ''}';
    if (fen.isEmpty || !_game.load(fen)) return;
    if (!mounted) return;
    setState(() {
      _version = (row['version'] as num?)?.toInt() ?? 0;
      _boardNumber = (row['board'] as num?)?.toInt() ?? 1;
      _turn = '${row['turn'] ?? 'w'}';
      _gameStatus = '${row['status'] ?? 'waiting'}';
      _whiteMs = (row['white_ms'] as num?)?.toInt() ?? 300000;
      _blackMs = (row['black_ms'] as num?)?.toInt() ?? 300000;
      _activeSince = DateTime.tryParse('${row['active_since'] ?? ''}')?.toUtc();
      _networkReady = true;
      _selectedSquare = null;
    });
  }

  int _remainingMs(String color) {
    var value = color == 'w' ? _whiteMs : _blackMs;
    if (_gameStatus == 'running' && _turn == color && _activeSince != null) {
      value -= DateTime.now().toUtc().difference(_activeSince!).inMilliseconds;
    }
    return value < 0 ? 0 : value;
  }

  String _clockText(int milliseconds) {
    final seconds = (milliseconds / 1000).ceil();
    final minutes = seconds ~/ 60;
    return '${minutes.toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _submitTimeoutIfNeeded() async {
    if (_timeoutSubmitting || _remainingMs(_turn) > 0) return;
    _timeoutSubmitting = true;
    try {
      await Supabase.instance.client.rpc(
        'finish_makechess_tournament_game_v1',
        params: <String, dynamic>{
          'p_owner_id': widget.ownerId,
          'p_tournament_id': widget.tournamentId,
          'p_board': _boardNumber,
          'p_result': _turn == 'w' ? '0-1' : '1-0',
          'p_reason': 'time',
        },
      );
    } finally {
      _timeoutSubmitting = false;
    }
  }

  List<String?> _piecesFromFen() {
    final result = <String?>[];
    for (final rank in _game.fen.split(' ').first.split('/')) {
      for (final symbol in rank.split('')) {
        final empty = int.tryParse(symbol);
        if (empty != null) {
          result.addAll(List<String?>.filled(empty, null));
        } else {
          final white = symbol == symbol.toUpperCase();
          result.add('${white ? 'w' : 'b'}${symbol.toUpperCase()}');
        }
      }
    }
    return result.length == 64 ? result : _pieces;
  }

  String _squareForIndex(int displayedIndex) {
    final index = widget.playAsBlack ? 63 - displayedIndex : displayedIndex;
    final file = String.fromCharCode('a'.codeUnitAt(0) + index % 8);
    final rank = 8 - index ~/ 8;
    return '$file$rank';
  }

  Future<void> _tapSquare(int displayedIndex) async {
    if (!_networkReady || !widget.active || _gameStatus != 'running') return;
    final myTurn = widget.playAsBlack ? _turn == 'b' : _turn == 'w';
    if (!myTurn) return;
    final square = _squareForIndex(displayedIndex);
    if (_selectedSquare == null) {
      final piece = _game.get(square);
      if (piece == null) return;
      final ownPiece = widget.playAsBlack
          ? piece.color == ch.Color.BLACK
          : piece.color == ch.Color.WHITE;
      if (!ownPiece) return;
      setState(() => _selectedSquare = square);
      return;
    }
    final from = _selectedSquare!;
    var promotion = '';
    final piece = _game.get(from);
    if (piece?.type == ch.PieceType.PAWN &&
        (square.endsWith('8') || square.endsWith('1'))) {
      promotion = 'q';
    }
    final ok = _game.move(<String, dynamic>{
      'from': from,
      'to': square,
      if (promotion.isNotEmpty) 'promotion': promotion,
    });
    if (!ok) {
      setState(() => _selectedSquare = null);
      return;
    }
    try {
      await Supabase.instance.client.rpc(
        'move_makechess_tournament_game_v1',
        params: <String, dynamic>{
          'p_owner_id': widget.ownerId,
          'p_tournament_id': widget.tournamentId,
          'p_board': _boardNumber,
          'p_from': from,
          'p_to': square,
          'p_promotion': promotion,
          'p_fen': _game.fen,
          'p_expected_version': _version,
        },
      );
      if (_game.game_over) {
        final result = _game.in_checkmate
            ? (_game.turn == ch.Color.WHITE ? '0-1' : '1-0')
            : '1/2-1/2';
        await Supabase.instance.client.rpc(
          'finish_makechess_tournament_game_v1',
          params: <String, dynamic>{
            'p_owner_id': widget.ownerId,
            'p_tournament_id': widget.tournamentId,
            'p_board': _boardNumber,
            'p_result': result,
            'p_reason': _game.in_checkmate ? 'checkmate' : 'draw',
          },
        );
      }
      if (mounted) setState(() => _selectedSquare = null);
    } catch (_) {
      await _loadNetworkGame();
    }
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    final channel = _gameChannel;
    if (channel != null) Supabase.instance.client.removeChannel(channel);
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111C27),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.cyanAccent.withOpacity(.5)),
        ),
        padding: const EdgeInsets.all(7),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: MakeChessLocalizedText(
                widget.label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 5),
            if (_networkReady)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ClockLabel(
                    caption: 'Белые',
                    value: _clockText(_remainingMs('w')),
                    active: _gameStatus == 'running' && _turn == 'w',
                  ),
                  _ClockLabel(
                    caption: 'Чёрные',
                    value: _clockText(_remainingMs('b')),
                    active: _gameStatus == 'running' && _turn == 'b',
                  ),
                ],
              ),
            if (_networkReady) const SizedBox(height: 5),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: AnimatedBuilder(
                    animation: _theme,
                    builder: (_, __) => GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                      ),
                      itemCount: 64,
                      itemBuilder: (_, index) {
                        final row = index ~/ 8;
                        final column = index % 8;
                        final pieces =
                            _networkReady ? _piecesFromFen() : _pieces;
                        final boardIndex =
                            widget.playAsBlack ? 63 - index : index;
                        final piece = pieces[boardIndex];
                        final square = _squareForIndex(index);
                        return GestureDetector(
                          onTap: () => _tapSquare(index),
                          child: ColoredBox(
                            color: square == _selectedSquare
                                ? Colors.amber.withOpacity(.65)
                                : (row + column).isEven
                                    ? _theme.lightSquare
                                    : _theme.darkSquare,
                            child: piece == null
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: SvgPicture.asset(
                                      'assets/pieces/cburnett/$piece.svg',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            if (widget.active &&
                _gameStatus == 'running' &&
                (widget.playAsBlack ? _turn == 'b' : _turn == 'w'))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: const Color(0xFF167C4D),
                alignment: Alignment.center,
                child: const MakeChessLocalizedText(
                  'ВАШ ХОД',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            if (_networkReady && _gameStatus == 'paused')
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: MakeChessLocalizedText(
                  'ТУРНИР ПРИОСТАНОВЛЕН',
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      );
}

class _ClockLabel extends StatelessWidget {
  const _ClockLabel({
    required this.caption,
    required this.value,
    required this.active,
  });

  final String caption;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF167C4D) : Colors.white10,
          borderRadius: BorderRadius.circular(6),
        ),
        child: MakeChessLocalizedText(
          '$caption  $value',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      );
}

class _LiveTournamentTableDialog extends StatefulWidget {
  const _LiveTournamentTableDialog({
    required this.tournamentId,
    required this.ownerId,
    required this.tournamentName,
  });

  final String tournamentId;
  final String ownerId;
  final String tournamentName;

  @override
  State<_LiveTournamentTableDialog> createState() =>
      _LiveTournamentTableDialogState();
}

class _LiveTournamentTableDialogState
    extends State<_LiveTournamentTableDialog> {
  Timer? _refreshTimer;
  Map<String, dynamic>? _tournament;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) => _reload());
  }

  Future<void> _reload() async {
    try {
      final tournaments =
          await TournamentStorageService.instance.loadVisibleTournaments();
      Map<String, dynamic>? found;
      for (final tournament in tournaments) {
        if ('${tournament['id'] ?? ''}' == widget.tournamentId &&
            '${tournament['_ownerId'] ?? ''}' == widget.ownerId) {
          found = tournament;
          break;
        }
      }
      if (mounted) {
        setState(() {
          _tournament = found;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  double _pointsFor(String playerId, List<Map<String, dynamic>> pairings) {
    var points = 0.0;
    for (final pairing in pairings) {
      final white = '${pairing['whiteId'] ?? ''}';
      final black = '${pairing['blackId'] ?? ''}';
      final result = '${pairing['result'] ?? '*'}';
      if (playerId != white && playerId != black) continue;
      if (black.isEmpty && playerId == white) {
        points += 1;
      } else if (result == '1-0' && playerId == white) {
        points += 1;
      } else if (result == '0-1' && playerId == black) {
        points += 1;
      } else if (result == '1/2-1/2' || result == '½-½') {
        points += .5;
      }
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final tournament = _tournament;
    final ids = tournament?['participantIds'] is List
        ? (tournament!['participantIds'] as List).map((id) => '$id').toList()
        : <String>[];
    final names = tournament?['participantNames'] is Map
        ? Map<String, dynamic>.from(tournament!['participantNames'] as Map)
        : <String, dynamic>{};
    final pairings = tournament?['pairings'] is List
        ? (tournament!['pairings'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    ids.sort((a, b) => _pointsFor(b, pairings).compareTo(_pointsFor(a, pairings)));

    return Dialog(
      insetPadding: const EdgeInsets.all(28),
      backgroundColor: const Color(0xFF081722),
      child: SizedBox(
        width: 1050,
        height: 720,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.emoji_events, color: Colors.amberAccent),
              title: MakeChessLocalizedText('Турнирная таблица — ${widget.tournamentName}'),
              subtitle: const MakeChessLocalizedText('Результаты обновляются автоматически'),
              trailing: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            const Divider(height: 1),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (tournament == null)
              const Expanded(
                child: Center(child: MakeChessLocalizedText('Не удалось загрузить турнир')),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: DataTable(
                    columns: const [
                      DataColumn(label: MakeChessLocalizedText('Место')),
                      DataColumn(label: MakeChessLocalizedText('Участник')),
                      DataColumn(label: MakeChessLocalizedText('Очки')),
                      DataColumn(label: MakeChessLocalizedText('Сыграно')),
                      DataColumn(label: MakeChessLocalizedText('Результаты')),
                    ],
                    rows: [
                      for (var index = 0; index < ids.length; index++)
                        _row(index, ids[index], names, pairings),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  DataRow _row(
    int index,
    String playerId,
    Map<String, dynamic> names,
    List<Map<String, dynamic>> pairings,
  ) {
    final played = pairings.where((pairing) {
      final involved = '${pairing['whiteId'] ?? ''}' == playerId ||
          '${pairing['blackId'] ?? ''}' == playerId;
      return involved && '${pairing['result'] ?? '*'}' != '*';
    }).toList();
    final results = played.map((pairing) => '${pairing['result']}').join(', ');
    final points = _pointsFor(playerId, pairings);
    return DataRow(cells: [
      DataCell(MakeChessLocalizedText('${index + 1}')),
      DataCell(MakeChessLocalizedText('${names[playerId] ?? playerId}')),
      DataCell(MakeChessLocalizedText(points == points.roundToDouble()
          ? '${points.toInt()}'
          : points.toStringAsFixed(1))),
      DataCell(MakeChessLocalizedText('${played.length}')),
      DataCell(MakeChessLocalizedText(results.isEmpty ? '—' : results)),
    ]);
  }
}
