@echo off
rem ============================================================
rem  Volcano - first install (Windows)
rem
rem  THIS FILE MUST STAY PURE ASCII. Do not put Korean here.
rem  cmd.exe reads a .bat with the SYSTEM code page (CP949 on a
rem  Korean Windows), so any UTF-8 Korean byte becomes garbage and
rem  every line runs as a broken command. "chcp 65001" inside the
rem  file is too late - the file is already being read.
rem  All Korean text lives in the sibling UTF-8-BOM file setup.ps1.
rem
rem  THE FILE NAME MUST STAY PURE ASCII TOO. Measured 2026-09-05:
rem  when this file was named in Korean, Windows unzipped it with a
rem  mangled name while the sibling .ps1 kept its own - so "%~dpn0.ps1"
rem  pointed at a file that did not exist and setup stopped dead.
rem  We now look for the fixed name "setup.ps1" as well, just in case.
rem ============================================================
title Volcano setup
chcp 65001 >nul 2>nul

set "VOLCANO_PS1=%~dpn0.ps1"
if not exist "%VOLCANO_PS1%" set "VOLCANO_PS1=%~dp0setup.ps1"

if not exist "%VOLCANO_PS1%" (
  echo.
  echo   [X] Missing helper file: setup.ps1
  echo       Keep every file you received in the SAME folder and try again.
  echo.
  pause
  exit /b 1
)

echo Starting Volcano setup...

powershell -NoProfile -ExecutionPolicy Bypass -File "%VOLCANO_PS1%"
if errorlevel 1 goto failed
goto done

:failed
echo.
echo   [X] Setup did not finish.
echo       If PowerShell is missing or blocked, ask the sender for help.
echo.
pause
exit /b 1

:done
exit /b 0
