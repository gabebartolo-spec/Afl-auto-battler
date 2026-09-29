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

## 0.2 Design philosophy — fun and agency over simulation purity

**Aussie Rules Dynasties is a game first and a simulation second.** Football realism matters because it makes decisions understandable and the world believable, but realism is not a reason to preserve passive, opaque or unfun play.

Do **not** be afraid to gamify football systems when doing so creates meaningful player agency. The player should be able to read a problem, make a deliberate choice, and materially influence what happens next. A good decision does not need to guarantee a win, erase list quality or produce an exaggerated arcade effect, but it must have enough leverage that the player can reasonably feel and learn from its consequences.

When realism and agency genuinely conflict, prefer the design that is **more fun and gives the player more meaningful control**, provided it still reads as Australian football. Do not preserve simulation purity merely because it is more realistic.

This principle applies especially to tactics, match-day decisions, list construction, training and other systems where the player is expected to make choices. If a system is realistic but the player's choices barely matter, treat that as a design problem rather than a successful simulation.

### Party-based RPG lens

The game should retain the uncertainty and emergent outcomes of a football simulation while creating some of the attachment and agency of a party-based CRPG. **The club is the campaign; the playing group is the party; matches are where that party is tested.**

This is a design lens, not a request to bolt literal RPG conventions onto football. Do not add fantasy classes, ability bars, dialogue trees or other genre furniture merely to satisfy the analogy. Borrow the useful qualities instead:

- individual players should become recognisable pieces with strengths, weaknesses, roles, development and distinctive ways they can help a side;
- list construction and selection should feel like building a party whose pieces complement one another, not merely maximizing aggregate OVR;
- coaching and preparation should give the player meaningful ways to deploy the particular group they have built;
- unusual player archetypes should create different possibilities, not merely slightly different simulation coefficients;
- long-term development, history and shared success should create attachment to individuals and to the group;
- the player prepares, selects and instructs the side, but does not directly control footballers once play unfolds. MatchSim retains uncertainty: good plans can fail, stars can have poor games and stronger opposition can still win.

A useful feature test is: **Does this help the player care about their players, understand what makes their group distinctive, or make a meaningful decision about how to use that group?** If not, be cautious about adding complexity for its own sake.

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
7. Add targeted regression tests for the behaviour actually changed.
8. During implementation, run only the targeted/relevant suites needed for fast feedback. Do **not** repeatedly run the entire repository suite after small edits.
9. When the coherent implementation is ready, push/open the PR. GitHub CI is the default owner of the full regression suite.
10. For simulation-affecting work, run the smallest appropriate seeded balance comparison that can answer the actual hypothesis; only scale the sample up once the implementation is stable.
11. For save-schema changes, prove backward compatibility with targeted save/load coverage.
12. For UI work, check the relevant narrow Android portrait layouts; do not re-screenshot unrelated screens.
13. Update this roadmap's status/notes if the task is completed or materially changed.
14. Commit logically. Under the standing authority above, merge a clean PR once required tests/checks and any balance/save/UI gates pass. Do not wait for a second permission message.
15. Verify the merged result on `main`, then update the roadmap status/implementation record.
16. Handoff with exact files, commits, tests, behaviour before/after, balance evidence and remaining risks.

If the requested feature turns into a broad rewrite, **stop and report the dependency/risk instead of silently expanding scope**.

## 0.6 Lean validation ownership

The goal is **high confidence without making Claude spend development time repeatedly proving the same thing**.

### Claude owns while coding
Claude should:
- run the smallest targeted test suite(s) that cover the code being changed;
- add/repair regression tests for the changed behaviour;
- run targeted save, UI or balance probes only when the task requires them;
- fix genuine failures caused by the implementation;
- push a coherent PR as soon as the feature is ready for repository-wide verification.

Claude should **not** routinely run the full suite locally when GitHub CI will run the same suite on the same PR head. A local full-suite run is justified only when:
- the change modifies the test harness / CI itself;
- CI is unavailable;
- a difficult integration failure is easier to diagnose locally;
- the task is unusually high-risk and repository-wide behaviour must be checked before pushing.

### ChatGPT owns repository-wide verification
When ChatGPT has GitHub access, ChatGPT should take over the mechanical verification work after Claude pushes:
- inspect the PR diff and test coverage;
- monitor the GitHub Actions full-suite result;
- inspect failing job logs;
- distinguish a real code failure from an infrastructure/flaky failure;
- rerun only the failed job/run when appropriate rather than restarting everything;
- confirm the PR is current enough with `main` and mergeable;
- verify required balance/save/UI evidence is present;
- merge clean validated work under the standing authority;
- verify the merge on `main` and keep the roadmap record accurate.

If CI exposes a genuine implementation bug, ChatGPT should give Claude the **specific failure and relevant log context**; Claude remains the coding agent.

### PR feedback handoff
Claude must actively check the conversation/comments on any open PR he owns:
- immediately after pushing/opening the PR;
- before resuming work on that PR after doing another task;
- before treating the PR as ready to merge or abandoning it for the next roadmap item.

