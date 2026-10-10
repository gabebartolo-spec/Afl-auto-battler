# M1 — Correctness & Low-Risk UX

Goal: fix things that are currently wrong, misleading, broken on mobile or capable of trapping the player.

## ARD-M1-001 — Football sanity audit
**Status:** `DONE`  
**Verified:** PR #82 (`05ad9354`) closed the final audit finding on main, 2026-09-28.  
**Priority:** `P0`  
**Autonomy:** `SUPERVISED`

### Implementation record (2026-09-28)
- **Diagnosis:** the MatchSim football sanity audit (300 matches) found these issues.
  - Stat-credit bugs:
    - goal assists were credited on every inside-50 entry (`goal_assists == inside50` in all 13,200 player-games; the team total was 0);
    - frees for were never credited to a player.
  - Six dead squad aggregates.
  - Over-restrictive gates:
    - carrying by zone (defenders cannot carry into the attacking half, forwards cannot help the exit);
    - only forwards and mids can shoot;
    - only defenders take one-percenters;
    - only mids and rucks win clearances.
- **Part 1, stat credits (branch `claude/football-sanity`):**
  - A goal assist is the last kick to a goalkicker, credited only when the goal is kicked and never to the scorer. It covers the set-shot moment too: the feeder, or the man who played on.
  - A free kick is paid to an opponent near the ball, drawn from a separate `stat_rng`, so match results are unchanged (200 seeded matches give an identical scoreline hash before and after).
  - Player Rating keeps an inside 50 at 4 and adds 2 per real goal assist and +1 per free for; the position-parity test holds.
  - Regression: `test_match_game.gd::_test_stat_credits`.
- **Part 2, gates (branch `claude/football-gates`):** hard role filters became role weights, like `PRESS_ZONES`. Lines that could always make the play keep full weight; the rest get a small share.
  - Carrying by zone (`CARRY_ROLES`): defenders can carry through the attacking half, and forwards can help the exit.
  - The shot (`SHOT_ROLES`): rucks 0.35, defenders 0.06.
  - Clearances (`CLEARANCE_ROLES`): forwards 0.12, defenders 0.10.
  - One-percenter credit (`ONE_PCT_ROLES`, drawn from `stat_rng`).
- **Effect (300 matches):**
  - Defenders: 0.56 inside 50s a game (was 0.33) and 0.10 goals (0.07).
  - Rucks: 0.32 goals (0.22) and 1.15 one-percenters (0.10).
  - Mids: 0.96 one-percenters (0.19). Forwards: 0.53 (0.07).
  - Defenders still take 72% of one-percenters. Forwards and defenders win the odd clearance.
  - Team totals are unchanged.
- **Balance (1,000 seeded matches, before v after):** mean score 86.9 v 86.5, goals per team 12.92 v 12.85, home win 59.6% v 61.3%, median margin 22 v 23. The calibration and league_balance suites pass.
- **Regression:** `test_match_game.gd::_test_no_role_gates`.
- **Balance follow-up (2026-09-28, re-measured on main after part 2 and ARD-M5-010):**
  - Disposal split over 150 seeded matches: mids 35.9%, defenders 35.0%, forwards 24.1%, rucks 4.9%.
  - Real AFL runs roughly mids 40%, defenders 34%, forwards 21%, rucks 5%.
  - The role weights in part 2 removed the defender excess the audit found (43%), so no further tuning.
  - Lowering defenders' carrying weight through the middle (1.0 to 0.5) moved it under a point (mids 36.4%, defenders 34.0%). It was not kept.
  - The back-third carrier stays weighted by intercept. Interceptor defenders winning the ball in their back half is football, and the defender core already rates intercept first.
- **Status note:** both parts are merged. The remaining findings are resolved or measured as within range, so nothing is open under this item. The verification record is ChatGPT's.

### Intent
Normal AFL actions should not become impossible because of simplistic role gates.

### Known trigger
Forwards were effectively excluded from normal tackling participation by a MID/DEF selection gate. Similar assumptions may exist elsewhere.

