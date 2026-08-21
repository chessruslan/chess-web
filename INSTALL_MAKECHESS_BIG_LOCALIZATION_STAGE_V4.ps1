param(
  [string]$ProjectRoot = "C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$items = @(
  @{ Source = 'makechess_localization_BIG_LOCALIZATION_STAGE_V4.dart'; Target = 'lib\localization\makechess_localization.dart'; OldHash = '39b9195b587c727e83bd9c026040e096185a54398bad9b94f10f0cb3f233c6a6'; PackageHash = '57ee09f56aef1617d4ccae58e7ae7801aea6c756f58dfe74e213b551f6e1cafc' },
  @{ Source = 'app_shell_BIG_LOCALIZATION_STAGE_V4.dart'; Target = 'lib\ui\app_shell.dart'; OldHash = '13803b5153304393e2ca95f51730fe073b2ca0c9ef88eb7d350c48082188bb90'; PackageHash = '884bf6eac4d4d701f7786aee8673dfa800415ab796a85df7f6d7b95da7f9059c' },
  @{ Source = 'common_top_bar_BIG_LOCALIZATION_STAGE_V4.dart'; Target = 'lib\ui\common_top_bar.dart'; OldHash = '7865a138143103cf95ea4b44f7c2c1431df24871a2edc8f969405166cfa1e240'; PackageHash = '74726c8b8109caaca33bd3186be3299268871e2284815db85ef365cc3b22196d' },
  @{ Source = 'start_modal_BIG_LOCALIZATION_STAGE_V4.dart'; Target = 'lib\ui\start_modal.dart'; OldHash = '8a8aa9ba43791513a2bc753682cb8dcf911913070535d372cdb310d60b628c56'; PackageHash = '4880bc84cdb7b7b9c454aeedf0db937b33ecb92b5463adc4e255d485cc430cf3' },
  @{ Source = 'site_settings_dialog_BIG_LOCALIZATION_STAGE_V4.dart'; Target = 'lib\ui\dialogs\site_settings_dialog.dart'; OldHash = 'a75f8d845606e302530eb0a14e435ec1b54ca070baed26bc8483cda208d5f8a8'; PackageHash = '189c635bac484c1403a721d40f1c4613f5dc33c6e613398a6f2ecccc8d578c66' },
  @{ Source = 'personal_cabinet_dialog_BIG_LOCALIZATION_STAGE_V4.dart'; Target = 'lib\ui\dialogs\personal_cabinet_dialog.dart'; OldHash = 'ddb87250aeab72cb95749eb9ffe8384030c2fef5d09218e5dcb20204d8eca477'; PackageHash = '842c12efdca2720b8e0e96fc336e669a883121c7bedf26feeb29eecf00e1b905' },
  @{ Source = 'board_theme_picker_dialog_BIG_LOCALIZATION_STAGE_V4.dart'; Target = 'lib\ui\dialogs\board_theme_picker_dialog.dart'; OldHash = '7f9eafa440261c0a1ef33348b8b75d6bfabfbf3acae3fe629edc0da8f999a72b'; PackageHash = '515f25a25ae21811ac91e811134b71f461d6e16cc16f75e4d0274e5637b1af94' },
  @{ Source = 'tournament_table_editor_BIG_LOCALIZATION_STAGE_V4.dart'; Target = 'lib\ui\tournament\tournament_table_editor.dart'; OldHash = '3444c541b6185288a23fcfcd9de303bd2839603f8f9141ec521db1056884fd0f'; PackageHash = '137a5fc4e2004a623c5061cf1a09761fba6964431f8cfccd8cbaf5b28de668e7' },
  @{ Source = 'tournament_manager_dialog_BIG_LOCALIZATION_STAGE_V4.dart'; Target = 'lib\ui\tournament\tournament_manager_dialog.dart'; OldHash = 'be4963fc663f23a4812340c897905fa31edf1d3731083370c06d6880be76d966'; PackageHash = '9d792090449f893aa380a0911ccd2d3745403b2df2ac8990bd51d8d1b0aa7b87' },
  @{ Source = 'puzzle_types_panel_BIG_LOCALIZATION_STAGE_V4.dart'; Target = 'lib\ui\panels\puzzle_types_panel.dart'; OldHash = '5955aeeb901524808e60db9fd89f65dc3a1518710f52f840e2a42cf6f50db6e8'; PackageHash = 'e0f82e181ffa7b726917c9dd3c883c0fe2ff2df1340e939ecc4515e5c4cb10e4' },
  @{ Source = 'learn_panel_BIG_LOCALIZATION_STAGE_V4.dart'; Target = 'lib\ui\panels\learn_panel.dart'; OldHash = '519cd1f2f341319d05a22bc9f19672b282a4dcd0989d140c6c3723d8f4a818c5'; PackageHash = 'd335306b174468e024c00b82362ac0016d37a7986808a3056a43b2107007e007' },
  @{ Source = 'opening_trainer_BIG_LOCALIZATION_STAGE_V4.dart'; Target = 'lib\ui\panels\opening_trainer.dart'; OldHash = '1bdb2d258553f963e81c82d03b544c3a0f0eb20a603ed45baf62345c8178d3ab'; PackageHash = '5a79fbc999cd2ca880971ef8f581317c83d610e97498a075d759543bbd57ea0a' },
  @{ Source = 'puzzle_settings_dialog_BIG_LOCALIZATION_STAGE_V4.dart'; Target = 'lib\ui\panels\puzzle_settings_dialog.dart'; OldHash = 'db142f8694e70a2f0c205d9ef4fa6ccfb1901f3872983cba9d79115b6bfc37a7'; PackageHash = 'f24c789e079238bc6cdaaff4001c55bbb902e8d5cdae31ae0f8c7865f7d337e3' },
  @{ Source = 'room_chat_panel_BIG_LOCALIZATION_STAGE_V4.dart'; Target = 'lib\ui\panels\room_chat_panel.dart'; OldHash = 'f50714ac948569146a17622e8cd93d6c5c945d717557718f5ce02166f468a7eb'; PackageHash = '8eca715a97ff0d213cf26ac08bb81642f161268ce3e28492c3dad909356dd21e' }
)

