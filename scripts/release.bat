@echo off

call variables.cmd
:: call encode-csv-strings.bat
call uninstall.bat

rmdir "%modpath%\release" /s /q
mkdir "%modpath%\release"

mkdir "%modpath%\release\mods"
XCOPY "%modpath%\mod_automatic_dialog_picker" "%modpath%\release\mods\mod_automatic_dialog_picker\" /e /s /y

call compileblob

tree %modpath%/release /F

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::::::::::::::::::::::::::::::::FUNCTIONS::::::::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
goto:eof