### Scope
Audit:
- tackling,
- possession access,
- target selection,
- stoppage participation,
- marking/defending,
- scoring involvement,
- rotations,
- emergency roles,
- watched vs simulated assumptions.

Classify findings:
- real sanity bug,
- over-restrictive model,
- balance question,
- no issue.

### Guardrails
- Diagnosis first.
- Do not flatten all positional identity.
- Do not "fix" football by giving every player identical event access.
- Prefer weighted tendencies over absolute exclusion.

### Done when
- Structural sanity bugs are listed with evidence.
- Authorised bugs have regression tests.
- No ordinary football action is accidentally impossible for a plausible player/context.

### Tests
- Targeted seeded scenarios by position.
- Regression tests for any discovered hard gate.
- Full suite after fixes.

---

## ARD-M1-002 — Ruck contest integrity & emergency ruck
**Status:** `DONE`  
**Merged:** PR #60 as `2e0c69d`; verified on main 2026-09-28 (full suite green).  
**Priority:** `P0`  
**Autonomy:** `SAFE` if local; otherwise `SUPERVISED`  
**Depends on:** ARD-M1-001

### Intent
A genuine ruck should contest when available; unrelated players must not casually become dominant rucks.

### Requirements
- Auto-selection strongly prefers genuine rucks for RUCK.
- If an available genuine selected ruck exists, use them.
- Emergency ruck only when no genuine option exists.
- Emergency ruck should suffer a sensible disadvantage.
- Hitout probability should use the actual contesting players' ruck attributes.
- Credit hitouts to the actual contestant.
- Rotations/injuries/bench swaps must not silently assign nonsense rucks.
- Later support user-nominated backup ruck under ARD-M5-005.

### Guardrails
If this requires rewriting selection/rotation architecture, stop and document why.

### Tests
- Genuine ruck vs genuine ruck.
- Ruck injury with nominated/eligible fallback.
- No-ruck emergency scenario.
- Regression: unrelated non-ruck cannot replace a healthy selected ruck.

### Outcome (2026-09-28)
Hit-outs were decided on `Squad.ruck` (the starting ruck, computed once) and credited to whoever stood in the ruck slot, so a bench midfielder covering a resting ruck was credited with hit-outs won on the ruck's rating: 51.5% of all hit-outs went to non-ruckmen over 1,000 seeded matches.

