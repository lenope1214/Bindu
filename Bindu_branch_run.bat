@echo off
rem Bindu branch launcher (Windows): opens a window to pick a GitHub branch and run it.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Bindu_branch_run.ps1"
if errorlevel 1 pause
