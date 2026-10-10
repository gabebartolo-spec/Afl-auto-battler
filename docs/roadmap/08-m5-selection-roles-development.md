# M5 — Selection, Roles & Development

Goal: make player deployment intuitive, footy-authentic and consequential.

## ARD-M4-012 — Intercepts by zone: any player can intercept
**Status:** `DONE` · **Priority:** `P1` · **Autonomy:** `SUPERVISED`
**Merged (2026-10-06):** PR #462. Defenders intercept 4.9 a game and the loose defender 8.4, with scoring unchanged. Midfield intercepts sit at 1.4 against 2.5 in the real numbers; the director said "Merge, gap later", so closing it is backlog item 25, not part of this item.

**Director decision (2026-10-06, interview):** "any player can intercept, but the loose defender should get more intercepts if he's good at it." Today the general-play aerial pool is defenders and midfielders only, and forward-entry contests are defenders only. Neither pool looks at where the ball is, so forwards never pick off a rebound kick in their forward half.

**Scope:**
- Choose the intercepting player from the players near the ball's zone, weighted by their intercept and marking.
- Keep the named loose defender's skill-scaled extra entry (`_roam_chance`, 0.20–0.38, scaled down when the attack makes him accountable).
- Calibrate per position against real splits. The evidence is docs/research/INTERCEPT_EVIDENCE.md (#416), plus the Wheelo Ratings CSVs (download approved by the director).

**Validation:**
- paired seeded batches: intercepts by position against the evidence;
- team intercepts, rebounds, scoring and margin unchanged within error;
- determinism.

## ARD-M4-013 — Set shots: three visibly different choices, and a real pack for the bomb
**Status:** `PARTIAL` — choice/event/pack and three-sequence implementation is on main via #467 (including #471's presentation); remaining set-shot-share calibration and outstanding balance/device checks are not closed · **Priority:** `P1` · **Autonomy:** `SUPERVISED`
**Implementation reconciliation (2026-10-07):** #471 merged into #467's branch and #467 then merged into main; current MatchSim/MatchDirector and `test_match_visual` contain pass/receive/pack staging and attribution checks. The distinct set-shot-share calibration remains **IN PROGRESS** in open #484 and kick/held-ball art repair remains in #506; neither is silently closed by this status. Native-phone checks remain where outstanding.

**Progress record (2026-10-06; branches now landed):** the sim half was #467 and the view half #471; the baseline audit (`setshot_impl`, #463) is the before. Event contract: every event a set-shot call produces carries `"choice"` (shoot, pass or bomb), and its result also carries `"setshot": true`. A pass records a `"pass"` event, then either a rebound (intercept) or a `"receive"` mark with the teammate 15 m nearer goal (10 to 30 m out) shooting from there. A bomb records one `"pack"` event at the goal square with an `"outcome"` of marked, spoiled (a crumber may gather and snap), defence or through. Pack odds come from the forward's marking against the best pack defender. The AI never gets the call. The baseline audit (`setshot_impl`, #463) is the before.  

**Director decision (2026-10-06):** "should be 3 visibly different sequences, but also add a pack contest, also gives an opportunity for a crumber to pick up a spoiled ball if it is not marked."

**Scope:**
1. **Record the choice.** Put the choice (shoot, pass or bomb) and the teammate's id on the resulting score or rebound event; today `m["choice"]` stays on the decision (MatchSim.gd:3636).
2. **Pass:** emit the pass and receive actions that are already resolved, without double-counting the disposal. The teammate shoots from his own spot.
3. **Bomb:** becomes a real goal-square pack contest:
   - a forward marks and shoots;
   - or it's spoiled, and a crumber can gather and snap;
   - or the defence marks or rebounds;
   - or it goes through untouched.
   Recalibrate against today's bomb goal rate so the choice keeps its trade-off.
4. **Presentation (under M8-003):** three distinct sequences from these events, with no invented actors or stats.

**Calibration targets** (every number sourced in `docs/research/SET_SHOT_EVIDENCE.md`, #456):
- **Set-shot conversion by distance, against general-play shots** (ABC / Champion Data, 2021 to 2025, straight on): 0 to 10 m 100% against 89%; 10 to 20 m 96% against 63%; 20 to 30 m 85% against 51%; 30 to 40 m 71% against 38%; 40 to 50 m 54% against 39%; over 50 m 33% against 34%. The set-shot edge holds to about 40 m and is gone beyond 50 m. By distance alone: 97% at 0 to 15 m falling to 36% at 50 m and over.
- **Set shots are about 55% of shots** (54% in 2025), from the Champion Data counts of players with 10 or more games.
- **Crumbing rates by position** (2026 per game, Wheelo/Champion Data): general forwards 1.16 crumbing possessions and 33% of their ground-ball gets; mid-forwards 1.09 and 23%; midfielders 1.09 and 20%; key forwards 0.66 and 29%; key defenders 0.71 and 26%; ruck 0.48 and 14%. Key defenders spoil 4.93 a game, key forwards 0.99.
- **To measure in the sim, no real target:** how often a set shot is played on rather than kicked from the mark, how often a long one is bombed into the pack, and the marked, spoiled or to-ground split of kicks into a pack. No public source gives these (the evidence doc lists them as not found), so the sim reports its own rates and the choice keeps its trade-off against today's bomb goal rate.

## ARD-M4-014 — Kick lanes that matter (corridor, switch, down the line)
**Status:** `TODO` · **Priority:** `P2` · **Autonomy:** `SUPERVISED`

**Director decision (2026-10-06):** lanes are recorded **and** affect play, not presentation only.

**Scope:**
- MatchSim picks a lane for each kick (corridor, switch, down the line), weighted by the gameplan: Attack corridor goes through the middle more, Controlled tempo switches and resets, Defensive press goes down the line.
- A lane changes that kick's risk and reward, e.g. corridor gains more but turns over into open space.
- It replaces part of the plans' flat multipliers, so effects aren't counted twice.
- The director draws the recorded lane, so the random 10% "switch of play" goes.
- Recalibrate plan balance and the counter triangle.

**Dependencies:** M8-003 tactical timeline. Merge the plan names first (below).

## ARD-M4-015 — Six gameplans, not eight names
**Status:** `DONE` — merged in #479; current `PLAN_ALIAS`/`plan_key`, CoachReport and saved-plan migration consolidate fast/press into attacking/defensive; seeded equivalence regression is present · **Priority:** `P2` · **Autonomy:** `SAFE`

**Director decision (2026-10-06):** merge the duplicates. "Fast movement" becomes Attack corridor and "High press" becomes Defensive press; they're the same effects under older names (MatchSim `PLANS`, `PLAN_UPSIDE`, CoachReport). Old saves map across on load. No gameplay change.

## ARD-M4-016 — Match-day weather: perfect day, wet, windy, hot
**Status:** `PARTIAL` — the condition/forecast/effects/trait foundation (#449) and weather visuals (#473) are on main; wet-weather long-sleeve integration and outstanding native-phone evidence remain · **Priority:** `P1` · **Autonomy:** `SUPERVISED`
**Implementation reconciliation (2026-10-07):** `Weather`, `MatchSim.WEATHER_RATES`/plan fit/breeze/hot fatigue, Hub forecast, wet-weather trait and `VignetteWeather` are implemented and have regression coverage. Do not create another weather system. Scope 6's long sleeves remain with open kit work (#368 or its verified successor); preserve any unmet finer acceptance/calibration below.

**Progress record (2026-10-06):** wet is calibrated in #449: scoring down 5 to 6%, marks down 14%, clangers up 10%, one-percenters up 15%, accuracy down about 2 points; tackles are up 6% against a real 12%, documented. The look and the Hub forecast follow the director's decisions below.  

**Director decisions (2026-10-06):**
- Rain affects play, calibrated against real stats, and has a look.
- Conditions: perfect day, wet, windy and hot.
- "Certain gameplans should work better in certain weather: contested footy is better in the wet as it's less precise; in dry weather ball handling is easier and it's easier to mark the ball."
- The forecast is known during the week.
- Windy has a breeze end per quarter.
- A visible "Wet-weather player" trait.
- Long sleeves: about 15% of a list wear them, up to 25% in the wet.
- **Director decision (2026-10-08, #522):** the long-sleeve look is approved: the guernsey's top runs over the shoulder (a yoke or stripes), the sleeve below is the base colour, no bare shoulder. Sock hoops approved as shown (off until a kit sets them).

**Evidence:** docs/research/WEATHER_EVIDENCE.md, the lead's own research and conclusions.

**Scope:**
1. **One condition per match,** seeded by venue and month from the real frequencies. Docklands is always a perfect day.
2. **MatchSim effects through existing keys,** calibrated to the evidence ranges:
   - wet: marks about −13%, contested possessions +7%, turnovers +11%, a small accuracy drop, and contested ball weighs more in the result;
   - windy (20 km/h or more): fewer marks, more turnovers, lower accuracy, and a breeze end that swaps each quarter;
   - hot: freer early, with heavier legs late.
3. **Plan fit by condition:**
   - wet favours Win contest and Defensive press, and hurts Attack corridor;
   - windy favours Controlled tempo;
   - hot favours Attack corridor, and Defensive press fades;
   - a perfect day favours Attack corridor and Controlled tempo.
   It's a rule the player can look up, not a recommendation label.
4. **Forecast on the Hub during the week,** as a fact. The coach report and Stat Guide state each condition's rule in words.
5. **The trait "Wet-weather player":** generated players and evidence-backed real players; it only matters when wet.
6. **Look (with the art agent and the existing scenes):**
   - rain on the pitch and vignettes;
   - wind in flags and banners;
   - heat haze and hard shadows;
   - long sleeves per player (#522, which replaces #368; look approved 2026-10-08).
   Zero result effect from the look itself.

**Validation:**
- seeded batches per condition against WEATHER_EVIDENCE: scoring, marks, contested share, turnovers, accuracy;
- the plan-by-condition matrix shows the intended edges with no dominant plan;
- determinism;
- old saves load as a perfect day.

## ARD-M5-001 — Matchday squad: 18 + 5 interchange
**Status:** `DONE` — merged in #331 (`11e2f13`, 2026-10-06).  

**Implementation record (2026-10-06):**
- **Squad:** `Ratings.INTERCHANGE := 5`, the match-day 23, no substitute role. Auto and AI selection pick 18 + 5, the Team screen has five bench slots, and an older save with four named on the bench keeps them and gets a fifth on match day.
- **Bench make-up (auto/AI):** a forward, a defender and a midfielder first, then the best of the rest. Without it a midfielder relieved every tired forward, and crumbed goals by forwards fell below real (caught by match_game).
- **Dual ruck (director):**
  - Your call: 'One ruck / Dual ruck' on the Team screen, off until chosen, saved across seasons. With it on, your second ruck takes a bench spot.
  - AI clubs run it by rule: when their spare ruck is within 5 OVR of the bench player he would replace.
- **All-Australian team:** 23 (director).
- **Wording:** best 22 becomes best 23 for the selected side, in the game's text and the docs. Dated evidence docs are left alone.
- **Evidence:** `tools/audit/interchange_impl.gd`, run on GitHub (runs 37395368728 and 37395371529). The same 8 careers × 3 seasons a side, 18+4 (the old bench rules, `RULES=0`) against final 18+5, per team-match:
  - goals 11.86 → 12.01, disposals 371.1 → 371.4, tackles 63.5 → 63.5, inside 50s 50.1 → 50.2;
  - interchanges 41.1 → 47.0, players who took part 21.87 → 22.87;
  - distance per player 13.22 → 12.62 km, injuries 0.80 → 0.84;
  - in-season OVR rise +3.90 → +3.88, off-season OVR change −3.91 → −3.87.
  - The fifth player plays and the running is shared; scoring, stats and development hold. No recalibration.
- **Tests:**
  - selection 33 (`_test_fifth_interchange`: all five come on and take part, the fifth earns a selected player's XP, a 4-man saved bench fills to 5; `_test_dual_ruck`); roles 23; awards 23.
  - match_game: the boundary-free and Through-stars samples were widened (16 and 40 matches). They had sat on a one-event or two-SE margin; the medium agent diagnosed it.
  - Calibration, workload, balance, injuries, pressure, matchday, save and career_ui pass locally.

**Was:** `TODO`  
**Priority:** `P0`  
**Autonomy:** `SUPERVISED`

**Director priority (2026-10-06):** Implement this next ahead of unrelated feature expansion and presentation work; urgent crash/save blockers still take precedence. This is an existing task promoted to priority, not a new duplicate.

Before #331 (verified 2026-10-06): `Ratings.gd` defined `INTERCHANGE := 4`, `SelectionScene.gd` rendered four bench slots, and selection tests expected 18 + 4. The migration below is what #331 delivered.

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

Acceptance:
- Manual and auto/AI selection produce 18 on ground + 5 interchange (23 total) for both teams, and the UI exposes all five bench slots.
- The fifth player participates correctly in rotations, injury cover, match stats, XP/development and appearance/played-game tracking; no cosmetic-only extra slot.
- Remove or update every relevant hard-coded 22-player/four-bench assumption, including tests and saved-squad compatibility, without losing existing save information.
- Validate the squad migration with targeted selection/rotation tests and the required CI gates; use the existing balance-audit process for any resulting simulation effects.

---

## ARD-M5-002 — Visual oval/team-shape selection
**Status:** `DONE` — merged in PR #194. The §9.1 playtest asks for Shape to become a functional selection surface; that is follow-up work, not this item. _(reconciled 2026-10-05)_  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`
**Depends on:** stable role semantics. The fifth interchange player (M5-001) is a separate follow-up; #194 intentionally preserves the current bench size.

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
**Status:** `DONE` — learning a position as a bounded development project (the director's ARD-RC-003 pick), with the Unicorn, merged in #266 (2026-10-06). Phone feel and balance measurement remain with the director. Made to matter (2026-10-06, merged in #379): learned positions compete on merit in the auto-pick, a learned position pays back next season inside POT, and the in-season price is smaller.  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

This is the canonical item for the user's previously requested secondary-position training/retraining.

- Sustained use/training at a plausible secondary role can improve suitability.
- Respect body/skill/archetype plausibility.
- Do not allow universal retraining.
- Progress should be visible but low-admin.
- Position learning should affect selection fit, not magically rewrite unrelated attributes.

### Research refinement — 2026-10-05

**Dependencies:** current Roles/M5-009 classifications, training/development and save persistence.

**Smallest scope:** one plausible secondary role; sustain a visible training/usage commitment using the existing progression system.

**Exclusions:** universal retraining, instant new archetypes, guaranteed POT fulfilment, extra weekly chores or the unselected development-project candidate.

**Acceptance:** suitability improves without rewriting unrelated skills; physical eligibility remains credible; the time/usage cost is clear; progress survives save/load and remains distinct from current form. A player can gain another useful job without becoming best at everything.

**Validation:** eligible/ineligible bodies, interruption and save/resume, selected/omitted usage and multi-season growth comparisons. Phone players can explain what is being learned and what they give up.

### Implementation record — learning a position (2026-10-06, branch `claude/dev-project`)
The director chose ARD-RC-003 (a bounded development commitment with an opportunity cost) and placed it here.
- **The project:** a "Learn to play <job>" training plan. For 8 fit weeks his XP trains the new position's game (injured weeks do not count). At the end he can be picked there if his rating there is within 3 of his own; otherwise it has not taken. One project per player a season, two at a time per club. Switching plan ends it and spends that season's chance.
- **Who may try (director):** a plausible move only (his rating there within 6 of his own). The job follows his size: key forward from 192 cm, small forward up to 181 cm, key defender from 191 cm, ruck from 196 cm. POT 70+ for a second position and POT 90+ for a third (raised from 85 by the director after the first audit, so Unicorns stay rare).
- **The price, stated exactly:** from the day he starts, training in his own position can lift him only 2 more that season (3 in a normal season; 1 until 2026-10-06). **The payback:** the season after he learns a position, his training limit is 1 higher, never past his POT; and the auto-pick plays him at a learned position whenever he rates higher there than the line's weakest starter (director, 2026-10-06: projects must have an impact). The new position's training still helps his own game where the two overlap.
- **The Unicorn (director):** a player who can be picked at forward, midfield and back earns the Unicorn trait. On the ground he fills one missing place in one synergy (the first in rule order that he completes, in his line for a line synergy), never two.
- **Rival clubs (director):** each runs one project a season, on its highest-POT candidate, by the same gates and weekly rules, with no news items.
- **Endings:** a move to another club ends a project (the season's chance stays spent); a project still running when the season ends is judged where it stands. A learned third position counts wherever positions matter in a match (ruck contest, bench replacements, midfield checks). Its trade value waits for #228 (no trade-valuation changes until it is settled).
- **Seeded evidence** (`tools/audit/devproj_impl.gd`, seeds 21–24, Melbourne and Geelong, 3 seasons, both project places kept busy):
  - About 7 projects in a club's first season, then 0–1 a season, as eligible players run out of second positions. About 88% pass (about 94% for rivals); failures come from the longest moves.
  - Own rating over the project season: +2.2 against +3.0 for eligible team-mates aged 27 or under on the club plan, so the project costs about 0.8 OVR against team-mates. Paired with his own no-project self the cost is about 0.2 OVR in the project season and it pays back +0.4 to +0.56 OVR two seasons on (`docs/research/LEVER_TRUTH_AUDIT.md`, development projects, runs 37928374658, 37928378497, 37928382115).
  - Unicorns: 3 of 8 user careers had one by season 3 (8 of 8 at POT 85); 3–5 league-wide, about one per 4–6 clubs. Rival clubs make 13–17 projects a season at first and nearly all pass.
  - Once a side has a Unicorn, he completes a synergy in about 60% of weeks (median 20 of 29). This is the director's wildcard rule; rarity is the control.
- **Open levers (not changed):** pass margin (3), reach (6) and the cost against team-mates (measured as 0.2 OVR against the same player, see above). If play shows projects are too sure a thing, tighten the pass margin first.
- **Tests:** `test_training.gd` covers size jobs, POT gates, the club limit, injured weeks, the price, the Unicorn and wildcard, and rival projects; `run_roles_tests.gd` covers selection at a learned position.

**\* Claude to refine — development conversations (user-approved, 2026-10-06):** Connect existing training/retraining plans to short private player conversations and later factual follow-through. Discuss a plausible football goal and any explicitly agreed playing opportunity; later acknowledge the actual trial, continued development or changed plan. Reuse existing training, positional-learning and commitment rules; this adds personal continuity, not a new progression system or guaranteed success. Claude should refine the smallest useful scene, triggers and callback within existing development/player-dialogue work, preserving clear obligations and accurate save/load behaviour.

---

## ARD-M5-004 — Training multi-select
**Status:** `DONE` — long-press group selection and shared valid plans merged in PR #192.  
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
**Status:** `PARTIAL`  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

Players omitted from the senior side should still develop at a reduced rate.

- No playable reserves competition.
- No reserves fixture/tactics/selection screen.
- Reuse existing XP/development systems.
- Senior AFL remains the best development environment.
- Availability rules still apply.

Balance omitted-player growth against selected senior players over multi-season sims.

### Research refinement — 2026-10-05

**Dependencies:** current XP/development, availability and normal season rollover.

**Smallest scope:** verify existing reduced-rate omitted-player progression, then repair only an evidenced missing path or imbalance.

**Exclusions:** playable reserves leagues, extra selection/fixture screens, guaranteed youth improvement or reserve-stat fabrication.

**Acceptance:** healthy omitted players have a credible path to usefulness; senior opportunities retain value; injured/suspended cases obey existing availability rules; the player can distinguish passive growth from senior performance and other training.

**Validation:** matched age/role/potential cohorts selected, omitted and injured over several seasons; stable identity and save/resume; check both stagnation and runaway growth. Observed sessions assess anticipation and selection trade-offs, not only XP.

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

### Research refinement — 2026-10-05

**Dependencies:** trustworthy M2 statistics, current Roles, Awards/CoachReport and existing form handling.

**Smallest scope:** compare one defensively useful low-disposal performance with role peers before broadening recognition.

**Exclusions:** invented contribution statistics, a new ratings engine by accident, automatic praise or awarding every player a story.

**Acceptance:** defenders, rucks, forwards and mids can earn recognition through actual relevant contributions; quiet or poor matches are not disguised; the recognition/form rule is understandable and uses the real job played. Check older specialists as well as prospects.

**Validation:** seeded role fixtures and different squad compositions; bias/overlap with existing awards and backing recognition; save/history consistency and Android comprehension. A useful non-star should be recognisable without being rated as an elite all-rounder.

---

## ARD-M5-009 — Player role/archetype identity sanity
**Status:** `DONE`  
**Merged:** 2026-10-01 — role allocation/direct-land reconciliation from PR #147.  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

Role labels should match actual football identity.

Known sanity examples:
- George Wardlaw should not read like a wing when his game is heavily contested/on-ball.
- Harvey Langford should not be forced into "inside mid" because of crude weighting if his usage is much more tall/goal-scoring wing.

### Direction
Validate labels against real role evidence and in-game usage.

Do not manually patch only famous names if the classifier itself is wrong.

### Role-identity implementation record (2026-10-01)
- Club-listed forward/defender identity now wins over a misleading MID classification unless the player's own clearance and listed-line evidence says he is genuinely a midfielder.
- Key defenders require key-position size; short stopping defenders no longer read as key defenders.
- Wing identity now also recognises genuine outside players with low clearance volume and low contested share, covering Harvey Langford/Xavier Duursma-type usage without turning contested mids into wings.
- Position rating anchors/harnesses were recalibrated to the corrected role population, with regression coverage for named sanity cases and league-wide positional depth.


---

## ARD-M5-010 — OVR should predict football strength
**Status:** `DONE`  
**Merged:** PR #80 as `69955d03`; verified on main 2026-09-28.  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

Overall rating should be meaningfully aligned with what Squad/MatchSim reward.

### Implementation record (2026-09-28, branch `claude/ovr-predicts`)
- **Measured:** margin per OVR point by position. A median and a 98th-percentile player of each position replaced a side's weakest selected player of that position (600 matches per condition, same seeds). Forward 63 to 87: +8.7 points (0.36 a point). Ruck 62 to 89: +7.5 (0.28). Defender 63 to 86: +3.7 (0.16). Mid 62 to 89: +4.0 (0.15). The per-condition noise is about 1.4 points.
- **Cause:** not the forward core weights but the position scale. The forwards' 98th percentile was placed 85% of the way to the midfield one, while the engine says an elite forward is worth at least an elite mid.
- **Change:** the forward 98th-percentile target equals the midfield one (73.42 to 78.04) in `Ratings.gd`, `tools/sim_harness.py` and `tools/intake_harness.py`. Medians and the low tail are unchanged. Greene 79 to 82, Cameron 77 to 79, the best forward 88 to 92; forward p90 79 to 82. Salary value and selection follow from OVR. `data/player_history_2026.csv` (past seasons for POT) carries only the change this makes: 153 forward season ratings across 66 players rise, and nothing else moves. A fresh page fetch also showed unrelated source drift (non-forward ratings, one relinked player), which is left out here.
- **Not changed:** rucks measure high per point too (0.28) but keep the 85% ceiling: there are only 46 of them and play has shown no problem. The same lever applies if it does.
- **Tests:** ratings, potential and intake suites pass (every position's best in the mid 80s, medians together, monotonic scale).

### Current calibration notes
- PR #47 deliberately re-measured forward/midfield OVR against MatchSim rather than hand-tuning famous players.
- Do **not** revert the pressure/OVR work merely because individual headline ratings moved.
- User sanity target: Toby Greene at 79 after #47 still reads a little low; expect roughly **low 80s** if the broader model supports it. Treat this as a calibration spot-check, not a manual one-player buff.
- No special McKay correction is requested from the #47 movement; investigate only if the wider OVR model says the player is mis-valued.

### Guardrails
- Diagnose measurement first.
- Prefer fixing Ratings/OVR interpretation before changing MatchSim merely to force correlation.
- Validate impacts on salary, POT, value, awards, selection and drafting.
- Preserve role-specific value; one generic OVR should not erase archetypes.
- Named-player sanity checks are evidence, not the model. Fix the general cause where possible rather than building a patch list of famous names.

### Director follow-up — career-stage OVR economy

**Status:** `TODO / BALANCE-GATED` — phone playtesting shows the current OVR economy can make brand-new high-POT rookies look immediately better than too many established AFL players.

The intended shape is:
- **high-potential youngsters should generally enter with more development headroom:** a high POT prospect can be exciting without already carrying an established-pro OVR;
- **most genuinely established veterans/pros should read slightly stronger in current OVR than they do now when their demonstrated senior performance supports it;**
- POT is future ceiling/upside, not permission for current OVR to collapse toward POT at draft generation;
- exceptional young players may already be excellent, and declining/poor veterans may genuinely be weak. Do **not** apply a blind age bonus/penalty.

This is a league-wide calibration problem, not a request for hand-authored veteran buffs. Claude should first measure OVR/POT distributions by career stage and source senior experience, then identify whether the distortion comes from generated rookie starting attributes, real-player rating normalisation, age/development assumptions, or several of those together.

Required audit:
- compare National Draft rookie OVR/POT distributions against established 24–28 and veteran 29+ players by position/role;
- inspect how often first-year rookies immediately outrank proven regulars and veterans in the best side before any development;
- separate genuinely elite ready-made prospects from ordinary high-upside projects;
- check whether established players with multiple seasons of credible AFL production are being compressed too low by the ratings model;
- verify that lowering rookie starting OVR does not accidentally lower their POT or long-term ability to become stars;
- verify that any veteran/pro correction reflects demonstrated football ability rather than age alone.

Acceptance:
- a high-POT draftee usually looks like **future value plus development headroom**, not an instant established star;
- the majority of competent established AFL players are not routinely rated below unproven new draftees;
- rare AFL-ready top prospects remain possible and visibly special;
- weak/declining veterans can still be weak;
- career progression has a believable arc from prospect → established player → decline rather than beginning near the finished product;
- salary, selection, draft AI, trade value, development rate and long-save list turnover remain coherent after recalibration.

Keep ARD-M5-010's original match-strength correlation requirement intact: current OVR must still describe current football strength. Do not solve this by making OVR lie about MatchSim strength or by adding a cosmetic age modifier.

---

## ARD-M5-011 — League Draft career-stage filters
**Status:** `DONE` — merged in PR #208. _(reconciled 2026-10-05)_  
**Priority:** `P2`  
**Autonomy:** `SAFE`

### Intent
Make the opening League Draft easier to browse by career stage, so the player can quickly build around youth, prime-age talent or experienced veterans without manually scanning ages.

### UX
Add an age/career-stage filter to the **opening League Draft**:

- **All**
- **Rookies**
- **Prime**
- **Veterans**

Use natural player-facing labels rather than raw implementation bands.

The exact age cut-offs are **not locked yet**. An initial candidate is:
- Rookie: roughly 18–23,
- Prime: roughly 24–28,
- Veteran: roughly 29+.

Before implementation, inspect the actual 2027 League Draft age distribution and choose cut-offs that produce useful, reasonably populated groups. Do not contort the data just to preserve those example numbers.

### Behaviour
- Filtering changes only which players are shown; it must not alter draft eligibility, rankings, AI behaviour, cap logic or availability.
- Combine cleanly with existing position/search/filter controls.
- Preserve the selected filter while inspecting a player and returning to the draft list.
- Mobile-first: the control should remain compact and tappable without adding a dense filter bar.
- If exact age is already shown elsewhere, do not duplicate it unnecessarily on every row just because this filter exists.

### Tests
- every eligible player appears in exactly one non-All career-stage band,
- boundary ages route to the intended band,
- switching bands never changes the underlying draft pool,
- existing position/search filters combine correctly,
- Back/profile navigation preserves the selected band,
- narrow Android portrait remains usable.

Implementation in #208 keeps this as a view-only opening-League-Draft filter. The 2027 pool supports clean **18–23 / 24–28 / 29+** bands (252 / 248 / 169 players respectively), exposed as **Rookies / Prime / Veterans** inside the existing advanced filter area. It does not touch draft eligibility, AI valuation, cap logic or National Draft scouting.

---



## ARD-M5-012 — Draft AI asset valuation sanity
**Status:** `DONE` — implemented in #148; top picks prioritise long-term asset quality, with need/scarcity used for close calls.  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

### Triggers
Two separate phone-playtest cases now show that AI draft ordering can become implausible in opposite directions:
- **Opening League Draft:** Bodhi Uwland was selected at pick #1. He can reasonably be a good AFL player, but that result is implausible enough to audit the established-player valuation model rather than manually changing him.
- **2027 National Draft:** **Sora Crinkle, projected 78 OVR / 92 POT, was still available at pick #30** while clubs had already selected prospects with potential in the low 70s. Barring an extreme, visible reason (major injury/character/scouting uncertainty etc.), a prospect with that combination of current ability and ceiling should almost never slide that far.

### Current implementation lead
The National Draft is **not** currently producing this through club scouting error: `_eval_error()` returns zero in `intake_mode`. Intake valuation already weights POT heavily (`AI_POT_WEIGHT_INTAKE = 0.65`), but the final candidate score is then multiplied by `_need_weight()`. Once a club considers a position surplus, that multiplier can fall to **0.2**, meaning even an exceptional prospect can be heavily suppressed purely because the club thinks it has enough players at his position. Treat this as a strong diagnostic lead, not a predetermined fix.

### Intent
Make both the opening League Draft and annual National Draft value players as long-term dynasty assets without becoming deterministic or ignoring legitimate list construction.

### Scope
Audit repeated seeded drafts and inspect:
- current ability;
- age / remaining career runway;
- potential and development upside;
- positional value/scarcity;
- list need where appropriate;
- salary/cap cost where relevant;
- value-over-replacement / expected availability at the club's next pick;
- whether list-need multipliers can overwhelm obvious best-available talent.

For the National Draft, explicitly chart where the top 5/10/20 prospects by shared talent/worth are actually selected across many classes. Manually inspect major sliders and reaches.

Do **not** special-case named players/prospects to manufacture plausible order. Fix the valuation model.

### Guardrail — best available vs need
List need should influence close decisions and explain sensible reaches, but it must not routinely make clubs pass on elite talent for marginal low-ceiling prospects. Early/high-value selections should lean strongly toward **best available long-term asset**; need can matter more as talent gaps narrow or later in the draft.

If an elite prospect falls dramatically, the game should have a legible football reason — e.g. genuine injury concern, severe scouting uncertainty, role/body concern — rather than an invisible `0.2` multiplier.

### Acceptance
- Repeated opening League Drafts produce broadly credible top-end selections without becoming deterministic.
- In annual National Drafts, prospects in the very top band of both OVR and POT almost never survive to pick ~30 absent a documented adverse factor.
- A 78 OVR / 92 POT prospect is not passed over for low-70s-ceiling prospects merely because clubs already have nominal positional coverage.
- Elite young/high-upside cornerstone players are valued appropriately against good established players.
- Veterans and role players can still rise when their quality/context warrants it, but obvious outlier #1 reaches are rare and explainable.
- Need/scarcity can move players within plausible bands without overpowering major talent gaps.
- AI clubs continue to obey the same cap/list rules as the player.
- Measure before/after top-30 composition across deterministic seeds and check that any weighting change does not create a new age, position or potential monoculture.



## ARD-M5-013 — Potential ceiling semantics audit
**Status:** `DONE`  
**Merged:** 2026-10-01 — projected-peak/development-parity work from PR #156, reconciled directly onto current main.  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

### Final implementation (2026-10-01)
- POT means a player's **projected natural peak**, not a hard cap and not a value that rises merely because OVR overtakes it.
- Human and AI players now earn/develop under the same underlying rules; difficulty no longer gives either side hidden development-rate or XP advantages.
- Training gets progressively dearer near and beyond POT, with the same seasonal training ceiling for every club.
- Rare fresh breakout rolls can push a player meaningfully beyond his original projection; these are recorded as career development stories rather than predetermined hidden destinies.
- League re-anchoring moves POT on the same rating scale as OVR, preserving projection headroom without silently ratcheting POT up to current OVR.
- Regression coverage now checks drafting/POT stability, at- and past-POT training, breakouts, AI/human parity, difficulty parity and balance-harness scaling.

### Trigger
Phone playtesting after the first season shows several players with **OVR above displayed POT** (for example Jordan Sweet 76 OVR / 70 POT, Zac Bailey 75 / 73, Karl Amon 73 / 70, Ryan Lester 70 / 63). This is currently possible by design, but the presentation reads as contradictory: if POT means “the overall rating a player can grow into”, a player already above it makes POT look wrong or secretly dynamic.

### Current implementation reality
- `Potential.assign()` creates a seeded POT intended to be stable for that player.
- Natural off-season growth pulls toward POT and stops once the gap closes.
- Rival XP spending explicitly stops at POT.
- **The user's manual training does not stop at POT**; `_spend_with_weights(..., stop_at_pot=false)` may push OVR above it, with `Potential.training_multiplier()` making post-POT training 50% more expensive.
- Rating-formula migrations can also lift POT alongside a recalculated OVR on load so old saves do not become internally inconsistent, but ordinary in-career training does not raise POT.

So OVR > POT is **expected under the current rules**, not necessarily a save corruption bug. The problem is whether those rules and the word “Potential” are the right design.

### Audit question
Decide what POT should mean in a long-save dynasty game before changing numbers. The user's current preference is that POT should remain **stable/static**, but development should have enough bounded uncertainty/headroom that careers do not feel pre-written.

Compare at least these models with multi-season evidence:
1. **Hard static ceiling:** OVR cannot exceed POT. Simple and legible, but risks making development deterministic once POT is visible.
2. **Static expected ceiling + bounded overachievement:** POT stays fixed as the player's expected peak, while exceptional development/training can exceed it by a small, explicitly bounded amount. If used, the UI wording must make clear that POT is a projection rather than a hard maximum.
3. **Mutable POT:** development events change the ceiling itself. This is currently *not preferred* because it makes the displayed number unstable and can turn “potential” into a second OVR, but include it in the audit as a control rather than assuming it is forbidden.

Questions to measure:
- How often and by how many OVR points do user-trained players currently exceed POT?
- Does the player-only ability to train past POT create an unfair long-save advantage over AI clubs, which currently stop at POT?
- Do low-POT veterans become artificially improvable simply because the user can spend enough XP?
- How much unpredictability is needed so a 70 POT prospect can still have a memorable breakout without making POT meaningless?
- Should POT remain directly visible, become a range/qualitative estimate, or be renamed if it is an expected ceiling rather than a maximum? Avoid adding uncertainty UI unless it materially improves decisions.

### Acceptance
- POT has one consistent, player-understandable meaning across draft, list, training, contracts and trade value.
- OVR > POT is either impossible, or deliberately rare/bounded and clearly explained by that meaning.
- User and AI development obey equivalent ceiling/headroom rules unless an explicit difficulty rule says otherwise.
- Multi-season development distributions remain plausible: young high-upside players improve meaningfully, late bloomers/breakouts remain possible, veterans do not become endlessly trainable, and league OVR does not inflate.
- Save/load and rating-formula migrations preserve the chosen semantics.
- Add regression coverage for below-POT growth, at-POT behaviour, any allowed overachievement, age decline and AI/player parity.


## ARD-M5-014 — National Draft decision support, combine & list-need clarity
**Status:** `VERIFY` — list-need strip (#150), recruiting meeting (#152) and Combine/scouting uncertainty (PR #188, closed and carried by #208) are all on `main`; a phone draft playtest remains. _(reconciled 2026-10-05)_  
**Priority:** `P1` — **HIGH director priority (2026-10-07)**; the complete navigable Combine menu is an integral part of the post-season → scouting/Combine → National Draft flow, not optional polish. Schedule ahead of lower-priority features and cosmetic work, while preserving the Stats patch as the single highest-priority item.  
**Autonomy:** `SUPERVISED`

### Trigger
The 2027 National Draft currently presents a long pool of names plus OVR/POT and a position strip, but the user still feels under-informed about *why* to consider particular prospects. The position strip is itself confusing: examples such as **“FWD 9 / 14 can play / NEED +5”** and **“MID 15 / 17 can play / COVERED”** do not read as one coherent model and do not appear to change in the intuitive way as players are selected.

### Current implementation reality
The contradiction is structural, not just copy:
- `role_coverage()` counts a dual-position player in **every** role he can play;
- `position_needs()` uses a slot-matching pass where each player can fill **only one** target slot.
So “14 can play FWD” does **not** mean 14 forward slots are actually covered, because some of those same dual-role players may be required elsewhere. The screen is showing two different counting semantics side by side without explaining the distinction.

### List-need presentation
Replace the current `count / can play / NEED +x / COVERED` language with one coherent, football-readable composition model.

Requirements:
- one primary answer per line: what the list currently has and whether it is genuinely short in that area;
- dual-role flexibility may contribute to coverage, but do not double-count the same player in a way that makes the headline self-contradictory;
- after every selection/release, the displayed need state must visibly and deterministically update;
- distinguish **mandatory structural shortages** (e.g. not enough usable rucks / cannot field the required shape) from softer recruiting guidance/depth;
- do not tell the player the “correct” position to draft or automatically rank prospects by need;
- on phone, prefer a short label such as `Forwards: short 2`, `Midfield: covered`, `Ruck: one more needed` over stacked implementation counts.

Add targeted UI/tests proving the labels change after a relevant pick and that a dual-role player is never presented as simultaneously solving two mandatory slots.

### Pre-draft coaching/recruiting meeting
Before the National Draft begins, add a short **pre-draft meeting** with the coaching/recruiting panel. Its job is to give the player a starting mental model, not solve the draft.

It can summarise:
- what the current list already does well;
- genuine structural/depth holes;
- age/profile issues worth being aware of;
- a small handful of scouted prospects who may be relevant;
- why each named prospect caught the recruiting staff's eye, in football terms.

Examples of useful language:
- “We have enough inside mids, but we're light for genuine outside run.”
- “We only have two credible rucks on the list.”
- “Recruiting liked the marking and forward craft of X.”
- “Y tested well athletically, but we're less certain about his football production.”

Guardrails:
- typically surface only a few names, not a ranked top-20 shopping list;
- different scouting quality/knowledge can change how much confidence/detail the panel provides;
- never label one prospect as the objectively correct pick;
- allow disagreement/uncertainty where appropriate;
- the meeting should remain useful even when the user's next pick is late in the round.

### Draft combine / scouting information
This is the canonical Combine menu owner. Extend the existing Combine/scouting implementation carried onto `main` by #208; do not create a duplicate Combine task or assume the complete menu below already exists.

The Combine should give the draft pool more identity and evidence before selection:
- physical/athletic testing and relevant football testing where the game has meaningful underlying attributes;
- role/archetype clues, strengths and weaknesses;
- scouting uncertainty rather than exact omniscient ratings where appropriate;
- enough information to distinguish prospects with similar projected OVR/POT.

Do not make the Combine another number-vomit screen. Default to interpretable results/relative descriptors, with deeper detail available on inspection. Combine results should inform scouting, not override actual football production or make every athletic outlier a top prospect.

**Director clarification — fully navigable Combine menu (2026-10-07):** the Combine must be a complete, navigable menu with useful statistics, not just a static summary or isolated prospect popup. This expanded menu requirement is **TODO pending implementation/verification**, independently of the existing merged Combine/scouting foundation.

- Integrate the complete menu into the normal post-season/pre-draft flow under ARD-M6-007's existing off-season navigation owner, with clear timing and access before draft decisions; do not create a disconnected destination or duplicate transition system. Provide clear entry from the relevant pre-draft/off-season navigation, a browsable prospect pool, testing/statistics views and individual prospect inspection. Users must be able to move between these views and return cleanly to the same pool/filter/scroll state. Support desktop and phone with clear back paths and informative empty/unavailable-data states.
- Include meaningful Combine statistics/results for the tests the game actually models, with readable units, useful relative comparisons and sorting/filtering by relevant test, football position, role/archetype and prospect search. Connect prospect inspection to existing bio/scouting and recorded football production where available; distinguish measured testing, observed football statistics and uncertain scouting projections. Never fabricate missing results or imply that every physical test is a direct measurement of football ability.
- **Football information first; avoid number vomit.** Default to short, readable explanations of what a result suggests on the field: e.g. acceleration to separate from an opponent, repeat running to cover ground, or clean handling under pressure, only where supported by the actual test/mechanics. Show a few relevant headline results and strengths/limitations; let users deliberately open detailed statistics and comparisons rather than confronting a wall of figures or formulas.
- **Flavour copy is encouraged:** give the Combine a recognisable football voice through concise scout observations, prospect descriptions and testing-day colour. Keep copy grounded in actual results and scouting confidence, with restrained humour where appropriate. It must help users understand the footballer, without invented performances, guaranteed development, repetitive filler or prescribed best picks.
- Verify the full entry → pool → statistics/comparison → prospect → return flow, sorting/filtering, state restoration, accurate results/units and missing-data handling in regression checks and a runnable desktop/phone playtest. Do not mark the complete menu verified from a screenshot or the presence of a Combine popup alone.


### Acceptance
- list needs are internally consistent and visibly update after each relevant selection;
- the player can explain what the squad lacks without reverse-engineering `can play` vs `NEED`;
- the pre-draft meeting gives useful direction and a few names without prescribing the answer;
- prospect inspection/Combine provides enough evidence for a deliberate choice rather than “pick the biggest POT number”;
- mobile presentation remains fast to scan and does not become another dashboard.


### Post-draft handoff
The National Draft's own decision-support work ends when the selections are complete. The **off-season Ins/Outs summary, coaching movement recap and board-expectation reveal are owned by ARD-M6-007**, so do not build a second transition flow inside the draft screen.


## ARD-M5-015 — Workload across the campaign
**Status:** `VERIFY` — implementation merged in PR #154; native phone playtest remains the final follow-up.

**Priority:** `P2`

**Autonomy:** `BALANCE-GATED`

Explicitly assigned by the director: implement idea 4, carrying workload
between weeks so selection and resting a veteran before finals have consequences.

- Record actual on-ground effort in MatchSim, including rotations and extra time.
- Apply effort and automatic recovery once per completed week to every club.
  Omitted players, injured players and clubs with a bye recover without senior effort.
- Carry load into starting energy and the recovery ceiling during matches;
  preserve permanent ratings and existing injury odds.
- Show Fresh / Carrying a load / Needs a break in selection, with an explanation
  in the player profile. Existing manual selection and Out controls provide rest.
- Auto-pick weighs readiness alongside ability; manual choices remain available.
- Persist workload in career saves, default absent fields to fresh, and reset
  every club at the offseason transition.

Implementation: `scripts/sim/Workload.gd`, the shared end-of-week career path,
selection and player profiles. Regression suite: `workload` (32 checks).
Measurement: `tools/workload_probe.gd`; validation record in
`docs/WORKLOAD_VALIDATION.md`. Native phone playtesting remains a follow-up.

## ARD-M5-016 — Inherited-list career: 2026 National Draft start
**Status:** `TODO` — explicitly accepted by the director; documentation only in this pass.
**Priority:** `P0`
**Autonomy:** `SUPERVISED`
**Depends on:** §1.11 correctness/phone gate; M1-010's merged chronology; the usable M5-014 National Draft/scouting foundation and M6-004 contract/pick persistence; a verified complete roster/pick manifest. Do not require unrelated parts of those umbrella tickets to be DONE. Full academy/father-son bidding is not a dependency.

**Director priority (2026-10-06):** Still missing on main; promote this to the next major career-start feature priority ahead of unrelated content/presentation expansion. Urgent correctness/save blockers and the already-prioritised five-interchange migration remain ahead; preserve the specific source-data, opening-draft and save prerequisites below without waiting for unrelated umbrella work to finish.

### Player benefit / smallest useful delivery
Choose a familiar club with its actual inherited playing group, shape its future through the 2026 National Draft, then play 2027. Preserve the League redraft as a distinct existing option. First build the source manifest and dedicated opening-intake handoff; connect setup and persistence only once those are credible.

### Scope

- New-career setup offers **League redraft** and **Inherit 2026 lists**. Choose one of the 18 founding clubs; all 18 retain their inherited groups in this mode.
- Use complete **end-of-season 2026 club lists, before subsequent offseason changes**, including registered players with zero senior appearances. Record the actual snapshot date/boundary and source dates; announcements/transactions after it must not silently alter this starting world.
- The current 669-player appearance dataset is not proof of registered-list completeness. Reconcile official club/AFL lists, primary roster announcements and existing enriched data; maintain existing player IDs and an explicit mapping for additions. Record per-club counts, omissions/conflicts and rating basis for players without 2026 appearances. No fictional fillers.
- Begin with preparation for the **2026 National Draft**, using the researched 2026 prospect cohort and sourced pick ownership/order corresponding to that snapshot. As of 5 October the real draft has not taken place; outcomes here remain the player's alternative history.
- Reuse the current National Draft framework, including its simplified order and club-tie rules. Source pick ownership without claiming the simplified draft implements every AFL regulation.
- Where list space is needed, present explicit pre-draft list decisions and resulting available places. Never silently cut inherited players, auto-empty a list or discard a pick/prospect to hide a full-list problem. Apply the same list-space rules to AI clubs; record their actual decisions.
- Identify simulated contracts as estimates, preserve real/fictional-name preference and reuse existing budget/scouting UI.
- Persist the chosen start mode, preparation state, list decisions, picks/ownership, draft progress and handoff completion. Older saves without the new fields retain their existing redraft/ongoing-career behaviour.

### Opening-draft lifecycle
Provide a dedicated opening-intake path. Current `begin_intake_draft()` expects a season context and completion normally invokes `_start_next_season()`; do not fake a completed 2026 season to satisfy it.

1. Initialise inherited ownership, estimates, scouting and 2026 opening picks/prospects without running a season.
2. Make list-space decisions, run the existing simplified intake and support save/resume at each stage.
3. Commit rookie ownership, contracts and ledger exactly once, then initialise the first playable **2027** season. GameDB already dates existing ages to 2027; do not repeat ageing, development, retirement or the 2026 career-history import. Existing real 2026 history appears once, with no simulated 2026 season.
4. After this one-time handoff, reuse normal seasons, contracts, development, subsequent drafts and scheduled Tasmania/Canberra expansion.

### Exclusions
No change to existing saves/redraft behaviour, full bidding reform, other historical start years, alternative league customisation, new economy, extra reserves competition or gameplay changes in the research PR. Do not mix the opening 2026 prospect class with a generated later-year class.

### Observable acceptance

- Before user/AI list decisions, every player in the signed-off roster manifest belongs to exactly one correct club, including zero-appearance players; every addition has provenance and a rating basis.
- Setup clearly identifies start mode, snapshot, draft year and first playable year.
- Full-list cases expose real choices and can complete the draft without silent loss or filler.
- Saving/resuming during preparation, between picks and at completion preserves choices/ownership and cannot double-assign a rookie, repeat history or advance the year twice.
- Existing players start with the correct 2027 age/history; 2027 produces the first simulated season record.
- Both starts reach normal later drafts, rollover, contracts, development and scheduled expansion.

### Validation
Data fixtures for roster completeness/unique ownership/source-date boundary, zero-appearance players, original IDs and sourced pick ownership. Test full-list decisions and insufficient-space handling; save/resume at every opening stage; repeated finish/reload; one-time rookie assignment/contracts/ledger; 2027 ages and imported history once; complete 2027 plus a subsequent normal rollover/draft. Include old-save fixtures and expansion. Check **both start modes on Android** for setup, scrolling, Back, list decisions and resumed draft flow. Keep a concise provenance record in DATA_SOURCES.md when implementing.

---


