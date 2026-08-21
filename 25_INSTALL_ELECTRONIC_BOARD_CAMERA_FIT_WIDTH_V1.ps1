$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = [System.IO.Path]::GetFullPath($PSScriptRoot)
$PatchRoot = Join-Path $Root "PATCH_FILES"

$Panel = Join-Path $Root "lib\ui\dialogs\electronic_board_calibration_panel.dart"
$CameraExport = Join-Path $Root "lib\ui\dialogs\electronic_board_camera.dart"
$CameraStub = Join-Path $Root "lib\ui\dialogs\electronic_board_camera_stub.dart"
$CameraWeb = Join-Path $Root "lib\ui\dialogs\electronic_board_camera_web.dart"
$PublishCmd = Join-Path $Root "PUBLISH_MAKECHESS.cmd"

$PatchPanel = Join-Path $PatchRoot "electronic_board_calibration_panel.dart"
$PatchCameraExport = Join-Path $PatchRoot "electronic_board_camera.dart"
$PatchCameraStub = Join-Path $PatchRoot "electronic_board_camera_stub.dart"
$PatchCameraWeb = Join-Path $PatchRoot "electronic_board_camera_web.dart"

$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Backup = Join-Path $Root ("_backup_electronic_board_camera_fit_width_v1_" + $Stamp)
$ResultLog = Join-Path $Root "MAKECHESS_ELECTRONIC_BOARD_CAMERA_FIT_WIDTH_V1_RESULT.txt"
$BuildLog = Join-Path $Root "MAKECHESS_ELECTRONIC_BOARD_CAMERA_FIT_WIDTH_V1_BUILD.log"
$StdoutLog = Join-Path $env:TEMP ("makechess_camera_fit_width_stdout_" + $Stamp + ".txt")
$StderrLog = Join-Path $env:TEMP ("makechess_camera_fit_width_stderr_" + $Stamp + ".txt")

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

    foreach ($name in @(
        "electronic_board_calibration_panel.dart",
        "electronic_board_camera.dart",
        "electronic_board_camera_stub.dart",
        "electronic_board_camera_web.dart"
    )) {
        $backupFile = Join-Path $Backup $name
        $targetFile = Join-Path (Split-Path $Panel -Parent) $name
        if (Test-Path -LiteralPath $backupFile) {
            Copy-Item -LiteralPath $backupFile -Destination $targetFile -Force
        }
    }
    Write-Host "ROLLBACK_OK"
}

try {
    Write-Host "=========================================================="
    Write-Host "MAKECHESS - ELECTRONIC BOARD CAMERA FIT WIDTH V1"
    Write-Host "The entire camera frame fits by width; monitor height follows."
    Write-Host "NO DATABASE CHANGES. NO STOCKFISH CHANGES. NO PUBLISH."
    Write-Host "=========================================================="
    Write-Host "Project: $Root"
    Write-Host ""

    foreach ($p in @(
        $Panel, $CameraExport, $CameraStub, $CameraWeb, $PublishCmd,
        $PatchPanel, $PatchCameraExport, $PatchCameraStub, $PatchCameraWeb
    )) {
        Assert-File $p
    }

    $panelCurrent = [System.IO.File]::ReadAllText($Panel, [System.Text.Encoding]::UTF8)
    if (-not $panelCurrent.Contains("class ElectronicBoardCalibrationPanel")) {
        throw "ELECTRONIC_BOARD_PANEL_NOT_FOUND"
    }
    if (-not $panelCurrent.Contains("ElectronicBoardCameraView")) {
        throw "CAMERA_GRID_V1_1_NOT_FOUND"
    }

    New-Item -ItemType Directory -Force -Path $Backup | Out-Null
    foreach ($file in @($Panel, $CameraExport, $CameraStub, $CameraWeb)) {
        Copy-Item -LiteralPath $file -Destination (Join-Path $Backup (Split-Path $file -Leaf))
    }

    Write-Host "[1/5] BACKUP_OK:"
    Write-Host "      $Backup"

    Write-Host "[2/5] Installing width-fit camera monitor..."
    Copy-Item -LiteralPath $PatchPanel -Destination $Panel -Force
    Copy-Item -LiteralPath $PatchCameraExport -Destination $CameraExport -Force
    Copy-Item -LiteralPath $PatchCameraStub -Destination $CameraStub -Force
    Copy-Item -LiteralPath $PatchCameraWeb -Destination $CameraWeb -Force

    $panelAfter = [System.IO.File]::ReadAllText($Panel, [System.Text.Encoding]::UTF8)
    $cameraAfter = [System.IO.File]::ReadAllText($CameraWeb, [System.Text.Encoding]::UTF8)

    if (-not $panelAfter.Contains("_cameraAspectRatio")) { throw "PANEL_ASPECT_RATIO_VALIDATION_FAILED" }
    if (-not $cameraAfter.Contains("objectFit = 'contain'")) { throw "CAMERA_CONTAIN_VALIDATION_FAILED" }
    if (-not $cameraAfter.Contains("onAspectRatioChanged")) { throw "CAMERA_ASPECT_CALLBACK_VALIDATION_FAILED" }

    Write-Host "[3/5] SOURCE_PATCH_OK"
    Write-Host "      Left/right cropping removed."
    Write-Host "      The full camera frame now fits by width."
    Write-Host "      The camera monitor height grows according to the camera aspect ratio."
    Write-Host ""

    $SupabaseUrl = Read-PublishSetting "SUPABASE_URL"
    $SupabaseAnonKey = Read-PublishSetting "SUPABASE_ANON_KEY"
    $flutter = (Get-Command flutter.bat -ErrorAction Stop).Source

    Write-Host "[4/5] Building Flutter Web locally..."
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
        "MAKECHESS_ELECTRONIC_BOARD_CAMERA_FIT_WIDTH_V1_OK"
        "Backup: $Backup"
        "Build log: $BuildLog"
        "No publish was performed."
    ) | Set-Content -LiteralPath $ResultLog -Encoding UTF8

    Write-Host "[5/5] BUILD_OK"
    Write-Host ""
    Write-Host "=========================================================="
    Write-Host "MAKECHESS_ELECTRONIC_BOARD_CAMERA_FIT_WIDTH_V1_OK"
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
        "MAKECHESS_ELECTRONIC_BOARD_CAMERA_FIT_WIDTH_V1_ERROR"
        "Error: $message"
        "Backup: $Backup"
        "Rollback attempted."
        "No publish was performed."
    ) | Set-Content -LiteralPath $ResultLog -Encoding UTF8

    Write-Host ""
    Write-Host "=========================================================="
    Write-Host "MAKECHESS_ELECTRONIC_BOARD_CAMERA_FIT_WIDTH_V1_ERROR"
    Write-Host "NO WEBSITE WAS PUBLISHED."
    Write-Host "Send this entire window to ChatGPT."
    Write-Host "=========================================================="
    exit 1
}
