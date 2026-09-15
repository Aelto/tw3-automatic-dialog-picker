@addField(CR4HudModuleDialog)
var MCM_randomDialogPicker: MCM_RandomDialogPicker;

@addField(CR4HudModuleDialog)
var MCM_choiceAutomated: bool;

@wrapMethod(CR4HudModuleDialog)
function OnConfigUI() {
  var result: bool;
  
  result = wrappedMethod();

  this.MCM_randomDialogPicker = new MCM_RandomDialogPicker in this;
  this.MCM_randomDialogPicker.init(this);

  return result;
}

@wrapMethod(CR4HudModuleDialog)
function OnDialogChoicesSet(choices: array<SSceneChoice>, alternativeUI: bool) {
  // copy the vanilla function but pass a `false` to the RequestMouseCursor call
  if (this.MCM_choiceAutomated) {
    m_fxSetAlternativeDialogOptionView.InvokeSelfOneArg(FlashArgBool(alternativeUI));
		SendDialogChoicesToUI(choices, true);
		m_guiManager.RequestMouseCursor(false); // <-- the RequestMouseCursor call

		theGame.ForceUIAnalog(true);
  }
  else {
    wrappedMethod(choices, alternativeUI);
  }
}

@wrapMethod(CR4HudModuleDialog)
function SendDialogChoicesToUI(
  choices: array<SSceneChoice>,
  allowContentMissingDialog: bool
) {
  this.MCM_choiceAutomated = this.MCM_randomDialogPicker.getRandomChoiceToPick(choices);

  if (this.MCM_choiceAutomated) {
    // skip the whole vanilla logic, except the line of code below because
    // because that one matters
    if (choices.Size() > 0) {
      SetGwentMode(false);
    }
  }
  else {
    wrappedMethod(
      choices,
      allowContentMissingDialog
    );
  }
}