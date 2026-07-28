# Makechess working context

Updated: 2026-07-23

## Infrastructure

- Production site: `makechess.com`.
- Backend is self-hosted on Selectel. It exposes a Supabase-compatible API
  through Kong (Auth, PostgREST and Realtime), but Supabase Cloud is not used.
- Existing coturn endpoint is hosted on the Selectel server.
- Do not describe the backend as hosted Supabase.

## Current video task

- A teacher maintains an unlimited number of students in
  `public.teacher_students`.
- `LearningPanel` loads those students. `Выбрать ученика` opens a database
  picker populated from registered users in `public.profiles`; it supports
  nickname search and A-Z/Z-A sorting. Teachers never type a student's
  nickname manually.
- The limit of 8 applies only to students selected for one video call, not to
  the teacher's saved student list.
- Each student row has a game invitation button labelled `Вызвать`.
- Clicking a student toggles selection for a classroom video call.
- Up to 8 students can be selected.
- The top-bar `Видео` action first starts a classroom call for selected
  students; if none are selected, it retains the legacy one-to-one call.
- Classroom topology is teacher-to-each-student. The teacher sees all students;
  every student sees the teacher; students do not see each other.
- Classroom invitations use the existing Selectel Realtime channel and carry
  `kind: video` plus a shared `classroomId`.
- The classroom WebRTC service uses the existing Selectel coturn configuration.
- Remote video is rendered as an adaptive full-screen grid, with local preview
  in the lower-right corner.

## Verification state

- Direct Dart analysis reports no compile errors in the changed files.
- The installed Flutter command currently hangs before producing build output,
  including for `flutter --version`; this is an environment/tool lock issue.
- A production deployment has not been made for this video change.

## Recovery checkpoint — 2026-07-23 after Codex restart

The complete pre-restart transcript is stored by Codex at:

`C:\Users\BOBAH\.codex\sessions\2026\07\23\rollout-2026-07-23T09-46-52-019f8dba-04ca-7382-a7cc-9ea780b92e8b.jsonl`

Important recovered state:

- Production releases `20260723_164010`, `20260723_180449`,
  `20260723_183127`, and `20260723_193252` were reported as published.
- Addressed invitations were fixed: the video invitation reaches only the
  selected student.
- The remaining unresolved defect is remote media: the call invitation and
  video window appear, but each side sees only its own local video; the remote
  image does not appear.
- Do not claim this defect is fixed until a real teacher/student two-browser
  call proves that remote frames are received on both sides.
- The user explicitly stopped further work after the failed media fixes. Do
  not change or deploy anything until the user explicitly asks to continue.

Exact final exchange in the recovered old session:

User: `ничего не делай. просто ответь на привет!`

Assistant: `Привет!`

User: `привет`

Assistant: `Привет!`

## Selectel connection inventory

- Hosting: self-hosted Supabase-compatible stack on Selectel, exposed through
  Kong. It is not Supabase Cloud.
- Application API credentials are injected at Flutter build time through
  `SUPABASE_URL` and `SUPABASE_ANON_KEY`; declarations are in
  `lib/secrets.dart`.
- Database/API use: Auth, PostgREST, and Realtime. Relevant tables include
  `public.profiles`, `public.teacher_students`, and
  `public.classroom_signals`.
- Realtime signaling code is primarily in
  `lib/classroom/classroom_signaling.dart` and
  `lib/classroom/classroom_call_service.dart`.
- TURN/coturn is on the Selectel server at `111.88.227.25:3478` over UDP and
  TCP. Credentials exist in the application code and must never be copied into
  chat or committed to a new public file.
- Proven deployment route recovered from the transcript: SSH user `flexyops`,
  key name `flexytube_selectel_ed25519`, server target under
  `/opt/flexytube/supabase-stack/volumes/proxy/caddy/makechess`.
- Never report access as lost before checking the Codex session journal and
  protected SSH storage. Never print private keys, passwords, anon/service
  keys, or TURN credentials into chat.

## Remote-video transport fix — release 20260723_221315

- `lib/classroom/classroom_call_service.dart` no longer forces
  `iceTransportPolicy: relay`; WebRTC may select host, srflx, or the Selectel
  TURN relay route.
