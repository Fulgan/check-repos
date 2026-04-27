@echo off
REM Double-click this file to run the sync checker.
REM
REM Before launching, this:
REM   1. Checks that git is installed (the tool needs it)
REM   2. Pulls the latest version of the script from its git repo
REM   3. Launches the script
REM
REM If any of those fail, it tells you why and stops. The tool can't
REM do its job without git and internet, so we don't pretend otherwise.
REM
REM First-time setup: if the script folder isn't a git clone yet,
REM the .cmd will clone it on first run.

setlocal

REM ---- Settings ----------------------------------------------------------
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_PATH=%SCRIPT_DIR%sync-check-gui.ps1"

REM Change this to YOUR repo URL.
set "REPO_URL=https://github.com/Fulgan/check-repos.git"
REM ------------------------------------------------------------------------

REM ---- 1. git installed? ----
where git >nul 2>nul
if errorlevel 1 (
    echo.
    echo  =====================================================
    echo   GIT IS NOT INSTALLED ON THIS COMPUTER
    echo  =====================================================
    echo.
    echo  This tool needs git to check your projects.
    echo.
    echo  Install Git for Windows from:
    echo    https://git-scm.com/download/win
    echo or by running "winget install git".
    echo.
    echo  Then run this again.
    echo.
    pause
    exit /b 1
)

REM ---- 2. first-time clone if needed ----
if not exist "%SCRIPT_PATH%" (
    echo First-time setup: downloading the script from GitHub...
    set "TEMP_CLONE=%TEMP%\sync-check-bootstrap-%RANDOM%"
    git clone --quiet "%REPO_URL%" "%TEMP_CLONE%"
    if errorlevel 1 (
        echo.
        echo  =====================================================
        echo   COULD NOT DOWNLOAD THE SCRIPT
        echo  =====================================================
        echo.
        echo  Tried to clone:
        echo    %REPO_URL%
        echo.
        echo  Check your internet connection and that the repo URL
        echo  is correct, then try again.
        echo.
        pause
        exit /b 1
    )
    xcopy /E /H /Y /Q "%TEMP_CLONE%\*" "%SCRIPT_DIR%" >nul
    rmdir /S /Q "%TEMP_CLONE%" >nul 2>nul
    goto :launch
)

REM ---- 3. update existing clone ----
if not exist "%SCRIPT_DIR%.git" (
    echo.
    echo  =====================================================
    echo   THIS FOLDER ISN'T A GIT CLONE
    echo  =====================================================
    echo.
    echo  The script is here, but the .git folder is missing,
    echo  so I can't auto-update it.
    echo.
    echo  Easiest fix: delete sync-check-gui.ps1 from this folder
    echo  and run this .cmd again - it will re-download a fresh
    echo  clone from GitHub.
    echo.
    pause
    exit /b 1
)

pushd "%SCRIPT_DIR%" >nul
git pull --ff-only --quiet
set "PULL_RESULT=%errorlevel%"
popd >nul

if not "%PULL_RESULT%"=="0" (
    echo.
    echo  =====================================================
    echo   COULDN'T REACH GITHUB
    echo  =====================================================
    echo.
    echo  Couldn't update the script from:
    echo    %REPO_URL%
    echo.
    echo  This usually means no internet, or GitHub is down.
    echo.
    echo  Try again when you're back online.
    echo.
    pause
    exit /b 1
)

:launch
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%SCRIPT_PATH%"
endlocal