ChatGPT will post actionable failures as a top-level PR comment, prefixed **`[CI HANDOFF]`**, with the failing suite/job, the relevant log excerpt or symptom, and what needs fixing. Claude should treat an unresolved `[CI HANDOFF]` comment as work on that PR, fix the code, push the update, and reply/resolve through the PR rather than asking the user to relay the failure.

Claude should not assume GitHub comments will be surfaced automatically by the coding session; **checking the PR is part of the workflow**.

Documentation-only PRs (`docs/**` and Markdown-only changes) are excluded from the expensive Godot full-suite workflow. If a PR changes both documentation and game/code/data/config files, CI still runs normally.

### Test tiers
Use the cheapest tier that answers the current question:

1. **Fast loop — targeted tests:** after code edits; normally seconds/minutes.
2. **Feature gate — targeted integration/balance/save/UI checks:** once the implementation stabilises.
3. **PR gate — full repository suite in GitHub CI:** normally once per coherent PR head, not after every local edit.
4. **Long-run gate — multi-season / large seeded simulations:** only for systems whose correctness or balance genuinely emerges over time.

Do not duplicate equivalent validation merely because both local and CI execution are available. A green GitHub full suite on the exact PR head normally satisfies the repository-wide regression requirement.

### While CI runs
Claude should not sit idle merely because CI is running. If there is a **clearly independent** next task, Claude should continue development on it.

**A PR that has been pushed and is only waiting on GitHub CI, review, or ChatGPT's merge/verification work does not count as an active implementation branch.** The normal limit of two active implementation branches applies only to branches Claude is currently coding on, debugging, or otherwise modifying.

If CI fails and ChatGPT returns a genuine `[CI HANDOFF]`, that branch counts as active again only while Claude is reproducing/fixing the failure. Once the fix is pushed and CI owns verification again, it stops counting as active.

Avoid uncontrolled branch sprawl, but do not use the branch-limit rule as a reason to go idle while completed PR heads are merely waiting on CI.

If the next task depends directly on unmerged code, prefer diagnosis, design inspection, or non-conflicting preparation. Building on the dependency is acceptable only when the overlap is understood and rebasing/merging will be straightforward; otherwise choose an independent task.

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

## 1.11 Current playtest gate — match flow and decision clarity

**Status:** `IN PROGRESS`  
**Priority:** `P0`  
**Autonomy:** `SUPERVISED`

The current phone playtest has exposed a core-loop problem more important than feature expansion. **Pause unrelated new feature work until this gate is addressed.** Existing PRs may finish through CI/merge, but the next development work should focus on the failures below rather than advancing the roadmap for completion's sake.

### Observed failures
- Match simulation can freeze/stall.
- Loose-ball sequences can visibly stop while players wait for a far-away predetermined player to run over and collect the ball instead of nearby players contesting naturally.
- The watched match therefore feels discontinuous and unlike football.
- List/selection synergies are opaque enough that the user cannot reliably reason about why a combination should work.
- Pre-match and in-match choices feel insufficiently informed: the user is often clicking an option and hoping rather than making a football decision from understandable evidence.
- Results do not provide enough feedback to connect a decision to what subsequently happened, so the player cannot readily learn from wins/losses.

### Product goal
The core loop must support:
**understand the side → identify a football problem/opportunity → make an informed choice → observe the consequence → learn for the next decision.**

Do **not** solve this by revealing an objectively best choice, adding recommendation arrows, or dumping more numbers onto primary screens. Preserve uncertainty and trade-offs while making the underlying football logic scrutable.

### Hard gates before unrelated feature expansion
1. **Match flow:** watched matches run without freezes/stalls or obviously artificial waits for predetermined receivers. Loose-ball possession must look locally contestable and believable.
2. **Decision inputs:** before a meaningful selection/tactical choice, the player can see enough relevant football information to form a reasoned expectation.
3. **Synergy clarity:** list/line/role synergies can be understood in football language; the player can explain broadly what a combination is good/bad at without reverse-engineering hidden formulas.
4. **Decision feedback:** after a choice, the game gives enough concise evidence to judge broadly whether the intended effect occurred and why the match developed as it did.
5. **No number vomit:** clarity comes from better framing, comparisons, football language and causal feedback—not exposing raw internal weights or adding dense dashboards.

### Implementation record — match flow, part 1 (2026-09-29, branch `claude/match-flow`)
- **Diagnosis (presentation, not simulation):**
  - Over two full matches replayed at 1x (RIC v SYD, SYD v RIC), no beat hung for good; the longest was 5.5 s, a mark.
  - The ball sat still with nobody holding it 38-40% of watched time. Real dead ball (set-ups, celebrations, tackles, packs) accounts for part of that.
  - The largest single cause was the receiver collecting after the ball had landed or gone to ground: 120-150 s a match waiting on a receiver 12 m or more away.
  - The sim names who wins each ball, so a forward who wins it back in defence is often 40-50 m from it.
  - Separately, at a kick-in the taker kept carrying the ball up the ground with the structure when the log moved on without his kick. That was the source of the last wrong-way kicks.
