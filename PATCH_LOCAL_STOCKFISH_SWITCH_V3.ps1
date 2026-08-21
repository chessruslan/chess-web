param(
  [string]$ProjectRoot = ""
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = $PSScriptRoot
}
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$payload = Join-Path $PSScriptRoot 'V3_PATCH_FILES'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Read-Utf8([string]$Path) {
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}
function Write-Utf8([string]$Path, [string]$Text) {
  [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}
function Normalize-Lf([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}
function Replace-DartMethod {
  param(
    [string]$Text,
    [string]$Signature,
    [string]$Replacement
  )
  $start = $Text.IndexOf($Signature, [System.StringComparison]::Ordinal)
  if ($start -lt 0) {
    throw "Dart method not found: $Signature"
  }
  $brace = $Text.IndexOf('{', $start)
  if ($brace -lt 0) { throw "Opening brace not found for: $Signature" }
  $depth = 0
  $finish = -1
  for ($i = $brace; $i -lt $Text.Length; $i++) {
    $c = $Text[$i]
    if ($c -eq '{') { $depth++ }
    elseif ($c -eq '}') {
      $depth--
      if ($depth -eq 0) {
        $finish = $i + 1
        break
      }
    }
  }
  if ($finish -lt 0) { throw "Closing brace not found for: $Signature" }
  return $Text.Substring(0, $start) + $Replacement + $Text.Substring($finish)
}

if (-not (Test-Path (Join-Path $ProjectRoot 'pubspec.yaml'))) {
  throw "Run this patch from the MakeChess project root (pubspec.yaml not found): $ProjectRoot"
}
if (-not (Test-Path $payload)) {
  throw "Payload folder not found: $payload"
}

$pubspecPath = Join-Path $ProjectRoot 'pubspec.yaml'
$mainPath = Join-Path $ProjectRoot 'lib\main.dart'
$panelPath = Join-Path $ProjectRoot 'lib\ui\panels\right_sidebar_panel.dart'
$rootSfPath = Join-Path $ProjectRoot 'lib\stockfish_service.dart'
$localAppPath = Join-Path $ProjectRoot 'lib\stockfish_test_app.dart'
$ioPath = Join-Path $ProjectRoot 'lib\services\stockfish\stockfish_service_io.dart'
$localExporterPath = Join-Path $ProjectRoot 'lib\services\stockfish\stockfish_service.dart'
$localModelsPath = Join-Path $ProjectRoot 'lib\services\stockfish\stockfish_models.dart'
$localStubPath = Join-Path $ProjectRoot 'lib\services\stockfish\stockfish_service_stub.dart'

foreach ($path in @($mainPath, $panelPath, $rootSfPath, $localAppPath, $ioPath)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Required project file not found: $path"
  }
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = Join-Path $ProjectRoot "_backup_local_stockfish_switch_v3_$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

$backupPairs = @(
  @($pubspecPath, 'pubspec.yaml'),
  @($mainPath, 'lib\main.dart'),
  @($panelPath, 'lib\ui\panels\right_sidebar_panel.dart'),
  @($rootSfPath, 'lib\stockfish_service.dart'),
  @($localAppPath, 'lib\stockfish_test_app.dart'),
  @($ioPath, 'lib\services\stockfish\stockfish_service_io.dart')
)
foreach ($pair in $backupPairs) {
  $source = $pair[0]
  $rel = $pair[1]
  $dst = Join-Path $backupDir $rel
  New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($dst)) | Out-Null
  Copy-Item -LiteralPath $source -Destination $dst -Force
}
foreach ($optionalBackup in @(
  @($localExporterPath, 'lib\services\stockfish\stockfish_service.dart'),
  @($localModelsPath, 'lib\services\stockfish\stockfish_models.dart'),
  @($localStubPath, 'lib\services\stockfish\stockfish_service_stub.dart')
)) {
  if (Test-Path -LiteralPath $optionalBackup[0]) {
    $dst = Join-Path $backupDir $optionalBackup[1]
    New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($dst)) | Out-Null
    Copy-Item -LiteralPath $optionalBackup[0] -Destination $dst -Force
  }
}
Write-Host "BACKUP_OK: $backupDir" -ForegroundColor DarkGray

# Install the global router, untouched network backend and local bridge files.
$copyPairs = @(
  @('lib\stockfish_service.dart', 'lib\stockfish_service.dart'),
  @('lib\stockfish_network_service.dart', 'lib\stockfish_network_service.dart'),
  @('lib\stockfish_test_app.dart', 'lib\stockfish_test_app.dart'),
  @('lib\services\stockfish\stockfish_service.dart', 'lib\services\stockfish\stockfish_service.dart'),
  @('lib\services\stockfish\stockfish_models.dart', 'lib\services\stockfish\stockfish_models.dart'),
  @('lib\services\stockfish\stockfish_service_stub.dart', 'lib\services\stockfish\stockfish_service_stub.dart'),
  @('lib\services\stockfish\stockfish_service_io.dart', 'lib\services\stockfish\stockfish_service_io.dart')
)
foreach ($pair in $copyPairs) {
  $src = Join-Path $payload $pair[0]
  $dst = Join-Path $ProjectRoot $pair[1]
  New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($dst)) | Out-Null
  Copy-Item -LiteralPath $src -Destination $dst -Force
}
Write-Host 'ROUTER_AND_BRIDGE_FILES_OK' -ForegroundColor Green

