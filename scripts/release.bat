@echo off

call variables.cmd
call encode-csv-strings.bat
call uninstall.bat

rmdir "%modpath%\release" /s /q
mkdir "%modpath%\release"

mkdir "%modpath%\release\mods"
XCOPY "%modpath%\modAutomaticDialogPicker" "%modpath%\release\mods\modAutomaticDialogPicker\" /e /s /y
XCOPY "%modpath%\strings" "%modpath%\release\mods\modAutomaticDialogPicker\content\" /e /s /y

mkdir "%modpath%\release\%releaseName%\bin\config\r4game\user_config_matrix\pc\"
copy "%modpath%\mod-menu.xml" "%modpath%\release\bin\config\r4game\user_config_matrix\pc\%modname%.xml" /y

call compileblob
tree %modpath%/release /F