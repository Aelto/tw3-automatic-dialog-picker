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
function OnDialogOptionSelected(index: int) {
  return wrappedMethod(this.MCM_randomDialogPicker.toSimulatedIndex(index));
}

@wrapMethod(CR4HudModuleDialog)
function OnDialogOptionAccepted(index: int) {
  var acceptedChoice: SSceneChoice;

  acceptedChoice = this.lastSetChoices[index];

  if (!acceptedChoice.disabled) {
    index = this.MCM_randomDialogPicker.toSimulatedIndex(index);
  }

  return wrappedMethod(index);
}

@wrapMethod(CR4HudModuleDialog)
function OnDialogChoicesSet(choices: array<SSceneChoice>, alternativeUI: bool) {
  // copy the vanilla function but skip the RequestMouseCursor call
  if (this.MCM_choiceAutomated) {
    m_fxSetAlternativeDialogOptionView.InvokeSelfOneArg(FlashArgBool(alternativeUI));
		SendDialogChoicesToUI(choices, true);
		m_guiManager.RequestMouseCursor(false); // modAutomaticDialogPicker

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
  var automatedDialogResult: MCM_RandomDialogPickerResult;

  automatedDialogResult = this.MCM_randomDialogPicker.handleCurrentChoices(choices);
  this.MCM_choiceAutomated = automatedDialogResult.choice_automated;

  if (this.MCM_choiceAutomated) {
    automatedDialogResult.filtered_choices.Clear();
  }

  wrappedMethod(
    automatedDialogResult.filtered_choices,
    allowContentMissingDialog
  );

  if (choices.Size() > 0 && automatedDialogResult.choice_automated) {
    // manually call this as sending an empty array would cause the vanilla scripts
    // to skip it.
    SetGwentMode(false);
  }
}