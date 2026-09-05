@echo off
rem ============================================================
rem  Volcano - one-file installer for Windows
rem
rem  THIS ONE FILE IS ALL YOU NEED. Nothing else has to sit next
rem  to it. Everything is downloaded from the web at run time.
rem  (2026-09-06: the old version needed setup.ps1 and a 30MB zip
rem   in the same folder, and people pressed the wrong file.)
rem
rem  THIS FILE MUST STAY PURE ASCII - name and content both.
rem  cmd.exe reads a .bat with the SYSTEM code page (CP949 on a
rem  Korean Windows), so any UTF-8 Korean byte becomes garbage and
rem  every line runs as a broken command. All Korean text lives in
rem  setup-body.ps1, which is downloaded and read as UTF-8.
rem ============================================================
title Volcano setup
chcp 65001 >nul 2>nul
setlocal

set "BASE=https://beautifulahin.github.io/volcano-setup-temp"
set "BOOT=%TEMP%\volcano_boot.ps1"

set "PS=powershell"
if exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

echo.
echo   ============================================
echo     Volcano setup
echo   ============================================
echo     Getting the installer...   (10-20 min total)
echo.

if exist "%BOOT%" del /f /q "%BOOT%" >nul 2>nul

"%PS%" -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; try{[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}catch{}; Invoke-WebRequest -Uri ($env:BASE.TrimEnd('/')+'/setup-body.ps1') -OutFile $env:BOOT -UseBasicParsing -TimeoutSec 180"
if errorlevel 1 goto nonet
if not exist "%BOOT%" goto nonet

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%BOOT%"
if errorlevel 1 goto failed

rem The window must not vanish before the last message is read.
rem A .bat window closes the moment the batch ends, so hold it here.
echo.
pause
exit /b 0

:nonet
echo.
echo   [X] Could not download the installer.
echo       Check your internet connection and run this file again.
echo       Address: %BASE%/setup-body.ps1
echo.
pause
exit /b 1

:failed
echo.
echo   [X] Setup did not finish. Run this file again.
echo       If it keeps failing, send a screenshot of this window.
echo.
pause
exit /b 1
