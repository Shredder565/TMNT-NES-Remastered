@echo off
rem Runs the game without opening the editor.
set "GODOT=C:\Users\Neil\MarioProject\Godot\Godot_v4.6.1-stable_win64.exe"
rem A copy of Godot inside this folder (Tools\Godot) is used if it is there.
if exist "%~dp0Tools\Godot\Godot_v4.6.1-stable_win64.exe" set "GODOT=%~dp0Tools\Godot\Godot_v4.6.1-stable_win64.exe"
rem Another PC: put the full path of its Godot .exe in a file called godot_path.txt
rem next to this file. That file is not synced, so each PC keeps its own.
if exist "%~dp0godot_path.txt" set /p GODOT=<"%~dp0godot_path.txt"
if not exist "%GODOT%" goto :nogodot
rem Always re-scan the project first, so Godot learns about scripts added by an update.
"%GODOT%" --headless --path "%~dp0." --import >nul 2>&1
start "" "%GODOT%" --path "%~dp0."
exit /b 0
:nogodot
echo Could not find Godot at:
echo   %GODOT%
echo Put the full path of your Godot .exe in a file called godot_path.txt next to this file.
pause
exit /b 1
