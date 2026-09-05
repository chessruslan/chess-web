$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Host ""
    Write-Host "ОШИБКА: $Message" -ForegroundColor Red
    exit 1
}

$root = (Get-Location).Path
$gitDir = Join-Path $root ".git"
if (-not (Test-Path $gitDir)) {
    Fail "Запустите этот файл из корня проекта MakeChess."
}

$buildFile = Join-Path $root "BUILD_MAKECHESS_WINDOWS.cmd"
if (-not (Test-Path $buildFile)) {
    Fail "Не найден BUILD_MAKECHESS_WINDOWS.cmd"
}

$localEnvName = "MAKECHESS_WINDOWS_LOCAL_ENV.cmd"
$localEnvFile = Join-Path $root $localEnvName
$gitignore = Join-Path $root ".gitignore"

$text = [System.IO.File]::ReadAllText($buildFile)

# Ищем только прямое присваивание ключа, значение на экран не выводим.
$rx = [regex]'(?im)^\s*set\s+"?SUPABASE_ANON_KEY\s*=\s*([^"\r\n]+)"?\s*$'
$m = $rx.Match($text)

if ($m.Success) {
    $secret = $m.Groups[1].Value.Trim()

    # Сохраняем ключ только в локальный игнорируемый файл.
    $localContent = "@echo off`r`nset `"SUPABASE_ANON_KEY=$secret`"`r`n"
    [System.IO.File]::WriteAllText(
        $localEnvFile,
        $localContent,
        (New-Object System.Text.UTF8Encoding($false))
    )

    $replacement = @'
if exist "%~dp0MAKECHESS_WINDOWS_LOCAL_ENV.cmd" call "%~dp0MAKECHESS_WINDOWS_LOCAL_ENV.cmd"
if not defined SUPABASE_ANON_KEY (
  echo OSHIBKA: ne nayden lokalnyy SUPABASE_ANON_KEY.
  echo Ozhidaetsya fayl MAKECHESS_WINDOWS_LOCAL_ENV.cmd ryadom so skriptom.
  exit /b 1
)
'@.TrimEnd()

    $text = $rx.Replace($text, $replacement, 1)
    [System.IO.File]::WriteAllText(
        $buildFile,
        $text,
        (New-Object System.Text.UTF8Encoding($false))
    )
}
elseif (-not (Test-Path $localEnvFile)) {
    Fail "Прямой ключ в BUILD_MAKECHESS_WINDOWS.cmd не найден, но локального файла ключа тоже нет."
}

# Гарантируем, что локальный файл с ключом никогда не попадёт в Git.
if (-not (Test-Path $gitignore)) {
    New-Item -ItemType File -Path $gitignore | Out-Null
}
$ignoreText = [System.IO.File]::ReadAllText($gitignore)
if ($ignoreText -notmatch '(?m)^/?MAKECHESS_WINDOWS_LOCAL_ENV\.cmd\s*$') {
    if ($ignoreText.Length -gt 0 -and -not $ignoreText.EndsWith("`n")) {
        Add-Content -Path $gitignore -Value ""
    }
    Add-Content -Path $gitignore -Value "/MAKECHESS_WINDOWS_LOCAL_ENV.cmd"
}

# Обновляем индекс уже безопасной версией файлов.
git add -A
if ($LASTEXITCODE -ne 0) { Fail "git add завершился ошибкой." }

# Локальный файл с ключом не должен быть staged.
$staged = git diff --cached --name-only
if ($staged -contains $localEnvName) {
    git restore --staged -- $localEnvName 2>$null
    if ($LASTEXITCODE -ne 0) { Fail "Не удалось убрать локальный файл ключа из staged." }
}

# Проверяем, что в staged-версии build-скрипта больше нет прямого ключа.
$cachedBuild = git show ":BUILD_MAKECHESS_WINDOWS.cmd" 2>$null
if ($LASTEXITCODE -ne 0) { Fail "Не удалось проверить staged BUILD_MAKECHESS_WINDOWS.cmd." }
$cachedBuildText = ($cachedBuild -join "`n")
if ($rx.IsMatch($cachedBuildText)) {
    Fail "В staged BUILD_MAKECHESS_WINDOWS.cmd всё ещё найден прямой ключ. Коммит НЕ выполнен."
}

# Проверяем, что локальный файл действительно игнорируется.
git check-ignore -q -- $localEnvName
if ($LASTEXITCODE -ne 0) {
    Fail "$localEnvName не игнорируется Git. Коммит НЕ выполнен."
}

# Коммитим текущую проверенную рабочую точку.
$branch = (git branch --show-current).Trim()
if ([string]::IsNullOrWhiteSpace($branch)) {
    Fail "Не удалось определить текущую ветку."
}

git commit -m "SAFE: Windows online working state before tournament auto refresh"
if ($LASTEXITCODE -ne 0) { Fail "git commit завершился ошибкой." }

git push -u origin $branch
if ($LASTEXITCODE -ne 0) { Fail "Коммит создан локально, но push на GitHub завершился ошибкой." }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  СОХРАНЕНО: рабочее состояние MakeChess зафиксировано" -ForegroundColor Green
Write-Host "  Ветка: $branch" -ForegroundColor Green
Write-Host "  Локальный ключ в Git НЕ добавлен" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
