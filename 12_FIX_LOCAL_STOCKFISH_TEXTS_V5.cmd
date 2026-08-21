@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ==========================================================
echo MAKECHESS - LOCAL STOCKFISH TEXT FIX V5
echo UTF-8 + 11 languages, engine logic unchanged
echo ==========================================================
echo Project: %CD%
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0PATCH_LOCAL_STOCKFISH_TEXTS_V5.ps1" -ProjectRoot "%CD%"
if errorlevel 1 goto :fail

echo.
echo ==========================================================
echo LOCAL_STOCKFISH_TEXT_FIX_V5_OK
echo ==========================================================
echo Now run PUBLISH_MAKECHESS.cmd and then Ctrl+F5 on the site.
echo.
pause
exit /b 0

:fail
echo.
echo ==========================================================
echo LOCAL_STOCKFISH_TEXT_FIX_V5_ERROR
echo ==========================================================
echo Do not publish. Send this window to ChatGPT.
echo.
pause
exit /b 1
