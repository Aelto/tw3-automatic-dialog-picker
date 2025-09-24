struct MCM_RandomDialogPickerResult {
  var choice_automated : bool;
  var filtered_choices : array<SSceneChoice>;
}

struct MCM_BetterFlowWeight {
  var description: string;
  var weight: int;
}

struct MCM_IndexedChoice {
  var simulated_index : int;
  var choice: SSceneChoice;
}

statemachine class MCM_RandomDialogPicker {
  protected var dialog_module: CR4HudModuleDialog;
  protected var picked_choice_index: int;
  protected var filtered_indexed_choices: array<MCM_IndexedChoice>;

  /**
   * choices that short circuit the mod if seen.
   * Those are mostly bugged choices that CDPR missed, choices that never turn
   * as read or choices that should be emphasised but are not.
   */
  protected var short_circuit_choices: array<string>;
  protected var better_flow_weights: array<MCM_BetterFlowWeight>;

  /**
   * stores the current region the player is in. It is set after every loading
   * screen so it will always correspond.
   */
  protected var current_region: string;

  public function init(module: CR4HudModuleDialog) {
    this.dialog_module = module;
    this.GotoState('Loading');
  }

  public function handleCurrentChoices(choices: array<SSceneChoice>): MCM_RandomDialogPickerResult {
    var result: MCM_RandomDialogPickerResult;
    var valid_choice_indices: array<int>;
    var has_leave_action: bool;
    var has_action_choice: bool;
    var emphasized_choices_count: int;
    var has_optional_choice: bool;
    var has_important_action_choice: bool;
    var read_optional_choices_count: int;
    var current_choice_weight: int;
    var better_flow_choice_weight: int;
    var better_flow_choice_index: int;
    var current_choice: SSceneChoice;
    var i: int;

    better_flow_choice_weight = 0;

    // this is a safety key to force the mod to show the option. There are cases
    // where it loops over and over and this keybind helps get out of them.
    if (
      theInput.IsActionPressed('ChangeChoiceDown')
      || theInput.IsActionPressed('ChangeChoiceUp')
      || AbsF(theInput.GetActionValue('GI_AxisLeftY')) > 0.1
    ) {
      return makeResultFromSceneChoices(choices, false);
    }

    // filters possible choices based on mod settings
    filtered_indexed_choices = toFilteredIndexedChoices(choices);
    if (filtered_indexed_choices.Size() == 0) {
      // uh oh we filtered everything... just send the original choices through!
      return makeResultFromSceneChoices(choices, false);
    }

    // this is a safety mechanism to make sure that if there is only one choice
    // and we don't automate that the game selects the simulated index of the
    // 0th element (instead of an element that may have been filtered)
    dialog_module.OnDialogOptionSelected(0);

    // due to mod settings, prevent automation
    if (!MCMConfig_automateChoices()) {
      return makeResult(filtered_indexed_choices, false);
    }

    // first we do a pass to gather information about the types of choices and
    // what we'll focus on later
    for (i = 0; i < filtered_indexed_choices.Size(); i += 1) {
      current_choice = filtered_indexed_choices[i].choice;

      current_choice_weight = this.getBetterFlowChoiceWeight(current_choice);

      if (!current_choice.previouslyChoosen && current_choice_weight > 0) {
        if (better_flow_choice_weight < current_choice_weight) {
          better_flow_choice_weight = current_choice_weight;
          better_flow_choice_index = i;
        }

        continue;
      }

      // anytime there is a leave action, do not pick anything.
      // but do this only in Toussaint, as this is where it causes most issues.
      if (this.current_region == "bob"
          && this.isLeaveAction(current_choice)
          && better_flow_choice_weight <= 0) {
        return makeResult(filtered_indexed_choices, false);
      }

      if (this.isShortCircuitChoice(current_choice)) {
        return makeResult(filtered_indexed_choices, false);
      }

      // important choice that requires user attention, we leave instantly
      if (this.isImportantAction(current_choice)) {
        return makeResult(filtered_indexed_choices, false);
      }

      has_leave_action = has_leave_action || this.isLeaveAction(current_choice);
      has_action_choice = has_action_choice || this.isAction(current_choice);

      if (current_choice.previouslyChoosen) {
        read_optional_choices_count += (int)this.isReadOptionalChoice(current_choice);

        continue;
      }

      if (this.isEmphasised(current_choice)) {
        emphasized_choices_count += 1;
      }

      has_optional_choice = has_optional_choice || this.isUnreadOptionalChoice(current_choice);
    }

    if (better_flow_choice_weight > 0) {
      this.picked_choice_index = better_flow_choice_index;
      this.GotoState('RandomDialogPicked');
      return makeResult(filtered_indexed_choices, true);
    }

    // there are actions that always require user attention
    if (has_important_action_choice) {
      return makeResult(filtered_indexed_choices, false);
    }

    // when there are two choices, let the player pick. But the optional choices
    // are always played first so it's safe to let them go first.
    if (emphasized_choices_count > 1 && !has_optional_choice) {
      return makeResult(filtered_indexed_choices, false);
    }

    // when there are multiple optional choices and nothing else
    if (read_optional_choices_count > 1
        && !emphasized_choices_count
        && !has_action_choice
        && !has_optional_choice) {
      return makeResult(filtered_indexed_choices, false);
    }

    for (i = 0; i < filtered_indexed_choices.Size(); i += 1) {
      current_choice = filtered_indexed_choices[i].choice;

      // most important are optional dialogues
      if (has_optional_choice) {
        if (this.isUnreadOptionalChoice(current_choice)) {
          valid_choice_indices.PushBack(i);
        }
      }

      // second most important are quest choices
      else if (emphasized_choices_count > 0) {
        if (this.isEmphasised(current_choice)) {
          valid_choice_indices.PushBack(i);
        }
      }

      // third if there is a leave action and nothing else
      else if (has_leave_action && !has_action_choice) {
        // commented while i find a way to avoid situations
        // where it picks it when the player wants to replay a dialogue
        //
        if (this.isLeaveAction(current_choice)) {
          valid_choice_indices.PushBack(i);
        }
      }
    }

    if (valid_choice_indices.Size() == 0) {
      return makeResult(filtered_indexed_choices, false);
    }

    this.picked_choice_index = valid_choice_indices[RandRange(valid_choice_indices.Size())];
    this.GotoState('RandomDialogPicked');

    return makeResult(filtered_indexed_choices, true);
  }

  public function toSimulatedIndex(index: int) : int {
    if (index < filtered_indexed_choices.Size()) {
      return filtered_indexed_choices[index].simulated_index;
    } else {
      return index;
    }
  }

  protected function getBetterFlowChoiceWeight(choice: SSceneChoice): int {
    var i: int;

    for (i = 0; i < this.better_flow_weights.Size(); i += 1) {
      if (this.better_flow_weights[i].description == choice.description) {
        return this.better_flow_weights[i].weight;
      }
    }

    return 0;
  }

  protected function isUnreadOptionalChoice(choice: SSceneChoice): bool {
    return this.isOptionalChoice(choice)
        && !choice.previouslyChoosen;
  }

  protected function isReadOptionalChoice(choice: SSceneChoice): bool {
    return isOptionalChoice(choice)
        && choice.previouslyChoosen;
  }

  protected function isOptionalChoice(choice: SSceneChoice): bool {
    return !choice.emphasised 
        && choice.dialogAction == DialogAction_NONE;
  }

  protected function isEmphasised(choice: SSceneChoice): bool {
    return choice.emphasised
        && !choice.previouslyChoosen;
  }

  protected function isLeaveAction(choice: SSceneChoice): bool {
    return choice.dialogAction == DialogAction_EXIT;
  }

  protected function isAction(choice: SSceneChoice): bool {
    return !choice.emphasised
        && choice.dialogAction != DialogAction_NONE
        && !this.isLeaveAction(choice);
  }

  protected function isBribeAction(choice: SSceneChoice): bool {
    return choice.dialogAction == DialogAction_BRIBE
        || choice.dialogAction == DialogAction_MONSTERCONTRACT;
  }

  protected function isAxiiAction(choice: SSceneChoice): bool {
    return choice.dialogAction == DialogAction_AXII
        || choice.dialogAction == DialogAction_PERSUASION;
  }

  protected function isImportantAction(choice: SSceneChoice): bool {
    return this.isBribeAction(choice)
        || this.isAxiiAction(choice)
        || choice.dialogAction == DialogAction_HOUSE
        || choice.dialogAction == DialogAction_GAME_DICES
        || choice.dialogAction == DialogAction_GAME_FIGHT
        || choice.dialogAction == DialogAction_GAME_WRESTLE
        || choice.dialogAction == DialogAction_TimedChoice
        || choice.dialogAction == DialogAction_HAIRCUT
        || choice.dialogAction == DialogAction_MONSTERCONTRACT
        || choice.dialogAction == DialogAction_BET
        || choice.dialogAction == DialogAction_STORAGE
        || choice.dialogAction == DialogAction_GIFT
        || choice.dialogAction == DialogAction_GAME_DRINK
        || choice.dialogAction == DialogAction_GAME_DAGGER
        || choice.dialogAction == DialogAction_GAME_CARDS
        || choice.dialogAction == DialogAction_AUCTION

        // if it's an emphasised choice and it has an icon
        // it's always considered important
        || (
          choice.emphasised
          && choice.dialogAction != DialogAction_NONE
        )

        // if it contains special characters
        || this.hasImportantWord(choice.description);
  }

  protected function hasImportantWord(description: string): bool {
    var lowercase: string;

    lowercase = StrLower(description);

    // IMPORTANT NOTE:
    // 
    // some lines were updated to no longer include these special characters as
    // they weren't that important and could benefit from automatic selection by
    // the mod:
    // - quest "flying bovine":
    //   - 1202617|00000000||[Wounds on the worker's body.]
    //   - 1150029|00000000||[Cause of the accident.]
    //   - 1150030|00000000||[Blunt trauma wounds on the cow.]
    //   - 1150031|00000000||[Bite wounds on the cow.]
    //   - 1150032|00000000||[Punctures and slashes on the cow.]
    //   - 1150033|00000000||[Leave.]
    //
    return StrContains(lowercase, "(")
        || StrContains(lowercase, ")")
        || StrContains(lowercase, "[")
        || StrContains(lowercase, "]")
        || StrContains(lowercase, "card")
        || StrContains(lowercase, "gwent")
        || StrContains(lowercase, "a round");
  }

  protected function isShortCircuitChoice(choice: SSceneChoice): bool {
    var i: int;

    for (i = 0; i < this.short_circuit_choices.Size(); i += 1) {
      if (this.short_circuit_choices[i] == choice.description) {
        return true;
      }
    }

    return false;
  }

  protected function makeResult(
    filtered_indexed_choices: array<MCM_IndexedChoice>,
    choice_automated: bool
  ): MCM_RandomDialogPickerResult {
    return makeResultFromSceneChoices(toSceneChoices(filtered_indexed_choices), choice_automated);
  }

  protected function makeResultFromSceneChoices(
    choices: array<SSceneChoice>,
    choice_automated: bool
  ): MCM_RandomDialogPickerResult {
    var result: MCM_RandomDialogPickerResult;

    result.choice_automated = choice_automated;
    result.filtered_choices = choices;

    return result;
  }

  protected function allChoicesOptional(choices: array<SSceneChoice>): bool {
    var all_choices_optional: bool;
    var i: int;

    for(i = 0, all_choices_optional = true; i < choices.Size(); i += 1) {
      all_choices_optional = all_choices_optional && isOptionalChoice(choices[i]);
    }

    return all_choices_optional;
  }

  protected function toFilteredIndexedChoices(choices: array<SSceneChoice>): array<MCM_IndexedChoice> {
    var filtered_indexed_choices: array<MCM_IndexedChoice>;
    var skip_filter: bool;
    var i: int;

    skip_filter = willFilterRemoveAllChoices(choices);
    for (i = 0; i < choices.Size(); i += 1) {
      if (skip_filter || shouldFilterKeepChoice(choices[i])) {
        filtered_indexed_choices.PushBack(toIndexedChoice(choices[i], i));
      }
    }

    return filtered_indexed_choices;
  }

  protected function willFilterRemoveAllChoices(choices: array<SSceneChoice>): bool {
    var i: int;

    for(i = 0; i < choices.Size(); i += 1) {
      if (shouldFilterKeepChoice(choices[i])) {
        return false;
      }
    }

    return true;
  }

  protected function shouldFilterKeepChoice(choice: SSceneChoice): bool {
    var optional_filter_level: EMCM_OptionalDialogFilterLevel;

    optional_filter_level = MCMConfig_getOptionalDialogFilterLevel();

    if (optional_filter_level == EMCM_None) {
      return true;
    }
    
    if (optional_filter_level == EMCM_All && isOptionalChoice(choice)) {
      return false;
    }
    else if (optional_filter_level == EMCM_Read && isReadOptionalChoice(choice)) {
      return false;
    }

    return true;
  }

  protected function toIndexedChoice(choice: SSceneChoice, simulated_index: int): MCM_IndexedChoice {
    var indexedChoice: MCM_IndexedChoice;
    
    indexedChoice.simulated_index = simulated_index;
    indexedChoice.choice = choice;

    return indexedChoice;
  }

  private function toSceneChoices(indexed_choices: array<MCM_IndexedChoice>): array<SSceneChoice> {
    var i: int;
    var choices: array<SSceneChoice>;

    for(i = 0; i < indexed_choices.Size(); i += 1) {
      choices.PushBack(indexed_choices[i].choice);
    }

    return choices;
  }

  protected function printChoice(choice: SSceneChoice) {
    // NLOG(
    //   "is emphasised: " + choice.emphasised +
    //   " action: " + choice.dialogAction +
    //   " chunk: " + choice.playGoChunk +
    //   " previouslyChoosen: " + choice.previouslyChoosen +
    //   " description: " + choice.description);
  }
}

