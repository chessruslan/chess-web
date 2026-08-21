MAKECHESS LOCAL STOCKFISH HTTP BRIDGE V2

WHY V2
------
Windows on this PC blocks creation of a custom URL protocol even when the
registration script is elevated. V2 does not touch the Registry at all.

HOW IT WORKS
------------
makechess.com
    |
    | button "Local Stockfish"
    v
http://127.0.0.1:17891/analyze?fen=...
    |
    v
local Flutter Windows module
    |
    v
local stockfish.exe

The local Windows module stays minimized in the background.
A shortcut is placed into the user's Startup folder, so it starts automatically
when the user logs into Windows.

Chrome 142+ may show a one-time "Local Network Access" permission prompt for
makechess.com. Allow it. The request stays on 127.0.0.1 (this computer).

FILES TO REPLACE
----------------
lib\main.dart
lib\stockfish_test_app.dart

FILES TO PUT IN PROJECT ROOT
----------------------------
PATCH_LOCAL_STOCKFISH_HTTP_LOCALIZATION.ps1
07_INSTALL_LOCAL_STOCKFISH_HTTP_BRIDGE.cmd
08_START_LOCAL_STOCKFISH_BRIDGE.cmd

RUN
---
1. 07_INSTALL_LOCAL_STOCKFISH_HTTP_BRIDGE.cmd
2. Wait for:
   LOCAL_STOCKFISH_HTTP_BRIDGE_OK
3. Run:
   .\PUBLISH_MAKECHESS.cmd
4. Open makechess.com
5. Press "Local Stockfish"
6. If Chrome asks for Local Network Access, choose Allow.

NO ADMIN RIGHTS ARE REQUIRED.
NO CUSTOM URL PROTOCOL IS REQUIRED.
