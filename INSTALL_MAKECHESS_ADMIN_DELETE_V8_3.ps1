param(
  [string]$ProjectRoot = "C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
)
$ErrorActionPreference = "Stop"
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PayloadRoot = Join-Path $PackageRoot "payload"

$moduleRel = 'lib\ui\dialogs\admin_management_panel.dart'
$msgRel = 'lib\ui\messages\general_messages_dialog.dart'
$locRel = 'lib\localization\makechess_localization.dart'

$moduleTarget = Join-Path $ProjectRoot $moduleRel
$msgTarget = Join-Path $ProjectRoot $msgRel
$locTarget = Join-Path $ProjectRoot $locRel
$moduleSource = Join-Path $PayloadRoot $moduleRel
$msgSource = Join-Path $PayloadRoot $msgRel
$locBlockPath = Join-Path $PackageRoot 'LOCALIZATION_ADMIN_DELETE_V8_3_BLOCK.txt'
$locLookupPath = Join-Path $PackageRoot 'LOCALIZATION_ADMIN_DELETE_V8_3_LOOKUP.txt'

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " MAKECHESS - ADMIN DELETE V8.3" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

foreach ($path in @($moduleTarget,$msgTarget,$locTarget,$moduleSource,$msgSource,$locBlockPath,$locLookupPath)) {
  if (-not (Test-Path -LiteralPath $path)) { throw "SAFETY STOP: missing file: $path" }
}

$moduleCurrent = [IO.File]::ReadAllText($moduleTarget)
$msgCurrent = [IO.File]::ReadAllText($msgTarget)
$locCurrent = [IO.File]::ReadAllText($locTarget)

if ($moduleCurrent.Contains('MAKECHESS_ADMIN_DELETE_V8_3_20260808') -and
    $msgCurrent.Contains('MAKECHESS_ADMIN_DELETE_MESSAGES_V8_3_20260808') -and
    $locCurrent.Contains('MAKECHESS_ADMIN_DELETE_V8_3_TRANSLATIONS_20260808') -and
    $locCurrent.Contains('final v8DeleteRow = _v8DeletePhraseRows[source];')) {
  Write-Host "ALREADY INSTALLED: ADMIN DELETE V8.3" -ForegroundColor Green
  exit 0
}

