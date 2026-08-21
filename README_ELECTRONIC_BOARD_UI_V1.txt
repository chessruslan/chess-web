MAKECHESS — ELECTRONIC BOARD UI V1

WHAT IS ADDED
-------------
1. Settings -> "Электронная доска"
   The button is placed directly under "Турниры".

2. Initial calibration interface:
   - V: number of rows
   - S: number of columns
   - L: horizontal grid offset
   - R: vertical grid offset
   - black camera placeholder
   - movable calibration grid
   - technical grid addresses V1S1, V1S2, ...
   - click a grid cell and assign chess square A1-H8
   - the same mapping can be edited in the list below
   - empty grid cells are ignored

3. Tournament management -> "Цифровая доска"
   The button is placed directly under "Текущие турниры".
   The section is intentionally empty for now.

4. New text is translated into all 11 MakeChess interface languages.

SAFETY
------
- Creates a timestamped backup first.
- Does not change database/server data.
- Does not change Stockfish.
- Does not publish the website.
- Runs "flutter build web --release" only as a compile verification.
- If patching/build fails, restores the modified source files.

INSTALL
-------
Extract the whole ZIP into:
C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka

You must see:
PATCH_FILES
21_INSTALL_ELECTRONIC_BOARD_UI_V1.cmd
21_INSTALL_ELECTRONIC_BOARD_UI_V1.ps1

Run:
21_INSTALL_ELECTRONIC_BOARD_UI_V1.cmd

SUCCESS:
MAKECHESS_ELECTRONIC_BOARD_UI_V1_OK

After success, send the command-window output to ChatGPT.
Do NOT run PUBLISH_MAKECHESS.cmd yet.
