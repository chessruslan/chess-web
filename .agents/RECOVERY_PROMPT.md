# Makechess — промпт восстановления после перезапуска

Скопируй весь текст ниже в новый чат Codex:

---

Продолжай работу над проектом Makechess из
`C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka`.

Сначала, до любых изменений, полностью прочитай:

1. `C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka\.agents\CONTEXT.md`
2. `C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka\.agents\RECOVERY_PROMPT.md`
3. актуальный `lib/classroom/classroom_call_service.dart`
4. `lib/classroom/classroom_signaling.dart`
5. `lib/classroom/classroom_overlay.dart`
6. участок `lib/main.dart` с `startSelectedStudentsVideo()` и
   `acceptVideoInvitation()`
7. рабочий обычный звонок:
   `lib/services/webrtc_service.dart`,
   `lib/features/call/voice_service.dart`,
   `lib/features/call/call_coordinator.dart`,
   `lib/features/call/video_overlay.dart`.

Не начинай поиск базы и сервера заново. Инфраструктура уже установлена:

- production: `https://makechess.com`;
- backend: self-hosted Supabase-compatible stack на Selectel, не Supabase Cloud;
- SSH: `flexyops@111.88.227.25`;
- приватный SSH-ключ уже находится в
  `C:\Users\BOBAH\.ssh\flexytube_selectel_ed25519`;
- пример безопасного подключения:
  `ssh -i C:\Users\BOBAH\.ssh\flexytube_selectel_ed25519 -o BatchMode=yes flexyops@111.88.227.25`;
- stack: `/opt/flexytube/supabase-stack`;
- production-файлы:
  `/opt/flexytube/supabase-stack/volumes/proxy/caddy/makechess`;
- PostgreSQL доступен внутри контейнера `supabase-db`; SELECT выполнять так:
  передавать SQL через stdin в
  `docker exec -i supabase-db psql -U postgres -d postgres -P pager=off`;
- TURN-контейнер: `makechess-turn`;
- TURN endpoint: `111.88.227.25:3478`, UDP/TCP;
- TURN username/credential уже объявлены в
  `lib/services/webrtc_service.dart`; прочитай их локально, не проси пользователя;
- API URL и anon key передаются через `SUPABASE_URL` и
  `SUPABASE_ANON_KEY`; декларации находятся в `lib/secrets.dart`;
- никогда не печатай в чат приватный SSH-ключ, JWT, пароли, anon/service-role
  key или TURN credential. Используй их только из существующих локальных
  файлов/переменных;
- важные таблицы:
  `public.classrooms`, `public.active_classrooms`,
  `public.classroom_signals`, `public.teacher_students`, `public.profiles`;
- главный полный журнал ПОСЛЕДНЕЙ рабочей сессии с продолжением работы над
  classroom-видео:
  `C:\Users\BOBAH\.codex\sessions\2026\07\23\rollout-2026-07-23T21-31-22-019f903f-0585-7cb3-ad95-563703a99c2c.jsonl`;
- журнал
  `C:\Users\BOBAH\.codex\sessions\2026\07\23\rollout-2026-07-23T09-46-52-019f8dba-04ca-7382-a7cc-9ea780b92e8b.jsonl`
  является предпоследним и не должен использоваться как текущая точка
  восстановления;
- если содержание `CONTEXT.md` кажется неполным, восстанови последовательность
  из главного журнала `...T21-31-22...jsonl`, не начинай расследование заново.

Текущая задача: в режиме «Учиться» учитель и ученик видят собственное видео,
но удалённая плитка чёрная. Нельзя считать старую папку classroom рабочим
образцом. Реально используемый путь импортирует
`lib/classroom/classroom_call_service.dart`.

Уже доказано SELECT-запросом по последнему classroom:

- offer и answer доставляются;
- SDP обеих сторон имеет video `a=sendrecv`, SSRC/MSID;
- ICE идёт в обе стороны, есть host/srflx/relay;
- чёрная плитка появляется после classroom `onTrack`, то есть объект
  удалённого video-track получен;
- неисправность остаётся в renderer/frame lifecycle либо в RTP после
  соединения.

В `lib/classroom/classroom_call_service.dart` уже сделана локальная,
НЕ ОПУБЛИКОВАННАЯ хирургическая правка:

- remote renderer инициализируется для известных peer до переговоров;
- плитка показывается только после реального video-track;
- поток назначается один раз;
- удалено обнуление и повторное назначение `srcObject` при `connected`;
- обычный звонок, контакты, lobby, приглашения, камера, база и схема не
  изменялись.

Последняя production-версия: `20260724_185844` (восстановлена откатом).
Публичный SHA-256 `main.dart.js`:
`5cb0106c2bb8af5927adce869aff2ddc6ddeebe49f1a051eea1a84011e15fa04`.
Она содержит актуальный classroom поверх того же `WebRTCService`, который
используется рабочим обычным звонком, и собрана с
`WEBRTC_USE_HTML_ELEMENT_VIEW=true`. Предыдущая production сохранена как
Повреждённые сборки сохранены как `makechess_failed_20260724_211227` и
`makechess_failed_20260724_215248`.

КРИТИЧЕСКИ ВАЖНО: при Flutter Web build передавать
`SUPABASE_URL=https://makechess.com` без `/auth/v1`. Нельзя использовать
серверный `API_EXTERNAL_URL` напрямую, если он содержит `/auth/v1`: клиент
Supabase сам добавляет `/auth/v1`, `/rest/v1` и `/realtime/v1`.

До перезапуска Flutter CLI зависал даже на `flutter --version`. После
перезапуска VS Code:

1. сначала проверь `flutter --version`;
2. затем запусти анализ изменённого classroom-файла;
3. выполни Web release build обязательно с
   `--dart-define=WEBRTC_USE_HTML_ELEMENT_VIEW=true`;
4. не публикуй, если сборка не завершилась успешно;
5. перед публикацией покажи/проверь, что функциональная правка ограничена
   `lib/classroom/classroom_call_service.dart`;
6. после публикации проверь HTTP 200 и совпадение SHA-256 локального,
   серверного и публичного `main.dart.js`;
7. не объявляй проблему решённой до реального теста учитель/ученик на двух
   компьютерах.

Если после этой одной renderer-правки удалённое видео останется чёрным, больше
не меняй поведение наугад. Добавь только classroom-диагностику `getStats()` и
получи для обеих сторон:

- connection/ICE state;
- выбранную candidate pair;
- inbound video `bytesReceived`, `packetsReceived`, `framesReceived`,
  `framesDecoded`;
- outbound video `bytesSent`, `packetsSent`, `framesEncoded`;
- состояние remote track (`enabled`, `muted`).

По результату:

- `bytesReceived == 0` — исправлять RTP/ICE transport;
- байты растут, но `framesDecoded == 0` — исправлять codec/decoder;
- decoded frames растут, но окно чёрное — исправлять только HTML renderer/view.

Работай хирургически. Не трогай контакты, lobby и обычную видеосвязь. Не
делай новую публикацию без успешной сборки и точного понимания diff. После
каждого существенного результата обновляй `.agents/CONTEXT.md`, чтобы контекст
никогда больше не потерялся.

---

## Почему секреты не продублированы здесь

Этот файл содержит точные места хранения и команды доступа, но не копии
секретов. Приватный ключ остаётся в защищённой папке `.ssh`, TURN credential —
в уже существующем исходнике, API-ключи — в существующих переменных сборки.
Так новый агент сразу найдёт подключения, а пересылка этого промпта не
раскроет ключи посторонним.
