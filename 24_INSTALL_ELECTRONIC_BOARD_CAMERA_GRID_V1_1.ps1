$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = [System.IO.Path]::GetFullPath($PSScriptRoot)
$PatchRoot = Join-Path $Root "PATCH_FILES"

$Panel = Join-Path $Root "lib\ui\dialogs\electronic_board_calibration_panel.dart"
$CameraExport = Join-Path $Root "lib\ui\dialogs\electronic_board_camera.dart"
$CameraStub = Join-Path $Root "lib\ui\dialogs\electronic_board_camera_stub.dart"
$CameraWeb = Join-Path $Root "lib\ui\dialogs\electronic_board_camera_web.dart"
$Localization = Join-Path $Root "lib\localization\makechess_localization.dart"
$PublishCmd = Join-Path $Root "PUBLISH_MAKECHESS.cmd"

$PatchPanel = Join-Path $PatchRoot "electronic_board_calibration_panel.dart"
$PatchCameraExport = Join-Path $PatchRoot "electronic_board_camera.dart"
$PatchCameraStub = Join-Path $PatchRoot "electronic_board_camera_stub.dart"
$PatchCameraWeb = Join-Path $PatchRoot "electronic_board_camera_web.dart"
$TranslationEntries = Join-Path $PatchRoot "localization_camera_grid_entries.txt"

