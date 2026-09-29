@echo off

call variables.cmd
call release.bat

:: install scripts
XCOPY "%modPath%\release\mods\" "%gamePath%\mods\" /e /s /y

