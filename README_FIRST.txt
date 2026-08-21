MAKECHESS — LOCAL STOCKFISH BRIDGE V1

ЦЕЛЬ
Кнопка "Лучший ход" в правой панели заменяется на "Локальный Stockfish".
Нажатие в web-версии передает ТЕКУЩИЙ FEN в локальное Windows-приложение.
Локальное приложение запускает установленный stockfish.exe и автоматически начинает анализ.
Сам анализ не использует интернет.

ЧТО ЗАМЕНИТЬ
1) lib\main.dart
2) lib\ui\panels\right_sidebar_panel.dart
3) lib\stockfish_test_app.dart

ЧТО ПОЛОЖИТЬ В КОРЕНЬ ПРОЕКТА
4) OPEN_LOCAL_STOCKFISH_PROTOCOL.ps1
5) PATCH_LOCAL_STOCKFISH_LOCALIZATION.ps1
6) 04_INSTALL_LOCAL_STOCKFISH_BRIDGE.cmd

ПОРЯДОК
1. Замените 3 Dart-файла.
2. Положите 3 скрипта в:
   C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka
3. Запустите:
   04_INSTALL_LOCAL_STOCKFISH_BRIDGE.cmd
4. Дождитесь:
   LOCAL_STOCKFISH_BRIDGE_OK
5. Затем обычная публикация сайта:
   .\PUBLISH_MAKECHESS.cmd
6. В Chrome откройте MakeChess.
7. Нажмите "Локальный Stockfish".
8. В первый раз Chrome/Windows может спросить разрешение открыть внешнее приложение.
9. Локальное окно должно открыться уже с FEN текущей позиции и само начать анализ.

ВАЖНО
- Старый сетевой _fetchUciBestMove НЕ удален: он еще нужен другим функциям сайта,
  включая игру компьютера. Мы меняем только действие кнопки в правой панели.
- Патчер локализации не заменяет большой localization-файл. Он делает резервную
  копию и добавляет только одну строку-понятие во все 11 языков.
- Протокол регистрируется только для текущего пользователя Windows (HKCU);
  права администратора не нужны.