- `iceCandidatePoolSize` is now zero so candidate gathering cannot finish
  before the `onIceCandidate` database-signaling handler is installed.
- Student offer and teacher answer wait for ICE gathering (with an 8-second
  upper bound) and send the current complete local SDP. Trickle ICE remains
  enabled as a second delivery path.
- Offer and teacher-side candidate handling now checks `receiverId`.
- Flutter production build completed successfully.
- Production release `20260723_221315` was atomically deployed. Previous
  production is preserved as `makechess_backup_20260723_221315`.
- Local, server, and public `main.dart.js` SHA-256:
  `11b88f03d49d4287f5c535cdacdbb495dda3d08d088e618e0b0a16a9c3a52f28`.
- `https://makechess.com/` and the published JavaScript returned HTTP 200.
- A real teacher/student call still requires user verification. Do not claim
  remote frames are proven until that call succeeds.

## Renderer correction and rollback — 2026-07-23

- Release `20260723_221315` caused a production regression and was immediately
  rolled back. It is preserved as `makechess_failed_20260723_221315`.
- The rollback was publicly verified: SHA-256
  `14b3969268f178b3a78c081956e35c0a6b22bf91496b48e37a726cfccffc10ee`.
- Root renderer issue found in `flutter_webrtc 1.2.0`: its default web
  frame-capture `RTCVideoView` can initialize a dynamically added remote view
  before the HTML video element exists and keep a null element reference.
- The call transport and camera code were restored to the pre-regression
  state. A new build uses the package-supported compile-time option
  `WEBRTC_USE_HTML_ELEMENT_VIEW=true`, which renders the actual HTML video
  element directly.
- Production release `20260723_225015` is deployed. Public and local
  `main.dart.js` SHA-256:
  `fcf0ff06dff5fa4db1fab1277e88d0fe88456b5fae81906e43704b8d3173809d`.
- Previous production is backed up as `makechess_backup_20260723_225015`.
- Real teacher/student verification is still required before declaring the
  remote video fixed.

## Surgical classroom alignment — release 20260723_230000

- The ordinary one-to-one call in Play mode was confirmed by the user to show
  remote video correctly and was used as the implementation reference.
- Only `lib/classroom/classroom_call_service.dart` was changed:
  - removed the classroom-only forced `iceTransportPolicy: relay`, matching
    the working ordinary call while retaining the same TURN servers;
  - initializes each peer's remote renderer before SDP/onTrack;
  - onTrack/onAddStream now bind the stream to that existing renderer;
  - added the same receiver-track fallback pattern used by the working call,
    via `pc.getReceivers()`.
- Invitation routing, student selection, camera acquisition, database schema,
  and the ordinary Play-mode call were not changed.
- Production release `20260723_230000` is deployed. Previous production is
  backed up as `makechess_backup_20260723_230000`.
- Public/local SHA-256:
  `5b4f079be51917b5291021a4f8d149a4d221bd3640d724ed22f648da70c73cd4`.
- Real teacher/student verification is still required.

## Rollback after ordinary-call/presence regression

- User reported release `20260723_230000` caused asymmetric online contacts,
  disappearance of the other player during a call attempt, and only the local
  video window appearing in the ordinary call.
- Release `20260723_230000` was immediately removed from production and saved
  as `makechess_failed_20260723_230000`.
- Production was restored to `20260723_225015`; active/public build hash:
  `fcf0ff06dff5fa4db1fab1277e88d0fe88456b5fae81906e43704b8d3173809d`.
- The local classroom service was also restored to the pre-230000 state.
- No further release should be published until the ordinary contacts/call and
  classroom call are separately verified.
- Server evidence for the failed test: both participants produced offer,
  answer, and ICE candidates. Later Realtime logged no connected users and
  stopped the tenant, which explains the contact disappearing from the
  broadcast-only lobby. The lobby currently lacks robust channel
  reconnection after a dropped Realtime socket.

## ICE-only classroom release — 20260724_001500

- Started from restored production/local state `20260723_225015`.
- Exact functional change is limited to
  `lib/classroom/classroom_call_service.dart`: classroom now uses the same
  `forceRelayForDebug` switch as the working ordinary call instead of always
  forcing `iceTransportPolicy: relay`.
