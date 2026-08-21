param(
  [string]$ProjectRoot = "C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$lib = Join-Path $ProjectRoot "lib"
$out = Join-Path $ProjectRoot "MAKECHESS_CURRENT_REMAINING_UI_V6_FILES.zip"
$tmp = Join-Path $env:TEMP "makechess_remaining_ui_v6"

if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

$selected = New-Object System.Collections.Generic.List[string]
$report = New-Object System.Collections.Generic.List[string]

Get-ChildItem $lib -Recurse -File -Filter *.dart | ForEach-Object {
  $name = $_.Name.ToLowerInvariant()
  $full = $_.FullName.ToLowerInvariant()

  if (
    $name.Contains("before_") -or
    $name.Contains("backup") -or
    $name.EndsWith(".bak.dart") -or
    $name.EndsWith(".old.dart") -or
    $name.EndsWith(".orig.dart") -or
    $full.Contains("\backup\") -or
    $full.Contains("\backups\") -or
    $full.Contains("\localization_backups\")
  ) { return }

  $rel = $_.FullName.Substring($ProjectRoot.Length).TrimStart("\")

  if ($rel -ieq "lib\localization\makechess_localization.dart") {
    $selected.Add($_.FullName)
    return
  }

  $lines = [IO.File]::ReadAllLines($_.FullName)
  $hits = New-Object System.Collections.Generic.List[string]

  for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    $trim = $line.TrimStart()

    if ($line -notmatch "[А-Яа-яЁё]") { continue }
    if (
      $trim.StartsWith("//") -or
      $trim.StartsWith("/*") -or
      $trim.StartsWith("*")
    ) { continue }

    $hits.Add(("{0}: {1}" -f ($i + 1), $line.Trim()))
  }

  if ($hits.Count -gt 0) {
    $selected.Add($_.FullName)
    $report.Add("FILE: $rel")
    $report.Add("CANDIDATES: $($hits.Count)")
    foreach ($hit in $hits) { $report.Add("  $hit") }
    $report.Add("")
  }
}

$selected = $selected | Sort-Object -Unique

Write-Host ""
Write-Host "Remaining V6 candidate files: $($selected.Count)" -ForegroundColor Green

foreach ($src in $selected) {
  $rel = $src.Substring($ProjectRoot.Length).TrimStart("\")
  $dst = Join-Path $tmp $rel
  New-Item -ItemType Directory -Path (Split-Path $dst -Parent) -Force | Out-Null
  Copy-Item $src $dst -Force
  Write-Host "OK - $rel"
}

$report | Set-Content (Join-Path $tmp "MAKECHESS_REMAINING_UI_V6_REPORT.txt") -Encoding UTF8

if (Test-Path $out) { Remove-Item $out -Force }

Push-Location $tmp
try {
  & tar -a -c -f $out .
  if ($LASTEXITCODE -ne 0) { throw "ZIP creation failed." }
}
finally {
  Pop-Location
}

Remove-Item $tmp -Recurse -Force

Write-Host ""
Write-Host "DONE." -ForegroundColor Green
Write-Host "No project source file was changed." -ForegroundColor Green
Write-Host $out
