@echo off
rem Runs the self-tests. They use a fake ROM built in memory, so no real
rem ROM is needed.
set "GODOT=C:\Users\Neil\MarioProject\Godot\Godot_v4.6.1-stable_win64_console.exe"
if not exist "%GODOT%" set "GODOT=C:\Users\Neil\MarioProject\Godot\Godot_v4.6.1-stable_win64.exe"
rem Another PC: put the full path of its Godot .exe in a file called godot_path.txt
rem next to this file. That file is not synced, so each PC keeps its own.
if exist "%~dp0godot_path.txt" set /p GODOT=<"%~dp0godot_path.txt"
rem Godot's _console.exe shows the test output in this window; use it if it is there.
if exist "%GODOT:~0,-4%_console.exe" set "GODOT=%GODOT:~0,-4%_console.exe"
if not exist "%GODOT%" goto :nogodot
rem Always re-scan the project first, so Godot learns about scripts added by an update.
"%GODOT%" --headless --path "%~dp0." --import >nul 2>&1
"%GODOT%" --headless --path "%~dp0." res://Tests/RunTests.tscn
if errorlevel 1 goto :failed
echo.
echo RESULT: PASS
pause
exit /b 0
:failed
echo.
echo RESULT: FAIL - copy the text above and send it to Claude.
pause
exit /b 1
:nogodot
echo Could not find Godot. Put the full path of your Godot .exe in a file called godot_path.txt next to this file.
pause
exit /b 1
