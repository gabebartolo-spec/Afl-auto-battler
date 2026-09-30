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
## Appendix: repair sprint status (moment cards)

**C3, moment cards: repaired.** The cause differed by card, so each was measured on its own. Each card got a random option in 600–900 live matches, and the net score change was measured over the window the call covers.

**"They've kicked 3 in a row" (surge / slow it down / ride it out):**
- **Why it did nothing:** the calls lasted 8 of about 180 possession chains, roughly two minutes. They also barely moved scoring at either end.
- **Fix:**
  - the calls last 15 chains ("the next ten minutes") and end at the break;
  - "Throw numbers at it" is more goals at both ends: your shots ×1.12, theirs ×1.25 when they get out, +3% of the ball, and heavier legs;
  - "Slow it down" is a quieter game at both ends: your shots ×0.90, theirs ×0.85, plus fewer turnovers and less ground gained.
- **After:** rest of the quarter, about 1,200 cards:

  | Call | Yours | Theirs | Net |
  |---|---|---|---|
  | Ride it out | 14.5 | 13.7 | +0.9 |
  | Throw numbers at it | 15.4 | 14.0 | +1.4 |
  | Slow it down | 13.8 | 12.9 | +1.0 |

  The shape differs and the nets are close, so the right call depends on the scoreboard. Before, the three differed by 0.3 ± 0.4.

**Late centre bounce (stack / flood / straight):**
- Stack now covers the next few bounces (12 chains); flood covers the rest of the quarter.
- About 30 cards each: stack +5.6, flood +0.2 (theirs 8.7 against 9.6), straight +0.4. The card is rare (0.1 a match).

**Set shot:** already situational; the aggregate policy test hid it. Points from the kick:
- better than even: shoot 2.69 (bomb 1.72, play on 1.86);
- a coin toss: shoot 2.75;
- a tough shot: bomb 2.32 (shoot 2.00);
- a long shot: play on 2.48 (small sample).

Classified as working.

**Tired star:** intentionally low-impact. Rest +0.97 against keep +0.52 (±0.3) over the rest of the quarter. A real but small call.

**Hot midfielder (tag):** see the tagging repair.

**Tests:** `test_match_game.gd::_test_moment_calls_matter`:
- a call lasts a passage and ends at the break;
- over 40 matches, surge gives more total scoring than riding it out, and slowing it down less;
- the best-value set-shot call is not always "shoot".

Branch `claude/moment-consequences` (pending merge).

## Appendix: repair sprint status (test harness)

**Weak tests: silent skips (repaired).**

**Reproduced:** Godot's `--frame-delay 50` simulates a loaded machine. Under it, matchday ran 290 of 293 checks and still passed. The match screen plays by elapsed time, so a busy machine changes how far a match gets between two checks.

**Fix (`tools/run_tests.sh`):**
- Every suite runs on a fixed frame clock (`--fixed-fps 60`). Under the same load, matchday ran all 293.
- Every suite has a check floor in `tests/expected_checks.txt`, taken from a full run under the fixed clock.
  - A suite that reports fewer checks fails: "checks went missing".
  - A suite with no floor fails until one is added.
- A check a suite skips on purpose prints `SKIP: <reason>`, and the summary counts it.
- The one matchday block that could skip without a failure (the key match-up Change button) now starts with a required check.

**Harness regression:** `tools/test_run_tests.sh` runs a real suite three ways (its floor passes; an impossible floor fails; no floor fails). The full run in CI calls it.

Branch `claude/test-floors` (pending merge; stacked on the first-bounce fix, whose checks its floors count).

## Appendix: repair sprint status (tagging, C4)

**Root cause.** A tag only moved possessions around: the tagged player's share went to his teammates, the tagger paid nothing, and nothing reached the stoppages. So it changed one player's stat line, not the match. The AI also tagged every second half whatever it had to do the job with.

**Repair (smallest change that makes it a trade):**
- **At the stoppages** (`MatchSim._tag_drag`), a tagged midfielder takes the lost share of his game (1 − tag share) out of his side's contest number.
  - Your tag costs you 40% of your tagger's own midfield game (`TAGGER_COST`).
  - The better the target, the more a tag takes; the better your tagger is as a midfielder, the more it costs.
- **Around the ground**, the tagger gets 60% of his usual share of the ball while he tags (`TAGGER_BALL`).
- **The AI follows the same rule.** It tags from half time only when it has a specialist tagger on the ground.
- **Copy:**
  - The hot-player card no longer says "for the rest of the quarter": the tag stays on until you call it off.
  - It says who does the job and what that costs.
  - The break box says so too when there is no specialist.

