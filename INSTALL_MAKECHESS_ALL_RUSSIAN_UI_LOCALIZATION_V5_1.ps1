param(
  [string]$ProjectRoot = "C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$items = @(
  @{ Target = 'lib\chess_board.dart'; Source = 'payload\lib\chess_board.dart'; OldHash = '1431606d6141e423dd49d32ee927cbddf978835a2e8898e948bb631341277610'; PackageHash = '3236006e6da7662cd0b12e35e2207e51fb098fc3b5c25597b9e5a6bba5c86301' },
  @{ Target = 'lib\classroom\classroom_overlay.dart'; Source = 'payload\lib\classroom\classroom_overlay.dart'; OldHash = 'addfbe5c38feb2e96cbacdc558ef397150f36bb8f830579f11aff912be990631'; PackageHash = '22bdcefacbc6023efb7c769f81af70a40056902c5abc0dc9f1b642c54ecfdafd' },
  @{ Target = 'lib\classroom\school_dialog_new.dart'; Source = 'payload\lib\classroom\school_dialog_new.dart'; OldHash = '0ac5ec12fe9fac2ff4f6ce2d9eefb7d8db5d7986ac6e4cb56e7dcc148ecdfae4'; PackageHash = '4a9cdc019c348e3c84197c505046e691cad9a6850acd45839900f904bb85099d' },
  @{ Target = 'lib\dev\smoke_test_button.dart'; Source = 'payload\lib\dev\smoke_test_button.dart'; OldHash = '77e303de089b659c7c6a468713e52cb283fe5ef95e52b7dfec4c404f57d1c2a7'; PackageHash = '358de5a813e9f1e14ec3f7dc28233705e0131547040718009e55d0ad4e961628' },
  @{ Target = 'lib\features\call\call_overlay.dart'; Source = 'payload\lib\features\call\call_overlay.dart'; OldHash = '42b71ce4477900268b52880f252bb873b9f1a4cd3778e34417ad408f8d34e5a4'; PackageHash = 'b336122576a20b9b257bee01d58c16a24bf0226d2c80c0461b7db762e5b8124b' },
  @{ Target = 'lib\features\call\call_panel.dart'; Source = 'payload\lib\features\call\call_panel.dart'; OldHash = '81b90f52eee2c9c613f4f9cda792eebf3e1e05cf41b8660428dc7aa677dd56e1'; PackageHash = '413b49ffc1afce058b99d7acb52a5e036030032aba1fa94de581764705a2e352' },
  @{ Target = 'lib\features\call\classroom_call_overlay.dart'; Source = 'payload\lib\features\call\classroom_call_overlay.dart'; OldHash = '5eb47214ad37c8a5cb3af10136d400de0081f04007d8492ed6a7096fa102a848'; PackageHash = '33f53e8cf5f9c755e1ab136424d33d9f38f352746d2128d663039d25fb438284' },
  @{ Target = 'lib\features\call\schools\learn_sheet.dart'; Source = 'payload\lib\features\call\schools\learn_sheet.dart'; OldHash = '007a5fef70ba69fe98d85a67ec5b79f3f87e44b6387af25bf407fc442cb61ba5'; PackageHash = 'a133daa24dd39a4f9f21b7aeed200e2c48a618a9ee4c042d08b74a2158ad909c' },
  @{ Target = 'lib\features\call\schools\school_dialog_new.dart'; Source = 'payload\lib\features\call\schools\school_dialog_new.dart'; OldHash = '31fa74166eaceab1e61fbc136846ab44a1de526febb5960de01f34cbc7f78e90'; PackageHash = 'd9d46e2441743d32353a703a7c5b0f7e9893b6e19a9e16ac2e7872c040e3c5cc' },
  @{ Target = 'lib\features\call\video_overlay.dart'; Source = 'payload\lib\features\call\video_overlay.dart'; OldHash = '1309f6294e773526b56ce071907b23da9cf13057913fc47342ef90410c8e6a52'; PackageHash = '636c8b5dbab7643ecab1bcc3be857a983c41aebf93cb559472390e6be4c6c429' },
  @{ Target = 'lib\features\call\video_window.dart'; Source = 'payload\lib\features\call\video_window.dart'; OldHash = '51c5877878f09471c0dfb04f5a7a674ace69aa619b95841d5f0bbb08f660115c'; PackageHash = '5b8f3dc8000e08bd2047856ec6d661355dbf7c500e8bcb0841fe8fe2fb9fdb49' },
  @{ Target = 'lib\landing_page.dart'; Source = 'payload\lib\landing_page.dart'; OldHash = 'a54e9fa5785ea041507d996db33a022a912da416658f7b735c7327b018b705e5'; PackageHash = 'e4586702ae138868145fa3cd9fd614237f7d3e00189c43b1c28a66dbd9aec0aa' },
  @{ Target = 'lib\localization\makechess_localization.dart'; Source = 'payload\lib\localization\makechess_localization.dart'; OldHash = '10beb77c1d51b3135826af301ad2aba31af92829170da027d0b5e584e071bd85'; PackageHash = '67f75579303f38a5b5c485ecdcfbbeb7a20a1c1ee60190e73ed99c34299c461d' },
  @{ Target = 'lib\main.dart'; Source = 'payload\lib\main.dart'; OldHash = '250e1c91c9ab731e0d152550fe95dc99fa7a7acc3cfdc61b3e43caf60117e5db'; PackageHash = '476f31cf77eb8bd5e9b933fad48be6e433158a8442298a31c99da01898ffb48a' },
  @{ Target = 'lib\ui\app_shell.dart'; Source = 'payload\lib\ui\app_shell.dart'; OldHash = '632a93796610bac99da57b56542f3baeda6469af58647ba57fa0bb5fde9e4c01'; PackageHash = '9bf58e030a1ef1eb68c428249ab6bddf8d70d996b33f91dd9faf29a354ea7149' },
  @{ Target = 'lib\ui\assignments\teacher_assignment_dialog.dart'; Source = 'payload\lib\ui\assignments\teacher_assignment_dialog.dart'; OldHash = 'be88ee3ec0d6610e074e628c567220120337dffef69103b0a7dd9fa29a83aef0'; PackageHash = '518cd6b8cf909c886301134a0c647c795c4b573c01aec920c33bd2b8cd1dce2e' },
  @{ Target = 'lib\ui\common_top_bar.dart'; Source = 'payload\lib\ui\common_top_bar.dart'; OldHash = '74726c8b8109caaca33bd3186be3299268871e2284815db85ef365cc3b22196d'; PackageHash = '7db42094ee2572c003380ecdc068a49f1fbd2fe21ecb4336d115bd2e23fca4a7' },
  @{ Target = 'lib\ui\dialogs\board_theme_dialog.dart'; Source = 'payload\lib\ui\dialogs\board_theme_dialog.dart'; OldHash = 'a6cd3897b984bf03f34264649b688bd40395ff8c09909b6e06d734e59147a8b7'; PackageHash = '91640d2e09715120a63f2f69e86f59b605fc5e7adf73555f66c027e45fba5d23' },
  @{ Target = 'lib\ui\dialogs\board_theme_picker_dialog.dart'; Source = 'payload\lib\ui\dialogs\board_theme_picker_dialog.dart'; OldHash = '515f25a25ae21811ac91e811134b71f461d6e16cc16f75e4d0274e5637b1af94'; PackageHash = '94934308cea81b0ed8ca9b78c558942cbf4f040b91677555e0e93d7fa2c0f814' },
  @{ Target = 'lib\ui\dialogs\personal_cabinet_dialog.dart'; Source = 'payload\lib\ui\dialogs\personal_cabinet_dialog.dart'; OldHash = '27bba6d4a8b660952895a4b58d12bdf1e164a848c83536876770f7e449de15e3'; PackageHash = '96a4de180021fbfbed2d5f1d4a8f828dd7ca857da0d61aa0147b3973a79c288c' },
  @{ Target = 'lib\ui\dialogs\site_settings_dialog.dart'; Source = 'payload\lib\ui\dialogs\site_settings_dialog.dart'; OldHash = 'c9a90e1ed846653a6778dbfff56cb933170778443dd8e104ccbab8884a924358'; PackageHash = 'ca793a863d716db19139f8f216b8c619985813918c91156dfea26408ddef993c' },
  @{ Target = 'lib\ui\dialogs\teacher_access_dialog.dart'; Source = 'payload\lib\ui\dialogs\teacher_access_dialog.dart'; OldHash = 'a77bea711ec8cf17dad9645bf0218b98712e339e71be2bf8700721297b596d6f'; PackageHash = 'bc5ba974531d886af679c659a913743e456df0d2117c8d1dd98d78bbaecc6419' },
  @{ Target = 'lib\ui\messages\general_messages_dialog.dart'; Source = 'payload\lib\ui\messages\general_messages_dialog.dart'; OldHash = '503487d2271f3b695e21c2c27319a6b2bea01fa0f0c171ef0e5e4a841202e9a9'; PackageHash = '03da9fa9944a94ebe774642dd47c5be43936dbf379175c1ca8c68fda63b47d03' },
  @{ Target = 'lib\ui\panels\auth_widgets.dart'; Source = 'payload\lib\ui\panels\auth_widgets.dart'; OldHash = '0824fda2fc57095b15634edaa94cca2bab83289a516c5df878e9c67d28b7d83d'; PackageHash = '6e70138ba5cb0322ae6a183cd6558e4b93e8acecb424e7e242153e3aceb3c30c' },
  @{ Target = 'lib\ui\panels\learn_panel.dart'; Source = 'payload\lib\ui\panels\learn_panel.dart'; OldHash = '2e2dd79c9444211e4e66d50f87b59ba7b7492dc4a03cc4297fbb06cf559da92c'; PackageHash = 'd7ddc95c6484cbba82ccfebee78e80781a953d01ccf6b8fa758f826eacd00610' },
  @{ Target = 'lib\ui\panels\move_list_panel.dart'; Source = 'payload\lib\ui\panels\move_list_panel.dart'; OldHash = 'de36cd9879811714cfb06f212ba4c4ee20b7d8be284086d59c77a91856cbd64d'; PackageHash = '9877ac6822476d8915b9e959a6909bffb45fbf3b767e1fac4e54ebba2fc6d5ef' },
  @{ Target = 'lib\ui\panels\opening_trainer.dart'; Source = 'payload\lib\ui\panels\opening_trainer.dart'; OldHash = '7100034f5788f3f88754887f4af044603cd6b2475b33f86e10d3a41fd95a4dd0'; PackageHash = '4efb042a1392d4929374495282f01269367559316ef7b8950ae2fffeba591d3c' },
  @{ Target = 'lib\ui\panels\puzzle_settings_dialog.dart'; Source = 'payload\lib\ui\panels\puzzle_settings_dialog.dart'; OldHash = '7bdc0e13d6a434ded359e452d44a1ff5e4dcb5306dbd5547efc3e3756f2dbc6f'; PackageHash = 'c3573f9b8d208aa0e3ea1c43bb154235cb4427308f98b0650f1c6d99537adc0e' },
  @{ Target = 'lib\ui\panels\puzzle_types_panel.dart'; Source = 'payload\lib\ui\panels\puzzle_types_panel.dart'; OldHash = '892b502fb719d9e1239f6e3d256d0678e3a8359fb6efe51585543796b2df9d57'; PackageHash = 'a5b0e161e7579170ecd9c48b83fad8798da2993a7fffb2dd3f05caca44f5bf5c' },
  @{ Target = 'lib\ui\panels\room_chat_panel.dart'; Source = 'payload\lib\ui\panels\room_chat_panel.dart'; OldHash = '8eca715a97ff0d213cf26ac08bb81642f161268ce3e28492c3dad909356dd21e'; PackageHash = 'd971c8967c7ae2b4c21e98139826f05398107c1349b8716ab7e91eb5b3770c74' },
  @{ Target = 'lib\ui\payment_modal.dart.dart'; Source = 'payload\lib\ui\payment_modal.dart.dart'; OldHash = '919d638b46342d9d9a3adbd0bd92c38ffb5a79191f3328e106d67648bf4bc1a7'; PackageHash = 'a6354e9bac96693c6027bffe5b75fa27f470e1585576a3e9c0d7140d5334811d' },
  @{ Target = 'lib\ui\start_modal.dart'; Source = 'payload\lib\ui\start_modal.dart'; OldHash = '4880bc84cdb7b7b9c454aeedf0db937b33ecb92b5463adc4e255d485cc430cf3'; PackageHash = '20b36b648a2e835e91253d947a6da01a841f55164f357f31082b9b3224ba63e3' },
  @{ Target = 'lib\ui\tournament\student_tournaments_dialog.dart'; Source = 'payload\lib\ui\tournament\student_tournaments_dialog.dart'; OldHash = 'c61db0f426ba1139c350de82ee03596f7aa25da3d6d6230410e4cd2330512423'; PackageHash = '8068148db241bbf08ef94bc6a10e72c4bcef48680d39d763dee14b20fc48d0ca' },
  @{ Target = 'lib\ui\tournament\tournament_game_platform_dialog.dart'; Source = 'payload\lib\ui\tournament\tournament_game_platform_dialog.dart'; OldHash = '5b42eddf0e050acd1d19f7943aad1a66b4b3f751ff37dd4afc6a06e813f39c42'; PackageHash = '1613ddcc3eed040d43a13fe5fea945c864ad953ad4834ed27b5a6ea0e4ff3097' },
  @{ Target = 'lib\ui\tournament\tournament_manager_dialog.dart'; Source = 'payload\lib\ui\tournament\tournament_manager_dialog.dart'; OldHash = '0460f0c590a8ce07eeef5b54bb47f5f16f2a75b066f81fdc7a4ebb791b75efb1'; PackageHash = '63719307a578b62e9ede7a4e9ced8a371fa945926fa8591d52f64945b70f104f' },
  @{ Target = 'lib\ui\tournament\tournament_pairing_control_dialog.dart'; Source = 'payload\lib\ui\tournament\tournament_pairing_control_dialog.dart'; OldHash = 'cdb2407860cfbbd80e2fac010996000f0ed071d1c0bee970bba1e9b32a8b7450'; PackageHash = 'a0c734c2d49c022445c4185f2c523d2579e8ae95b9cddb9c36a2cd44bd8dc1d1' },
  @{ Target = 'lib\ui\tournament\tournament_participant_picker_dialog.dart'; Source = 'payload\lib\ui\tournament\tournament_participant_picker_dialog.dart'; OldHash = '5c4a2f9af6585d49030fc8e609cd377bcf4a0b36fd7b3b8ada3a5d6ff9eda04e'; PackageHash = '6ecf748761fc17adcdcf620857b3ce0201e13094fbab3300c869d880cc1a83e0' },
  @{ Target = 'lib\ui\tournament\tournament_table_editor.dart'; Source = 'payload\lib\ui\tournament\tournament_table_editor.dart'; OldHash = '7a99181c614316b1361f4a461652705c05e70ade341ef5b9c33661f13ff54262'; PackageHash = '9c40e4483a602ca839d001b3ac856085c70afc837614700924eb45d2feef840f' },
  @{ Target = 'lib\ui\video_window.dart'; Source = 'payload\lib\ui\video_window.dart'; OldHash = '215fb0c08ff2fc0e34436c6f8ceb481ca22927c92b8e6c0dac22f7a3ca48f6f1'; PackageHash = 'c6fec6e167161d1a6d2c1c5086c9d693c5b43734bc070a3f703fa3e4985fb25c' },
  @{ Target = 'lib\widgets\eval_bar.dart'; Source = 'payload\lib\widgets\eval_bar.dart'; OldHash = '3f049a98167a154ebca207361eca4f427831a54f21651a8729029618fd08e9d5'; PackageHash = '80c824c1a200b983ffff8fc3d486024b8e56ce9751d905b1ca8341e8a3936b87' }
)

