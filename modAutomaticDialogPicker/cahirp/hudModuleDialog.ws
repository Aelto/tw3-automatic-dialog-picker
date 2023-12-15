@context(
  file(game/gui/hud/modules/hudModuleDialog.ws)
  at(class CR4HudModuleDialog)
)

@insert(
  note("delcare the variables holding the RandomDialogPicker properties")
  above(event  OnConfigUI)
)
// modAutomaticDialogPicker - BEGIN
private var MCM_randomDialogPicker: MCM_RandomDialogPicker;
private var MCM_choiceAutomated: bool;
  default MCM_choiceAutomated = false;
// modAutomaticDialogPicker - END

@insert(
  note("initialize the mod on boot")
  at(event  OnConfigUI)
  above(super.OnConfigUI())
)
// modAutomaticDialogPicker - BEGIN
MCM_randomDialogPicker = new MCM_RandomDialogPicker in this;
MCM_randomDialogPicker.init(this);
// modAutomaticDialogPicker - END

@insert(
  at(event  OnDialogOptionSelected)
  select(system.SendSignal( SSST_Highlight, index );)
)
system.SendSignal( SSST_Highlight, MCM_randomDialogPicker.toSimulatedIndex(index) );  // modAutomaticDialogPicker

@insert(
  at(event  OnDialogOptionAccepted)
  at(if (!acceptedChoice.disabled))
  select(system.SendSignal( SSST_Accept, index );)
)
system.SendSignal( SSST_Accept, MCM_randomDialogPicker.toSimulatedIndex(index) );  // modAutomaticDialogPicker

@insert(
  at(function OnDialogChoicesSet)
  select(m_guiManager.RequestMouseCursor(true);)
)
m_guiManager.RequestMouseCursor(!MCM_choiceAutomated); // modAutomaticDialogPicker

@insert(
  at(function SendDialogChoicesToUI)
  below(var progress)
)
var automatedDialogResult	: MCM_RandomDialogPickerResult; //modAutomaticDialogPicker

@insert(
  at(function SendDialogChoicesToUI)
  at(choiceFlashArray = flashValueStorage.CreateTempFlashArray())
)
// modAutomaticDialogPicker - BEGIN
automatedDialogResult = this.MCM_randomDialogPicker.handleCurrentChoices(choices);
MCM_choiceAutomated = automatedDialogResult.choice_automated;
lastSetChoices = automatedDialogResult.filtered_choices;
// modAutomaticDialogPicker - END

@insert(
  at(function SendDialogChoicesToUI)
  select(for ( i = 0; i < lastSetChoices.Size(); i += 1 ))
)
for ( i = 0; i < lastSetChoices.Size() && !MCM_choiceAutomated; i += 1 ) // modAutomaticDialogPicker