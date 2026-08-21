param(
  [string]$ProjectRoot = ""
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = $PSScriptRoot
}
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$payload = Join-Path $PSScriptRoot 'V5_TEXT_PATCH_FILES'
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
  if ($start -lt 0) { throw "Dart method not found: $Signature" }
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
function Replace-LocalButtonBlock {
  param([string]$Text, [string]$Template)

  $needle = 'valueListenable: sf.localStockfishEnabledNotifier'
  $stateIndex = $Text.IndexOf($needle, [System.StringComparison]::Ordinal)
  if ($stateIndex -lt 0) {
    throw 'Local Stockfish state builder was not found in right_sidebar_panel.dart.'
  }

  $expandedIndex = $Text.LastIndexOf('Expanded(', $stateIndex, [System.StringComparison]::Ordinal)
  if ($expandedIndex -lt 0) { throw 'Expanded widget for Local Stockfish was not found.' }

  $lineStart = $Text.LastIndexOf("`n", $expandedIndex)
  if ($lineStart -lt 0) { $lineStart = -1 }
  $blockStart = $lineStart + 1
  $indent = $Text.Substring($blockStart, $expandedIndex - $blockStart)

  $openParen = $Text.IndexOf('(', $expandedIndex)
  if ($openParen -lt 0) { throw 'Opening parenthesis for Local Stockfish block was not found.' }

  $depth = 0
  $closeParen = -1
  for ($i = $openParen; $i -lt $Text.Length; $i++) {
    $c = $Text[$i]
    if ($c -eq '(') { $depth++ }
    elseif ($c -eq ')') {
      $depth--
      if ($depth -eq 0) {
        $closeParen = $i
        break
      }
    }
  }
  if ($closeParen -lt 0) { throw 'Closing parenthesis for Local Stockfish block was not found.' }

  $blockEnd = $closeParen + 1
  if ($blockEnd -lt $Text.Length -and $Text[$blockEnd] -eq ',') { $blockEnd++ }

  $templateLf = Normalize-Lf $Template
  $lines = $templateLf.TrimEnd("`n").Split("`n")
  $newBlock = (($lines | ForEach-Object { $indent + $_ }) -join "`n")

  return $Text.Substring(0, $blockStart) + $newBlock + $Text.Substring($blockEnd)
}

$pubspecPath = Join-Path $ProjectRoot 'pubspec.yaml'
$mainPath = Join-Path $ProjectRoot 'lib\main.dart'
$panelPath = Join-Path $ProjectRoot 'lib\ui\panels\right_sidebar_panel.dart'
$localizationPath = Join-Path $ProjectRoot 'lib\localization\makechess_localization.dart'

foreach ($path in @($pubspecPath, $mainPath, $panelPath, $localizationPath)) {
  if (-not (Test-Path -LiteralPath $path)) { throw "Required file not found: $path" }
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = Join-Path $ProjectRoot "_backup_local_stockfish_texts_v5_$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

foreach ($pair in @(
  @($mainPath, 'lib\main.dart'),
  @($panelPath, 'lib\ui\panels\right_sidebar_panel.dart'),
  @($localizationPath, 'lib\localization\makechess_localization.dart')
)) {
  $dst = Join-Path $backupDir $pair[1]
  New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($dst)) | Out-Null
  Copy-Item -LiteralPath $pair[0] -Destination $dst -Force
}
Write-Host "BACKUP_OK: $backupDir" -ForegroundColor DarkGray

$toggleFragment = Read-Utf8 (Join-Path $payload 'toggle_method.dartfrag')
$buttonFragment = Read-Utf8 (Join-Path $payload 'button_block.dartfrag')
$rowsFragment = Read-Utf8 (Join-Path $payload 'localization_rows.dartfrag')

$main = Normalize-Lf (Read-Utf8 $mainPath)
$main = Replace-DartMethod -Text $main -Signature '  Future<void> _toggleLocalStockfish() async' -Replacement (Normalize-Lf $toggleFragment).TrimEnd("`n")
Write-Utf8 $mainPath $main
Write-Host 'MAIN_TEXTS_OK' -ForegroundColor Green

$panel = Normalize-Lf (Read-Utf8 $panelPath)
$panel = Replace-LocalButtonBlock -Text $panel -Template $buttonFragment
Write-Utf8 $panelPath $panel
Write-Host 'RIGHT_SIDEBAR_TEXT_OK' -ForegroundColor Green

$loc = Normalize-Lf (Read-Utf8 $localizationPath)
$marker = 'MAKECHESS_LOCAL_STOCKFISH_TEXTS_V5_20260817'
if (-not $loc.Contains($marker)) {
  $anchor = 'static const Map<String, List<String>> _v6PhraseRows = <String, List<String>>{'
  $anchorIndex = $loc.IndexOf($anchor, [System.StringComparison]::Ordinal)
  if ($anchorIndex -lt 0) { throw 'Localization V6 phrase map anchor was not found.' }
  $insertAt = $anchorIndex + $anchor.Length
  $loc = $loc.Substring(0, $insertAt) + "`n" + (Normalize-Lf $rowsFragment).TrimEnd("`n") + $loc.Substring($insertAt)
}
Write-Utf8 $localizationPath $loc
Write-Host 'LOCALIZATION_11_LANGUAGES_OK' -ForegroundColor Green

# ASCII-only structural verification. Human text lives only in UTF-8 payload files.
$mainCheck = Read-Utf8 $mainPath
$panelCheck = Read-Utf8 $panelPath
$locCheck = Read-Utf8 $localizationPath
if (-not $mainCheck.Contains("MakeChessLocalization.phrase(")) { throw 'Localized toggle messages were not installed.' }
if (-not $panelCheck.Contains('MakeChessLocalizationController.languageCode')) { throw 'Button language listener was not installed.' }
if (-not $locCheck.Contains($marker)) { throw 'Localization rows marker is missing.' }

Write-Host ''
Write-Host '=========================================================='
Write-Host 'LOCAL_STOCKFISH_TEXT_FIX_V5_OK' -ForegroundColor Green
Write-Host '=========================================================='
Write-Host 'Button text is now UTF-8 and localized in 11 languages.'
Write-Host 'Stockfish engine logic was not changed.'
Write-Host ''
Write-Host 'NEXT: run PUBLISH_MAKECHESS.cmd, then Ctrl+F5 on makechess.com'