function Get-Sha256([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " MAKECHESS - ALL RUSSIAN UI LOCALIZATION V5" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/8] Checking V5 package hashes..." -ForegroundColor Cyan
foreach ($item in $items) {
  $sourcePath = Join-Path $PackageRoot $item.Source
  if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "PACKAGE ERROR: missing source file: $($item.Source)"
  }
  if ((Get-Sha256 $sourcePath) -ne $item.PackageHash) {
    throw "PACKAGE ERROR: source hash mismatch: $($item.Source)"
  }
}

Write-Host "[2/8] Checking the exact current files from YOUR V5 collector..." -ForegroundColor Cyan
foreach ($item in $items) {
  $targetPath = Join-Path $ProjectRoot $item.Target
  if (-not (Test-Path -LiteralPath $targetPath)) {
    throw "SAFETY STOP: target file missing: $($item.Target). Nothing changed."
  }

  $currentHash = Get-Sha256 $targetPath
  if ($currentHash -ne $item.OldHash) {
    throw "SAFETY STOP: $($item.Target) changed after MAKECHESS_CURRENT_ALL_RUSSIAN_UI_V5_FILES.zip was created. Nothing changed."
  }
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $ProjectRoot "localization_backups\ALL_RUSSIAN_UI_V5_$stamp"

Write-Host "[3/8] Creating exact backups of 40 files..." -ForegroundColor Cyan
foreach ($item in $items) {
  $targetPath = Join-Path $ProjectRoot $item.Target
  $backupPath = Join-Path $backupDir $item.Target
  $backupParent = Split-Path -Parent $backupPath
  New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
  Copy-Item -LiteralPath $targetPath -Destination $backupPath -Force
}

try {
  Write-Host "[4/8] Installing the broad V5 localization pass..." -ForegroundColor Cyan
  foreach ($item in $items) {
    $sourcePath = Join-Path $PackageRoot $item.Source
    $targetPath = Join-Path $ProjectRoot $item.Target
    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
  }

  Write-Host "[5/8] Running Dart parser/formatter on all changed files..." -ForegroundColor Cyan
  $dart = Get-Command dart -ErrorAction SilentlyContinue
  if ($null -ne $dart) {
    $formatTargets = @()
    foreach ($item in $items) {
      $formatTargets += (Join-Path $ProjectRoot $item.Target)
    }
    & $dart.Source format @formatTargets | Out-Host
    if ($LASTEXITCODE -ne 0) {
      throw "dart format reported a Dart syntax error."
    }
  } else {
    Write-Host "Dart is not in PATH. PUBLISH_MAKECHESS.cmd will perform final compilation." -ForegroundColor Yellow
  }

  Write-Host "[6/8] Checking central localization..." -ForegroundColor Cyan
  $locPath = Join-Path $ProjectRoot "lib\localization\makechess_localization.dart"
  $loc = [System.IO.File]::ReadAllText($locPath)

  foreach ($marker in @(
    "MAKECHESS_CENTRAL_LOCALIZATION_V5_20260807",
    "MAKECHESS_ALL_RUSSIAN_UI_V5_PHRASES_20260807",
    "MAKECHESS_ALL_RUSSIAN_UI_V5_DYNAMIC_ROW_20260807",
    "MAKECHESS_CENTRAL_LOCALIZATION_MESSAGES_TOURNAMENTS_V3_2_20260807",
    "MAKECHESS_BIG_LOCALIZATION_STAGE_V4_PHRASES_20260807",
    "class MakeChessLocalization",
    "class MakeChessLocalizedText",
    "_v5ExactPhrase",
    "_v5DynamicPhrase"
  )) {
    if (-not $loc.Contains($marker)) {
      throw "Localization verification failed: $marker"
    }
  }

  foreach ($code in @("RU","EN","DE","FR","ES","AR","ZH","HI","JA","KO","VI")) {
    if (-not $loc.Contains("'$code'")) {
      throw "Localization language missing: $code"
    }
  }

  Write-Host "[7/8] Checking real functional markers..." -ForegroundColor Cyan

  $checks = @(
    @("lib\main.dart", "class MyHomePage"),
    @("lib\ui\app_shell.dart", "class AppShell extends StatefulWidget"),
    @("lib\ui\common_top_bar.dart", "makechessLearningTopBarLabel"),
    @("lib\ui\panels\learn_panel.dart", "class LearningPanel extends StatefulWidget"),
    @("lib\ui\panels\opening_trainer.dart", "MAKECHESS_OPENING_ADD_VARIANT_V16_20260806"),
    @("lib\ui\panels\opening_trainer.dart", "OPENING_TRAINER_PROGRAMMABLE_BOT_V8_20260805"),
    @("lib\ui\panels\opening_trainer.dart", "MAKECHESS_OPENING_DISPLAY_NAME_V5_20260807"),
    @("lib\ui\tournament\tournament_manager_dialog.dart", "TournamentStorageService.instance"),
    @("lib\ui\tournament\tournament_table_editor.dart", "showTournamentTableEditor"),
    @("lib\ui\messages\general_messages_dialog.dart", "class MakeChessMessageRealtimeService"),
    @("lib\ui\assignments\teacher_assignment_dialog.dart", "showTeacherAssignmentBuilderDialog")
  )

  foreach ($check in $checks) {
    $path = Join-Path $ProjectRoot $check[0]
    $text = [System.IO.File]::ReadAllText($path)
    if (-not $text.Contains($check[1])) {
      throw "Functional marker missing: $($check[0]) :: $($check[1])"
    }
  }

  Write-Host "[8/8] Checking V5 UI markers..." -ForegroundColor Cyan
  $markedCount = 0
  foreach ($item in $items) {
    if ($item.Target -eq "lib\localization\makechess_localization.dart") {
      continue
    }
    $path = Join-Path $ProjectRoot $item.Target
    $text = [System.IO.File]::ReadAllText($path)
    if ($text.Contains("MAKECHESS_ALL_RUSSIAN_UI_V5_20260807")) {
      $markedCount++
    }
  }

  if ($markedCount -lt 39) {
    throw "V5 UI marker count is too small: $markedCount"
  }
}
catch {
  Write-Host ""
  Write-Host "ERROR: restoring all 40 exact files from the V5 backup..." -ForegroundColor Red

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
Write-Host "DONE: ALL RUSSIAN UI LOCALIZATION V5.1 installed." -ForegroundColor Green
Write-Host "Changed files: 40" -ForegroundColor Green
Write-Host "New exact phrase rows: 283" -ForegroundColor Green
Write-Host "New dynamic phrase patterns: 38" -ForegroundColor Green
Write-Host "Languages: RU EN DE FR ES AR ZH HI JA KO VI" -ForegroundColor Green
Write-Host "Opening catalog: Russian names in RU, original English names in other languages." -ForegroundColor Green
Write-Host ""
Write-Host "Backup:"
Write-Host "  $backupDir"
Write-Host ""
Write-Host "Next command:"
Write-Host "  .\PUBLISH_MAKECHESS.cmd"
