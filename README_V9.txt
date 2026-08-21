MAKECHESS TOURNAMENT OWNER JOIN V9

Why V9 exists:
- V8 assumed a fixed lib\ui\tournaments path that does not exist in your current project.
- V8 CMD also had a UTF-8 BOM, causing the initial garbage command before @echo off.

V9:
- searches recursively inside the real lib folder by filename + class signature;
- patches current files surgically instead of overwriting them with an old copy;
- creates a backup before writing;
- uses a BOM-free CMD;
- does not publish automatically.

Run 16_INSTALL_TOURNAMENT_OWNER_JOIN_V9.cmd from the project root.
