MAKECHESS — REMAINING UI LOCALIZATION V6

V6 is built from the exact files collected after successful V5 publication.

What was found
--------------
The remaining Russian text was not mainly ordinary Text('...') anymore.
V5 had already converted those.

The leftovers were mostly a different class of problem:
1. helper widgets received a Russian label as a String variable and passed it
   directly to labelText/hintText/tooltip;
2. dynamic opening titles were assembled from several Russian pieces;
3. ternary tooltips were still raw strings;
4. composite labels joined several pieces with " • ".

That is why screens could be 90% Japanese/Arabic/etc. but still contain a few
Russian labels.

V6 fixes
--------
- Statistics fields: Участник / Проверяющий / Период.
- Generic labelText/hintText helpers in:
  main, personal cabinet, teacher access, tournament participant picker,
  tournament table editor, learning panel, puzzle settings, puzzle types.
- Opening chooser titles for White/Black:
  first moves / name / popularity / effectiveness.
- The same opening-choice buttons for both colors.
- Password show/hide tooltips.
- Tournament invitation/participation tooltips.
- Tournament suffix "мин." through localization.
- Bullet-separated composite UI labels now translate known UI fragments while
  leaving usernames, tournament names and other unknown data unchanged.

All 11 languages are preserved:
RU EN DE FR ES AR ZH HI JA KO VI.

Safety
------
- exact SHA-256 checks before any write;
- exact backup of all 12 files;
- package hash verification;
- dart format parser check;
- automatic rollback on installer error.

Install:
  .\INSTALL_MAKECHESS_REMAINING_UI_LOCALIZATION_V6.cmd

After DONE:
  .\PUBLISH_MAKECHESS.cmd