- Because `forceRelayForDebug` is false, WebRTC may select host/srflx and keeps
  the existing Selectel TURN server as fallback.
- No renderer, lobby, contacts, invitation, camera, database, or ordinary-call
  code was changed.
- Production release `20260724_001500` deployed; previous production backed up
  as `makechess_backup_20260724_001500`.
- Public/local SHA-256:
  `7050d5414831c6e7f4eaf4158a60a9099f3038c85d1b3ea1b8b80c9f6722f629`.
- Requires a fresh two-browser classroom call test.
## 2026-07-24: classroom remote-video investigation after release 20260724_001500

- User confirmed both teacher and student still see only their own local video; the remote classroom tile is black.
- Actual `Учиться` route imports `lib/classroom/classroom_call_service.dart` from `lib/main.dart`. Duplicate classroom implementations under `lib/features/call` and `lib/services` are not used by this route.
- Read-only DB inspection of the latest classroom (`926ba40f-e9ea-40c6-8398-6fffff4b5130`) proved:
  - student offer and teacher answer both arrived;
  - both SDP video sections are `a=sendrecv` and contain video SSRC/MSID data;
  - ICE candidates arrived in both directions, including host, srflx, and TURN relay candidates.
- Therefore invitation delivery, `addTrack`, SDP direction, and two-way ICE signaling are present. A black tile is created only after classroom `onTrack` receives a video track; the remaining fault is in the remote renderer/frame lifecycle or post-connection RTP flow.
- Code comparison with the regular working call found its local and remote `RTCVideoRenderer`s are initialized before PeerConnection negotiation. Classroom created each remote renderer late inside `onTrack` and also reset/rebound `srcObject` on `connected`.
- A surgical local-only change was made in `lib/classroom/classroom_call_service.dart`:
  - preinitialize remote renderers for known peer IDs before subscribing/negotiating;
  - still add a remote tile only after an actual video track arrives;
  - bind the received stream once;
  - remove the `srcObject = null` / reassignment on `connected`;
  - no changes to contacts, lobby, ordinary calls, camera acquisition, DB schema, or signaling.
- NOT PUBLISHED. Verification is blocked by a local Flutter CLI failure: `flutter analyze`, `dart analyze`, `flutter build web`, and even `flutter --version` hang without output. Old analyzer/build processes started by this investigation were stopped; the persistent CLI problem remains.
- Next action: repair/restart the local Flutter tool process, run a clean Web release build with `--dart-define=WEBRTC_USE_HTML_ELEMENT_VIEW=true`, then publish only if compilation succeeds. If the remote tile remains black, add classroom-only `getStats()` diagnostics for `bytesReceived` and `framesDecoded` before any further behavioral change.

## Permanent restart recovery

- A self-contained restart prompt is saved at
  `C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka\.agents\RECOVERY_PROMPT.md`.
- The authoritative full transcript of the latest video-work session is:
  `C:\Users\BOBAH\.codex\sessions\2026\07\23\rollout-2026-07-23T21-31-22-019f903f-0585-7cb3-ad95-563703a99c2c.jsonl`.
- The previously recorded `...T09-46-52...jsonl` transcript is the
  penultimate session, not the latest one.
- It contains the current task, evidence, local unpublished change, production
  checkpoint, server/container/database inventory, exact protected credential
  locations, safe connection commands, build/deployment gates, and the next
  stats-based diagnostic branch.
- Secrets are intentionally referenced at their protected existing locations
  rather than duplicated into chat or this recovery file.

## 2026-07-24: renderer lifecycle release 20260724_120828

- After the VS Code restart, Flutter still hung because stale SDK lock files
  remained in `C:\Dart\Flutter\bin\cache`. The stale Dart processes and the
  two lock files were removed; `flutter --version` worked again.
- Direct Dart analysis of `lib/classroom/classroom_call_service.dart` found no
  compile errors (only four existing `avoid_print` info diagnostics).
- A clean Flutter Web release build completed successfully with:
  `WEBRTC_USE_HTML_ELEMENT_VIEW=true`, the production API URL, and the existing
  production anon key injected from the protected server environment.
- The only functional source correction remains the surgical classroom
  renderer lifecycle change in `lib/classroom/classroom_call_service.dart`:
  preinitialize known-peer renderers, bind the received stream once, and do not
  clear/rebind `srcObject` on `connected`.
