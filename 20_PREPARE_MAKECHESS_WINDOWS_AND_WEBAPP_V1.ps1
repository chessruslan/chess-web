$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = [System.IO.Path]::GetFullPath($PSScriptRoot)
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Backup = Join-Path $Root ("_backup_windows_webapp_v1_" + $Stamp)
$Log = Join-Path $Root "MAKECHESS_WINDOWS_WEBAPP_V1_RESULT.txt"

function Write-Result([string]$Text) {
    $Text | Tee-Object -FilePath $Log -Append
}

function Assert-File([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "FILE_NOT_FOUND: $Path"
    }
}

function Replace-Exact([string]$Text, [string]$Old, [string]$New, [string]$Label) {
    if (-not $Text.Contains($Old)) {
        throw "PATCH_MARKER_NOT_FOUND [$Label]"
    }
    return $Text.Replace($Old, $New)
}

Write-Host "=========================================================="
Write-Host "MAKECHESS - WINDOWS APP + WEB APP V1"
Write-Host "Safe preparation. No website publishing."
Write-Host "=========================================================="
Write-Host "Project: $Root"
Write-Host ""

$Pubspec  = Join-Path $Root "pubspec.yaml"
$Manifest = Join-Path $Root "web\manifest.json"
$Index    = Join-Path $Root "web\index.html"
$MainCpp  = Join-Path $Root "windows\runner\main.cpp"
$RunnerRc = Join-Path $Root "windows\runner\Runner.rc"
$StockfishRoot = Join-Path $Root "stockfish\stockfish.exe"
$BuildRelease = Join-Path $Root "build\windows\x64\runner\Release"
$BuildExe = Join-Path $BuildRelease "my_new_chess_app.exe"

foreach ($p in @($Pubspec,$Manifest,$Index,$MainCpp,$RunnerRc,$StockfishRoot,$BuildExe)) {
    Assert-File $p
}

if (Test-Path -LiteralPath $Log) { Remove-Item -LiteralPath $Log -Force }
Write-Result "MAKECHESS_WINDOWS_WEBAPP_V1"
Write-Result "Project: $Root"
Write-Result "Started: $(Get-Date -Format o)"

# ----------------------------------------------------------------------
# 1. BACKUP
# ----------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $Backup | Out-Null
Copy-Item -LiteralPath $Pubspec  -Destination (Join-Path $Backup "pubspec.yaml")
Copy-Item -LiteralPath $Manifest -Destination (Join-Path $Backup "manifest.json")
Copy-Item -LiteralPath $Index    -Destination (Join-Path $Backup "index.html")
Copy-Item -LiteralPath $MainCpp  -Destination (Join-Path $Backup "main.cpp")
Copy-Item -LiteralPath $RunnerRc -Destination (Join-Path $Backup "Runner.rc")

$OldWatchdog = Join-Path $Root "MAKECHESS_LOCAL_STOCKFISH_SILENT_WATCHDOG.ps1"
if (Test-Path -LiteralPath $OldWatchdog) {
    Copy-Item -LiteralPath $OldWatchdog -Destination (Join-Path $Backup "MAKECHESS_LOCAL_STOCKFISH_SILENT_WATCHDOG.ps1")
}
Write-Host "[1/8] BACKUP_OK: $Backup"
Write-Result "BACKUP_OK: $Backup"

