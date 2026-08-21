MAKECHESS — BIG LOCALIZATION STAGE V4

This stage was built from the exact 15-file ZIP collected from the user's
current project. The teacher-assignment module was inspected but is already
connected to the central localization system, so it is not overwritten.

V4 changes 14 files:
- central localization;
- app shell;
- common top bar;
- start modal;
- site settings;
- personal cabinet;
- board theme picker;
- tournament table editor;
- teacher tournament manager;
- puzzle types;
- learning panel;
- opening trainer;
- puzzle settings;
- room chat.

Localization coverage:
- 528 central Russian source phrases;
- translations for all 11 selector languages:
  RU EN DE FR ES AR ZH HI JA KO VI;
- static legacy Text labels;
- common buttons;
- tooltips;
- form labels / hints / helper text;
- reusable helper widgets in the large modules;
- fixed opening-trainer buttons and controls.

Important:
- user-created names, FEN/PGN, database content, chat content and opening catalog
  source data are intentionally not blindly translated.
- the opening trainer's existing V16/V8 logic and catalog conversion remain.
- V3.2 Messages + Student tournaments central localization is preserved.

Safety:
1. Exact SHA-256 is checked for every current target file BEFORE changes.
2. Exact package hashes are checked.
3. All 14 files are backed up.
4. dart format is run over every changed Dart file when Dart is available.
5. Only real pre-existing functional markers are checked.
6. Any actual installer error restores all 14 previous files.

Install:
  .\INSTALL_MAKECHESS_BIG_LOCALIZATION_STAGE_V4.cmd

After DONE:
  .\PUBLISH_MAKECHESS.cmd

If Flutter compilation succeeds but only network upload fails:
  .\PUBLISH_MAKECHESS_READY_BUILD_V1.cmd