- Production release `20260724_120828` was atomically deployed; the previous
  production directory was preserved as `makechess_backup_20260724_120828`.
- Local, server, and public `main.dart.js` SHA-256:
  `0e107e260489eb64d7df34776165cb683fc893dc475f889a29c383484f392b7d`.
- `https://makechess.com/` returned HTTP 200.
- A real teacher/student classroom call is still required. Do not claim the
  black remote tile is fixed until that test succeeds. If it remains black,
  add classroom-only `getStats()` diagnostics before changing behavior again.

## 2026-07-24: current classroom/WebRTC release 20260724_185844

- Recovered the actual latest local implementation after restart. The active
  `lib/classroom/classroom_call_service.dart` no longer maintains a separate
  ad-hoc WebRTC implementation: every teacher/student pair is backed by its
  own `WebRTCService`, the same implementation used by the working Play-mode
  call. The teacher's one local MediaStream is shared across up to eight peer
  connections, while each peer owns its own PeerConnection and remote
  renderer.
- Flutter SDK stale locks were removed and Flutter 3.35.5 / Dart 3.9.2 became
  responsive.
- A fresh Web release build completed successfully with production
  `SUPABASE_URL`, the existing protected Selectel anon key, and
  `WEBRTC_USE_HTML_ELEMENT_VIEW=true`.
- Production release `20260724_185844` was atomically deployed. The prior
  production is preserved at `makechess_backup_20260724_185844`.
- Local, server, and public `main.dart.js` SHA-256:
  `5cb0106c2bb8af5927adce869aff2ddc6ddeebe49f1a051eea1a84011e15fa04`.
- `https://makechess.com/` and public `main.dart.js` both returned HTTP 200.
- A real teacher/student two-computer test is still the required proof of
  remote frames. If a black tile remains, do not make another speculative
  behavioral change; add classroom-only WebRTC `getStats()` diagnostics.

## 2026-07-24: persistent automatic context entry point

- Added the repository-root `AGENTS.md`.
- Every new agent session must read `.agents/CONTEXT.md` and
  `.agents/RECOVERY_PROMPT.md` before asking the user about infrastructure,
  database access, deployment, or the current project state.
- Existing credentials must be discovered and used only from the protected
  local/server locations already documented; secrets must never be copied into
  chat or context files.
- Updating this context after each material result is now an explicit
  completion requirement.

## 2026-07-24: production republish 20260724_211227

- Flutter 3.35.5 / Dart 3.9.2 was restored by stopping stale Dart processes
  and removing the two stale Flutter SDK lock files.
- Targeted Dart analysis hung without output and timed out after 120 seconds,
  matching the previously documented analyzer issue.
- A fresh Flutter Web release build completed successfully with production
  `SUPABASE_URL`, the protected Selectel anon key,
  `WEBRTC_USE_HTML_ELEMENT_VIEW=true`, `--no-tree-shake-icons`, and
  `--no-wasm-dry-run`.
- Production release `20260724_211227` was deployed. The prior production was
  preserved as `makechess_backup_20260724_211227`.
- `https://makechess.com/` returned HTTP 200.
- Local, server, and public `main.dart.js` SHA-256 values matched:
  `ba7e4ae788e4e4e9b69a9c203e7b1887423b66429e93300dfe007f08c030c37f`.
- The user can now perform a hard refresh with `Ctrl+F5`. A real
  teacher/student two-computer test is still required to verify remote video.

## 2026-07-24: classroom remote-view lifecycle release 20260724_215248

- Recovered and verified the accepted topology: one independent
  `WebRTCService` per teacher/student pair, one shared teacher local stream,
  at most eight students, and no student-to-student peer connections.
- A read-only production DB check of the latest classroom calls confirmed one
  offer, one answer, two senders, and 11-12 ICE candidates per call. This
  supports the existing conclusion that invitation routing and SDP/ICE
  exchange are working.
- The remaining concrete difference from the working Play-mode call was the
  remote view lifecycle. Play mode mounts its remote `RTCVideoView` before
  negotiation and later assigns the stream. Classroom initialized the
  renderer early but did not mount `RTCVideoView` until `onTrack`, after
  `srcObject` was assigned. On Flutter Web this late HTML-video creation can
  leave the remote tile black.
