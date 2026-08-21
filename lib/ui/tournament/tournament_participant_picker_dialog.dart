// MAKECHESS_REMAINING_UI_V6_20260807
// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/teacher_account_store.dart';

import '../../localization/makechess_localization.dart';

enum _PickerTab { mySchool, otherSchool, all }

Future<Map<String, dynamic>?> showTournamentParticipantPickerDialog({
  required BuildContext context,
  required Set<String> excludedIds,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _TournamentParticipantPickerDialog(
      excludedIds: excludedIds,
    ),
  );
}

class _TournamentParticipantPickerDialog extends StatefulWidget {
  const _TournamentParticipantPickerDialog({required this.excludedIds});

  final Set<String> excludedIds;

  @override
  State<_TournamentParticipantPickerDialog> createState() =>
      _TournamentParticipantPickerDialogState();
}

class _TournamentParticipantPickerDialogState
    extends State<_TournamentParticipantPickerDialog> {
  final _search = TextEditingController();
  final _schoolSearch = TextEditingController();
  final List<Map<String, dynamic>> _profiles = [];
  final List<Map<String, dynamic>> _myStudents = [];
  final List<TeacherAccount> _schools = [];
  final Map<String, List<Map<String, dynamic>>> _schoolMembers = {};
  final Set<String> _expanded = {};
  final Set<String> _loadingSchools = {};
  _PickerTab _tab = _PickerTab.mySchool;
  bool _loading = true;
  bool _sortRating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id ?? '';
      final results = await Future.wait<dynamic>([
        client.from('profiles').select(),
        if (userId.isNotEmpty)
          client
              .from('teacher_students')
              .select('student_id, student_nickname')
              .eq('teacher_id', userId)
        else
          Future.value(<Map<String, dynamic>>[]),
        TeacherAccountStore.instance.loadAccounts(),
      ]);
      final profiles = (results[0] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final byId = <String, Map<String, dynamic>>{
        for (final profile in profiles) '${profile['id'] ?? ''}': profile,
      };
      final mine = (results[1] as List).whereType<Map>().map((raw) {
        final row = Map<String, dynamic>.from(raw);
        final id = '${row['student_id'] ?? ''}';
        final profile = byId[id] ?? const <String, dynamic>{};
        return <String, dynamic>{
          ...profile,
          'id': id,
          'nickname': '${row['student_nickname'] ?? profile['nickname'] ?? id}',
        };
      }).toList();
      if (!mounted) return;
      setState(() {
        _profiles.addAll(profiles);
        _myStudents.addAll(mine);
        _schools.addAll(results[2] as List<TeacherAccount>);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _schoolSearch.dispose();
    super.dispose();
  }

  Map<String, dynamic> _participant(Map<String, dynamic> profile,
          {String school = ''}) =>
      <String, dynamic>{
        'id': '${profile['id'] ?? ''}',
        'name': '${profile['nickname'] ?? profile['name'] ?? 'Участник'}',
        'rating': (profile['rating'] as num?)?.toInt() ?? 1200,
        'school': school,
        'flag': '${profile['country'] ?? ''}',
        'avatarUrl': '${profile['avatar_url'] ?? ''}',
      };

  List<Map<String, dynamic>> get _visiblePeople {
    final source = _tab == _PickerTab.mySchool ? _myStudents : _profiles;
    final query = _search.text.trim().toLowerCase();
    final result = source.where((profile) {
      final id = '${profile['id'] ?? ''}';
      final name =
          '${profile['nickname'] ?? profile['name'] ?? ''}'.toLowerCase();
      return id.isNotEmpty &&
          !widget.excludedIds.contains(id) &&
          (query.isEmpty || name.contains(query));
    }).toList();
    result.sort((a, b) => _sortRating
        ? ((b['rating'] as num?)?.toInt() ?? 1200)
            .compareTo((a['rating'] as num?)?.toInt() ?? 1200)
        : '${a['nickname'] ?? ''}'.compareTo('${b['nickname'] ?? ''}'));
    return result;
  }

  Future<void> _toggleSchool(TeacherAccount school) async {
    if (_expanded.remove(school.id)) {
      setState(() {});
      return;
    }
    setState(() => _expanded.add(school.id));
    if (_schoolMembers.containsKey(school.id) || school.ownerUserId.isEmpty) {
      return;
    }
    setState(() => _loadingSchools.add(school.id));
    try {
      final rows = await Supabase.instance.client
          .from('teacher_students')
          .select('student_id, student_nickname')
          .eq('teacher_id', school.ownerUserId);
      final byId = <String, Map<String, dynamic>>{
        for (final profile in _profiles) '${profile['id'] ?? ''}': profile,
      };
      final members = rows.whereType<Map>().map((raw) {
        final row = Map<String, dynamic>.from(raw);
        final id = '${row['student_id'] ?? ''}';
        return <String, dynamic>{
          ...?byId[id],
          'id': id,
          'nickname':
              '${row['student_nickname'] ?? byId[id]?['nickname'] ?? id}',
        };
      }).toList();
      if (mounted) setState(() => _schoolMembers[school.id] = members);
    } finally {
      if (mounted) setState(() => _loadingSchools.remove(school.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF111C27),
      child: SizedBox(
        width: 760,
        height: 680,
        child: Column(
          children: [
            ListTile(
              leading:
                  const Icon(Icons.person_add_alt_1, color: Colors.cyanAccent),
              title: const MakeChessLocalizedText('Добавить участника'),
              subtitle: const MakeChessLocalizedText(
                  'Участник будет добавлен в открытый турнир'),
              trailing: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _tabButton('Моя школа', _PickerTab.mySchool),
                  const SizedBox(width: 8),
                  _tabButton('Другая школа', _PickerTab.otherSchool),
                  const SizedBox(width: 8),
                  _tabButton('Все участники', _PickerTab.all),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _tab == _PickerTab.otherSchool
                      ? _schoolsView()
                      : _peopleView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String text, _PickerTab value) => Expanded(
        child: OutlinedButton(
          onPressed: () => setState(() => _tab = value),
          style: OutlinedButton.styleFrom(
            foregroundColor: _tab == value ? Colors.cyanAccent : Colors.white70,
            side: BorderSide(
                color: _tab == value ? Colors.cyanAccent : Colors.white24),
          ),
          child: MakeChessLocalizedText(text),
        ),
      );

  Widget _peopleView() => Column(
        children: [
          _searchRow(_search, 'Поиск участника'),
          Expanded(child: _peopleList(_visiblePeople)),
        ],
      );

  Widget _searchRow(TextEditingController controller, String hint) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: MakeChessLocalization.phrase(hint),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => setState(() => _sortRating = !_sortRating),
              icon: const Icon(Icons.sort),
              label: MakeChessLocalizedText(
                  _sortRating ? 'По рейтингу' : 'По имени'),
            ),
          ],
        ),
      );

  Widget _peopleList(List<Map<String, dynamic>> people, {String school = ''}) =>
      ListView.builder(
        itemCount: people.length,
        itemBuilder: (_, index) {
          final profile = people[index];
          final participant = _participant(profile, school: school);
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: MakeChessLocalizedText('${participant['name']}'),
            subtitle: MakeChessLocalizedText([
              'Рейтинг: ${participant['rating']}',
              if ('${profile['country'] ?? ''}'.isNotEmpty)
                '${profile['country']}',
            ].join(' • ')),
            trailing: FilledButton.icon(
              onPressed: () => Navigator.pop(context, participant),
              icon: const Icon(Icons.add),
              label: const MakeChessLocalizedText('Добавить'),
            ),
          );
        },
      );

  Widget _schoolsView() {
    final query = _schoolSearch.text.trim().toLowerCase();
    final schools = _schools
        .where(
            (s) => query.isEmpty || s.schoolName.toLowerCase().contains(query))
        .toList();
    return Column(
      children: [
        _searchRow(_schoolSearch, 'Поиск школы или учителя'),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: schools.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final school = schools[index];
              final expanded = _expanded.contains(school.id);
              final members = (_schoolMembers[school.id] ?? [])
                  .where(
                      (p) => !widget.excludedIds.contains('${p['id'] ?? ''}'))
                  .toList();
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.cyanAccent.withOpacity(.55)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading:
                          const Icon(Icons.school, color: Colors.cyanAccent),
                      title: MakeChessLocalizedText(school.schoolName),
                      subtitle: MakeChessLocalizedText(school.about),
                      trailing: IconButton(
                        onPressed: () => _toggleSchool(school),
                        icon: Icon(expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down),
                      ),
                    ),
                    if (expanded) ...[
                      const Divider(height: 1),
                      if (_loadingSchools.contains(school.id))
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child:
                              _peopleList(members, school: school.schoolName),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
