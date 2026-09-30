# System Reality Audit

2026-09-29. Audit only: nothing was fixed. Code traced from the player's choice to the outcome, and match levers measured with paired seeds.

**What was audited.** `main` plus the open stack #97 → #102, all of which are my own work:
- #97 in-match injuries and the story feed;
- #98 traits;
- #99 draft information;
- #100 "With us";
- #101 numbers out of decisions;
- #102 momentum.

Where a finding differs between `main` and the stack, both are given.

**How to read the measurements.**
- "Paired" means the same 600 fixtures, clubs and seeds, run with and without one change for side 0 (home). Opponents play Balanced unless stated.
- ± is one standard error of the paired difference. With about 36 points of margin spread, effects under about 3 points are hard to separate from noise at this sample size.

## Executive summary

**40 systems audited**, with these statuses:

| Status | Count |
|---|---|
| WORKING | 26 |
| WORKING BUT QUESTIONABLE | 7 |
| PARTIALLY CONNECTED | 2 |
| UI / REPORT ONLY | 2 (momentum on `main`, fixed in #102; player form) |
| NO-OP | 1 |
| DEAD / DISCONNECTED | 1 (not player-facing) |
| UNVERIFIED | 1 |

**Most important discoveries:**

1. **The game plan you choose is thrown away at the first bounce of every live match.**
   - The pre-bounce call box starts on Balanced, not on your club plan. Pressing Start without re-picking sets the engine to Balanced.
   - Proven by driving a real live match: engine plan "defensive" before the box, "balanced" after Start.
   - Plan counters are the biggest lever in the game (about 20+ points), so a player who reads "Their usual game: Defensive press" and counters it loses the counter.
2. **The momentum meter was decorative on `main`.** The engine had no momentum. This is fixed in #102, not yet merged.
3. **Your seven or so moment-card decisions a match do not change results.** Over 300 live matches, always taking the default, first or last option gave margins within 0.4 points of each other.
4. **Tagging works on the man but not on the match.** The tagged midfielder loses about 6 disposals; your margin changes by −0.9 ± 1.5.
5. **Balanced is a trap.** Every other plan except Through stars beats it by 2.6 to 7.8 points against a Balanced side. It is the default, and bug 1 forces it.
6. **Through stars does nothing measurable** to a match (+0.9 ± 1.5).
7. **Morale has a large, never-explained match effect.** An unhappy side (morale 20) is −6.0 ± 1.5 a match. The player only ever sees a "Mood" word.
8. **"In form / Out of form" on the Coaching screen is report only.** The engine has no player form.

## Critical findings

### C1. The standing game plan is dropped in live matches (PARTIALLY CONNECTED, Critical)

**What happens:**
- Selection (and Coaching) set `club_plan`.
- `GameState.prepare_interactive_match` passes it to the engine: `pending_sim.set_tactics(side, {"gameplan": club_plan})`.
- `MatchScene` then opens the "Before the first bounce" call box. It builds `calls["gameplan"]` from `_last_tactics`, which is empty before quarter one, so it defaults to `"balanced"` (`MatchScene.gd`, `_show_coach_box`).
- Start calls `_apply_quarter_tactics(t)` → `sim.set_tactics(my_side, t)`, which overwrites the plan.

**Evidence:** a headless probe drove a real live match with `set_club_plan("defensive")`:

```
PROBE before bounce: engine plan for my side = defensive  club_plan = defensive
PROBE after Start (plan untouched): engine plan for my side = balanced
```

**Why it matters:**
- Plans are worth +2.6 to +7.8 against Balanced, and +22 to +24 as a counter.
- The selection screen says "The game plan you take in", and the call box then silently shows Balanced.
- Simulated rounds are unaffected (`season.plans` via `_sync_club_plan`), so the bug only hits the matches the player watches.

**Tests:** `run_roles_tests` and `run_career_ui_tests` check that picking a plan stores `club_plan`. No test checks the plan the engine plays at the first bounce.

**Recommendation:** seed the pre-bounce call box from the club plan, and add a behavioural test on the engine's plan after Start.

### C2. The momentum meter was UI-only on `main` (UI / REPORT ONLY on `main`; WORKING in #102, Critical)

**On `main`:**
- `MatchScene._track_momentum` computed its own number from the events on screen.
- The engine had no momentum state; the only related thing was a goal-run counter (`_run`) used to trigger a moment card.
- The old test ("Ordinary play still ages the momentum meter") tested the display's own arithmetic.

**Fixed in #102 (unmerged):**
- An engine value that goals swing, fades and caps.
- A 4% contest edge at full momentum.
- The meter reads the engine value.
- Measured: the scorers kick the next goal 51.8% of the time, against 51.1% without it.

### C3. Moment-card choices do not move results (WORKING BUT QUESTIONABLE, High)

**Promise:** each card is "your call" at a turning point (set shot, tired star, hot player, a run against you, a late centre bounce, a key forward on top).

**Evidence:**
- 300 live matches, same seeds. Side 0 average margin: always the default option +6.73, always the first +6.34, always the last +6.31.
- Cards per match: set shot 2.6, tired star 2.5, "run against you" 1.4, key forward 0.5, hot midfielder 0.16, late bounce 0.11.

**Why:**
- The set-shot options are built with similar expected value.
- The burst calls ("Throw numbers at it", "Stack the stoppage"…) last 4–8 chains, two to five minutes.
- Resting a tired star swaps him with a bench player whose legs are also below full.

**Tests:** `_test_moments` checks that moments fire, are logged and add up on the scoreboard. None checks that a choice changes anything.

**Recommendation:** decide which cards should matter and give their options real, visible trade-offs; retire the ones that cannot.

### C4. Tagging reduces the man, not the match (WORKING BUT QUESTIONABLE, High)

**Evidence:** tag on the opposition's best midfielder for the whole match, paired, 600 matches:
- his disposals −6.18 a match;
- your margin −0.9 ± 1.5;
- clearance and inside-50 differentials unchanged.

**Why:** the engine picks who gets the ball after it has decided which side wins it. The ball just goes to his teammates (design audit §4.1).

**Tests:** check his share falls. None checks the team result.

**Recommendation:** already the design audit's root problem, the named-player contests of §4.1; Gate 1.12 did this for forwards.

## System-by-system audit

The same fields for each system.

### Match: pre-match and break calls

**1. Standing game plan into live matches**
- **Status:** PARTIALLY CONNECTED. Critical. See C1.

**2. Game plans (the engine effect)**
- **Player promise:** each plan trades something; "every plan gives something up"; Balanced "plays it straight".
- **Implementation path:** `tactics[side].gameplan` → `_pv` (scaled by `tactics_exec` and PlanFit) → contest, goal, gain, clangers, pressure, pace.
- **Evidence (paired, 600 matches, against a Balanced side):**

  | Plan | Margin | Notes |
  |---|---|---|
  | Defensive press | +7.8 ± 1.7 | win % 57 → 68 |
  | Attack corridor | +5.2 ± 1.7 | +6.6 own clangers |
  | Controlled tempo | +5.1 ± 1.7 | −8.2 own clangers |
  | Win contest | +2.6 ± 1.7 | +4.6 clearance differential |
  | Through stars | +0.9 ± 1.5 | |

- **Test coverage:** multiplier-level. #93 measured plan fit behaviourally.
- **Status:** WORKING BUT QUESTIONABLE. High.
  - Every plan except Through stars beats Balanced, so the default is dominated.
  - Against a Balanced side, Defensive press is the best choice.
- **Recommendation:** give Balanced a genuine role, or make the plans' costs real against Balanced.

**3. Plan counters**
- **Player promise:** "Attack corridor beats Controlled tempo; a Defensive press squeezes it", and so on.
- **Evidence:** gain from switching from Balanced to plan X, against an opponent on plan Y (400 paired matches each):

  | X against Y | Gain |
  |---|---|
  | Defensive press v Attack corridor | +23.8 ± 2.1 |
  | Controlled tempo v Defensive press | +22.2 ± 2.1 |
  | Attack corridor v Controlled tempo | +9.9 ± 2.1 |
  | Controlled tempo v Attack corridor | +3.0 ± 2.0 |
  | Attack corridor v Defensive press | −1.9 ± 2.0 |
  | Defensive press v Controlled tempo | −4.9 ± 2.0 |

- **Status:** WORKING, and the strongest lever in the game.
  - Three-plus goals for the right counter to a press, or the press against a corridor side.
  - Worth noting: much bigger than anything else the player controls.

**4. Plan fit (does the list suit the plan)**
- **Implementation path:** `PlanFit.fit` scales a plan's upside.
- **Evidence:** #93 measured it. On a list suited to it, Defensive press went 95% / +35 against Balanced 66% / +12.
- **Status:** WORKING.

**5. Pep talks**
- **Player promise:** "Fire them up: more intensity at the contest; legs go quicker". "Calm the group: fewer errors…". "Composed" is the default.
- **Evidence (paired, 600 matches):**
  - Fire them up: +3.1 ± 1.5 (+3.0 clearance differential, +0.9 clangers).
  - Calm the group: +1.6 ± 1.6 (−4.6 clangers).
  - The legs cost of Fire them up does not show over a match.
- **Test coverage:** multipliers and energy only.
- **Status:** WORKING BUT QUESTIONABLE. Medium. Fire them up is a free gain, and the default ("Composed") is dominated.

**6. Tag**
- **Status:** WORKING BUT QUESTIONABLE. High. See C4.

**7. Play through (a named player)**
- **Player promise:** get the ball to him.
- **Evidence (paired, 600):** his disposals +2.0; margin +0.4 ± 1.3.
- **Test coverage:** his disposals rise (behavioural, for the promise).
- **Status:** WORKING BUT QUESTIONABLE. Medium. It keeps its promise but does nothing for the result.

**8. Through stars (plan)**
- **Player promise:** funnel the ball to 82+ stars. The assistant's text says "+12% possessions"; the code gives +20% selection weight.
- **Evidence:** +0.9 ± 1.5; no clearance, inside-50 or goal change.
- **Status:** NO-OP (on results). Medium.
- **Recommendation:** remove, or give it a real consequence.

**9. Rotation policy**
- **Evidence:**
  - Rotate hard: +1.9 ± 1.5.
  - Ride the stars: −1.5 ± 1.4.
  - Interchange counts differ as described (tests).
- **Status:** WORKING (small).

**10. Key match-ups (Gate 1.12, merged in #96)**
- **Evidence:** 400 matches: the strong defender against a mismatch is about 0.8 of a goal from the forward, 4–6 points.
- **Test coverage:** behavioural (contests against the assigned defender; leverage over 30 seeds).
- **Status:** WORKING.

**11. The AI moving a defender onto a forward who is beating his man**
- **Status:** WORKING (code). `_ai_rematch` at breaks, for AI clubs.

### Match: moment cards

**12. Moment cards in aggregate**
- **Status:** WORKING BUT QUESTIONABLE. High. See C3.

**13. Hot-midfielder tag card**
- **Player promise:** "For the rest of the quarter he gets about half as much of the ball."
- **Actual:** the tag stays in `tactics.tag_id`, and the next break pre-fills it, so it lasts beyond the quarter unless the player changes it.
- **Status:** WORKING, with inaccurate text (Low). Its match value is that of the tag (C4).

### Match: player and team state

**14. Momentum**
- **Status:** UI / REPORT ONLY on `main`; WORKING in #102. Critical. See C2.

**15. Traits (all)**
- **Evidence:** removing every trait from one side −4.6 ± 1.5, including −4.7 clangers (Hothead).
- **Test coverage:** Hothead and Lockdown are tested for behaviour; the rest for their multipliers.
- **Status:** WORKING.

**16. Synergies**
- **Evidence:** 800 paired matches each (#98): Engine room +7, Intercept wall +6.4, Tall-small +5.7, Lockdown unit +5.6, Supply line +4.3, Running machine +4.2. On `main`, four of them were 0.7–4.2.
- **Status:** WORKING (on the stack); weaker on `main`.

**17. Team form**
- **Evidence:** full form +2.6 ± 1.4, worst form −2.6 ± 1.5.
- **Status:** WORKING.

**18. Player form ("In form / Out of form", Coaching)**
- **Player promise:** a "Form" section on Coaching. Most players will assume form affects play.
- **Actual:** `GameState.player_form()` compares the last three Player Ratings with the season's. Nothing reads it except that screen, and the engine has no player form.
- **Status:** UI / REPORT ONLY. Medium.
- **Recommendation:** make it real (design audit §4.7), or label it as a report.

**19. Morale**
- **Implementation path:** `ClubLife.form(p)` gives ±3% on every attribute through `MatchSim.fit()`. It also drives contract refusals and unhappiness events.
- **Evidence:** a whole side at morale 20: −6.0 ± 1.5; at 100: +2.4 ± 1.5.
- **Test coverage:** the sign of `ClubLife.form` only.
- **Status:** WORKING BUT QUESTIONABLE. Medium.
  - A 6-point match effect the player is never told exists.
  - The profile shows only "Mood: …", and selection only "Unhappy".

**20. Fatigue and legs**
- **Status:** WORKING. `fit()` scales attributes by energy; tests prove tiring and rotations.

**21. Home ground**
- **Status:** WORKING (code). A 3% stoppage edge (`home_edge`); the Grand Final venue rule is tested.

**22. Injuries**
- **Status:** WORKING. On `main` they are rolled after the siren; in #97 during the match, with the player replaced.

**23. Suspension (weekly event "suspend him")**
- **Status:** WORKING. Sets `rested`, and `Ratings.available` excludes him.

**24. Weekly event flags (sore, heavy week, recovery week)**
- **Status:** WORKING. They feed `Injuries.chance` and starting energy, and are cleared after the round.

**25. Selection, named side, bench**
- **Status:** WORKING. Behavioural tests prove a player left out does not play and a named side takes the field.

**26. Positional roles**
- **Status:** WORKING.
  - Wing (transition, stoppage share) and tagger (tag share) are real.
  - Descriptive labels such as "Inside midfielder" have no engine role and do not claim one.

### Coaching staff

**27. Coaching tactics (plan execution)**
- **Player promise:** a sharper tactical assistant makes the plan bite harder, both ways.
- **Evidence:** Attack corridor with execution at 1.15 against 1.0 gives −3.5 ± 1.5; at 0.89 against 1.0, −1.0 ± 1.5. Both "wrong", and inside the noise.
- **Test coverage:** multipliers only.
- **Status:** WORKING BUT QUESTIONABLE. Low. The effect exists in code but is not measurable in results.

**28. Coaching: teaching (match XP)**
- **Status:** WORKING. `xp_mult` 0.95–1.10 is read in `_grant_xp`; tests are behavioural on XP.

**29. Coaching: man-management**
- **Status:** WORKING (code). Softens the morale loss of dropped players, up to 40%.

**30. AI tactical reading**
- **Status:** UNVERIFIED. `tactics_read` changes when an AI club changes plan; the magnitude was not measured.

**31. Coach table for a live-match week**
- **Actual:** `prepare_interactive_match` simulates the round's other matches before `_refresh_coach_tactics()`. The table is a static variable and is not saved, so on the first live week after loading, those matches use an empty table: no tactics execution, and AI clubs do not pick plans.
- **Status:** PARTIALLY CONNECTED. Low.

### List building, development and progression

| # | System | Status | Evidence |
|---|---|---|---|
| 32 | Training plans | WORKING | Behavioural tests: attributes move under each plan; Manual banks XP |
| 33 | Development, potential, age | WORKING | `Prospects.age_league` applies `Potential.growth` league-wide |
| 34 | Reserves | WORKING | Reserves XP paid and tested |
| 35 | Draft scouting uncertainty | WORKING (honest) | Rival clubs only; you see true OVR and POT, and the code says so |
| 36 | Salary cap | WORKING | Re-signing, trades, free agency and AI keeping all check it |
| 37 | Contracts and trades | WORKING | `evaluate_trade`; morale under 40 refuses to re-sign |
| 38 | Board confidence and sacking | WORKING | |
| 39 | Difficulty | WORKING | Rival gain, trade margin and XP multiplier are all read |
| 40 | AI counter-plan code (`MatchSim.counter_to`) | DEAD | Left from the counter removed in #93; not player-facing |

## Hidden and dead systems found

- `MatchSim.counter_to`: the removed AI counter-plan logic, never called.
- `Matchup.STANDING_WORDS`: a constant never read.
- Never-called helpers:
  - `Draft.pick_number_in_round`, `Draft.is_complete_size`, `Draft.ai_lists`;
  - `MatchSim.average_energy`;
  - `Squad.best_on_ground`;
  - `Traits.needs_text`;
  - `CoachReport.verdict_for`;
  - `GameState.season_is_over`.
- The engine's `_run` (goal runs) existed alongside the display-only meter on `main`. It drives the "They have kicked 3 in a row" card only.

## Misleading UI

1. **The pre-bounce call box shows Balanced** while selection says your plan is another one (C1).
2. **The momentum meter on `main`** looks like a live mechanic and was not one (C2).
3. **The assistant's plan text** (`CoachReport.PLAN_EFFECTS`, in the half-time report) quotes numbers that do not match the engine:
   - Through stars says "+12% possessions"; the code gives ×1.2.
   - Defensive press says "−7% your conversion, −8% metres"; the code gives ×0.96 and ×0.95.
   - PlanFit scaling of the upside is not mentioned.
4. **"Form" on Coaching** implies a playing effect; there is none.
5. **Morale** has a real match effect that no screen mentions.
6. **The hot-midfielder card** says "for the rest of the quarter"; the tag carries into later quarters.
7. **Plan descriptions understate the counters.** "Squeezes it" is a 20+ point swing.

## Weak tests (false confidence)

- **Plan selection:** `run_roles_tests` ("Picking a plan sets the standing plan") and `run_career_ui_tests` check stored state only. The plan the engine plays was never checked (C1).
- **Momentum meter (`test_match_visual`, `main`):** "Ordinary play still ages the momentum meter" tested the display's arithmetic, not a mechanic. Replaced in #102.
- **Moment cards (`_test_moments`):** check that cards fire, are logged and add up. Nothing checks that a choice matters (C3).
- **Pep talks (`_test_pep_talks`):** check multipliers and energy. No outcome check.
- **Tag:** the tagged player's share falls, but no team-outcome check (C4).
- **Coaching tactics (`test_coach_effects`):** check `_pv` multipliers. No outcome check.
- **Morale (`test_club`):** checks the sign of `ClubLife.form`. No match check.
- **The matchday suite and silent skips:**
  - `run_matchday_tests` has 13 `if node != null:` guarded blocks, so checks disappear when a node is missing and the suite still passes.
  - Under CPU load it reported 243 checks instead of 284 with 0 failures.
  - `test_match_visual` loops over each match's events, so its count moved from 53 to 37 under the same load.
- **Crumb test (`_test_spoils_and_crumbs`):** its "mostly forwards" threshold of 55% sat on the true rate (54–56%), and it passed only on fixed seeds. Fixed in #98 by making Crumbers matter.

## Recommended repair order

1. **C1: the live-match plan is dropped at the first bounce.** A deceptive no-op of the game's biggest lever. Small fix plus a behavioural test.
2. **Merge #102 (momentum), or remove the meter.** Deceptive UI on `main`.
3. **C3: moment cards whose choices do not matter.** Seven decisions a match that change nothing.
4. **C4: tagging does not change the match.** A headline call whose effect is only cosmetic (design audit §4.1).
5. **Balanced is dominated, Through stars is a no-op, "Fire them up" is free.** Core plan and call balance.
6. **Player form: report or make it real; tell the player what morale does.** Honesty.
7. **Assistant plan text** that misstates numbers; the hot-card duration text.
8. **Weak tests:**
   - add behavioural checks for plan at the bounce, tag team effect, moment choices and morale;
   - make guarded matchday checks fail loudly instead of skipping.
9. **Low:** the coach table on a live week after loading; dead code; the unmeasurable coaching-tactics effect; AI tactical reading, unverified.

## Method notes

**Probes** (in `tests/_x_*.gd` during the audit, not committed):
- the live-match driver for C1;
- a paired lever probe (600 matches per lever, 19 levers, four shards);
- a plan-counter probe (400 per pair);
- a moment-policy probe (300 live matches per policy).

**Clubs:** 2027 active clubs, rotating home and away pairs; seeds 60000+, 70000+ and 80000+.

The home-versus-away lever in the paired probe was mis-built (both arms away) and is not reported. Home ground is classified from code.

## Appendix: repair sprint status

The findings above are kept as found. This appendix records each repair as it lands.

| Finding | Repair | Status |
|---|---|---|
| C1: standing plan dropped at the first bounce of a live match | The pre-bounce box (and Skip) read the plan the engine already holds for your side, which is your club plan, so Start without a change keeps it. Behavioural test `run_matchday_tests.gd::_plan_at_first_bounce` drives the live start and reads the engine's own quarter record (`tactics_history`). It fails on the old code (engine: balanced) and passes on the fix. | Fixed, branch `claude/fix-first-bounce-plan` (pending merge) |

