@echo off
REM uis.cmd - UIS wrapper for Windows Command Prompt
REM This calls the PowerShell script to handle all commands
REM
REM Usage: uis <command> [args]

powershell -ExecutionPolicy Bypass -File "%~dp0uis.ps1" %*
