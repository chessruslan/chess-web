$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host 'MAKECHESS - TOURNAMENT OWNER JOIN V9' -ForegroundColor Cyan
Write-Host 'Path-safe surgical patch; creator may join as player' -ForegroundColor Cyan
Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host "Project: $Root"
Write-Host ''

function Read-Utf8([string]$Path) {
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Find-UniqueDartFile([string]$FileName, [string]$Signature) {
    $lib = Join-Path $Root 'lib'
    if (-not (Test-Path -LiteralPath $lib)) {
        throw "LIB_NOT_FOUND: $lib"
    }

    $candidates = @(Get-ChildItem -LiteralPath $lib -Recurse -File -Filter $FileName -ErrorAction SilentlyContinue)
    if ($candidates.Count -eq 0) {
        # Fallback: file may have been renamed. Find it by a class/function signature.
        $allDart = @(Get-ChildItem -LiteralPath $lib -Recurse -File -Filter '*.dart' -ErrorAction SilentlyContinue)
        $candidates = @($allDart | Where-Object {
            try { (Read-Utf8 $_.FullName).Contains($Signature) } catch { $false }
        })
    } else {
        $candidates = @($candidates | Where-Object {
            try { (Read-Utf8 $_.FullName).Contains($Signature) } catch { $false }
        })
    }

    if ($candidates.Count -eq 0) {
        throw "TARGET_NOT_FOUND_BY_NAME_OR_SIGNATURE: $FileName / $Signature"
    }
    if ($candidates.Count -gt 1) {
        Write-Host "MULTIPLE_TARGETS: $FileName" -ForegroundColor Red
        foreach ($candidate in $candidates) { Write-Host "  $($candidate.FullName)" }
        throw "SAFE_STOP_MULTIPLE_TARGETS: $FileName"
    }
    return $candidates[0].FullName
}

function Replace-Method([string]$Text, [string]$StartMarker, [string]$EndMarker, [string]$Replacement) {
    $start = $Text.IndexOf($StartMarker, [System.StringComparison]::Ordinal)
    if ($start -lt 0) { throw "METHOD_START_NOT_FOUND: $StartMarker" }
    $end = $Text.IndexOf($EndMarker, $start + $StartMarker.Length, [System.StringComparison]::Ordinal)
    if ($end -lt 0) { throw "METHOD_END_NOT_FOUND: $EndMarker" }
    return $Text.Substring(0, $start) + $Replacement + "`r`n`r`n" + $Text.Substring($end)
}

Write-Host '[1/6] Locating the real project files...' -ForegroundColor Yellow
$StudentPath = Find-UniqueDartFile 'student_tournaments_dialog.dart' 'class TournamentCurrentTournamentsPanel'
$ManagerPath = Find-UniqueDartFile 'tournament_manager_dialog.dart' 'class TournamentManagerDialog'
$StoragePath = Find-UniqueDartFile 'tournament_storage_service.dart' 'class TournamentStorageService'
Write-Host "STUDENT: $StudentPath" -ForegroundColor Green
Write-Host "MANAGER: $ManagerPath" -ForegroundColor Green
Write-Host "STORAGE: $StoragePath" -ForegroundColor Green

$student = Read-Utf8 $StudentPath
$manager = Read-Utf8 $ManagerPath
$storage = Read-Utf8 $StoragePath

Write-Host '[2/6] Preparing student tournament patch in memory...' -ForegroundColor Yellow

# Inside an opened tournament, owner and participant are independent roles.
$student = [regex]::Replace(
    $student,
    'onParticipate:\s*!owner\s*&&\s*!_isParticipant\(tournament\)\s*\?\s*\(\)\s*=>\s*_requestParticipation\(tournament\)\s*:\s*null,',
    "onParticipate: !_isParticipant(tournament)`r`n          ? () => _requestParticipation(tournament)`r`n          : null,"
)

$requestMethod = @'
  Future<void> _requestParticipation(Map<String, dynamic> tournament) async {
    if (_isParticipant(tournament)) return;
    final tournamentId = '${tournament['id'] ?? ''}';
    final result = await TournamentStorageService.instance.requestParticipation(
      ownerId: '${tournament['_ownerId'] ?? ''}',
      tournamentId: tournamentId,
    );
    if (!mounted) return;

    String message;
    if (result == 'joined' ||
        result == 'owner_joined' ||
        result == 'already_joined') {
      message = MakeChessLocalization.phrase(
        'Вы добавлены в турнирную таблицу',
      );
    } else if (result == 'owner_full') {
      message = MakeChessLocalization.phrase(
        'В турнире нет свободных мест',
      );
    } else if (result.startsWith('owner_rating_low|')) {
      final parts = result.split('|');
      final actual = parts.length > 1 ? parts[1] : '?';
      final required = parts.length > 2 ? parts[2] : '?';
      message =
          'Ваш рейтинг $actual ниже минимального рейтинга турнира $required. '
          'Чтобы участвовать, поднимите свой рейтинг либо снизьте '
          'ограничение по рейтингу турнира.';
    } else if (result.startsWith('owner_rating_high|')) {
      final parts = result.split('|');
      final actual = parts.length > 1 ? parts[1] : '?';
      final required = parts.length > 2 ? parts[2] : '?';
      message =
          'Ваш рейтинг $actual выше максимального рейтинга турнира $required. '
          'Чтобы участвовать, измените ограничение по рейтингу турнира.';
    } else if (result == 'owner_not_found') {
      message = MakeChessLocalization.phrase('Турнир не найден');
    } else if (result == 'not_authenticated') {
      message = 'Сначала войдите в аккаунт.';
    } else {
      message = MakeChessLocalization.phrase(
        'Заявка на участие отправлена организатору',
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: MakeChessLocalizedText(message)),
    );
    await _load();
  }
'@
$student = Replace-Method $student '  Future<void> _requestParticipation(Map<String, dynamic> tournament) async {' '  @override' $requestMethod

# Fix the card buttons in Current / My tournaments. This supports both the old
# one-button version and V7's two-button version.
$student = $student.Replace('if (!owned && !joined) ...[', 'if (!joined) ...[')

$ownedAnchor = $student.IndexOf('final owned = _isOwner(t);', [System.StringComparison]::Ordinal)
if ($ownedAnchor -lt 0) { throw 'STUDENT_BUTTON_ANCHOR_NOT_FOUND: final owned = _isOwner(t);' }
$ifCurrent = $student.IndexOf('if (current)', $ownedAnchor, [System.StringComparison]::Ordinal)
if ($ifCurrent -lt 0) { throw 'STUDENT_BUTTON_BLOCK_NOT_FOUND: if (current)' }
$closeChildren = $student.IndexOf("`n                          ],", $ifCurrent, [System.StringComparison]::Ordinal)
if ($closeChildren -lt 0) {
    $closeChildren = $student.IndexOf("`r`n                          ],", $ifCurrent, [System.StringComparison]::Ordinal)
}
if ($closeChildren -lt 0) { throw 'STUDENT_BUTTON_BLOCK_END_NOT_FOUND' }

$finalButtons = @'
if (current)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _openTournament(t),
                                    icon: const Icon(Icons.visibility_outlined),
                                    label: MakeChessLocalizedText(
                                      MakeChessLocalization.phrase(
                                        'Открыть турнир',
                                      ),
                                    ),
                                  ),
                                  if (!joined) ...[
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      onPressed: () => _requestParticipation(t),
                                      icon: const Icon(Icons.how_to_reg),
                                      label: MakeChessLocalizedText(
                                        MakeChessLocalization.phrase(
                                          'Принять участие',
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
'@
$prefixStart = $ifCurrent
$student = $student.Substring(0, $prefixStart) + $finalButtons + $student.Substring($closeChildren)

Write-Host '[3/6] Preparing owner direct-join storage patch in memory...' -ForegroundColor Yellow

$storageHelpers = @'
  int? _intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim());
  }

  int? _restrictionInt(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = _intValue(data[key]);
      if (value != null) return value;
    }
    for (final containerKey in const <String>[
      'restrictions',
      'eligibility',
      'limits',
      'participationRules',
    ]) {
      final raw = data[containerKey];
      if (raw is! Map) continue;
      final nested = Map<String, dynamic>.from(raw);
      for (final key in keys) {
        final value = _intValue(nested[key]);
        if (value != null) return value;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _currentProfile() async {
    if (_userId.isEmpty) return <String, dynamic>{};
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', _userId)
          .maybeSingle();
      return row is Map ? Map<String, dynamic>.from(row) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _profileName(Map<String, dynamic> profile) {
    final user = _client.auth.currentUser;
    for (final value in <Object?>[
      profile['nickname'],
      profile['name'],
      profile['display_name'],
      profile['full_name'],
      user?.userMetadata?['nickname'],
      user?.userMetadata?['name'],
      user?.email,
    ]) {
      final text = '${value ?? ''}'.trim();
      if (text.isNotEmpty) return text;
    }
    return 'Организатор';
  }

  Future<String> _joinOwnerDirectly(String tournamentId) async {
    final userId = _userId;
    if (userId.isEmpty) return 'not_authenticated';

    final row = await _client
        .from('makechess_tournaments_v1')
        .select('data')
        .eq('owner_id', userId)
        .eq('id', tournamentId)
        .maybeSingle();
    final raw = row?['data'];
    if (raw is! Map) return 'owner_not_found';

    final data = Map<String, dynamic>.from(raw);
    final idsRaw = data['participantIds'];
    final participantIds = idsRaw is List
        ? idsRaw.map((value) => '$value').where((id) => id.isNotEmpty).toList()
        : <String>[];

    if (participantIds.contains(userId)) return 'already_joined';

    final maxParticipants = _intValue(data['maxParticipants']) ?? 8;
    if (participantIds.length >= maxParticipants) return 'owner_full';

    Map<String, dynamic> tableData = <String, dynamic>{};
    try {
      final tableRow = await _client
          .from('makechess_tournament_tables_v1')
          .select('data')
          .eq('owner_id', userId)
          .eq('tournament_id', tournamentId)
          .maybeSingle();
      final tableRaw = tableRow?['data'];
      if (tableRaw is Map) {
        tableData = Map<String, dynamic>.from(tableRaw);
      }
    } catch (_) {
      // Main tournament record remains the source of truth.
    }

    final profile = await _currentProfile();
    final rating = _intValue(profile['rating']) ?? 1200;

    final minRating = _restrictionInt(
          data,
          const <String>[
            'minRating', 'minimumRating', 'ratingMin', 'min_rating', 'rating_min',
          ],
        ) ??
        _restrictionInt(
          tableData,
          const <String>[
            'minRating', 'minimumRating', 'ratingMin', 'min_rating', 'rating_min',
          ],
        );
    if (minRating != null && rating < minRating) {
      return 'owner_rating_low|$rating|$minRating';
    }

    final maxRating = _restrictionInt(
          data,
          const <String>[
            'maxRating', 'maximumRating', 'ratingMax', 'max_rating', 'rating_max',
          ],
        ) ??
        _restrictionInt(
          tableData,
          const <String>[
            'maxRating', 'maximumRating', 'ratingMax', 'max_rating', 'rating_max',
          ],
        );
    if (maxRating != null && rating > maxRating) {
      return 'owner_rating_high|$rating|$maxRating';
    }

    final participantName = _profileName(profile);
    participantIds.add(userId);
    final participantNamesRaw = data['participantNames'];
    final participantNames = participantNamesRaw is Map
        ? Map<String, dynamic>.from(participantNamesRaw)
        : <String, dynamic>{};
    participantNames[userId] = participantName;

    data['participantIds'] = participantIds;
    data['participantNames'] = participantNames;
    if ('${data['status'] ?? ''}' == 'draft' && participantIds.length >= 2) {
      data['status'] = 'ready';
    }

    await _client
        .from('makechess_tournaments_v1')
        .update(<String, dynamic>{
          'data': data,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('owner_id', userId)
        .eq('id', tournamentId);

    final participantsRaw = tableData['participants'];
    final participants = participantsRaw is List
        ? participantsRaw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];

    if (!participants.any((item) => '${item['id'] ?? ''}' == userId)) {
      participants.add(<String, dynamic>{
        'id': userId,
        'name': participantName,
        'rating': rating,
        'school': '${profile['school'] ?? profile['club'] ?? ''}',
        'flag': '${profile['country'] ?? profile['flag'] ?? ''}',
        'avatarUrl': '${profile['avatar_url'] ?? profile['avatarUrl'] ?? ''}',
      });
    }

    if (tableData.isEmpty) {
      tableData = <String, dynamic>{
        'name': '${data['name'] ?? 'Турнир'}',
        'type': '${data['format'] ?? data['type'] ?? ''}',
        'status': '${data['status'] ?? ''}',
        'minutes': data['minutes'] ?? 5,
        'increment': data['increment'] ?? 0,
        'rounds': data['rounds'] ?? 1,
        'maxParticipants': maxParticipants,
        'organizer': participantName,
        'results': const <String, String>{},
      };
    }
    tableData['participants'] = participants;

    await _client.from('makechess_tournament_tables_v1').upsert(
      <String, dynamic>{
        'owner_id': userId,
        'tournament_id': tournamentId,
        'data': tableData,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'owner_id,tournament_id',
    );

    return 'owner_joined';
  }

'@

if (-not $storage.Contains('Future<String> _joinOwnerDirectly(String tournamentId) async {')) {
    $requestStart = $storage.IndexOf('  Future<String> requestParticipation({', [System.StringComparison]::Ordinal)
    if ($requestStart -lt 0) { throw 'STORAGE_REQUEST_METHOD_NOT_FOUND' }
    $storage = $storage.Substring(0, $requestStart) + $storageHelpers + $storage.Substring($requestStart)
}

$newRequestParticipation = @'
  Future<String> requestParticipation({
    required String ownerId,
    required String tournamentId,
  }) async {
    final userId = _userId;
    if (userId.isEmpty) return 'not_authenticated';

    final normalizedOwnerId = ownerId.trim();
    final normalizedTournamentId = tournamentId.trim();
    if (normalizedTournamentId.isEmpty) return 'owner_not_found';

    // Creator and participant are independent roles. Explicit Join by the
    // creator adds the creator directly and never sends a message to self.
    if (normalizedOwnerId == userId) {
      return _joinOwnerDirectly(normalizedTournamentId);
    }

    final result = await _client.rpc(
      'request_makechess_tournament_participation_v1',
      params: <String, dynamic>{
        'p_owner_id': normalizedOwnerId,
        'p_tournament_id': normalizedTournamentId,
      },
    );
    return '$result';
  }
'@
$storage = Replace-Method $storage '  Future<String> requestParticipation({' '  Future<void> respondParticipationRequest({' $newRequestParticipation

Write-Host '[4/6] Removing automatic self-invitation after publishing...' -ForegroundColor Yellow
# Remove the two call sites, but leave the old helper function itself untouched.
$manager = $manager.Replace('      await _inviteOrganizerToTournament(tournament);', '      // Creator joins only by explicit action; no self-invitation.')
$manager = $manager.Replace('                                        await _inviteOrganizerToTournament(`r`n                                            updated);', '                                        // Creator joins only by explicit action; no self-invitation.')
$manager = $manager.Replace("                                        await _inviteOrganizerToTournament(`n                                            updated);", '                                        // Creator joins only by explicit action; no self-invitation.')

# More robust fallback for formatting variants at the two known call sites.
$manager = [regex]::Replace(
    $manager,
    'await\s+_inviteOrganizerToTournament\(\s*(tournament|updated)\s*\);',
    '// Creator joins only by explicit action; no self-invitation.'
)

Write-Host '[5/6] Verifying the patch before writing anything...' -ForegroundColor Yellow
if (-not $student.Contains("if (!joined) ...[")) { throw 'VERIFY_STUDENT_JOIN_BUTTON_FAILED' }
if (-not $student.Contains("onParticipate: !_isParticipant(tournament)")) { throw 'VERIFY_OWNER_OPEN_TOURNAMENT_JOIN_FAILED' }
if (-not $student.Contains("result == 'owner_joined'")) { throw 'VERIFY_OWNER_RESULT_UI_FAILED' }
if (-not $storage.Contains('Future<String> _joinOwnerDirectly(String tournamentId) async {')) { throw 'VERIFY_DIRECT_JOIN_METHOD_FAILED' }
if (-not $storage.Contains('if (normalizedOwnerId == userId)')) { throw 'VERIFY_OWNER_ROUTING_FAILED' }
if ($manager -match 'await\s+_inviteOrganizerToTournament\(') { throw 'VERIFY_SELF_INVITE_CALL_REMAINS' }

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $Root "_backup_tournament_owner_join_v9_$stamp"
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $StudentPath -Destination (Join-Path $backup 'student_tournaments_dialog.dart') -Force
Copy-Item -LiteralPath $ManagerPath -Destination (Join-Path $backup 'tournament_manager_dialog.dart') -Force
Copy-Item -LiteralPath $StoragePath -Destination (Join-Path $backup 'tournament_storage_service.dart') -Force
Write-Host "BACKUP_OK: $backup" -ForegroundColor Green

Write-Host '[6/6] Writing the three patched files...' -ForegroundColor Yellow
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
try {
    [System.IO.File]::WriteAllText($StudentPath, $student, $utf8NoBom)
    [System.IO.File]::WriteAllText($ManagerPath, $manager, $utf8NoBom)
    [System.IO.File]::WriteAllText($StoragePath, $storage, $utf8NoBom)
} catch {
    Copy-Item -LiteralPath (Join-Path $backup 'student_tournaments_dialog.dart') -Destination $StudentPath -Force
    Copy-Item -LiteralPath (Join-Path $backup 'tournament_manager_dialog.dart') -Destination $ManagerPath -Force
    Copy-Item -LiteralPath (Join-Path $backup 'tournament_storage_service.dart') -Destination $StoragePath -Force
    throw
}

Write-Host ''
Write-Host '==========================================================' -ForegroundColor Green
Write-Host 'TOURNAMENT_OWNER_JOIN_V9_OK' -ForegroundColor Green
Write-Host '==========================================================' -ForegroundColor Green
Write-Host 'Creator can now:'
Write-Host '  1. Open own tournament without joining it.'
Write-Host '  2. Press Join separately.'
Write-Host '  3. Join directly without receiving a self-invitation.'
Write-Host '  4. Be rejected by capacity / stored rating limits like a player.'
Write-Host ''
Write-Host 'Other users keep the existing request-to-organizer flow.'
Write-Host 'DO NOT publish yet. Send this full window to ChatGPT.' -ForegroundColor Yellow
