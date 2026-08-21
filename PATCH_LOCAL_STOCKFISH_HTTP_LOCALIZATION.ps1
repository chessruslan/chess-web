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

$marker = 'static const Map<String, List<String>> _v4PhraseRows = <String, List<String>>{'
$index = $text.IndexOf($marker)
if ($index -lt 0) {
  throw 'Could not find _v4PhraseRows marker. Localization file was NOT changed.'
}

$insertAt = $index + $marker.Length
$rows = ''

$key1 = 'Позиция отправлена в локальный Stockfish.'
if (-not $text.Contains('"' + $key1 + '": <String>[')) {
  $rows += @'

    "Позиция отправлена в локальный Stockfish.": <String>[
      "Позиция отправлена в локальный Stockfish.",
      "Position sent to local Stockfish.",
      "Position an lokalen Stockfish gesendet.",
      "Position envoyée à Stockfish local.",
      "Posición enviada a Stockfish local.",
      "تم إرسال الوضعية إلى Stockfish المحلي.",
      "局面已发送到本地 Stockfish。",
      "स्थिति स्थानीय Stockfish को भेज दी गई है।",
      "局面をローカル Stockfish に送信しました。",
      "포지션을 로컬 Stockfish로 보냈습니다.",
      "Đã gửi thế cờ tới Stockfish cục bộ.",
    ],
'@
}

$key2 = 'Локальный Stockfish недоступен. Запустите локальный модуль и разрешите Chrome доступ к локальной сети.'
if (-not $text.Contains('"' + $key2 + '": <String>[')) {
  $rows += @'

    "Локальный Stockfish недоступен. Запустите локальный модуль и разрешите Chrome доступ к локальной сети.": <String>[
      "Локальный Stockfish недоступен. Запустите локальный модуль и разрешите Chrome доступ к локальной сети.",
      "Local Stockfish is unavailable. Start the local module and allow Chrome access to the local network.",
      "Lokaler Stockfish ist nicht verfügbar. Starten Sie das lokale Modul und erlauben Sie Chrome den Zugriff auf das lokale Netzwerk.",
      "Stockfish local est indisponible. Démarrez le module local et autorisez Chrome à accéder au réseau local.",
      "Stockfish local no está disponible. Inicie el módulo local y permita que Chrome acceda a la red local.",
      "Stockfish المحلي غير متاح. شغّل الوحدة المحلية واسمح لـ Chrome بالوصول إلى الشبكة المحلية.",
      "本地 Stockfish 不可用。请启动本地模块，并允许 Chrome 访问本地网络。",
      "स्थानीय Stockfish उपलब्ध नहीं है। स्थानीय मॉड्यूल शुरू करें और Chrome को स्थानीय नेटवर्क एक्सेस की अनुमति दें।",
      "ローカル Stockfish を利用できません。ローカルモジュールを起動し、Chrome にローカルネットワークへのアクセスを許可してください。",
      "로컬 Stockfish를 사용할 수 없습니다. 로컬 모듈을 실행하고 Chrome의 로컬 네트워크 접근을 허용하세요.",
      "Stockfish cục bộ không khả dụng. Hãy chạy mô-đun cục bộ và cho phép Chrome truy cập mạng cục bộ.",
    ],
'@
}

if ([string]::IsNullOrEmpty($rows)) {
  Write-Host 'LOCAL_HTTP_BRIDGE_LOCALIZATION_ALREADY_PRESENT'
  exit 0
}

$backup = "$LocalizationPath.before_local_http_bridge.bak"
Copy-Item -LiteralPath $LocalizationPath -Destination $backup -Force

$newText = $text.Insert($insertAt, $rows)
[System.IO.File]::WriteAllText($LocalizationPath, $newText, $utf8NoBom)

Write-Host 'LOCAL_HTTP_BRIDGE_LOCALIZATION_OK'
Write-Host "Backup: $backup"
