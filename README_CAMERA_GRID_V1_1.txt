MAKECHESS — ELECTRONIC BOARD CAMERA + GRID V1.1

FIX
---
The previous V1 build failed because electronic_board_camera_web.dart used
PlatformViewHitTestBehavior without importing Flutter's rendering library.

V1.1 adds exactly this missing import:
package:flutter/rendering.dart show PlatformViewHitTestBehavior

The previous installer reported ROLLBACK_OK, so V1.1 is intended to be run
against the restored project state.

INSTALL
-------
Extract into:
C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka

Run:
24_INSTALL_ELECTRONIC_BOARD_CAMERA_GRID_V1_1.cmd

SUCCESS:
MAKECHESS_ELECTRONIC_BOARD_CAMERA_GRID_V1_1_OK

Nothing is published automatically.
