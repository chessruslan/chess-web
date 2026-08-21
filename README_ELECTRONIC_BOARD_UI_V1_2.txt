MAKECHESS — ELECTRONIC BOARD UI V1.2

FIX OVER V1.1
-------------
The previous installer incorrectly treated Flutter/file_picker text written to STDERR
as a fatal PowerShell error before Flutter could finish and return its real exit code.

V1.2:
- keeps PowerShell strict error handling for the installer itself;
- temporarily allows native Flutter STDERR during the build;
- checks Flutter's real process exit code;
- uses the same SUPABASE_URL and SUPABASE_ANON_KEY already present in the user's
  approved PUBLISH_MAKECHESS.cmd;
- does NOT upload or publish anything.

INSTALL
-------
Extract the whole ZIP into:
C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka

Run:
22_INSTALL_ELECTRONIC_BOARD_UI_V1_2.cmd

SUCCESS:
MAKECHESS_ELECTRONIC_BOARD_UI_V1_2_OK

After success send the entire command-window output to ChatGPT.
Do NOT run PUBLISH_MAKECHESS.cmd yet.
