enum EMCM_OptionalDialogFilterLevel {
  EMCM_None = 0,
  EMCM_Read = 1,
  EMCM_All = 2
}

function MCMConfig_getOptionalDialogFilterLevel(): EMCM_OptionalDialogFilterLevel {
  var cfgVal : int;
  cfgVal = StringToInt(theGame.GetInGameConfigWrapper().GetVarValue('MCMgeneral', 'VIRTUAL_MCMoptionalFilterLevel'));
  switch( cfgVal ) {
    case 0:
      return EMCM_None;
    case 1:
      return EMCM_Read;
    case 2:
      return EMCM_All;
  }
  return EMCM_None;
}

function MCMConfig_automateChoices(): bool {
  return (bool) theGame.GetInGameConfigWrapper().GetVarValue('MCMgeneral', 'MCMautomate');
}