param(
  [string]$ProjectRoot = "C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PayloadRoot = Join-Path $PackageRoot "payload"

$targets = @(
  @{ Rel='lib\ui\dialogs\site_settings_dialog.dart'; Old='e28a3d489e581b4541f7cbf1ecfd832e2469aa596c49bf04ce938af42a844acf'; New='7e9a0d9fee583339acdc6e11fc04cb254efd94e38609968d51c4f46c85d90367' },
  @{ Rel='lib\ui\messages\general_messages_dialog.dart'; Old='4363e81f927a4a784cddd7ce9b9c81267bb92b3994038cf67fd94add7f72a91f'; New='595a72b3919a911a35429342948063452f335e13b1d64dad4e3837b4d0af78d5' },
  @{ Rel='lib\localization\makechess_localization.dart'; Old='d7454b07c1aa51af031cad1ff1be4e81ef114897c07eacf9b856b586e09910a2'; New='61dd4b2089a781a646be8f4757c066a1f1da85b5c6b23cdb53bd054c14293f96' }
)
$moduleRel = 'lib\ui\dialogs\admin_management_panel.dart'
$moduleSource = Join-Path $PayloadRoot $moduleRel
$moduleTarget = Join-Path $ProjectRoot $moduleRel
$moduleNew = 'cb3c10029ab238dc522112c9d1d9757b34f0cddee43987125e286d0bf7a0e157'

function Get-Sha256([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " MAKECHESS - ADMIN CASES + ARCHIVE V8.1" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

foreach ($item in $targets) {
  $source = Join-Path $PayloadRoot $item.Rel
  $target = Join-Path $ProjectRoot $item.Rel
  if (-not (Test-Path -LiteralPath $source)) { throw "PACKAGE ERROR: missing $($item.Rel)" }
  if (-not (Test-Path -LiteralPath $target)) { throw "SAFETY STOP: missing current $($item.Rel). Nothing changed." }
  if ((Get-Sha256 $source) -ne $item.New) { throw "PACKAGE ERROR: hash mismatch $($item.Rel)" }
}
if (-not (Test-Path -LiteralPath $moduleSource)) { throw "PACKAGE ERROR: admin module missing" }
if ((Get-Sha256 $moduleSource) -ne $moduleNew) { throw "PACKAGE ERROR: admin module hash mismatch" }

# Idempotent check first. Dart format may change hashes, so markers are the reliable rerun test.
$siteText = [IO.File]::ReadAllText((Join-Path $ProjectRoot 'lib\ui\dialogs\site_settings_dialog.dart'))
$msgText = [IO.File]::ReadAllText((Join-Path $ProjectRoot 'lib\ui\messages\general_messages_dialog.dart'))
$locText = [IO.File]::ReadAllText((Join-Path $ProjectRoot 'lib\localization\makechess_localization.dart'))
$moduleText = if (Test-Path -LiteralPath $moduleTarget) { [IO.File]::ReadAllText($moduleTarget) } else { '' }
if ($siteText.Contains('MAKECHESS_ADMIN_CASES_V8_1_20260808') -and
    $msgText.Contains('MAKECHESS_ADMIN_CASE_REPLIES_V8_1_20260808') -and
    $locText.Contains('MAKECHESS_ADMIN_CASES_V8_1_TRANSLATIONS_20260808') -and
    $moduleText.Contains('MAKECHESS_ADMIN_CASES_V8_1_20260808')) {
  Write-Host "ALREADY INSTALLED: ADMIN CASES + ARCHIVE V8.1" -ForegroundColor Green
  exit 0
}

Write-Host "[1/7] Checking exact current V6/V7 files..." -ForegroundColor Cyan
foreach ($item in $targets) {
  $target = Join-Path $ProjectRoot $item.Rel
  $current = Get-Sha256 $target
  if ($current -ne $item.Old) {
    throw "SAFETY STOP: $($item.Rel) is not the exact current file used for V8.1. Nothing changed."
  }
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $ProjectRoot "localization_backups\ADMIN_CASES_V8_1_$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

Write-Host "[2/7] Creating exact backups..." -ForegroundColor Cyan
foreach ($item in $targets) {
  $src = Join-Path $ProjectRoot $item.Rel
  $dst = Join-Path $backupDir $item.Rel
  New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
  Copy-Item -LiteralPath $src -Destination $dst -Force
}
$moduleExisted = Test-Path -LiteralPath $moduleTarget
if ($moduleExisted) {
  $dst = Join-Path $backupDir $moduleRel
  New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
  Copy-Item -LiteralPath $moduleTarget -Destination $dst -Force
}

try {
  Write-Host "[3/7] Installing corrected V8.1 files..." -ForegroundColor Cyan
  foreach ($item in $targets) {
    Copy-Item -LiteralPath (Join-Path $PayloadRoot $item.Rel) -Destination (Join-Path $ProjectRoot $item.Rel) -Force
  }
  New-Item -ItemType Directory -Path (Split-Path -Parent $moduleTarget) -Force | Out-Null
  Copy-Item -LiteralPath $moduleSource -Destination $moduleTarget -Force

  Write-Host "[4/7] Checking corrected Messages architecture..." -ForegroundColor Cyan
  $msg = [IO.File]::ReadAllText((Join-Path $ProjectRoot 'lib\ui\messages\general_messages_dialog.dart'))
  foreach ($marker in @(
    'MAKECHESS_ADMIN_CASE_REPLIES_V8_1_20260808',
    "final Map<String, dynamic> metadata;",
    "'payload': metadata",
    'syncFromDatabase',
    'admin_case_reply',
    'Сообщить, что исправлено'
  )) {
    if (-not $msg.Contains($marker)) { throw "V8.1 Messages verification failed: $marker" }
  }
  if ($msg.Contains('Future<void> syncMakeChessMessagesFromDatabase()')) {
    throw 'V8.1 verification failed: obsolete syncMakeChessMessagesFromDatabase architecture returned.'
  }

  Write-Host "[5/7] Running Dart parser / formatter..." -ForegroundColor Cyan
  $dart = Get-Command dart -ErrorAction SilentlyContinue
  if ($null -ne $dart) {
    & $dart.Source format `
      (Join-Path $ProjectRoot 'lib\ui\dialogs\admin_management_panel.dart') `
      (Join-Path $ProjectRoot 'lib\ui\dialogs\site_settings_dialog.dart') `
      (Join-Path $ProjectRoot 'lib\ui\messages\general_messages_dialog.dart') `
      (Join-Path $ProjectRoot 'lib\localization\makechess_localization.dart') | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'dart format reported a Dart syntax error.' }
  } else {
    Write-Host 'Dart is not in PATH. PUBLISH_MAKECHESS.cmd will perform final compilation.' -ForegroundColor Yellow
  }

  Write-Host "[6/7] Checking admin rules and archive..." -ForegroundColor Cyan
  $site = [IO.File]::ReadAllText((Join-Path $ProjectRoot 'lib\ui\dialogs\site_settings_dialog.dart'))
  $module = [IO.File]::ReadAllText($moduleTarget)
  foreach ($marker in @(
    'AdminManagementPanel(kind: AdminEntityKind.player)',
    'AdminManagementPanel(kind: AdminEntityKind.school)',
    'AdminManagementPanel(kind: AdminEntityKind.teacher)',
    'AdminManagementPanel(kind: AdminEntityKind.tournament)',
    'AdminArchivePanel()'
  )) { if (-not $site.Contains($marker)) { throw "V8.1 Site Settings verification failed: $marker" } }
  foreach ($marker in @(
    'MAKECHESS_ADMIN_CASES_V8_1_20260808',
    'Сообщение обязательно для любого административного действия',
    "_performAction('warning')",
    "_performAction('restriction')",
    "_performAction('block')",
    'Срок истёк — требуется решение администратора',
    'MakeChessMessageRealtimeService.instance.syncFromDatabase()',
    'Пользователи',
    'Партии',
    'Турниры',
    'Школы / Учителя'
  )) { if (-not $module.Contains($marker)) { throw "V8.1 admin-module verification failed: $marker" } }

  Write-Host "[7/7] Checking all 11 language translations..." -ForegroundColor Cyan
  $loc = [IO.File]::ReadAllText((Join-Path $ProjectRoot 'lib\localization\makechess_localization.dart'))
  foreach ($marker in @(
    'MAKECHESS_ADMIN_CASES_V8_1_TRANSLATIONS_20260808',
    '_v8AdminPhraseRows',
    'Административное действие',
    'MakeChess уважает ваше право знать причину',
    'Школы / Учителя'
  )) { if (-not $loc.Contains($marker)) { throw "V8.1 localization verification failed: $marker" } }
  foreach ($code in @('RU','EN','DE','FR','ES','AR','ZH','HI','JA','KO','VI')) {
    if (-not $loc.Contains("'$code'")) { throw "V8.1 localization check failed: $code" }
  }
}
catch {
  Write-Host ""
  Write-Host "ERROR: restoring exact files from the V8.1 backup..." -ForegroundColor Red
  foreach ($item in $targets) {
    $backup = Join-Path $backupDir $item.Rel
    $target = Join-Path $ProjectRoot $item.Rel
    if (Test-Path -LiteralPath $backup) { Copy-Item -LiteralPath $backup -Destination $target -Force }
  }
  if ($moduleExisted) {
    $backup = Join-Path $backupDir $moduleRel
    if (Test-Path -LiteralPath $backup) { Copy-Item -LiteralPath $backup -Destination $moduleTarget -Force }
  } elseif (Test-Path -LiteralPath $moduleTarget) {
    Remove-Item -LiteralPath $moduleTarget -Force
  }
  throw
}

Write-Host ""
Write-Host "DONE: ADMIN CASES + ARCHIVE V8.1 installed." -ForegroundColor Green
Write-Host "Corrected for the current makechess_messages_v1 architecture." -ForegroundColor Green
Write-Host "Warning timer is reminder only; no automatic blocking." -ForegroundColor Green
Write-Host "Languages: RU EN DE FR ES AR ZH HI JA KO VI" -ForegroundColor Green
Write-Host "Backup: $backupDir"
Write-Host ""
Write-Host "Next command after DONE:"
Write-Host "  .\PUBLISH_MAKECHESS.cmd"
