[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Set-StrictMode -Version 2.0

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$Server = "flexyops@111.88.227.25"
$SshKey = Join-Path $env:USERPROFILE ".ssh\makechess_selectel"
$ApiBase = "https://api.111-88-227-25.sslip.io"
$PublicDownloadUrl = "$ApiBase/storage/v1/object/public/downloads/MakeChess_Setup.exe"
$DownloadGateMarker = "makechess_windows_download_status_v1"

$WindowsBuildCmd = Join-Path $Root "BUILD_MAKECHESS_WINDOWS.cmd"
$InstallerBuilder = Join-Path $Root "BUILD_MAKECHESS_OWN_INSTALLER_V1.ps1"
$PublishCmd = Join-Path $Root "PUBLISH_MAKECHESS.cmd"

# Only NEW approved DB migrations go here.
# Empty folder = database is not modified.
$DbQueue = Join-Path $Root "release\db"
$ReleaseDir = Join-Path $Root "release"
$LogDir = Join-Path $ReleaseDir "logs"
New-Item -ItemType Directory -Force -Path $DbQueue | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir "release_$Stamp.log"

$script:DbStatus = "NO CHANGES"
$script:WindowsStatus = "NOT RUN"
$script:InstallerStatus = "NOT RUN"
$script:StorageStatus = "NOT RUN"
$script:WebStatus = "NOT RUN"
$script:DownloadStatus = "NOT RUN"

function Log([string]$Message = "") {
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message
    Write-Host $line
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}

function Fail([string]$Message) {
    Log ""
    Log "ERROR: $Message"
    Log "RELEASE_STOPPED"
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host " MAKECHESS RELEASE STOPPED" -ForegroundColor Red
    Write-Host " $Message" -ForegroundColor Red
    Write-Host " LOG: $LogFile" -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    exit 1
}

function Require-File([string]$Path, [string]$Name) {
    if (-not (Test-Path -LiteralPath $Path)) {
        Fail "$Name not found: $Path"
    }
}

function Require-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Fail "$Name not found in PATH."
    }
}

