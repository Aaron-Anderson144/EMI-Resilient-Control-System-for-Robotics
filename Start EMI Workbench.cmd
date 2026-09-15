@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp012_Workbench\Start-Workbench.ps1"
if errorlevel 1 pause
