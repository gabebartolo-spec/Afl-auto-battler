# Aussie Rules Dynasties — Canonical Execution Roadmap

_Last reorganised: 2026-09-28_

This file is the **single source of truth** for the project roadmap. It is deliberately written so Claude or another coding agent can read it, select an authorised task, inspect the repo, implement it, validate it, and update the roadmap with minimal extra guidance.

This is **not** a chronological dump of ideas. Items are consolidated into systems, ordered by dependency and player value, and given implementation guardrails.

---

# 0. How to Use This Roadmap

## 0.1 Authority

When the user says **"add this to the roadmap"**, update this file.

Before adding a new item:

1. Search this file for the concept and its synonyms.
2. Check the **Duplicate / Merge Map** at the end.
3. Extend the existing task if it is the same system.
4. Create a new task only if it has a genuinely different player-facing purpose or implementation boundary.
5. Do not create duplicate tasks because the wording changed.

### Standing development authority — 2026-09-28

The user has granted Claude standing authority to action this roadmap as the project's primary development agent. A ready roadmap item does **not** require a fresh bespoke prompt or a separate per-PR permission check.

Claude may inspect, implement, test, balance-check, update the roadmap, open PRs and **merge clean completed work into `main`** under this standing authority.

Old task briefs, PR descriptions or planning notes that say **"do not merge"**, **"wait for review"**, or equivalent are superseded by this standing authority unless the user placed a newer, task-specific `HOLD` after 2026-09-28.

A dependency such as "Phase 4 starts after Phase 3 is merged" is a sequencing rule, not a user-approval gate. If Phase 3 is green, validated and otherwise ready, merge it and continue to Phase 4 rather than waiting for ceremonial approval.

Stop and ask the user only for a genuine unresolved player-experience/design decision, a failed/ambiguous balance gate, destructive data/save risk, unexplained failing tests, a merge conflict whose correct resolution is unclear, or a task that has expanded materially beyond its roadmap intent.

## 0.2 Status legend

Use exactly these statuses:

- `KNOWN BUG` — observed incorrect behaviour.
- `TODO` — accepted roadmap work, not started.
- `PARTIAL` — some foundation exists but the roadmap outcome is incomplete.
- `IN PROGRESS` — actively being implemented on a branch/PR.
- `VERIFY` — may already exist; inspect before changing.
- `DONE` — implemented, tested, merged and verified.
- `DEFERRED` — intentionally postponed.

Never mark an item `DONE` because code was written locally. It must be merged and verified.

## 0.3 Priority legend

- `P0` — correctness / soft-lock / broken UX / football-sanity problem.
- `P1` — high player value or foundational dependency.
- `P2` — meaningful depth once foundations are stable.
- `P3` — long-term flavour, polish or expansion.

## 0.4 Autonomy legend

- `SAFE` — routine enough to proceed autonomously once ready.
- `SUPERVISED` — inspect carefully for design/cross-system consequences. This is **not** an automatic approval gate: proceed when the roadmap already resolves the player-experience decision; stop only if a material design choice remains genuinely unresolved.
- `BALANCE-GATED` — may materially change results; proceed autonomously through implementation and measurement, but merge only when the required simulation evidence supports the intended effect without unacceptable side effects. Ambiguous or bad evidence is a stop condition.

## 0.5 Claude execution contract

For every authorised roadmap task:

1. **Read this file first.**
2. Inspect the current implementation before writing code. Do not assume the roadmap's historical note is still current.
3. Search for existing code, tests, docs and overlapping systems.
4. State the smallest implementation plan.
5. Implement only the authorised scope.
6. Do not opportunistically redesign adjacent systems.
7. Add targeted regression tests.
8. Run the relevant tests.
9. Run the full suite before handoff unless the environment prevents it.
10. For simulation-affecting work, run an appropriate seeded balance comparison.
11. For save-schema changes, prove backward compatibility.
12. For UI work, check narrow Android portrait layouts.
13. Update this roadmap's status/notes if the task is completed or materially changed.
14. Commit logically. Under the standing authority above, merge a clean PR once required tests/checks and any balance/save/UI gates pass. Do not wait for a second permission message.
15. Verify the merged result on `main`, then update the roadmap status/implementation record.
16. Handoff with exact files, commits, tests, behaviour before/after, balance evidence and remaining risks.

If the requested feature turns into a broad rewrite, **stop and report the dependency/risk instead of silently expanding scope**.

---

# 1. Global Engineering Guardrails

These apply to every milestone.

## 1.1 MatchSim is the football authority

- Watched matches and skipped/simulated matches must derive from the same football simulation authority.
- Presentation must not invent a second set of match outcomes.
- Visualisation may interpolate movement, but goals, disposals, frees, injuries, stats and decisions must reconcile with simulation state.
- Preserve deterministic seeded behaviour wherever the sim currently guarantees it.

## 1.2 Stats must come from football events

Do not generate player-facing statistics independently merely to make box scores look realistic.

A stat should be credited because the corresponding football event occurred:
- inside 50 from an actual entry,
- metres gained from actual territory advanced,
- effective disposal from the disposal outcome,
- intercept possession from an actual interception,
- score involvement from an actual scoring chain,
- CBA from actual centre-bounce participation.

Avoid double-crediting and avoid "random stat garnish".

## 1.3 Football roles are tendencies, not hard rails

- Position should strongly influence where/how a player participates.
- Normal AFL actions should remain structurally possible unless the laws or match context genuinely prevent them.
- Do not solve role identity by making ordinary actions impossible for whole position groups.
- If a role gate creates absurd behaviour, treat it as a sanity bug first and a balance problem second.

## 1.4 AI parity

Unless a feature is explicitly player-only UX:
- AI clubs obey the same availability, salary-cap, suspension, concussion, selection and match rules.
- AI should be able to make equivalent tactical choices.
- Never give the player a rule loophole unavailable to AI, or vice versa, without documenting why.

## 1.5 Save compatibility

For persistent-state changes:
- Existing saves must load.
- New keys require safe defaults.
- Do not rename/remove persisted keys without migration.
- Add/load an older save fixture where practical.
- Perform save → reload → continue-season roundtrip testing.
- Never silently overwrite an existing career when creating a new one.

## 1.6 Mobile-first UI

Primary target is Android portrait.

Minimum validation:
- 360px-ish narrow portrait.
- 390px-ish common portrait.
- 412px-ish wider portrait.

Rules:
- no one-character-per-line label wrapping,
- no critical clipped controls,
- no accidental horizontal scrolling,
- touch targets should be comfortably tappable,
- critical state must not rely on hover,
- avoid dense tables on primary screens,
- detailed numbers belong in drill-down/stat screens.

## 1.7 No "number vomit"

Primary screens should answer:
- what is happening,
- what matters,
- what can I do.

Deep analytics can exist in secondary screens. Do not turn coaching, reports or matchday UI into debug dashboards.

