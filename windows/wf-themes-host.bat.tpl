@echo off
REM wf-themes — Firefox native messaging wrapper for Windows.
REM
REM Firefox (on Windows) spawns this .bat; the .bat in turn launches the
REM Linux native host inside WSL. wsl.exe -e preserves binary stdio so
REM Firefox's length-prefixed JSON wire format survives the boundary.
REM
REM __WSL_BIN_PATH__ is replaced by install.ps1 with the absolute WSL path
REM to wf-themes-host (typically /home/<user>/.local/bin/wf-themes-host).

wsl.exe -e __WSL_BIN_PATH__
