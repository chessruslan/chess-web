param(
  [Parameter(Mandatory=$true)][string]$Version
)
$ErrorActionPreference = 'Stop'

$installer = "build\installer\MakeChessSetup-$Version.exe"
if (-not (Test-Path $installer)) {
  throw "Installer not found: $installer"
}

$sha = (Get-FileHash $installer -Algorithm SHA256).Hash.ToLowerInvariant()
$url = "https://makechess.com/desktop/MakeChessSetup-$Version.exe"

$data = [ordered]@{
  version = $Version
  published_at = (Get-Date).ToUniversalTime().ToString('o')
  notes = "Автоматическое обновление MakeChess $Version"
  windows = [ordered]@{
    url = $url
    sha256 = $sha
  }
}

New-Item -ItemType Directory -Path 'desktop' -Force | Out-Null
$data | ConvertTo-Json -Depth 5 | Set-Content 'desktop\update.json' -Encoding UTF8
Write-Host "UPDATE_JSON_OK SHA256=$sha"
