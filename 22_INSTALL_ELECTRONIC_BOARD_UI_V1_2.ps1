$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = [System.IO.Path]::GetFullPath($PSScriptRoot)
$PatchRoot = Join-Path $Root "PATCH_FILES"
$Site = Join-Path $Root "lib\ui\dialogs\site_settings_dialog.dart"
$Tournament = Join-Path $Root "lib\ui\tournament\tournament_manager_dialog.dart"
$Localization = Join-Path $Root "lib\localization\makechess_localization.dart"
$Panel = Join-Path $Root "lib\ui\dialogs\electronic_board_calibration_panel.dart"
$PatchPanel = Join-Path $PatchRoot "electronic_board_calibration_panel.dart"
$ReplacementsFile = Join-Path $PatchRoot "replacements.json"
$LocalizationEntriesFile = Join-Path $PatchRoot "localization_entries.txt"
$PublishCmd = Join-Path $Root "PUBLISH_MAKECHESS.cmd"
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Backup = Join-Path $Root ("_backup_electronic_board_ui_v1_2_" + $Stamp)
$ResultLog = Join-Path $Root "MAKECHESS_ELECTRONIC_BOARD_UI_V1_2_RESULT.txt"
$BuildLog = Join-Path $Root "MAKECHESS_ELECTRONIC_BOARD_UI_V1_2_BUILD.log"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Assert-File([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "FILE_NOT_FOUND: $Path"
    }
}

function Read-Normalized([string]$Path) {
    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    return [PSCustomObject]@{
        Text = $raw.Replace("`r`n", "`n")
        HadCrLf = $raw.Contains("`r`n")
    }
}

function Write-Preserved([string]$Path, [string]$Text, [bool]$HadCrLf) {
    $out = if ($HadCrLf) { $Text.Replace("`n", "`r`n") } else { $Text }
    [System.IO.File]::WriteAllText($Path, $out, $Utf8NoBom)
}

function Replace-Once([string]$Text, [string]$Before, [string]$After, [string]$Label) {
    $first = $Text.IndexOf($Before, [System.StringComparison]::Ordinal)
    if ($first -lt 0) {
        throw "PATCH_MARKER_NOT_FOUND: $Label"
    }
    $second = $Text.IndexOf($Before, $first + $Before.Length, [System.StringComparison]::Ordinal)
    if ($second -ge 0) {
        throw "PATCH_MARKER_NOT_UNIQUE: $Label"
    }
    return $Text.Substring(0, $first) + $After + $Text.Substring($first + $Before.Length)
}

function Restore-Backup {
    Write-Host ""
    Write-Host "Restoring files from backup..."
    Copy-Item -LiteralPath (Join-Path $Backup "site_settings_dialog.dart") -Destination $Site -Force
    Copy-Item -LiteralPath (Join-Path $Backup "tournament_manager_dialog.dart") -Destination $Tournament -Force
    Copy-Item -LiteralPath (Join-Path $Backup "makechess_localization.dart") -Destination $Localization -Force

    $panelBackup = Join-Path $Backup "electronic_board_calibration_panel.dart"
    if (Test-Path -LiteralPath $panelBackup) {
        Copy-Item -LiteralPath $panelBackup -Destination $Panel -Force
    } elseif (Test-Path -LiteralPath $Panel) {
        Remove-Item -LiteralPath $Panel -Force
    }
    Write-Host "ROLLBACK_OK"
}

function Read-PublishSetting([string]$Name) {
    $lines = Get-Content -LiteralPath $PublishCmd -Encoding Default
    $prefix = 'set "' + $Name + '='
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) -and $trimmed.EndsWith('"')) {
            return $trimmed.Substring($prefix.Length, $trimmed.Length - $prefix.Length - 1)
        }
    }
    throw "PUBLISH_SETTING_NOT_FOUND: $Name"
}

