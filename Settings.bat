@echo off
setlocal
cd /d "%~dp0"
echo Opening Codexy pet usages ring settings.
echo Keep this window open while editing; it closes after the settings page is idle.
echo.
call "%~dp0bin\cmd\settings.cmd" %*
set "EXITCODE=%ERRORLEVEL%"
echo.
if not "%EXITCODE%"=="0" (
  echo Settings failed with exit code %EXITCODE%.
  pause
)
exit /b %EXITCODE%
