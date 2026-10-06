# FL-001 copy audit: engine terms and software prose in player-facing strings (2026-10-06)

Copy only; nothing here is changed in the game. The rules are CLAUDE.md's: natural AFL language, no engine terms the reader does not need, sentence case. Essential action labels stay plain.

**What was searched.** A keyword sweep of the quoted strings in `scripts/ui`, `scripts/core` and `scripts/state/GameState.gd`, for:
- engine and software words (coefficient, multiplier, seed, simulation, null, cache, invalid, "could not", "failed to" and the like);
- words from other sports (roster, playoff, starter, franchise, seed);
- software prose (confirm dialogs, "please wait", "error").

It is not a read of every string. Strings built from data (names, club lines, news) and the match commentary in `scripts/sim` were not read line by line. Most hits were code, not copy.

## Replace

| Where | Now | Suggested | Why |
|---|---|---|---|
| `scripts/ui/LadderScene.gd:219` | "(level - higher seed advances)" | "(level: the higher-placed side goes through)" | "Seed" is a US playoff word. In AFL finals it is the higher-placed side on the ladder. |
| `scripts/ui/HubScene.gd:63` | "...both use the same match simulation." | "...both play the same match." | "Match simulation" is an engine term. The sentence only needs to say the result is the same kind of match. |
| `scripts/ui/OptionsSheet.gd:36` | "Confirm before simming a round" | "Ask before playing a round for me" | "Simming" is jargon, and the setting guards a round that skips the player's own match. |

## Check before changing

| Where | Now | Note |
|---|---|---|
| `scripts/ui/UiKit.gd:646` | column title "W-L" (narrow ladder) | AFL ladders read W, L, D, Pts and %. "W-L" is a US record. If the cell includes draws it should read "W-L-D". |
| `scripts/ui/TrainingScene.gd:702`, `scripts/state/GameState.gd:5502` | "Could not train that stat." | Fallback wording only. Fine if every failure carries a specific reason; if not, the specific reason is better football ("He's at the ceiling for that stat"). |

## For the director (a rule conflict, not a slip)

- **`scripts/ui/StatGuide.gd:92`** lists the exact weights behind team strengths ("42% midfield contested, 24% ruck, ..."), and `:73` says "The team average is 18% of Defence". CLAUDE.md says not to explain simulation mechanics or percentages unless the player needs them, and also says every rule must be lookable exactly. The guide is the drill-down, so keeping it is defensible. This needs a decision, not an edit.
- **"Sim Round N", "Sim to Grand Final", "Sim round"** (`scripts/ui/HubScene.gd:577, 588, 617`). "Sim" is a normal word in sports games, and "Play" is already the live-match button. Tests check "Sim Round 15". Only worth changing if the director dislikes it.

## Fine as they are

- "Team stats" (`MatchScene.gd:1798`) is AFL language.
- "Engine room" (`Traits.gd:56`) is a football term for the midfield.
- The Finals names (`HubScene.gd:687`) and the "Wildcard Round" label follow the AFL's own names.

## Not covered, and next

Reports, news headlines and clubroom notices are FL-006 and FL-001's remaining surfaces, and wait on the director's copy review ([the review sheet](AFL_FLAVOUR_FL001_COPY_REVIEW.md)). This audit found few engine terms in the fixed UI strings, which suggests the larger risk is in generated text (news, reports, match notes). A second pass could sample those from a played-out season.

## Second pass: the screens the first audit did not read (2026-10-06)

Scope: Main (how to play), StatGuide, Training, Draft, Offseason, Season Review, Coaching, Staff, Selection, List, the player and coach sheets, and the news lines in `GameState`. Fixed text only; generated match notes and reports still need a played-out sample.

**Fixed (copy only, in this PR):**

- `StatGuide.gd` Overall (OVR): "The match itself rolls the individual stats, not OVR." is now "In a match it is the individual stats that count, not OVR." "Rolls" is a dice word.

**For the director (debatable, not changed):**

1. **"XP"** appears across Training, the formation callout and the how-to-play text ("+1 · 40 XP", "banked XP"). It is a role-playing word, not a footy one. A footy alternative would be a plain "training points" or "development", but XP is the name of the whole system and tests and saves use it. Keep or rename?
2. **"Attributes"** is the heading on the player sheet (`PlayerSheet.gd:158`). "Ratings" or "Stats" is closer to how the rest of the game talks. Keep or change?
3. **"Simulate" and "simulated"** in the sim-round confirmations (`HubScene.gd:782, 783, 847`) sit with the "Sim Round N" decision already listed above.
4. **StatGuide mechanism prose** says things like "lifts the goal chance", "weighted strongly toward the best kick" and "a small chance of injury". It is the rules lookup, which the philosophy wants exact, so I left it. If the director wants it plainer, the rewrite is a separate pass.

**Checked and fine:** "OVR" and "POT" (AFL-game convention), the finals names, "Honour roll", "flag", "Team stats", and the news lines that quote an OVR.