try {
    Write-Host "=========================================================="
    Write-Host "MAKECHESS - ELECTRONIC BOARD UI V1.2"
    Write-Host "Calibration interface + two menu buttons + localization"
    Write-Host "NO DATABASE CHANGES. NO STOCKFISH CHANGES. NO PUBLISH."
    Write-Host "=========================================================="
    Write-Host "Project: $Root"
    Write-Host ""

    foreach ($p in @($Site, $Tournament, $Localization, $PatchPanel, $ReplacementsFile, $LocalizationEntriesFile, $PublishCmd)) {
        Assert-File $p
    }

    if (Test-Path -LiteralPath $ResultLog) { Remove-Item -LiteralPath $ResultLog -Force }
    if (Test-Path -LiteralPath $BuildLog) { Remove-Item -LiteralPath $BuildLog -Force }

    New-Item -ItemType Directory -Force -Path $Backup | Out-Null
    Copy-Item -LiteralPath $Site -Destination (Join-Path $Backup "site_settings_dialog.dart")
    Copy-Item -LiteralPath $Tournament -Destination (Join-Path $Backup "tournament_manager_dialog.dart")
    Copy-Item -LiteralPath $Localization -Destination (Join-Path $Backup "makechess_localization.dart")
    if (Test-Path -LiteralPath $Panel) {
        Copy-Item -LiteralPath $Panel -Destination (Join-Path $Backup "electronic_board_calibration_panel.dart")
    }

    Write-Host "[1/7] BACKUP_OK:"
    Write-Host "      $Backup"

    $replacements = Get-Content -LiteralPath $ReplacementsFile -Raw -Encoding UTF8 | ConvertFrom-Json

    $siteCheck = [System.IO.File]::ReadAllText($Site, [System.Text.Encoding]::UTF8)
    $tournamentCheck = [System.IO.File]::ReadAllText($Tournament, [System.Text.Encoding]::UTF8)
    $localizationCheck = [System.IO.File]::ReadAllText($Localization, [System.Text.Encoding]::UTF8)
    if ($siteCheck.Contains("electronic_board_calibration_panel.dart") -or
        $tournamentCheck.Contains("_TournamentSection.digitalBoard") -or
        $localizationCheck.Contains('"Электронная доска": <String>[')) {
        throw "PATCH_ALREADY_PRESENT_OR_PARTIAL. Send this window to ChatGPT; do not run the installer again."
    }

    Write-Host "[2/7] Patching site settings..."
    $siteState = Read-Normalized $Site
    $siteText = $siteState.Text
    foreach ($r in $replacements.'lib/ui/dialogs/site_settings_dialog.dart') {
        $siteText = Replace-Once $siteText ([string]$r.before) ([string]$r.after) ([string]$r.label)
    }
    Write-Preserved $Site $siteText $siteState.HadCrLf

    Write-Host "[3/7] Patching tournament manager..."
    $tournamentState = Read-Normalized $Tournament
    $tournamentText = $tournamentState.Text
    foreach ($r in $replacements.'lib/ui/tournament/tournament_manager_dialog.dart') {
        $tournamentText = Replace-Once $tournamentText ([string]$r.before) ([string]$r.after) ([string]$r.label)
    }
    Write-Preserved $Tournament $tournamentText $tournamentState.HadCrLf

    Write-Host "[4/7] Adding Electronic Board panel and 11-language translations..."
    Copy-Item -LiteralPath $PatchPanel -Destination $Panel -Force

    $locState = Read-Normalized $Localization
    $locText = $locState.Text
    $locAnchor = '    "Турниры доступны после входа в аккаунт": <String>['
    $anchorPos = $locText.IndexOf($locAnchor, [System.StringComparison]::Ordinal)
    if ($anchorPos -lt 0) {
        throw "PATCH_MARKER_NOT_FOUND: localization anchor"
    }
    $entries = [System.IO.File]::ReadAllText($LocalizationEntriesFile, [System.Text.Encoding]::UTF8).Replace("`r`n", "`n")
    $locText = $locText.Substring(0, $anchorPos) + $entries + $locText.Substring($anchorPos)
    Write-Preserved $Localization $locText $locState.HadCrLf

    $siteAfter = [System.IO.File]::ReadAllText($Site, [System.Text.Encoding]::UTF8)
    $tournamentAfter = [System.IO.File]::ReadAllText($Tournament, [System.Text.Encoding]::UTF8)
    $locAfter = [System.IO.File]::ReadAllText($Localization, [System.Text.Encoding]::UTF8)

    if (-not $siteAfter.Contains("ElectronicBoardCalibrationPanel")) { throw "SITE_PATCH_VALIDATION_FAILED" }
    if (-not $tournamentAfter.Contains("_TournamentSection.digitalBoard")) { throw "TOURNAMENT_PATCH_VALIDATION_FAILED" }
    if (-not $locAfter.Contains('"Электронная доска": <String>[')) { throw "LOCALIZATION_PATCH_VALIDATION_FAILED" }
    Assert-File $Panel

    Write-Host "[5/7] SOURCE_PATCH_OK"
    Write-Host "      Electronic Board: Settings -> under Tournaments"
    Write-Host "      Digital Board: Tournament management -> under Current tournaments"
    Write-Host "      Calibration grid: V/S + L/R + direct/list mapping"
    Write-Host ""

    # IMPORTANT:
    # Use the SAME production build configuration already stored in the user's
    # approved PUBLISH_MAKECHESS.cmd, but DO NOT execute any publishing steps.
    $SupabaseUrl = Read-PublishSetting "SUPABASE_URL"
    $SupabaseAnonKey = Read-PublishSetting "SUPABASE_ANON_KEY"
    if ([string]::IsNullOrWhiteSpace($SupabaseUrl) -or [string]::IsNullOrWhiteSpace($SupabaseAnonKey)) {
        throw "EMPTY_PUBLISH_BUILD_SETTINGS"
    }
    Write-Host "[6/7] Production build settings loaded from existing PUBLISH_MAKECHESS.cmd."
    Write-Host "      No server upload will be performed."

    Write-Host "[7/7] Building Flutter Web locally to verify compilation..."
    Write-Host "      file_picker plugin warnings may appear; they are not treated as fatal by this installer."
    Write-Host ""

    Push-Location $Root
    try {
        # Windows PowerShell 5.1 can wrap native STDERR as ErrorRecords.
        # Temporarily use Continue so warnings written by Flutter to STDERR
        # do not throw before we can read the real native exit code.
        $oldEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            & flutter build web `
                --dart-define="SUPABASE_URL=$SupabaseUrl" `
                --dart-define="SUPABASE_ANON_KEY=$SupabaseAnonKey" 2>&1 |
                Tee-Object -FilePath $BuildLog
            $buildExit = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $oldEap
        }
    } finally {
        Pop-Location
    }

    if ($buildExit -ne 0) {
        throw "FLUTTER_WEB_BUILD_FAILED_EXIT_CODE_$buildExit. See: $BuildLog"
    }

    if (-not (Test-Path -LiteralPath (Join-Path $Root "build\web\main.dart.js"))) {
        throw "BUILD_OUTPUT_NOT_FOUND: build\web\main.dart.js"
    }

    @(
        "MAKECHESS_ELECTRONIC_BOARD_UI_V1_2_OK"
        "Backup: $Backup"
        "Panel: $Panel"
        "Build log: $BuildLog"
        "Build used settings from existing PUBLISH_MAKECHESS.cmd."
        "No publish was performed."
    ) | Set-Content -LiteralPath $ResultLog -Encoding UTF8

    Write-Host ""
    Write-Host "=========================================================="
    Write-Host "MAKECHESS_ELECTRONIC_BOARD_UI_V1_2_OK"
    Write-Host "=========================================================="
    Write-Host "Build passed."
    Write-Host "Nothing was published."
    Write-Host ""
    Write-Host "NEXT:"
    Write-Host "  Send this window to ChatGPT."
    Write-Host "  Do NOT run PUBLISH_MAKECHESS.cmd yet."
    Write-Host "=========================================================="
    exit 0
}
catch {
    $message = $_.Exception.Message
    Write-Host ""
    Write-Host "ERROR: $message"
    if (Test-Path -LiteralPath $Backup) {
        Restore-Backup
    }
    @(
        "MAKECHESS_ELECTRONIC_BOARD_UI_V1_2_ERROR"
        "Error: $message"
        "Backup: $Backup"
        "Rollback attempted."
        "No publish was performed."
    ) | Set-Content -LiteralPath $ResultLog -Encoding UTF8

    Write-Host ""
    Write-Host "=========================================================="
    Write-Host "MAKECHESS_ELECTRONIC_BOARD_UI_V1_2_ERROR"
    Write-Host "NO WEBSITE WAS PUBLISHED."
    Write-Host "Send this entire window to ChatGPT."
    Write-Host "=========================================================="
    exit 1
}
