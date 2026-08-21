MAKECHESS — WINDOWS APP + WEB APP V1

FILES
-----
20_PREPARE_MAKECHESS_WINDOWS_AND_WEBAPP_V1.cmd
20_PREPARE_MAKECHESS_WINDOWS_AND_WEBAPP_V1.ps1

WHAT THIS DOES
--------------
1. Creates a timestamped backup of:
   pubspec.yaml
   web\manifest.json
   web\index.html
   windows\runner\main.cpp
   windows\runner\Runner.rc

2. Moves the already-working Local Stockfish bridge into an independent
   hidden runtime folder:
   _runtime\local_stockfish_bridge

   This is important because a normal Flutter Windows build uses the same
   build\windows\...\my_new_chess_app.exe path and would otherwise overwrite
   the Stockfish bridge.

3. Keeps Local Stockfish running invisibly with a hidden watchdog.

4. Prepares MakeChess branding for Windows and Web App/PWA.

5. Builds the real Windows application from:
   lib\main.dart

6. Creates:
   dist\MakeChess_Windows\MakeChess.exe

   and a MakeChess shortcut on the Windows Desktop.

7. Prepares the web PWA source, but DOES NOT publish the live website.

HOW TO RUN
----------
Extract both installer files into:
C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka

Run:
20_PREPARE_MAKECHESS_WINDOWS_AND_WEBAPP_V1.cmd

SUCCESS MARKER
--------------
MAKECHESS_WINDOWS_WEBAPP_V1_OK

After success:
- First open MakeChess from the new Desktop shortcut.
- Do NOT run PUBLISH_MAKECHESS.cmd yet.
- Send the result/screenshot to ChatGPT.

If Windows build fails:
- The five branding/PWA source files are restored automatically.
- The live website is unchanged.
- Local Stockfish remains on its independent background runtime.
