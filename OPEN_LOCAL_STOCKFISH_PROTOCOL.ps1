param(
  [Parameter(Mandatory = $true)]
  [string]$Uri,

  [Parameter(Mandatory = $true)]
  [string]$ExePath
)

$ErrorActionPreference = 'Stop'

if (-not $Uri.StartsWith('makechess-stockfish://', [System.StringComparison]::OrdinalIgnoreCase)) {
  exit 3
}

$requestDir = Join-Path $env:LOCALAPPDATA 'MakeChess'
$requestFile = Join-Path $requestDir 'local_stockfish_request.txt'

New-Item -ItemType Directory -Path $requestDir -Force | Out-Null

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($requestFile, $Uri, $utf8NoBom)

if (-not (Test-Path -LiteralPath $ExePath)) {
  Add-Type -AssemblyName PresentationFramework
  [System.Windows.MessageBox]::Show(
    "Локальное приложение MakeChess Stockfish не найдено:`n$ExePath`n`nЗапустите 04_INSTALL_LOCAL_STOCKFISH_BRIDGE.cmd.",
    "MakeChess — Local Stockfish"
  ) | Out-Null
  exit 2
}

Start-Process -FilePath $ExePath
