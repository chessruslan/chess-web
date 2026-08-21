param(
  [string]$ProjectRoot = "C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$msgRel = 'lib\ui\messages\general_messages_dialog.dart'
$locRel = 'lib\localization\makechess_localization.dart'
$msgPath = Join-Path $ProjectRoot $msgRel
$locPath = Join-Path $ProjectRoot $locRel

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " MAKECHESS - ADMIN RECIPIENT LABEL V8.6.1" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

foreach ($path in @($msgPath,$locPath)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "SAFETY STOP: missing file: $path"
  }
}

$msg = [IO.File]::ReadAllText($msgPath)
$loc = [IO.File]::ReadAllText($locPath)

Write-Host "[1/6] Checking current V8.6 Messages structure..." -ForegroundColor Cyan
foreach ($marker in @(
  'MAKECHESS_GENERAL_MESSAGES_COMPOSER_V8_6_20260808',
  'Widget _recipientSearchZone()',
  'Widget _composeZone()',
  '_administrationRecipient',
  '_recipientMode = key;',
  '_recipientSearch.clear();'
)) {
  if (-not $msg.Contains($marker)) {
    throw "SAFETY STOP: current general_messages_dialog.dart is not compatible: $marker"
  }
}

if ($msg.Contains('MAKECHESS_ADMIN_RECIPIENT_LABEL_V8_6_1_20260808') -and
    $loc.Contains('MAKECHESS_ADMIN_RECIPIENT_LABEL_V8_6_1_TRANSLATIONS_20260808')) {
  Write-Host "ALREADY INSTALLED: V8.6.1" -ForegroundColor Green
  exit 0
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $ProjectRoot "localization_backups\ADMIN_RECIPIENT_LABEL_V8_6_1_$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

Write-Host "[2/6] Creating exact backups..." -ForegroundColor Cyan
foreach ($rel in @($msgRel,$locRel)) {
  $src = Join-Path $ProjectRoot $rel
  $dst = Join-Path $backupDir $rel
  New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
  Copy-Item -LiteralPath $src -Destination $dst -Force
}

try {
  Write-Host "[3/6] Patching ONLY recipient selection behavior..." -ForegroundColor Cyan

  $old = @"
        onSelected: (_) {
          setState(() {
            _recipientMode = key;
            _recipientSearch.clear();
          });
        },
"@

  $new = @"
        onSelected: (_) {
          setState(() {
            _recipientMode = key;
            _recipientSearch.clear();
            _replySource = null;

            // MAKECHESS_ADMIN_RECIPIENT_LABEL_V8_6_1_20260808
            // Switching a recipient category must never leave the old
            // recipient in the "Кому" field.
            if (key == 'administration') {
              final administration = _administrationRecipient;
              _selectedRecipient = _GeneralMessageRecipient(
                id: administration?.id ?? '',
                name: MakeChessLocalization.phrase('Администратор'),
                kind: 'administration',
                subtitle: administration?.subtitle ??
                    MakeChessLocalization.phrase(
                      'Сообщение будет направлено администрации',
                    ),
              );
            } else {
              _selectedRecipient = null;
            }
          });
        },
"@

  if (-not $msg.Contains($old)) {
    throw "SAFETY STOP: exact V8.6 mode switch block was not found. Nothing changed."
  }

  $msg = $msg.Replace($old, $new)

  # Every admin recipient shown in the main Messages composer must be singular.
  $msg = $msg.Replace(
    "name: MakeChessLocalization.phrase('Администрация MakeChess'),",
    "name: MakeChessLocalization.phrase('Администратор'),"
  )
  $msg = $msg.Replace(
    "? MakeChessLocalization.phrase('Администрация MakeChess')",
    "? MakeChessLocalization.phrase('Администратор')"
  )

  [IO.File]::WriteAllText(
    $msgPath,
    $msg,
    [Text.UTF8Encoding]::new($false)
  )

  Write-Host "[4/6] Adding 'Администратор' to central localization (11 languages)..." -ForegroundColor Cyan
  $loc = [IO.File]::ReadAllText($locPath)
  $block = [IO.File]::ReadAllText(
    (Join-Path $PackageRoot 'LOCALIZATION_V8_6_1_BLOCK.txt')
  ).Trim([char]0xFEFF)
  $lookup = [IO.File]::ReadAllText(
    (Join-Path $PackageRoot 'LOCALIZATION_V8_6_1_LOOKUP.txt')
  ).Trim([char]0xFEFF)

  if (-not $loc.Contains('MAKECHESS_ADMIN_RECIPIENT_LABEL_V8_6_1_TRANSLATIONS_20260808')) {
    $anchor = '  static String normalizeLanguageCode'
    $idx = $loc.IndexOf($anchor, [StringComparison]::Ordinal)
    if ($idx -lt 0) { throw "Localization insertion anchor not found." }
    $loc = $loc.Substring(0,$idx) +
      $block.TrimEnd() + "`r`n`r`n" +
      $loc.Substring($idx)
  }

  if (-not $loc.Contains('final v861AdminRecipientRow = _v861AdminRecipientRows[source];')) {
    $method = '  static String? _v5ExactPhrase(String source, String code) {'
    $idx = $loc.IndexOf($method, [StringComparison]::Ordinal)
    if ($idx -lt 0) { throw "Localization lookup anchor not found." }
    $insertAt = $idx + $method.Length
    $loc = $loc.Substring(0,$insertAt) +
      "`r`n" + $lookup.TrimEnd() + "`r`n" +
      $loc.Substring($insertAt)
  }

  [IO.File]::WriteAllText(
    $locPath,
    $loc,
    [Text.UTF8Encoding]::new($false)
  )

  Write-Host "[5/6] Running Dart formatter / parser..." -ForegroundColor Cyan
  $dart = Get-Command dart -ErrorAction SilentlyContinue
  if ($null -ne $dart) {
    & $dart.Source format $msgPath $locPath | Out-Host
    if ($LASTEXITCODE -ne 0) {
      throw "dart format reported a syntax error."
    }
  }

  Write-Host "[6/6] Verifying surgical change..." -ForegroundColor Cyan
  $msgCheck = [IO.File]::ReadAllText($msgPath)
  $locCheck = [IO.File]::ReadAllText($locPath)

  foreach ($marker in @(
    'MAKECHESS_ADMIN_RECIPIENT_LABEL_V8_6_1_20260808',
    "if (key == 'administration')",
    "name: MakeChessLocalization.phrase('Администратор')",
    'Future<void> _acceptTournamentInvitation',
    '_previewTournament(message)',
    '_openTournamentPlatform(message)',
    'respondParticipationRequest('
  )) {
    if (-not $msgCheck.Contains($marker)) {
      throw "Verification failed: $marker"
    }
  }

  foreach ($marker in @(
    'MAKECHESS_ADMIN_RECIPIENT_LABEL_V8_6_1_TRANSLATIONS_20260808',
    'final v861AdminRecipientRow = _v861AdminRecipientRows[source];'
  )) {
    if (-not $locCheck.Contains($marker)) {
      throw "Localization verification failed: $marker"
    }
  }
}
catch {
  Write-Host ""
  Write-Host "ERROR: restoring exact pre-V8.6.1 files..." -ForegroundColor Red
  foreach ($rel in @($msgRel,$locRel)) {
    $src = Join-Path $backupDir $rel
    $dst = Join-Path $ProjectRoot $rel
    if (Test-Path -LiteralPath $src) {
      Copy-Item -LiteralPath $src -Destination $dst -Force
    }
  }
  throw
}

Write-Host ""
Write-Host "DONE: ADMIN RECIPIENT LABEL V8.6.1 installed." -ForegroundColor Green
Write-Host "Only recipient selection/label + one localized phrase were changed." -ForegroundColor Green
Write-Host "Tournament mechanics were not changed." -ForegroundColor Green
Write-Host "No publication was performed." -ForegroundColor Green
Write-Host ""
