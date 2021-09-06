struct MCM_BetterFlowWeight {
  var description: string;
  var weight: int;
}

statemachine class MCM_RandomDialogPicker {
  var dialog_module: CR4HudModuleDialog;
  var picked_choice: int;

  /**
   * choices that short circuit the mod if seen.
   * Those are mostly bugged choices that CDPR missed, choices that never turn
   * as read or choices that should be emphasised but are not.
   */
  var short_circuit_choices: array<string>;
  var better_flow_weights: array<MCM_BetterFlowWeight>;

  function init(module: CR4HudModuleDialog) {
    this.dialog_module = module;
    this.GotoState('Loading');
  }

  function loadBetterFlowChoiceWeights() {
    var better_flow_choice: MCM_BetterFlowWeight;

    // Family Matters: Talk to Fisherman
    // Tell me about these marks.
    better_flow_choice.description = GetLocStringById(401244);
    better_flow_choice.weight = 400;
    this.better_flow_weights.PushBack(better_flow_choice);
    // What happened next?
    better_flow_choice.description = GetLocStringById(400689);
    better_flow_choice.weight = 300;
    this.better_flow_weights.PushBack(better_flow_choice);
    // Why did you help them?
    better_flow_choice.description = GetLocStringById(401246);
    better_flow_choice.weight = 200;
    this.better_flow_weights.PushBack(better_flow_choice);
    // I know where Anna is.
    better_flow_choice.description = GetLocStringById(400687);
    better_flow_choice.weight = 100;
    this.better_flow_weights.PushBack(better_flow_choice);
  }

  function getBetterFlowChoiceWeight(choice: SSceneChoice): int {
    var i: int;

    for (i = 0; i < this.better_flow_weights.Size(); i += 1) {
      if (this.better_flow_weights[i].description == choice.description) {
        return this.better_flow_weights[i].weight;
      }
    }

    return 0;
  }

  function loadShortCircuitChoices() {
    // "Need an armor repair table"
    // when upgrading the house in B&W
    this.short_circuit_choices.PushBack(
      GetLocStringById(1187179)
    );

    // "Let's do some work on the house"
    // when upgrading the house in B&W
    this.short_circuit_choices.PushBack(
      GetLocStringById(1187165)
    );

    // "The grounds - be nice to improve those."
    // when upgrading the house in B&W
    this.short_circuit_choices.PushBack(
      GetLocStringById(1187166)
    );

    // "Need a loan."
    this.short_circuit_choices.PushBack(
      GetLocStringById(1032393)
    );

    // "Wanna pay back my loan."
    this.short_circuit_choices.PushBack(
      GetLocStringById(1032416)
    );

    // Nothing to mourn. They were Nilfgaardians.
    this.short_circuit_choices.PushBack(
      GetLocStringById(570554)
    );

    // Same as above, duplicated for some reason
    this.short_circuit_choices.PushBack(
      GetLocStringById(570560)
    );

    // Refuse to chase down some goat.
    this.short_circuit_choices.PushBack(GetLocStringById(472848));

    // Don't talk to her that way.
    this.short_circuit_choices.PushBack(GetLocStringById(433741));
    this.short_circuit_choices.PushBack(GetLocStringById(433743));

    // You can't torture Triss. I won't allow it.
    this.short_circuit_choices.PushBack(GetLocStringById(380941));
    // no other way?
    this.short_circuit_choices.PushBack(GetLocStringById(380987));
    // I'm looking for this treasure…
    this.short_circuit_choices.PushBack(GetLocStringById(434433));

    // Got no time for this. You're dead.
    this.short_circuit_choices.PushBack(GetLocStringById(1092100));

    // Surprise me.
    this.short_circuit_choices.PushBack(GetLocStringById(1200406));

    // Middle of the road, let's.
    this.short_circuit_choices.PushBack(GetLocStringById(1200422));

    // Need to change some coin.
    this.short_circuit_choices.PushBack(GetLocStringById(1104418));
    
    // I'd like to change some coin.
    this.short_circuit_choices.PushBack(GetLocStringById(1104531));

    // Got something else to do here.
    this.short_circuit_choices.PushBack(GetLocStringById(1200894));

    // Cave I came out of… what was that place?
    this.short_circuit_choices.PushBack(GetLocStringById(1156674));
    this.short_circuit_choices.PushBack(GetLocStringById(1156732));

    // Sure, why not
    this.short_circuit_choices.PushBack(GetLocStringById(1171652));
    this.short_circuit_choices.PushBack(GetLocStringById(1196346));

    // Where'd you develop this interest in witchers' things?
    this.short_circuit_choices.PushBack(GetLocStringById(1094253));

    // You could've shown a little sympathy
    this.short_circuit_choices.PushBack(GetLocStringById(481132));

    // Family Matters: Resemblance is uncanny.
    this.short_circuit_choices.PushBack(GetLocStringById(475532));

    // Family Matters: Let's do this.
    this.short_circuit_choices.PushBack(GetLocStringById(393189));

    // Family Matters: Who'd you see? Describe her.
    this.short_circuit_choices.PushBack(GetLocStringById(177966));
  }

  function isOptionalChoice(choice: SSceneChoice): bool {
    return this.isReadOptionalChoice(choice)
        && !choice.previouslyChoosen;
  }

  function isReadOptionalChoice(choice: SSceneChoice): bool {
    return !choice.emphasised
        && choice.dialogAction == DialogAction_NONE;
  }

  function isEmphasised(choice: SSceneChoice): bool {
    return choice.emphasised
        && !choice.previouslyChoosen;
  }

  function isLeaveAction(choice: SSceneChoice): bool {
    return choice.dialogAction == DialogAction_EXIT;
  }

  function isAction(choice: SSceneChoice): bool {
    return !choice.emphasised
        && choice.dialogAction != DialogAction_NONE
        && !this.isLeaveAction(choice);
  }

  function isBribeAction(choice: SSceneChoice): bool {
    return choice.dialogAction == DialogAction_BRIBE
        || choice.dialogAction == DialogAction_MONSTERCONTRACT;
  }

  function isAxiiAction(choice: SSceneChoice): bool {
    return choice.dialogAction == DialogAction_AXII
        || choice.dialogAction == DialogAction_PERSUASION;
  }

  function isImportantAction(choice: SSceneChoice): bool {
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

  function hasImportantWord(description: string): bool {
    var lowercase: string;

    lowercase = StrLower(description);

    return StrContains(lowercase, "(")
        || StrContains(lowercase, ")")
        || StrContains(lowercase, "[")
        || StrContains(lowercase, "]")
        || StrContains(lowercase, "]")
        || StrContains(lowercase, "card")
        || StrContains(lowercase, "gwent")
        || StrContains(lowercase, "a round");
  }

  function isShortCircuitChoice(choice: SSceneChoice): bool {
    var i: int;

    for (i = 0; i < this.short_circuit_choices.Size(); i += 1) {
      if (this.short_circuit_choices[i] == choice.description) {
        return true;
      }
    }

    return false;
  }

  function printChoice(choice: SSceneChoice) {
    // NLOG(
    //   "is emphasised: " + choice.emphasised +
    //   " action: " + choice.dialogAction +
    //   " chunk: " + choice.playGoChunk +
    //   " previouslyChoosen: " + choice.previouslyChoosen +
    //   " description: " + choice.description);
  }


  function getRandomChoiceToPick(choices: array<SSceneChoice>): bool {
    var valid_choices: array<int>;
    var can_randomly_pick_choice: bool;
    var has_leave_action: bool;
    var has_action_choice: bool;
    var has_emphasised_choices: int;
    var has_optional_choice: bool;
    var has_important_action_choice: bool;
    var read_optional_choices: int;
    var current_choice_weight: int;
    var better_flow_choice_weight: int;
    var better_flow_choice_index: int;
    var choice: SSceneChoice;
    var index: int;
    var i: int;

    better_flow_choice_weight = 0;

    if (choices.Size() == 0) {
      return false;
    }

    // this is a safety key to force the mod to show the option. There are cases
    // where it loops over and over and this keybind helps get out of them.
    if (theInput.IsActionPressed('ChangeChoiceDown') || theInput.IsActionPressed('ChangeChoiceUp')) {
      return false;
    }

    // first we do a pass to gather information about the types of choices and
    // what we'll focus on later
    for (i = 0; i < choices.Size(); i += 1) {
      choice = choices[i];

      // this.printChoice(choice);

      current_choice_weight = this.getBetterFlowChoiceWeight(choice);

      if (!choice.previouslyChoosen && current_choice_weight > 0) {
            if (better_flow_choice_weight < current_choice_weight) {
              better_flow_choice_weight = current_choice_weight;
              better_flow_choice_index = i;
            }
            continue;
      }

      // anytime there is a leave action, do not pick anything.
      if (this.isLeaveAction(choice) && better_flow_choice_weight <= 0) {
        return false;
      }

      if (this.isShortCircuitChoice(choice)) {
        return false;
      }

      // important choice that requires user attention, we leave instantly
      if (this.isImportantAction(choice)) {
        return false;
      }

      has_action_choice = has_action_choice || this.isAction(choice);

      if (choice.previouslyChoosen) {
        read_optional_choices += (int)this.isReadOptionalChoice(choice);

        continue;
      }

      if (this.isEmphasised(choice)) {
        has_emphasised_choices += 1;
      }

      has_optional_choice = has_optional_choice || this.isOptionalChoice(choice);
    }

    if (better_flow_choice_weight > 0) {
      this.picked_choice = better_flow_choice_index;
      this.GotoState('RandomDialogPicked');
      return true;
    }

    // there are actions that always require user attention
    if (has_important_action_choice) {
      return false;
    }

    // when there are two choices, let the player pick. But the optional choices
    // are always played first so it's safe to let them go first.
    if (has_emphasised_choices > 1 && !has_optional_choice) {
      return false;
    }

    // when there are multiple optional choices and nothing else
    if (read_optional_choices > 1
    && !has_emphasised_choices
    && !has_action_choice
    && !has_optional_choice) {
      return false;
    }

    for (i = 0; i < choices.Size(); i += 1) {
      choice = choices[i];

      // most important are optional dialogues
      if (has_optional_choice) {
        if (this.isOptionalChoice(choice)) {
          valid_choices.PushBack(i);
        }
      }

      // second most important are quest choices
      else if (has_emphasised_choices > 0) {
        if (this.isEmphasised(choice)) {
          valid_choices.PushBack(i);
        }
      }
    }

    if (valid_choices.Size() == 0) {
      return false;
    }

    index = RandRange(valid_choices.Size());
    this.picked_choice = valid_choices[index];
    this.GotoState('RandomDialogPicked');

    return true;
  }
}

state Loading in MCM_RandomDialogPicker {
  event OnEnterState(previous_state_name: name) {
    super.OnEnterState(previous_state_name);
    this.Loading_main();
  }

  entry function Loading_main() {
    parent.loadShortCircuitChoices();
    parent.loadBetterFlowChoiceWeights();
    parent.GotoState('Waiting');
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
    parent.dialog_module.OnDialogOptionSelected(parent.picked_choice);
    Sleep(0.4);
    parent.dialog_module.OnDialogOptionAccepted(parent.picked_choice);

    parent.GotoState('Waiting');
  }
}