# ----------------------------------------------------------------------
# 2. FREEZE CURRENT WORKING BRIDGE INTO ITS OWN RUNTIME FOLDER
#    This prevents flutter build windows from overwriting the bridge app.
# ----------------------------------------------------------------------
$RuntimeRoot = Join-Path $Root "_runtime\local_stockfish_bridge"
$RuntimeStage = Join-Path $Root ("_runtime\local_stockfish_bridge_stage_" + $Stamp)
$RuntimeExe = Join-Path $RuntimeRoot "my_new_chess_app.exe"

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $RuntimeStage) | Out-Null
if (Test-Path -LiteralPath $RuntimeStage) {
    Remove-Item -LiteralPath $RuntimeStage -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $RuntimeStage | Out-Null
Copy-Item -Path (Join-Path $BuildRelease "*") -Destination $RuntimeStage -Recurse -Force

$StageStockfishDir = Join-Path $RuntimeStage "stockfish"
if (-not (Test-Path -LiteralPath (Join-Path $StageStockfishDir "stockfish.exe"))) {
    New-Item -ItemType Directory -Force -Path $StageStockfishDir | Out-Null
    Copy-Item -Path (Join-Path $Root "stockfish\*") -Destination $StageStockfishDir -Recurse -Force
}

Assert-File (Join-Path $RuntimeStage "my_new_chess_app.exe")
Assert-File (Join-Path $RuntimeStage "stockfish\stockfish.exe")

# Replace runtime only after complete staging copy.
if (Test-Path -LiteralPath $RuntimeRoot) {
    Remove-Item -LiteralPath $RuntimeRoot -Recurse -Force
}
Move-Item -LiteralPath $RuntimeStage -Destination $RuntimeRoot

Write-Host "[2/8] Stable local Stockfish runtime prepared:"
Write-Host "      $RuntimeRoot"
Write-Result "BRIDGE_RUNTIME_OK: $RuntimeRoot"

# ----------------------------------------------------------------------
# 3. INSTALL HIDDEN WATCHDOG V2 TARGETING THE STABLE RUNTIME
# ----------------------------------------------------------------------
$WatchdogV2 = Join-Path $Root "MAKECHESS_LOCAL_STOCKFISH_RUNTIME_WATCHDOG.ps1"
$watchdogText = @'
param([string]$ProjectRoot = "")
$ErrorActionPreference = "SilentlyContinue"
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$BridgeExe = Join-Path $ProjectRoot "_runtime\local_stockfish_bridge\my_new_chess_app.exe"
$HealthUrl = "http://127.0.0.1:17891/health"

$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, "Local\MakeChessLocalStockfishRuntimeV2", [ref]$createdNew)
if (-not $createdNew) { exit 0 }

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class MakeChessRuntimeWin32 {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

function Test-Bridge {
  try {
    $r = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 2
    return (($r.ok -eq $true) -and ($r.stockfish -eq $true))
  } catch { return $false }
}

function Runtime-BridgePids {
  try {
    $exact = $BridgeExe.ToLowerInvariant()
    return @(Get-CimInstance Win32_Process -Filter "Name='my_new_chess_app.exe'" |
      Where-Object { $_.ExecutablePath -and $_.ExecutablePath.ToLowerInvariant() -eq $exact } |
      Select-Object -ExpandProperty ProcessId)
  } catch { return @() }
}

function Hide-BridgeWindows {
  foreach ($pval in (Runtime-BridgePids)) {
    $pid32 = [uint32]$pval
    $callback = [MakeChessRuntimeWin32+EnumWindowsProc]{
      param([IntPtr]$hWnd,[IntPtr]$lParam)
      $wpid=[uint32]0
      [void][MakeChessRuntimeWin32]::GetWindowThreadProcessId($hWnd,[ref]$wpid)
      if ($wpid -eq $pid32 -and [MakeChessRuntimeWin32]::IsWindowVisible($hWnd)) {
        [void][MakeChessRuntimeWin32]::ShowWindow($hWnd,0)
      }
      return $true
    }
    [void][MakeChessRuntimeWin32]::EnumWindows($callback,[IntPtr]::Zero)
  }
}

function Start-Bridge {
  if (-not (Test-Path -LiteralPath $BridgeExe)) { return $false }
  Start-Process -FilePath $BridgeExe -ArgumentList @("--bridge","--minimized") `
    -WorkingDirectory (Split-Path -Parent $BridgeExe) -WindowStyle Hidden | Out-Null
  for($i=0;$i -lt 50;$i++){
    Start-Sleep -Milliseconds 100
    Hide-BridgeWindows
    if(Test-Bridge){ return $true }
  }
  return (Test-Bridge)
}

try {
  while($true){
    Hide-BridgeWindows
    if(-not (Test-Bridge)){
      foreach($pval in (Runtime-BridgePids)){
        Stop-Process -Id $pval -Force -ErrorAction SilentlyContinue
      }
      Start-Sleep -Milliseconds 250
      [void](Start-Bridge)
    }
    Hide-BridgeWindows
    Start-Sleep -Seconds 3
  }
}
finally {
  try { $mutex.ReleaseMutex() } catch {}
  $mutex.Dispose()
}
'@
Set-Content -LiteralPath $WatchdogV2 -Value $watchdogText -Encoding UTF8

# Stop old hidden watchdogs, but not this installer.
try {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
      Where-Object {
        $_.ProcessId -ne $PID -and $_.CommandLine -and
        ($_.CommandLine -match 'MAKECHESS_LOCAL_STOCKFISH_SILENT_WATCHDOG\.ps1' -or
         $_.CommandLine -match 'MAKECHESS_LOCAL_STOCKFISH_RUNTIME_WATCHDOG\.ps1')
      } |
      ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
} catch {}

# Stop current bridge from build folder only. Runtime copy will replace it.
try {
    $oldPath = $BuildExe.ToLowerInvariant()
    Get-CimInstance Win32_Process -Filter "Name='my_new_chess_app.exe'" |
      Where-Object { $_.ExecutablePath -and $_.ExecutablePath.ToLowerInvariant() -eq $oldPath } |
      ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
} catch {}

$startup = [Environment]::GetFolderPath("Startup")
foreach ($lnkName in @("MakeChess Local Stockfish.lnk","MakeChess Local Stockfish Silent.lnk","MakeChess Local Stockfish Runtime.lnk")) {
    $p = Join-Path $startup $lnkName
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
}

$runtimeLnk = Join-Path $startup "MakeChess Local Stockfish Runtime.lnk"
$ws = New-Object -ComObject WScript.Shell
$s = $ws.CreateShortcut($runtimeLnk)
$s.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$s.Arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $WatchdogV2 + '" -ProjectRoot "' + $Root + '"'
$s.WorkingDirectory = $Root
$s.WindowStyle = 7
$s.Description = "MakeChess local Stockfish background runtime"
$s.Save()

Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -ArgumentList @("-NoProfile","-NonInteractive","-WindowStyle","Hidden","-ExecutionPolicy","Bypass","-File","`"$WatchdogV2`"","-ProjectRoot","`"$Root`"") `
    -WorkingDirectory $Root -WindowStyle Hidden | Out-Null

$healthOk = $false
for($i=0;$i -lt 30;$i++){
    Start-Sleep -Milliseconds 500
    try{
        $r = Invoke-RestMethod -Uri "http://127.0.0.1:17891/health" -TimeoutSec 2
        if(($r.ok -eq $true) -and ($r.stockfish -eq $true)){
            $healthOk = $true
            Write-Host ("      HEALTH_JSON: " + ($r | ConvertTo-Json -Compress))
            break
        }
    }catch{}
}
if(-not $healthOk){
    # Emergency fallback: bring back the old build bridge so Stockfish remains usable.
    if(Test-Path -LiteralPath $BuildExe){
        Start-Process -FilePath $BuildExe -ArgumentList @("--bridge","--minimized") `
            -WorkingDirectory $BuildRelease -WindowStyle Hidden | Out-Null
    }
    throw "STABLE_BRIDGE_HEALTH_FAILED"
}
Write-Host "[3/8] Stable hidden Stockfish bridge: OK"
Write-Result "STABLE_BRIDGE_HEALTH_OK"