function Get-HttpStatusNoThrow([string]$Uri) {
    try {
        $response = Invoke-WebRequest `
            -Uri $Uri `
            -Method Head `
            -UseBasicParsing `
            -TimeoutSec 40 `
            -ErrorAction Stop
        return [int]$response.StatusCode
    }
    catch {
        $webResponse = $_.Exception.Response
        if ($webResponse -and $webResponse.StatusCode) {
            return [int]$webResponse.StatusCode
        }
        throw
    }
}

function Get-ProjectVersion {
    $pubspec = Join-Path $Root "pubspec.yaml"
    $line = Get-Content -LiteralPath $pubspec -Encoding UTF8 |
        Where-Object { $_ -match '^\s*version\s*:\s*([0-9A-Za-z._+-]+)\s*$' } |
        Select-Object -First 1

    if ($line -and $line -match '^\s*version\s*:\s*([0-9A-Za-z._+-]+)\s*$') {
        $raw = $Matches[1]
        $plain = ($raw -split '\+')[0]
        if (-not [string]::IsNullOrWhiteSpace($plain)) {
            return $plain
        }
    }
    return "1.0.0"
}

function Patch-InstallerForMaximumCompatibility {
    # Remove only OUR artificial restrictions.
    # We do not fake OS/runtime compatibility: Windows/Flutter itself decides
    # whether the generated application can actually run on a machine.
    $path = $InstallerBuilder
    $text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    $original = $text

    # Remove the installer block that refuses non-64-bit Windows outright.
    if ($text.Contains("Environment.Is64BitOperatingSystem")) {
        $pattern = '(?ms)\r?\n\s*if\s*\(!Environment\.Is64BitOperatingSystem\)\s*\{.*?\r?\n\s*\}\r?\n(?=\s*Process\[\]\s+running)'
        $patched = [regex]::Replace($text, $pattern, "`r`n", 1)
        if ($patched -eq $text -or $patched.Contains("Environment.Is64BitOperatingSystem")) {
            Fail "Could not safely remove the artificial 64-bit installer block."
        }
        $text = $patched
    }

    # Installer/uninstaller helper EXEs should not be forced to x64.
    $text = $text.Replace('"/platform:x64"', '"/platform:anycpu"')

    # Let release version follow pubspec.yaml automatically.
    if ($text.Contains('$Version = "1.0.0"')) {
        $text = $text.Replace(
            '$Version = "1.0.0"',
            '$Version = if ($env:MAKECHESS_RELEASE_VERSION) { $env:MAKECHESS_RELEASE_VERSION } else { "1.0.0" }'
        )
    }

    # Do not open Explorer during automated release.
    if ($text.Contains('explorer.exe /select,"$OutExe"') -and
        -not $text.Contains('MAKECHESS_RELEASE_AUTOMATED')) {
        $text = $text.Replace(
            '    explorer.exe /select,"$OutExe"',
            '    if ($env:MAKECHESS_RELEASE_AUTOMATED -ne "1") { explorer.exe /select,"$OutExe" }'
        )
    }

    if ($text -ne $original) {
        $backup = "$path.before_max_compat_$Stamp.bak"
        Copy-Item -LiteralPath $path -Destination $backup -Force
        [IO.File]::WriteAllText(
            $path,
            $text,
            (New-Object System.Text.UTF8Encoding($true))
        )
        Log "Installer compatibility patch applied."
        Log "Installer backup: $backup"
    }
    else {
        Log "Installer compatibility patch already applied."
    }

    $verify = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    if ($verify.Contains("Environment.Is64BitOperatingSystem")) {
        Fail "Artificial 64-bit installer restriction is still present."
    }
    if ($verify.Contains('"/platform:x64"')) {
        Fail "Installer helper executables are still forced to x64."
    }
}

function Invoke-RemoteSqlText([string]$Sql, [switch]$Quiet) {
    $remote = "docker exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1"
    if ($Quiet) { $remote += " -Atq" }

    $output = $Sql | & ssh `
        -i $SshKey `
        -o BatchMode=yes `
        -o ConnectTimeout=20 `
        -o ServerAliveInterval=5 `
        -o ServerAliveCountMax=3 `
        $Server $remote

    if ($LASTEXITCODE -ne 0) {
        Fail "Remote PostgreSQL command failed."
    }
    return $output
}

function Apply-QueuedDatabaseChanges {
    $migrations = @(Get-ChildItem -LiteralPath $DbQueue -Filter "*.sql" -File | Sort-Object Name)

    if ($migrations.Count -eq 0) {
        $script:DbStatus = "NO CHANGES"
        Log "DATABASE: no queued SQL files. Skipping DB write and backup."
        return
    }

    Log "DATABASE: $($migrations.Count) queued migration(s) detected."

    # BACKUP BEFORE ANY DATABASE WRITE.
    $backupCommand = @'
set -e
mkdir -p /home/flexyops/db_backups
STAMP=$(date +%Y%m%d_%H%M%S)
OUT="/home/flexyops/db_backups/postgres_before_makechess_release_${STAMP}.dump"
docker exec -i supabase-db pg_dump -U postgres -d postgres -Fc > "$OUT"
test -s "$OUT"
echo "DB_BACKUP_OK:$OUT"
'@

    $backupOut = $backupCommand | & ssh `
        -i $SshKey `
        -o BatchMode=yes `
        -o ConnectTimeout=20 `
        -o ServerAliveInterval=5 `
        -o ServerAliveCountMax=3 `
        $Server "bash -s"

    if ($LASTEXITCODE -ne 0 -or -not (($backupOut -join "`n") -match "DB_BACKUP_OK:")) {
        Fail "Database backup failed. No migration was applied."
    }
    Log (($backupOut | Where-Object { $_ -match "DB_BACKUP_OK:" }) -join "")

    $trackingSql = @'
create table if not exists public.makechess_release_migrations (
  sha256 text primary key,
  file_name text not null,
  applied_at timestamptz not null default now()
);
'@
    Invoke-RemoteSqlText -Sql $trackingSql | Out-Null

    foreach ($migration in $migrations) {
        $hash = (Get-FileHash -LiteralPath $migration.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $safeName = $migration.Name.Replace("'", "''")
        $query = "select count(*) from public.makechess_release_migrations where sha256='$hash';"
        $countOut = Invoke-RemoteSqlText -Sql $query -Quiet
        $countText = ($countOut -join "").Trim()

        if ($countText -eq "1") {
            Log "DATABASE SKIP: $($migration.Name) already applied."
            continue
        }
        if ($countText -ne "0") {
            Fail "Unexpected migration tracking result for $($migration.Name): $countText"
        }

        $remoteSql = "/home/flexyops/makechess_release_$hash.sql"
        Log "DATABASE APPLY: $($migration.Name)"

        & scp `
            -i $SshKey `
            -o BatchMode=yes `
            -o ConnectTimeout=20 `
            $migration.FullName "${Server}:$remoteSql"

        if ($LASTEXITCODE -ne 0) {
            Fail "Could not upload DB migration: $($migration.Name)"
        }

        $remoteApply = "set -e; docker exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 < '$remoteSql'; rm -f '$remoteSql'"
        & ssh `
            -i $SshKey `
            -o BatchMode=yes `
            -o ConnectTimeout=20 `
            -o ServerAliveInterval=5 `
            -o ServerAliveCountMax=3 `
            $Server $remoteApply

        if ($LASTEXITCODE -ne 0) {
            Fail "DB migration failed: $($migration.Name). Backup exists."
        }

        $recordSql = @"
insert into public.makechess_release_migrations(sha256, file_name)
values ('$hash', '$safeName')
on conflict (sha256) do nothing;
"@
        Invoke-RemoteSqlText -Sql $recordSql | Out-Null
        Log "DATABASE OK: $($migration.Name)"
    }

    $script:DbStatus = "OK"
}

function Stop-RunningMakeChess {
    $procs = @(Get-Process -Name "MakeChess" -ErrorAction SilentlyContinue)
    if ($procs.Count -eq 0) { return }

    Log "Closing running MakeChess before Windows build..."
    foreach ($p in $procs) {
        try { [void]$p.CloseMainWindow() } catch {}
    }
    Start-Sleep -Seconds 3

    $remaining = @(Get-Process -Name "MakeChess" -ErrorAction SilentlyContinue)
    foreach ($p in $remaining) {
        try { Stop-Process -Id $p.Id -Force -ErrorAction Stop } catch {}
    }
    Start-Sleep -Milliseconds 500
}

function Build-WindowsAndInstaller {
    Stop-RunningMakeChess

    $env:MAKECHESS_RELEASE_VERSION = Get-ProjectVersion
    $env:MAKECHESS_RELEASE_AUTOMATED = "1"

    Log "WINDOWS VERSION LABEL: $env:MAKECHESS_RELEASE_VERSION"
    Log "WINDOWS: building MakeChess..."
    # MAKECHESS_NATIVE_STDERR_FIX_V3_WINDOWS
    $savedErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & cmd.exe /d /c "call `"$WindowsBuildCmd`" nopause" 2>&1 |
            ForEach-Object { Write-Host $_ }
        $windowsBuildExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $savedErrorActionPreference
    }

    if ($windowsBuildExitCode -ne 0) {
        Fail "Windows build failed with exit code $windowsBuildExitCode."
    }
    $script:WindowsStatus = "OK"

    Log "INSTALLER: building own MakeChess installer..."
    # MAKECHESS_NATIVE_STDERR_FIX_V3_INSTALLER
    $savedErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $InstallerBuilder 2>&1 |
            ForEach-Object { Write-Host $_ }
        $installerBuildExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $savedErrorActionPreference
    }

    if ($installerBuildExitCode -ne 0) {
        Fail "Own installer build failed with exit code $installerBuildExitCode."
    }

    $installer = Get-ChildItem -LiteralPath (Join-Path $Root "dist") `
        -Filter "MakeChess_Setup_*.exe" -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $installer) {
        Fail "Installer output was not found in dist."
    }

    $hash = (Get-FileHash -LiteralPath $installer.FullName -Algorithm SHA256).Hash
    $script:InstallerStatus = "OK"
    Log ("INSTALLER OK: {0}" -f $installer.FullName)
    Log ("INSTALLER SIZE: {0} bytes" -f $installer.Length)
    Log ("INSTALLER SHA256: {0}" -f $hash)

    return $installer
}

