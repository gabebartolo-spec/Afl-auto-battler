# M4 — Tactical Matchday Layer

Goal: watching a match should involve genuine coaching choices without becoming manual-control football.

## ARD-M4-001 — Match-driven decision gates and observable consequences
**Status:** `PARTIAL` — MatchSim already has context-triggered moments, resolution and a moments log; the end-to-end player outcome still needs verification/refinement. _(code reconciled 2026-10-05)_
**Priority:** `P1`
**Autonomy:** `SUPERVISED`
**Depends on:** reliable M2/M3 events and §1.11's correctness/readability requirements. Repairs within that gate take priority; unrelated expansion waits for its phone checks. Reuse the existing duel/tag/interceptor mechanics; completion of the remaining matchup/structural scopes is not a prerequisite.

### Target and smallest useful slice
Inspect the existing set-shot, tired-player, hot-midfielder, duel, momentum and late-bounce gates before adding one. Start with one existing gate from trigger through consequences. A normal watched match should offer useful coaching opportunities, but do not force a quota into a quiet quarter or manufacture routine matchups.

### Scope / acceptance

- Trigger from the match actually being played: named people, current contests, score/time, workload or observed opposition influence. Test quiet and false-positive contexts.
- Show feasible options with a football trade-off and a keep-current/default path. Do not offer an unavailable replacement or counter as if it can execute.
- Record triggering evidence, choice, application time, affected players/structure, duration or cancellation rule and observed outcome using the existing event/moment model.
- Resolve the action once. Applied state, oval presentation, event log, player/team statistics and summary agree. If application fails, explain why; never print success for a no-op.
- Deliver football impact which can be positive or negative: changed contests, possessions, space, entries, shots, energy or uncovered responsibility. A subsequent win is not proof that the call caused it.
- Show concise follow-through at the next relevant interval; longer-lived calls can remain inconclusive when the sample is thin. Explain actual observations rather than an invented counterfactual.
- Keep meaningful negative consequences and uncertainty. AI uses equivalent mechanics and only observable/scouted information.
- Preserve natural football language, phone flow and ordinary watching/skip behaviour. Short questions should arise from current evidence and offer logical responses; restrained humour must not hide a cost or suggest an effect the engine does not apply.

### Exclusions
No new decision engine, direct footballer control system, best-choice hints, forced close finishes, giant hidden buffs or added cinematic library. M8-007 remains a separate presentation gate.

### Validation
Targeted trigger/resolution tests, invalid personnel and repeat-resolution coverage, seeded keep-current/context-informed/mismatched comparisons, watch/skip event agreement, and Android touch/Back checks. Check interruption frequency and option dominance across several match contexts; shared seeds do not imply identical later RNG consumption. In observed sessions the player should explain the expected benefit/cost and what actually changed. Simulations prove behaviour, not enjoyment.