Write-Host "[1/6] Checking installed V8.2 structure..." -ForegroundColor Cyan
foreach ($marker in @(
  'MAKECHESS_ADMIN_CASES_V8_1_20260808',
  "Future<void> _performAction(String action)",
  "class AdminArchivePanel extends StatefulWidget"
)) {
  if (-not $moduleCurrent.Contains($marker)) {
    throw "SAFETY STOP: current admin module is not the installed V8.2 module: $marker"
  }
}
foreach ($marker in @(
  'MAKECHESS_ADMIN_CASE_REPLIES_V8_1_20260808',
  "message.category == 'admin_restriction'"
)) {
  if (-not $msgCurrent.Contains($marker)) {
    throw "SAFETY STOP: current messages file is not V8.2-compatible: $marker"
  }
}
foreach ($marker in @(
  'MAKECHESS_ADMIN_CASES_V8_1_TRANSLATIONS_20260808',
  'MAKECHESS_TOURNAMENT_UI_LOCALIZATION_V7_20260807',
  'static String? _v5ExactPhrase(String source, String code)',
  'static String normalizeLanguageCode'
)) {
  if (-not $locCurrent.Contains($marker)) {
    throw "SAFETY STOP: current localization is not V8.2/V7-compatible: $marker"
  }
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $ProjectRoot "localization_backups\ADMIN_DELETE_V8_3_$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

Write-Host "[2/6] Creating backups..." -ForegroundColor Cyan
foreach ($rel in @($moduleRel,$msgRel,$locRel)) {
  $src = Join-Path $ProjectRoot $rel
  $dst = Join-Path $backupDir $rel
  New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
  Copy-Item -LiteralPath $src -Destination $dst -Force
}

try {
  Write-Host "[3/6] Installing DELETE action and archive deletion..." -ForegroundColor Cyan
  Copy-Item -LiteralPath $moduleSource -Destination $moduleTarget -Force
  Copy-Item -LiteralPath $msgSource -Destination $msgTarget -Force

  Write-Host "[4/6] Adding translations to CURRENT localization..." -ForegroundColor Cyan
  $loc = [IO.File]::ReadAllText($locTarget)
  $block = [IO.File]::ReadAllText($locBlockPath).Trim([char]0xFEFF)
  $lookup = [IO.File]::ReadAllText($locLookupPath).Trim([char]0xFEFF)

  if (-not $loc.Contains('MAKECHESS_ADMIN_DELETE_V8_3_TRANSLATIONS_20260808')) {
    $anchor = '  static String normalizeLanguageCode'
    $idx = $loc.IndexOf($anchor, [StringComparison]::Ordinal)
    if ($idx -lt 0) { throw "Localization insertion anchor not found." }
    $loc = $loc.Substring(0,$idx) + $block.TrimEnd() + "`r`n`r`n" + $loc.Substring($idx)
  }

  if (-not $loc.Contains('final v8DeleteRow = _v8DeletePhraseRows[source];')) {
    $method = '  static String? _v5ExactPhrase(String source, String code) {'
    $idx = $loc.IndexOf($method, [StringComparison]::Ordinal)
    if ($idx -lt 0) { throw "Localization lookup anchor not found." }
    $insertAt = $idx + $method.Length
    $loc = $loc.Substring(0,$insertAt) + "`r`n" + $lookup.TrimEnd() + "`r`n" + $loc.Substring($insertAt)
  }

  [IO.File]::WriteAllText($locTarget, $loc, [Text.UTF8Encoding]::new($false))

  Write-Host "[5/6] Running Dart parser / formatter..." -ForegroundColor Cyan
  $dart = Get-Command dart -ErrorAction SilentlyContinue
  if ($null -ne $dart) {
    & $dart.Source format $moduleTarget $msgTarget $locTarget | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "dart format reported a Dart syntax error." }
  } else {
    Write-Host "Dart is not in PATH. Final parser check will happen during Flutter build." -ForegroundColor Yellow
  }

  Write-Host "[6/6] Verifying DELETE mechanics..." -ForegroundColor Cyan
  $module = [IO.File]::ReadAllText($moduleTarget)
  $msg = [IO.File]::ReadAllText($msgTarget)
  $loc = [IO.File]::ReadAllText($locTarget)

  foreach ($marker in @(
    'MAKECHESS_ADMIN_DELETE_V8_3_20260808',
    'Future<void> _confirmDeleteTarget()',
    "await TournamentStorageService.instance.deleteTournament(target.id);",
    'makechess_admin_deleted_targets_v1',
    'Удаление невозможно без сообщения с причиной',
    'Удалить запись из архива',
    'deleteCase(String caseId)'
  )) {
    if (-not $module.Contains($marker)) { throw "Admin delete verification failed: $marker" }
  }
  foreach ($marker in @(
    'MAKECHESS_ADMIN_DELETE_MESSAGES_V8_3_20260808',
    "message.category == 'admin_delete'"
  )) {
    if (-not $msg.Contains($marker)) { throw "Messages verification failed: $marker" }
  }
  foreach ($marker in @(
    'MAKECHESS_ADMIN_DELETE_V8_3_TRANSLATIONS_20260808',
    'final v8DeleteRow = _v8DeletePhraseRows[source];'
  )) {
    if (-not $loc.Contains($marker)) { throw "Localization verification failed: $marker" }
  }
}
catch {
  Write-Host ""
  Write-Host "ERROR: restoring exact files from V8.3 backup..." -ForegroundColor Red
  foreach ($rel in @($moduleRel,$msgRel,$locRel)) {
    $src = Join-Path $backupDir $rel
    $dst = Join-Path $ProjectRoot $rel
    if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination $dst -Force }
  }
  throw
}

Write-Host ""
Write-Host "DONE: ADMIN DELETE V8.3 installed." -ForegroundColor Green
Write-Host "No publication was performed." -ForegroundColor Green
Write-Host ""
