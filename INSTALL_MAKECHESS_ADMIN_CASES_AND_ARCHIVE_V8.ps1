param(
  [string]$ProjectRoot = "C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PayloadRoot = Join-Path $PackageRoot "payload"

$sitePath = Join-Path $ProjectRoot "lib\ui\dialogs\site_settings_dialog.dart"
$messagesPath = Join-Path $ProjectRoot "lib\ui\messages\general_messages_dialog.dart"
$localizationPath = Join-Path $ProjectRoot "lib\localization\makechess_localization.dart"
$adminModulePath = Join-Path $ProjectRoot "lib\ui\dialogs\admin_management_panel.dart"
$adminModuleSource = Join-Path $PayloadRoot "lib\ui\dialogs\admin_management_panel.dart"

$translationPatch = Join-Path $PackageRoot "PATCH_V8_LOCALIZATION_ROWS.txt"
$messageMethodsPatch = Join-Path $PackageRoot "PATCH_V8_GENERAL_MESSAGE_METHODS.txt"
$adminPanelPatch = Join-Path $PackageRoot "PATCH_V8_SITE_ADMIN_PANEL.txt"
$sectionBodyPatch = Join-Path $PackageRoot "PATCH_V8_SITE_SECTION_BODY.txt"
$generalRowPatch = Join-Path $PackageRoot "PATCH_V8_GENERAL_ROW_HELPER.txt"
$genericSyncPatch = Join-Path $PackageRoot "PATCH_V8_GENERIC_SYNC_BLOCK.txt"
$updateStatusPatch = Join-Path $PackageRoot "PATCH_V8_UPDATE_MESSAGE_STATUS.txt"
$sendMethodPatch = Join-Path $PackageRoot "PATCH_V8_SEND_METHOD.txt"

function Read-Utf8([string]$Path) {
  return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}

function Write-Utf8([string]$Path, [string]$Text) {
  [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
}

function Replace-Range(
  [string]$Text,
  [string]$StartMarker,
  [string]$EndMarker,
  [string]$Replacement,
  [string]$Label
) {
  $start = $Text.IndexOf($StartMarker, [StringComparison]::Ordinal)
  if ($start -lt 0) {
    throw "SAFETY STOP: cannot find start marker for $Label"
  }
  $end = $Text.IndexOf($EndMarker, $start, [StringComparison]::Ordinal)
  if ($end -lt 0) {
    throw "SAFETY STOP: cannot find end marker for $Label"
  }
  return $Text.Substring(0, $start) + $Replacement + $Text.Substring($end)
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " MAKECHESS - ADMIN CASES + ARCHIVE V8" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

foreach ($path in @(
  $sitePath,
  $messagesPath,
  $localizationPath,
  $adminModuleSource,
  $translationPatch,
  $messageMethodsPatch,
  $adminPanelPatch,
  $sectionBodyPatch,
  $generalRowPatch,
  $genericSyncPatch,
  $updateStatusPatch,
  $sendMethodPatch
)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "SAFETY STOP: required file is missing: $path"
  }
}

$siteBefore = Read-Utf8 $sitePath
$messagesBefore = Read-Utf8 $messagesPath
$localizationBefore = Read-Utf8 $localizationPath

foreach ($guard in @(
  "showSiteSettingsDialog",
  "Widget _adminPanel()",
  "Widget _sectionBody()",
  "Widget _players()"
)) {
  if (-not $siteBefore.Contains($guard)) {
    throw "SAFETY STOP: current site_settings_dialog.dart does not contain: $guard"
  }
}
foreach ($guard in @(
  "class MakeChessMessage",
  "class MakeChessMessageRealtimeService",
  "Future<void> _openMessage",
  "Future<void> _acceptTournamentInvitation"
)) {
  if (-not $messagesBefore.Contains($guard)) {
    throw "SAFETY STOP: current general_messages_dialog.dart does not contain: $guard"
  }
}
foreach ($guard in @(
  "class MakeChessLocalization",
  "static String phrase(",
  "static String? _v5ExactPhrase(",
  "static String normalizeLanguageCode"
)) {
  if (-not $localizationBefore.Contains($guard)) {
    throw "SAFETY STOP: current makechess_localization.dart does not contain: $guard"
  }
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $ProjectRoot "localization_backups\ADMIN_CASES_V8_$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

Write-Host "[1/8] Creating exact backups..." -ForegroundColor Cyan
foreach ($rel in @(
  "lib\ui\dialogs\site_settings_dialog.dart",
  "lib\ui\messages\general_messages_dialog.dart",
  "lib\localization\makechess_localization.dart"
)) {
  $src = Join-Path $ProjectRoot $rel
  $dst = Join-Path $backupDir $rel
  New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
  Copy-Item -LiteralPath $src -Destination $dst -Force
}
$adminModuleExisted = Test-Path -LiteralPath $adminModulePath
if ($adminModuleExisted) {
  $dst = Join-Path $backupDir "lib\ui\dialogs\admin_management_panel.dart"
  New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
  Copy-Item -LiteralPath $adminModulePath -Destination $dst -Force
}

try {
  Write-Host "[2/8] Installing isolated admin-management module..." -ForegroundColor Cyan
  Copy-Item -LiteralPath $adminModuleSource -Destination $adminModulePath -Force

  Write-Host "[3/8] Patching Site Settings navigation and sections..." -ForegroundColor Cyan
  $site = Read-Utf8 $sitePath

  if (-not $site.Contains("// MAKECHESS_ADMIN_CASES_V8_20260808")) {
    $site = "// MAKECHESS_ADMIN_CASES_V8_20260808`r`n" + $site
  }

  if (-not $site.Contains("import '../../localization/makechess_localization.dart';")) {
    $anchor = "import '../board_theme_controller.dart';"
    if (-not $site.Contains($anchor)) {
      throw "SAFETY STOP: cannot add localization import to site settings."
    }
    $site = $site.Replace(
      $anchor,
      $anchor + "`r`nimport '../../localization/makechess_localization.dart';"
    )
  }

  if (-not $site.Contains("import 'admin_management_panel.dart';")) {
    $anchor = "import 'board_theme_picker_dialog.dart';"
    if (-not $site.Contains($anchor)) {
      throw "SAFETY STOP: cannot add admin-management import to site settings."
    }
    $site = $site.Replace(
      $anchor,
      $anchor + "`r`nimport 'admin_management_panel.dart';"
    )
  }

  # Give the one-window administrative workspace enough horizontal room.
  $site = [regex]::Replace(
    $site,
    'width:\s*_authorized\s*\?\s*\d+\s*:\s*440,',
    'width: _authorized ? 1280 : 440,',
    1
  )

  $site = Replace-Range `
    $site `
    "  Widget _adminPanel()" `
    "  Widget _nav(" `
    (Read-Utf8 $adminPanelPatch) `
    "admin panel"

  $site = Replace-Range `
    $site `
    "  Widget _sectionBody()" `
    "  Widget _title(" `
    (Read-Utf8 $sectionBodyPatch) `
    "section body"

  # New and old navigation labels both use the same central localization.
  $site = $site.Replace(
    "Text(label, style: AppTextStyles.buttonCompact)",
    "Text(MakeChessLocalization.phrase(label), style: AppTextStyles.buttonCompact)"
  )

  Write-Utf8 $sitePath $site

  Write-Host "[4/8] Adding user reply / Fixed response to Messages..." -ForegroundColor Cyan
  $messages = Read-Utf8 $messagesPath

  if (-not $messages.Contains("// MAKECHESS_ADMIN_CASE_REPLIES_V8_20260808")) {
    if (-not $messages.Contains("import '../../localization/makechess_localization.dart';")) {
      $importAnchor = "import 'package:supabase_flutter/supabase_flutter.dart';"
      if (-not $messages.Contains($importAnchor)) {
        throw "SAFETY STOP: cannot add localization import to messages."
      }
      $messages = $messages.Replace(
        $importAnchor,
        $importAnchor + "`r`n`r`nimport '../../localization/makechess_localization.dart';"
      )
    }


    if (-not $messages.Contains("MAKECHESS_ADMIN_GENERIC_MESSAGES_V8_20260808")) {
      $syncAt = $messages.IndexOf(
        "Future<void> syncMakeChessMessagesFromDatabase()",
        [StringComparison]::Ordinal
      )
      if ($syncAt -lt 0) {
        throw "SAFETY STOP: syncMakeChessMessagesFromDatabase was not found."
      }
      $helper = Read-Utf8 $generalRowPatch
      $messages =
        $messages.Substring(0, $syncAt) +
        $helper +
        $messages.Substring($syncAt)

      $mergedAt = $messages.IndexOf(
        "  final merged = byId.values.toList()",
        $syncAt,
        [StringComparison]::Ordinal
      )
      if ($mergedAt -lt 0) {
        throw "SAFETY STOP: generic-message sync insertion point was not found."
      }
      $genericSync = Read-Utf8 $genericSyncPatch
      $messages =
        $messages.Substring(0, $mergedAt) +
        $genericSync +
        $messages.Substring($mergedAt)

      $messages = Replace-Range `
        $messages `
        "Future<void> _updateInvitationStatus(" `
        "class MakeChessMessageRealtimeService" `
        ((Read-Utf8 $updateStatusPatch) + "`r`n") `
        "message status updater"

      $messages = Replace-Range `
        $messages `
        "  Future<void> send(" `
        "  Future<void> stop(" `
        (Read-Utf8 $sendMethodPatch) `
        "generic/admin send method"
    }

    $openStart = $messages.IndexOf(
      "  Future<void> _openMessage(",
      [StringComparison]::Ordinal
    )
    if ($openStart -lt 0) {
      throw "SAFETY STOP: _openMessage was not found."
    }
    $acceptedAt = $messages.IndexOf(
      "    final accepted = await showDialog<bool>(",
      $openStart,
      [StringComparison]::Ordinal
    )
    if ($acceptedAt -lt 0) {
      throw "SAFETY STOP: tournament message dialog anchor was not found."
    }

    $branch = @"
    if (_isAdminCaseMessage(message)) {
      await _openAdminCaseMessage(message);
      await _reload();
      return;
    }

"@
    $messages =
      $messages.Substring(0, $acceptedAt) +
      $branch +
      $messages.Substring($acceptedAt)

    $acceptMethodAt = $messages.IndexOf(
      "  Future<void> _acceptTournamentInvitation(",
      [StringComparison]::Ordinal
    )
    if ($acceptMethodAt -lt 0) {
      throw "SAFETY STOP: _acceptTournamentInvitation was not found."
    }

    $methods = Read-Utf8 $messageMethodsPatch
    $messages =
      $messages.Substring(0, $acceptMethodAt) +
      $methods +
      $messages.Substring($acceptMethodAt)
  }

  Write-Utf8 $messagesPath $messages

  Write-Host "[5/8] Adding V8 translations for ALL 11 site languages..." -ForegroundColor Cyan
  $loc = Read-Utf8 $localizationPath

  if (-not $loc.Contains("MAKECHESS_ADMIN_CASES_V8_TRANSLATIONS_20260808")) {
    $normalizeAt = $loc.IndexOf(
      "  static String normalizeLanguageCode",
      [StringComparison]::Ordinal
    )
    if ($normalizeAt -lt 0) {
      throw "SAFETY STOP: localization insertion point was not found."
    }
    $translationRows = Read-Utf8 $translationPatch
    $loc =
      $loc.Substring(0, $normalizeAt) +
      $translationRows +
      $loc.Substring($normalizeAt)

    $exactSignature = "  static String? _v5ExactPhrase(String source, String code) {"
    $exactAt = $loc.IndexOf($exactSignature, [StringComparison]::Ordinal)
    if ($exactAt -lt 0) {
      throw "SAFETY STOP: localization lookup method was not found."
    }
    $bodyAt = $exactAt + $exactSignature.Length
    $v8Lookup = @"

    final v8AdminRow = _v8AdminPhraseRows[source];
    if (v8AdminRow != null) {
      final index = _v4LanguageOrder.indexOf(code);
      if (index >= 0 && index < v8AdminRow.length) {
        return v8AdminRow[index];
      }
    }
"@
    $loc = $loc.Substring(0, $bodyAt) + $v8Lookup + $loc.Substring($bodyAt)
  }

  Write-Utf8 $localizationPath $loc

  Write-Host "[6/8] Running Dart parser / formatter..." -ForegroundColor Cyan
  $dart = Get-Command dart -ErrorAction SilentlyContinue
  if ($null -ne $dart) {
    & $dart.Source format `
      $adminModulePath `
      $sitePath `
      $messagesPath `
      $localizationPath | Out-Host
    if ($LASTEXITCODE -ne 0) {
      throw "dart format reported a Dart syntax error."
    }
  } else {
    Write-Host "Dart is not in PATH. PUBLISH_MAKECHESS.cmd will perform final compilation." -ForegroundColor Yellow
  }

  Write-Host "[7/8] Checking core V8 philosophy and reply mechanics..." -ForegroundColor Cyan
  $siteCheck = Read-Utf8 $sitePath
  $messagesCheck = Read-Utf8 $messagesPath
  $locCheck = Read-Utf8 $localizationPath
  $moduleCheck = Read-Utf8 $adminModulePath

  foreach ($marker in @(
    "AdminManagementPanel(kind: AdminEntityKind.player)",
    "AdminManagementPanel(kind: AdminEntityKind.school)",
    "AdminManagementPanel(kind: AdminEntityKind.teacher)",
    "AdminManagementPanel(kind: AdminEntityKind.tournament)",
    "AdminArchivePanel()"
  )) {
    if (-not $siteCheck.Contains($marker)) {
      throw "V8 verification failed in Site Settings: $marker"
    }
  }

  foreach ($marker in @(
    "MAKECHESS_ADMIN_CASES_V8_20260808",
    "Сообщение обязательно для любого административного действия",
    "_performAction('block')",
    "_performAction('warning')",
    "_reminderEnabled",
    "Timer.periodic",
    "Срок истёк — требуется решение администратора"
  )) {
    if (-not $moduleCheck.Contains($marker)) {
      throw "V8 verification failed in admin module: $marker"
    }
  }

  foreach ($marker in @(
    "MAKECHESS_ADMIN_CASE_REPLIES_V8_20260808",
    "MAKECHESS_ADMIN_GENERIC_MESSAGES_V8_20260808",
    "makechess_messages_v1",
    "admin_case_reply",
    "Сообщить, что исправлено",
    "Ответ на административное сообщение"
  )) {
    if (-not $messagesCheck.Contains($marker)) {
      throw "V8 verification failed in messages: $marker"
    }
  }

  foreach ($marker in @(
    "MAKECHESS_ADMIN_CASES_V8_TRANSLATIONS_20260808",
    "_v8AdminPhraseRows",
    "MakeChess уважает ваше право знать причину",
    "Административное действие",
    "Школы / Учителя"
  )) {
    if (-not $locCheck.Contains($marker)) {
      throw "V8 verification failed in localization: $marker"
    }
  }

  foreach ($code in @("RU","EN","DE","FR","ES","AR","ZH","HI","JA","KO","VI")) {
    if (-not $locCheck.Contains("'$code'")) {
      throw "V8 localization check failed: language $code is missing."
    }
  }

  Write-Host "[8/8] V8 installation checks completed." -ForegroundColor Cyan
}
catch {
  Write-Host ""
  Write-Host "ERROR: restoring exact files from the V8 backup..." -ForegroundColor Red

  foreach ($rel in @(
    "lib\ui\dialogs\site_settings_dialog.dart",
    "lib\ui\messages\general_messages_dialog.dart",
    "lib\localization\makechess_localization.dart"
  )) {
    $backup = Join-Path $backupDir $rel
    $target = Join-Path $ProjectRoot $rel
    if (Test-Path -LiteralPath $backup) {
      Copy-Item -LiteralPath $backup -Destination $target -Force
    }
  }

  if ($adminModuleExisted) {
    $backup = Join-Path $backupDir "lib\ui\dialogs\admin_management_panel.dart"
    if (Test-Path -LiteralPath $backup) {
      Copy-Item -LiteralPath $backup -Destination $adminModulePath -Force
    }
  } else {
    if (Test-Path -LiteralPath $adminModulePath) {
      Remove-Item -LiteralPath $adminModulePath -Force
    }
  }

  throw
}

Write-Host ""
Write-Host "DONE: ADMIN CASES + ARCHIVE V8 installed." -ForegroundColor Green
Write-Host "No hidden block: message is mandatory before block/restriction." -ForegroundColor Green
Write-Host "Warning timer: reminder only, NEVER automatic blocking." -ForegroundColor Green
Write-Host "User response: Reply + Fixed are connected to Messages." -ForegroundColor Green
Write-Host "Languages: RU EN DE FR ES AR ZH HI JA KO VI" -ForegroundColor Green
Write-Host ""
Write-Host "Backup:"
Write-Host "  $backupDir"
Write-Host ""
Write-Host "Next command after DONE:"
Write-Host "  .\PUBLISH_MAKECHESS.cmd"
