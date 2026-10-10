# M3 — AFL Rules & Match Authenticity

Goal: make the event stream and visualisation look and behave like Australian football.

## ARD-M3-001 — Set shots vs open-play scoring
**Status:** `PARTIAL` — open-play freeze is merged; scoring-model/context variety remains.  
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
**Status:** `PARTIAL` — forward archetypes (key forwards mark inside 50, small forwards crumb) merged in #286; #297 then let generated forwards include small forwards (172–203 cm, was 184–203). Balance measurement and the spoils-outside-the-50 gap (below) remain. _(2026-10-06)_  
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

### Implementation record (2026-10-06, branch `claude/forward-archetypes`)
**Director's note:** small half-forwards take many of their marks running up the ground into the midfield. Key forwards take theirs inside 50, unless they present up the ground for a contested mark.

**Changes:** all in MatchSim `resolve_forward50`, `pick_carrier` and the crumb pick. Archetypes are by height, as in Training's jobs: key from 192 cm, small up to 181 cm.
- **Marking:** on an unmatched entry, the target's own game in the air (marking and height, `Matchups.forward_air`) moves his mark chance. A named key match-up already did this.
- **Spills:** an unmarked, unspoiled entry can spill, more often off a tall. The first forward to it is weighted toward small forwards, Crumbers and Pressure. He wins it at ground level (by size and Pressure) and snaps, or the defence clears it.
- **Crumbs:** crumbs off spoils are weighted the same way.
- **Targeting:** entries lean a little toward key forwards.
- **Lead-up work:** small and general forwards do more of it in the middle and attack zones.
- **Calibration:** `inside50_goal` goes from 0.269 to 0.279 so league scoring holds.

**Evidence** (`tools/audit/fwd_archetype_impl.gd`, 576 matches on drafted leagues, seeds 21–24, the same seeds before and after), per forward-game:

| | Goals | Set-shot share | Crumb share | Marks inside 50 | All marks |
|---|---|---|---|---|---|
| Key, before → after | 1.14 → 1.28 | 54 → 57% | 4 → 3% | — → 3.00 | 4.80 → 4.67 |
| General, before → after | 0.84 → 0.85 | 47 → 41% | 6 → 12% | — → 1.53 | 4.60 → 4.42 |
| Small, before → after | 0.94 → 0.92 | 44 → 26% | 8 → 23% | — → 1.16 | 4.19 → 4.14 |

Small forwards keep their total marks because more of them now come on the lead up the ground. Calibration passes: goals 0.96–0.98 of real, marks 1.03–1.04, rebound 50s 1.05–1.06. The top-3 goalkicker share is 0.42 against a real 0.38, inside tolerance but more concentrated than before.

**Not resolved:** sides with four or five key forwards still score slightly more (13.4 goals against 12.0–12.6). That was already true before the change (13.5), and those lists are probably stronger overall. A controlled mixed-versus-tall comparison belongs with RPG-004's audited Tall-small sequence.

**M3-001 (later variety):** spills and ground balls now produce a distinct open-play crumb or snap, tagged on the event. Running shots, soccered goals, dribbles and long bombs remain.

**Tests:** `test_match_game.gd` covers size classes, key forwards' marks inside 50 (at least 1.5× small forwards'), set-shot and crumb shares by archetype, and that either archetype still scores the other way.

---

## ARD-M3-003 — Spoils across the ground
**Status:** `PARTIAL`  
**Merged foundation:** PR #83 as `a013277`; forward-50 spoils are real loose-ball events, while general-play marking contests remain open.  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

### Implementation record (2026-09-28, branch `claude/spoils`)
- **Spoil stat:** when a forward-50 entry is not marked and the defender gets a fist to it, the defender is credited a spoil (team and player). This is a credit only. There are 15.2 a team per game, all from forward-50 contests.
- **A spoil is a loose ball, not defender possession:** when a spoiled entry does not score, the ball is on the deck.
  - A crumbing player sometimes wins it (`MatchSim._crumb`), weighted by pressure. By role: forwards 1.0, mids 0.25, rucks 0.1, defenders 0.03.
  - The chance is 30% scaled by his pressure. He then snaps: an unmarked shot at 0.85.
  - Otherwise the defence clears it, as before (a rebound, an intercept that is never a mark off a spoil).
  - Crumbed goals carry `crumb: true` on the event for the match view and commentary.
