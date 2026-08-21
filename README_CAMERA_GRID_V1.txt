MAKECHESS — ELECTRONIC BOARD CAMERA + GRID V1

ADDED
-----
1. Button "Камера" in:
   Настройка сайта -> Электронная доска

2. On click the web browser requests access to the webcam.
   After permission is granted, the live camera image appears inside
   the calibration monitor.

3. The calibration grid stays over the camera image.

4. Grid geometry is now fully explicit:
   V = number of rows
   S = number of columns
   Cell width = exact width in px
   Cell height = exact height in px
   L = horizontal position/offset in px
   R = vertical position/offset in px

5. Existing VxS -> chess-square mapping remains unchanged.

6. New labels are translated into all 11 MakeChess languages.

SAFETY
------
- Only the Electronic Board panel and localization are changed.
- Three new camera helper files are added.
- Database, Stockfish and tournament logic are not changed.
- A timestamped backup is created first.
- The site is NOT published.
- If build fails, the changed files are rolled back.

INSTALL
-------
Extract the ZIP into:
C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka

Run:
23_INSTALL_ELECTRONIC_BOARD_CAMERA_GRID_V1.cmd

SUCCESS:
MAKECHESS_ELECTRONIC_BOARD_CAMERA_GRID_V1_OK
