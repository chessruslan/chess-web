param(
  [string]$ProjectRoot = "C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$LibRoot = Join-Path $ProjectRoot "lib"
$OutZip = Join-Path $ProjectRoot "MAKECHESS_CURRENT_ALL_RUSSIAN_UI_V5_FILES.zip"
$TempRoot = Join-Path $env:TEMP "makechess_all_russian_ui_v5"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " MAKECHESS - ALL RUSSIAN UI V5 COLLECTOR" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path -LiteralPath $LibRoot)) {
  throw "lib folder not found: $LibRoot"
}

if (Test-Path -LiteralPath $TempRoot) {
  Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

$allDart = Get-ChildItem -LiteralPath $LibRoot -Recurse -File -Filter *.dart | Where-Object {
  $name = $_.Name.ToLowerInvariant()
  $full = $_.FullName.ToLowerInvariant()

  -not (
    $name.Contains(".before_") -or
    $name.Contains("_before_") -or
    $name.EndsWith(".bak.dart") -or
    $name.EndsWith(".old.dart") -or
    $name.EndsWith(".orig.dart") -or
    $name.Contains("backup") -or
    $full.Contains("\backup\") -or
    $full.Contains("\backups\") -or
    $full.Contains("\localization_backups\")
  )
}

$selected = New-Object System.Collections.Generic.List[object]

foreach ($file in $allDart) {
  $text = [System.IO.File]::ReadAllText($file.FullName)
  if ($text -match '[А-Яа-яЁё]') {
    $relative = $file.FullName.Substring($ProjectRoot.Length).TrimStart('\')
    $matches = [regex]::Matches($text, '[А-Яа-яЁё]+')
    $selected.Add([pscustomobject]@{
      File = $file
      Relative = $relative
      CyrillicFragments = $matches.Count
    })
  }
}

if ($selected.Count -eq 0) {
  throw "No current Dart files with Cyrillic text were found."
}

Write-Host "Found current Dart files containing Cyrillic: $($selected.Count)" -ForegroundColor Green
Write-Host ""

$manifest = New-Object System.Collections.Generic.List[string]
$manifest.Add("MAKECHESS ALL RUSSIAN UI V5")
$manifest.Add("Project root: $ProjectRoot")
$manifest.Add("Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$manifest.Add("Current Dart files containing Cyrillic: $($selected.Count)")
$manifest.Add("")
$manifest.Add("FILES:")

$index = 0
foreach ($item in $selected | Sort-Object Relative) {
  $index++
  $source = $item.File.FullName
  $relative = $item.Relative
  $destination = Join-Path $TempRoot $relative
  $destinationDir = Split-Path -Parent $destination
  New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
  Copy-Item -LiteralPath $source -Destination $destination -Force

  $hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()

  Write-Host ("[{0}/{1}] {2}" -f $index, $selected.Count, $relative) -ForegroundColor DarkGray
  $manifest.Add("$relative")
  $manifest.Add("  CyrillicFragments: $($item.CyrillicFragments)")
  $manifest.Add("  SHA256: $hash")
}

$manifest.Add("")
$manifest.Add("NOTE:")
$manifest.Add("This collector changes NOTHING in the project.")
$manifest.Add("It excludes historical .before_ / backup copies.")
$manifest.Add("The ZIP is intended for a broad V5 localization sweep.")
$manifest | Set-Content -LiteralPath (Join-Path $TempRoot "MAKECHESS_ALL_RUSSIAN_UI_V5_MANIFEST.txt") -Encoding UTF8

if (Test-Path -LiteralPath $OutZip) {
  Remove-Item -LiteralPath $OutZip -Force
}

Write-Host ""
Write-Host "Creating ZIP..." -ForegroundColor Cyan

Push-Location $TempRoot
try {
  & tar -a -c -f $OutZip .
  if ($LASTEXITCODE -ne 0) {
    throw "ZIP creation failed."
  }
}
finally {
  Pop-Location
}

Remove-Item -LiteralPath $TempRoot -Recurse -Force

Write-Host ""
Write-Host "DONE." -ForegroundColor Green
Write-Host "No project source file was changed." -ForegroundColor Green
Write-Host ""
Write-Host "Created:" -ForegroundColor Cyan
Write-Host "  $OutZip"
Write-Host ""
Write-Host "Send this ZIP to ChatGPT." -ForegroundColor Cyan