# ----------------------------------------------------------------------
# 4. PREPARE PATCHED SOURCE FILES
# ----------------------------------------------------------------------
$pub = Get-Content -LiteralPath $Pubspec -Raw -Encoding UTF8
$pub = Replace-Exact $pub 'description: Chess demo project' 'description: MakeChess chess platform' 'pubspec description'
Set-Content -LiteralPath $Pubspec -Value $pub -Encoding UTF8

$manifestObj = Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json
$manifestObj.name = "MakeChess"
$manifestObj.short_name = "MakeChess"
$manifestObj.display = "standalone"
$manifestObj.background_color = "#071827"
$manifestObj.theme_color = "#071827"
$manifestObj.description = "MakeChess — шахматная платформа для игры, обучения, анализа и турниров."
$manifestObj.orientation = "any"
$manifestObj.prefer_related_applications = $false
$manifestJson = $manifestObj | ConvertTo-Json -Depth 10
Set-Content -LiteralPath $Manifest -Value $manifestJson -Encoding UTF8

$indexText = Get-Content -LiteralPath $Index -Raw -Encoding UTF8
$indexText = Replace-Exact $indexText '<meta name="description" content="A new Flutter project.">' '<meta name="description" content="MakeChess — шахматная платформа для игры, обучения, анализа и турниров.">' 'web description'
$indexText = Replace-Exact $indexText '<meta name="apple-mobile-web-app-title" content="my_new_chess_app">' '<meta name="apple-mobile-web-app-title" content="MakeChess">' 'apple title'
$indexText = Replace-Exact $indexText '<title>my_new_chess_app</title>' '<title>MakeChess</title>' 'web title'
if(-not $indexText.Contains('<meta name="theme-color"')){
    $indexText = $indexText.Replace(
        '<meta content="IE=Edge" http-equiv="X-UA-Compatible">',
        '<meta content="IE=Edge" http-equiv="X-UA-Compatible">' + "`r`n  " +
        '<meta name="theme-color" content="#071827">' + "`r`n  " +
        '<meta name="mobile-web-app-capable" content="yes">'
    )
}
Set-Content -LiteralPath $Index -Value $indexText -Encoding UTF8