- **Changes (`MatchDirector.gd`):**
  - A loose ball whose winner is still more than 8 m away is scrapped for: the nearest two players converge on it. It is knocked on toward him in short hops, 5 m every 0.45 s, 16 m at most, and never back toward his own goal. The ball is no longer left on the deck while he runs.
  - A ball held by someone other than the collector is put down where it is, not carried.
  - Hang time for a kick to a running receiver can stretch to 1.8x its natural length (was 1.45x).
- **Measured (same matches, main v branch):**
  - pauses of 1.5 s or longer: 63 v 40 and 54 v 29;
  - waiting on a far receiver: 152 v 97 s and 120 v 76 s;
  - ball still overall: 40% v 35% and 38% v 34%.
  - Wrong-way kicks: 0 in six seeded matches (two occurred on main).
- **Remaining:** the rest of the far waits are the sim choosing a far-off winner (role weights let a forward win the ball in defence). Closing that would mean the sim considering position, which is a separate, balance-gated change. The phone playtest is the acceptance check.
- **The mid-play freeze near the boundary (reported from the phone playtest):**
  - A loose ball can settle 1 m inside the fence, but a player's run is kept 2 m inside. With others crowding the ball, the collector could end up more than 1.4 m short.
  - Collecting was the only step with no time limit, so play stopped for good.
  - Now close enough (3 m) after 1.5 s counts as his, and no collect lasts longer than 6 s. Players contesting a scrap go beside the ball, not onto it.
- **The mid-play freeze in a live match (found by driving live matches end to end):**
  - After a moment call, the match screen resumes play. When the sim stopped at another moment with no new events to show, the view's `play()` returned silently without reporting it had finished.
  - So the next moment card never appeared and the match sat frozen: every event shown, a call pending, no card.
  - `play()` on an idle view now reports finished straight away.
- **Tests:**
  - `_test_play_when_idle`: resuming with nothing new to show still hands back to the match screen.
  - `test_match_visual.gd::_test_match_flow`: no beat longer than 8 s; far-receiver waits at most 12% of a match.
  - `_test_boundary_collect`: a ball against the fence with a crowd around it is always collected.
  - The wrong-way check still passes.
### Implementation record — quarter breaks (2026-09-29, branch `claude/quarter-breaks`)
The director's playtest named quarter breaks as the most obtuse decision. The break now follows the gate's loop: the problem, what your last calls did, then the response.
- **What's happening:** the quarter's facts as before: stoppages, territory, the opposition player hurting you, wayward kicking, their plan, moments.
- **What your calls did (new, `MatchNotes.calls_lines`):** one line per call you made, with the stat that call is about, against the quarter before. Examples:
  - "Defensive press: they had 6 inside 50s and kicked 1 goal, from 11 and 4 in the first."
  - "Win contest: clearances 9 to 6, from 5 to 8 in the first."
  - "Tag on Walsh: 4 disposals, from 11 in the first."
  - "Through Bontempelli: …"
  - The problem and the call that answers it use the same words (stoppages and Win contest, a player hurting you and the tag). There is no verdict and no "best call".
- **Your calls:** the game plan and the tag stay in view. Play through, pep talk, rotations, legs and the synergy line sit behind one "More calls" tap.
- **Full time:** a "Your calls" section lists the same lines quarter by quarter (at most five) for a match you played live.
- **Tests:** `run_matchday_tests.gd` checks:
  - the break leads with what's happening;
  - what your calls did, with the tag, is shown;
  - plan and tag are in view and the rest one tap away;
  - More calls opens the rest.
- **Screens:** quarter time at 390 px reviewed.
- **Next in this gate:** decision inputs before the match (selection and the standing plan), and synergy clarity.

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

### Playtest test
For each important decision, verify the player can answer:
- What decision am I making?
- What information am I using?
- What do I expect to happen?
- Afterward, can I tell whether it mattered?

If those questions cannot be answered, that decision loop is not complete.

### Implementation approach
Treat each observed failure as a reproducible problem. Diagnose simulation authority vs visualisation/presentation before changing architecture. Prefer small fixes where sufficient; do not launch a movement-engine rewrite without evidence that local fixes cannot solve the problem. Use the user's phone playtest observations as the acceptance signal alongside targeted regression tests.

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
**Status:** `IN PROGRESS`  
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
**Status:** `IN PROGRESS`  
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
**Status:** `IN PROGRESS`  
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
**Status:** `IN PROGRESS`  
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

---

## ARD-M5-011 — League Draft career-stage filters
**Status:** `TODO`  
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

---



## ARD-M5-012 — League Draft AI asset valuation sanity
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

### Trigger
Observed in the 2027 opening League Draft: Bodhi Uwland was selected at pick #1. He can reasonably be a good AFL player, but that result is implausible enough to treat as a draft-valuation sanity failure rather than manually changing one player's ratings.

### Intent
Make opening League Draft AI value players as long-term dynasty assets, not merely as current-rating or positional-fit purchases.

### Scope
Audit the top ~30 selections across repeated seeded 2027 opening drafts before changing weights. Inspect whether AI valuation gives appropriate weight to:
- current ability,
- age / remaining career runway,
- potential and development upside,
- positional value/scarcity,
- list need where appropriate,
- salary/cap cost where relevant.

