param(
  [string]$ProjectRoot = "C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PayloadRoot = Join-Path $PackageRoot "payload"

$adminRel = 'lib\ui\dialogs\admin_management_panel.dart'
$siteRel  = 'lib\ui\dialogs\site_settings_dialog.dart'
$msgRel   = 'lib\ui\messages\general_messages_dialog.dart'
$appRel   = 'lib\ui\app_shell.dart'
$locRel   = 'lib\localization\makechess_localization.dart'

$adminTarget = Join-Path $ProjectRoot $adminRel
$siteTarget  = Join-Path $ProjectRoot $siteRel
$msgTarget   = Join-Path $ProjectRoot $msgRel
$appTarget   = Join-Path $ProjectRoot $appRel
$locTarget   = Join-Path $ProjectRoot $locRel

foreach ($path in @($adminTarget,$siteTarget,$msgTarget,$appTarget,$locTarget)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "SAFETY STOP: missing project file: $path"
  }
}
foreach ($rel in @($adminRel,$siteRel,$msgRel)) {
  $source = Join-Path $PayloadRoot $rel
  if (-not (Test-Path -LiteralPath $source)) {
    throw "PACKAGE ERROR: missing payload: $rel"
  }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " MAKECHESS - ADMIN CASE WORKFLOW V8.4" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$adminCurrent = [IO.File]::ReadAllText($adminTarget)
$siteCurrent  = [IO.File]::ReadAllText($siteTarget)
$msgCurrent   = [IO.File]::ReadAllText($msgTarget)
$appCurrent   = [IO.File]::ReadAllText($appTarget)
$locCurrent   = [IO.File]::ReadAllText($locTarget)

if ($adminCurrent.Contains('MAKECHESS_ADMIN_CASE_WORKFLOW_V8_4_20260808') -and
    $msgCurrent.Contains('MAKECHESS_ADMIN_CASE_WORKFLOW_V8_4_20260808') -and
    $siteCurrent.Contains('initialAdminCase') -and
    $appCurrent.Contains('initialAdminCase: adminCase') -and
    $locCurrent.Contains('MAKECHESS_ADMIN_CASE_WORKFLOW_V8_4_TRANSLATIONS_20260808')) {
  Write-Host "ALREADY INSTALLED: V8.4" -ForegroundColor Green
  exit 0
}

Write-Host "[1/7] Checking current files..." -ForegroundColor Cyan
foreach ($marker in @(
  'MAKECHESS_ADMIN_DELETE_V8_3_20260808',
  'class AdminArchivePanel extends StatefulWidget',
  'String? _archiveDeleteConfirmId;'
)) {
  if (-not $adminCurrent.Contains($marker)) {
    throw "SAFETY STOP: admin_management_panel.dart is not current V8.3: $marker"
  }
}
foreach ($marker in @(
  'MAKECHESS_ADMIN_CASES_V8_1_20260808',
  "_nav(9, Icons.campaign_outlined, 'Сообщения')",
  'AdminArchivePanel'
)) {
  if (-not $siteCurrent.Contains($marker)) {
    throw "SAFETY STOP: site_settings_dialog.dart is not V8.2-compatible: $marker"
  }
}
foreach ($marker in @(
  'MAKECHESS_ADMIN_DELETE_MESSAGES_V8_3_20260808',
  'class MakeChessMessageRealtimeService',
  "message.category == 'admin_delete'"
)) {
  if (-not $msgCurrent.Contains($marker)) {
    throw "SAFETY STOP: general_messages_dialog.dart is not V8.3-compatible: $marker"
  }
}
foreach ($marker in @(
  'Future<void> _openGeneralMessages()',
  'onMessages: _openGeneralMessages',
  'unreadMessages: _unreadMessages'
)) {
  if (-not $appCurrent.Contains($marker)) {
    throw "SAFETY STOP: app_shell.dart is not compatible: $marker"
  }
}
foreach ($marker in @(
  'MAKECHESS_ADMIN_DELETE_V8_3_TRANSLATIONS_20260808',
  'MAKECHESS_TOURNAMENT_UI_LOCALIZATION_V7_20260807',
  'static String? _v5ExactPhrase(String source, String code)',
  'static String normalizeLanguageCode'
)) {
  if (-not $locCurrent.Contains($marker)) {
    throw "SAFETY STOP: localization is not V8.3-compatible: $marker"
  }
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $ProjectRoot "localization_backups\ADMIN_CASE_WORKFLOW_V8_4_$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

Write-Host "[2/7] Creating exact backups..." -ForegroundColor Cyan
foreach ($rel in @($adminRel,$siteRel,$msgRel,$appRel,$locRel)) {
  $src = Join-Path $ProjectRoot $rel
  $dst = Join-Path $backupDir $rel
  New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
  Copy-Item -LiteralPath $src -Destination $dst -Force
}

try {
  Write-Host "[3/7] Installing admin case cards, action dialogs and admin inbox..." -ForegroundColor Cyan
  Copy-Item -LiteralPath (Join-Path $PayloadRoot $adminRel) -Destination $adminTarget -Force
  Copy-Item -LiteralPath (Join-Path $PayloadRoot $siteRel)  -Destination $siteTarget  -Force
  Copy-Item -LiteralPath (Join-Path $PayloadRoot $msgRel)   -Destination $msgTarget   -Force

  Write-Host "[4/7] Patching main Messages -> exact admin case navigation..." -ForegroundColor Cyan
  $app = [IO.File]::ReadAllText($appTarget)

  $old = @"
    await showGeneralMessagesDialog(
      context: context,
      currentUserId: userId,
      currentUserName: name,
    );
    await _refreshUnreadMessages();
"@

  $new = @"
    final adminCase = await showGeneralMessagesDialog(
      context: context,
      currentUserId: userId,
      currentUserName: name,
    );
    await _refreshUnreadMessages();
    if (!mounted || adminCase == null || !adminCase.isValid) return;
    await showSiteSettingsDialog(
      context,
      boardTheme: boardTheme,
      initialAdminCase: adminCase,
    );
"@

  if (-not $app.Contains('initialAdminCase: adminCase')) {
    if (-not $app.Contains($old)) {
      throw "SAFETY STOP: app_shell Messages block changed. Restoring backup."
    }
    $app = $app.Replace($old, $new)
    [IO.File]::WriteAllText($appTarget, $app, [Text.UTF8Encoding]::new($false))
  }

  Write-Host "[5/7] Adding all new phrases to central localization..." -ForegroundColor Cyan
  $loc = [IO.File]::ReadAllText($locTarget)
  $block = [IO.File]::ReadAllText(
    (Join-Path $PackageRoot 'LOCALIZATION_V8_4_BLOCK.txt')
  ).Trim([char]0xFEFF)
  $lookup = [IO.File]::ReadAllText(
    (Join-Path $PackageRoot 'LOCALIZATION_V8_4_LOOKUP.txt')
  ).Trim([char]0xFEFF)

  if (-not $loc.Contains('MAKECHESS_ADMIN_CASE_WORKFLOW_V8_4_TRANSLATIONS_20260808')) {
    $anchor = '  static String normalizeLanguageCode'
    $idx = $loc.IndexOf($anchor, [StringComparison]::Ordinal)
    if ($idx -lt 0) { throw "Localization insertion anchor not found." }
    $loc = $loc.Substring(0,$idx) + $block.TrimEnd() + "`r`n`r`n" + $loc.Substring($idx)
  }

  if (-not $loc.Contains('final v84AdminCaseRow = _v84AdminCaseRows[source];')) {
    $method = '  static String? _v5ExactPhrase(String source, String code) {'
    $idx = $loc.IndexOf($method, [StringComparison]::Ordinal)
    if ($idx -lt 0) { throw "Localization lookup anchor not found." }
    $insertAt = $idx + $method.Length
    $loc = $loc.Substring(0,$insertAt) + "`r`n" + $lookup.TrimEnd() + "`r`n" + $loc.Substring($insertAt)
  }
  [IO.File]::WriteAllText($locTarget, $loc, [Text.UTF8Encoding]::new($false))

  Write-Host "[6/7] Running Dart formatter / parser..." -ForegroundColor Cyan
  $dart = Get-Command dart -ErrorAction SilentlyContinue
  if ($null -ne $dart) {
    & $dart.Source format $adminTarget $siteTarget $msgTarget $appTarget $locTarget | Out-Host
    if ($LASTEXITCODE -ne 0) {
      throw "dart format reported a syntax error."
    }
  } else {
    Write-Host "Dart is not in PATH. Flutter build will perform the final compiler check." -ForegroundColor Yellow
  }

  Write-Host "[7/7] Verifying workflow..." -ForegroundColor Cyan
  $adminCheck = [IO.File]::ReadAllText($adminTarget)
  $siteCheck  = [IO.File]::ReadAllText($siteTarget)
  $msgCheck   = [IO.File]::ReadAllText($msgTarget)
  $appCheck   = [IO.File]::ReadAllText($appTarget)
  $locCheck   = [IO.File]::ReadAllText($locTarget)

  foreach ($marker in @(
    'MAKECHESS_ADMIN_CASE_WORKFLOW_V8_4_20260808',
    'Future<void> _openActionDialog(String action)',
    'ПЕРВОНАЧАЛЬНАЯ ПРИЧИНА',
    'class AdminRepliesInbox extends StatefulWidget',
    'Снять ограничения',
    'Сохранить ограничения'
  )) {
    if (-not $adminCheck.Contains($marker)) {
      throw "Admin verification failed: $marker"
    }
  }
  foreach ($marker in @(
    'class AdminCaseNavigationRequest',
    'makechessAdminReplyUnreadCount',
    "message.category == 'admin_case_reply'"
  )) {
    if (-not $msgCheck.Contains($marker)) {
      throw "Messages verification failed: $marker"
    }
  }
  foreach ($marker in @(
    'initialAdminCase',
    'AdminRepliesInbox',
    'badgeCount: count'
  )) {
    if (-not $siteCheck.Contains($marker)) {
      throw "Site settings verification failed: $marker"
    }
  }
  if (-not $appCheck.Contains('initialAdminCase: adminCase')) {
    throw "App shell navigation verification failed."
  }
  foreach ($marker in @(
    'MAKECHESS_ADMIN_CASE_WORKFLOW_V8_4_TRANSLATIONS_20260808',
    'final v84AdminCaseRow = _v84AdminCaseRows[source];'
  )) {
    if (-not $locCheck.Contains($marker)) {
      throw "Localization verification failed: $marker"
    }
  }
}
catch {
  Write-Host ""
  Write-Host "ERROR: restoring exact V8.4 backups..." -ForegroundColor Red
  foreach ($rel in @($adminRel,$siteRel,$msgRel,$appRel,$locRel)) {
    $src = Join-Path $backupDir $rel
    $dst = Join-Path $ProjectRoot $rel
    if (Test-Path -LiteralPath $src) {
      Copy-Item -LiteralPath $src -Destination $dst -Force
    }
  }
  throw
}

Write-Host ""
Write-Host "DONE: ADMIN CASE WORKFLOW V8.4 installed." -ForegroundColor Green
Write-Host "No publication was performed." -ForegroundColor Green
Write-Host ""