- **Balance:** crumbs added about 0.7 goals a team, offset by the base conversion (`inside50_goal` 0.284 to 0.269, `inside50_behind` 0.187 to 0.180). This is mirrored in `tools/sim_harness.py` along with the crumb step.
- **Result (400 seeded matches, calibration seed), main v this branch:**
  - score 86.6 v 86.7;
  - goals 12.85 v 12.87;
  - behinds 9.47 v 9.52;
  - rebounds 38.6 v 39.0;
  - home win 59.4% v 60.0%.
  The calibration and league_balance suites pass. The Python harness reads 0.98 of benchmark scoring.
- **UI:** "spoils" in the player's detail line on Match stats.
- **Tests:** `test_match_game.gd::_test_spoils_and_crumbs` checks that:
  - spoils add up to the team total and are made by defenders;
  - crumbed goals happen and go mostly to forwards.
- **Still open:** spoils in general play (marking contests outside the forward 50 are not yet modelled as contests). Small-forward crumbing as an archetype belongs to ARD-M3-002.

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
**Status:** `DONE` — smothers are on `main` with tests; PR #196 was closed and carried by #208. _(reconciled 2026-10-05)_  
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
**Status:** `DONE` — MatchSim-authored speccies and the 0–2/match quota are on `main`; PR #196 was closed and carried by #208. _(reconciled 2026-10-05)_  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

- Rare spectacular mark outcome only from a genuine contested marking situation.
- Marking/aerial quality and traits can increase chance.
- Statistically a mark unless a dedicated stat later adds value.
- Presentation flourish, not a giant gameplay buff.
- Frequency target: roughly **0.8 speccies per match**, with **2 as a hard match maximum**; #196 implements that target deterministically.

---

## ARD-M3-006 — Boundary rules / OOB / out on full / last disposal
**Status:** `DONE` — merged in PR #190. _(reconciled 2026-10-05)_  
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
**Status:** `PARTIAL` — the generic clanger free now has a football cause (ruck contest at ball-ups, a forward held in a marking contest in the forward 50, otherwise incorrect disposal); measured in [free kicks](FREE_KICKS_2026-10-06.md). _(2026-10-06)_  
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
**Status:** `VERIFY` — 50-metre penalties are on `main` (PR #196 closed, carried by #208); confirm the long-run frequency/balance evidence before calling it done. _(reconciled 2026-10-05)_  
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
**Status:** `DONE` — real kick-in takers/styles/stats are on `main`; PR #196 was closed and carried by #208. _(reconciled 2026-10-05)_  
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
**Status:** `DONE`  
**Merged:** PR #97 as `e068060`; injuries now occur during the match, remove the player, bring on bench cover, and reconcile with post-match availability.  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

- Player goes down / leaves field where appropriate.
- Bench/rotation structure responds.
- Availability after match reconciles with injury record.
- Do not let visualisation claim an injury that MatchSim/save state does not record.

---

## ARD-M3-011 — MRO / suspensions
**Status:** `VERIFY` — MRO, suspensions, Brownlow eligibility and the Tribunal/Appeals flow are on `main` (PR #196 closed, carried by #208); confirm suspension frequency/balance evidence before calling it done. _(reconciled 2026-10-05)_  
**Priority:** `P2`  
**Autonomy:** `BALANCE-GATED`

- Reportable incidents should come from plausible match events where possible.
- Outcomes: no action / warning or fine / suspension.
- Suspended players unavailable for specified matches.
- Discipline/aggression/Hothead-like tendencies can influence risk, capped.
- AI same rules.
- Post-round MRO summary.
- PR #196 includes a one-shot Tribunal challenge and, after a failed Tribunal suspension challenge, one Appeals Board path for the user's club. Verdict evidence is fixed with the incident so reloads cannot reroll it.
- Any upheld sanction makes the player Brownlow-ineligible for that season while preserving the raw votes; overturning the case restores eligibility unless another upheld case still disqualifies him.

---

