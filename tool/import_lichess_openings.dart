import 'dart:convert';
import 'dart:io';

import 'package:chess/chess.dart' as chess;

const _sourceFiles = <String, String>{
  'A': 'https://raw.githubusercontent.com/lichess-org/chess-openings/master/a.tsv',
  'B': 'https://raw.githubusercontent.com/lichess-org/chess-openings/master/b.tsv',
  'C': 'https://raw.githubusercontent.com/lichess-org/chess-openings/master/c.tsv',
  'D': 'https://raw.githubusercontent.com/lichess-org/chess-openings/master/d.tsv',
  'E': 'https://raw.githubusercontent.com/lichess-org/chess-openings/master/e.tsv',
};

class _OpeningLine {
  const _OpeningLine({
    required this.eco,
    required this.name,
    required this.pgn,
    required this.uci,
  });

  final String eco;
  final String name;
  final String pgn;
  final List<String> uci;
}

class _OpeningGroup {
  _OpeningGroup(this.name);

  final String name;
  final Set<String> ecoCodes = <String>{};
  final List<_OpeningLine> lines = <_OpeningLine>[];
  final Set<String> _lineKeys = <String>{};

  void add(_OpeningLine line) {
    final key = line.uci.join(' ');
    if (!_lineKeys.add(key)) return;
    ecoCodes.add(line.eco);
    lines.add(line);
  }

  List<String> get firstMoves {
    if (lines.isEmpty) return const <String>[];
    final sorted = List<_OpeningLine>.from(lines)
      ..sort((a, b) {
        final byLength = a.uci.length.compareTo(b.uci.length);
        if (byLength != 0) return byLength;
        return a.uci.join(' ').compareTo(b.uci.join(' '));
      });
    return List<String>.unmodifiable(sorted.first.uci);
  }
}

Future<String> _downloadText(Uri uri) async {
  final client = HttpClient();
  client.userAgent = 'MakeChess-Lichess-Opening-Importer/1.0';
  try {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'text/plain');
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'HTTP ${response.statusCode} for $uri',
        uri: uri,
      );
    }
    return await utf8.decoder.bind(response).join();
  } finally {
    client.close(force: true);
  }
}

String _promotionCode(dynamic raw) {
  if (raw == null) return '';
  final value = '$raw'.trim().toLowerCase();
  if (value == 'q' || value.endsWith('queen')) return 'q';
  if (value == 'r' || value.endsWith('rook')) return 'r';
  if (value == 'b' || value.endsWith('bishop')) return 'b';
  if (value == 'n' || value.endsWith('knight')) return 'n';
  return '';
}

List<String>? _pgnToUci(String pgn) {
  final game = chess.Chess();
  final loaded = game.load_pgn(pgn);
  if (!loaded) return null;

  final history = game.getHistory(<String, dynamic>{'verbose': true});
  final result = <String>[];

  for (final raw in history) {
    if (raw is! Map) return null;
    final move = Map<String, dynamic>.from(raw);
    final from = '${move['from'] ?? ''}'.trim().toLowerCase();
    final to = '${move['to'] ?? ''}'.trim().toLowerCase();
    if (!RegExp(r'^[a-h][1-8]$').hasMatch(from) ||
        !RegExp(r'^[a-h][1-8]$').hasMatch(to)) {
      return null;
    }
    result.add('$from$to${_promotionCode(move['promotion'])}');
  }

  return result.isEmpty ? null : result;
}

String _sqlLiteral(String value) => "'${value.replaceAll("'", "''")}'";

int _fnv1a32(String value) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(value)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

String _idForName(String name) {
  final hex = _fnv1a32(name).toRadixString(16).padLeft(8, '0');
  return 'lichess_cc0_$hex';
}

String _valueSql(_OpeningGroup group, int sortOrder) {
  final sortedLines = List<_OpeningLine>.from(group.lines)
    ..sort((a, b) {
      final byLength = a.uci.length.compareTo(b.uci.length);
      if (byLength != 0) return byLength;
      return a.uci.join(' ').compareTo(b.uci.join(' '));
    });

  final json = <String, dynamic>{
    'id': _idForName(group.name),
    'name': group.name,
    'studentColor': 'white',
    'startFen': 'startpos',
    'sourceName': 'Lichess chess-openings',
    'sourceLicense': 'CC0-1.0',
    'eco': (group.ecoCodes.toList()..sort()).join(', '),
    'firstMoves': group.firstMoves,
    'popularity': 0,
    'whiteEfficiency': 0,
    'blackEfficiency': 0,
    'statisticsStatus': 'not_indexed',
    'lines': sortedLines
        .map(
          (line) => <String, dynamic>{
            'title': line.name,
            'eco': line.eco,
            'pgn': line.pgn,
            'moves': line.uci,
          },
        )
        .toList(growable: false),
  };

  final jsonBase64 = base64Encode(utf8.encode(jsonEncode(json)));
  final buffer = StringBuffer();
  buffer.writeln('(');
  buffer.writeln('  ${_sqlLiteral(_idForName(group.name))},');
  buffer.writeln('  ${_sqlLiteral(group.name)},');
  buffer.writeln("  'white',");
  buffer.writeln("  'startpos',");
  buffer.writeln("  'Lichess chess-openings',");
  buffer.writeln("  'CC0-1.0',");
  buffer.writeln(
    "  convert_from(decode('$jsonBase64', 'base64'), 'UTF8')::jsonb,",
  );
  buffer.writeln('  true,');
  buffer.writeln('  $sortOrder');
  buffer.write(')');
  return buffer.toString();
}