function Upload-InstallerToStorage([System.IO.FileInfo]$Installer) {
    Log "STORAGE: copying installer to Selectel staging..."
    & scp `
        -i $SshKey `
        -o BatchMode=yes `
        -o ConnectTimeout=20 `
        $Installer.FullName "${Server}:/home/flexyops/MakeChess_Setup.exe"

    if ($LASTEXITCODE -ne 0) {
        Fail "Could not copy installer to Selectel."
    }

    # Service key is read only INSIDE Selectel and is never printed.
    $remoteUpload = @'
set -e
cd /opt/flexytube/supabase-stack
set -a
. ./.env
set +a

KEY="${SERVICE_ROLE_KEY:-${SUPABASE_SERVICE_ROLE_KEY:-}}"
test -n "$KEY"

curl -fsS -X POST \
  "https://api.111-88-227-25.sslip.io/storage/v1/object/downloads/MakeChess_Setup.exe" \
  -H "apikey: ${KEY}" \
  -H "Authorization: Bearer ${KEY}" \
  -H "x-upsert: true" \
  -H "Content-Type: application/octet-stream" \
  --data-binary "@/home/flexyops/MakeChess_Setup.exe" >/dev/null

REMOTE_SIZE=$(docker exec -i supabase-db psql -U postgres -d postgres -Atq -c \
  "select coalesce((metadata->>'size')::bigint, 0) from storage.objects where bucket_id='downloads' and name='MakeChess_Setup.exe' limit 1;")
test "${REMOTE_SIZE:-0}" -gt 0

rm -f /home/flexyops/MakeChess_Setup.exe
unset KEY SERVICE_ROLE_KEY SUPABASE_SERVICE_ROLE_KEY
echo "STORAGE_REMOTE_SIZE:${REMOTE_SIZE}"
echo STORAGE_UPLOAD_OK
'@

    Log "STORAGE: uploading MakeChess_Setup.exe..."
    $uploadOut = $remoteUpload | & ssh `
        -i $SshKey `
        -o BatchMode=yes `
        -o ConnectTimeout=20 `
        -o ServerAliveInterval=5 `
        -o ServerAliveCountMax=3 `
        $Server "bash -s"

    if ($LASTEXITCODE -ne 0 -or -not (($uploadOut -join "`n") -match "STORAGE_UPLOAD_OK")) {
        Fail "Storage upload failed."
    }

    $sizeLine = @($uploadOut | Where-Object { $_ -match '^STORAGE_REMOTE_SIZE:[0-9]+$' } |
        Select-Object -Last 1)
    if ($sizeLine.Count -ne 1) {
        Fail "Storage upload succeeded, but secure size verification was not returned."
    }

    $remoteLength = [int64](($sizeLine[0] -split ':', 2)[1])
    if ($remoteLength -ne [int64]$Installer.Length) {
        Fail "Storage size mismatch. Local=$($Installer.Length), Remote=$remoteLength"
    }

    $script:StorageStatus = "OK"
    $script:DownloadStatus = "GATED"
    Log "STORAGE OK: private installer object size matches local installer."
}

