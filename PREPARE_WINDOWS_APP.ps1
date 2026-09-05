$ErrorActionPreference = 'Stop'

Write-Host 'MAKECHESS - prepare Windows desktop project'

$packageName = 'my_new_chess_app'
if (Test-Path 'pubspec.yaml') {
    $match = Select-String -Path 'pubspec.yaml' -Pattern '^name:\s*([A-Za-z0-9_]+)\s*$' | Select-Object -First 1
    if ($match -and $match.Matches.Count -gt 0) {
        $packageName = $match.Matches[0].Groups[1].Value
    }
}

if (-not (Test-Path 'windows\CMakeLists.txt')) {
    & flutter config --enable-windows-desktop | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'flutter config failed' }
    & flutter create --platforms=windows . | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'flutter create windows failed' }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$cmake = 'windows\CMakeLists.txt'
if (Test-Path $cmake) {
    $text = Get-Content $cmake -Raw
    $replacement = 'set(BINARY_NAME "' + $packageName + '")'
    $text = $text -replace 'set\(BINARY_NAME\s+"[^"]+"\)', $replacement
    [System.IO.File]::WriteAllText((Resolve-Path $cmake), $text, $utf8NoBom)
}

$runnerCmake = 'windows\runner\CMakeLists.txt'
if (Test-Path $runnerCmake) {
    $text = Get-Content $runnerCmake -Raw
    $text = $text -replace '(?ms)\r?\n?# MAKECHESS_OUTPUT_NAME_BEGIN.*?# MAKECHESS_OUTPUT_NAME_END\r?\n?', "`r`n"

    $outputBlock = @'
# MAKECHESS_OUTPUT_NAME_BEGIN
set_target_properties(${BINARY_NAME} PROPERTIES OUTPUT_NAME "MakeChess")
# MAKECHESS_OUTPUT_NAME_END
'@

    $text = $text.TrimEnd() + "`r`n`r`n" + $outputBlock.TrimEnd() + "`r`n"
    [System.IO.File]::WriteAllText((Resolve-Path $runnerCmake), $text, $utf8NoBom)
}

foreach ($file in @('windows\runner\main.cpp','windows\runner\Runner.rc')) {
    if (Test-Path $file) {
        $text = Get-Content $file -Raw
        $text = $text -replace [regex]::Escape($packageName), 'MakeChess'
        $text = $text -replace 'Chess demo project', 'MakeChess'
        [System.IO.File]::WriteAllText((Resolve-Path $file), $text, $utf8NoBom)
    }
}

$iconSource = 'installer\MakeChess.ico'
$iconTarget = 'windows\runner\resources\app_icon.ico'
if ((Test-Path $iconSource) -and (Test-Path 'windows\runner\resources')) {
    Copy-Item $iconSource $iconTarget -Force
}

# IMPORTANT:
# Do NOT delete build\windows here.
# Keeping the build cache makes normal development builds much faster
# and avoids access-denied errors when MakeChess.exe still has files open.

Write-Host ('WINDOWS_PROJECT_READY: target=' + $packageName + ', exe=MakeChess.exe')
