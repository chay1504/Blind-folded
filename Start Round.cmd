@echo off
powershell.exe -NoProfile -MTA -ExecutionPolicy Bypass -File "%~dp0Start-Round.ps1" %*
pause