Future<void> main(List<String> args) async {
  var outputPath =
      'supabase/migrations/20260805114500_import_lichess_cc0_openings.sql';

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--output' && i + 1 < args.length) {
      outputPath = args[++i];
    }
  }

  stdout.writeln('Downloading the official Lichess CC0 opening catalog...');

  final groups = <String, _OpeningGroup>{};
  var sourceRows = 0;
  var skippedRows = 0;

  for (final entry in _sourceFiles.entries) {
    stdout.writeln('  ECO ${entry.key}...');
    final text = await _downloadText(Uri.parse(entry.value));
    final lines = const LineSplitter().convert(text);

    for (var index = 1; index < lines.length; index++) {
      final row = lines[index].trimRight();
      if (row.isEmpty) continue;

      final columns = row.split('\t');
      if (columns.length < 3) {
        skippedRows++;
        continue;
      }

      final eco = columns[0].trim();
      final name = columns[1].trim();
      final pgn = columns.sublist(2).join('\t').trim();
      if (eco.isEmpty || name.isEmpty || pgn.isEmpty) {
        skippedRows++;
        continue;
      }

      sourceRows++;
      final uci = _pgnToUci(pgn);
      if (uci == null || uci.isEmpty) {
        skippedRows++;
        stderr.writeln('Skipped PGN: $eco | $name | $pgn');
        continue;
      }

      final group = groups.putIfAbsent(name, () => _OpeningGroup(name));
      group.add(
        _OpeningLine(
          eco: eco,
          name: name,
          pgn: pgn,
          uci: uci,
        ),
      );
    }
  }

  final catalog = groups.values.where((group) => group.lines.isNotEmpty).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  if (catalog.length < 1000) {
    throw StateError(
      'Safety stop: only ${catalog.length} opening names were parsed.',
    );
  }

  final sql = StringBuffer()
    ..writeln(r'\set ON_ERROR_STOP on')
    ..writeln('BEGIN;')
    ..writeln()
    ..writeln(r'''DO $$
BEGIN
  IF to_regclass('public.makechess_opening_trees_v1') IS NULL THEN
    RAISE EXCEPTION 'Table public.makechess_opening_trees_v1 does not exist';
  END IF;
END
$$;''')
    ..writeln()
    ..writeln(
      r"DELETE FROM public.makechess_opening_trees_v1 "
      r"WHERE id LIKE 'lichess\_cc0\_%' ESCAPE '\';",
    )
    ..writeln();

  const batchSize = 150;
  for (var start = 0; start < catalog.length; start += batchSize) {
    final end = (start + batchSize < catalog.length)
        ? start + batchSize
        : catalog.length;

    sql
      ..writeln('INSERT INTO public.makechess_opening_trees_v1 (')
      ..writeln('  id, name, student_color, start_fen, source_name,')
      ..writeln('  source_license, opening_json, is_published, sort_order')
      ..writeln(') VALUES');

    for (var i = start; i < end; i++) {
      sql.write(_valueSql(catalog[i], i + 100));
      sql.writeln(i + 1 == end ? '' : ',');
    }

    sql
      ..writeln('ON CONFLICT (id) DO UPDATE SET')
      ..writeln('  name = EXCLUDED.name,')
      ..writeln('  student_color = EXCLUDED.student_color,')
      ..writeln('  start_fen = EXCLUDED.start_fen,')
      ..writeln('  source_name = EXCLUDED.source_name,')
      ..writeln('  source_license = EXCLUDED.source_license,')
      ..writeln('  opening_json = EXCLUDED.opening_json,')
      ..writeln('  is_published = EXCLUDED.is_published,')
      ..writeln('  sort_order = EXCLUDED.sort_order,')
      ..writeln('  updated_at = now();')
      ..writeln();
  }

  sql
    ..writeln(
      "DELETE FROM public.makechess_opening_trees_v1 "
      "WHERE id = 'demo_open_games_white';",
    )
    ..writeln()
    ..writeln('COMMIT;')
    ..writeln()
    ..writeln(
      "SELECT count(*) AS lichess_openings "
      "FROM public.makechess_opening_trees_v1 "
      r"WHERE id LIKE 'lichess\_cc0\_%' ESCAPE '\';",
    );

  final output = File(outputPath);
  await output.parent.create(recursive: true);
  await output.writeAsString(sql.toString(), encoding: utf8);

  stdout.writeln();
  stdout.writeln('Source rows read: $sourceRows');
  stdout.writeln('Unique opening names: ${catalog.length}');
  stdout.writeln('Skipped rows: $skippedRows');
  stdout.writeln('SQL created: ${output.absolute.path}');
  stdout.writeln('SQL size: ${await output.length()} bytes');
}
