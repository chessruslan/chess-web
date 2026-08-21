$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host '=========================================================='
Write-Host 'MAKECHESS - TOURNAMENT OWNER JOIN V10'
Write-Host 'Compile fix only; tournament behavior unchanged'
Write-Host '=========================================================='
Write-Host "Project: $root"
Write-Host ''

$target = Join-Path $root 'lib\services\tournament_storage_service.dart'
if (-not (Test-Path -LiteralPath $target)) {
    throw "TARGET_NOT_FOUND: $target"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$text = [System.IO.File]::ReadAllText($target, [System.Text.Encoding]::UTF8)

if ($text -notmatch 'Future<Map<String, dynamic>> _currentProfile\(\) async') {
    throw 'V9_OWNER_JOIN_HELPER_NOT_FOUND. File does not look like the V9-patched storage service.'
}

$old = "      return row is Map ? Map<String, dynamic>.from(row) : <String, dynamic>{};"
$new = @'
      if (row == null) return <String, dynamic>{};
      return Map<String, dynamic>.from(row);
'@

if ($text.Contains($old)) {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupDir = Join-Path $root "_backup_tournament_owner_join_v10_$stamp"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Copy-Item -LiteralPath $target -Destination (Join-Path $backupDir 'tournament_storage_service.dart') -Force
    Write-Host "BACKUP_OK: $backupDir"

    $text = $text.Replace($old, $new.TrimEnd("`r", "`n"))
    [System.IO.File]::WriteAllText($target, $text, $utf8NoBom)
    Write-Host 'NULLABLE_MAP_COMPILE_FIX_OK'
} elseif ($text -match 'if \(row == null\) return <String, dynamic>\{\};\s*return Map<String, dynamic>\.from\(row\);') {
    Write-Host 'ALREADY_FIXED_OK'
} else {
    throw 'EXPECTED_V9_COMPILE_LINE_NOT_FOUND. Nothing was changed.'
}

$verify = [System.IO.File]::ReadAllText($target, [System.Text.Encoding]::UTF8)
if ($verify.Contains($old)) { throw 'VERIFY_FAILED: old nullable Map line still exists.' }
if ($verify -notmatch 'if \(row == null\) return <String, dynamic>\{\};\s*return Map<String, dynamic>\.from\(row\);') {
    throw 'VERIFY_FAILED: replacement not found.'
}

Write-Host ''
Write-Host '=========================================================='
Write-Host 'TOURNAMENT_OWNER_JOIN_V10_OK'
Write-Host '=========================================================='
Write-Host 'Only the Dart compile error in tournament_storage_service.dart was fixed.'
Write-Host 'No tournament behavior was changed.'
Write-Host 'NEXT: run PUBLISH_MAKECHESS.cmd. It will build first and deploy only if build succeeds.'
