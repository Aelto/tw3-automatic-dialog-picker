@echo off

call variables.cmd
call release.bat

rem install scripts
XCOPY "%modPath%\release\mods\" "%gamePath%\mods\" /e /s /y
copy "%modPath%\mod-menu.xml" "%gamePath%\bin\config\r4game\user_config_matrix\pc\%modname%.xml" /y

