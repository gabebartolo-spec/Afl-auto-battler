### Implementation record — synergy clarity (2026-09-29, branch `claude/synergy-clarity`)
- **Problem:** a synergy showed only its name ("Engine room: On"). The player could not tell what it does for the side or who in the side makes it work, so a combination had to be reverse-engineered.
- **Changes:**
  - Wherever an active synergy is named (selection, the match coach box), it now carries what it does in plain football words: "Engine room (wins more of the stoppages)". `Traits.with_effect`.
  - The synergy guide on the selection screen names who in your side carries each trait a synergy needs, in its line: "Aerial threats in your side: Fenn Quiver. Crumbers in your side: none." `Traits.carriers`. Facts only: no "one more X" prompts or suggested picks.
  - The coach box reads "Your synergies: ... Theirs: ...".
  - No numbers added; the effect lines are the existing `does` text.
- **Tests:** `run_roles_tests.gd`: each synergy names who in your side carries what it needs.
- **Acceptance:** the phone playtest - can the player say broadly what their combination is good at and who makes it work?

### Implementation record — decision inputs before the match (2026-09-29, branch `claude/decision-inputs`)
- **Problem:** the selection screen showed the opponent's facts and your own lines separately, in different words, so the comparison was left to the player. The game plan was set on Coaching, away from any match, and not shown before one. How the opponent plays was worked out for every club but only ever shown for yours.
- **Changes (approved proposal), all on the selection screen, replacing the old standing line and opponent facts:**
  - Line against line, both sides in the same words: "Midfield: yours strong, theirs one of the best." / "Your forwards v their defence: below par v middle of the pack." Your half follows your selection. `Matchup.head_to_head`.
  - The people: their danger, their best player missing, a run of wins or losses, and your own key injuries. `Matchup.people`.
  - How they play, after three games, in words and no numbers: "They win it at the stoppages." At most two lines. `GameState.their_style`, from the same model as your "How we win".
  - The game plan you take in, with a Change button opening the same six plans and what each does. It's the same standing plan Coaching sets.
- **Not done, deliberately:** no plan or player suggested, no "suits this opponent", no ratings. The hub stays a quick glance.
- **Tests:**
  - `run_roles_tests.gd`: the matchup reads line against line in words; the plan is shown, can be changed from selection, and Back closes the chooser.
  - `run_matchup_tests.gd`: their style is football words with no numbers; the people facts are people.

