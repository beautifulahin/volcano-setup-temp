@echo off
rem ============================================================
rem  Volcano - first install (Windows)
rem
rem  THIS FILE MUST STAY PURE ASCII. Do not put Korean here.
rem  cmd.exe reads a .bat with the SYSTEM code page (CP949 on a
rem  Korean Windows), so any UTF-8 Korean byte becomes garbage and
rem  every line runs as a broken command. "chcp 65001" inside the
rem  file is too late - the file is already being read.
rem  All Korean text lives in the sibling UTF-8-BOM file
rem  "%~dpn0.ps1" - same base name, .ps1 extension.
rem ============================================================
title Volcano setup
chcp 65001 >nul 2>nul

set "VOLCANO_PS1=%~dpn0.ps1"

if not exist "%VOLCANO_PS1%" (
  echo.
  echo   [X] Missing helper file: "%VOLCANO_PS1%"
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