$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Backup = Join-Path $Root ("_backup_electronic_board_camera_grid_v1_1_" + $Stamp)
$ResultLog = Join-Path $Root "MAKECHESS_ELECTRONIC_BOARD_CAMERA_GRID_V1_1_RESULT.txt"
$BuildLog = Join-Path $Root "MAKECHESS_ELECTRONIC_BOARD_CAMERA_GRID_V1_1_BUILD.log"
$StdoutLog = Join-Path $env:TEMP ("makechess_camera_grid_stdout_" + $Stamp + ".txt")
$StderrLog = Join-Path $env:TEMP ("makechess_camera_grid_stderr_" + $Stamp + ".txt")

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Assert-File([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "FILE_NOT_FOUND: $Path"
    }
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

function Restore-Backup {
    Write-Host ""
    Write-Host "Restoring files from backup..."

    Copy-Item -LiteralPath (Join-Path $Backup "electronic_board_calibration_panel.dart") -Destination $Panel -Force
    Copy-Item -LiteralPath (Join-Path $Backup "makechess_localization.dart") -Destination $Localization -Force

    foreach ($name in @(
        "electronic_board_camera.dart",
        "electronic_board_camera_stub.dart",
        "electronic_board_camera_web.dart"
    )) {
        $backupFile = Join-Path $Backup $name
        $targetFile = Join-Path (Split-Path $Panel -Parent) $name
        if (Test-Path -LiteralPath $backupFile) {
            Copy-Item -LiteralPath $backupFile -Destination $targetFile -Force
        } elseif (Test-Path -LiteralPath $targetFile) {
            Remove-Item -LiteralPath $targetFile -Force
        }
    }

    Write-Host "ROLLBACK_OK"
}

try {
    Write-Host "=========================================================="
    Write-Host "MAKECHESS - ELECTRONIC BOARD CAMERA + GRID V1.1"
    Write-Host "USB/web camera preview + exact calibration-grid geometry"
    Write-Host "NO DATABASE CHANGES. NO STOCKFISH CHANGES. NO PUBLISH."
    Write-Host "=========================================================="
    Write-Host "Project: $Root"
    Write-Host ""

    foreach ($p in @(
        $Panel, $Localization, $PublishCmd,
        $PatchPanel, $PatchCameraExport, $PatchCameraStub, $PatchCameraWeb,
        $TranslationEntries
    )) {
        Assert-File $p
    }

    $panelCurrent = [System.IO.File]::ReadAllText($Panel, [System.Text.Encoding]::UTF8)
    if (-not $panelCurrent.Contains("class ElectronicBoardCalibrationPanel")) {
        throw "ELECTRONIC_BOARD_V1_2_NOT_FOUND"
    }

    $locCurrent = [System.IO.File]::ReadAllText($Localization, [System.Text.Encoding]::UTF8)
    if (-not $locCurrent.Contains('"Электронная доска": <String>[')) {
        throw "ELECTRONIC_BOARD_LOCALIZATION_V1_2_NOT_FOUND"
    }
    if ($locCurrent.Contains('"Ширина ячейки": <String>[')) {
        throw "CAMERA_GRID_PATCH_ALREADY_PRESENT_OR_PARTIAL"
    }

    New-Item -ItemType Directory -Force -Path $Backup | Out-Null
    Copy-Item -LiteralPath $Panel -Destination (Join-Path $Backup "electronic_board_calibration_panel.dart")
    Copy-Item -LiteralPath $Localization -Destination (Join-Path $Backup "makechess_localization.dart")

    foreach ($file in @($CameraExport, $CameraStub, $CameraWeb)) {
        if (Test-Path -LiteralPath $file) {
            Copy-Item -LiteralPath $file -Destination (Join-Path $Backup (Split-Path $file -Leaf))
        }
    }

    Write-Host "[1/6] BACKUP_OK:"
    Write-Host "      $Backup"

    Write-Host "[2/6] Installing camera module..."
    Copy-Item -LiteralPath $PatchCameraExport -Destination $CameraExport -Force
    Copy-Item -LiteralPath $PatchCameraStub -Destination $CameraStub -Force
    Copy-Item -LiteralPath $PatchCameraWeb -Destination $CameraWeb -Force

    Write-Host "[3/6] Replacing only our Electronic Board calibration panel..."
    Copy-Item -LiteralPath $PatchPanel -Destination $Panel -Force

    Write-Host "[4/6] Adding 11-language camera/grid phrases..."
    $locText = [System.IO.File]::ReadAllText($Localization, [System.Text.Encoding]::UTF8)
    $anchor = '    "Камера будет подключена на следующем этапе.": <String>['
    $anchorPos = $locText.IndexOf($anchor, [System.StringComparison]::Ordinal)
    if ($anchorPos -lt 0) {
        throw "LOCALIZATION_ANCHOR_NOT_FOUND"
    }
    $entries = [System.IO.File]::ReadAllText($TranslationEntries, [System.Text.Encoding]::UTF8)
    $locText = $locText.Substring(0, $anchorPos) + $entries + $locText.Substring($anchorPos)
    [System.IO.File]::WriteAllText($Localization, $locText, $Utf8NoBom)

    $panelAfter = [System.IO.File]::ReadAllText($Panel, [System.Text.Encoding]::UTF8)
    $locAfter = [System.IO.File]::ReadAllText($Localization, [System.Text.Encoding]::UTF8)

    if (-not $panelAfter.Contains("ElectronicBoardCameraView")) { throw "PANEL_CAMERA_VALIDATION_FAILED" }
    if (-not $panelAfter.Contains("_cellWidthController")) { throw "GRID_WIDTH_VALIDATION_FAILED" }
    if (-not $panelAfter.Contains("_cellHeightController")) { throw "GRID_HEIGHT_VALIDATION_FAILED" }
    if (-not $locAfter.Contains('"Ширина ячейки": <String>[')) { throw "LOCALIZATION_VALIDATION_FAILED" }

    Write-Host "[5/6] SOURCE_PATCH_OK"
    Write-Host "      Camera button added."
    Write-Host "      Camera image appears inside the calibration monitor."
    Write-Host "      Grid remains clickable over the camera image."
    Write-Host "      Added exact cell width and cell height in pixels."
    Write-Host "      Existing V/S, L/R and cell-to-chess-square mapping preserved."
    Write-Host ""

    $SupabaseUrl = Read-PublishSetting "SUPABASE_URL"
    $SupabaseAnonKey = Read-PublishSetting "SUPABASE_ANON_KEY"

    $flutter = (Get-Command flutter.bat -ErrorAction Stop).Source

    Write-Host "[6/6] Building Flutter Web locally..."
    Write-Host "      Flutter warnings are written to the log and do not stop PowerShell by themselves."
    Write-Host ""

    if (Test-Path -LiteralPath $StdoutLog) { Remove-Item $StdoutLog -Force }
    if (Test-Path -LiteralPath $StderrLog) { Remove-Item $StderrLog -Force }
    if (Test-Path -LiteralPath $BuildLog) { Remove-Item $BuildLog -Force }

    $arguments = @(
        "build",
        "web",
        "--dart-define=SUPABASE_URL=$SupabaseUrl",
        "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey"
    )

    $process = Start-Process `
        -FilePath $flutter `
        -ArgumentList $arguments `
        -WorkingDirectory $Root `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $StdoutLog `
        -RedirectStandardError $StderrLog

    $stdout = if (Test-Path $StdoutLog) { Get-Content -LiteralPath $StdoutLog -Raw -Encoding UTF8 } else { "" }
    $stderr = if (Test-Path $StderrLog) { Get-Content -LiteralPath $StderrLog -Raw -Encoding UTF8 } else { "" }

    $combined = $stdout
    if (-not [string]::IsNullOrWhiteSpace($stderr)) {
        $combined += "`r`n" + $stderr
    }
    [System.IO.File]::WriteAllText($BuildLog, $combined, $Utf8NoBom)

    if (-not [string]::IsNullOrWhiteSpace($stdout)) { Write-Host $stdout }
    if (-not [string]::IsNullOrWhiteSpace($stderr)) { Write-Host $stderr }

    if ($process.ExitCode -ne 0) {
        throw "FLUTTER_WEB_BUILD_FAILED_EXIT_CODE_$($process.ExitCode). See: $BuildLog"
    }

    if (-not (Test-Path -LiteralPath (Join-Path $Root "build\web\main.dart.js"))) {
        throw "BUILD_OUTPUT_NOT_FOUND"
    }

    @(
        "MAKECHESS_ELECTRONIC_BOARD_CAMERA_GRID_V1_1_OK"
        "Backup: $Backup"
        "Build log: $BuildLog"
        "No publish was performed."
    ) | Set-Content -LiteralPath $ResultLog -Encoding UTF8

    Write-Host ""
    Write-Host "=========================================================="
    Write-Host "MAKECHESS_ELECTRONIC_BOARD_CAMERA_GRID_V1_1_OK"
    Write-Host "=========================================================="
    Write-Host "Build passed."
    Write-Host "Nothing was published."
    Write-Host ""
    Write-Host "NEXT:"
    Write-Host "  Send this window to ChatGPT."
    Write-Host "  Do NOT publish until we confirm the build result."
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
        "MAKECHESS_ELECTRONIC_BOARD_CAMERA_GRID_V1_1_ERROR"
        "Error: $message"
        "Backup: $Backup"
        "Rollback attempted."
        "No publish was performed."
    ) | Set-Content -LiteralPath $ResultLog -Encoding UTF8

    Write-Host ""
    Write-Host "=========================================================="
    Write-Host "MAKECHESS_ELECTRONIC_BOARD_CAMERA_GRID_V1_1_ERROR"
    Write-Host "NO WEBSITE WAS PUBLISHED."
    Write-Host "Send this entire window to ChatGPT."
    Write-Host "=========================================================="
    exit 1
}