function Remove-OldInstallerFromWebTree {
    # Installer is now in Storage. Leaving 24+ MB under web\downloads
    # makes every web publish slower for no benefit.
    $downloadsDir = Join-Path $Root "web\downloads"
    if (-not (Test-Path -LiteralPath $downloadsDir)) { return }

    $oldFiles = @(Get-ChildItem -LiteralPath $downloadsDir -Filter "MakeChess_Setup*.exe" -File -ErrorAction SilentlyContinue)
    foreach ($f in $oldFiles) {
        Log "Removing obsolete web-tree installer: $($f.FullName)"
        Remove-Item -LiteralPath $f.FullName -Force
    }
}

function Publish-Web {
    Remove-OldInstallerFromWebTree

    $topBar = Join-Path $Root "lib\ui\common_top_bar.dart"
    Require-File $topBar "common_top_bar.dart"
    $topText = [IO.File]::ReadAllText($topBar, [Text.Encoding]::UTF8)

    if ($topText.Contains($PublicDownloadUrl)) {
        Fail "Website source still contains the forbidden public installer URL."
    }
    if (-not $topText.Contains($DownloadGateMarker)) {
        Fail "Website source does not contain the Windows download approval gate."
    }

    Log "WEB: publishing ONLY through existing PUBLISH_MAKECHESS.cmd..."

    # Feed one newline to the publisher's final PAUSE without modifying it.
    & cmd.exe /d /c "(echo.)|call `"$PublishCmd`""
    if ($LASTEXITCODE -ne 0) {
        Fail "Website publish failed."
    }
    $script:WebStatus = "OK"

    $nonce = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    Log "WEB: verifying makechess.com..."
    $site = Invoke-WebRequest `
        -Uri "https://makechess.com/?release=$nonce" `
        -UseBasicParsing `
        -TimeoutSec 40

    if ([int]$site.StatusCode -ne 200) {
        Fail "makechess.com returned HTTP $($site.StatusCode)."
    }

    Log "WEB: verifying published download gate..."
    $js = Invoke-WebRequest `
        -Uri "https://makechess.com/main.dart.js?release=$nonce" `
        -UseBasicParsing `
        -TimeoutSec 60

    if ($js.Content.Contains($PublicDownloadUrl)) {
        Fail "Published main.dart.js still contains the forbidden public installer URL."
    }
    if (-not $js.Content.Contains($DownloadGateMarker)) {
        Fail "Published main.dart.js does not contain the Windows download approval gate."
    }

    Log "WEB OK."
}

# ---------------- PRE-FLIGHT ----------------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " MAKECHESS - ONE COMMAND FULL RELEASE" -ForegroundColor Cyan
Write-Host " NO ARTIFICIAL WINDOWS VERSION LIMIT" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Require-File (Join-Path $Root "pubspec.yaml") "pubspec.yaml"
Require-File $WindowsBuildCmd "BUILD_MAKECHESS_WINDOWS.cmd"
Require-File $InstallerBuilder "BUILD_MAKECHESS_OWN_INSTALLER_V1.ps1"
Require-File $PublishCmd "PUBLISH_MAKECHESS.cmd"
Require-File $SshKey "Selectel SSH key"

Require-Command "flutter"
Require-Command "powershell.exe"
Require-Command "ssh"
Require-Command "scp"

Log "ROOT: $Root"
Log "LOG: $LogFile"
Log "Preflight OK."

Patch-InstallerForMaximumCompatibility
Apply-QueuedDatabaseChanges
# MAKECHESS_INSTALLER_FILEINFO_FIX_V3
$buildResult = @(Build-WindowsAndInstaller)

$installer = $buildResult |
    Where-Object { $_ -is [System.IO.FileInfo] } |
    Select-Object -Last 1

if (-not $installer) {
    $installer = Get-ChildItem -LiteralPath (Join-Path $Root "dist") `
        -Filter "MakeChess_Setup_*.exe" -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

if (-not $installer -or $installer -isnot [System.IO.FileInfo]) {
    Fail "Installer output could not be resolved to one FileInfo."
}

Upload-InstallerToStorage -Installer $installer
Publish-Web

$publicStatus = Get-HttpStatusNoThrow(
    $PublicDownloadUrl + "?final=" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
)
if ($publicStatus -eq 200) {
    Fail "Installer is still publicly downloadable without administrator approval."
}
$script:DownloadStatus = "ADMIN GATED"
Log "DOWNLOAD GATE OK: public installer URL is blocked (HTTP $publicStatus)."

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " MAKECHESS RELEASE OK" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host (" DATABASE:     {0}" -f $script:DbStatus) -ForegroundColor Green
Write-Host (" WINDOWS APP:  {0}" -f $script:WindowsStatus) -ForegroundColor Green
Write-Host (" INSTALLER:    {0}" -f $script:InstallerStatus) -ForegroundColor Green
Write-Host (" STORAGE:      {0}" -f $script:StorageStatus) -ForegroundColor Green
Write-Host (" WEBSITE:      {0}" -f $script:WebStatus) -ForegroundColor Green
Write-Host (" DOWNLOAD:     {0}" -f $script:DownloadStatus) -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host " INSTALLER STORAGE: PRIVATE / ADMIN APPROVAL REQUIRED" -ForegroundColor Green
Write-Host (" LOG: {0}" -f $LogFile) -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

exit 0
