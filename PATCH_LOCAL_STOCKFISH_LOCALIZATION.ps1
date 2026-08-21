param(
  [string]$LocalizationPath = ""
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($LocalizationPath)) {
  $LocalizationPath = Join-Path $PSScriptRoot 'lib\localization\makechess_localization.dart'
}

if (-not (Test-Path -LiteralPath $LocalizationPath)) {
  throw "Localization file not found: $LocalizationPath"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$text = [System.IO.File]::ReadAllText($LocalizationPath, [System.Text.Encoding]::UTF8)

$hasLabel = $text.Contains('"Локальный Stockfish": <String>[')
$hasError = $text.Contains('"Локальный Stockfish не запущен. Сначала установите локальный модуль MakeChess.": <String>[')

if ($hasLabel -and $hasError) {
  Write-Host 'LOCAL_STOCKFISH_LOCALIZATION_ALREADY_PRESENT'
  exit 0
}

$marker = 'static const Map<String, List<String>> _v4PhraseRows = <String, List<String>>{'
$index = $text.IndexOf($marker)
if ($index -lt 0) {
  throw 'Could not find _v4PhraseRows marker. Localization file was NOT changed.'
}

$insertAt = $index + $marker.Length

$rows = ''

if (-not $hasLabel) {
  $rows += @'

    "Локальный Stockfish": <String>[
      "Локальный Stockfish",
      "Local Stockfish",
      "Lokaler Stockfish",
      "Stockfish local",
      "Stockfish local",
      "Stockfish المحلي",
      "本地 Stockfish",
      "स्थानीय Stockfish",
      "ローカル Stockfish",
      "로컬 Stockfish",
      "Stockfish cục bộ",
    ],
'@
}

if (-not $hasError) {
  $rows += @'

    "Локальный Stockfish не запущен. Сначала установите локальный модуль MakeChess.": <String>[
      "Локальный Stockfish не запущен. Сначала установите локальный модуль MakeChess.",
      "Local Stockfish could not be started. Install the MakeChess local module first.",
      "Lokaler Stockfish konnte nicht gestartet werden. Installieren Sie zuerst das lokale MakeChess-Modul.",
      "Impossible de démarrer Stockfish local. Installez d’abord le module local MakeChess.",
      "No se pudo iniciar Stockfish local. Instale primero el módulo local de MakeChess.",
      "تعذر تشغيل Stockfish المحلي. ثبّت وحدة MakeChess المحلية أولاً.",
      "无法启动本地 Stockfish。请先安装 MakeChess 本地模块。",
      "स्थानीय Stockfish शुरू नहीं हो सका। पहले MakeChess का स्थानीय मॉड्यूल इंस्टॉल करें।",
      "ローカル Stockfish を起動できません。先に MakeChess のローカルモジュールをインストールしてください。",
      "로컬 Stockfish를 시작할 수 없습니다. 먼저 MakeChess 로컬 모듈을 설치하세요.",
      "Không thể khởi động Stockfish cục bộ. Hãy cài mô-đun MakeChess cục bộ trước.",
    ],
'@
}

$backup = "$LocalizationPath.before_local_stockfish.bak"
Copy-Item -LiteralPath $LocalizationPath -Destination $backup -Force

$newText = $text.Insert($insertAt, $rows)
[System.IO.File]::WriteAllText($LocalizationPath, $newText, $utf8NoBom)

Write-Host 'LOCAL_STOCKFISH_LOCALIZATION_OK'
Write-Host "Backup: $backup"