function Get-Sha256([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " MAKECHESS - BIG LOCALIZATION STAGE V4" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/7] Checking V4 package files..." -ForegroundColor Cyan
foreach ($item in $items) {
  $sourcePath = Join-Path $PackageRoot $item.Source
  if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "PACKAGE ERROR: missing source file: $($item.Source)"
  }
  if ((Get-Sha256 $sourcePath) -ne $item.PackageHash) {
    throw "PACKAGE ERROR: source hash mismatch: $($item.Source)"
  }
}

Write-Host "[2/7] Checking YOUR exact files collected for V4..." -ForegroundColor Cyan
foreach ($item in $items) {
  $targetPath = Join-Path $ProjectRoot $item.Target
  if (-not (Test-Path -LiteralPath $targetPath)) {
    throw "SAFETY STOP: target file is missing: $($item.Target). Nothing changed."
  }

  $currentHash = Get-Sha256 $targetPath
  if ($currentHash -ne $item.OldHash) {
    throw "SAFETY STOP: $($item.Target) changed after the V4 collector ZIP was created. Nothing changed."
  }
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $ProjectRoot "localization_backups\BIG_STAGE_V4_$stamp"

Write-Host "[3/7] Creating exact backups of 14 files..." -ForegroundColor Cyan
foreach ($item in $items) {
  $targetPath = Join-Path $ProjectRoot $item.Target
  $backupPath = Join-Path $backupDir $item.Target
  $backupParent = Split-Path -Parent $backupPath
  New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
  Copy-Item -LiteralPath $targetPath -Destination $backupPath -Force
}

try {
  Write-Host "[4/7] Installing the large localization stage..." -ForegroundColor Cyan
  foreach ($item in $items) {
    $sourcePath = Join-Path $PackageRoot $item.Source
    $targetPath = Join-Path $ProjectRoot $item.Target
    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
  }

  Write-Host "[5/7] Running Dart syntax/format check on all changed files..." -ForegroundColor Cyan
  $dart = Get-Command dart -ErrorAction SilentlyContinue
  if ($null -ne $dart) {
    $formatArgs = @("format")
    foreach ($item in $items) {
      $formatArgs += (Join-Path $ProjectRoot $item.Target)
    }
    & $dart.Source @formatArgs | Out-Host
    if ($LASTEXITCODE -ne 0) {
      throw "dart format reported a Dart syntax error."
    }
  } else {
    Write-Host "Dart is not in PATH. Flutter build will perform the final syntax/type check." -ForegroundColor Yellow
  }

  Write-Host "[6/7] Checking localization markers and preserved core modules..." -ForegroundColor Cyan

  $locPath = Join-Path $ProjectRoot "lib\localization\makechess_localization.dart"
  $loc = [System.IO.File]::ReadAllText($locPath)

  foreach ($marker in @(
    "MAKECHESS_CENTRAL_LOCALIZATION_BIG_STAGE_V4_20260807",
    "MAKECHESS_CENTRAL_LOCALIZATION_MESSAGES_TOURNAMENTS_V3_2_20260807",
    "MAKECHESS_LOCALIZED_TEXT_WIDGET_V4_20260807",
    "MAKECHESS_BIG_LOCALIZATION_STAGE_V4_PHRASES_20260807",
    "class MakeChessLocalization",
    "class MakeChessLocalizationController",
    "class MakeChessLocalizedText",
    "static String phrase("
  )) {
    if (-not $loc.Contains($marker)) {
      throw "Localization verification failed: $marker"
    }
  }

  foreach ($code in @("RU","EN","DE","FR","ES","AR","ZH","HI","JA","KO","VI")) {
    if (-not $loc.Contains("'$code'")) {
      throw "Localization verification failed: language code missing: $code"
    }
  }

  foreach ($item in $items) {
    if ($item.Target -eq "lib\localization\makechess_localization.dart") {
      continue
    }
    $targetPath = Join-Path $ProjectRoot $item.Target
    $text = [System.IO.File]::ReadAllText($targetPath)
    if (-not $text.Contains("MAKECHESS_BIG_LOCALIZATION_STAGE_V4_20260807")) {
      throw "V4 marker missing after install: $($item.Target)"
    }
  }

  # Only real, pre-existing functional markers from the user's current files.
  $functionalChecks = @(
    @("lib\ui\app_shell.dart", "class AppShell extends StatefulWidget"),
    @("lib\ui\common_top_bar.dart", "makechessLearningTopBarLabel"),
    @("lib\ui\start_modal.dart", "class StartModal"),
    @("lib\ui\dialogs\site_settings_dialog.dart", "showSiteSettingsDialog"),
    @("lib\ui\dialogs\personal_cabinet_dialog.dart", "showPersonalCabinetDialog"),
    @("lib\ui\dialogs\board_theme_picker_dialog.dart", "showBoardThemePickerDialog"),
    @("lib\ui\tournament\tournament_table_editor.dart", "showTournamentTableEditor"),
    @("lib\ui\tournament\tournament_manager_dialog.dart", "TournamentStorageService.instance"),
    @("lib\ui\panels\puzzle_types_panel.dart", "class PuzzleTypesPanel extends StatefulWidget"),
    @("lib\ui\panels\learn_panel.dart", "class LearningPanel extends StatefulWidget"),
    @("lib\ui\panels\opening_trainer.dart", "MAKECHESS_OPENING_ADD_VARIANT_V16_20260806"),
    @("lib\ui\panels\opening_trainer.dart", "OPENING_TRAINER_PROGRAMMABLE_BOT_V8_20260805"),
    @("lib\ui\panels\opening_trainer.dart", "class OpeningBotReplyRuleParser"),
    @("lib\ui\panels\puzzle_settings_dialog.dart", "class PuzzleSettingsDialog extends StatefulWidget"),
    @("lib\ui\panels\room_chat_panel.dart", "class RoomChatPanel extends StatelessWidget")
  )

  foreach ($check in $functionalChecks) {
    $path = Join-Path $ProjectRoot $check[0]
    $text = [System.IO.File]::ReadAllText($path)
    if (-not $text.Contains($check[1])) {
      throw "Functional marker missing: $($check[0]) :: $($check[1])"
    }
  }

  Write-Host "[7/7] V4 installation checks completed." -ForegroundColor Cyan
}
catch {
  Write-Host ""
  Write-Host "ERROR: restoring all 14 exact files from the V4 backup..." -ForegroundColor Red

  foreach ($item in $items) {
    $backupPath = Join-Path $backupDir $item.Target
    $targetPath = Join-Path $ProjectRoot $item.Target
    if (Test-Path -LiteralPath $backupPath) {
      Copy-Item -LiteralPath $backupPath -Destination $targetPath -Force
    }
  }

  throw
}

Write-Host ""
Write-Host "DONE: BIG LOCALIZATION STAGE V4 installed." -ForegroundColor Green
Write-Host "Central phrase rows: 528" -ForegroundColor Green
Write-Host "Languages: RU EN DE FR ES AR ZH HI JA KO VI" -ForegroundColor Green
Write-Host "Changed modules: 13 UI modules + central localization file" -ForegroundColor Green
Write-Host "Teacher assignment module was already centralized and was not overwritten." -ForegroundColor Green
Write-Host ""
Write-Host "Backup:"
Write-Host "  $backupDir"
Write-Host ""
Write-Host "Next command:"
Write-Host "  .\PUBLISH_MAKECHESS.cmd"
