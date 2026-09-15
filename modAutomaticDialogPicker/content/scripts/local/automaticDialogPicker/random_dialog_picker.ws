/**
 * A note on the methods of this class & performances, you will sometimes find
 * `out` parameters especially when structs are passed around. This is rarely
 * to perform mutation on the parameters but rather to avoid the engine from
 * copying the values as structs are passed by value and copied on function 
 * calls, same for arrays.
 * 
 * So to avoid unnecessary copies of data the class uses out parameters to pass
 * them by reference.
 */
statemachine class MCM_RandomDialogPicker {
  protected var dialog_module: CR4HudModuleDialog;
  protected var picked_choice_index: int;

  /**
   * choices that short circuit the mod if seen.
   * Those are mostly bugged choices that CDPR missed, choices that never turn
   * as read or choices that should be emphasised but are not.
   */
  protected var short_circuit_choices: array<string>;

  public function init(module: CR4HudModuleDialog) {
    this.dialog_module = module;
    this.GotoState('Loading');
  }

  function getRandomChoiceToPick(choices: array<SSceneChoice>): bool {
    var valid_choices: array<int>;
    var can_randomly_pick_choice: bool;
    var has_leave_action: bool;
    var has_action_choice: bool;
    var emphasized_choices_count: int;
    var has_optional_choice: bool;
    var has_important_action_choice: bool;
    var read_optional_choices: int;
    var choice: SSceneChoice;
    var index: int;
    var i: int;

    if (choices.Size() == 0) {
      return false;
    }

    LogChannel('MCM', "Obtained choices (count = " + choices.Size() + "), trying to find an automatic pick");

    // this is a safety key to force the mod to show the option. There are cases
    // where it loops over and over and this keybind helps get out of them.
    if (
      theInput.IsActionPressed('ChangeChoiceDown')
      || theInput.IsActionPressed('ChangeChoiceUp')
      || theInput.IsActionPressed('IK_Pad_DigitDown')
      || AbsF(theInput.GetActionValue('GI_AxisRightY')) > 0.1
    ) {
      LogChannel('MCM', "safety short-circuit key found, cancelled");
      return false;
    }

    // first we do a pass to gather information about the types of choices and
    // what we'll focus on later
    for (i = 0; i < choices.Size(); i += 1) {
      choice = choices[i];

      // this.printChoice(choice);

      // anytime there is a leave action, do not pick anything.
      // but do this only in Toussaint, as this is where it causes most issues.
      if (
        theGame.GetCommonMapManager().GetCurrentArea() == 'bob'
        || theGame.GetCommonMapManager().GetCurrentArea() == 'AN_Bob'
        && this.isLeaveAction(choice)
      ) {
        LogChannel('MCM', "found leave action while in BOB region, cancelled for safety");
        return false;
      }

      if (this.isShortCircuitChoice(choice)) {
        LogChannel('MCM', "found short-circuit choice, cancelled for safety");
        return false;
      }

      // important choice that requires user attention, we leave instantly
      if (this.isImportantAction(choice)) {
        LogChannel('MCM', "found important action choice (like gwent or axii), cancelled for safety");
        return false;
      }

      has_leave_action = has_leave_action || this.isLeaveAction(choice);
      has_action_choice = has_action_choice || this.isAction(choice);

      if (choice.previouslyChoosen) {
        read_optional_choices += (int)this.isReadOptionalChoice(choice);

        continue;
      }

      if (this.isEmphasised(choice)) {
        emphasized_choices_count += 1;
      }

      has_optional_choice = has_optional_choice || this.isOptionalChoice(choice);
    }

    // there are actions that always require user attention
    if (has_important_action_choice) {
      return false;
    }

    // when there are two choices, let the player pick. But the optional choices
    // are always played first so it's safe to let them go first.
    if (emphasized_choices_count > 1 && !has_optional_choice) {
      LogChannel('MCM', "found multiple emphasized choices (gold) and no optional choice, cancelled");
      return false;
    }

    // when there are multiple optional choices and nothing else
    if (
      read_optional_choices > 1
      && emphasized_choices_count <= 0
      && !has_action_choice
      && !has_optional_choice
    ) {
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
      else if (emphasized_choices_count > 0) {
        if (this.isEmphasised(choice)) {
          valid_choices.PushBack(i);
        }
      }

      // third if there is a leave action and nothing else
      else if (has_leave_action && !has_action_choice) {
        // commented while i find a way to avoid situations
        // where it picks it when the player wants to replay a dialogue
        //
        if (this.isLeaveAction(choice)) {
          valid_choices.PushBack(i);
        }
      }
    }

    if (valid_choices.Size() == 0) {
      return false;
    }

    LogChannel('MCM', "found " + valid_choices.Size() + " potential choices");
    index = RandRange(valid_choices.Size());
    this.picked_choice_index = valid_choices[index];

    choice = choices[this.picked_choice_index];
    LogChannel('MCM', "automatic dialogchoice picked, description = " + choice.description);

    this.GotoState('RandomDialogPicked');

    return true;
  }

  protected function isUnreadOptionalChoice(out choice: SSceneChoice): bool {
    return this.isOptionalChoice(choice)
        && !choice.previouslyChoosen;
  }

  protected function isReadOptionalChoice(out choice: SSceneChoice): bool {
    return isOptionalChoice(choice)
        && choice.previouslyChoosen;
  }

  protected function isOptionalChoice(out choice: SSceneChoice): bool {
    return !choice.emphasised 
        && choice.dialogAction == DialogAction_NONE;
  }

  protected function isEmphasised(out choice: SSceneChoice): bool {
    return choice.emphasised
        && !choice.previouslyChoosen;
  }

  protected function isLeaveAction(out choice: SSceneChoice): bool {
    return choice.dialogAction == DialogAction_EXIT;
  }

  protected function isAction(out choice: SSceneChoice): bool {
    return !choice.emphasised
        && choice.dialogAction != DialogAction_NONE
        && !this.isLeaveAction(choice);
  }

  protected function isBribeAction(out choice: SSceneChoice): bool {
    return choice.dialogAction == DialogAction_BRIBE
        || choice.dialogAction == DialogAction_MONSTERCONTRACT;
  }

  protected function isAxiiAction(out choice: SSceneChoice): bool {
    return choice.dialogAction == DialogAction_AXII
        || choice.dialogAction == DialogAction_PERSUASION;
  }

  protected function isImportantAction(out choice: SSceneChoice): bool {
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

  protected function isShortCircuitChoice(out choice: SSceneChoice): bool {
    var i: int;

    for (i = 0; i < this.short_circuit_choices.Size(); i += 1) {
      if (this.short_circuit_choices[i] == choice.description) {
        return true;
      }
    }

    return false;
  }
  
  protected function printChoice(out choice: SSceneChoice) {
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
    if (parent.picked_choice_index >= 0) {
      parent.dialog_module.OnDialogOptionSelected(parent.picked_choice_index);
      Sleep(0.4);
      parent.dialog_module.OnDialogOptionAccepted(parent.picked_choice_index);
    }

    parent.GotoState('Waiting');
  }
}