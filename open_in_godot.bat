@echo off
rem Opens this project in the Godot editor. Godot is only run from the Mario
rem folder; nothing in that folder is changed.
set "GODOT=C:\Users\Neil\MarioProject\Godot\Godot_v4.6.1-stable_win64.exe"
rem A copy of Godot inside this folder (Tools\Godot) is used if it is there.
if exist "%~dp0Tools\Godot\Godot_v4.6.1-stable_win64.exe" set "GODOT=%~dp0Tools\Godot\Godot_v4.6.1-stable_win64.exe"
rem Another PC: put the full path of its Godot .exe in a file called godot_path.txt
rem next to this file. That file is not synced, so each PC keeps its own.
if exist "%~dp0godot_path.txt" set /p GODOT=<"%~dp0godot_path.txt"
if not exist "%GODOT%" goto :nogodot
start "" "%GODOT%" --editor --path "%~dp0."
exit /b 0
:nogodot
echo Could not find Godot at:
echo   %GODOT%
echo Put the full path of your Godot .exe in a file called godot_path.txt next to this file.
pause
exit /b 1
