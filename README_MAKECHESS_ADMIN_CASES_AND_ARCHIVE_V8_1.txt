MAKECHESS ADMIN CASES + ARCHIVE V8.1

Why V8.1 exists
----------------
V8 stopped safely because it expected the older function
syncMakeChessMessagesFromDatabase().
The current Messages module already uses MakeChessMessageRealtimeService.syncFromDatabase()
and public.makechess_messages_v1. V8.1 is rebuilt for that current architecture.

What V8.1 changes
------------------
1. Adds the isolated admin_management_panel.dart module.
2. Adds Players / Schools / Teachers / Tournaments / Archive to Site Settings.
3. Adds mandatory explanatory message before warning/restriction/block.
4. Warning deadline is only a reminder. Deadline expiry never auto-blocks.
5. Adds user Reply and Fixed responses inside Messages.
6. Stores admin-case metadata in makechess_messages_v1.payload.
7. Adds 86 centralized phrases in all 11 site languages:
   RU EN DE FR ES AR ZH HI JA KO VI.

Safety
------
The installer checks exact current V6/V7 hashes before changing anything.
It makes exact backups and restores them on any error.

Run from the project root:
  .\INSTALL_MAKECHESS_ADMIN_CASES_AND_ARCHIVE_V8_1.cmd

After DONE only:
  .\PUBLISH_MAKECHESS.cmd