- `MatchSim._contestant`: the ruck-slot player if he is a ruckman (listed or second position); else a ruckman already on the ground (a ruck-forward); only with none there, the best tap man on the ground (emergency, on his own rating). The tap is decided on, and credited to, that player.
- Selection fills an empty ruck spot by ruck work, not overall (`Ratings.by_ruck`, in `select_22` and the `select_side` gap fill).
- Rotations stay plain two-way interchanges (a three-way re-slot broke the match view's lineup replay).

Balance (1,000 seeded matches, before/after): hit-outs to non-ruckmen 51.5% -> 6.1%; total score, margin, home win rate, team hit-outs and clearances identical (hit-outs are a stat; stoppage wins come from the squad contest). Regression: `tests/test_match_game.gd::_test_ruck_integrity`.

**Follow-up (balance-gated, not in this task):** `Squad.ruck`/`contest` - the side's stoppage strength - is still computed once from the starting 18, so it does not drop while the ruck rests or rise when a better ruck comes on. Refreshing it after interchanges would change results and needs its own balance run.

**Phone-playtest follow-up — hit-outs, hit-outs to advantage and clearances (2026-09-30):** The user observed an extreme hit-out advantage but only a narrow clearance win, including a match where Tim English was beaten far too heavily in the ruck. Treat this as a ruck-system audit plus a new stat requirement, not as a request to make clearances deterministic:
- Audit whether team and individual hit-out totals are within plausible AFL ranges.
- Audit the **distribution of ruck matchups** for feast-or-famine behaviour. A strong ruck may clearly win a matchup, but comparable AFL-quality rucks should not routinely produce absurd blowouts. Measure repeated seeded matchups between similarly rated, moderately mismatched and heavily mismatched rucks; inspect both mean share and variance.
- Audit whether ruck dominance has enough causal influence on stoppage/clearance outcomes. A large hit-out advantage should generally improve the chance of clearance dominance, while still allowing opposition mids to shark taps and win clearances.
- Trace the current authority path: hit-outs are presently recorded separately while stoppage wins come from the squad contest score, so verify whether the displayed hit-out result and the clearance engine can materially diverge without football justification.
- **Implement hit-outs to advantage (HTA) alongside ordinary hit-outs.** Every credited ruck contest may be a normal hit-out or a hit-out to advantage; retain total hit-outs as its own stat rather than replacing it. HTA should represent a tap that materially advantages a teammate at the stoppage and therefore be more strongly related to clearance probability than a raw hit-out, without guaranteeing the clearance.
- Track HTA at player and team level and expose it anywhere detailed ruck/match stats are shown; do not add it to already crowded primary decision surfaces just because it exists.
- Acceptance: regular hit-outs and HTA reconcile at player/team level; HTA never exceeds hit-outs; ruck quality affects both winning the tap and the chance the tap is useful; clearances correlate more meaningfully with HTA than with raw hit-outs; plausible midfield sharking and lost clearances still occur after won taps.
- Diagnose and measure before tuning. Use seeded simulations plus real-AFL reference ranges/relationships; preserve uncertainty rather than hard-linking each hit-out to a clearance.


---

## ARD-M1-003 — "Play through" shooter-bias fix
**Status:** `DONE`  
**Merged:** PR #48 as `66e3d53`; verified on main 2026-09-28 (full suite green).  
**Priority:** `P0`  
**Autonomy:** `SAFE`  
**Balance:** `BALANCE-GATED`

### Intent
"Play through" should mean get the ball into that player's hands, not turn a midfielder into a full-forward.

### Requirements
- Focus primarily affects possession-chain and transition involvement.
- Remove/restrict the generic focus bonus to shooter selection.
- Midfield/wing focus should primarily increase possessions, transition, metres gained and inside-50 delivery.
- Rebounding defenders should benefit mainly through exits/transition.
- Forwards may naturally receive more shots through their normal role.
- Keep the possession soft-cap that prevents absurd disposal totals.
- Clarify UI copy, e.g. "Favour this player in possession chains and attacking transition."

### Tests / balance
Compare focused vs unfocused:
- disposals,
- inside 50s,
- metres gained once available,
- shots/goals,
- positional distributions.

A focused midfielder should gain meaningful usage without an implausible goal spike.

### Outcome (2026-09-28, PR #48)
`MatchSim._tactic_player_mult` now applies the focus bonus to carrying/transition only, not shooter selection; the soft possession cap is unchanged. The coach box explains the call: "Favour this player in possession chains and attacking transition."

Balance, 1,000 seeded GEE v COL matches per condition (focused player's per-game line):

| Condition | Disposals (p90/max) | Inside 50s | Goals | Shots | Team margin |
|---|---|---|---|---|---|
| Unfocused MID | 28.5 (30/33) | 5.29 | 0.623 | 1.09 | +24.7 |
| Focus MID, old | 30.4 (32/34) | 5.65 | 0.702 | 1.25 | +24.6 |
| Focus MID, new | 30.4 (32/35) | 5.62 | 0.639 | 1.14 | +24.8 |
| Unfocused FWD | 9.0 (13/20) | 4.45 | 2.343 | 3.81 | +24.7 |
| Focus FWD, old | 10.0 (14/23) | 4.92 | 2.596 | 4.29 | +25.4 |
| Focus FWD, new | 10.0 (14/20) | 4.91 | 2.306 | 3.79 | +24.8 |

Usage and inside-50 gains are unchanged; the goal spike (+13% MID, +11% FWD) is gone. Metres gained was not yet available (ARD-M2-001). Regression: `tests/test_match_game.gd::_test_play_through`.

---

## ARD-M1-004 — Attacking ends swap every quarter
**Status:** `DONE`  
**Merged:** PR #49 as `dffcefe`; verified on main 2026-09-28 (full suite green).  
**Priority:** `P0`  
**Autonomy:** `SAFE`
**Outcome (2026-09-28, PR #49):** `PitchView` counts breaks and mirrors the ground's x axis in even periods (Q2, Q4, and each extra-time break), so every token, the ball, the camera and the goal squares follow; the director and MatchSim are untouched, so results cannot change. Regression: `tests/test_match_visual.gd::_test_ends_swap` (a full match: the period matches the quarter at every in-play event; home goal right in Q1/Q3, left in Q2/Q4).

### Intent
Teams must visibly attack opposite ends in alternating quarters.

### Acceptance
Q1 direction A → Q2 B → Q3 A → Q4 B.

The change must affect actual visual target direction, not only labels/commentary.

### Tests
- Deterministic four-quarter visual/state assertion.
- Goal/behind/kick-in direction remains correct after each swap.

---

## ARD-M1-005 — Wrong-way / bizarre long-kick sanity
**Status:** `DONE`  
**Merged:** PR #69 as `9e14165`; later match-flow regression coverage remains green on main.  
**Priority:** `P0`  
**Autonomy:** `SUPERVISED`

### Implementation record (2026-09-28, branch `claude/wrong-way-kicks`)
- **Engine:** a chain only ever moves the ball towards the attacking side's goal (`fp += gain * dir`, gain >= 0; tackles broken are forward too), so the engine cannot produce a wrong-way kick. Turnovers change the side, not the direction.
- **Instrumented:**
  - Director frame: every staged ball flight was checked against the attacking direction of the side in possession. 6 matches, 6,064 flights, 0 went back 30 m+.
  - Screen: the same check through PitchView, including the change of ends each quarter. 8 matches (4 seeds x your club home and away), 7,472 flights, 0 went back 30 m+, and the ends never changed with the ball in the air.
  - The live, quarter-by-quarter match appends to the same shared event list and director state, so it takes the same path.
- **Finding:** not reproducible on current main. The most likely original cause was the missing change of ends (ARD-M1-004, PR #49): before it, the second and fourth quarters showed each side attacking the end a watcher expects them to defend.
- **Regression guard:** `test_match_visual.gd::_test_no_wrong_way_kicks` covers a full match with your club at home and one away. No flight goes 30 m+ back towards the kicker's own goal on screen, and no change of ends happens mid-flight.
- **If it is seen again:** reopen with the save or seed and quarter. The test names the event it catches.

### Intent
Remove cases where the user's side appears to kick long deep into the opponent's attacking 50 without a football reason.

### Direction
Treat first as:
- attacking-direction bug,
- coordinate transform bug,
- target-selection bug,
- visualisation mapping bug.

Do not explain it away as intended tactics without evidence.

### Tests
Instrument/seed the offending situation and confirm the ball is targeting the correct attacking direction.

---

## ARD-M1-006 — Concussion: mandatory two-match absence
**Status:** `DONE`  
**Merged:** PR #51 as `2fa23c1`; verified on main 2026-09-28 (full suite green).  
**Priority:** `P0`  
**Autonomy:** `SAFE`
**Outcome (2026-09-28, PR #51):** `Injuries.roll_match` floors a concussion at `CONCUSSION_MIN` = 2 matches after the roll (no extra random draws, so every other injury rolls as before). Already true and verified: `injury_weeks` counts the club's matches; `Ratings.select_side` drops injured players for every club, named or not (AI parity); the absence is saved on the player. UI: "Concussion — 2 matches" / "Concussion — 1 match" on the player sheet, list, selection and matchup notes. Regression: `tests/test_injuries.gd` (every concussion in a season is 2+ matches; a named concussed player does not play; survives save/load; available only after two matches).

### Requirements
- Concussion means a minimum **2 matches unavailable**.
- No manual early return.
- AI follows the same rule.
- Existing injury-duration logic cannot shorten it below two.
- Longer absence can be supported later, but never shorter.
- UI: `Concussion — X matches`.
- Persist through save/load.

### Tests
- concussion created,
- availability false for two matches,
- manual selection rejected,
- countdown persists through save/load,
- return occurs only after required absence.

---

## ARD-M1-007 — Sim Round safety & quick-sim controls
**Status:** `PARTIAL` — original safety/quick-sim controls are DONE (#53); the director's new end-of-season skip performance follow-up below is TODO  
**Merged:** PR #53 as `4552e20`; verified on main 2026-09-28 (full suite green).  
**Priority:** `P0`  
**Autonomy:** `SAFE`
### Play round long-press discovery — missing onboarding explanation (director, 2026-10-07)
**Status:** `TODO`. **Priority:** `P1` — usability/onboarding defect, under this existing quick-sim owner and M8-004.

The director reports **nowhere explains how to long-press “Play round” to reach the skip-to-finals/season-skip controls**. Verify the current button label, available menu options and actual stopping point; do not teach obsolete “Sim round” wording or imply that skipping to the end of home-and-away simulates finals if it does not.

At the first relevant Hub encounter, explicitly explain **press and hold Play round to open the quick-sim options**, then explain the available options and where each stops. Demonstrate the interaction with a short contextual cue/walkthrough anchored to the actual button, with clear dismiss/skip and replayable Help. Make the hidden interaction discoverable beyond the one-time introduction through a restrained persistent cue or an accessible equivalent entry. Explain any desktop equivalent actually supported. Verify a fresh-save user can discover and perform the gesture and select the intended skip action without prior knowledge; tutorials must not activate simulation by themselves.

### Pre-timeskip survey — how the sim runs your club while you skip (director, 2026-10-09)
**Status:** `TODO`, unassigned. **Priority:** not set by the director. From the design bible brainstorm.

Before a timeskip the player tells the sim how to manage their club. The ethos is the bible's: the player knows the risk of playing hands-off, the risk is theirs to take, and the results are explained clearly and objectively afterwards. The game is designed for a player who plays most matches and sims the odd one.

**Open director question:** a full survey, or the simpler version in which the sim follows the instructions the club already holds (game plan, selection, roles) and asks only about what nothing else covers. Do not build either until the director chooses.

### Skip to end of season — excessive simulation/loading time (director, 2026-10-07)
**Status:** `TODO`. **Priority:** `P1` — high-priority performance/usability follow-up, coordinated with the existing §1.11 simulation/performance owner.

The director reports **“Skip to end of season” can take up to five minutes to simulate the season**, which is far too long. Reproduce the actual control and career state, platform/build, club count and number of remaining rounds; the five-minute duration is a user-observed report, not a benchmark already confirmed. **Reduce the actual wait/loading duration where possible**, not merely the appearance of the loading screen.

Measure the complete button-to-usable-result path and identify where time goes: match simulation, presentation/event work unnecessarily run for skipped matches, repeated UI rebuilding, aggregation/awards/AI management, saving and loading. Compare this season-batch path with the earlier per-round timing evidence; a fast single-round/start tap does not prove season skipping is acceptable. Reuse existing MatchSim/no-presentation optimisation work rather than build a second outcome engine.

Optimise demonstrated bottlenecks while preserving full football outcomes, newly required competition-wide Stats capture, player development/fatigue/injuries, records/awards, AI parity, seeded behaviour and save integrity. Preserve the skip control's real stopping boundaries (home-and-away/finals, sackings and required decisions); do not silently skip mandatory user actions, replace matches with fabricated scores or reduce scope to achieve a faster time. Keep progress truthful and the interface responsive, but progress text alone is not the fix.

Provide before/after elapsed time on the same representative saves/seeds and number of simulated rounds, including full-season and partial-season runs and desktop/phone measurements where available. Agree a practical measured target after establishing the baseline; report achieved improvement and remaining limits honestly. Add targeted reconciliation/regression checks for changed paths. Do not claim completion from a shorter animation or an unmeasured theoretical speedup.

**Outcome (2026-09-28, PR #53):** short press asks before simming your match (Sim round / Cancel / Don't ask again, re-enabled from Options). Holding Sim round (0.5 s, or right-click on desktop) opens Quick sim: this round, skip 4 rounds, or skip to the end of the home and away. Each option names where it lands. Batches stop at the end of the home and away (never into finals) and if you are sacked. The long press ignores the confirmation setting. Tests are in `run_career_ui_tests.gd`.

### Short press
Before sacrificing the user's only playable match that round, confirm:

`Simulate Round X? Your match will be simulated instead of played.`

Actions:
- Sim round
- Cancel
- Don't ask again

`Don't ask again` persists until re-enabled in:
`Options → Gameplay → Confirm before simming round`.

### Long press
Open a compact quick-sim menu:
- Sim this round
- Skip next 4 rounds
- Skip to end of home-and-away season
- Cancel

### Rules
- Show landing round where practical.
- Next 4 stops early if the H&A season ends.
- End-of-H&A **must stop before finals**.
- Never silently simulate finals.
- Genuine blocking decisions/events may interrupt a batch.
- Long press always opens its menu even when ordinary confirmation is disabled.

### Tests
- setting persistence,
- season-boundary stop,
- finals stop,
- current round advancement,
- no duplicate simulation,
- save/reload during preference state.

---


### Temporary playtest affordance — one-tap Sim to finals
**Status:** `TODO` — temporary testing convenience only; remove/defer once the post-season test cycle no longer needs it. _(2026-10-06: never built. `Sim round` and `Sim to Grand Final` on the Hub, week-by-week finals and the quick-sim path now cover the need; drop this unless the director still wants the button.)_

For the current post-season/off-season playtest cycle, expose a visible **Sim to finals** button on the regular-season Hub so the user can reach the finals/post-season quickly without long-pressing Quick sim or manually advancing rounds.

This should **reuse the existing quick-sim-to-end-of-home-and-away path** rather than create a second simulation route:
- one tap simulates the remaining home-and-away rounds;
- it must stop **before the first finals week**;
- it must still stop if the user is sacked or another existing hard stop occurs;
- it must preserve the same match results, injuries, awards, XP, board effects and save behaviour as the normal quick-sim path;
- after arriving at the finals, normal finals controls take over so the user can test the post-season flow.

Keep this deliberately lightweight and easy to delete. It is a **testing convenience, not a permanent UX commitment**. Mark the control/comment clearly enough that it can be removed once post-season testing is no longer the active focus.

Acceptance:
- from Round 1 or any later home-and-away round, one tap reaches the end of H&A without entering the finals;
- no duplicate sim logic is introduced;
- the resulting ladder/finals bracket is identical to using the existing `quick_sim(-1)` path;
- the temporary button can be removed later without touching simulation code.

## ARD-M1-008 — Full Ratings mobile layout
**Status:** `DONE`  
**Merged:** PR #54 as `5b93a40`; verified on main 2026-09-28 (full suite green).  
**Priority:** `P0`  
**Autonomy:** `SAFE`
**Outcome (2026-09-28, PR #54):** the draft details' Full ratings put wrapped labels in a 2-column grid, so at portrait widths each name collapsed to one letter per line. They now reuse the player profile's attribute rows (`PlayerSheet.attr_bar`: name, bar, rating on one line; one column under 520px, two above). The profile's own Attributes section was already correct. Regression: `tests/run_draft_ui_tests.gd` (on a portrait phone every attribute is one readable line; hiding the list leaves the details the same size); checked at 360x740.

### Intent
Attribute names must never collapse into one-character-per-line columns.

### Requirements
- Readable Attribute — Rating layout.
- Vertical scrolling where needed.
- Touch-friendly spacing.
- No giant blank areas.
- Expand/collapse cannot distort the modal.
- Validate narrow Android portrait.

### Tests
Manual/UI snapshot checks at ~360 / 390 / 412 px widths.

---

## ARD-M1-009 — Draft salary-cap completion guard
**Status:** `DONE`  
**Merged:** PR #68 as `c3f60e5`; verified on main.  
**Priority:** `P0`  
**Autonomy:** `SUPERVISED`

### Implementation record (2026-09-28, branch `claude/draft-cap-guard`)
- **Finding:** the cap guard (keep enough to fill every remaining place at the average price of the cheapest players still available) was already in place. A 100-draft probe (5 spending styles x 20 seeds, including "always the dearest", "no rucks until forced" and random, on the 2027 pool) found 0 stalls and 0 illegal lists. The remaining gaps were the explanation, older saves and a rival that could not pick.
- **Before:** the cap line read "CAP LEFT $X / $Y spent / $Z". A refusal said "Not enough salary cap..."; a rival with no legal pick silently halted the draft; and a save stuck without a legal pick had no way on.
- **After:** `Draft.usable_cap_for()` and `reserve_for()` spell out the rule (usable = cap left - reserve for the other places). The header reads "Cap left $X / Up to $Y this pick". A refusal says "This selection would leave too little salary cap to complete your list", with the cap left, the amount kept back and what is free. A rival with no legal pick passes. When you have no legal pick (only an older save can get there), My list explains why and offers Release on each pick: he returns to the pool, his salary comes off your books and you get an extra pick at the end. The cap is never breached. Released picks stay out of `drafted_by` across save and reload.
- **Tests:** `test_draft.gd::_test_cap_guard` (exact boundary allowed, $1 over refused with the reason, the last pick can use the whole cap, rivals all legal) and `_test_stuck_draft_recovery` (an old-save state spent on stars is stuck without ever breaching the cap; release, save and reload, then finish a full legal list). The draft, draft_ui, ai, save and intake suites pass.

### Intent
Prevent a draft from reaching an incomplete-list soft-lock without ever allowing an illegal cap breach.

### Rule
`usable cap room = current cap room - minimum salary needed to fill all remaining mandatory list spots`

A selection is illegal if it leaves insufficient cap room to complete the list.

### UX
Explain:
`This selection would leave insufficient cap space to complete your list.`

Show:
- actual cap room,
- amount effectively available after mandatory remaining spots.

### Existing bad saves
Provide a legal compliance path such as releasing/delisting eligible commitments. Do not magically permit cap breach.

### Tests
- exact-boundary cap cases,
- AI drafting,
- final mandatory pick,
- existing invalid save recovery,
- save/reload.

---

## ARD-M1-010 — Career starts in 2027 / chronology alignment
**Status:** `DONE`  
**Merged:** PR #45 as `2cf5223`; verified on main 2026-09-28 (full suite green).  
**Priority:** `P0`  
**Autonomy:** `SAFE`
**Outcome (2026-09-28, PR #45):** the dataset is the completed 2026 season (`GameDB.DATA_SEASON`); careers start in 2027 (`START_YEAR`, ages as at 1 March 2027). The League Draft pool includes the real 2026 draft class (725 players, lists of 40); every player's career line carries his real 2026 season; the first generated national class is 2027; 2026 coaching stints stay history (`Coaches.SEED_YEAR`); old 2026 saves keep their original behaviour. Regression: new chronology suite (28 checks) plus career, intake, coaches, expansion, awards and achievements suites parameterised on `START_YEAR`; a full-career trace ran League Draft 2027 -> season -> national draft -> rollover to 2028 with Tasmania.

### Intent
The playable career baseline should be 2027 so roster, draft and coaching chronology make sense.

### Scope
Verify:
- season start year,
- displayed year,
- draft/year rollover,
- coach records/appointments,
- age/career histories,
- fixtures/finals,
- generated-player chronology.

Do not blindly add +1 to UI labels if underlying state is still 2026.

### Tests
New career → Round 1 → season rollover → 2028.

---

## ARD-M1-011 — Event choices with obvious right answers
**Status:** `DONE`  
**Merged:** PR #44 as `f549755`; the eight weekly club-life events were audited and dominated/repeating choices were fixed.  
**Priority:** `P1`  
**Autonomy:** `SAFE` for clearly local events

### Intent
Events should present meaningful trade-offs rather than one objectively dominant choice.

### Guardrails
- Fix observed bad events first.
- Do not redesign the entire event system because one event is weak.
- Outcomes should remain concise and football/career relevant.

### Tests
For each changed event, demonstrate the trade-off and verify no choice dominates under all normal states.

---

