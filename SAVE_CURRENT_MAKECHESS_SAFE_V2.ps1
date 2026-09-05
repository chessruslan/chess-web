$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

$root = (Get-Location).Path
if (-not (Test-Path (Join-Path $root ".git"))) {
    Fail "Run this script from the MakeChess project root."
}

$buildFile = Join-Path $root "BUILD_MAKECHESS_WINDOWS.cmd"
if (-not (Test-Path $buildFile)) {
    Fail "BUILD_MAKECHESS_WINDOWS.cmd was not found."
}

$localEnvName = "MAKECHESS_WINDOWS_LOCAL_ENV.cmd"
$localEnvFile = Join-Path $root $localEnvName
$gitignore = Join-Path $root ".gitignore"

$text = [System.IO.File]::ReadAllText($buildFile)

# Match only a direct hard-coded value. Do not print the value.
$pattern = '(?im)^\s*set\s+"?SUPABASE_ANON_KEY\s*=\s*([^"%\r\n][^"\r\n]*)"?\s*$'
$rx = New-Object System.Text.RegularExpressions.Regex($pattern)
$m = $rx.Match($text)

if ($m.Success) {
    $secret = $m.Groups[1].Value.Trim()

    $localContent = "@echo off`r`nset `"SUPABASE_ANON_KEY=$secret`"`r`n"
    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($localEnvFile, $localContent, $utf8Bom)

    $replacement = "if exist `"%~dp0MAKECHESS_WINDOWS_LOCAL_ENV.cmd`" call `"%~dp0MAKECHESS_WINDOWS_LOCAL_ENV.cmd`"`r`n" +
                   "if not defined SUPABASE_ANON_KEY (`r`n" +
                   "  echo ERROR: local SUPABASE_ANON_KEY is missing.`r`n" +
                   "  echo Expected: MAKECHESS_WINDOWS_LOCAL_ENV.cmd next to this script.`r`n" +
                   "  exit /b 1`r`n" +
                   ")"

    $text = $rx.Replace($text, $replacement, 1)
    [System.IO.File]::WriteAllText($buildFile, $text, $utf8Bom)
}
elseif (-not (Test-Path $localEnvFile)) {
    Fail "No hard-coded key was found, and the local key file does not exist."
}

# Ensure the local key file is ignored by Git.
if (-not (Test-Path $gitignore)) {
    New-Item -ItemType File -Path $gitignore | Out-Null
}

$ignoreText = [System.IO.File]::ReadAllText($gitignore)
if ($ignoreText -notmatch '(?m)^/?MAKECHESS_WINDOWS_LOCAL_ENV\.cmd\s*$') {
    Add-Content -Path $gitignore -Value "/MAKECHESS_WINDOWS_LOCAL_ENV.cmd"
}

git add -A
if ($LASTEXITCODE -ne 0) {
    Fail "git add failed."
}

# Safety: local secret file must not be staged.
$stagedNames = @(git diff --cached --name-only)
if ($stagedNames -contains $localEnvName) {
    git restore --staged -- $localEnvName
    if ($LASTEXITCODE -ne 0) {
        Fail "Could not unstage the local secret file."
    }
}

git check-ignore -q -- $localEnvName
if ($LASTEXITCODE -ne 0) {
    Fail "The local secret file is not ignored by Git."
}

# Safety: staged BUILD script must not contain a hard-coded anon key.
$cachedBuildLines = @(git show ":BUILD_MAKECHESS_WINDOWS.cmd" 2>$null)
if ($LASTEXITCODE -ne 0) {
    Fail "Could not inspect staged BUILD_MAKECHESS_WINDOWS.cmd."
}
$cachedBuildText = $cachedBuildLines -join "`n"
if ($rx.IsMatch($cachedBuildText)) {
    Fail "A hard-coded anon key is still present in staged BUILD_MAKECHESS_WINDOWS.cmd. Commit aborted."
}

$branch = (git branch --show-current).Trim()
if ([string]::IsNullOrWhiteSpace($branch)) {
    Fail "Could not determine current Git branch."
}

git commit -m "SAFE: Windows online working state before tournament auto refresh"
if ($LASTEXITCODE -ne 0) {
    Fail "git commit failed."
}

git push -u origin $branch
if ($LASTEXITCODE -ne 0) {
    Fail "Commit was created locally, but push failed."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "SAVED: MakeChess working state committed and pushed." -ForegroundColor Green
Write-Host "BRANCH: $branch" -ForegroundColor Green
Write-Host "LOCAL SECRET FILE: NOT COMMITTED" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
