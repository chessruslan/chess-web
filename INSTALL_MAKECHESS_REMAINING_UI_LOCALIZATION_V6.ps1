param(
  [string]$ProjectRoot = "C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PayloadRoot = Join-Path $PackageRoot "payload"

$items = @(
  @{ Target = 'lib\localization\makechess_localization.dart'; OldHash = '29cb34945575dfb7ec4022f37f9fb960edf5266f2482c08005ebbe94e1dd0e0b'; PackageHash = 'ca15a66f19a5baf626253c53a86a0423a46888e337a5eb31e08f9e55672ec1f5' },
  @{ Target = 'lib\main.dart'; OldHash = '2425d40486564f75d722b8d57b6e6105ca91905fc6933a29170382758759738c'; PackageHash = '7011badbafaf392a0fe17a41f39805327c588a6d6956202e6170dbc424a19dc9' },
  @{ Target = 'lib\ui\dialogs\personal_cabinet_dialog.dart'; OldHash = 'fbd38b43ff5c52b45a23b72ce7217e329ba0214d860347ffdd542cf5f2145f32'; PackageHash = 'e3332422ee810bab7c8408313037f406b8b823cf760f4d6467f98ade7bca634f' },
  @{ Target = 'lib\ui\dialogs\teacher_access_dialog.dart'; OldHash = '8d1bff2076bf34fd53a806051320b3c9411399b7f76d3d8647076a4b1dcb84a0'; PackageHash = 'a768939cf9941828a69f41ee77b00decc2f613be2fe06ffe7e01e7e2e4c327dc' },
  @{ Target = 'lib\ui\tournament\tournament_participant_picker_dialog.dart'; OldHash = 'e50d61b7c8d9bdff86b5a92d9a1b2d1d5a2a77718f5ea199be36d718b830146b'; PackageHash = '05537a79b14225e37a9e6ab8d841c492b599e0bf0e12f9f7f0661eaf9b416dab' },
  @{ Target = 'lib\ui\tournament\tournament_table_editor.dart'; OldHash = '52f75572c5226ecffd5fee092aafffb786bae9bcae3a187da9fff39b0d53ec22'; PackageHash = '368d0cfbf198d677118937189a187b704f19d920d13dcaa3b3961fb67d4498fe' },
  @{ Target = 'lib\ui\panels\learn_panel.dart'; OldHash = 'd7ddc95c6484cbba82ccfebee78e80781a953d01ccf6b8fa758f826eacd00610'; PackageHash = '1294f84a641b291358179fbc85e2fa7a1b73ca6a670a5d7e1e944c23d35db1ff' },
  @{ Target = 'lib\ui\panels\puzzle_settings_dialog.dart'; OldHash = '3eab11e8d0660de84e6bdc5029d6f4a2b3d355c6a510c8c3f85a2697d8d7616f'; PackageHash = '624538248ee78de48e46ce6b9a18b1616cebe69f75ede39367c34954e9263f9d' },
  @{ Target = 'lib\ui\panels\puzzle_types_panel.dart'; OldHash = 'a5b0e161e7579170ecd9c48b83fad8798da2993a7fffb2dd3f05caca44f5bf5c'; PackageHash = '1d097b0e6596341645be86971ad46fc9503e47141f7c043f59b34498d7d46d01' },
  @{ Target = 'lib\ui\panels\auth_widgets.dart'; OldHash = '1b300f273f209e80882dc092dc85fa4c73587b28e02c34c470ab6ce11ad1f0b8'; PackageHash = '0cc676a73c7aa634e00092be97eb2bee081f0f97b6d471669ff5903b1ef1868f' },
  @{ Target = 'lib\ui\panels\opening_trainer.dart'; OldHash = 'cc2920a0b91aecffda61ffa2cf08ebdf5fc3640abdb94de3fa1ea7682b5e2ce8'; PackageHash = '228f097d2b4c8b769cd4fc01d6b50681ef67bbac5c03dd71d0f03a9024a3675b' },
  @{ Target = 'lib\ui\tournament\tournament_manager_dialog.dart'; OldHash = '70d95dd3eda5f937b7505f83e35754faac145ebdfa2e62c1117f061b8d7177f3'; PackageHash = '396a6cc60041a14bfadd79f391a387cb281161002ce9457f5f6bbcb20de60950' }
)

function Get-Sha256([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " MAKECHESS - REMAINING UI LOCALIZATION V6" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/7] Checking V6 package hashes..." -ForegroundColor Cyan
foreach ($item in $items) {
  $source = Join-Path $PayloadRoot $item.Target
  if (-not (Test-Path -LiteralPath $source)) {
    throw "PACKAGE ERROR: missing $($item.Target)"
  }
  if ((Get-Sha256 $source) -ne $item.PackageHash) {
    throw "PACKAGE ERROR: hash mismatch $($item.Target)"
  }
}

Write-Host "[2/7] Checking exact current files from YOUR V6 collector..." -ForegroundColor Cyan
foreach ($item in $items) {
  $target = Join-Path $ProjectRoot $item.Target
  if (-not (Test-Path -LiteralPath $target)) {
    throw "SAFETY STOP: missing $($item.Target). Nothing changed."
  }
  if ((Get-Sha256 $target) -ne $item.OldHash) {
    throw "SAFETY STOP: $($item.Target) changed after the V6 collector. Nothing changed."
  }
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $ProjectRoot "localization_backups\REMAINING_UI_V6_$stamp"

Write-Host "[3/7] Creating exact backups of 12 files..." -ForegroundColor Cyan
foreach ($item in $items) {
  $target = Join-Path $ProjectRoot $item.Target
  $backup = Join-Path $backupDir $item.Target
  New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force | Out-Null
  Copy-Item -LiteralPath $target -Destination $backup -Force
}

try {
  Write-Host "[4/7] Installing V6 remaining-UI fixes..." -ForegroundColor Cyan
  foreach ($item in $items) {
    $source = Join-Path $PayloadRoot $item.Target
    $target = Join-Path $ProjectRoot $item.Target
    Copy-Item -LiteralPath $source -Destination $target -Force
  }

  Write-Host "[5/7] Running Dart parser/formatter..." -ForegroundColor Cyan
  $dart = Get-Command dart -ErrorAction SilentlyContinue
  if ($null -ne $dart) {
    $args = @("format")
    foreach ($item in $items) {
      $args += (Join-Path $ProjectRoot $item.Target)
    }
    & $dart.Source @args | Out-Host
    if ($LASTEXITCODE -ne 0) {
      throw "dart format reported a syntax error."
    }
  } else {
    Write-Host "Dart is not in PATH. PUBLISH_MAKECHESS.cmd will do the final compile check." -ForegroundColor Yellow
  }

  Write-Host "[6/7] Checking V6 markers..." -ForegroundColor Cyan
  $loc = [IO.File]::ReadAllText((Join-Path $ProjectRoot "lib\localization\makechess_localization.dart"))
  foreach ($marker in @(
    "MAKECHESS_REMAINING_UI_LOCALIZATION_V6_20260807",
    "MAKECHESS_REMAINING_UI_V6_EXACT_ROWS_20260807",
    "MAKECHESS_REMAINING_UI_V6_COMPOSITE_FALLBACK_20260807",
    "MAKECHESS_CENTRAL_LOCALIZATION_V5_20260807"
  )) {
    if (-not $loc.Contains($marker)) {
      throw "V6 localization marker missing: $marker"
    }
  }

  foreach ($code in @("RU","EN","DE","FR","ES","AR","ZH","HI","JA","KO","VI")) {
    if (-not $loc.Contains("'$code'")) {
      throw "Language code missing after V6: $code"
    }
  }

  Write-Host "[7/7] Checking the specific leftover UI paths fixed by V6..." -ForegroundColor Cyan

  $puzzle = [IO.File]::ReadAllText((Join-Path $ProjectRoot "lib\ui\panels\puzzle_types_panel.dart"))
  if (-not $puzzle.Contains("labelText: MakeChessLocalization.phrase(label)")) {
    throw "V6 check failed: statistics field labels are not localized."
  }

  $opening = [IO.File]::ReadAllText((Join-Path $ProjectRoot "lib\ui\panels\opening_trainer.dart"))
  if (-not $opening.Contains("MAKECHESS_REMAINING_UI_V6_20260807")) {
    throw "V6 check failed: opening trainer marker missing."
  }

  $manager = [IO.File]::ReadAllText((Join-Path $ProjectRoot "lib\ui\tournament\tournament_manager_dialog.dart"))
  if (-not $manager.Contains("MAKECHESS_REMAINING_UI_V6_20260807")) {
    throw "V6 check failed: tournament manager marker missing."
  }
}
catch {
  Write-Host ""
  Write-Host "ERROR: restoring all 12 exact files from the V6 backup..." -ForegroundColor Red
  foreach ($item in $items) {
    $backup = Join-Path $backupDir $item.Target
    $target = Join-Path $ProjectRoot $item.Target
    if (Test-Path -LiteralPath $backup) {
      Copy-Item -LiteralPath $backup -Destination $target -Force
    }
  }
  throw
}

Write-Host ""
Write-Host "DONE: REMAINING UI LOCALIZATION V6 installed." -ForegroundColor Green
Write-Host "Fixed: raw helper labels, statistics fields, opening list titles, password/tooltips, tournament helper labels." -ForegroundColor Green
Write-Host "Languages: RU EN DE FR ES AR ZH HI JA KO VI" -ForegroundColor Green
Write-Host "Backup:"
Write-Host "  $backupDir"
Write-Host ""
Write-Host "Next command:"
Write-Host "  .\PUBLISH_MAKECHESS.cmd"