$cpp = Get-Content -LiteralPath $MainCpp -Raw -Encoding UTF8
$cpp = Replace-Exact $cpp 'window.Create(L"my_new_chess_app", origin, size)' 'window.Create(L"MakeChess", origin, size)' 'Windows title'
Set-Content -LiteralPath $MainCpp -Value $cpp -Encoding UTF8

$rc = Get-Content -LiteralPath $RunnerRc -Raw -Encoding UTF8
$rc = Replace-Exact $rc 'VALUE "CompanyName", "com.example" "\0"' 'VALUE "CompanyName", "MakeChess" "\0"' 'CompanyName'
$rc = Replace-Exact $rc 'VALUE "FileDescription", "my_new_chess_app" "\0"' 'VALUE "FileDescription", "MakeChess" "\0"' 'FileDescription'
$rc = Replace-Exact $rc 'VALUE "InternalName", "my_new_chess_app" "\0"' 'VALUE "InternalName", "MakeChess" "\0"' 'InternalName'
$rc = Replace-Exact $rc 'VALUE "LegalCopyright", "Copyright (C) 2025 com.example. All rights reserved." "\0"' 'VALUE "LegalCopyright", "Copyright (C) 2026 MakeChess. All rights reserved." "\0"' 'Copyright'
$rc = Replace-Exact $rc 'VALUE "OriginalFilename", "my_new_chess_app.exe" "\0"' 'VALUE "OriginalFilename", "MakeChess.exe" "\0"' 'OriginalFilename'
$rc = Replace-Exact $rc 'VALUE "ProductName", "my_new_chess_app" "\0"' 'VALUE "ProductName", "MakeChess" "\0"' 'ProductName'
Set-Content -LiteralPath $RunnerRc -Value $rc -Encoding UTF8

# Validate manifest JSON after writing.
$null = Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json

Write-Host "[4/8] Branding + Web App metadata patched."
Write-Result "SOURCE_PATCH_OK"

# ----------------------------------------------------------------------
# 5. FLUTTER PACKAGES
# ----------------------------------------------------------------------
Write-Host "[5/8] flutter pub get..."
Push-Location $Root
try {
    & flutter pub get
    if($LASTEXITCODE -ne 0){ throw "FLUTTER_PUB_GET_FAILED" }
} finally { Pop-Location }

# ----------------------------------------------------------------------
# 6. BUILD WINDOWS APP FROM lib/main.dart
# ----------------------------------------------------------------------
Write-Host "[6/8] Building MakeChess Windows app..."
$BuildLog = Join-Path $Root "MAKECHESS_WINDOWS_BUILD_V1.log"
if(Test-Path -LiteralPath $BuildLog){ Remove-Item -LiteralPath $BuildLog -Force }

Push-Location $Root
try {
    & flutter build windows --release -t lib/main.dart 2>&1 | Tee-Object -FilePath $BuildLog
    $buildExit = $LASTEXITCODE
} finally { Pop-Location }