state Loading in MCM_RandomDialogPicker {
  event OnEnterState(previous_state_name: name) {
    super.OnEnterState(previous_state_name);
    this.Loading_main();
  }

  entry function Loading_main() {
    this.loadShortCircuitChoices();
    this.loadbetter_flow_choice_weights();
    parent.current_region = AreaTypeToName(theGame.GetCommonMapManager().GetCurrentArea());
    parent.GotoState('Waiting');
  }

  function loadShortCircuitChoices() {
    // "Need an armor repair table"
    // when upgrading the house in B&W
    parent.short_circuit_choices.PushBack(
      GetLocStringById(1187179)
    );

    // "Let's do some work on the house"
    // when upgrading the house in B&W
    parent.short_circuit_choices.PushBack(
      GetLocStringById(1187165)
    );

    // "The grounds - be nice to improve those."
    // when upgrading the house in B&W
    parent.short_circuit_choices.PushBack(
      GetLocStringById(1187166)
    );

    // "Need a loan."
    parent.short_circuit_choices.PushBack(
      GetLocStringById(1032393)
    );

    // "Wanna pay back my loan."
    parent.short_circuit_choices.PushBack(
      GetLocStringById(1032416)
    );

    // Nothing to mourn. They were Nilfgaardians.
    parent.short_circuit_choices.PushBack(
      GetLocStringById(570554)
    );

    // Same as above, duplicated for some reason
    parent.short_circuit_choices.PushBack(
      GetLocStringById(570560)
    );

    // Refuse to chase down some goat.
    parent.short_circuit_choices.PushBack(GetLocStringById(472848));

    // Don't talk to her that way.
    parent.short_circuit_choices.PushBack(GetLocStringById(433741));
    parent.short_circuit_choices.PushBack(GetLocStringById(433743));

    // You can't torture Triss. I won't allow it.
    parent.short_circuit_choices.PushBack(GetLocStringById(380941));
    // no other way?
    parent.short_circuit_choices.PushBack(GetLocStringById(380987));
    // I'm looking for this treasure…
    parent.short_circuit_choices.PushBack(GetLocStringById(434433));

    // Got no time for this. You're dead.
    parent.short_circuit_choices.PushBack(GetLocStringById(1092100));

    // Surprise me.
    parent.short_circuit_choices.PushBack(GetLocStringById(1200406));

    // Middle of the road, let's.
    parent.short_circuit_choices.PushBack(GetLocStringById(1200422));

    // Need to change some coin.
    parent.short_circuit_choices.PushBack(GetLocStringById(1104418));

    // I'd like to change some coin.
    parent.short_circuit_choices.PushBack(GetLocStringById(1104531));

    // Got something else to do here.
    parent.short_circuit_choices.PushBack(GetLocStringById(1200894));

    // Cave I came out of… what was that place?
    parent.short_circuit_choices.PushBack(GetLocStringById(1156674));
    parent.short_circuit_choices.PushBack(GetLocStringById(1156732));

    // Sure, why not
    parent.short_circuit_choices.PushBack(GetLocStringById(1171652));
    parent.short_circuit_choices.PushBack(GetLocStringById(1196346));

    // Where'd you develop this interest in witchers' things?
    parent.short_circuit_choices.PushBack(GetLocStringById(1094253));

    // You could've shown a little sympathy
    parent.short_circuit_choices.PushBack(GetLocStringById(481132));

    // Family Matters: Resemblance is uncanny.
    parent.short_circuit_choices.PushBack(GetLocStringById(475532));

    // Family Matters: Let's do this.
    parent.short_circuit_choices.PushBack(GetLocStringById(393189));

    // Family Matters: Who'd you see? Describe her.
    parent.short_circuit_choices.PushBack(GetLocStringById(177966));

    // Magic Lamp: Repeat the inscription.
    parent.short_circuit_choices.PushBack(GetLocStringById(558241));

    // Hendrik Candle Puzzle: Turn Left Turn Right
    parent.short_circuit_choices.PushBack(GetLocStringById(474052));
    parent.short_circuit_choices.PushBack(GetLocStringById(474054));
    parent.short_circuit_choices.PushBack(GetLocStringById(474048));
    parent.short_circuit_choices.PushBack(GetLocStringById(474050));
    parent.short_circuit_choices.PushBack(GetLocStringById(474050));
    parent.short_circuit_choices.PushBack(GetLocStringById(474040));
    parent.short_circuit_choices.PushBack(GetLocStringById(474038));

    // Race, Crow's Perch:
    parent.short_circuit_choices.PushBack(GetLocStringById(579270));
    parent.short_circuit_choices.PushBack(GetLocStringById(579373));
    parent.short_circuit_choices.PushBack(GetLocStringById(579375));
    parent.short_circuit_choices.PushBack(GetLocStringById(579374));

    // Race, Skelliger:
    parent.short_circuit_choices.PushBack(GetLocStringById(575266));
    parent.short_circuit_choices.PushBack(GetLocStringById(574690));
    parent.short_circuit_choices.PushBack(GetLocStringById(576537));

    // Contract Mysterious Tracks: Here about the contract.
    parent.short_circuit_choices.PushBack(GetLocStringById(445108));

    // Contract The Merry Widow: Here about the job.
    parent.short_circuit_choices.PushBack(GetLocStringById(445122));

    // Fools' Gold: Let's talk.
    parent.short_circuit_choices.PushBack(GetLocStringById(522217));

    // The Play's the Thing: We can start now.
    parent.short_circuit_choices.PushBack(GetLocStringById(368277));

    // The Play's the Thing
    parent.short_circuit_choices.PushBack(GetLocStringById(396613));
    parent.short_circuit_choices.PushBack(GetLocStringById(396617));
    parent.short_circuit_choices.PushBack(GetLocStringById(396621));
    parent.short_circuit_choices.PushBack(GetLocStringById(396625));

    // The Play's the Thing
    parent.short_circuit_choices.PushBack(GetLocStringById(182706));
    parent.short_circuit_choices.PushBack(GetLocStringById(396633));
    parent.short_circuit_choices.PushBack(GetLocStringById(396637));
    parent.short_circuit_choices.PushBack(GetLocStringById(396641));

    // The Play's the Thing
    parent.short_circuit_choices.PushBack(GetLocStringById(182742));
    parent.short_circuit_choices.PushBack(GetLocStringById(396647));
    parent.short_circuit_choices.PushBack(GetLocStringById(396651));
    parent.short_circuit_choices.PushBack(GetLocStringById(396655));

    // Barbers with dialogs that contain the "haircut" word,
    // they're usually split in two options: one to select the haircut, another
    // for the beard. But these choices don't have any icon so the mod may think
    // they're ordinary optional choices.
    parent.short_circuit_choices.PushBack(GetLocStringById(1066777));
    parent.short_circuit_choices.PushBack(GetLocStringById(1066772));
    parent.short_circuit_choices.PushBack(GetLocStringById(1092732));
    parent.short_circuit_choices.PushBack(GetLocStringById(577814));
    parent.short_circuit_choices.PushBack(GetLocStringById(577784));
    parent.short_circuit_choices.PushBack(GetLocStringById(577797));
  }

  function loadbetter_flow_choice_weights() {
    // Family Matters: Talk to Fisherman
    // Tell me about these marks.
    this.setbetter_flow_choice_weight(GetLocStringById(401244), 400);
    // What happened next?
    this.setbetter_flow_choice_weight(GetLocStringById(400689), 300);
    // Why did you help them?
    this.setbetter_flow_choice_weight(GetLocStringById(401246), 200);
    // I know where Anna is.
    this.setbetter_flow_choice_weight(GetLocStringById(400687), 100);

    // A Towerful of Mice: Talk with Keira
    // Xenovox - never heard of that.
    this.setbetter_flow_choice_weight(GetLocStringById(520972), 200);
    // Where'd you get the xenovox?
    this.setbetter_flow_choice_weight(GetLocStringById(520974), 100);
  }

  function setbetter_flow_choice_weight(choice_description: string, choice_weight: int) {
    var better_flow_choice: MCM_BetterFlowWeight;

    better_flow_choice.description = choice_description;
    better_flow_choice.weight = choice_weight;
    parent.better_flow_weights.PushBack(better_flow_choice);
  }
}

state Waiting in MCM_RandomDialogPicker {
  event OnEnterState(previous_state_name: name) {
    super.OnEnterState(previous_state_name);
  }
}

state RandomDialogPicked in MCM_RandomDialogPicker {
  event OnEnterState(previous_state_name: name) {
    super.OnEnterState(previous_state_name);
    // MCMDEBUG("entering state RandomDialogPicked");
    
    RandomDialogPicked_main();
  }

  entry function RandomDialogPicked_main() {
    parent.dialog_module.OnDialogOptionSelected(parent.picked_choice_index);
    Sleep(0.4);
    parent.dialog_module.OnDialogOptionAccepted(parent.picked_choice_index);

    parent.GotoState('Waiting');
  }
}