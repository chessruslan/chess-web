param(
  [string]$ProjectRoot = "C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PayloadRoot = Join-Path $PackageRoot "payload"

$siteRel = 'lib\ui\dialogs\site_settings_dialog.dart'
$msgRel = 'lib\ui\messages\general_messages_dialog.dart'
$locRel = 'lib\localization\makechess_localization.dart'
$moduleRel = 'lib\ui\dialogs\admin_management_panel.dart'

$siteTarget = Join-Path $ProjectRoot $siteRel
$msgTarget = Join-Path $ProjectRoot $msgRel
$locTarget = Join-Path $ProjectRoot $locRel
$moduleTarget = Join-Path $ProjectRoot $moduleRel

$siteSource = Join-Path $PayloadRoot $siteRel
$msgSource = Join-Path $PayloadRoot $msgRel
$moduleSource = Join-Path $PayloadRoot $moduleRel
$locBlockPath = Join-Path $PackageRoot 'LOCALIZATION_ADMIN_V8_2_BLOCK.txt'
$locLookupPath = Join-Path $PackageRoot 'LOCALIZATION_ADMIN_V8_2_LOOKUP.txt'

function Get-Sha256([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " MAKECHESS - ADMIN CASES + ARCHIVE V8.2" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

foreach ($path in @($siteTarget,$msgTarget,$locTarget,$siteSource,$msgSource,$moduleSource,$locBlockPath,$locLookupPath)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "SAFETY STOP: missing file: $path"
  }
}

# Exact safety remains for the two files that V8.1 already verified on this project.
if ((Get-Sha256 $siteSource) -ne '7e9a0d9fee583339acdc6e11fc04cb254efd94e38609968d51c4f46c85d90367') { throw "PACKAGE ERROR: site payload hash mismatch." }
if ((Get-Sha256 $msgSource) -ne '595a72b3919a911a35429342948063452f335e13b1d64dad4e3837b4d0af78d5') { throw "PACKAGE ERROR: messages payload hash mismatch." }
if ((Get-Sha256 $moduleSource) -ne 'cb3c10029ab238dc522112c9d1d9757b34f0cddee43987125e286d0bf7a0e157') { throw "PACKAGE ERROR: module payload hash mismatch." }

$siteText = [IO.File]::ReadAllText($siteTarget)
$msgText = [IO.File]::ReadAllText($msgTarget)
$locText = [IO.File]::ReadAllText($locTarget)
$moduleText = if (Test-Path -LiteralPath $moduleTarget) { [IO.File]::ReadAllText($moduleTarget) } else { '' }

if ($siteText.Contains('MAKECHESS_ADMIN_CASES_V8_1_20260808') -and
    $msgText.Contains('MAKECHESS_ADMIN_CASE_REPLIES_V8_1_20260808') -and
    $locText.Contains('MAKECHESS_ADMIN_CASES_V8_1_TRANSLATIONS_20260808') -and
    $locText.Contains('final v8AdminRow = _v8AdminPhraseRows[source];') -and
    $moduleText.Contains('MAKECHESS_ADMIN_CASES_V8_1_20260808')) {
  Write-Host "ALREADY INSTALLED: ADMIN CASES + ARCHIVE V8.2" -ForegroundColor Green
  exit 0
}

Write-Host "[1/7] Checking current files..." -ForegroundColor Cyan

# V8.1 already proved these exact two current files matched before it stopped on localization.
if ((Get-Sha256 $siteTarget) -ne 'e28a3d489e581b4541f7cbf1ecfd832e2469aa596c49bf04ce938af42a844acf') {
  throw "SAFETY STOP: site_settings_dialog.dart changed after the V8.1 attempt. Nothing changed."
}
if ((Get-Sha256 $msgTarget) -ne '4363e81f927a4a784cddd7ce9b9c81267bb92b3994038cf67fd94add7f72a91f') {
  throw "SAFETY STOP: general_messages_dialog.dart changed after the V8.1 attempt. Nothing changed."
}

# IMPORTANT V8.2 FIX:
# Do NOT compare localization by SHA256. Previous localization installers run
# dart format, so an equivalent current V7 file can have a different byte hash.
# Verify its semantic structure and patch only the new V8 translation block.
foreach ($marker in @(
  'MAKECHESS_REMAINING_UI_LOCALIZATION_V6_20260807',
  'MAKECHESS_TOURNAMENT_UI_LOCALIZATION_V7_20260807',
  'static String? _v5ExactPhrase(String source, String code)',
  'static String normalizeLanguageCode'
)) {
  if (-not $locText.Contains($marker)) {
    throw "SAFETY STOP: current localization structure is not compatible: $marker"
  }
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $ProjectRoot "localization_backups\ADMIN_CASES_V8_2_$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

Write-Host "[2/7] Creating exact backups..." -ForegroundColor Cyan
foreach ($rel in @($siteRel,$msgRel,$locRel)) {
  $src = Join-Path $ProjectRoot $rel
  $dst = Join-Path $backupDir $rel
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
  Write-Host "[3/7] Installing admin panel and Messages..." -ForegroundColor Cyan
  Copy-Item -LiteralPath $siteSource -Destination $siteTarget -Force
  Copy-Item -LiteralPath $msgSource -Destination $msgTarget -Force
  New-Item -ItemType Directory -Path (Split-Path -Parent $moduleTarget) -Force | Out-Null
  Copy-Item -LiteralPath $moduleSource -Destination $moduleTarget -Force

  Write-Host "[4/7] Adding translations to CURRENT localization file..." -ForegroundColor Cyan
  $loc = [IO.File]::ReadAllText($locTarget)
  $block = [IO.File]::ReadAllText($locBlockPath).Trim([char]0xFEFF)
  $lookup = [IO.File]::ReadAllText($locLookupPath).Trim([char]0xFEFF)

  if (-not $loc.Contains('MAKECHESS_ADMIN_CASES_V8_1_TRANSLATIONS_20260808')) {
    $anchor = '  static String normalizeLanguageCode'
    $idx = $loc.IndexOf($anchor, [StringComparison]::Ordinal)
    if ($idx -lt 0) { throw "Localization insertion anchor not found." }
    $loc = $loc.Substring(0,$idx) + $block.TrimEnd() + "`r`n`r`n" + $loc.Substring($idx)
  }

  if (-not $loc.Contains('final v8AdminRow = _v8AdminPhraseRows[source];')) {
    $method = '  static String? _v5ExactPhrase(String source, String code) {'
    $idx = $loc.IndexOf($method, [StringComparison]::Ordinal)
    if ($idx -lt 0) { throw "Localization lookup anchor not found." }
    $insertAt = $idx + $method.Length
    $loc = $loc.Substring(0,$insertAt) + "`r`n" + $lookup.TrimEnd() + "`r`n" + $loc.Substring($insertAt)
  }

  [IO.File]::WriteAllText($locTarget, $loc, [Text.UTF8Encoding]::new($false))

  Write-Host "[5/7] Running Dart parser / formatter..." -ForegroundColor Cyan
  $dart = Get-Command dart -ErrorAction SilentlyContinue
  if ($null -ne $dart) {
    & $dart.Source format $moduleTarget $siteTarget $msgTarget $locTarget | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "dart format reported a Dart syntax error." }
  } else {
    Write-Host "Dart is not in PATH. Final parser check will happen during Flutter build." -ForegroundColor Yellow
  }

  Write-Host "[6/7] Verifying admin mechanics and localization..." -ForegroundColor Cyan
  $site = [IO.File]::ReadAllText($siteTarget)
  $msg = [IO.File]::ReadAllText($msgTarget)
  $loc = [IO.File]::ReadAllText($locTarget)
  $module = [IO.File]::ReadAllText($moduleTarget)

  foreach ($marker in @(
    'AdminManagementPanel(kind: AdminEntityKind.player)',
    'AdminManagementPanel(kind: AdminEntityKind.school)',
    'AdminManagementPanel(kind: AdminEntityKind.teacher)',
    'AdminManagementPanel(kind: AdminEntityKind.tournament)',
    'AdminArchivePanel()'
  )) { if (-not $site.Contains($marker)) { throw "Site verification failed: $marker" } }

  foreach ($marker in @(
    'MAKECHESS_ADMIN_CASE_REPLIES_V8_1_20260808',
    'syncFromDatabase',
    'admin_case_reply',
    'Сообщить, что исправлено'
  )) { if (-not $msg.Contains($marker)) { throw "Messages verification failed: $marker" } }

  foreach ($marker in @(
    'MAKECHESS_ADMIN_CASES_V8_1_TRANSLATIONS_20260808',
    'final v8AdminRow = _v8AdminPhraseRows[source];',
    'MAKECHESS_TOURNAMENT_UI_LOCALIZATION_V7_20260807'
  )) { if (-not $loc.Contains($marker)) { throw "Localization verification failed: $marker" } }

  foreach ($marker in @(
    'Сообщение обязательно для любого административного действия',
    "_performAction('warning')",
    "_performAction('block')",
    'Срок истёк — требуется решение администратора',
    'История и ответ пользователя'
  )) { if (-not $module.Contains($marker)) { throw "Admin module verification failed: $marker" } }

  Write-Host "[7/7] Done." -ForegroundColor Cyan
}
catch {
  Write-Host ""
  Write-Host "ERROR: restoring exact files from the V8.2 backup..." -ForegroundColor Red
  foreach ($rel in @($siteRel,$msgRel,$locRel)) {
    $src = Join-Path $backupDir $rel
    $dst = Join-Path $ProjectRoot $rel
    if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination $dst -Force }
  }
  if ($moduleExisted) {
    $src = Join-Path $backupDir $moduleRel
    if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination $moduleTarget -Force }
  } elseif (Test-Path -LiteralPath $moduleTarget) {
    Remove-Item -LiteralPath $moduleTarget -Force
  }
  throw
}

Write-Host ""
Write-Host "DONE: ADMIN CASES + ARCHIVE V8.2 installed." -ForegroundColor Green
Write-Host "Current V7 localization was preserved and patched surgically." -ForegroundColor Green
Write-Host "No publication was performed." -ForegroundColor Green
Write-Host ""