## 1.8 Australian football language

Use natural AFL terminology in player-facing text.

Avoid exposing implementation jargon such as `DEF`, `MID`, `FWD`, internal enum names, raw multipliers or diagnostic labels.

Use Australian spelling: `metres`, not `meters`.

## 1.9 Current AFL rules

If a task depends on a contemporary AFL law/rule:
- verify the current rule before implementing it where network access is available,
- record the rule assumption in code/test comments where it is easy to misunderstand,
- do not rely on vague memory for changed rules.

The game's intended starting season is **2027**, so rule/data assumptions should make sense for that baseline.

## 1.10 Balance gate

Any change that can materially alter wins, scoring, player production, development, availability or tactical strength is `BALANCE-GATED`.

At minimum:
- use deterministic seeds,
- compare before vs after,
- use the existing sim harness where possible,
- run enough matches for the direction of the effect to stabilise (prefer 1,000+ per condition when cheap),
- inspect mean and distribution, not only one showcase match,
- check positional/archetype side effects,
- check strong-team vs weak-team behaviour,
- check AI and player teams use the same rules.

Do not tune purely until one screenshot "looks right".

---

# 2. Roadmap Execution Order

The sequence below is deliberate. Later milestones depend on cleaner football events, statistics and selection semantics from earlier milestones.

| Milestone | Purpose | Why it comes here |
|---|---|---|
| **M1 — Correctness & Low-Risk UX** | Remove known sanity bugs, soft-locks and misleading UI | Stabilises the existing game before adding more systems |
| **M2 — Match Event & Stat Foundation** | Make the sim record the football information later features need | Reports, roles, scouting and tactics need trustworthy event data |
| **M3 — AFL Rules & Match Authenticity** | Expand scoring, marking, pressure, restarts and presentation | Builds richer football on top of reliable event semantics |
| **M4 — Tactical Matchday Layer** | Meaningful coaching decisions, match-ups and game-state AI | Requires M2/M3 context to avoid arbitrary buffs |
| **M5 — Selection, Roles & Development** | Make list/position/development decisions deeper and more intuitive | Benefits from corrected roles and richer match stats |
| **M6 — Coaching, Board & List Management** | Strengthen the management game outside matches | Best added once weekly football loop is trustworthy |
| **M7 — Competition Identity & Long Careers** | Rivalries, history, records, weather, venues and milestones | Long-save flavour relies on stable career/stat data |
| **M8 — Release Polish & Long-Save QA** | Onboarding, accessibility, performance and 100-year robustness | Finalises systems after core design settles |

Do not rigidly wait for an entire milestone to finish before touching the next one. Dependencies matter more than labels. A self-contained later task may proceed if its prerequisites are already satisfied.

---

# M1 — Correctness & Low-Risk UX

Goal: fix things that are currently wrong, misleading, broken on mobile or capable of trapping the player.

## ARD-M1-001 — Football sanity audit
**Status:** `PARTIAL`  
**Priority:** `P0`  
**Autonomy:** `SUPERVISED`

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
**Status:** `KNOWN BUG`  
**Priority:** `P0`  
**Autonomy:** `SUPERVISED`

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
**Status:** `DONE`  
**Merged:** PR #53 as `4552e20`; verified on main 2026-09-28 (full suite green).  
**Priority:** `P0`  
**Autonomy:** `SAFE`
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
**Status:** `KNOWN BUG`  
**Priority:** `P0`  
**Autonomy:** `SUPERVISED`

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
**Status:** `TODO`  
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

# M2 — Match Event & Stat Foundation

Goal: create trustworthy football data that later coaching, scouting, reports and role systems can use.

