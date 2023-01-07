call variables.cmd
call encode-csv-strings.bat

rmdir "%modpath%\release" /s /q
mkdir "%modpath%\release"

mkdir "%modpath%\release\%modname%\content\scripts\"
rmdir "%modpath%\release\%modName%\content\" /s /q
XCOPY "%modpath%\src" "%modpath%\release\%modName%\content\scripts\" /e /s /y
XCOPY "%modpath%\strings" "%modpath%\release\%modName%\content\" /e /s /y

mkdir "%modpath%\release\%modName%\bin\config\r4game\user_config_matrix\pc\"
copy "%modpath%\mod-menu.xml" "%modpath%\release\%modName%\bin\config\r4game\user_config_matrix\pc\%modname%.xml" /y
