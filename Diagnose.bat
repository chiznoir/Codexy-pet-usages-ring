@echo off
setlocal
cd /d "%~dp0"
call "%~dp0bin\cmd\diagnose.cmd" %*
set "EXITCODE=%ERRORLEVEL%"
echo.
if not "%EXITCODE%"=="0" (
  echo Diagnose failed with exit code %EXITCODE%.
) else (
  echo Diagnose completed.
)
pause
exit /b %EXITCODE%