## ARD-M2-001 — Metres gained
**Status:** `DONE`  
**Priority:** `P1`  
**Autonomy:** `SAFE`
**Merged:** PR #55 as `43b344a`; verified on main 2026-09-28 (full suite green).  
**Outcome (2026-09-28, PR #55, with M2-002):** player and team `metres_gained` are the ball's real forward movement in each possession (the disposal's gain, or ground won breaking a tackle); backwards movement earns nothing and nothing is counted twice. Shown in a player's detailed line in Match stats. No random draws added, so results are unchanged. There is no season aggregation because the game has no generic season player-stat store (only career games and goals); add it when one exists. Known gap: about 3,200 m a team against about 5,500 m broadcast, because field position moves only about 10 m a disposal (engine territory model, balance-gated). Regression: `test_match_game.gd::_test_metres_and_efficiency` (players reconcile with the team; no negative metres).

### Intent
The sim already moves the ball in metres; retain the meaningful territory contribution as a player/team stat.

### Requirements
- Credit actual forward territory advanced by the responsible player.
- Backward movement must not become positive metres gained.
- Avoid double-counting the same movement as both carry and disposal unless the model explicitly represents both.
- Aggregate player → team → match → season using existing stat plumbing where practical.
- Display in detailed stats, not necessarily every primary screen.

### Tests
- forward kick,
- backward kick,
- handball/carry where applicable,
- turnover chain,
- team total reconciliation,
- season aggregation.

---

## ARD-M2-002 — Effective disposals / Disposal Efficiency %
**Status:** `DONE`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`
**Merged:** PR #55 as `43b344a`; verified on main 2026-09-28 (full suite green).  
**Outcome (2026-09-28, PR #55):** `effective_disposals` per player and team; `MatchSim.disposal_efficiency()` gives the percentage (0 when there are no disposals). Effective means his side has the ball next, or his inside-50 entry is not rebounded. Ineffective means he is caught holding it, the chain dies in a stoppage, or the entry is rebounded. By line: DEF 89%, RUCK 88%, MID 82%, FWD 71%. Known gap: team DE is about 84% against about 73% real, because a non-free clanger does not turn the ball over in the engine. It isn't counted as ineffective (that would be pretending). Fixing it is engine turnover work (balance-gated; see the MatchSim audit). Regression: `test_match_game.gd::_test_metres_and_efficiency` (effective never exceeds disposals; forwards are less efficient than defenders; formula).

### Intent
A disposal should be judged from its actual outcome.

### Data
- `effective_disposals`
- `disposal_efficiency = effective_disposals / disposals`

### Effective examples
- successful teammate receipt,
- retained possession,
- successful marked kick,
- clearly productive controlled disposal.

### Ineffective examples
- direct turnover,
- intercepted disposal,
- clanger attributable to that disposal,
- obvious failed pass.

### Guardrails
Do not define "everything except clangers" as effective if the event model knows more.

### Tests
Deterministic examples for each classification; denominator zero handling; player/team aggregation.

---

## ARD-M2-003 — Centre bounce attendances (CBA / CBA%)
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `SAFE`

### Intent
Track who actually attends centre bounces so role usage is visible and auditable.

### Requirements
- Credit attendance from actual centre-bounce participants.
- CBA% denominator is team centre bounces, not generic stoppages.
- Useful in detailed player stats and role sanity checks.
- Do not infer CBA from listed position.

### Tests
- normal midfield mix,
- rotations,
- injury/substitution,
- wing does not accidentally receive inside-mid CBAs unless actually used there.

---

## ARD-M2-004 — Intercept possessions
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `SAFE`

Track actual intercept possessions separately from an `intercept` attribute.

Include:
- intercept mark,
- intercept ground possession where represented.

Avoid crediting generic rebounds as intercepts unless possession was actually won from the opposition.

---

## ARD-M2-005 — Contested vs uncontested marks
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

### Intent
Differentiate aerial contest players from loose/intercept marking.

### Requirements
Mark context must determine classification. Do not randomly label existing marks after the fact.

This feeds:
- key forward/defender identity,
- match ratings,
- scouting,
- eventual speccies.

---

## ARD-M2-006 — Pressure acts
**Status:** `DONE`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`
**Balance:** `BALANCE-GATED`
**Merged:** PR #47 as `307b68b`; verified on main 2026-09-28 (full suite green).  
**Outcome (2026-09-28, PR #47):** zonal pressure (forwards and mids press the opposition's back third, mids and rucks the middle, defenders and mids their own back third) with one roll per disposal: a tackle, a rushed disposal (a pressure act whose turnover chance scales with presser against carrier), or nothing. Any line can tackle. Pressure acts and pressure wins are recorded per player and team; the team Pressure rating (0-100) is acts plus wins over the opposition's disposals (p10 55, p50 60, p90 66). Calibration: every team stat within 6% of real 2026; tackles by line FWD 2.29 (real 1.98), MID 3.46 (3.33), DEF 2.02 (1.80), RUCK 2.48 (2.64). OVR re-measured (+20 per attribute, 2,500 matches a line): the forward core is now goalkicking .30, pressure .20, marking .15, accuracy .15, creating .12, carry .08, and midfield adds pressure .10. Pressure small forwards rise (Greene 72 to 79) and stay-at-home key forwards ease (McKay 72 to 66). UI: pressure rows in Match stats and full time; Player Rating counts tackles 2 and pressure acts 1. Regression: new `pressure` suite (21 checks); ratings, potential and matchday updated.

### Intent
Tackles alone should not represent defensive pressure.

Credit meaningful pressure actions from actual event context where practical.

Particularly important for small/general forwards.

### Guardrails
Do not spam a pressure stat for every nearby player every disposal. Define a clear football event/threshold.

---

## ARD-M2-007 — Score involvements
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

### Intent
Recognise players who materially participate in scoring chains before the final kick.

### Guardrails
- Define a bounded chain window.
- Do not award the entire team an involvement.
- Goals and goal assists remain distinct stats.
- Score involvement should complement, not duplicate, assists.

---

## ARD-M2-008 — Score-source tracking
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

Classify scores by meaningful origin such as:
- turnover,
- stoppage/clearance,
- kick-in,
- other/general play where needed.

This is primarily a **coaching/scouting data source**, not another dashboard.

Later reporting should be able to say:
- "They hurt us from turnover."
- "We generated scores from stoppage."
without guessing.

---

## ARD-M2-009 — Goal accuracy by shot context
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

Track enough context to analyse:
- set shot vs open play,
- broad distance/angle bands if the simulation genuinely models them.

Do not create fake precision from coordinates the simulation does not meaningfully use.

---

# M3 — AFL Rules & Match Authenticity

Goal: make the event stream and visualisation look and behave like Australian football.

## ARD-M3-001 — Set shots vs open-play scoring
**Status:** `PARTIAL / KNOWN PRESENTATION BUG`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`
**Depends on:** M2 shot/event context
**Current state (2026-09-28):** the open-play freeze is fixed and merged (PR #50 as `d1757f5`: scores carry `set_shot`; open-play shots are kicked on the run while forwards crumb). The scoring-model part is not started.

### Current issue
MatchSim can score without a mark, but the visualisation routes every goal/behind through staged shot presentation, making open-play shots look like set shots.

### Requirements
**Set shot**
- triggered from genuine mark/free/set-shot context,
- deliberate hold/staging is acceptable,
- surrounding players largely hold structure.

**Open play**
- no global pause,
- shooter kicks as part of continuous movement,
- defenders keep chasing/pressuring,
- forwards keep leading/crumbing,
- nearby players continue football movement.

### Later variety
running shots, snaps, crumbs, soccered goals, dribble kicks, long bombs.

### Tests
Seeded marked goal vs unmarked goal. Only the marked/set-shot path may trigger the staged hold.

---

## ARD-M3-002 — Forward archetype scoring
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`
**Depends on:** ARD-M3-001, marking context

### Intent
Empower different forward types naturally.

- Key forwards: more chances from leads, aerial contests and set shots.
- Small/general forwards: more chances from crumbs, loose-ball wins, snaps, pressure-created and running opportunities.
- Either archetype can still score in the other way.
- Attributes/traits drive tendencies; listed position is not an absolute script.

### Balance checks
- total goals by archetype,
- set/open-play share,
- efficiency,
- shot volume,
- marking dominance,
- volatility,
- mixed forward line vs one-dimensional forward line.

---

## ARD-M3-003 — Spoils across the ground
**Status:** `PARTIAL`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

### Current foundation
Forward-50 resolution has a partial spoil modifier but no complete spoil event/stat model.

### Requirements
- Real marking contest outcome.
- Defender ability/positioning/traits influence spoil.
- Spoil normally produces a loose/ground-ball situation, not automatic defender possession.
- Track spoils in detailed stats if reliable.
- No need to spam commentary.

---

## ARD-M3-004 — Smothers
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

- Rare close-pressure/block-kick event.
- Pressure/positioning/defensive attributes influence success.
- Successful smother creates disrupted/loose play.
- Track if useful.
- No routine commentary spam.
- Balance frequency carefully.

---

## ARD-M3-005 — Speccies
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

- Rare spectacular mark outcome only from a genuine contested marking situation.
- Marking/aerial quality and traits can increase chance.
- Statistically a mark unless a dedicated stat later adds value.
- Presentation flourish, not a giant gameplay buff.

---

## ARD-M3-006 — Boundary rules / OOB / out on full / last disposal
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

### Requirements
Implement:
- out of bounds,
- out on the full,
- boundary throw-ins,
- correct field-position restart.

For the intended rules baseline:
- between the two 50m arcs, a kick/handball that goes out under the current AFL last-disposal rule gives the opposition a free from where it crossed,
- inside 50 arcs, ordinary OOB remains a throw-in subject to other laws,
- out on full remains a free,
- contested/unclear exits can still be throw-ins.

### Guardrail
Verify contemporary AFL law before coding.

### Tests
Every boundary type plus direction/end changes.

---

## ARD-M3-007 — Contextual free kicks
**Status:** `PARTIAL`  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

### Current foundation
Free kicks exist, but are heavily simplified and largely produced as a generic clanger outcome.

### Direction
Add real football causes where the event model supports them, e.g.:
- holding the ball,
- high contact,
- other sensible infringements.

### Guardrails
- Do not create a huge umpiring simulator.
- Causes should emerge from event context.
- Player discipline can influence risk but should not overwhelm football actions.
- Free rates need league-level sanity checks.

---

## ARD-M3-008 — 50 metre penalties
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `BALANCE-GATED`

- Trigger from relevant post-mark/free infringements such as encroachment, dissent or delay.
- Advance ball 50m toward goal, respecting field limits.
- Can turn an ordinary free into a scoring chance.
- Player discipline may influence risk.
- AI same rules.
- Visualise ball advancement clearly.
- Track conceded 50s if useful.

---

## ARD-M3-009 — Kick-ins as real football
**Status:** `PARTIAL`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

### Preserve
A behind restarts from the defending goal-square area and must not become a centre bounce.

### Expand
- Treat kick-ins as real possession sequences where appropriate.
- Identify/nominated primary kick-in player.
- Sometimes play on; sometimes use safer exit.
- Rebounding defenders should gain meaningful value.
- Stats should follow actual AFL-style possession accounting used by the game.

### Tests
Behind → kick-in → exit; no phantom stoppage; correct end/direction after quarter changes.

---

## ARD-M3-010 — In-match injuries visibly affect play
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

- Player goes down / leaves field where appropriate.
- Bench/rotation structure responds.
- Availability after match reconciles with injury record.
- Do not let visualisation claim an injury that MatchSim/save state does not record.

---

## ARD-M3-011 — MRO / suspensions
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `BALANCE-GATED`

- Reportable incidents should come from plausible match events where possible.
- Outcomes: no action / warning or fine / suspension.
- Suspended players unavailable for specified matches.
- Discipline/aggression/Hothead-like tendencies can influence risk, capped.
- AI same rules.
- Post-round MRO summary.
- Tribunal/appeal system deferred until justified.

---

# M4 — Tactical Matchday Layer

Goal: watching a match should involve genuine coaching choices without becoming manual-control football.

## ARD-M4-001 — At least one meaningful live decision per quarter
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`
**Depends on:** reliable match context from M2/M3

### Target
Typically 1–2 decisions per quarter, with at least one in a normal watched quarter.

### Examples
- shoot vs pass,
- ambitious back-half kick vs safe outlet,
- flood/spare behind the ball,
- keep attacking vs slow tempo,
- play on vs take time off clock,
- extra number at stoppage,
- keep tired/star player on vs rotate.

### Rules
- Trigger from actual match state.
- Real trade-offs, not trivia/pop quizzes.
- Avoid obviously dominant choices.
- Avoid giant hidden bonuses.
- Use actual players/context where possible.
- AI makes equivalent decisions.
- Record enough context for post-match explanation.

### Tests
Trigger frequency, choice diversity, no repeated spam, deterministic resolution under seed, no match-state corruption after a moment.

---

## ARD-M4-002 — Defensive / forward match-ups
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

- Let user assign a defender to a dangerous forward.
- Opposition AI can make equivalent assignments.
- Defender can follow the player or protect space depending on instruction.
- Match-up should matter through contest context, not a flat arbitrary debuff.

### Guardrails
Do not create 18 individual matchup controls. Focus on meaningful key assignments.

---

## ARD-M4-003 — Tagging has an attacking cost
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

A hard tag may reduce the target's influence, but the tagger should generally sacrifice some attacking involvement/output.

No free "debuff their best player" button.

Check:
- target disposals/influence,
- tagger disposals/influence,
- team-level net effect,
- role/trait differences.

---

## ARD-M4-004 — Structural coaching choices
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `BALANCE-GATED`

Support concepts such as:
- spare/loose player behind the ball,
- extra number at stoppage,
- seventh-defender-type positioning.

Do not literally create an extra player. Moving numbers to one area must reduce presence elsewhere.

Prefer situational/live choices before adding permanent micromanagement.

---

## ARD-M4-005 — Simple player role instructions
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `BALANCE-GATED`

Keep small and readable:
- defender: attacking / balanced / lockdown,
- midfielder: inside / balanced / outside,
- forward: deep / balanced / high.

Extend the existing role/selection model; do not build a parallel tactical engine.

---

## ARD-M4-006 — Game-state tactical AI
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

AI should react to:
- score margin,
- time remaining,
- quarter,
- available personnel,
- opposition tactic where sensible.

Examples:
- behind late → more aggressive,
- protecting narrow lead → safer possession, boundary, spare behind ball,
- final-quarter urgency differs from Q1.

AI must not play Q4 down 22 exactly like 0–0 in Q1.

---

## ARD-M4-007 — Late-game tempo / time management
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `BALANCE-GATED`

Represent:
- taking time off clock,
- safer possession,
- boundary use,
- play-on urgency when behind.

Integrate with ARD-M4-001 and ARD-M4-006 instead of creating a separate hidden bonus system.

---

## ARD-M4-008 — Opponent preparation / scouting
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `SAFE` once M2 data exists

Before the match, show only 3–4 high-signal observations such as:
- strong at stoppage,
- scores heavily from turnover,
- dangerous key forwards,
- vulnerable defending transition.

### Guardrails
- Derived from actual team data/tendencies.
- Plain English first.
- Do not tell the user the "correct" tactical answer.
- No giant analytics dashboard.

---

## ARD-M4-009 — Match report / "why we won or lost"
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `SAFE` once M2 data exists

Create **one** concise coaching report, not a compact report plus a giant full-report dump.

### Include
- result/game state once,
- 2–3 sentence match read,
- 2–3 best performers,
- 1–2 needing a lift,
- 1–2 opposition dangers if relevant,
- concise tactical/coaching insight,
- 3–5 explanatory stats at most,
- 1–2 causal "why" statements from actual sim data.

### Remove
- duplicate scores,
- quarter-by-quarter stat dumps,
- raw diagnostics,
- redundant full-report toggle,
- irrelevant opposition strategy text.

Detailed stats live in the Stats screen.

---

## ARD-M4-010 — In-match Momentum
**Status:** `PARTIAL`  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

### Current foundation
A presentation-only momentum value exists.

### Goal
Make Momentum a small, capped, reversible football mechanic.

Potential influence:
- composure,
- confidence,
- narrow situational outcomes.

### Guardrails
- no large raw attribute boosts,
- no runaway snowball,
- comeback remains possible,
- meter must clearly be labelled **Momentum**.

### Balance
Compare:
- neutral vs high momentum,
- comeback frequency,
- win rates,
- strong-team dominance,
- interaction with season form.

---

## ARD-M4-011 — Team Form / season momentum
**Status:** `PARTIAL`  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

Consolidates existing team form with the requested winning-streak momentum concept.

- Consecutive wins can build a modest longer-term effect.
- Losses erode it.
- Diminishing, capped, reversible.
- Do not add a second duplicate "season momentum" modifier on top of existing form.
- Match Momentum + Team Form must not stack aggressively.

---

# M5 — Selection, Roles & Development

Goal: make player deployment intuitive, footy-authentic and consequential.

## ARD-M5-001 — Matchday squad: 18 + 5 interchange
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

Current known structure uses 18 + 4.

Migrate to:
- 18 on ground,
- 5 interchange,
- 23 total,
- no substitute role.

Audit:
- manual selection,
- auto/AI selection,
- rotations,
- XP/development,
- match participation,
- injuries,
- stats,
- played-game tracking,
- UI,
- tests,
- every hard-coded 22/4 assumption.

---

## ARD-M5-002 — Visual oval/team-shape selection
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`
**Depends on:** stable squad-size/role semantics

Primary team selection should be a recognisable AFL field shape:
- backs,
- half-backs,
- wings,
- centre/on-ballers,
- half-forwards,
- forwards,
- ruck,
- interchange.

### Interaction
- tap position → choose player,
- move/swap players intuitively,
- show empty/unavailable/out-of-position state,
- bench on same screen,
- Auto-pick retained,
- full list becomes secondary,
- player profile accessible without losing selection state.

Mobile portrait first.

---

## ARD-M5-003 — Secondary-position learning / retraining
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

This is the canonical item for the user's previously requested secondary-position training/retraining.

- Sustained use/training at a plausible secondary role can improve suitability.
- Respect body/skill/archetype plausibility.
- Do not allow universal retraining.
- Progress should be visible but low-admin.
- Position learning should affect selection fit, not magically rewrite unrelated attributes.

---

## ARD-M5-004 — Training multi-select
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `SAFE`

- Press/hold player to enter multi-select.
- Tap others to select/deselect.
- Apply the same training plan to arbitrary selected players.
- Clear selection state/count.
- Normal single-tap unchanged outside multi-select.
- Mobile touch behaviour must be reliable.

---

## ARD-M5-005 — Emergency / depth role designations
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

Allow simple contingencies such as:
- backup ruck,
- spare defender,
- other genuinely useful emergency assignment.

Purpose: prevent MatchSim from improvising absurd replacements.

Keep the list short; do not create a depth-chart spreadsheet.

---

## ARD-M5-006 — Passive reserves/VFL development
**Status:** `PARTIAL / TODO`  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

Players omitted from the senior side should still develop at a reduced rate.

- No playable reserves competition.
- No reserves fixture/tactics/selection screen.
- Reuse existing XP/development systems.
- Senior AFL remains the best development environment.
- Availability rules still apply.

Balance omitted-player growth against selected senior players over multi-season sims.

---

## ARD-M5-007 — Selection continuity / cohesion
**Status:** `TODO`  
**Priority:** `P3`  
**Autonomy:** `BALANCE-GATED`

Consider a small capped benefit for stable line-ups/combinations, especially defensive units.

Guardrails:
- distinct from recent-result Team Form,
- do not punish injuries excessively,
- no runaway "never change your side" incentive.

---

## ARD-M5-008 — Role-aware performance & form
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`
**Depends on:** M2 stats

A defender can play well with 11 disposals; an inside mid probably cannot.

Use role expectations for:
- match ratings,
- player form,
- best-player recognition,
- coaching feedback,
- later coaches' votes.

Avoid disposal-count bias.

---

## ARD-M5-009 — Player role/archetype identity sanity
**Status:** `PARTIAL`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

Role labels should match actual football identity.

Known sanity examples:
- George Wardlaw should not read like a wing when his game is heavily contested/on-ball.
- Harvey Langford should not be forced into "inside mid" because of crude weighting if his usage is much more tall/goal-scoring wing.

### Direction
Validate labels against real role evidence and in-game usage.

Do not manually patch only famous names if the classifier itself is wrong.

---

## ARD-M5-010 — OVR should predict football strength
**Status:** `PARTIAL / KNOWN ISSUE`  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

Overall rating should be meaningfully aligned with what Squad/MatchSim reward.

### Guardrails
- Diagnose measurement first.
- Prefer fixing Ratings/OVR interpretation before changing MatchSim merely to force correlation.
- Validate impacts on salary, POT, value, awards, selection and drafting.
- Preserve role-specific value; one generic OVR should not erase archetypes.

---

# M6 — Coaching, Board & List Management

Goal: strengthen the management loop around the football.

## ARD-M6-001 — Coaching hub
**Status:** `PARTIAL`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

Bottom navigation target:
`Training · My list · Coaching · Sim round`

Coaching should become the home for:
- staff,
- gameplan templates,
- "How we play",
- how we win / how we get beaten,
- in-form players,
- out-of-form players,
- salary-cap information,
- Board Confidence.

Plain-English coaching insight first; supporting numbers second.

Before implementing more, inspect current merged Staff/coaching work and extend it rather than duplicating screens.

---

## ARD-M6-002 — Coaching staff gameplay
**Status:** `IN PROGRESS / PARTIAL`  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`
**Current state (2026-09-28):** Phase 2 (data model, Round 1 2026 seed, read-only Staff UI) is merged. Phase 3 (the living coaching market: sackings, contracts, retirement, promotions, poaching, your vacancies and releases, development, reputation, generated coaches, expansion staffing, archive) is merged: PR #62 as `bf8bd0a`, `coach_market` suite, 50-season probe with every job filled. Phase 4 (retired players become coaches) is next; Phase 5 (gameplay effects) after it.  

Core design:
- Teaching → development,
- Tactics → match performance,
- Man-management → morale/selection response.

Requirements:
- modest/capped effects,
- role fit where sensible,
- coach career histories,
- replacement/succession over long saves,
- save compatibility,
- avoid generic "+10% everything" staff bonuses.

Validate with targeted multi-season simulations.


### Phase 4 implementation record (2026-09-28, branch `claude/coaching-phase4`)
- **Capture:** a playing career ends (retired in `Prospects.age_league`, or delisted and unsigned at the close of free agency) and `GameState._career_over` captures him before he leaves the lists. The `played` snapshot holds games, goals, club stints, draft, listed position, retirement year and in-save Brownlows and Colemans. No ratings, contract, training, injury or stat tables are kept.
- **Decision:** one career-seeded roll per player, decided once: 19%, 22% at 150+ games, 25% at 250+, +1 point per major award, capped at 30%. He becomes `C_P_<player id>` with his real name and the same alias, then has 1-3 pathway seasons (+1 if the market is flooded, never more than 3 extra) before the ordinary market.
- **Fame is not ability:** skills come from the coach id alone (52-72, centred 62). Across 3,000 retirees, games correlate with skill at r ~0.03 and with starting reputation at r ~0.7. The fame part of reputation fades over nine coaching seasons. A former club rates him +2.5% (half of the 5% club link).
- **Market change (Phase 3 tuning):**
  - Generated external coaches are now top-up supply: fewer as the pathway fills, pool floor 20, top 40.
  - They get the same newcomer starting skills as a former player.
  - The population anchor is now 70, which keeps Elite at 1-4%.
- **Evidence:**
  - Real 32-season career: about 19 career endings a season, median about 280 games, 593 retired, 2 unsigned. Generated draftees reached AFL coaching jobs; for example, a 2031 draftee (253 games) became development coach at Tasmania in 2049 and midfield coach at Essendon in 2053.
  - Synthetic 50-season market at that volume: 23% of endings go into coaching, 36% of those are hired (almost all first as development coaches), then 91% reach a line job, 44% senior assistant and 25% senior coach (about 25 years after retiring). Former players hold 38% of jobs at year 50 and make 33% of new appointments after year 20. Emergencies 0; generated pool 16-22; coach records plus archive about 180 KB at year 50.
- **Limiting factor:** the 60-80% long-run aim is supply-limited by how few playing careers end each season (a list-turnover question, not coaching).
- **UI:** the coach profile shows the playing career (clubs, games, goals, draft, medals), then the coaching career, wrapped for 360 px. News covers notable former players joining the coaching ranks and their first appointment.
- **Tests:** new `coach_pathway` suite, plus the coaches and coach_market suites.

---

## ARD-M6-003 — Board Confidence
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

Persistent qualitative hierarchy satisfaction.

Player-facing states may be:
- Very Secure,
- Secure,
- Stable,
- Under Pressure,
- In Trouble.

Primary input: results relative to expectations.

Smaller inputs may include:
- finals performance,
- long losing streaks,
- player development,
- salary-cap health,
- trajectory/trend.

Rules:
- slow movement,
- explain why it moved,
- no opaque random swings,
- sacking/job-security consequences come later after balance proves the confidence model.

---

## ARD-M6-004 — Contracts / trades / free agency
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

Build toward a complete AFL list-management ecosystem.

Guardrails:
- understandable and streamlined,
- AI follows same core constraints,
- no contract-admin busywork,
- do not attempt all player movement systems in one mega-PR.

Split into smaller authorised subphases when started.

---

## ARD-M6-005 — Options / settings
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `SAFE`

Accessible top-right/main-hub Options.

Include as relevant:
- return to main menu,
- dark/light/system,
- visualisation speed/default mode,
- confirm-before-sim setting,
- audio once available,
- reduced motion,
- UI scale,
- help/about/version,
- New Game,
- Delete Save.

Destructive actions require clear confirmation.

---

# M7 — Competition Identity & Long Careers

Goal: make decades of play feel like a living AFL world rather than repeated isolated seasons.

## ARD-M7-001 — Rivalries
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

This was an existing user-requested roadmap feature and must not be re-added as a "new idea".

Support:
- established club rivalries,
- dynamic/emergent rivalries where justified by repeated finals, close games, player movement, etc.

Use mainly for:
- atmosphere,
- scheduling/context,
- history,
- presentation.

Avoid arbitrary large stat buffs.

---

## ARD-M7-002 — Marquee games
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

Existing requested feature.

Represent appropriate competition traditions such as King's Birthday and other marquee fixtures.

Presentation/identity first. Avoid arbitrary gameplay bonuses.

---

## ARD-M7-003 — Player milestones
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `SAFE` once career stats are stable

Examples:
- 100th / 200th / 300th game,
- first goal,
- career-high goals,
- notable season/career marks.

Surface lightly during matches and/or weekly flow.

Do not spam routine milestones.

---

## ARD-M7-004 — Captaincy / leadership
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `BALANCE-GATED`

Give captaincy modest football meaning:
- composure during swings,
- late-game stability,
- morale/leadership context.

Avoid blanket attribute boosts.

---

## ARD-M7-005 — History, records, leaders & recognition
**Status:** `PARTIAL`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

Canonical umbrella for:
- career games/goals,
- club stints,
- league leaders,
- club records,
- league records,
- biggest wins/highest scores,
- season/career records,
- player of the match,
- coaches' votes,
- honours,
- Hall of Fame / legends where justified,
- famous finals/dynasties/droughts.

### Guardrails
- count each season/event once,
- no duplicate career aggregation on reload,
- generated-player careers remain coherent over decades,
- build from stored facts, not fabricated retrospective text.

---

## ARD-M7-006 — Weather
**Status:** `TODO`  
**Priority:** `P3`  
**Autonomy:** `BALANCE-GATED`

### Wind
- direction/strength affect kick distance/accuracy,
- teams changing ends each quarter changes the effect.

### Wet weather
- fewer clean marks,
- more ground balls,
- lower disposal efficiency,
- more stoppages.

Keep the system compact and legible.

---

## ARD-M7-007 — Ground dimensions & home familiarity
**Status:** `TODO`  
**Priority:** `P3`  
**Autonomy:** `BALANCE-GATED`

Ground dimensions can subtly influence:
- corridor use,
- width/wing play,
- defensive structure.

Home-ground familiarity can provide only a **small** contextual edge.

Do not overpower player/team quality.

---

# M8 — Presentation, Identity & Release Quality

Goal: make the game coherent, readable and robust enough to ship/play for very long careers.

## ARD-M8-001 — Club colour markers
**Status:** `DONE`  
**Merged:** PR #57 as `f549755`; verified on main 2026-09-28 (full suite green).  
**Priority:** `P1`  
**Autonomy:** `SAFE`
**Outcome (2026-09-28, PR #57):** `UiKit.club_marker(code)` draws the club's real colours as vertical bands: two for most clubs, three where the third is a genuine club colour (`GameDB.THREE_COLOUR_CLUBS`: Adelaide, Brisbane, Gold Coast, GWS, Port, St Kilda, Bulldogs, Tasmania, Canberra). A faint edge keeps navy and black readable. `club_badge` uses it, so the ladder, hub, results, draft, season review and match change together; no logos. Regression: `tests/test_matchday.gd::_test_club_markers`.

Replace tiny single-colour squares with compact multi-colour markers.

Examples:
- Melbourne: navy + red,
- Western Bulldogs: blue + red + white,
- Adelaide: navy + red + yellow.

Use simple bands/segments/stripes, not imported logos.

Reuse one component/helper across ladder, fixtures, matchups and reports.

---

## ARD-M8-002 — Visual identity: remove generic green
**Status:** `DONE`  
**Priority:** `P1`  
**Autonomy:** `SAFE` if theme-level
**Merged:** PR #58 as `6ff1ae0`; verified on main 2026-09-28 (full suite green).  
**Outcome (2026-09-28, PR #58):** a small pass, not a redesign; red (`ACCENT`) was already the only action colour. Green used as decoration now goes neutral. Training selection uses the shared outline. Your draft picks get a neutral surface. The Premiers line, "Week off" and "Your best" are plain text. The quarter-by-quarter winner is bold. Season-review club lines are bold. Real states keep green (won, needs met, a rise, form, cap room, re-signed). Regression: `test_matchday.gd::_test_no_green_decoration` (no UI script paints a green highlight surface). The broader palette direction above stays as guidance for future screens.

Direction:
- charcoal / near-black base,
- warm off-white text,
- rusty football red/orange main accent,
- warm grey / stone / cream secondary,
- club colours for variation.

Green only for semantic success/positive state where useful.

Avoid:
- emerald/teal/cyan generic AI-game accents,
- purple-blue gradients,
- glows,
- excessive rounded cards,
- arbitrary decorative coding.

Target feel:
**Australian sporting editorial / old footy record / modern newspaper.**

Prefer shared theme changes over manually touching hundreds of controls.

---

## ARD-M8-003 — Match visualisation authenticity pass
**Status:** `PARTIAL`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

Umbrella for presentation problems after their simulation causes are understood.

Includes:
- correct attacking-end swaps,
- no wrong-way kicks,
- open-play shots remain live,
- believable winger width/work rate,
- correct kick-ins/stoppages/boundary restarts,
- camera/pacing improvements where they improve football readability.

Guardrail:
Do not perform a movement-engine rewrite without evidence that local fixes are insufficient.

---

## ARD-M8-004 — Main menu / onboarding
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `SAFE`

Main menu should remain minimal:
- title/logo,
- optional exact tagline: **Build your dynasty.**
- Continue only when save exists,
- New Career,
- quiet How to Play / Settings.

Onboarding should explain the weekly loop contextually, be skippable, and avoid a giant tutorial.

---

## ARD-M8-005 — Long-career QA
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

Test decades-long / 100+ year careers.

Watch for:
- save growth,
- duplicate career history,
- stale records,
- impossible list states,
- generated-player degradation,
- coaching-history corruption,
- draft/salary-cap dead ends,
- season rollover bugs,
- performance degradation.

Use automated long-run simulation wherever practical.

---

## ARD-M8-006 — Release polish
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

Final pass:
- Android portrait QA,
- accessibility/readability,
- save robustness,
- performance,
- useful error states,
- no silent failure/fallbacks,
- remove debug UI,
- ensure critical game actions are understandable without external explanation.

---

# 3. Cross-Cutting Systems That Must Stay Consolidated

These are not separate roadmap items. They are architectural umbrellas used to prevent duplicates.

## A. Match Report
Includes:
- concise report,
- why we won/lost,
- relevant score sources,
- role-aware player reads.

Do not create a second "advanced report" feature unless explicitly requested.

## B. Opponent Preparation
Includes:
- scouting,
- opponent strengths/weaknesses,
- relevant tactical context.

Do not create separate "scouting card", "weekly opponent report" and "opposition insights" features.

## C. Team Form
Includes:
- existing team-form calculation,
- requested winning-streak/season momentum.

Do not add a duplicate season-momentum modifier.

## D. Forward-50 & Scoring
Includes:
- set/open-play distinction,
- shot context,
- forward archetypes,
- marking/spoil/crumb interaction,
- shot-type stats.

## E. Match-ups & Accountability
Includes:
- defensive assignments,
- forward match-ups,
- tagging trade-offs.

## F. History & Records
Includes:
- career history,
- records,
- leaders,
- awards/votes,
- honours,
- long-save history.

## G. AFL Rules & Restarts
Includes:
- contextual frees,
- boundary rules,
- last disposal,
- out on full,
- throw-ins,
- 50m penalties,
- kick-in correctness.

## H. Simulation Controls
Includes:
- Sim Round confirmation,
- Don't ask again,
- long-press quick-sim,
- stopping before finals.

---

# 4. Verified / Known Current-State Notes

These are here to stop Claude from rebuilding things that already exist. **Verify against the current branch before acting because the repo evolves.**

- Inside 50s are already tracked at player/team level.
- Goal conversion uses the actual shooter rather than a team-wide accuracy average.
- Open-play scoring is structurally possible in MatchSim, but presentation has treated goal/behind events too uniformly.
- A presentation-only Momentum value exists; the requested gameplay Momentum system is not complete.
- Free kicks exist in simplified form.
- Concussion exists as a generic injury type but does not yet represent the requested mandatory two-match protocol.
- Wildcard finals/top-10 finals structure already exists; do not add another wildcard-finals feature.
- Matchday squad has historically been 18 + 4 interchange and needs migration to 18 + 5 unless already changed.
- "Play through" has historically boosted both carrying/transition and shooter selection; the shooter component is the known issue.
- MatchSim already calculates movement distance during possession chains; player metres gained is not yet a fully accumulated player stat unless since implemented.
- True player Disposal Efficiency % has not historically been tracked.
- OOB/out-on-full/throw-in/last-disposal have not historically existed as a complete event path.
- Spoils have existed only partially in forward-50 resolution.
- Coaching staff/career-history work has already begun; inspect current main/active PRs before creating new staff architecture.
- Wildcard finals are **not** backlog work unless the competition rules change.

---

# 5. Standard Validation Matrix

Claude should use the relevant rows for every task.

| Change type | Required validation |
|---|---|
| Pure UI | narrow portrait check; navigation/state preservation; no clipping; relevant UI tests |
| MatchSim logic | deterministic unit/regression tests; seeded sim comparison; full suite |
| Player statistics | event-level attribution test; player/team reconciliation; season aggregation; save/load if persisted |
| Balance mechanic | baseline vs change over many seeds; distribution and positional effects; strong/weak team comparison |
| Availability/injury/suspension | manual selection; AI selection; decrement rules; save/load roundtrip |
| Season/calendar | new career; round progression; finals boundary; rollover; save/reload |
| Salary/list rule | exact-boundary cases; AI parity; invalid-state recovery; save/reload |
| Persistent schema | old-save default/migration; current-save roundtrip; no data loss |
| Visualisation | event/result reconciliation; direction/restart; no second simulation logic |
| Long-save feature | multi-season automated run; duplicate/history checks; performance/data growth |

---

# 6. Balance Assessment Template

Use this section in handoffs for `BALANCE-GATED` tasks.

## Hypothesis
What football behaviour should change?

## Control
Commit/branch and settings for baseline.

## Variant
Commit/branch and exact change.

## Sample
Number of seeded matches/seasons and whether teams were mirrored/randomised.

## Primary metrics
Only metrics directly relevant to the change.

## Side-effect metrics
Check likely unintended consequences, e.g.:
- total scoring,
- win margins,
- positional stat distributions,
- strong-vs-weak team results,
- comeback rates,
- player usage concentration,
- injury/suspension frequency,
- development speed.

## Acceptance
State whether the intended effect is:
- absent,
- too weak,
- plausible,
- too strong,
- unstable.

Do not hide an unwanted result by changing several unrelated tuning constants at once.

---

# 7. Claude Task Prompt Template

When the user says something like **"do ARD-M2-002"**, this roadmap should contain enough information to work from. If a standalone prompt is useful, use this:

```text
IMPLEMENT ROADMAP ITEM: <TASK ID — TITLE>

Repo: gabebartolo-spec/Afl-auto-battler
Engine: Godot 4.7.2

Read docs/ROADMAP.md first and treat it as the source of truth.

Before coding:
1. Inspect the current implementation and existing tests.
2. Confirm whether the roadmap's current-state note is still accurate.
3. Search for overlapping systems so you extend rather than duplicate.
4. Give a short implementation plan.

Implementation rules:
- Stay inside the authorised roadmap item's scope.
- Prefer the smallest robust change.
- Do not refactor adjacent architecture unless genuinely required.
- MatchSim remains the authority for football outcomes.
- Stats must derive from real sim events.
- AI follows the same football rules unless explicitly stated otherwise.
- Preserve save compatibility.
- Mobile-first for UI.
- Do not add number-vomit UI.
- Use natural AFL terminology.
- If the task expands materially beyond its roadmap scope, stop and explain before proceeding.

Validation:
- Add targeted regression tests.
- Run relevant tests.
- Run the full suite before handoff.
- If simulation outcomes change, perform the roadmap Balance Assessment.
- If persisted data changes, run old-save/default + save/reload checks.
- If UI changes, verify narrow Android portrait layouts.

Roadmap maintenance:
- Update this item's status/implementation note only after the work is actually completed.
- Do not mark DONE until merged and verified.
- Do not create duplicate roadmap entries for consequences of this same system.

Git:
- Keep commits logical.
- Standing authority applies: merge clean completed PRs after required validation passes.
- A stale historical "do not merge" line is not a blocker unless the user placed a newer task-specific HOLD.

Final handoff:
1. What changed.
2. Behaviour before vs after.
3. Files changed.
4. Tests added/updated.
5. Full suite result.
6. Balance evidence if applicable.
7. Save-compatibility evidence if applicable.
8. Remaining risks/deferred work.
9. Commit hash(es).
10. PR status.
```

---

# 8. Night-Shift / Autonomous Batch Rules

Claude has standing authority to work through ready roadmap tasks unattended.

Use the autonomy labels as risk guidance, not as ceremonial gates:
- `SAFE`: proceed.
- `SUPERVISED`: proceed when the roadmap already resolves the design; stop only for a genuine unresolved player-experience choice or unexpectedly broad architecture change.
- `BALANCE-GATED`: implement and measure autonomously; merge only when the balance evidence passes the roadmap's acceptance standard.

For each task:
- inspect first,
- skip/stop if unexpectedly architectural or genuinely ambiguous,
- one logical concern per commit where practical,
- merge clean validated work rather than leaving finished PRs idle,
- do not make speculative balance changes without measurement,
- do not "clean up" unrelated code,
- do not create a second implementation of an existing system,
- leave a clear handoff for anything skipped.

Preferred unattended work:
- local correctness fixes,
- clear UI bugs,
- stat plumbing with unambiguous attribution,
- settings/confirmation UX,
- regression tests,
- shared visual-theme fixes.

Poor unattended work:
- new economy,
- broad ratings rebalance,
- new tactical model,
- contracts/trades,
- Momentum tuning,
- major selection architecture,
- rules requiring uncertain interpretation,
- large save-schema migration.

---

# 9. Duplicate / Merge Map

Before adding any new roadmap line, check this table.

| New wording may sound like... | Canonical home |
|---|---|
| Winning streak / season momentum / team confidence streak | ARD-M4-011 Team Form |
| Match momentum / momentum bar matters | ARD-M4-010 In-match Momentum |
| Scouting card / opponent report / weekly opponent insights | ARD-M4-008 Opponent Preparation |
| Full report / why we lost / coaching summary | ARD-M4-009 Match Report |
| Marquee fixtures / special games | ARD-M7-002 Marquee Games |
| Rivals / rivalry system / dynamic rivalry | ARD-M7-001 Rivalries |
| Retrain positions / learn secondary role | ARD-M5-003 Secondary-position learning |
| Defensive assignment / forward matchup | ARD-M4-002 Match-ups |
| Backup ruck / emergency ruck / depth role | ARD-M1-002 + ARD-M5-005 |
| Oval selection / positional team board | ARD-M5-002 Team Selection |
| Flood / spare behind ball / seventh defender | ARD-M4-004 Structural choices |
| Late-game clock / close out game / protect lead | ARD-M4-006/007 |
| Kick-in restart / kick-in player / kick-in possessions | ARD-M3-009 Kick-ins |
| Set shots / snaps / open-play goals / small-forward scoring | ARD-M3-001/002 Forward scoring |
| Spoils / contested marks / speccies | ARD-M2-005 + ARD-M3-003/005 |
| Pressure / smother / tackle pressure | ARD-M2-006 + ARD-M3-004 |
| I50 / metres / DE / CBA / intercepts / score involvements | M2 Match Event & Stat Foundation |
| Player form / match rating by position | ARD-M5-008 Role-aware performance |
| Best on ground / coaches votes / honours / league leaders | ARD-M7-005 History & recognition |
| Injury / visible injury / concussion | ARD-M1-006 + ARD-M3-010 |
| Sim confirmation / skip rounds / don't ask again | ARD-M1-007 Simulation controls |
| Settings / options menu | ARD-M6-005 Options |
| Club colours / green UI / game visual style | ARD-M8-001/002 |
| End swaps / wrong-way movement / shot freeze | ARD-M1-004/005 + ARD-M8-003 |
| OOB / last disposal / throw-in / OOF / 50m / frees | M3 AFL Rules & Match Authenticity |
| Wind / rain | ARD-M7-006 Weather |
| Ground size / home ground edge | ARD-M7-007 Venues |
| 22-player side / 4 bench / 5 interchange | ARD-M5-001 |
| Career history / records / Hall of Fame / league leaders | ARD-M7-005 |
| Board satisfaction / job security | ARD-M6-003 Board Confidence |
| VFL / reserves development | ARD-M5-006 Passive reserves |
| OVR correlation / rating predicts strength | ARD-M5-010 |
| Wing/inside-mid/forward identity labels | ARD-M5-009 |

---

# 10. Roadmap Maintenance Log

Keep this short. Add only meaningful structural changes, not every code commit.

- **2026-09-28:** Removed stale per-PR/phase approval gates. Claude now has standing authority to action ready roadmap work and merge clean validated PRs; supervised/balance labels are risk gates, not ceremonial user-approval gates.
- **2026-09-28:** Converted roadmap from conversation-style backlog into a canonical execution roadmap with milestones, stable task IDs, dependency ordering, global guardrails, validation matrix, balance template, Claude task prompt and duplicate map.
- **2026-09-28:** Consolidated repeated concepts including season momentum/team form, reports, opponent scouting, forward scoring, match-ups, history/records, simulation controls, AFL rules/restarters, rivalries, marquee games and secondary-position learning.