Diagnose the model-level cause. **Do not special-case or manually nerf Bodhi Uwland or other individual players to manufacture plausible draft order.**

### Acceptance
- Repeated startup drafts produce broadly credible top-end selections without becoming deterministic.
- Elite young/high-upside cornerstone players are valued appropriately against good established players.
- Veterans and role players can still rise when their quality/context warrants it, but obvious outlier #1-type selections are rare and explainable.
- AI clubs continue to obey the same cap/list rules as the player.
- Measure before/after top-30 composition across deterministic seeds and check that any weighting change does not create a new age, position or potential monoculture.


# M6 — Coaching, Board & List Management

Goal: strengthen the management loop around the football.

## ARD-M6-001 — Coaching hub
**Status:** `DONE`  
**Merged:** PR #81 as `6a9abc73`; verified on main 2026-09-28.  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

### Implementation record (2026-09-28, branch `claude/coaching-hub`)
- **Navigation:** the hub's bottom row is Training · My list · Coaching · Sim round (after the season: Season review · Training · Coaching · Main menu). An open staff job shows on the tab ("Coaching · 1"). The hub's quiet Staff link is gone; its board line shows only when your job is at risk (a final warning or confidence under the warning line).
- **Coaching screen** (`CoachingScene.gd`, one scrolling page):
  - **How we play:** the club's standing game plan (the six quarter-break plans), with its plain-English summary. Every match of yours starts on it, played live or simmed, and the break calls change it from there (`GameState.club_plan`, `Season.plans`, set on the pending match).
  - **How we win / how we get beaten:** up to three lines each from the season's team numbers against the average club, biggest difference first. There's nothing until three games in, and a line needs a 7% gap and at least one a game. The words come first, then the number, e.g. "We get beaten at the stoppages: 5 fewer clearances a game than the average side."
  - **Form:** up to three players in form and three out of form. A player's Player Rating over his last three games is set against his own season average. He must have five games, and the gap must be at least 15. Tap a player for his profile.
  - **List and cap:** list size, payroll and cap room in one line, plus My list.
  - **The board:** confidence, their goal, any final warning.
  - **Staff:** one line per job, which opens the coach's profile (a vacant job opens Staff). The Staff screen is one button away for appointments and other clubs.
- **Saved:** `club_plan`, `form_log` (last three ratings plus the season sum), `season_team` (season team totals for every club). Form and team totals reset each season.
- **Score sources (M2-008):** the season also keeps points scored and conceded from turnovers and from stoppages (centre bounces included), so the lines can say "They hurt us on the turnover: 6 more points a game conceded from it than the average side." The Phase 5 effects copy (what teaching, tactics and man-management do) stays on each coach's profile, one tap from every staff line, rather than repeated on the hub.
- **Tests:** `test_club.gd::_test_coaching_hub` checks that:
  - the plan is valid, yours only, and reaches a simmed match;
  - style lines only appear after three games, with at most three each;
  - form reads last three against the season, with a five-game minimum;
  - everything survives a save.
- **UI test:** `run_career_ui_tests.gd` covers the Coaching tab, the board and staff on it, choosing a plan, and Back. The matchup suite confirms the four-button footer fits a phone.

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
**Current state (2026-09-28):** Phase 2 (data model, Round 1 2026 seed, read-only Staff UI) is merged. Phase 3 (the living coaching market: sackings, contracts, retirement, promotions, poaching, your vacancies and releases, development, reputation, generated coaches, expansion staffing, archive) is merged: PR #62 as `bf8bd0a`, `coach_market` suite, 50-season probe with every job filled. **Phase 4 (former players entering coaching) is actively being implemented by Claude; Phase 5 (gameplay effects) follows it.**  

Core design:
- Teaching → development,
- Tactics → match performance,
- Man-management → morale/selection response.

### Phase 4 — former-player coaching pathway

Implementation direction:

- capture a player before retirement/delisting removes them from the active lists;
- one deterministic career-seeded roll decides whether they pursue coaching;
- preserve the same player name/alias and link the coach record back to the playing career;
- pathway period: roughly 1–3 seasons before entering the normal coaching market;
- **playing ability must not determine coaching skill**;
- playing fame may raise starting reputation only, and that advantage should fade over roughly a decade;
- former clubs may provide a small, bounded hiring-link advantage;
- once in the market, former players obey the same hiring, promotion, retirement and vacancy rules as other coaches;
- profile/history should show the playing career without creating a separate former-player coaching ruleset.

### Phase 4 balance guidance

A real 32-season career exposed an upstream constraint: the current game ends only about **19 playing careers per season**, heavily skewed toward long-tenured veterans. At the original 8% coaching-entry rate, former players reached only about 10% of coaching jobs after 32 seasons.

Do **not** solve that by forcing an extreme conversion rate simply to hit a headline percentage.

Use this order:

