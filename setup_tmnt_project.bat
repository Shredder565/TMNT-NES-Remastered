@echo off
setlocal
title TMNT Remake setup
rem ---------------------------------------------------------------------
rem Sets a Windows PC up to run the TMNT Remake project.
rem
rem It does three things, and skips any that are already done:
rem   1. Installs Git (through winget) if this PC has none.
rem   2. Gets the project from GitHub, or updates it if it is already here.
rem   3. Downloads Godot 4.6.1 into the project's Tools folder and tells
rem      the project's own .bat files where it is.
rem
rem It cannot supply the game ROM. You give the game your own ROM the
rem first time it runs on each PC.
rem
rem Safe to run again at any time: it then just updates the project.
rem ---------------------------------------------------------------------

set "REPO_URL=https://github.com/Shredder565/TMNT-NES-Remastered.git"
set "REPO_ZIP=https://github.com/Shredder565/TMNT-NES-Remastered/archive/refs/heads/main.zip"
set "GODOT_URL=https://github.com/godotengine/godot/releases/download/4.6.1-stable/Godot_v4.6.1-stable_win64.exe.zip"
set "GODOT_EXE=Godot_v4.6.1-stable_win64.exe"

rem Where the project goes. If this file sits inside the project already,
rem use that folder; otherwise use a folder in your user folder.
set "HERE=%~dp0"
if "%HERE:~-1%"=="\" set "HERE=%HERE:~0,-1%"
set "PROJECT=%USERPROFILE%\TMNT-NES-Remastered"
if exist "%HERE%\project.godot" set "PROJECT=%HERE%"

echo.
echo TMNT Remake setup
echo Project folder: %PROJECT%
echo.

rem ---- 1. Git --------------------------------------------------------
set "GIT=git"
where git >nul 2>&1
if not errorlevel 1 goto :have_git
if exist "%ProgramFiles%\Git\cmd\git.exe" set "GIT=%ProgramFiles%\Git\cmd\git.exe"
if exist "%ProgramFiles%\Git\cmd\git.exe" goto :have_git

echo [1/3] Git is not installed. Installing it with winget...
where winget >nul 2>&1
if errorlevel 1 goto :no_git
winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
if exist "%ProgramFiles%\Git\cmd\git.exe" set "GIT=%ProgramFiles%\Git\cmd\git.exe"
if exist "%ProgramFiles%\Git\cmd\git.exe" goto :have_git

:no_git
echo       Git could not be installed automatically.
echo       The project will be downloaded as a plain copy instead. It will
echo       run, but this PC will not be able to sync changes until Git is
echo       installed from https://git-scm.com/download/win
set "GIT="
goto :get_project

:have_git
echo [1/3] Git is installed.

rem ---- 2. The project ------------------------------------------------
:get_project
if exist "%PROJECT%\.git" goto :update_project
if exist "%PROJECT%\project.godot" goto :project_ready
if not defined GIT goto :download_copy

echo [2/3] Getting the project from GitHub...
echo       If a sign-in window opens, sign in to GitHub.
"%GIT%" clone "%REPO_URL%" "%PROJECT%"
if errorlevel 1 goto :clone_failed
goto :project_ready

:update_project
if not defined GIT goto :project_ready
echo [2/3] The project is already here. Getting the latest version...
"%GIT%" -C "%PROJECT%" pull --ff-only
if errorlevel 1 echo       Could not update. The copy that is here will be used as it is.
goto :project_ready

:download_copy
echo [2/3] Downloading a copy of the project...
set "TMPZIP=%TEMP%\tmnt_remake_main.zip"
set "TMPDIR=%TEMP%\tmnt_remake_main"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; Invoke-WebRequest -Uri '%REPO_ZIP%' -OutFile '%TMPZIP%'; if (Test-Path '%TMPDIR%') { Remove-Item '%TMPDIR%' -Recurse -Force }; Expand-Archive -Path '%TMPZIP%' -DestinationPath '%TMPDIR%' -Force; $inner = Get-ChildItem '%TMPDIR%' -Directory | Select-Object -First 1; New-Item -ItemType Directory -Force -Path '%PROJECT%' | Out-Null; Copy-Item (Join-Path $inner.FullName '*') '%PROJECT%' -Recurse -Force"
if errorlevel 1 goto :clone_failed
if not exist "%PROJECT%\project.godot" goto :clone_failed
goto :project_ready

:clone_failed
echo.
echo The project could not be fetched from GitHub.
echo Check the internet connection, and that this PC is signed in to a
echo GitHub account that can see the repository, then run this file again.
goto :fail

:project_ready
if not exist "%PROJECT%\project.godot" goto :clone_failed
echo       Project is in place.

rem ---- 3. Godot ------------------------------------------------------
set "GODOT_DIR=%PROJECT%\Tools\Godot"
if exist "%GODOT_DIR%\%GODOT_EXE%" goto :have_godot

echo [3/3] Downloading Godot 4.6.1 (about 70 MB)...
if not exist "%GODOT_DIR%" mkdir "%GODOT_DIR%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; Invoke-WebRequest -Uri '%GODOT_URL%' -OutFile '%GODOT_DIR%\godot.zip'; Expand-Archive -Path '%GODOT_DIR%\godot.zip' -DestinationPath '%GODOT_DIR%' -Force; Remove-Item '%GODOT_DIR%\godot.zip'"
if errorlevel 1 goto :godot_failed
if not exist "%GODOT_DIR%\%GODOT_EXE%" goto :godot_failed
goto :write_path

:have_godot
echo [3/3] Godot 4.6.1 is already here.

:write_path
rem The project's own .bat files read this file to find Godot on this PC.
> "%PROJECT%\godot_path.txt" echo %GODOT_DIR%\%GODOT_EXE%

echo.
echo ---------------------------------------------------------------
echo Setup finished.
echo.
echo Project:  %PROJECT%
echo Godot:    %GODOT_DIR%\%GODOT_EXE%
echo.
echo Next, in the project folder:
echo   1. Double-click play.bat and give the game your ROM when it asks.
echo      This is needed once on each PC; the ROM is never synced.
echo   2. Double-click run_tests.bat. It should end with RESULT: PASS.
echo.
echo To get the latest version later, run this file again.
echo ---------------------------------------------------------------
echo.
choice /c YN /n /m "Open the project folder now? [Y/N] "
if errorlevel 2 goto :done
start "" "%PROJECT%"
:done
endlocal
exit /b 0

:godot_failed
echo.
echo Godot could not be downloaded. Check the internet connection and run
echo this file again. Everything already done will be kept.
goto :fail

:fail
echo.
pause
endlocal
exit /b 1
