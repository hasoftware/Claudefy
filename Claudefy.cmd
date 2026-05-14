@echo off
REM Claudefy - make Claude Code yours.
REM Double-click launcher. Requires PowerShell 7+ (pwsh).
REM
REM Author     : Hoang Anh Dev
REM Admin      : HASOFTWARE
REM Telegram   : https://t.me/hasoftware
REM Repository : https://github.com/hasoftware/Claudefy

where pwsh >nul 2>nul
if errorlevel 1 (
  echo [X] PowerShell 7+ ^(pwsh^) not found.
  echo     Install:  winget install Microsoft.PowerShell
  pause
  exit /b 1
)

pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Claudefy.ps1"