1. Test a former-player coaching-entry rate in roughly the **20–30%** range, with **25% as the first baseline**.
2. Make generated external coaches a **top-up/fallback supply**, not a fixed source that permanently crowds former players out as the ex-player pipeline matures.
3. Keep the long-run design target of roughly **60–80% of coaching jobs eventually being held by former players** as a mature-world aspiration, not a hard Phase 4 pass/fail if the current player-retirement pipeline cannot supply enough candidates.
4. Record the observed ~19 career endings per season as a separate player-lifecycle/list-turnover issue. Do not hide it inside coaching by inflating conversion rates.
5. Compare 30–50+ season runs for:
   - former-player share of all coaching jobs,
   - former-player share of new appointments,
   - generated-coach pool size,
   - vacancy fill rate,
   - internal promotion share,
   - coaching skill distribution / Elite share,
   - churn and repeat moves.

If 20–30% entry plus adaptive generated-coach supply still cannot produce a believable coaching ecosystem, report the limiting factor rather than tuning blindly.

### Phase 4 merge authority

The older Phase 4 brief saying **"do not merge"** is superseded by the roadmap's standing development authority. Once Phase 4:
- passes its targeted suites,
- passes the full suite,
- has acceptable long-run balance evidence,
- preserves save compatibility,
- and CI is green,

Claude should **merge it and proceed to Phase 5** without waiting for another permission message.

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
- **Real 32-season career (authoritative):** 615 career endings (602 retired, 13 unsigned), 23.4% into coaching (144). By 2058 former players held 102 of 119 jobs (86%), just above the 60-80% aim. Several reached senior coach by the normal path; for example, Ben Long went forwards coach 2040, senior assistant 2044, senior coach West Coast 2058. Coach records 106 KB and archive 66 KB after 32 seasons. The synthetic market probe (38% at year 50) under-predicts because it cannot reproduce real results and churn. If the share keeps climbing past 80%, lower `BASE_INTEREST` first.
- **Upstream issue:** about 19 playing careers end a season, almost all veterans. That is a list-turnover question for the player lifecycle, not coaching.
- **UI:** the coach profile shows the playing career (clubs, games, goals, draft, medals), then the coaching career, wrapped for 360 px. News covers notable former players joining the coaching ranks and their first appointment.
- **Tests:** new `coach_pathway` suite, plus the coaches and coach_market suites.


### Phase 5 implementation record (2026-09-28, branch `claude/coaching-phase5`)
- **Design:** `CoachEffects.gd` holds three capped modifiers read from the coach records; nothing is saved. A skill counts from a Good coach: level = (skill - 70) / 20, clamped -0.75..1. A vacant job counts as a weak coach.
- **Teaching:** scales match XP in the one place it is paid (`GameState._grant_xp`, your club and rivals alike).
  - Weights: 6% x the player's line coach's fit for the job, 5% x the development coach's fit for a player aged 22 or under or not on the ground (2% otherwise), and 2% x the senior assistant's teaching.
  - Capped at -5% to +10%. The reserves keep their half rate.
  - Probe, the same career with coaches set to 60 / 72 / 90: match XP 126.9k / 133.6k / 148.7k; starting list after 3 seasons +1.10 / +1.21 / +1.52 OVR.
- **Tactics:**
  - The tactical brain is the senior coach 60% and senior assistant 40%; at your club it is your assistant.
  - Plan effects, costs included, execute at 1 +/- 15% x level through `MatchSim._pv`.
  - `ai_tactics` reacts to a margin of 18 - 8 x level, counters after one quarter at level 0.4+ (two otherwise, never below -0.5), and tags from half time when sharp.
  - AI clubs now pick their plan each quarter in every match; before, only in the match you watched.
  - With no plan in play, tactics change nothing: a hash test confirms identical results.
  - Identical lists: 72 v 72 wins 50.4%; 90 v 72 wins 53.2% (+2.8 points a game).
  - AI plans league-wide (1,000 matches): plans used in about 18% of quarters, mean score 86.9 to 88.5, home win 59.6% to 57.1%, stronger side wins 63.1% to 64.6%.
- **Man-management:** spares part of the morale a fit player loses when left out, and part of a broken promise of a game.
  - The senior assistant counts 60% and his line coach 40%, up to 40% spared; a poor man-manager spares nothing.
  - A star dropped eight weeks from 70 ends at 22 / 30 / 38 with weak / Good / elite: he still slides.
- **UI:** one plain line on the coach profile says what each skill does. No numbers.
- **Tests:** new `coach_effects` suite (24 checks).

---

## ARD-M6-003 — Board Confidence
**Status:** `IN PROGRESS`  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

### Implementation record (2026-09-28, branch `claude/board-confidence`)
- **Relative to expectations:** each result moves the board by what the season's goal asks (`ClubLife.GOAL_STEPS`, [win, loss]).
  - Top four: +2 / −3.
  - Finals: +2 / −2.
  - Top 12: +2 / −2.
  - Win seven games: +3 / −1.
  - Plus one for a 40-point margin either way. After three losses in a row each further loss costs one more.
  - This replaced ±3 (±4 for a thrashing) whoever you were.
  - The season verdict (+20 met, −25 missed, +30 a flag) and the warning and sacking rules are unchanged.
- **States, not a percentage:** Very secure (80+), Secure (62+), Stable (45+), Under pressure (30+), In trouble. They show on the Coaching hub and the season review. The Hub's at-risk line reads "Board: Under pressure · goal". The number stays behind the scenes.
- **Why it moved:** after every match, a sentence, e.g.
  - "The loss to Carlton puts a top-four finish under threat."
  - "Four losses in a row: the board is getting restless about a finals spot."
  - The promise card and the season verdict set their own sentences.
