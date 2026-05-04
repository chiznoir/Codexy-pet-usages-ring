@echo off
setlocal
set "ROOT=%~dp0..\.."
set "SCRIPT_NAME=Diagnose.ps1"
call "%~dp0resolve-root.cmd"
set "SCRIPT=%ROOT%\bin\powershell\%SCRIPT_NAME%"
call "%~dp0run-powershell.cmd" %*
exit /b %ERRORLEVEL%
