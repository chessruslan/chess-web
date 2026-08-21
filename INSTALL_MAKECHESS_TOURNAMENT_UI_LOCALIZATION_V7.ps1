param(
  [string]$ProjectRoot = "C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$source = Join-Path $PackageRoot "makechess_localization.dart"
$target = Join-Path $ProjectRoot "lib\localization\makechess_localization.dart"

$expectedOld = "ca15a66f19a5baf626253c53a86a0423a46888e337a5eb31e08f9e55672ec1f5"
$expectedNew = "d7454b07c1aa51af031cad1ff1be4e81ef114897c07eacf9b856b586e09910a2"

function Get-Sha256([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " MAKECHESS - TOURNAMENT UI LOCALIZATION V7" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path -LiteralPath $source)) {
  throw "PACKAGE ERROR: makechess_localization.dart is missing."
}
if ((Get-Sha256 $source) -ne $expectedNew) {
  throw "PACKAGE ERROR: replacement file hash mismatch."
}
if (-not (Test-Path -LiteralPath $target)) {
  throw "SAFETY STOP: current localization file is missing."
}

$current = Get-Sha256 $target
if ($current -eq $expectedNew) {
  Write-Host "ALREADY INSTALLED: V7 localization file is already present." -ForegroundColor Green
  exit 0
}
if ($current -ne $expectedOld) {
  throw "SAFETY STOP: makechess_localization.dart changed after you sent it. Nothing changed."
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $ProjectRoot "localization_backups\TOURNAMENT_UI_V7_$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$backup = Join-Path $backupDir "makechess_localization.dart"
Copy-Item -LiteralPath $target -Destination $backup -Force

try {
  Write-Host "[1/3] Replacing central localization only..." -ForegroundColor Cyan
  Copy-Item -LiteralPath $source -Destination $target -Force

  Write-Host "[2/3] Running Dart parser/formatter..." -ForegroundColor Cyan
  $dart = Get-Command dart -ErrorAction SilentlyContinue
  if ($null -ne $dart) {
    & $dart.Source format $target | Out-Host
    if ($LASTEXITCODE -ne 0) {
      throw "dart format reported a syntax error."
    }
  }

  Write-Host "[3/3] Checking V7 markers..." -ForegroundColor Cyan
  $text = [IO.File]::ReadAllText($target)
  foreach ($marker in @(
    "MAKECHESS_TOURNAMENT_UI_LOCALIZATION_V7_20260807",
    "MAKECHESS_TOURNAMENT_UI_LOCALIZATION_V7_PUNCTUATION_20260807",
    "MAKECHESS_REMAINING_UI_LOCALIZATION_V6_20260807",
    "MAKECHESS_CENTRAL_LOCALIZATION_V5_20260807"
  )) {
    if (-not $text.Contains($marker)) {
      throw "Verification failed: $marker"
    }
  }

  foreach ($phrase in @(
    '"Тип турнира": <String>[',
    '"Судья": <String>[',
    '"Место проведения": <String>[',
    '"Контроль времени": <String>[',
    '"Участник": <String>[',
    '"Учебный турнир": <String>[',
    '"Автоматическая жеребьёвка": <String>['
  )) {
    if (-not $text.Contains($phrase)) {
      throw "Tournament translation missing: $phrase"
    }
  }
}
catch {
  Write-Host ""
  Write-Host "ERROR: restoring previous localization file..." -ForegroundColor Red
  Copy-Item -LiteralPath $backup -Destination $target -Force
  throw
}

Write-Host ""
Write-Host "DONE: TOURNAMENT UI LOCALIZATION V7 installed." -ForegroundColor Green
Write-Host "Only the central localization file was replaced." -ForegroundColor Green
Write-Host "Tournament names and other user-entered data are NOT translated." -ForegroundColor Green
Write-Host ""
Write-Host "Next command:"
Write-Host "  .\PUBLISH_MAKECHESS.cmd"