- **Balance (54 club-seasons, every club as yours, same results, old v new):**
  - average move a match 3.3 v 2.4;
  - confidence at the end of the home-and-away season 58.9 v 60.4;
  - after the verdict 62.4 v 64.0;
  - clubs that missed their goal and ended in trouble 14 v 16 of 18.
  - Sacking (a second missed goal after a warning) is unchanged.
- **Not in this change:** smaller inputs (finals runs, player development, cap health, trend). Those come once play shows the base model is right.
- **Tests:** `test_club.gd::_test_board_confidence` covers:
  - steps against the goal;
  - no ordinary result moving more than three;
  - the losing run;
  - draws, the five states and the reason sentences;
  - a reason after a real round.

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
**Status:** `IN PROGRESS`  
**Priority:** `P1`  
**Autonomy:** `SAFE`

### Implementation record (2026-09-28, branch `claude/options`)
- **One Settings sheet** (`scripts/ui/OptionsSheet.gd`), opened from the main menu (Settings) and from a new top-right Settings on the hub. It holds:
  - player names;
  - confirm before simming a round;
  - match speed (new: 1x, 2x, 4x or 8x, the speed a watched match starts at, default 4x);
  - the version.
- **In a career it also has:**
  - Main menu (saves, then returns);
  - Delete this career. It asks first ("This deletes your saved career for good. It cannot be undone.", with Keep it / Delete career), then removes the save and returns to the menu.
  - Quit game stays on the menu's sheet (desktop only).
  - Back closes the sheet.
- **Left out, as not yet relevant:**
  - light/dark theme and UI scale: one palette and type scale, and a change there is project-wide;
  - audio: none yet;
  - reduced motion: the match view already has 1x to 8x and Skip.
- **Also fixed:** the hub's four-button bottom row cut "Sim round" short at 360 px. Below 380 px it uses 13 px type and tighter padding.
- **Tests:** `run_career_ui_tests.gd` covers:
  - Settings on the hub's top bar;
  - speed, main menu and version present;
  - speed remembered;
  - Keep it cancels;
  - delete asks first, removes the save and returns to the menu.
  - The existing menu Settings checks still pass.
- **Screens:** hub and Settings at 360 and 390 px reviewed.

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

## ARD-M7-008 — Create a custom draft prospect
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

### Intent
Let the player create a self-insert or fictional prospect who enters the normal AFL draft ecosystem, creating a personal long-term story without turning the feature into a cheat-character creator.

The fantasy is not "build a 99 OVR player". It is:
- create someone you care about,
- watch where they are drafted,
- follow whether they become a star, journeyman, role player or bust,
- see their career interact naturally with clubs, trades, finals, records and retirement.

### V1 scope
At New Career setup, optionally create **one custom prospect** for that career.

Player-facing choices should stay concise:
- name,
- basic bio fields already supported by the player model,
- height,
- primary position,
- optional secondary position where valid,
- archetype / play style,
- a small set of strengths and weaknesses.

Do not expose exact underlying attributes, OVR, potential or draft rank as editable fields.

### Draft integration
- The custom player enters the **first national draft class** of the career, not the opening League Draft of established AFL players.
- They go through the same draft order and AI evaluation as every other prospect.
- The user's club gets no priority access unless a future explicit father-son / academy mechanic genuinely applies.
- No guaranteed draft position.
- No guaranteed selection by the user's club.
- If undrafted, normal undrafted/carry-over rules apply.

### Generation / balance
The user's choices shape **attribute distribution**, not total power.

- Generate the player's overall talent from the same draft-class quality model as other prospects.
- Archetype, position, height, strengths and weaknesses redistribute that talent into a coherent football profile.
- Potential remains hidden and is generated through the normal prospect/development model.
- Do not grant special development speed, durability, consistency, personality, longevity or career outcomes because the player is custom.
- The custom prospect should be statistically ordinary relative to the draft class except for the identity/profile choices the user made.

A user-created key forward, winger or rebounding defender should feel meaningfully different without one archetype being an exploit.

### Narrative / tracking
Because the point is emotional attachment:
- mark the player as user-created in persistent data,
- preserve the entered name regardless of real-name / fictional-name display mode,
- automatically make their profile easy to find from the draft and career-history flows,
- retain their full career history after retirement,
- surface meaningful milestones through the normal milestone/history systems rather than creating a separate "custom player" ruleset.

A lightweight **Follow / Watch** affordance is preferred over extra bespoke dashboards.

### Guardrails
- Do not let the user assign a club, draft pick, OVR or potential.
- Do not quietly bias AI clubs toward or away from the custom player.
- Do not create a second player-generation pipeline if the existing prospect generator can be parameterised.
- Do not add multiplayer/share-code complexity in V1.
- Do not allow repeated custom-player creation to flood a draft class in V1.
- Preserve save compatibility and deterministic draft-class generation.

