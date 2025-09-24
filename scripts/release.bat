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
call variables.cmd
call :createnomenurelease

tree %modpath%/release /F

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::::::::::::::::::::::::::::::::FUNCTIONS::::::::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
goto:eof

:createnomenurelease
  rmdir "%modpath%\release.no-menu" /s /q
  mkdir "%modpath%\release.no-menu"

  XCOPY "%modpath%\release\mods" "%modpath%\release.no-menu\mods\" /e /s /y

  del "%modpath%\release.no-menu\mods\modAutomaticDialogPicker\content\*.w3strings"
  del "%modpath%\release.no-menu\mods\modAutomaticDialogPicker\content\*.csv"
goto:eof
