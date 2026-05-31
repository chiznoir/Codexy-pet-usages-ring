@echo off
setlocal
set "ROOT=%~dp0"
set "UNINSTALL_ARGS=%*"
if "%~1"=="" (
  echo This will stop Codexy pet usages ring and remove its startup/start menu shortcuts.
  echo Installed files are kept by default so settings and local state are not removed by accident.
  echo.
  choice /C YN /N /M "Also remove installed files from %LOCALAPPDATA%\CodexyPetUsagesRing? [y/N] "
  if errorlevel 2 (
    set "UNINSTALL_ARGS="
  ) else (
    set "UNINSTALL_ARGS=-RemoveFiles"
  )
)
cd /d "%TEMP%"
call "%ROOT%bin\cmd\uninstall.cmd" %UNINSTALL_ARGS%
set "EXITCODE=%ERRORLEVEL%"
echo.
if not "%EXITCODE%"=="0" (
  echo Uninstall failed with exit code %EXITCODE%.
  pause
) else (
  echo Uninstall completed. You can close this window.
  timeout /t 5 >nul
)
exit /b %EXITCODE%