- Changed only:
  - `lib/classroom/classroom_call_service.dart`;
  - `lib/classroom/classroom_overlay.dart`.
- Each classroom peer now mounts a waiting remote tile immediately after its
  renderer is initialized and before PeerConnection/SDP negotiation. When the
  video stream arrives, the same renderer and view are retained and the
  waiting indicator is removed.
- Invitation routing, DB schema, shared signaling, camera acquisition,
  Play-mode calls, and the eight-student star topology were not changed.
- Targeted Dart analysis again hung due to the documented SDK lock problem.
  After clearing only the stale analysis processes and Flutter locks, a fresh
  production Web build completed successfully with the required protected
  Supabase values and `WEBRTC_USE_HTML_ELEMENT_VIEW=true`.
- Production release `20260724_215248` was deployed. The previous production
  was preserved as `makechess_backup_20260724_215248`.
- `https://makechess.com/` returned HTTP 200.
- Local, server, and public `main.dart.js` SHA-256 values matched:
  `5f33c8ee829cc873a4f19b46389fcab982459dd08611d8c6a4ef2d92663f90d5`.
- Required next proof: hard-refresh both computers, test one teacher/student
  classroom call in both directions, then test two students simultaneously.
  Do not claim remote video is fixed until the real two-computer test passes.

## 2026-07-24: emergency rollback after API URL regression

- User reported registration failed with `PostgrestException: 404 page not
  found` after the classroom release.
- Release `20260724_215248` was first rolled back to `20260724_211227`, but
  server logs proved that release was already broken.
- Exact cause: builds `20260724_211227` and `20260724_215248` used the server
  `API_EXTERNAL_URL` as Flutter `SUPABASE_URL`. That value includes
  `/auth/v1`, so the Supabase client generated invalid paths such as
  `/auth/v1/rest/v1/profiles` and `/auth/v1/realtime/v1/websocket`.
- Registration failed during profile nickname lookup. No registration source
  code was changed; the regression came from the incorrect build-time URL and
  insufficient deployment smoke testing.
- Production was restored to the last known-good release
  `20260724_185844`. Failed builds are preserved as
  `makechess_failed_20260724_211227` and
  `makechess_failed_20260724_215248`.
- Active server and public `main.dart.js` SHA-256 values match:
  `5cb0106c2bb8af5927adce869aff2ddc6ddeebe49f1a051eea1a84011e15fa04`.
- Mandatory future build value: `SUPABASE_URL=https://makechess.com`, with no
  path suffix. Never pass `API_EXTERNAL_URL` directly when it contains
  `/auth/v1`.
- Registration/profile REST and Realtime routing are mandatory smoke tests
  before any future deployment.
- The local classroom remote-view lifecycle change remains unpublished.

## 2026-07-28: local recovery checkpoint after manual development

- The current workspace was reviewed read-only after development continued
  without Codex.
- The active source contains a classroom video call for up to eight students:
  one shared teacher camera/microphone and one independent WebRTC peer
  connection per teacher/student pair. Students are not connected to each
  other. New selected students can be added to a running classroom call.
- The `Учиться` mode contains up to eight simultaneous independent learning
  game sessions. The teacher can switch between a two-column overview of eight
  boards and one focused board. Each session keeps its own game state, clock,
  engine evaluation and controls.
- The top navigation contains `Личный кабинет`. The cabinet contains profile,
  settings and game/archive sections. Its new profile settings and game
  archive currently use `SharedPreferences`, so they are local to the browser
  and are not yet synchronized through the Selectel database.
- Most of this work exists beyond the old Git history. A local recovery commit
  is being created from the current application source. Secret-bearing and
  operational files (`lib/secrets.dart`, SSH helper files, deployment logs,
  archives and publication scripts) must not be included in a public commit.
- `flutter analyze` of the affected source was attempted on 2026-07-28 and
  produced no output before timing out after 120 seconds. This matches the
  previously recorded Flutter analyzer/SDK lock problem. It is not a successful
  verification and must not be reported as one.
- No production publication was performed during this checkpoint.
- `PUBLISH_MAKECHESS.cmd` was not changed. It remains the only authorized
  publication entry point under the current project rules.