if($buildExit -ne 0){
    Write-Host ""
    Write-Host "WINDOWS_BUILD_FAILED - restoring the five patched source files..."
    Copy-Item -LiteralPath (Join-Path $Backup "pubspec.yaml")  -Destination $Pubspec  -Force
    Copy-Item -LiteralPath (Join-Path $Backup "manifest.json") -Destination $Manifest -Force
    Copy-Item -LiteralPath (Join-Path $Backup "index.html")    -Destination $Index    -Force
    Copy-Item -LiteralPath (Join-Path $Backup "main.cpp")      -Destination $MainCpp  -Force
    Copy-Item -LiteralPath (Join-Path $Backup "Runner.rc")     -Destination $RunnerRc -Force
    Write-Result "WINDOWS_BUILD_FAILED"
    Write-Result "PATCHES_ROLLED_BACK"
    Write-Result "Build log: $BuildLog"
    throw "WINDOWS_BUILD_FAILED"
}

Write-Result "WINDOWS_BUILD_OK"

# ----------------------------------------------------------------------
# 7. CREATE PORTABLE WINDOWS DISTRIBUTION
# ----------------------------------------------------------------------
$DistRoot = Join-Path $Root "dist\MakeChess_Windows"
if(Test-Path -LiteralPath $DistRoot){ Remove-Item -LiteralPath $DistRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $DistRoot | Out-Null
Copy-Item -Path (Join-Path $BuildRelease "*") -Destination $DistRoot -Recurse -Force

$DistOldExe = Join-Path $DistRoot "my_new_chess_app.exe"
$DistExe = Join-Path $DistRoot "MakeChess.exe"
Assert-File $DistOldExe
Rename-Item -LiteralPath $DistOldExe -NewName "MakeChess.exe"

$DistStockfish = Join-Path $DistRoot "stockfish"
if(-not (Test-Path -LiteralPath (Join-Path $DistStockfish "stockfish.exe"))){
    New-Item -ItemType Directory -Force -Path $DistStockfish | Out-Null
    Copy-Item -Path (Join-Path $Root "stockfish\*") -Destination $DistStockfish -Recurse -Force
}
Assert-File $DistExe
Assert-File (Join-Path $DistStockfish "stockfish.exe")

# Desktop shortcut to the portable distribution.
$desktop = [Environment]::GetFolderPath("Desktop")
$desktopLnk = Join-Path $desktop "MakeChess.lnk"
$ws2 = New-Object -ComObject WScript.Shell
$sd = $ws2.CreateShortcut($desktopLnk)
$sd.TargetPath = $DistExe
$sd.WorkingDirectory = $DistRoot
$sd.IconLocation = "$DistExe,0"
$sd.Description = "MakeChess"
$sd.Save()

Write-Host "[7/8] Windows app ready:"
Write-Host "      $DistExe"
Write-Host "      Desktop shortcut: $desktopLnk"
Write-Result "WINDOWS_APP: $DistExe"
Write-Result "DESKTOP_SHORTCUT: $desktopLnk"

# ----------------------------------------------------------------------
# 8. WEB APP SOURCE READY - DO NOT PUBLISH HERE
# ----------------------------------------------------------------------
Write-Host "[8/8] Web App/PWA source is ready."
Write-Host "      Existing PUBLISH_MAKECHESS.cmd must be used later for production web deploy."
Write-Result "WEBAPP_SOURCE_READY"
Write-Result "NO_WEB_PUBLISH_PERFORMED"
Write-Result "Finished: $(Get-Date -Format o)"

Write-Host ""
Write-Host "=========================================================="
Write-Host "MAKECHESS_WINDOWS_WEBAPP_V1_OK"
Write-Host "=========================================================="
Write-Host "Windows app:"
Write-Host "  $DistExe"
Write-Host ""
Write-Host "Web App/PWA:"
Write-Host "  prepared, NOT published"
Write-Host ""
Write-Host "Local Stockfish:"
Write-Host "  moved to independent hidden runtime, health OK"
Write-Host ""
Write-Host "NEXT:"
Write-Host "  1. Open MakeChess from the new Desktop shortcut."
Write-Host "  2. Send the result/screenshot to ChatGPT."
Write-Host "  3. Do NOT run PUBLISH_MAKECHESS.cmd until Windows app is checked."
Write-Host "=========================================================="
