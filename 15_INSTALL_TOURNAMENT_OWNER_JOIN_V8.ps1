$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$FilesRoot = Join-Path $Root 'V8_FILES'

Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host 'MAKECHESS - TOURNAMENT OWNER JOIN V8' -ForegroundColor Cyan
Write-Host 'Creator can join own tournament without self-invitation' -ForegroundColor Cyan
Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host "Project: $Root"
Write-Host ''

$targets = @(
    @{
        Name = 'student_tournaments_dialog.dart'
        Source = Join-Path $FilesRoot 'student_tournaments_dialog.dart'
        Target = Join-Path $Root 'lib\ui\tournaments\student_tournaments_dialog.dart'
        Expected = '90C81901F8D90B838BA43FD1871A4F25ACCDE5F74667804D6148E1DFB55438B7'
    },
    @{
        Name = 'tournament_manager_dialog.dart'
        Source = Join-Path $FilesRoot 'tournament_manager_dialog.dart'
        Target = Join-Path $Root 'lib\ui\tournaments\tournament_manager_dialog.dart'
        Expected = '396A6CC60041A14BFADD79F391A387CB281161002CE9457F5F6BBCB20DE60950'
    },
    @{
        Name = 'tournament_storage_service.dart'
        Source = Join-Path $FilesRoot 'tournament_storage_service.dart'
        Target = Join-Path $Root 'lib\services\tournament_storage_service.dart'
        Expected = 'CD0015C0F63E3943B5D5BEC6FF833F41FE75B153CBD314EAC10CBCA1716BA214'
    }
)

Write-Host '[1/5] Checking exact current source files...' -ForegroundColor Yellow
foreach ($item in $targets) {
    if (-not (Test-Path -LiteralPath $item.Target)) {
        throw "TARGET_NOT_FOUND: $($item.Target)"
    }
    if (-not (Test-Path -LiteralPath $item.Source)) {
        throw "PACKAGE_FILE_NOT_FOUND: $($item.Source)"
    }

    $actual = (Get-FileHash -LiteralPath $item.Target -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($actual -ne $item.Expected) {
        Write-Host ''
        Write-Host "CURRENT_FILE_CHANGED: $($item.Name)" -ForegroundColor Red
        Write-Host "Expected: $($item.Expected)"
        Write-Host "Actual:   $actual"
        Write-Host ''
        Write-Host 'Nothing was changed. Send this current file to ChatGPT.' -ForegroundColor Yellow
        throw "SAFE_STOP_HASH_MISMATCH: $($item.Name)"
    }
    Write-Host "SOURCE_OK: $($item.Name)" -ForegroundColor Green
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $Root "_backup_tournament_owner_join_v8_$stamp"
New-Item -ItemType Directory -Path $backup -Force | Out-Null

Write-Host '[2/5] Creating backup...' -ForegroundColor Yellow
foreach ($item in $targets) {
    Copy-Item -LiteralPath $item.Target -Destination (Join-Path $backup $item.Name) -Force
}
Write-Host "BACKUP_OK: $backup" -ForegroundColor Green

Write-Host '[3/5] Installing V8 files...' -ForegroundColor Yellow
foreach ($item in $targets) {
    Copy-Item -LiteralPath $item.Source -Destination $item.Target -Force
}
Write-Host 'FILES_INSTALLED_OK' -ForegroundColor Green

Write-Host '[4/5] Verifying required V8 logic...' -ForegroundColor Yellow
$student = Get-Content -LiteralPath (Join-Path $Root 'lib\ui\tournaments\student_tournaments_dialog.dart') -Raw -Encoding UTF8
$manager = Get-Content -LiteralPath (Join-Path $Root 'lib\ui\tournaments\tournament_manager_dialog.dart') -Raw -Encoding UTF8
$storage = Get-Content -LiteralPath (Join-Path $Root 'lib\services\tournament_storage_service.dart') -Raw -Encoding UTF8

if ($student -notmatch 'Creator and participant are independent roles') {
    throw 'VERIFY_FAILED: student creator/participant logic marker missing'
}
if ($student -notmatch "MakeChessLocalization\.phrase\(\s*'Принять участие'") {
    throw 'VERIFY_FAILED: Join button missing'
}
if ($storage -notmatch '_joinOwnerDirectly') {
    throw 'VERIFY_FAILED: direct owner join method missing'
}
if ($storage -notmatch 'owner_rating_low') {
    throw 'VERIFY_FAILED: owner rating check missing'
}
if ($manager -notmatch 'Publishing a tournament must not invite its creator automatically') {
    throw 'VERIFY_FAILED: auto-invite removal marker missing'
}
Write-Host 'V8_LOGIC_OK' -ForegroundColor Green

Write-Host '[5/5] Final status...' -ForegroundColor Yellow
Write-Host ''
Write-Host '==========================================================' -ForegroundColor Green
Write-Host 'TOURNAMENT_OWNER_JOIN_V8_OK' -ForegroundColor Green
Write-Host '==========================================================' -ForegroundColor Green
Write-Host 'Changed only:' -ForegroundColor White
Write-Host '  lib\ui\tournaments\student_tournaments_dialog.dart'
Write-Host '  lib\ui\tournaments\tournament_manager_dialog.dart'
Write-Host '  lib\services\tournament_storage_service.dart'
Write-Host ''
Write-Host 'Behavior:' -ForegroundColor White
Write-Host '  - Creator sees Open tournament + Join if not participating.'
Write-Host '  - Creator Join adds creator directly, no self-invitation message.'
Write-Host '  - Free-place limit is checked.'
Write-Host '  - Stored min/max rating restriction is checked when present.'
Write-Host '  - Other users keep the existing participation-request RPC.'
Write-Host ''
Write-Host 'DO NOT publish yet. Send this window result to ChatGPT.' -ForegroundColor Yellow
