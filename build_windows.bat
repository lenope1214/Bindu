@echo off
rem Bindu Windows build: double-click this file.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_windows.ps1" %*
if errorlevel 1 pause
