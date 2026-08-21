param(
    [string]$ProjectRoot = ""
)

$ErrorActionPreference = "SilentlyContinue"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)

$BridgeExe = Join-Path $ProjectRoot "build\windows\x64\runner\Release\my_new_chess_app.exe"
$HealthUrl = "http://127.0.0.1:17891/health"

# Only one hidden watchdog per Windows user.
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, "Local\MakeChessLocalStockfishSilentV1", [ref]$createdNew)
if (-not $createdNew) {
    exit 0
}

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class MakeChessWin32 {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

function Hide-BridgeWindows {
    $bridgePath = $BridgeExe.ToLowerInvariant()

    $targets = @()
    try {
        $targets = Get-CimInstance Win32_Process -Filter "Name='my_new_chess_app.exe'" |
            Where-Object {
                ($_.ExecutablePath -and $_.ExecutablePath.ToLowerInvariant() -eq $bridgePath) -or
                ($_.CommandLine -and $_.CommandLine -match '--bridge')
            } |
            Select-Object -ExpandProperty ProcessId
    } catch {}

    foreach ($pidValue in $targets) {
        $pid32 = [uint32]$pidValue
        $callback = [MakeChessWin32+EnumWindowsProc]{
            param([IntPtr]$hWnd, [IntPtr]$lParam)
            $windowPid = [uint32]0
            [void][MakeChessWin32]::GetWindowThreadProcessId($hWnd, [ref]$windowPid)
            if ($windowPid -eq $pid32 -and [MakeChessWin32]::IsWindowVisible($hWnd)) {
                # SW_HIDE = 0. Hide the window; DO NOT stop the process/bridge.
                [void][MakeChessWin32]::ShowWindow($hWnd, 0)
            }
            return $true
        }
        [void][MakeChessWin32]::EnumWindows($callback, [IntPtr]::Zero)
    }
}

function Test-Bridge {
    try {
        $r = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 2
        return (($r.ok -eq $true) -and ($r.stockfish -eq $true))
    } catch {
        return $false
    }
}

function Start-BridgeHidden {
    if (-not (Test-Path -LiteralPath $BridgeExe)) {
        return $false
    }

    try {
        Start-Process `
            -FilePath $BridgeExe `
            -ArgumentList @("--bridge", "--minimized") `
            -WorkingDirectory (Split-Path -Parent $BridgeExe) `
            -WindowStyle Hidden | Out-Null
    } catch {
        return $false
    }

    # Hide immediately and repeatedly while Flutter creates its native window.
    for ($i = 0; $i -lt 50; $i++) {
        Start-Sleep -Milliseconds 100
        Hide-BridgeWindows
        if (Test-Bridge) {
            return $true
        }
    }
    return (Test-Bridge)
}

try {
    while ($true) {
        Hide-BridgeWindows

        if (-not (Test-Bridge)) {
            # Do not touch unrelated MakeChess processes. Kill only bridge-mode
            # copies of this exact EXE before restoring the local service.
            try {
                $bridgePath = $BridgeExe.ToLowerInvariant()
                Get-CimInstance Win32_Process -Filter "Name='my_new_chess_app.exe'" |
                    Where-Object {
                        ($_.ExecutablePath -and $_.ExecutablePath.ToLowerInvariant() -eq $bridgePath) -and
                        ($_.CommandLine -and $_.CommandLine -match '--bridge')
                    } |
                    ForEach-Object {
                        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
                    }
            } catch {}

            Start-Sleep -Milliseconds 300
            [void](Start-BridgeHidden)
        }

        Hide-BridgeWindows
        Start-Sleep -Seconds 3
    }
}
finally {
    try { $mutex.ReleaseMutex() } catch {}
    $mutex.Dispose()
}
