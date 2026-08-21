$ErrorActionPreference = "Stop"

$ProjectRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$BridgeExe = Join-Path $ProjectRoot "build\windows\x64\runner\Release\my_new_chess_app.exe"
$StockfishExe = Join-Path $ProjectRoot "stockfish\stockfish.exe"
$Watchdog = Join-Path $ProjectRoot "MAKECHESS_LOCAL_STOCKFISH_SILENT_WATCHDOG.ps1"
$HealthUrl = "http://127.0.0.1:17891/health"

Write-Host "=========================================================="
Write-Host "MAKECHESS - LOCAL STOCKFISH SILENT V1"
Write-Host "No visible Stockfish window. Website switch stays unchanged."
Write-Host "=========================================================="
Write-Host "Project: $ProjectRoot"
Write-Host ""

if (-not (Test-Path -LiteralPath $BridgeExe)) {
    throw "BRIDGE_EXE_NOT_FOUND: $BridgeExe"
}
if (-not (Test-Path -LiteralPath $StockfishExe)) {
    throw "STOCKFISH_EXE_NOT_FOUND: $StockfishExe"
}
if (-not (Test-Path -LiteralPath $Watchdog)) {
    throw "WATCHDOG_NOT_FOUND: $Watchdog"
}

Write-Host "[1/5] Bridge and Stockfish files: OK"

# Remove old startup shortcut which launched the visible EXE directly.
$startup = [Environment]::GetFolderPath("Startup")
$oldLnk = Join-Path $startup "MakeChess Local Stockfish.lnk"
if (Test-Path -LiteralPath $oldLnk) {
    Remove-Item -LiteralPath $oldLnk -Force
}
Write-Host "[2/5] Old visible startup launcher removed."

# Create a new hidden startup shortcut which launches only the watchdog.
$newLnk = Join-Path $startup "MakeChess Local Stockfish Silent.lnk"
$ws = New-Object -ComObject WScript.Shell
$s = $ws.CreateShortcut($newLnk)
$s.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$s.Arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $Watchdog + '" -ProjectRoot "' + $ProjectRoot + '"'
$s.WorkingDirectory = $ProjectRoot
$s.WindowStyle = 7
$s.Description = "MakeChess local Stockfish background bridge"
$s.Save()
Write-Host "[3/5] Hidden Windows startup installed:"
Write-Host "      $newLnk"

# Stop only bridge-mode copies of the exact bridge EXE.
$bridgePathLower = $BridgeExe.ToLowerInvariant()
try {
    Get-CimInstance Win32_Process -Filter "Name='my_new_chess_app.exe'" |
        Where-Object {
            ($_.ExecutablePath -and $_.ExecutablePath.ToLowerInvariant() -eq $bridgePathLower) -and
            ($_.CommandLine -and $_.CommandLine -match '--bridge')
        } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
} catch {}

# Stop old watchdog copies so this installation starts the new file.
try {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object {
            $_.CommandLine -and $_.CommandLine -match 'MAKECHESS_LOCAL_STOCKFISH_SILENT_WATCHDOG\.ps1'
        } |
        Where-Object { $_.ProcessId -ne $PID } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
} catch {}

Start-Sleep -Milliseconds 500

Write-Host "[4/5] Starting silent watchdog..."
Start-Process `
    -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -ArgumentList @(
        "-NoProfile",
        "-NonInteractive",
        "-WindowStyle", "Hidden",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$Watchdog`"",
        "-ProjectRoot", "`"$ProjectRoot`""
    ) `
    -WorkingDirectory $ProjectRoot `
    -WindowStyle Hidden | Out-Null

$ok = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Milliseconds 500
    try {
        $r = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 2
        if (($r.ok -eq $true) -and ($r.stockfish -eq $true)) {
            Write-Host ("HEALTH_JSON: " + ($r | ConvertTo-Json -Compress))
            $ok = $true
            break
        }
    } catch {}
}
if (-not $ok) {
    throw "SILENT_BRIDGE_HEALTH_FAILED"
}

Write-Host "[5/5] Silent bridge health check: OK"
Write-Host ""
Write-Host "=========================================================="
Write-Host "LOCAL_STOCKFISH_SILENT_V1_OK"
Write-Host "=========================================================="
Write-Host "The large Local Stockfish window is no longer part of normal operation."
Write-Host "The bridge stays alive in background."
Write-Host "If the bridge stops, the hidden watchdog starts it again."
Write-Host "The website button only switches NETWORK <-> LOCAL source."
Write-Host "NO WEBSITE PUBLISH IS REQUIRED."