### Tests
- custom prospect is created once and persists through save/load,
- enters the correct national draft class,
- uses valid role / secondary-role combinations,
- strengths/weaknesses reshape attributes without escaping normal class power bands,
- AI evaluates/drafts them normally,
- user's club receives no hidden preference,
- undrafted path remains valid,
- career stats/history/milestones work after drafting,
- real-name/fantasy-name setting does not replace the user-entered custom name,
- old saves without custom-prospect data load safely.

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

## ARD-M8-007 — Cinematic tactical vignettes
**Status:** `DEFERRED`  
**Priority:** `P3`  
**Autonomy:** `SUPERVISED`

Use short, deliberately higher-detail tactical vignettes for selected high-value in-match decisions so the player can **see the football problem or opportunity**, not just read about it.

This is **not** a full 3D match engine or a replacement for the standard watched-match view.

### Dependency
Do not prioritise this until the current §1.11 playtest gate has proved that the underlying decisions themselves are informed, meaningful and give useful feedback. Better presentation must not be used to disguise arbitrary choices.

### Prototype first
Build **one** centre-stoppage decision vignette before committing to a library.

The prototype should use enlarged 2D / 2.5D presentation only. Do not introduce 3D player models or 3D match presentation.

A successful vignette should:
- enter briefly from the normal match view;
- show only the relevant players and space, not all 36 footballers;
- use the actual clubs/players/context from the match state;
- play a short tactical sequence, then freeze at the decision point;
- visually expose the problem/opportunity — e.g. an opponent getting goal-side, a spare defender, an isolated forward, or a numerical advantage;
- present the normal decision UI over/after that readable situation;
- return cleanly to the standard match view.

### Reuse model
If the prototype earns expansion, prefer a small reusable library of situation templates rather than bespoke cinematics.

Possible families:
- centre clearance / stoppage,
- defensive transition,
- forward isolated one-on-one,
- spare defender / loose player,
- kick-in press,
- wing/outside overlap,
- forward stoppage,
- late-game flood / protect-space situation.

### Guardrails
- MatchSim remains the authority. A vignette may illustrate state but must not invent a second football outcome.
- Do not introduce 3D player models, 3D stadium presentation or continuous 3D match recreation.
- Do not build hundreds of unique scenes.
- Tactical readability matters more than graphical fidelity.
- Preserve club colours and player identity where useful without requiring licensed likenesses.
- Keep mobile performance and load time within the Android-first target.
- No extra number-vomit: the visual should replace explanation where possible, not add another analytics layer.

### Acceptance test
The feature earns further work only if a phone playtest shows that the player can explain **why the decision is being asked**, form a reasonable expectation before choosing, and finds the moment materially more engaging than the normal presentation.

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

Use the relevant rows only. These are **feature-specific gates**; the repository-wide full suite is normally delegated to GitHub CI at PR time under §0.6.

| Change type | During coding / feature gate |
|---|---|
| Pure UI | relevant UI tests; inspect only affected portrait layouts; navigation/state preservation; no clipping |
| MatchSim logic | deterministic targeted regression; focused seeded sim comparison if outcomes can change |
| Player statistics | event-level attribution; player/team reconciliation; season aggregation; save/load only if persisted |
| Balance mechanic | start with a cheap baseline/variant sample; scale to a larger seeded run only after the effect stabilises; inspect relevant distributions/side effects |
| Availability/injury/suspension | targeted manual/AI selection rules; decrement rules; save/load if state persists |
| Season/calendar | targeted progression/boundary/rollover scenarios; save/reload if affected |
| Salary/list rule | exact-boundary cases; AI parity; invalid-state recovery; save/reload if affected |
| Persistent schema | old-save default/migration; current-save roundtrip; no data loss |
| Visualisation | affected event/result reconciliation; direction/restart regression; relevant phone view only |
| Long-save feature | run the minimum multi-season probe that exposes the long-run behaviour; expand to 30/50/100 seasons only when the question requires it |
| Docs/copy only | no game suite; docs/Markdown-only PRs skip the expensive Godot CI by path filter |

### Avoid redundant validation

- Do not run the same full suite locally and then again in CI without a specific reason.
- Do not rerun a long balance/career probe after a docs-only or copy-only change.
- After resolving a merge conflict, run the **affected targeted suites** locally; let CI provide the repository-wide regression pass.
- If a CI run fails for an unrelated/flaky reason, inspect the logs and rerun the failed job rather than making Claude repeat every local test.
- A test count is not a goal by itself. Prefer a small test that proves the behaviour over thousands of irrelevant checks during the coding loop.

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
- During coding, run only relevant/targeted suites.
- Push the coherent PR for the repository-wide full-suite gate; GitHub CI owns that by default.
- Do not duplicate a green CI full suite with an equivalent local full-suite run unless §0.6 gives a reason.
- If simulation outcomes change, perform the smallest useful roadmap Balance Assessment and scale the sample only when needed.
- If persisted data changes, run old-save/default + save/reload checks.
- If UI changes, verify only the affected narrow Android portrait layouts.
- Once pushed, ChatGPT may own CI monitoring/log review/reruns/merge verification so Claude can keep coding.

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
5. Targeted test result + GitHub CI full-suite result (do not duplicate equivalent runs).
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
- use targeted tests during the coding loop and delegate the routine full-suite PR gate to GitHub CI / ChatGPT where available,
- do not idle solely waiting for CI when an independent next task can safely proceed,
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
| Club colours / green UI / game visual style | ARD-M8-001/002 |\n| Android app name / launcher icon / installed app identity | ARD-M8-008 |
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
| Create-a-player / self-insert / custom draftee / custom prospect | ARD-M7-008 |
| Cinematic decision scene / tactical close-up / detailed match moment | ARD-M8-007 Cinematic tactical vignettes |
| Draft age filter / rookie-prime-veteran / career-stage filter | ARD-M5-011 |

