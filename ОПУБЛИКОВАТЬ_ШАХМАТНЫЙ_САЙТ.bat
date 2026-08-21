@echo off
chcp 65001 >nul
setlocal EnableExtensions
title Публикация шахматного сайта makechess.com

set "SERVER=root@111.88.227.25"
set "KEY=%USERPROFILE%\.ssh\makechess_selectel"
set "ARCHIVE=%TEMP%\makechess_web.tar.gz"

cd /d "%~dp0"

echo.
echo ============================================================
echo   ПУБЛИКАЦИЯ ШАХМАТНОГО САЙТА makechess.com
echo ============================================================
echo.

if not exist "pubspec.yaml" (
    echo ОШИБКА: этот файл нужно положить в главную папку шахматного проекта.
    echo В этой же папке должен находиться файл pubspec.yaml.
    echo.
    pause
    exit /b 1
)

where flutter >nul 2>&1
if errorlevel 1 (
    echo ОШИБКА: Windows не нашёл Flutter.
    echo Сначала проверь, что проект запускается обычной командой flutter run.
    echo.
    pause
    exit /b 1
)

where ssh >nul 2>&1
if errorlevel 1 (
    echo ОШИБКА: Windows не нашёл встроенное подключение к серверу.
    echo Ничего не устанавливай самостоятельно. Покажи этот экран ChatGPT.
    echo.
    pause
    exit /b 1
)

where scp >nul 2>&1
if errorlevel 1 (
    echo ОШИБКА: Windows не нашёл средство передачи файлов на сервер.
    echo Ничего не устанавливай самостоятельно. Покажи этот экран ChatGPT.
    echo.
    pause
    exit /b 1
)

where ssh-keygen >nul 2>&1
if errorlevel 1 (
    echo ОШИБКА: Windows не нашёл средство создания безопасного ключа.
    echo Ничего не устанавливай самостоятельно. Покажи этот экран ChatGPT.
    echo.
    pause
    exit /b 1
)

where tar >nul 2>&1
if errorlevel 1 (
    echo ОШИБКА: Windows не нашёл средство упаковки файлов.
    echo Ничего не устанавливай самостоятельно. Покажи этот экран ChatGPT.
    echo.
    pause
    exit /b 1
)

if not exist "%USERPROFILE%\.ssh" mkdir "%USERPROFILE%\.ssh"

if not exist "%KEY%" (
    echo Первый запуск: создаю безопасный ключ для публикации.
    ssh-keygen -t ed25519 -f "%KEY%" -N "" -C "makechess-selectel"
    if errorlevel 1 (
        echo.
        echo Не удалось создать ключ.
        pause
        exit /b 1
    )
)

if not exist "%KEY%.pub" (
    ssh-keygen -y -f "%KEY%" > "%KEY%.pub"
    if errorlevel 1 (
        echo.
        echo Не удалось подготовить ключ.
        pause
        exit /b 1
    )
)

ssh -i "%KEY%" -o BatchMode=yes -o ConnectTimeout=8 "%SERVER%" "exit" >nul 2>&1
if errorlevel 1 (
    echo.
    echo Сейчас сервер ОДИН РАЗ попросит новый пароль Selectel.
    echo Во время ввода пароля на экране не будут появляться буквы или звёздочки.
    echo Это нормально: вводи пароль и нажми Enter.
    echo.
    type "%KEY%.pub" | ssh -o StrictHostKeyChecking=accept-new "%SERVER%" "umask 077; mkdir -p /root/.ssh; cat >> /root/.ssh/authorized_keys; chmod 700 /root/.ssh; chmod 600 /root/.ssh/authorized_keys"
    if errorlevel 1 (
        echo.
        echo Не удалось связать компьютер с сервером.
        echo Проверь пароль Selectel и запусти этот файл ещё раз.
        echo.
        pause
        exit /b 1
    )
)

ssh -i "%KEY%" -o BatchMode=yes -o ConnectTimeout=8 "%SERVER%" "exit" >nul 2>&1
if errorlevel 1 (
    echo.
    echo Безопасное подключение не заработало.
    echo Покажи этот экран ChatGPT.
    echo.
    pause
    exit /b 1
)

echo [1 из 4] Собираю новую версию сайта...
call flutter build web
if errorlevel 1 (
    echo.
    echo Сборка сайта завершилась ошибкой. На сервер ничего не загружено.
    echo.
    pause
    exit /b 1
)

if not exist "build\web\index.html" (
    echo.
    echo ОШИБКА: после сборки не найден файл build\web\index.html.
    echo На сервер ничего не загружено.
    echo.
    pause
    exit /b 1
)

echo.
echo [2 из 4] Упаковываю готовый сайт в один временный файл...
if exist "%ARCHIVE%" del /q "%ARCHIVE%"
tar -czf "%ARCHIVE%" -C "build\web" .
if errorlevel 1 (
    echo.
    echo Не удалось упаковать сайт. На сервер ничего не загружено.
    echo.
    pause
    exit /b 1
)

echo.
echo [3 из 4] Передаю новую версию на сервер Selectel...
scp -i "%KEY%" -o BatchMode=yes "%ARCHIVE%" "%SERVER%:/tmp/makechess_web.tar.gz"
if errorlevel 1 (
    echo.
    echo Передача файлов не удалась. Работающий сайт не изменён.
    echo.
    pause
    exit /b 1
)

echo.
echo [4 из 4] Создаю резервную копию и включаю новую версию...
ssh -i "%KEY%" -o BatchMode=yes "%SERVER%" "set -eu; SITE=/opt/flexytube/supabase-stack/volumes/proxy/caddy/makechess; BASE=/opt/flexytube/supabase-stack/volumes/proxy/caddy; NEW=/opt/flexytube/supabase-stack/volumes/proxy/caddy/makechess_new; OLD=/opt/flexytube/supabase-stack/volumes/proxy/caddy/makechess_previous; BACKUPS=/opt/flexytube/backups; STAMP=$(date +%%Y%%m%%d_%%H%%M%%S); mkdir -p $BACKUPS; rm -rf $NEW $OLD; mkdir -p $NEW; tar -xzf /tmp/makechess_web.tar.gz -C $NEW; test -f $NEW/index.html; tar -czf $BACKUPS/makechess_$STAMP.tar.gz -C $BASE makechess; chown -R flexyops:flexyops $NEW; mv $SITE $OLD; mv $NEW $SITE; if command -v curl >/dev/null 2>&1; then sleep 2; if ! curl -kfsS --max-time 15 -H 'Host: makechess.com' https://127.0.0.1/ >/dev/null; then rm -rf $SITE; mv $OLD $SITE; exit 1; fi; fi; rm -rf $OLD /tmp/makechess_web.tar.gz; ls -1t $BACKUPS/makechess_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm -f"
if errorlevel 1 (
    echo.
    echo Новая версия не прошла проверку.
    echo Сервер автоматически вернул прежнюю рабочую версию.
    echo Покажи этот экран ChatGPT.
    echo.
    pause
    exit /b 1
)

if exist "%ARCHIVE%" del /q "%ARCHIVE%"

echo.
echo ============================================================
echo   ГОТОВО: ШАХМАТНЫЙ САЙТ ОПУБЛИКОВАН
echo ============================================================
echo.
echo Открываю makechess.com в браузере...
start "" "https://makechess.com"
echo.
echo Если браузер показывает старую версию, нажми Ctrl + F5.
echo.
pause
exit /b 0
