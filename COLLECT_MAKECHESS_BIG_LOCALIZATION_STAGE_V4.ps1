param(
  [string]$ProjectRoot = "C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$OutZip = Join-Path $ProjectRoot "MAKECHESS_CURRENT_BIG_LOCALIZATION_STAGE_V4_FILES.zip"
$TempRoot = Join-Path $env:TEMP "makechess_big_localization_stage_v4"

$files = @(
  "lib\localization\makechess_localization.dart",
  "lib\ui\app_shell.dart",
  "lib\ui\common_top_bar.dart",
  "lib\ui\panels\learn_panel.dart",
  "lib\ui\panels\puzzle_types_panel.dart",
  "lib\ui\panels\puzzle_settings_dialog.dart",
  "lib\ui\panels\opening_trainer.dart",
  "lib\ui\panels\room_chat_panel.dart",
  "lib\ui\assignments\teacher_assignment_dialog.dart",
  "lib\ui\tournament\tournament_manager_dialog.dart",
  "lib\ui\tournament\tournament_table_editor.dart",
  "lib\ui\dialogs\site_settings_dialog.dart",
  "lib\ui\dialogs\board_theme_picker_dialog.dart",
  "lib\ui\dialogs\personal_cabinet_dialog.dart",
  "lib\ui\start_modal.dart"
)

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " MAKECHESS - BIG LOCALIZATION STAGE V4 FILE COLLECTOR" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if (Test-Path -LiteralPath $TempRoot) {
  Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

$manifest = New-Object System.Collections.Generic.List[string]
$manifest.Add("MAKECHESS BIG LOCALIZATION STAGE V4")
$manifest.Add("Project root: $ProjectRoot")
$manifest.Add("Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$manifest.Add("")
$manifest.Add("Collected files:")

$copied = 0
$missing = 0

foreach ($relative in $files) {
  $source = Join-Path $ProjectRoot $relative

  if (-not (Test-Path -LiteralPath $source)) {
    Write-Host "SKIP - not found: $relative" -ForegroundColor Yellow
    $manifest.Add("MISSING: $relative")
    $missing++
    continue
  }

  $destination = Join-Path $TempRoot $relative
  $destinationDir = Split-Path -Parent $destination
  New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
  Copy-Item -LiteralPath $source -Destination $destination -Force

  Write-Host "OK   - $relative" -ForegroundColor Green
  $manifest.Add("OK: $relative")
  $copied++
}

$manifest.Add("")
$manifest.Add("Copied: $copied")
$manifest.Add("Missing: $missing")
$manifest | Set-Content -LiteralPath (Join-Path $TempRoot "MAKECHESS_BIG_LOCALIZATION_STAGE_V4_MANIFEST.txt") -Encoding UTF8

if ($copied -lt 8) {
  throw "Too few current files were found ($copied). Nothing in the project was changed."
}

if (Test-Path -LiteralPath $OutZip) {
  Remove-Item -LiteralPath $OutZip -Force
}

Write-Host ""
Write-Host "Creating ZIP..." -ForegroundColor Cyan

Push-Location $TempRoot
try {
  & tar -a -c -f $OutZip .
  if ($LASTEXITCODE -ne 0) {
    throw "ZIP creation failed."
  }
}
finally {
  Pop-Location
}

Remove-Item -LiteralPath $TempRoot -Recurse -Force

Write-Host ""
Write-Host "DONE." -ForegroundColor Green
Write-Host "No project source file was changed." -ForegroundColor Green
Write-Host ""
Write-Host "Created:" -ForegroundColor Cyan
Write-Host "  $OutZip"
Write-Host ""
Write-Host "Send this ZIP to ChatGPT." -ForegroundColor Cyan
