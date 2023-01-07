call variables.cmd
call encode-csv-strings.bat

rmdir "%modpath%\release" /s /q
mkdir "%modpath%\release"

mkdir "%modpath%\release\%releaseName%\%modname%\content\scripts\"
rmdir "%modpath%\release\%releaseName%\%modName%\content\" /s /q
XCOPY "%modpath%\src" "%modpath%\release\%releaseName%\%modName%\content\scripts\" /e /s /y
XCOPY "%modpath%\strings" "%modpath%\release\%releaseName%\%modName%\content\" /e /s /y

mkdir "%modpath%\release\%releaseName%\bin\config\r4game\user_config_matrix\pc\"
copy "%modpath%\mod-menu.xml" "%modpath%\release\%releaseName%\bin\config\r4game\user_config_matrix\pc\%modname%.xml" /y