## ARD-M8-008 — Android app identity: name and launcher icon
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `SAFE`

### Goal
Replace the leftover prototype identity shown by Android. The installed app must use the current game name, **Aussie Rules Dynasties**, rather than **AFL Auto-Battler**, and the launcher/app-info icon must be purpose-built for the Aussie Rules Dynasties identity rather than the current generic football-field placeholder.

### Acceptance
- Android launcher and App info show **Aussie Rules Dynasties**.
- Android launcher/adaptive icon is visually tied to the game's title/identity and remains legible at phone icon size.
- Remove visible legacy **AFL Auto-Battler** branding from Android export metadata where it is user-facing.
- Do not redesign the in-game title/logo as part of this task unless required to share the same approved identity assets.


---

# 10. Roadmap Maintenance Log

- **2026-09-29:** Added the party-based RPG design lens: the club is the campaign, the playing group is the party, and matches test the group. Preserve simulation uncertainty while making player identity, composition, development and deployment create CRPG-like attachment and agency without literal RPG genre furniture.

- **2026-09-29:** Codified the project's game-first philosophy: realism supports believable football, but fun and meaningful player agency take precedence over simulation purity. Gamification is explicitly welcome when it makes deliberate choices materially influence outcomes.

- **2026-09-29:** Added ARD-M8-008 to replace the Android prototype identity: installed app name becomes **Aussie Rules Dynasties** and the launcher/App info icon must be purpose-built around the game's identity rather than the generic football-field placeholder.

- **2026-09-29:** Added ARD-M8-007 for cinematic tactical vignettes: prototype one high-value decision moment first using 2D/2.5D presentation, use visual detail to make the football problem legible, and explicitly keep 3D out of scope. Deferred until the §1.11 decision-clarity gate proves the underlying choices are good.
Keep this short. Add only meaningful structural changes, not every code commit.

- **2026-09-29:** Added a P0 playtest gate for core fun/readability: pause unrelated feature expansion while match freezes/stalls, implausible loose-ball waiting, opaque synergies, uninformed choices and weak decision feedback are addressed. Core test is whether the player can understand a decision, form an expectation, observe the consequence and learn from it without number-vomit or best-choice hints.
- **2026-09-29:** Added ARD-M5-012 to audit/fix implausible opening League Draft AI asset valuation after Bodhi Uwland was observed going pick #1; fix the valuation model, not individual player ratings.
- **2026-09-29:** CI-waiting PRs do not count toward Claude's two-active-implementation-branch limit. Only branches being actively coded/debugged count; a branch re-enters the limit while resolving a genuine `[CI HANDOFF]` and leaves it again once pushed back to CI.
- **2026-09-28:** Added ARD-M7-008, an optional custom/self-insert draft prospect that enters the normal national draft and career ecosystem without custom OVR/potential or preferential treatment.
- **2026-09-28:** Docs-only CI optimisation: PRs/pushes that change only `docs/**` or Markdown skip the full Godot game suite; mixed docs+code changes still run it.
- **2026-09-28:** Added lean validation ownership: Claude uses targeted tests while coding; GitHub CI/ChatGPT owns the routine full-suite PR gate, log triage, selective reruns and merge verification. Avoid duplicate full-suite and long-run testing.
- **2026-09-28:** Added Phase 4 former-player coaching guidance: test ~25% pathway entry first, let generated coaches act as top-up supply, and treat low player-career turnover as a separate upstream issue rather than forcing the coaching percentage.
- **2026-09-28:** Added ARD-M5-011 for opening League Draft career-stage filters (Rookies / Prime / Veterans), with exact age cut-offs to be chosen from the actual 2027 pool distribution.
- **2026-09-28:** Added OVR calibration sanity notes: keep #47's measured pressure weighting; use Toby Greene in the low-80s as a broader-model spot-check rather than a manual patch.
- **2026-09-28:** Removed stale per-PR/phase approval gates. Claude now has standing authority to action ready roadmap work and merge clean validated PRs; supervised/balance labels are risk gates, not ceremonial user-approval gates.
- **2026-09-28:** Converted roadmap from conversation-style backlog into a canonical execution roadmap with milestones, stable task IDs, dependency ordering, global guardrails, validation matrix, balance template, Claude task prompt and duplicate map.
- **2026-09-28:** Consolidated repeated concepts including season momentum/team form, reports, opponent scouting, forward scoring, match-ups, history/records, simulation controls, AFL rules/restarters, rivalries, marquee games and secondary-position learning.