### Audit — the tired-star call (2026-10-05)
Evidence in `docs/TIRED_CALL_AUDIT_2026-10-05.md` (PR #230, merged; 288 paired matches). Trigger, feasibility, single application and determinism all hold. But **Rest and Keep produce almost the same match** (59.9% v 59.3% wins, +0.8 margin, his output after nearly equal) because a kept star is rotated off at 25 energy anyway and a rested one comes back once fresh; under Ride the stars the call fires in 88% of matches; the break restates the choice instead of reporting what followed; two card details are slightly inaccurate. **Director decision needed:** make the trade-off real, drop the call or keep it as flavour. Follow-through belongs to M4-009.

**Built (2026-10-06, merged in PR #233):** each answer now holds to the break: rested, the star sits out the rest of the quarter (the match in Q4) and starts the next fresh; kept, the rotations leave him on however cooked and he starts the next quarter tired. The card names who comes on and the duration; the break reports what followed. Re-measured on the same 288 matches: his output and next-quarter energy now diverge (0 v 2–3 disposals to the break; 94–98 v 38–52 energy), overall wins 58.3% v 58.9%, with resting better after a Q2 call and keeping better after a Q3 call (small sample). Evidence appended to `docs/TIRED_CALL_AUDIT_2026-10-05.md`. Phone check remains.

---

## ARD-M4-002 — Key match-ups
**Status:** `PARTIAL` — forward/defender assignments are merged; broader ruck/midfield/interceptor matchup presentation remains open.  
**Merged:** PR #96 as `26d34a2`; key forward/defender assignments are selectable, play out in named contests, can be changed during matches, and AI can rematch.  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

- Let user assign a defender to a dangerous forward.
- Opposition AI can make equivalent assignments.
- Defender can follow the player or protect space depending on instruction.
- Match-up should matter through contest context, not a flat arbitrary debuff.

### Guardrails
Do not create 18 individual matchup controls. Focus on meaningful key assignments.

### Follow-up — broaden “key match-ups” beyond forward vs defender
The current implementation is too narrow if “key match-ups” effectively means only a key forward against a key defender.

Treat **Key match-ups** as the handful of contests that shape the game, which may include:
- **Ruck battle:** the two primary rucks, especially where tap quality / hit-outs to advantage / clearances make the contest strategically important.
- **Star midfielder battle:** opposing elite mids, or a star mid against the player assigned to run with/tag him. This does **not** have to mean a literal fixed one-on-one all game; it can be presented as who is influencing the stoppages/contest more.
- **Key forward vs key defender:** the existing direct assignment model.
- **Interceptor vs opposition forward structure:** an elite intercept defender whose influence comes from reading play and leaving his direct opponent rather than simply winning one-on-one contests.

The pre-match and live-match presentation should surface only the genuinely important contests for that fixture. A “key matchup” may therefore be:
- a direct assignment,
- a positional duel such as ruck vs ruck,
- or an influence battle such as star midfielder vs star midfielder.

Do not imply every highlighted matchup is a hard man-on-man assignment. The point is to help the player understand **where the game is being won or lost**, not to create eighteen pairing controls.

Acceptance:
- a match can surface a ruck duel or midfield-star battle as a key matchup even when no forward/defender assignment is involved;
- direct defender assignments remain explicit when they exist;
- live and post-match matchup commentary uses the correct type of contest rather than pretending every matchup is one-on-one;
- the system still surfaces only a few high-value contests, not a full positional matrix.

### Research refinement — 2026-10-05

**Dependencies:** valid duel/contest events, current role/personnel eligibility and M4-001's application contract.

**Smallest scope:** one genuinely dangerous contest with an available response, extending the merged forward/defender foundation. Include the relevant sacrificed responsibility; a hot interceptor or midfielder is not automatically a literal one-on-one.

**Exclusions:** 18 assignment controls, routine pairing popups, fabricated danger or a recommended best defender.

**Acceptance:** feedback names both people and the observed threat; the available counter changes an actual eligible assignment/structure; keeping the current approach remains valid; no special intervention is required in a quiet match. Following events can show both benefit and exposure elsewhere.

**Validation:** positive/quiet/invalid-personnel cases, actual assignment and visual/log binding, AI parity, seeded contest/team comparisons and Android understanding/touch checks. Reuse §9.1 “X is hurting you” and matchup work; do not open another danger-feedback system.

---

## ARD-M4-003 — Tagging has an attacking cost
**Status:** `VERIFY` — attacking-cost constants and tagger/specialist handling already exist in MatchSim; inspect their measured effect and player feedback before changing them. _(code reconciled 2026-10-05)_  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

A hard tag may reduce the target's influence, but the tagger should generally sacrifice some attacking involvement/output.

No free "debuff their best player" button.

Check:
- target disposals/influence,
- tagger disposals/influence,
- team-level net effect,
- role/trait differences.

### Research refinement — 2026-10-05

**Dependencies:** current MatchSim tagging, Roles and event-backed influence/stat reporting.

**Smallest scope:** verify one specialist and one non-specialist case; repair only an evidenced cost/feedback defect.

**Exclusions:** another tag mechanic, universal player debuffs or a guaranteed team gain.

**Acceptance:** the named target and stopper are correct; applied/removed tag timing is clear; actual attacking sacrifice and suppression match the rule, including specialist differences; thin evidence does not produce a confident causal claim.

**Validation:** paired target/stopper involvement and team outcomes across personnel/score contexts; equal side rules; repeated application/removal; inspect Android feedback. A later defeat does not prove the tag failed, and a win does not establish its net benefit.

---

## ARD-M4-004 — Structural coaching choices
**Status:** `PARTIAL` — roaming-interceptor contests and accountable-spare response exist; broader structural outcomes and readable costs remain to validate/refine. _(code reconciled 2026-10-05)_  
**Progress (2026-10-06):** send a forward to the other side's loose defender merged in #303 (director: merge as built, forwards only; a check makes sure no midfielder or defender is offered).  
**Priority:** `P2`  
**Autonomy:** `BALANCE-GATED`

Support concepts such as:
- spare/loose player behind the ball,
- extra number at stoppage,
- seventh-defender-type positioning.

### Interceptor role — roam the backline as the spare
Support a deliberate instruction for a **Jake Lever-style interceptor**: a defender who is given licence to leave his nominal opponent, track the ball, attack aerial contests and hunt intercept possessions/marks across the backline.

This should be a real structural choice, not a flat intercept-stat buff:
- nominate an appropriate defender as the roaming interceptor / spare;
- weight his involvement toward opposition entries, aerial contests, intercept possessions and intercept marks;
- reduce his strict one-on-one accountability to a single forward;
- the cost is structural: somebody else must absorb the opponent he leaves, the defence can be exposed if the ball gets through him, and the side gives up something elsewhere by keeping a spare/loose player behind the ball;
- suitability should come from relevant football traits/attributes such as intercept ability, marking, reading play/positioning and defensive quality — not simply OVR or height;
- a genuine lockdown defender and a roaming interceptor should feel meaningfully different even if both are high-quality defenders;
- opposition AI can use the same role when its personnel and game state justify it.

The roaming interceptor should also be eligible to appear as a **key matchup / opposition danger** even though he is not assigned to one forward. If he is controlling the air, the player should have football-appropriate counters available (for example changing forward structure, making him accountable, lowering/altering entries, or moving the spare), rather than being told he is a danger with no response.

### Director addition — match preparation: solo vs dual ruck
**Status:** `TODO` — design and implementation follow-up; covered by this item's balance gate.

Give match preparation a meaningful **solo ruck vs dual ruck** choice, connected to the selected players' traits, skills and complementary roles. Both approaches must have benefits and drawbacks; neither should be a universally superior button.

Claude should refine the smallest football-credible design using the existing selection, workload, role and synergy systems. Candidate trade-offs to investigate, not prescribed numerical effects:
- **Solo:** more room for another midfielder/runner or other specialist, and concentrated responsibility for a dominant ruck; costs may include workload/fatigue, reduced genuine ruck cover and exposure if the sole ruck is injured or beaten.
- **Dual:** shared ruck workload, genuine cover and complementary around-ground/forward contributions; costs may include a selected-player opportunity cost, reduced running/pressure or poorer spacing when the two players do not complement one another.

Tie suitability into player identity rather than blanket solo/dual stat multipliers. **Ideas, not demands:** a "Ruck King" could operate better as the sole lead ruck, while an "Extra Midfielder" or "Unicorn"-type ruck could thrive in a complementary tandem. These names and exact behaviours are suggestions for Claude to assess; do not automatically add traits or redefine the existing Unicorn trait, which already has a separate multi-position synergy meaning. Reuse compatible existing traits/attributes where possible and avoid double-counting their benefits.

**Director reference examples — Extra Midfielder rucks:** Luke Jackson, Brodie Grundy and Tristan Xerri. The intended distinction is stronger contested grunt around stoppages (ground-level ball winning, clearance involvement and pressure), with generally less aerial potency than tap-focused rucks. This does not mean they are poor ruckmen or cannot win taps; tap craft, aerial strength and contested midfield contribution are separate dimensions, and individual exceptions should remain possible. In the intended archetype contrast, tap-focused rucks are more likely to take intercept marks, while Extra Midfielder rucks are more likely to follow up forward-50 ruck contests and become involved in scoring chains. Express these as personnel-dependent tendencies through real positioning, contest follow-up and disposal/assist events, rather than guaranteed outcomes or fabricated credits; preserve individual exceptions. Use these players as archetype reference points, not instructions to force traits onto them, manually buff them or automatically make tandem play optimal. Claude should refine how this profile interacts with a complementary partner versus solo responsibility using the existing skills, traits and football model.

Acceptance:
- The choice is clear in match prep, names the relevant selected ruck(s), and explains the likely benefit and cost in concise football language without prescribing the best option.
- Real selection, ruck responsibility, rotation/workload and off-ruck roles support the choice; no extra player, phantom second ruck, duplicate simultaneous contribution or cosmetic-only toggle.
- Both structures can succeed or struggle depending on personnel, complementarity and opponent; AI operates under the same rules.
- Invalid selections/injuries and emergency cover follow existing ruck-integrity rules (ARD-M1-002); integrate with the five-interchange migration (ARD-M5-001) and workload work (ARD-M5-015).
- Validate matched-resource solo/dual comparisons across dominant specialists, mobile/hybrid rucks and poorly complementary pairs. Demonstrate meaningful advantages and costs, and use actual match evidence for feedback rather than invented tactical success claims.

### Director addition — defensive forward archetype / trait

**Status (2026-10-06):** `IN REVIEW`. Implemented as the director approved: a **Defensive forward** trait (a forward's own position, Pressure 44+, about 1–2 a club) and a person-based answer to their loose defender. At a break, "Their loose defender" sits with the key match-ups and asks who goes to him. A Defensive forward cuts his reach to contests to 40%, any other forward to 70%. The forward sent is up the ground, so he is seldom a target, a shooter or a crumber himself (25%); that replaces the old flat −3.5% on the whole forward line. The AI names its forward by the same rule, after observable roam wins. Tests: `test_match_game.gd` `_test_defensive_forward`.

Add a **Defensive forward** as a genuine player archetype/trait and make it relevant to this exact problem: when an opposition loose/intercept defender is hurting you, a suitable defensive forward should be deployable to make him accountable rather than the response being only an abstract team button.

This is a design brief, not a fully specified mechanic. **Claude should ponder and propose the smallest football-credible implementation** before coding the deeper behaviour. Work out how the identity should be represented in the existing archetype/trait/role model, what makes a player genuinely suited to it, and how it interacts with live matchup/structural calls without creating another redundant role system.

Intent:
- a defensive forward sacrifices some attacking freedom/output to apply pressure, occupy or follow a dangerous defender and reduce that defender's ability to roam uncontested;
- this should create a recognisable player identity and list-building option, not a universal instruction that any forward performs equally well;
- deploying one against a loose defender should be a meaningful response available from the matchup UI when suitable personnel exist;
- the trade-off must remain real: making the interceptor accountable can cost forward potency, aerial presence, spacing or some other football-relevant attacking value;
- the opponent/AI gets equivalent access under the same personnel and information rules;
- it is **not** a magic “turn off their interceptor” counter, a flat hidden debuff or an optimal-move hint.

Claude has discretion over the final implementation details and may recommend whether this is best expressed as a player archetype, trait plus role instruction, or the smallest compatible extension of the existing systems. Preserve the director's core requirement that **Defensive forward exists as a distinct football identity** and can be deliberately deployed against loose/intercept defenders. Do not reopen the completed general role-classification pass except where this new identity genuinely requires an extension.

Do not literally create an extra player. Moving numbers to one area must reduce presence elsewhere.

Prefer situational/live choices before adding permanent micromanagement.

Acceptance:
- an elite interceptor can materially influence opposition entries without being hard-matched to one forward;
- his impact shows up through real intercept/spoil/mark events, not a hidden blanket modifier;
- using him loose creates a measurable trade-off elsewhere;
- the role can be changed/removed during a match;
- AI parity applies;
- post-match reporting can explain that the spare/interceptor controlled the backline when the event data supports it.

### Research refinement — 2026-10-05

**Dependencies:** M4-002 contest context, existing interceptor/roam events and M4-001 application/expiry records.

**Smallest scope:** make one existing roaming-interceptor choice legible and verify its actual defensive responsibility/cost before expanding structures.

**Exclusions:** flat free intercept buffs, a second formation engine, universal specialist roles or a new visual library.

**Acceptance:** suitability comes from relevant football skills; the spare's extra involvement and the responsibility left elsewhere are observable; making him accountable acts through the existing football model; the oval and report agree with real events. Changed/invalid personnel cannot leave a phantom assignment.

**Validation:** seeded equal-resource specialist/lockdown and accountable/not-accountable comparisons, event/visual binding, persistence where applicable and AI parity. Phone viewers should identify the relevant space and risk without an optimal-plan hint.

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

### Research refinement — 2026-10-05

**Dependencies:** current Roles/selection model (M5-009 foundation), reliable M2/M3 events and M4-001 follow-through.

**Smallest scope:** one role instruction with a demonstrable benefit and competing responsibility; inspect current role effects before adding controls.

**Exclusions:** a parallel tactics engine, fantasy classes, ability bars or arbitrary all-stat multipliers.

**Acceptance:** suitable players can perform a distinctive job; relevant involvement/positioning changes while a real football trade-off remains; inactive/descriptive labels do not promise an engine effect. Role, selection, report and oval use the same underlying facts.

**Validation:** matched personnel and opposing-composition comparisons, invalid/changed assignments, AI parity, save compatibility if persisted, and phone explanation of the chosen job/cost.

---

## ARD-M4-006 — Game-state tactical AI
**Status:** `PARTIAL` — score/quarter reactions, specialist tagging and responses to observed roaming wins already exist; broader timing/context validation remains. _(code reconciled 2026-10-05)_  
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

### Research refinement — 2026-10-05

**Dependencies:** observed scoreboard/quarter/contest state and shared tactic effects.

**Smallest scope:** test existing reactions in leading, chasing and quiet situations before adding a new policy.

**Exclusions:** hidden AI boosts, reading concealed user calls or unrevealed potential, perfect counters and guaranteed drama.

**Acceptance:** available personnel and visible history explain the reaction; changing concealed user choices while holding observable state fixed does not change the AI's response; AI calls incur the same costs and durations as user calls.

**Validation:** deterministic visible-state fixtures, late/early-quarter and unavailable-specialist cases, hidden-information isolation and shared-effect tests. Use multi-club seeded samples for policy behaviour; do not turn a few wins into a balance conclusion.

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
**Status:** `DONE`  
**Merged:** PR #90 as `71409fc`; selection now shows line-v-line strength, relevant people, opposition style and the game plan in football language without prescribing a best answer.  
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
**Status:** `DONE`  
**Merged:** PR #85 as `73338d6`, extended by PR #97; full time now uses one concise coaching report with causal match factors and turning points.  
**Priority:** `P1`  
**Autonomy:** `SAFE` once M2 data exists

### Implementation record (2026-09-28, branch `claude/match-report`)
- **Before:** at full time the Summary tab (result, how it went, best players, key numbers, your week) and a separate Report tab (match read, best, needs a lift, opposition danger, notes) answered the same question twice.
- **After:** the Summary is the one coaching report, in this order:
  - the result once, and what it means (finals, ladder, next opponent);
  - "How it went": the 2 or 3 causal lines from the sim (`MatchNotes.match_factors`: a run of goals, a quarter that swung it, stoppages, territory);
  - best players: your best three and their best one, with best on ground;
  - "Needs a lift": 1 or 2 of yours only when genuinely quiet (at least 4 points under their usual);
  - "Coaching notes": at most 2 from the assistant, observations only, nothing the lines above already say;
  - four key numbers (disposals, inside 50s, clearances, pressure rating);
  - your week.
  - The Report tab is gone at full time. Stats keeps quarters, team and player stats. The half-time report is unchanged.
- **Tests:** `run_matchday_tests.gd` checks two tabs and one report (no Report tab, no "Match read" or "Second-half notes" at full time). The existing summary checks (result, factors, best players, key stats) still pass.
- **Screens:** the phone portrait (390x844) full-time Summary was reviewed. Stat lines read the same way in best players and needs a lift.

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

### Director addition — full match stats at every quarter break (2026-10-06)
**Status:** `TODO` — explicit access requirement; audit existing break UI first and extend any missing access, preserving the completed report foundation.

Make the **full match stats** available at **quarter time, half time and three-quarter time**, with the same team/player stat coverage available at full time. Include both teams' cumulative match-to-date statistics and available quarter scoring/breakdowns; values must come from the current authoritative match state, not a completed-match reconstruction or future results.

Reuse the existing Stats screen/table in a clear tab/button accessible from each break. Keep the concise coaching/decision view as its own surface, so full statistics are available on demand without turning the break summary into a stat dump. Opening/closing stats must not resume the match, commit a call, discard pending tactical choices or advance the simulation; the user returns to the same paused break and can still make their decisions.

Acceptance: full team and player stats can be opened at all three breaks, match the events played so far, and remain accessible regardless of whether the user watched or skipped the preceding quarter. Validate all three break states, missing/zero stats, back navigation, selected tactical choices, phone scrolling and final-time parity.



### Research refinement — 2026-10-05

**Status boundary:** the merged report remains DONE. These checks apply when M4-001/002/003/004 follow-through changes; do not rebuild or add a second report.

**Dependencies / smallest scope:** use existing MatchNotes/CoachReport and authoritative moment/contest records to explain one changed call.

**Exclusions:** more stat panels, a permanent full-report dump, generic praise or claims about an unplayed alternative.

**Acceptance:** concise lines distinguish the applied instruction, observed effect and uncertainty; negative or absent evidence cannot be rewritten as success; quiet matches remain quiet. Named events and statistics agree.

**Validation:** event-to-copy fixtures, short/contradictory samples, watch/skip consistency and phone recall of the match's people/turning point. New replay/archive work remains an unselected candidate.


**Approved flavour extension:** FL-006 (§9.3) adds sparse truthful editorial headlines within the existing report; the DONE report foundation remains DONE. Keep decorative copy distinct from tactical follow-through.

---

## ARD-M4-010 — In-match Momentum
**Status:** `PARTIAL` — real momentum mechanic is complete; the director-requested meter presentation and onboarding overhaul below remains TODO.  
**Merged:** PR #102 as `902d152`; the meter now reads real MatchSim state and the effect is capped, fading and measured.  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

### Current state
Momentum is now an engine mechanic, not presentation-only. Goals/behinds move a capped state that fades each chain and halves at breaks; it gives the favoured side up to a small 4% contest edge, and the meter reads that exact state.

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

### Momentum meter appearance, meaning and onboarding — director request (2026-10-07)
**Status:** `TODO`. Preserve the momentum bar **and its real gameplay impact**; overhaul its presentation rather than removing it or making it cosmetic.

- Director reports an unexplained two-colour bar whose colours do not appear to change with the teams. Current-main `MatchScene._momentum_bar()` already selects both clubs' primary colours, so verify the actual build, colour lookup and custom-club handling before claiming this is absent or fixed. Ensure the displayed sides visibly identify the actual competing clubs; handle similar colours with contrasting treatment, club names/abbreviations or crests, and clear neutral/favoured-side cues.
- Create an attractive, legible meter with a persistent **Momentum** label and an accessible concise explanation; the existing hover-only “Momentum” tooltip is insufficient, especially on touch devices. Make which club has the run of play understandable without decoding an unexplained colour split or numerical dump.
- Explain the **actual** mechanic in plain football language: scoring shifts the run of play, its advantage fades between possession chains and reduces at breaks, and it gives the favoured club a small capped edge in stoppage/loose-ball contests. Use current engine behaviour as the source of truth; do not imply guaranteed goals, broad attribute boosts or invented effects.
- On a fresh save, introduce the meter at the first relevant watched-match moment with a brief contextual tutorial showing the clubs, direction and practical meaning. Make the explanation available again on demand; persist first-use completion and respect tutorial preferences. Include it in the existing onboarding owner ARD-M8-004, without repetitive prompts or an opening bombardment.
- Continue displaying authoritative `MatchSim` event momentum, not a separate UI estimate. Reuse existing momentum tests; add focused presentation/onboarding regression checks for both home/away perspectives, custom and similar-colour clubs, neutral/swing states, touch access, fresh-save/re-entry and save/resume. Retain the measured capped/fading contest effect and existing balance guardrails; any balance change remains balance-gated.

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