# ---- Surgical main.dart patch ----
$main = Normalize-Lf (Read-Utf8 $mainPath)

if ($main.Contains('Future<void> _openLocalStockfish(String fen) async')) {
$newMethod = @'
  Future<void> _toggleLocalStockfish() async {
    if (LichessPlayGuard.instance.active) return;

    try {
      final enabled = await sf.toggleLocalStockfish();
      if (!mounted) return;

      // Repaint every place that reflects the selected engine immediately.
      setState(() {});
      unawaited(_refreshEvalBar());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: MakeChessLocalizedText(
            enabled
                ? 'Локальный Stockfish ВКЛЮЧЁН. Весь анализ сайта теперь выполняется локально.'
                : 'Локальный Stockfish ВЫКЛЮЧЕН. Сайт снова использует сетевой Stockfish.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: MakeChessLocalizedText(
            'Не удалось включить локальный Stockfish: $e',
          ),
        ),
      );
    }
  }
'@
  $main = Replace-DartMethod -Text $main -Signature '  Future<void> _openLocalStockfish(String fen) async' -Replacement $newMethod
}
elseif (-not $main.Contains('Future<void> _toggleLocalStockfish() async')) {
  throw 'Neither old nor new Local Stockfish method was found in lib\main.dart.'
}

# Every former "send this FEN to local window" button now toggles the global backend.
$main = [regex]::Replace(
  $main,
  'await\s+_openLocalStockfish\([^;]*\);',
  'await _toggleLocalStockfish();'
)

# Local backend must receive the real FEN. Network sanitization belongs only in
# stockfish_network_service.dart.
$main = [regex]::Replace(
  $main,
  '(?m)^\s*final fenForApi = stripEpField\(saneFen\);\n',
  ''
)
$main = $main.Replace('fenForApi,', 'saneFen,')

if ($main.Contains('_openLocalStockfish(')) {
  throw 'Old _openLocalStockfish call remains in main.dart; aborting.'
}
if (-not $main.Contains('sf.toggleLocalStockfish()')) {
  throw 'Global Stockfish toggle was not installed into main.dart.'
}
Write-Utf8 $mainPath $main
Write-Host 'MAIN_TOGGLE_PATCH_OK' -ForegroundColor Green

# ---- Right sidebar: persistent visual ON marker ----
$panel = Normalize-Lf (Read-Utf8 $panelPath)
$routerImport = "import '../../stockfish_service.dart' as sf;"
if (-not $panel.Contains($routerImport)) {
  $anchor = "import '../../services/lichess_service.dart';"
  if (-not $panel.Contains($anchor)) {
    throw 'Could not find right-sidebar import anchor.'
  }
  $panel = $panel.Replace($anchor, $anchor + "`n" + $routerImport)
}

$oldLocalBlock = @'
                Expanded(
                  child: AppNeoButton(
                    text: loading
                        ? MakeChessLocalization.text(MakeChessTextKey.loading)
                        : MakeChessLocalization.phrase('Локальный Stockfish'),
                    icon: Icons.memory_outlined,
                    onTap: assistanceDisabled || loading
                        ? null
                        : () {
                            onBestMove();
                          },
                    showIcon: !compact,
                    compact: compact,
                  ),
                ),
'@

$oldBestMoveBlock = @'
                Expanded(
                  child: AppNeoButton(
                    text: loading
                        ? MakeChessLocalization.text(MakeChessTextKey.loading)
                        : MakeChessLocalization.text(MakeChessTextKey.bestMove),
                    icon: Icons.flash_on,
                    onTap: assistanceDisabled || loading
                        ? null
                        : () {
                            onBestMove();
                          },
                    showIcon: !compact,
                    compact: compact,
                  ),
                ),
'@

$newBlock = @'
                Expanded(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: sf.localStockfishEnabledNotifier,
                    builder: (context, localEnabled, _) {
                      final localText =
                          MakeChessLocalization.phrase('Локальный Stockfish');
                      return AppNeoButton(
                        text: loading
                            ? MakeChessLocalization.text(
                                MakeChessTextKey.loading,
                              )
                            : (localEnabled ? '$localText ✓' : localText),
                        icon: localEnabled
                            ? Icons.memory
                            : Icons.memory_outlined,
                        onTap: assistanceDisabled || loading
                            ? null
                            : () {
                                onBestMove();
                              },
                        showIcon: !compact,
                        compact: compact,
                      );
                    },
                  ),
                ),
'@

if (-not $panel.Contains('valueListenable: sf.localStockfishEnabledNotifier')) {
  if ($panel.Contains($oldLocalBlock)) {
    $panel = $panel.Replace($oldLocalBlock, $newBlock)
  }
  elseif ($panel.Contains($oldBestMoveBlock)) {
    $panel = $panel.Replace($oldBestMoveBlock, $newBlock)
  }
  else {
    throw 'Could not find Local Stockfish / Best Move button block in right_sidebar_panel.dart.'
  }
}
Write-Utf8 $panelPath $panel
Write-Host 'RIGHT_SIDEBAR_SWITCH_INDICATOR_OK' -ForegroundColor Green

Write-Host ''
Write-Host 'SOURCE_PATCH_OK' -ForegroundColor Green
Write-Host "Backup: $backupDir"
