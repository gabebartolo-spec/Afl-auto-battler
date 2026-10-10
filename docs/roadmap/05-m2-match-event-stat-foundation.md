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
**Status:** `DONE`  
**Merged:** PR #79 as `330a5fea`; verified on main 2026-09-28.  
**Priority:** `P1`  
**Autonomy:** `SAFE`

### Implementation record (2026-09-28, branch `claude/match-stats-m2`)
- **Built:** a centre bounce credits `cba` to the players who actually contest it: the ruck in the contest and the three best contested non-wing midfielders on the ground at that moment, so rotations, injuries and position moves change who attends. Team `centre_bounces` (both sides, at centre bounces only) is the CBA% denominator. The same players form the centre clearance group, drawn with the single existing roll. Every credit here is bookkeeping: extra dice use `stat_rng`, so a 200-match seeded hash of results is identical to main (3525566088). Per team-game over 60 matches: 30 centre bounces; ruck 19.6 CBA a game, mid 10.5, forward 1.9, defender 1.0 (on-ball time from list-role defenders and forwards moved into the midfield).
- **UI:** "centre bounce attendances" in the player's detail line on Match stats. No CBA% shown yet (the denominator is stored for a later drill-down).
- **Tests:** `test_match_game.gd::_test_m2_stats` (attendance per bounce between 2 and 4 players, team sums).

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
**Status:** `DONE`  
**Merged:** PR #79 as `330a5fea`; verified on main 2026-09-28.  
**Priority:** `P1`  
**Autonomy:** `SAFE`

### Implementation record (2026-09-28, branch `claude/match-stats-m2`)
- **Built:** `_intercept()` credits possession won from the opposition: a forced turnover to the presser, a rebound from a forward-50 entry, and a shot turned over by the defender. Generic rebound 50s are not intercepts. A share of rebounds that were not spoilt become intercept marks (judged from the player's intercept rating). Every credit here is bookkeeping: extra dice use `stat_rng`, so a 200-match seeded hash of results is identical to main (3525566088). Per team-game over 60 matches: 36.2 intercepts; defender 3.7 a game, mid 0.7, ruck 0.7, forward 0.3.
- **UI:** "intercepts" in the player's detail line. **Tests:** `_test_m2_stats` (player sums equal team).

Track actual intercept possessions separately from an `intercept` attribute.

Include:
- intercept mark,
- intercept ground possession where represented.

Avoid crediting generic rebounds as intercepts unless possession was actually won from the opposition.

---

## ARD-M2-005 — Contested vs uncontested marks
**Status:** `DONE`  
**Merged:** PR #79 as `330a5fea`; verified on main 2026-09-28.  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

### Implementation record (2026-09-28, branch `claude/match-stats-m2`)
- **Built:** classified from the mark's context: forward-50 marks taken against a defender (35%, more for aerial players, the rest on the lead) and half of intercept marks. Marks elsewhere in play are uncontested. Every credit here is bookkeeping: extra dice use `stat_rng`, so a 200-match seeded hash of results is identical to main (3525566088). Per team-game over 60 matches: 10.7 contested marks (real AFL about 10-11); forward 0.8 a game, mid 0.4, defender 0.4, ruck 0.2.
- **UI:** "contested marks" in the player's detail line. **Tests:** `_test_m2_stats` (always also a mark, player sums equal team).

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
**Status:** `DONE`  
**Merged:** PR #79 as `330a5fea`; verified on main 2026-09-28.  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

### Implementation record (2026-09-28, branch `claude/match-stats-m2`)
- **Built:** the chain window is one chain, from the stoppage, kick-in, free or turnover that began it to the score. Each on-ground player who carried or disposed of the ball in it, plus the scorer, gets one involvement. Goals and goal assists are unchanged. Every credit here is bookkeeping: extra dice use `stat_rng`, so a 200-match seeded hash of results is identical to main (3525566088). Per team-game over 60 matches: mid 5.6 a game, forward 4.7, defender 3.0, ruck 2.0.
- **UI:** "score involvements" in the player's detail line. **Tests:** `_test_m2_stats` (every scorer is involved in his own scores).

### Intent
Recognise players who materially participate in scoring chains before the final kick.

### Guardrails
- Define a bounded chain window.
- Do not award the entire team an involvement.
- Goals and goal assists remain distinct stats.
- Score involvement should complement, not duplicate, assists.

---

## ARD-M2-008 — Score-source tracking
**Status:** `DONE`  
**Merged:** PR #79 as `330a5fea`; verified on main 2026-09-28.  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

### Implementation record (2026-09-28, branch `claude/match-stats-m2`)
- **Built:** each chain is tagged by how it began (`centre`, `stoppage`, `kick_in`, `free`, `turnover`, `general`) and points are recorded as team `score_from_<source>`. Every credit here is bookkeeping: extra dice use `stat_rng`, so a 200-match seeded hash of results is identical to main (3525566088). Per team-game over 60 matches: stoppage 35.8 points, centre 16.8, general 14.0, turnover 11.6, free 7.6, kick-in 2.7. Stored as data only; no dashboard. **Note:** turnover share is low against real AFL (about 40% of scores); it comes from how the engine starts chains, so it is recorded here rather than tuned in this change.
- **Tests:** `_test_m2_stats` (sources add up to the score).

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

## ARD-M2-010 — GPS distance covered / running output
**Status:** `DONE` — GPS distance covered is on `main` with tests; PR #195 was closed and carried by the consolidated squash merge #208. _(reconciled 2026-10-05)_  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

Track believable player distance covered so running capacity and coaching style have a visible behavioural output rather than only hidden fatigue effects.

Current implementation in #195:
- accumulates metres for every on-ground player from actual possession-chain participation;
- varies running output by role/wing duty, involvement, play-through focus, tagging, gameplan tempo, pep talks and live tactical calls;
- keeps **distance covered separate from fatigue**, so strong runners can cover more ground without being paradoxically credited with less work because they tire less;
- shows one-decimal kilometres in detailed match stats and season km/game on the player profile;
- stores team running totals for later tactical analysis;
- adds no RNG draws, preserving deterministic match outcomes.

Guardrails:
- use distance as a readable consequence/diagnostic, not another primary-screen stat dump;
- do not double-count this as ARD-M5-015 workload: **distance is what the player physically covered; workload is the carried recovery/fatigue consequence between weeks**;
- calibrate believable role/team ranges before using distance as an input to awards, selection or injury risk.

---