**Measured (paired, 600 matches, side 0 tags the opposition's best or worst midfielder all match; before is `main`):**

| Target | Tagger | Before, margin | After, margin |
|---|---|---|---|
| Best midfielder | any | −3.4 ± 2.1 (N 300) | −1.5 ± 1.5 |
| Best midfielder | specialist on the ground (n 67) | | **+6.9 ± 4.1** |
| Best midfielder | no specialist (n 533) | | **−2.5 ± 1.7** |
| Worst midfielder | specialist (n 67) | | −0.7 ± 4.5 |
| Worst midfielder | no specialist (n 533) | | **−4.1 ± 1.7** |

- **Target disposals:** −5.9 (best), −4.4 (worst).
- **Tagger disposals:** about −3.6 (before: about 0).
- **Clearance differential, tagging the worst:** −1.3 (before −0.3).

**Status: WORKING, a real trade.**
- Tagging their star with a specialist is worth close to a goal.
- Sending a good midfielder to tag, or tagging an ordinary player, costs you.
- Only about one side in nine has a specialist on the ground, so for most clubs a tag is usually the wrong call, and the screens say what it costs.

**Tests (`test_match_game`):**
- the contest edge by target and tagger;
- target and tagger disposals over 20 paired matches;
- the AI tags only with a specialist on the ground.
## Appendix: repair sprint status (plans, Through stars, plan copy)

**Root cause.**
- **Balanced dominated:** each plan's upside was worth far more than its costs against a Balanced side. Every plan beat Balanced, even with a list that didn't suit it.
- **Counters too big:** a counter was worth three to four goals (+22 to +24), bigger than anything else a coach controls.
- **Through stars a no-op:** it went through "82+" players, whom several clubs don't have. Moving the ball between good players changed nothing.
- **Copy stale:** the plan copy quoted percentages the code no longer used, in two descriptions per plan.

**Repair:**
- **Halved each plan's upside (`MatchSim.PLANS`); costs unchanged.**
  - An average list now roughly breaks even against Balanced.
  - A list that suits the plan gains; one that doesn't loses.
  - Counters halve with the upside.
- **Win contest's stoppage edge** was set a little higher than half (0.025), so it keeps a reason to exist.
- **Through stars goes through the side's best three** (`PlanFit.carriers`):
  - They see more of the ball, finish better and make fewer errors.
  - They are easier to read, so the pressure on the ball rises a little.
  - Its upside scales with how far the best three stand above the side's average (`PlanFit`, as for the other plans). The gap runs from 10 to 22 OVR across the 2027 clubs.
- **One description per plan** (`CoachReport.PLAN_SUMMARY`), written from the engine, with no percentages:
  - selection, coaching, the quarter break and the assistant's report all read it;
  - the old percentage text (`PLAN_EFFECTS`) is gone;
  - the Through stars fit line names your best three and how far they stand out;
  - StatGuide no longer says "82+ … 12%".

**Measured: plans against a Balanced side** (paired; gain for switching side 0 from Balanced; "suited" means fit ≥ 1.1, "unsuited" fit ≤ 0.9):

| Plan | Before (N 300) | After (N 600) | Suited list, after | Unsuited list, after |
|---|---|---|---|---|
| Defensive press | +9.4 ± 2.4 | +1.1 ± 1.5 | +4.1 | 0.0 |
| Attack corridor | +7.2 ± 2.5 | +0.1 ± 1.7 | +3.9 | −1.9 |
| Controlled tempo | +7.8 ± 2.2 | +1.1 ± 1.6 | −0.5 | +5.0 |
| Win contest | +6.8 ± 2.3 | +1.9 ± 1.6 | +2.6 | −0.5 |
| Through stars | +2.3 ± 2.2 | +1.0 ± 1.7 | +4.5 | +0.3 |

**Measured: counters** (gain for switching from Balanced to X, against a side on Y; before is the audit's 400-match figure):

| X v Y | Before | After (N 400–600) |
|---|---|---|
| Defensive press v Attack corridor | +23.8 | +11.9 ± 1.8 |
| Controlled tempo v Defensive press | +22.2 | +5.7 ± 1.6 |
| Attack corridor v Controlled tempo | +9.9 | +3.3 ± 2.2 |
| Attack corridor v Defensive press | −1.9 | −9.7 ± 2.0 |
| Defensive press v Controlled tempo | −4.9 | −7.9 ± 2.1 |
| Controlled tempo v Attack corridor | +3.0 | −4.8 ± 2.1 |
| Win contest v Attack corridor | | −1.6 ± 2.4 (N 300) |
| Through stars v Defensive press | | +0.4 ± 1.8 |

**Reading it:**
- **Balanced is the safe call.** Nothing beats it by much on average, and it can't be countered.
- **A plan pays when the list suits it,** or when it counters the opposition's plan.
  - A counter is now worth one to two goals, not three to four.
  - The wrong plan into a press or a controlled side costs about as much.
  - List fit moves a plan by about four points either way, the same order as a counter, so the list still matters.
- **Controlled tempo's fit split is not clear.**
  - Unsuited lists gained more in every run: +14.3 v +8.0 before, +5.0 v −0.5 after.
  - Each difference is within about 1.5 standard errors.
  - Recorded as open: its upside may be carried by something other than the kicks-and-marks carriers PlanFit names.

**Tests:**
- `test_match_game._test_through_stars`:
  - the best three;
  - their disposals and goals over 20 paired matches;
  - fit follows the gap.
- `test_coach_effects` reads the written plan value from the engine instead of a copy.
- `test_matchday` keeps the no-percentages check on the plan copy.

**Status:**
- Balanced: WORKING (the safe choice).
- Plans and counters: WORKING, sized.
- Through stars: WORKING.
- Plan copy: honest, single source.
