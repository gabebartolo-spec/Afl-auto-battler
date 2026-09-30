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

## 0.1.1 Project lexicon and interaction conventions

These terms have established project-specific meanings. **Do not guess or reinterpret them from generic usage.** When one is used, verify against this roadmap and the current repo/project context before acting.

- **Poke** — a request for ChatGPT to perform the repository-status job now: check GitHub for new PRs, CI state, merges, commits/branches, blockers, and any mechanical action already expected from the current workflow. It is not a conversational acknowledgement.
- **Vignette / vignettes** — unless the user explicitly says otherwise, this means **ARD-M8-007 — Cinematic tactical vignettes**: short, higher-detail in-match visual sequences around meaningful football decisions. It does **not** mean ClubLife/week_event narrative events, player-dialogue scenes, or generic story cards.
- **Roadmap** — `docs/ROADMAP.md` is the canonical execution/source-of-truth document for this project.
- **Audit** — unless otherwise qualified, refers to the current project design/system audit material recorded in the roadmap and `docs/SYSTEM_REALITY_AUDIT.md`.
- **Claude** — the primary development agent. ChatGPT's AFL-project role is planning, review, roadmap maintenance, repo-status/mechanical GitHub work, and prompting/coordination unless the user explicitly asks otherwise.

### Interpretation rule
For AFL-project shorthand, named concepts, or phrases that may have an established project meaning:
1. Check this roadmap and relevant current repo docs first.
2. Use prior established project context second.
3. Only infer from ordinary-language meaning if no project-specific definition exists.
4. If sources genuinely conflict, surface the conflict instead of silently choosing one.

The user should not have to restate established project vocabulary each time.

---

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

### Matches as quests — emergent storytelling

Treat each match as the equivalent of a **quest or encounter in an RPG**: a test of the particular party the player has built. The result matters, but the match should produce more than a final score and a statistical summary.

**Emergent storytelling is a core design goal.** After a good match, the player should be able to recount a short story of what happened without the game manufacturing a scripted narrative for them: who started brilliantly, what went wrong, which adjustment changed the contest, who unexpectedly stood up, which star was shut down, the late mistake or heroic act, and how the result was won or lost.

Design MatchSim, presentation and decision systems so matches can naturally develop **arcs, reversals, individual moments and consequences**. Players should have opportunities to become the remembered protagonists or villains of particular games through simulated football events, not canned story events.

This does not mean forcing every match into artificial drama. Some matches should be comfortable wins, ugly losses or quiet professional performances. The goal is for the simulation to generate enough legible cause-and-effect and individual identity that, when something dramatic happens, the player understands it and remembers it.

A useful match-quality test is: **Immediately after the siren, can the player tell the story of that match in a few sentences — including its turning points and the players who defined it — rather than only reporting the margin and stat leaders?**

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

## 0.4.1 Current execution queue — overrides milestone order

This is the **authoritative near-term work order**. The M1→M8 milestone structure below is a catalogue/dependency map, **not** a command to complete every lower-numbered milestone before higher-value work.

When this queue conflicts with milestone number, item order, or a generic P1/P2 label, **follow this queue**.

1. **P0 audit repair pass — HOLD for user review.** The System Reality Audit is complete and merged as PR #103. Do not begin repairs until the user explicitly releases this hold. The provisional repair order is: live-match plan reset at first bounce; no-op/near-no-op moment choices; tagging with no team-level consequence; Through stars no measurable effect / plan-balance trap; misleading/incorrect plan copy; hidden morale effect; weak/silent-skipping tests; then lower-severity questionable systems.
2. **Close the current playtest gate (§1.11).** After the audit repair pass, the next phone playtest is the acceptance check. Any remaining freeze, fake choice, opaque cause/effect or misleading feedback is P0 and jumps the queue.
3. **Core match agency.** Prioritise ARD-M4-001, M4-003, M4-006 and M4-007. Then M4-004/M4-005 if the simpler live-decision layer proves worthwhile.
4. **Core football authenticity.** Prioritise ARD-M3-006, M3-007, M3-009 and completion of M3-001/M3-002. Then lower-frequency flavour such as 50m penalties, smothers and speccies.
5. **Core team management.** Prioritise ARD-M5-001, M5-002, M5-008 and M5-012. Then M5-003/M5-005/M5-006.
6. **Management depth / long-save substance.** Contracts/trades/free agency, history/records, role/development depth and other systems that make seasons and careers matter.
7. **Flavour, expansion and release polish.** Rivalries, marquee identity, captaincy, weather, venues, custom prospect, onboarding, long-save QA, app identity and cinematic vignettes belong here unless a release blocker promotes them.

### Queue rules

- A newly observed **P0 correctness, soft-lock, fake/no-op mechanic or core-fun failure** jumps ahead of planned feature work.
- Findings from the System Reality Audit that are player-facing no-ops or materially misleading become repair work **before** unrelated new systems.
- Within a queue tier, honour explicit dependencies and choose the smallest high-value coherent task.
- Do not chase roadmap completion percentage. The objective is a good game, not a finished checklist.
- Do not use a lower milestone number as justification to work on a lower-value task.
- When a queue item is completed/merged, update this section so the next task is obvious without interpretation.

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
- **treat concurrent open PRs as a merge queue, not independent patches:** before merging any PR, inspect the full open-PR set for shared base age, dependencies and overlapping files/systems; establish the safest merge order first;
- when several PRs were cut from the same/stale `main`, prefer merging dependent/high-overlap companion work in an order that minimises rebases rather than simply merging whichever CI finishes first;
- after each merge advances `main`, immediately re-check every remaining queued PR's mergeability. If a remaining branch needs to sync, hand it back for sync/rebase **before spending time waiting on an obsolete CI run**; validate and merge only its new exact head;
- avoid preventable conflict churn: a green CI result is necessary evidence, not permission to ignore the state of sibling PRs;
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
- **AI must never be psychic.** An AI club may react only to information it could plausibly know at that moment: public match state, observed behaviour, scouting/known tendencies, and other information deliberately exposed to both sides.
- AI must not inspect or counter hidden player-only choices merely because the simulation has access to them. This includes an unobserved game plan, a private moment-card choice, a future player decision, or other concealed UI/state unless that information has become observable or an explicit symmetric scouting mechanic provides it.
- Stronger AI should come from better inference, preparation and reactions to evidence, not omniscience. If an AI advantage only works because it reads hidden state, redesign the behaviour rather than preserving the advantage.

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
- **Residual far-away receiver / loose-ball wait bug:** phone playtesting still shows occasional pauses where the visualisation waits for a distant predetermined player to reach the ball while nearer players stand off, despite the earlier match-flow repair. Treat this as an unresolved core-flow defect rather than closed work. Capture concrete occurrences and trace whether the delay comes from MatchSim selecting an implausibly distant next actor, MatchDirector/Motion over-honouring a predetermined event actor, or presentation failing to hand the loose ball to a locally plausible contestant. Prefer the smallest fix that preserves MatchSim authority and existing balance; do not silently change football outcomes just to make the animation look smoother. Acceptance: loose-ball sequences no longer visibly stall for a far-away player when a nearby eligible player could plausibly contest/collect, and any unavoidable long run has a football reason visible in the simulation state. Add targeted regression/replay coverage for the previously observed failure pattern.
- Loose-ball sequences can visibly stop while players wait for a far-away predetermined player to run over and collect the ball instead of nearby players contesting naturally.
- The watched match therefore feels discontinuous and unlike football.
- List/selection synergies are opaque enough that the user cannot reliably reason about why a combination should work.
- Pre-match and in-match choices feel insufficiently informed: the user is often clicking an option and hoping rather than making a football decision from understandable evidence.
- Results do not provide enough feedback to connect a decision to what subsequently happened, so the player cannot readily learn from wins/losses.
- **Match-feed club identity bug:** injury lines can show a club that is not playing (for example, `Tim English (Bulldogs)` during Demons–Suns), even when ordinary scoring lines use the player's current in-save club correctly. Fix injury/story feed club labels so they are derived from the player's current match side/list context rather than stale source-data club metadata. Acceptance: moved players always show the club they represent in that match, and no uninvolved club can appear on their injury line; add targeted regression coverage.
- **Unavailable tag-target bug:** a player who has already been injured out of the match can still appear as a tag target at the next-quarter decision (for example, Jordan Dawson after the feed says he will not return). Tag-target eligibility must come from current match availability/on-ground state, not the pre-match opponent list. Acceptance: injured-off players and anyone else no longer taking part cannot be selected or retained as a tag target; if the current target leaves the match, clear/re-resolve the tag cleanly; add targeted regression coverage.
- **Three-game coaching trend gate bug:** after the user has completed three matches, Coaching can still show “After three games, how your side wins and gets beaten shows here.” Diagnose why `GameState.how_we_play()["games"]` is still below 3 or otherwise stale despite three completed user matches. Acceptance: the section unlocks immediately after the third completed match, persists correctly through save/load, and does not depend on unrelated clubs having played a particular number of matches; add targeted regression coverage.
- **How-we-play data maturity / season-learning audit:** once `How we win / How we get beaten` unlocks after three matches, it can feel effectively fixed for the rest of the season instead of becoming a better read as evidence accumulates. Current code is **not literally frozen**: `_note_form_and_team()` adds every match to `season_team`, and `_style_found()` recomputes per-game differences against the current league average whenever the screen is read. The phone screenshots already show small numeric movement (for example ruck edge 12 → 10 hit-outs, turnover concession 7 → 6), so treat this as a quality/confidence problem rather than a stale-state bug unless testing proves otherwise. Audit whether the same top traits become too sticky after the initial three-game sample, whether early outlier games dominate too long, and whether new evidence can realistically promote/demote/reorder traits. The system should become **more trustworthy, not merely more verbose**, as the season grows. Prefer sample-size-aware thresholds/shrinkage or similarly simple statistical treatment over extra UI; if early-season uncertainty needs copy, keep it minimal (for example an 'early read' treatment rather than confidence bars/numbers). Acceptance: after each match the underlying profile is recomputed from all available season data; early three-game identities are appropriately provisional; materially changing team performance can change which traits are surfaced; stable genuine traits become harder to dislodge as evidence grows; and late-season `How we play` is demonstrably more reliable than the first three-game read. Add deterministic season-progression tests at 3, 6, 12 and 20+ games.
- **How-we-win / get-beaten actionability and materiality audit:** the current section can surface trivial deviations as if they explain results — e.g. **2 extra points conceded from turnovers** and **1 fewer point scored from turnovers** are shown under `How we get beaten`. Nobody is meaningfully losing because of a three-point combined seasonal tendency, and the output becomes statistical vomit rather than coaching information. Code inspection shows the root cause: `_style_found()` only requires a **7% relative gap** plus an absolute difference rounding to at least 1. On low-baseline stats, a one- or two-point difference can therefore rank as a major trait, and correlated symptoms can stack (`against` plus `conceded_turnover`) without telling the user what to do. Redesign this section around **material, football-addressable problems/opportunities**, not whichever percentages are furthest from league average. Calibrate metric-specific minimum effect sizes from league distributions and match impact rather than one global relative threshold; suppress trivial differences even if percentage-wise large; collapse redundant/correlated lines into one clearer football diagnosis; and prefer leading/process indicators the player can act on (territory, stoppage control, turnover creation/concession, pressure, ball retention, aerial contests) over tiny score-source noise. Do not assert causation the data cannot support: if the section cannot demonstrate a credible reason a tendency contributes to wins/losses, phrase it as a team tendency or omit it. Each surfaced weakness should have at least one existing or planned football lever the player can plausibly use to address it, without recommending an objectively best button. Acceptance: a line such as +1/-2 points per game never appears as a headline win/loss identity merely because its relative percentage is high; the screen shows at most 2–3 genuinely material, non-duplicative traits; each is understandable and actionable in football terms; and seeded season tests show surfaced traits correspond to meaningful differences in outcomes or underlying play.
- **Recent-games form copy / number-vomit cleanup:** the Coaching `Recent games` section currently says things like **“How his last three games rated against his season so far”**, **“Playing above his season”**, and **“76 over his last three, 53 for the season.”** The pronoun has no clear referent at section level, and the raw numbers are internal `MatchNotes.rating()` scores with no football meaning exposed to the player. This is exactly the kind of number-vomit the UI should avoid. Keep the underlying comparison if it is useful for selection/coaching, but present the conclusion in football language. Prefer simple headers such as **“In good form”** and **“In poor form”** (or similarly concise football wording), list the relevant players, and omit the opaque rating numbers from the primary screen. If supporting context is needed, use a short qualitative line rather than unexplained scores. Acceptance: a player can scan the section and immediately understand who is in/out of form without knowing the Player Rating formula; no dangling `his` copy and no unexplained 76/53-style numbers.
- **Match-up narrative consistency bug:** live quarter-break/report messaging and the post-match summary can tell conflicting stories about the same matchup (for example, live play says Jye Amiss is beating Blake Hardwick, while the post-match review says Hardwick's move onto Amiss "turned the contest" / was decisive). A changing matchup is valid, but the game must make the timeline explicit rather than sounding self-contradictory. Audit all live and post-match matchup verdicts so they are derived from the same underlying contest windows and thresholds. Acceptance: if a defender turns a matchup after previously losing it, the post-match copy says that clearly (e.g. "Amiss had the better of him early; Hardwick held him after the move") and never implies the earlier live assessment was wrong; if the evidence does not support a genuine turn, do not claim one. Add regression coverage for matchup narrative continuity across quarters and full-time.
- **Quarter-break “What's happening” information vomit / tense problem:** the break screen currently mixes retrospective match facts, opponent-plan history, streaks and resolved in-play moments under a present-tense heading (“What's happening”), producing a dense, feed-like block that is awkward to read and visually ugly. Treat this as a presentation/decision-clarity issue, not a request for more data. Reframe the section as a concise record of **what happened in the quarter/half** and only surface the few facts that materially help the next decision. Avoid replaying resolved event-feed moments (for example a completed set shot) unless they matter tactically. Acceptance: at a break, the user can scan the section in a few seconds, understand the 2–3 most important developments from the period, and distinguish them cleanly from “What your calls did” and the next-quarter controls. Preserve football language; no stat dump and no duplicate story lines.
- **List Profile vs actual team strength validation:** the user's side can read as mostly Strong/Average across the five List Profile dimensions while losing every match heavily. The profile is not meant to predict every result, but if a side has no visible Weak area and repeatedly performs like a bottom side, the words may be overstating practical strength or omitting an important determinant of match performance. Audit the relationship between each profile label and realised match performance/results across clubs and repeated seeded matches. Do not turn this into an overall power rating or recommendation. Acceptance: Strong/Elite labels correspond to materially better outcomes in the football area they describe, and a side that is broadly above average across the profile does not routinely behave like a clearly weak team without an explainable cause visible elsewhere.
- **Current-list club identity bug:** `My list` is still colouring each player's guernsey/number tile from `p["club"]`, which in a league re-draft can remain the player's original/source club. On the user's Melbourne list this produces a patchwork of old-team colours even though every player now represents Melbourne. Current-squad screens must use the player's **current club/list context**, not historical source-club metadata. On `My list`, every player should therefore carry Melbourne's red/blue identity (prefer the existing multi-band club marker where practical, not a single stale origin colour). Apply the same rule anywhere else that presents a player as a current member of a club: selection, training, match-day list/profile surfaces. Preserve original/source club only for explicit history/draft-origin contexts. Acceptance: after a league re-draft, no current-list screen visually implies a player still belongs to his former club; a Melbourne list reads consistently red/blue while career/history screens can still show past clubs when relevant.
- **Club marker colour accuracy audit:** the round-results screen exposes that a number of club colour markers do not convincingly match their real AFL identities. This screen is not inventing colours locally: `HubScene._results_list()` uses `UiKit.club_badge()` → `club_marker()` → `GameDB.club_marker_colours()`, which reads the hard-coded `primary/secondary/accent` values in `data/clubs.csv`; therefore audit the **source palette for every current AFL club**, not just this popup. Verify genuine club colours, ordering, two-vs-three-colour treatment and sufficiently accurate shades against authoritative club/AFL branding references. Do not use generic approximations simply because they are distinguishable. Obvious shade/order candidates should be checked rather than guessed (for example North Melbourne currently uses a very dark navy-like `#0C2340` as its primary despite its recognisable royal blue/white identity). Keep fictional/future clubs separate from the real-club audit. Acceptance: every 2027 AFL club marker is immediately recognisable to a footy fan across results, ladder, draft, selection and other shared badge surfaces; shared `club_marker` remains the single source of presentation; add a palette regression/snapshot fixture so later UI work cannot silently reintroduce wrong colours.
- **St Kilda club code cleanup — `SKN` → `STK`:** the repository currently hard-codes St Kilda as `SKN` in `data/clubs.csv`, `GameDB.CLUB_ORDER`, the player datasets/history and therefore football-facing result rows. There is no good presentation reason for `SKN`; use the conventional **`STK`** abbreviation everywhere the user sees or reasons about club codes. Treat this as a data-key migration, not a one-line label patch: update canonical club/data keys and every dependent reference, and provide a save migration/alias so existing careers containing `SKN` continue to load correctly rather than losing St Kilda lists, history, fixtures or records. Acceptance: all new careers/data use `STK`; no user-facing screen emits `SKN`; an existing save made with `SKN` loads into the same St Kilda state under `STK`; tests cover fixture/list/history/save migration.
- **Player role-allocation / draft-position distribution audit — REOPEN:** Gryan Miers is being labelled **Wing** in the user's list even though the source data explicitly lists him as `FWD`, and his real football role is a pure small/creative forward rather than a wing or pressure-forward. **Bodhi Uwland is also being treated as a Key defender despite being a 188 cm medium/rebounding defender who can take lockdown jobs but is not a key-position defender.** Code inspection shows both primary-role and subtype problems. `Ratings.derive_all()` chooses the primary role largely from season-stat role scores, then only applies two hard-coded forward corrections; a player read as `MID` can receive `FWD` only as a secondary role, and `Roles.is_wing()` can then mislabel him from stat shape. Separately, defender subtype classification currently ignores height/size entirely: `PlayerProfile.player_type()` picks between training archetypes, where **Key defender = intercept 3 + pressure 2** and **Rebounding defender = carry 3 + intercept 2**. That means a medium defender with strong intercept/one-percent/pressure numbers can become a 'Key defender' simply because he is less of a ball carrier. Do **not** fix these with one-off Miers/Uwland overrides alone. Re-audit the whole role classifier against football reality and source listed positions, especially MID↔FWD, MID↔DEF, and defender subtypes. Audit whether the current binary Key/Rebounding defender labels are themselves too coarse; a medium/general/lockdown identity may be needed if it better describes real usage, but prefer the smallest model that avoids false key-position labels. Measure source `real_pos` vs derived primary/secondary roles across the full 2026 pool; manually inspect representative archetypes (small forwards/creative forwards, key forwards, rebounding defenders, medium/lockdown defenders, true key defenders, genuine wings, inside mids); quantify draft-pool counts and match-day coverage by role before and after any change. Source listed position, height and actual football usage should be meaningful evidence, with stats used to refine dual-role capability/archetype rather than casually overwriting an unambiguous football role. Preserve legitimate dual-role players. Acceptance: Gryan Miers is a forward; Bodhi Uwland is not labelled Key defender; true key defenders require credible key-position evidence rather than merely high intercept/pressure; known pure forwards/defenders are not routinely converted into midfielders because of disposal volume; genuine wings such as Harvey Langford remain distinguishable from inside mids/forwards; the league draft has a plausible supply of FWD and DEF options without artificial quota stuffing; and regression tests cover representative named and archetypal cases.
- **Form streak colour bug:** in the hub/form string (for example `Form: Poor · LLWL`), wins should be visually distinguished from losses. Render `W` in the positive/green result colour while losses remain in the loss/negative colour; preserve accessibility/legibility and do not rely on colour alone if the surrounding UI ever removes the W/L letters. Acceptance: a mixed streak such as `LLWL` clearly shows the `W` in green/positive colour without changing the text content.
- **Current-list club identity bug:** on `My list`, the guernsey/number chip is coloured from each player's stale source/original club (`GameDB.club_colours(str(p["club"]))`), so a drafted Melbourne list appears as a patchwork of Carlton/Geelong/etc. colours even though every player now represents Melbourne. On current-club contexts (My list, selection, training and similar squad-management screens), visual club identity must come from the player's **current in-save club**, not source-data provenance. Historical/original-club colours belong only in explicit history/drafted-from contexts. Acceptance: every player row on Melbourne's current list uses Melbourne red/blue (and equivalently for every other user club), with no stale former-club colour implying current allegiance.
- **Role allocation / draft positional-supply re-audit:** the classifier is still producing clearly wrong football identities and likely contributing to the draft's shortage of forwards and defenders. Concrete example: Gryan Miers is listed in the source data as `real_pos=FWD`, but the current primary-role classifier ignores listed position except for two hard-coded corrections, classifies primarily from stat-shape, and only uses a listed forward role as a **secondary** fallback for a player already classified MID. Once Miers becomes MID, `Roles.is_wing()` can label him `Wing` from carry/disposal versus contested percentiles, producing the screenshot's incorrect identity. He should be treated as a forward (small/general forward; creator rather than a pressure-forward archetype), not a wing. Do a league-wide role-allocation audit rather than adding one-off Miers corrections. Compare generated primary/secondary roles against reliable listed-position evidence and obvious football usage, with special attention to high-possession half-forwards/creative small forwards and rebounding defenders that stat-shape can pull into MID. Measure resulting primary-role and playable-role counts across the full draft pool and whether a normal draft can actually supply 6 FWD + 6 DEF per club without forcing obvious misclassifications. Preserve genuine dual-position players, but do not use secondary roles to paper over a systematically midfield-heavy classifier. Acceptance: known sanity cases such as Miers classify plausibly; forward/defender supply supports league-wide roster construction; position filters and draft needs reflect players who genuinely play those roles; and seeded distribution tests guard against the pool collapsing toward MID again.
- **Android battery / thermal audit:** phone playtesting is draining battery and heating the device far more than expected for the game's visual complexity. Treat this as a profiling task before optimisation. Measure power-relevant behaviour separately on an idle hub/menu, a paused match, a live match at 1x, and accelerated playback. Record actual FPS/refresh rate, CPU frame time, render frame time, draw/redraw frequency, active `_process` callbacks/timers, and whether the app continues doing meaningful work while visually idle. Concrete leads already visible in the repo: `project.godot` does not set an explicit FPS cap / low-processor mode, so a high-refresh Android display may be rendering far more frames than the game needs; `PitchView.gd` calls `set_process(true)` and its `pause()` only flips `playing = false`, so its per-frame callback continues while paused even when little is changing. These are audit leads, not assumed root causes. Compare a sensible capped rate (for example 60 fps, and lower when static if Godot permits cleanly) against current behaviour without degrading match readability or touch response. Acceptance: identify the dominant battery/thermal costs with measurements, eliminate unnecessary idle/per-frame work, and verify the game no longer keeps the phone hot or burns disproportionate battery during a normal play session. Do not trade simulation correctness for battery life.
- **Round simulation / Play match performance regression audit:** phone playtesting reports that **Sim round takes far too long**, and the delay after tapping **Play match** appears to get progressively worse as the season advances. Profile this by phase and by season round before optimising: benchmark cold-device runs at R1/R6/R12/R18/R24 for (a) `prepare_interactive_match`, (b) one background `Season.simulate`, (c) a full `Season.play_round`, (d) rival XP/training + `_after_round`, and (e) autosave/serialization; repeat after a long/hot session to separate state-growth from Android thermal throttling. A concrete architectural cost is already visible: `prepare_interactive_match()` synchronously simulates **every other match in the round before the user's MatchSim is even created**, so tapping Play match blocks on roughly eight full background simulations. Background `Season.simulate()` also runs the full `MatchSim.run()` path, which generates rich match state/events intended for watched/reviewed games even though most rival matches only need their result and stats. Audit whether a non-visual/background mode can suppress presentation-only event/log work while preserving identical football outcomes and award/training stats. Also inspect any season-length-dependent scans/allocations (including `club_form()` walking accumulated results) and save growth. Acceptance: Play match gives immediate transition feedback and reaches the user's match without waiting unnecessarily for unrelated fixtures; Sim round has a measured target suitable for phone use; R24 is not materially slower than R1 except for justified bounded work; background fast-sim produces the same seeded scores/player/team stats needed by the career; and no optimisation changes balance or RNG outcomes.
- **Vignette playtest reachability problem — BLOCKER FOR THIS PLAYTEST:** the current centre-bounce prototype is still not appearing in organic phone playtests. This now includes a match decided in the final minute, which is strong evidence that the issue may be more than simple rarity. The nominal trigger is a centre bounce in Q4 after 100 match minutes with the margin within 12 points, but `_moment_ready()` also gates moments behind the per-quarter moment cap / chain gap and `_boundary_moment()` checks other moment types first. Audit whether competing Q4 moments, `MAX_MOMENTS_Q`, `MOMENT_GAP`, trigger ordering, or centre-bounce state can make the vignette effectively unreachable even in close finishes. Do not ask for further organic vignette testing until it is deliberately reachable. For prototype validation, add a temporary/manual playtest trigger or otherwise guarantee one vignette opportunity in a normal test match without changing MatchSim's underlying football outcome. Acceptance: a tester can deliberately reach the vignette in one match without needing a lucky close finish; add targeted coverage proving the vignette can actually fire through the real MatchScene flow; production frequency must be reconsidered separately after the scene passes the phone-playtest gate.
- **Pre-match loading beat / vignette opportunity:** pressing “Play match” currently appears to freeze for several seconds while the match scene/state loads, which feels like the app has stalled. Cover that unavoidable wait with an immediate lightweight transition/loading beat in football language, e.g. “Warming up”, “Running through the banner”, “Final instructions”, rather than a generic spinner. Consider this a natural place for a short pre-match vignette (players warming up, entering through the banner, coaches' box, crowd/ground establishing shot) that hides loading and builds match-day atmosphere. Guardrail: do not add a heavy animation that makes load time worse; the visual must appear immediately and remain skippable/non-blocking where practical. Acceptance: after tapping Play match, the user gets instant feedback that the game is progressing, never a dead/frozen screen, and the transition feels like part of match day rather than a loading screen.
- **Opposition danger with no player lever:** the assistant can identify an opponent as a major danger (for example, Bodhi Uwland dominating from defence) while the player has no available tactical action that can plausibly reduce that player's influence. This makes the report informative but not actionable and undermines the core decision loop. Do **not** solve this by making every opponent universally taggable. Diagnose danger by role and ensure that when the game elevates a player as an actionable threat, at least one football-appropriate counter exists in the current decision set (for example a forward matchup/run-with role against a rebounding defender, changing who is played through, or another role-specific response). If there is genuinely no direct lever, phrase it as an observation rather than a problem the user is expected to solve. Acceptance: “Opposition danger” never presents a player-specific tactical problem with zero plausible player response; any added counter has a real, measurable trade-off and uses the same non-psychic information available to the user.
- **Run-of-goals intervention audit:** in a phone playtest Brisbane kicked eight unanswered goals and, once the run started, the game repeatedly asked after subsequent goals whether to **Throw numbers at it** or **Slow it down**. The user tried interventions and perceived no effect. This may be a legitimate case of being outclassed rather than a broken mechanic, so diagnose before tuning. Audit two things separately: **cadence** (the same run-of-goals prompt should not fire mechanically after every additional goal in one streak; repeated calls need a meaningful cooldown/state change) and **efficacy** (surge/hold should produce measurable short-term effects in the directions their copy promises, without guaranteeing that a weaker side stops the run). Use paired seeded states from the same score/run situation with each option and the no-change/default choice; measure next-N-chain clearances/territory/scoring, opponent scoring, and leg cost. Also verify repeated calls do not stack/reset in a way that makes them misleading or ineffective. Acceptance: each option has a statistically visible, bounded trade-off; a strong opponent can still overwhelm it; and the player is not spammed with the same decision every goal while nothing new has changed.
- **Draw frequency validation:** home-and-away draws are already mechanically possible: `Season.record_regular()` records equal scores as a draw and awards two premiership points, while `MatchSim.needs_extra_time()` only invokes extra time when `finals_mode` is true. Existing league-balance measurements report a draw rate around **1.1–1.4%**, which across an 18-club, 24-round season (216 matches) is roughly **2.4–3.0 draws per season** — already in the desired ballpark. Pin this behaviour so later scoring/balance changes do not accidentally eliminate draws or make them too common. Do **not** force a quota of exactly 2–3 every individual season; draws should emerge naturally from scores, with the long-run mean around 2–3 league-wide per 216-match season and natural year-to-year variance. Finals must never finish level: ordinary finals use extra time / next-score resolution, with any ladder-position fallback treated only as a defensive failsafe. Acceptance: large seeded season batches average roughly 1.0–1.5% regular-season draws, ladder points/history record them correctly, and finals always produce a winner through the intended extra-time path.
- **Post-elimination finals follow-through:** if the user's team misses the finals or is eliminated, the hub currently removes week-by-week control and offers only **“Sim to Grand Final”**. Code inspection confirms `_week_actions()` sends every non-bye/no-upcoming-match finals state straight to `_on_sim_to_end()`, which loops through the entire remaining series. That makes the league suddenly stop feeling alive at the most important time of year. Give the player a way to **follow the finals week by week** even when their club is out: at minimum offer `Sim [current finals week]` / `Next finals week` so each Wildcard, Qualifying/Elimination, Semi and Preliminary week resolves separately and its results can be reviewed before continuing. Keep `Sim to Grand Final` as an optional fast-forward, not the only path. Prefer reusing the existing round-results/finals-bracket presentation rather than building spectator match controls unless separately justified. Acceptance: a non-finalist can advance one finals week at a time, see every result and evolving bracket, stop between weeks, and still choose to skip the remainder; season awards/off-season do not trigger until the series is actually complete.
- **Grand Final result presentation lacks payoff when fast-forwarding:** after `Sim to Grand Final`, the game currently ends on the generic round-results modal with only `Premiers: [club]` and the final score. This is mechanically correct but dramatically flat for the season's climax. Do not build a separate throwaway fix if the broader post-season flow is imminent; fold this into the finals-follow-through / season-end presentation work. The Grand Final should get at least one distinct completion beat before the season story/awards flow: clear premier/runner-up identity, final score, and enough visual/pacing hierarchy to feel like the league has actually crowned a champion. If the user fast-forwards, they should still land on that climactic beat rather than an ordinary results popup. Acceptance: the Grand Final never feels identical to a normal round result, whether watched week-by-week or reached via fast-forward.
- **Grand Final / premiership climax presentation:** phone playtesting confirms that `Sim to Grand Final` currently ends on the generic round-results modal: a small **Grand Final** label, `Premiers: Greater Western Sydney`, two score rows and a **Continue** button. Code inspection confirms `_show_results()` is the same generic results overlay used for ordinary rounds, with only one extra `Premiers:` line when the season is over. That is far too unceremonious for the climax of a full season, even when the user's own club has already been eliminated. Give the Grand Final a bespoke end-of-season result presentation with clear escalation and a proper premiership reveal: establish the matchup/result, reveal the winner as premiers, give the final score/margin enough visual weight, and then hand off cleanly into the season-story/awards sequence. Fanfare should come from pacing, hierarchy, club identity and a sense of occasion rather than generic particles or a giant stat dump. If the user fast-forwards the finals, they should still land on this climax rather than an ordinary round popup. Acceptance: the Grand Final can never be mistaken for a routine fixture result; the premier reveal feels like the culmination of the league season on phone; the result is still quick to read/skip on repeat careers; and `Continue` leads into the proper post-season flow rather than making the season simply stop.
- **Season story / campaign recap — separate from awards night:** the existing `Season Review` is mostly a stat sheet plus league awards: finish/record/points, PF/PA/percentage, best win, worst loss, longest win streak, goals, a W/L strip, final ladder, board verdict, awards and achievements. That is useful, but it does **not** yet give the emotional/narrative payoff of finishing a long campaign. Add a concise **Your season / Season story** recap after the Grand Final that tells the story of the user's year in football language, separate from the awards panel. Treat it like completing a major RPG campaign: identify the season's arc rather than dumping every round. Candidate beats include the opening trajectory, longest/biggest winning and losing runs, a genuine finals push or collapse, defining wins/losses, key performers, important injuries that changed the side, major improvers/breakouts, and how the year ultimately ended. **Also include the football identity the player actually coached into the side across the year:** e.g. `We played through the corridor most weeks`, `Nick Daicos was our focal point in most matches`, `We were conservative with legs and rotated hard`, `We usually backed our contested game`, `We changed plans often rather than sticking to one style`. These tendencies must come from actual season usage, not generic flavour text. `MatchSim.result()` already exposes `tactics_history`, `stars`, `interchanges`, `moments`, `impact` and related match data, but `CareerSave.slim_results()` deliberately strips most of that from `season_log` on save/load; therefore if the recap needs to survive a reload, track a **small incremental season-story ledger** as matches finish (plan-quarter counts, play-through/focus usage, rotation philosophy counts, notable streaks/results, significant injuries, player development/performance candidates) instead of retaining giant match logs. Keep it curated: roughly 5–8 memorable beats plus a short `How we played` identity block, not a timeline dump. Do not conflate this with awards night; Brownlow/Coleman/AA/B&F remain separate recognition, while the story answers **what happened to us this season and what kind of side were we?** Acceptance: after a full season, the user can read the recap and recognise their own campaign and coaching habits; tendencies are quantitatively grounded in actual usage (e.g. majority-of-quarter/match thresholds rather than one isolated call); the same recap survives save/reload; major injuries/improvers only appear when genuinely season-defining; and the presentation avoids number vomit while preserving enough concrete detail to feel earned.
- **Season Review mobile scroll / replacement path:** on phone, the current Season Review can extend below the viewport and **cannot be scrolled**, so the lower sections/actions become unreachable. Code inspection confirms `SeasonReviewScene.gd` puts its main VBox directly inside a full-screen `MarginContainer` with no enclosing `ScrollContainer`; once the content height exceeds the screen, it simply overflows. Fix the current usability defect even if this screen is later substantially replaced by the richer post-season campaign recap. The comprehensive redesign should treat the whole post-season flow as a vertically scrollable or staged mobile experience rather than one oversized static page. Acceptance: every section and action is reachable at narrow Android widths; no content is clipped below the viewport; and replacing the old summary with the richer season-story flow must not regress scroll/touch behaviour.
- **Tired-star event / rotation-philosophy audit:** the recurring **“[star] is running on empty”** moment (e.g. Nick Daicos / Ed Richards) is already becoming stale and is asking the player to micromanage something the rotation system should normally handle. Code inspection confirms the tension: auto-rotations already exist, but under `Normal rotations` ordinary players come off below 70 energy while stars are deliberately ridden to 50; meanwhile the tired-star event fires at **58**, so Normal rotations intentionally creates a manual prompt before the automatic star rotation threshold. The event key includes the quarter (`tired|player|quarter`), so the same star can also generate the same decision again in later quarters. Rework the responsibility boundary: under **Normal rotations** and **Rotate hard**, tired players/stars should be rotated automatically according to the chosen philosophy without repetitive intervention cards. Reserve explicit fatigue decisions for **Ride the stars** (or genuinely exceptional match states where overriding the philosophy is meaningful), because choosing that philosophy is the player's deliberate instruction to keep stars out there longer. Audit thresholds, bench availability and repeat cadence so the system cannot spam the same star every quarter. Acceptance: selecting Normal means the coach can trust routine rotations to happen automatically; selecting Rotate hard gets stars off earlier; selecting Ride the stars knowingly risks cooked stars and may surface a rare meaningful intervention; the same generic running-on-empty card does not recur mechanically; and fatigue/rotation outcomes remain measurable in minutes/energy/performance without adding UI clutter.
- **Set-shot location vs conversion audit:** phone playtesting suggests the decision card **“from 30 metres, straight in front”** is missed far too often (user estimate ~80% misses). The current code confirms a likely modelling/presentation mismatch: `_offer_set_shot()` randomly labels 40% of set-shot moments as “30 metres, straight in front” and only multiplies the generic marked-shot goal probability by 1.18; for an average shooter the underlying `inside50_goal` baseline is 0.269, so an easy-looking 30 m shot can still have a low conversion chance. Audit and fix rather than merely changing the words. Shot location/difficulty should be causally tied to the actual shot probability (and, where possible, the real field position) rather than independently random flavour text. **Use real AFL calibration rather than guessing:** AFL.com.au/Champion Data reported 2024 directly-in-front set-shot accuracy of **92.20% from 15–30 m** and **73.87% from 30–40 m**. A nominal 30 m straight shot therefore belongs in a clearly high-probability band before kicker/fatigue modifiers; the user's rough 60% expectation is conservative relative to that evidence. Calibrate all distance/angle bands against comparable AFL data, then layer player goalkicking/accuracy, fatigue and tactical effects on top. Acceptance: 30 m directly in front is a high-probability AFL shot for an ordinary league-level player, elite/poor kicks still differ meaningfully, pocket/long shots remain materially harder, and the qualitative copy (“He should kick it”, etc.) matches the actual probability band. Add seeded distribution tests by distance/angle and kicker quality.
- **AI plan adaptation / Controlled-tempo free-counter audit:** phone playtesting showed an opponent repeatedly using **Defensive press** across quarters while trailing, while the user could answer with **Controlled tempo** even with subpar ball users and seemingly counter it for free. Current code explains both concerns: `ai_tactics()` only abandons the AI club's standing plan when the margin crosses a tactics-read threshold (`18 - 8 * read` points), so a naturally defensive side can remain in Defensive press while losing by a smaller margin; meanwhile `PlanFit.gd` explicitly gives Controlled tempo **no list-fit requirement at all** (`fit == 1.0` for every list), even though its identity is about reducing pressure/clangers and should plausibly depend on ball use/composure. Audit, do not just make the AI psychic. Test AI plan choices by quarter, margin, standing-plan identity and recent observed match state using only information available to a coach; determine when a losing side should persist with its style versus chase the game. Separately test Controlled tempo with strong vs weak disposal/decision-making lists against Defensive press. Acceptance: a defensive AI can sensibly persist when appropriate but does not mechanically sit in a losing countered plan all game; Controlled tempo is not an equally effective press-counter for poor ball-use sides; and there remains no hidden direct read of the user's selected plan.
- **Key-forward vs key-defender balance audit:** phone playtesting suggests good key forwards are consistently getting the better of good key defenders. Do not assume a nerf/buff yet; measure it. The current matchup system only sends a small explicit share of inside-50 entries through named key-forward matchups (`KEY_TARGET = 0.06`), while most forward-50 outcomes still come from broader line strength and shooter selection. On explicit duels, forward aerial ability is `70% marking + 30% height` while defender aerial ability is `45% intercept + 30% marking + 25% height`, then layered on top of team forward-mark vs defensive-intercept strength. Audit whether strong key forwards are over-performing overall, whether strong key defenders materially suppress them, and whether the named matchup system is too infrequent to matter. Run seeded matchup matrices across elite/good/average key forwards vs elite/good/average key defenders, tracking target share, mark win rate, shots, goals, spoils/intercepts and matchup-report verdicts. Acceptance: elite forwards can still win games, elite defenders can genuinely contain them, equal-quality matchups are not systematically tilted one way without evidence, and matchup presentation reflects the measured duel rather than reputation.
- **Coleman / individual goalkicker plausibility audit:** Round 18 phone playtesting has **Brodie Kemp leading the Coleman with 48 goals**, ahead of established spearheads. This is surprising enough to audit, but not automatically a bug: the shipped 2026 data already has Kemp at **39 goals from 25 games (1.56/game)** and listed as `FWD`, so the model has genuine source-season evidence that he can score; a redraft can also create unusual opportunity. The current calibration only checks **how concentrated** team goals are (top goalkicker ≈16% of club goals, top three ≈38%), not whether the players who become league-leading scorers are plausibly the best/most-used forwards. Add season-level validation across many drafted leagues: correlate goals/game and Coleman finishes with goalkicking, accuracy, marking/forward role, actual source scoring and team opportunity; inspect outlier Coleman leaders manually; and measure whether middling forwards can routinely become 60+ goal spearheads merely because shooter selection funnels chances to them. Preserve genuine breakout seasons and redraft weirdness — do not hard-code famous names or force the real-world Coleman order. Acceptance: unusual winners remain possible, but league-leading goal seasons are usually produced by players with a credible scoring profile and/or clearly explainable opportunity; strong source scorers are not systematically suppressed; and the long-run Coleman goal totals/distribution remain AFL-plausible.
- **Sim-round score / blowout plausibility audit:** phone playtesting produced some extreme-looking simulated results, including Melbourne 18.13 (121) defeating Port Adelaide 3.6 (24), a **97-point margin**, alongside several low losing totals in the same round. First clarify that Sim round is **not using a separate arcade score generator**: `Season.play_round()` calls `Season.simulate()` → `MatchSim.run()`, the same possession-chain engine used by watched matches, with AI/default tactics rather than live human interventions. Existing league-balance data says drafted leagues currently produce **60+ margins about 6.7–7.8% of matches and 100+ margins about 0.2–0.5%**, versus roughly 15.5% / 1.9% in the referenced real AFL season, so one 97-point result is not by itself evidence that blowouts are too common. Audit the **distribution and causes**, not the screenshot alone: compare full-season simulated score/margin distributions with real AFL and with watched-user matches; track 0–39, 40–59, 60–79, 80–99 and 100+ margins, team scores under 40/50 and over 120/140, quarter-by-quarter runaway frequency, and whether particular tactics/form/momentum/list mismatches create implausible snowballing. Use the same drafted league states and paired seeds where possible to compare `Season.simulate()` with equivalent live/default-call matches and confirm score generation is identical when decisions are held constant. Acceptance: no hidden fast-score path diverges from MatchSim; extreme scores occur at plausible long-run rates and for understandable football reasons; simmed rounds and equivalent watched/default-call matches have matching seeded outcomes/distributions; and any fix targets the actual causal mechanism rather than globally compressing scores.
- **Autosim vs played-match injury-rate parity audit:** phone playtesting gives the impression that the user's players get injured more often when matches are autosimmed than when watched/played. Do not assume this is true; measure it. Code inspection finds **no explicit autosim injury multiplier**: both paths use `MatchSim`, `_plan_injuries()` calls the same `Injuries.roll()` with the same `BASE_CHANCE`, durability and weekly-risk modifiers, and current results always carry an `injuries` record so `Injuries.apply_match()` should not perform the legacy fallback roll a second time. However, there are two real path differences worth testing: (1) an interactively prepared user match currently uses `season.next_seed(99)` whereas a Sim-round user match uses the fixture-index seed, so the same fixture is not an injury-identical replay; and (2) injuries are planned for ground + bench but only actually occur once that player has taken part, so rotation philosophy/manual rests can change how many bench players are exposed. Run large paired tests from identical list/selection/soreness states comparing pure autosim with a live/default-call path, holding rotation policy constant, and report injuries per team-game, per player-game, initial-18 injuries, bench-player injuries, severity mix and concussion rate. Also test Normal/Hard/Ride-stars separately so participation exposure is understood. Acceptance: after controlling for players who actually took the field, autosim and played matches have statistically equivalent injury probability/severity; no result is double-rolled; any genuine difference is traced to an intentional exposure/input difference rather than hidden mode logic. If parity already holds, add a regression test and leave balance unchanged.

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

### Implementation record — match calls that matter (2026-09-29, branch `claude/match-calls`)
- **Playtest finding:** the director lost four straight matches by 40+ and found game-plan choice "meaningless button clicking". Measured on a Demons list without Gawn v Collingwood (80 matches a plan):
  - AI clubs countered your last plan at every break, and it was never wrong. With that switched on, no plan beat Balanced, and a press or contest plan cost 4-5 points of margin.
  - Plans ignored the list: only Through stars cared who played.
- **Changes:**
  - `PlanFit`: each plan leans on the players who carry it (a press on pressure players, corridor footy on runners, the contest on ball-winners and a ruck, controlled tempo on good kicks and marks). Its upside scales with how they compare with the league; its costs do not, so a plan the list does not suit is a real risk.
  - AI clubs play the plan their own list suits as their usual game, shown on selection ("Their usual game: Defensive press"), and adjust only to the scoreboard. The automatic counter of your last plan is gone.
  - The plan chooser (selection, Coaching, quarter breaks) names who in your side makes the plan work and how they compare: "Your pressure players are among the best: ...". No verdict, no suggested plan.
  - Tags follow football: only their midfielders can be tagged, the note names the midfielder who goes to him (your tagger, or the one with the most pressure), and the AI tags only your midfielders.
- **Measured after (same set-up):** Balanced 66%, +12; Defensive press 95%, +35; Win contest without a ruck 62%, +9. Before, those were 65%/+11, 56%/+8 and 59%/+7. League balance, calibration and balance suites pass.
- **Also from the playtest (separate PR, `claude/honest-feedback`):** a hit-out scores 1 in the Player Rating (it was 3), and Needs a lift follows the Player Rating shown on screen.

### Implementation record — the match tells its story (2026-09-29, branch `claude/match-story`)
Design audit §4.3: the feed showed only scores, injuries happened after the siren off screen, and full time listed team facts but not the moments the match turned on.
- **Injuries happen in the match (`MatchSim._plan_injuries`, `_check_injuries`):**
  - Each player's roll is the same one as before (`Injuries.roll`, same chance and severity), drawn from the match's own injury dice so play is otherwise unchanged. It comes with a minute of the match.
  - At that minute he goes off for good and the best bench player for his spot comes on. A matched key defender's forward goes to the next defender.
  - `Injuries.apply_match` records the match's injuries on the lists. A result without that record falls back to the old roll.
  - Measured over 200 matches: 0.71 injuries a side a match, the same rate as before.
- **Feed (`MatchNotes.story_feed_line`):**
  - A player going off hurt, and who replaces him (always shown).
  - A goal from an intercept that takes or levels the lead ("From Moore's intercept.").
  - A missed set shot in a close last quarter.
  - At most one intercept and one miss line a quarter; about 2 lines a match in all, most of them injuries.
- **Full time, "How it went" (`MatchNotes.turning_points`):** leads with the score that put the winners in front for good (when they had been behind or level after quarter time), a star who went off hurt before the last quarter, and your missed set shot late in a close loss. Team facts fill the rest, three sentences at most. Quiet games stay quiet: nothing is invented.
- **Left out on purpose:** a player's third clearance in a quarter (clearances are not logged as events); momentum (a separate audit item, §4.7).
- **Tests:** `test_match_game.gd` (`_test_in_match_injuries`, `_test_match_story`). Calibration, league balance, balance, injuries, save, matchday and match visual suites pass.

### Implementation record — traits and synergies you can feel (2026-09-29, branch `claude/traits`)
Design audit §4.5: synergies worked in code but most were too small to feel, and a trait never said when it was at work.
- **Measured first:** each synergy was forced on and off over paired seeded matches (800 per synergy, noise about ±2 points).
  - Before: Engine room +7 points a match, Lockdown unit +5.6, Tall-small forward line +4.2, Intercept wall +3.4, Supply line +2.6, Running machine +0.7.
  - The four weakest were raised toward the audit's "about a goal a match":
    - Tall-small: +8% goal chance on forward-50 shots (was +5%).
    - Intercept wall: -9% on the opposition's (was -5%).
    - Supply line: +12% metres gained (was +6%).
    - Running machine: tires 30% slower (was 15%).
  - After: Intercept wall +6.4, Tall-small +5.7, Supply line +4.3, Running machine +4.2.
  - No club carries more than three, so there is no stacking cap; the league balance, calibration and balance suites pass.
- **Crumbers at the fall of the ball:** a Crumber is twice as likely to be the one who gathers a spill. Midfielders' weight at a forward-50 spill drops from 0.25 to 0.15, so crumbed goals are mostly forwards' (62%, was 55%, measured over 400 matches).
- **Surfaced (from the log, no numbers):**
  - A Crumber's goal off the pack reads "Crumbing goal" on its feed row.
  - A Big-game player's goal in the last quarter or a final: "X lifts when it matters." (once a match per side).
  - Full time, "Your synergies": the stat each of your active synergies plays on, yours against theirs ("Engine room: clearances 40 to 33.").
- **Not done:** synergies tied to game plans (PlanFit), and trade-off costs on synergies (the audit's risk mitigation). Both wait for play to show a dominant build.
- **Tests:** `test_match_game.gd::_test_traits_surfaced`; the crumb test now has margin.

### Implementation record — the draft shows your side against the league (2026-09-29, branch `claude/draft-shape`)
Design audit §4.6: the league draft decides most of a first season, but while drafting the player saw only position counts. The director's first season began with an unfixable ruck hole.
- **Change:** from eight picks, the draft's My list shows "Your side so far, against the league". It gives one line each for midfield, ruck, attack and defence, in the words the selection screen uses ("Ruck: among the weakest."). It compares your picks with every club's picks so far, through the same engine line values (`Matchup.standing`).
- **Not done, deliberately:** no suggested player, no "draft a ruck", no projected ladder, no numbers. The need counts stay. The intake draft is left alone, since rookies rarely change a side.
- **Tests:** `run_draft_ui_tests.gd::_test_side_shape`: none before eight picks; four lines in words after.

### Implementation record — "With us" and milestones (2026-09-29, branch `claude/with-us`)
Design audit §4.8 (and ARD-M7-003, lightly): the game had each player's full career, awards and flags, but never said what he had done for *your* club.
- **Profile:** "With us since 2027: 87 games, 42 goals. Best and fairest 2029. Premiership 2030." (`GameState.with_us_text`). It counts every spell at your club, this season included. Best and fairests come from the honour roll; flags are the premierships won while he was on the list. It is shown for your own players only.
- **Milestones:** 50, 100, 150 and so on, in career games (the AFL convention). "Jack Viney plays his 100th game." is marked on the hub and selection in the week he reaches it, in ordinary text (injury notes stay red). Nothing on other weeks, and nothing for a career not on record in full.
- **Not done:** best games from Player Ratings (no per-match history is kept), and a club best-and-fairest moment. Both need new data.
- **Tests:** `test_selection.gd::_test_with_us_and_milestones`.

### Implementation record — numbers out of decisions (2026-09-29, branch `claude/no-numbers`)
Design audit §4.9: set-shot odds, a kicker's attribute numbers, a tired star's legs percentage and a trade offer's percentage sat on decision cards.
- **Set shot:** each option reads in words.
  - The shot: "He should kick it" / "Better than even" / "A coin toss" / "A tough shot" / "A long shot".
  - Play on: "The pass usually sticks, then he shoots from closer: a coin toss."
  - The bomb: "Now and then it falls for a goal; more often a behind or they rebound it."
  - The kicker: "Your call. X is a reliable kick, and he is tiring."
  - The odds underneath are unchanged.
- **Tired star:** "Your star's legs are gone." (no percentage).
- **Trade refusal:** "your offer is a little short / well short of what they give up".
- **Rotation text:** "Your stars stay on until they are cooked." (was "80+ players").
- **Kept, deliberately:** the expected-points readout in the full-time Stats tab (a drill-down), and training costs (a price you pay is a fact you decide on).
- **Tests:** the set-shot test now requires words and no odds.

### Implementation record — momentum is real (2026-09-29, branch `claude/momentum`)
The match screen's momentum meter was display-only: the screen computed its own number from the events it showed, and the engine had no momentum. That is an incomplete feature, fixed here.
- **Engine (`MatchSim.momentum`, -1 away .. 1 home):**
  - A goal swings it 0.40 toward the scorers, a behind 0.10. The swing shrinks near the cap and grows when it turns the other side's run.
  - It keeps 93% each chain (halves in about nine chains, five or six minutes) and halves at a break. Capped at ±1.
  - Its only effect: the side it favours wins up to 4% more of the ball at stoppages and loose balls (`contest_winner`). The home-ground edge is 3%.
- **Meter:** every event carries the engine's value (`"mom"`), and the meter shows exactly that.
- **Measured over 600 matches:**

  | | Without momentum | With momentum |
  |---|---|---|
  | Scorers kick the next goal | 51.1% | 51.8% |
  | Same, after three in a row | 53.6% | 53.6% |
  | Goals a match | 25.1 | 25.4 |
  | Margin spread (SD) | 35.9 | 36.7 |

  Momentum averages 0.25 and spends 3% of a match above 0.6. The first setting tried (a faster fade, 88% a chain) barely moved and was not visible on the meter.
- **Tests:** `test_match_game.gd::_test_momentum`:
  - full momentum wins about 4% more of the ball;
  - a run of goals is capped;
  - one goal the other way arrests a strong run, two turn it;
  - it fades within ten passages;
  - events carry it;
  - the scorers kick the next goal under 56% of the time.

  `test_match_visual.gd`: the meter shows the engine's value and nothing of its own.

### Audit repair sprint (2026-09-29, from `docs/SYSTEM_REALITY_AUDIT.md`)
**Status:** `DONE` (merged 2026-09-30). Each repair is recorded, with its measurements, in the audit's appendix.
- **A. Live-match plan reset (P0):** the plan you take into a live match is the plan at the first bounce, proven by driving the live start. PR #104.
- **B. Test harness:** every suite has a check floor, deliberate skips say so, and a self-test proves missing checks fail the run. PR #106.
- **C. Moment cards:** calls last a real passage of play and are situational (surge v hold, set-shot choices). PR #105.
- **D. Tagging:** a real trade. A specialist tagger on their star is worth close to a goal; a good midfielder sent to tag, or a tag on an ordinary player, costs you. The AI tags only with a specialist on the ground. PR #108.
- **E. Plans:** Balanced is the safe call, counters are sized to one or two goals, and list fit decides whether a plan pays. Through stars goes through your best three. Each plan has one description, written from the engine. PR #110.
- **F. Morale, form and coaching:** the profile says what morale is doing; "Form" is now "Recent games"; coaching tactics sharpen a plan's upside, measurably but secondarily. PRs #107 and #111.
- **G. Loose ends:** the coach table is built before a live week's other matches, and dead code is gone. The AI's tactical read is measured and recorded as low-impact. PR #109.
- **Open, for the director:** a valuable AI read would have to infer your plan from observed play (no psychic AI); Controlled tempo's list-fit split is unclear; "Fire them up" is still a free gain.

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

## 1.12 P0 gate — System Reality Audit: does the mechanic actually work?

**Status:** `DONE`  
**Merged:** PR #103 as `ae4eb7b`; audit report is `docs/SYSTEM_REALITY_AUDIT.md`.  
**Priority:** `P0`  
**Autonomy:** `SUPERVISED — DIAGNOSIS FIRST`

### Trigger
The Momentum meter existed as a player-facing system even though MatchSim had no real Momentum state underneath it. That was not a design reason to remove Momentum; it exposed a more serious process risk: other "implemented" systems may also be UI-only, disconnected, written-but-never-read, statistically irrelevant, or tested only for existence rather than behaviour.

### Goal
Establish which current player-facing systems are **real**, which are only partially connected, and which do nothing meaningful.

This is an **audit before repair**. Do not start fixing individual findings while still discovering the scope unless a destructive/soft-locking defect makes continued testing unsafe.

### Required end-to-end trace
For every implemented player-facing mechanic, trace:

`player sees/chooses → state created → state stored → engine/system reads it → calculation changes → outcome changes → result is surfaced back`

A break anywhere in that chain is a finding.

At minimum inspect:
- Momentum and Team Form,
- traits and synergies,
- game plans/tactics and quarter-break calls,
- moment/event choices,
- tagging and defensive match-ups,
- Play through / focal-player instructions,
- positions/roles, selection and interchange behaviour,
- attributes and OVR where consumed,
- player form/morale/fatigue,
- injuries/suspensions where implemented,
- training, XP and passive reserves development,
- coaching Teaching/Tactics/Man-management effects,
- draft/scouting uncertainty and list/draft valuation systems,
- salary-cap consequences,
- every other implemented modifier/toggle/meter presented as consequential.

### Look specifically for
- state written but never read;
- return values/modifiers calculated then discarded;
- UI reading one value while MatchSim uses another;
- dead/unreachable branches and placeholder callbacks;
- effects overwritten, normalised away or applied after the result is decided;
- values technically connected but too weak/rare to matter;
- player/AI asymmetry;
- save/load dropping the state;
- report-only statistics presented as mechanics;
- tests that prove a widget/key/function exists but do not prove behaviour changes.

### Empirical verification
Where practical, use controlled paired-seed or identical-state comparisons: mechanic on/off, trait present/absent, plan A/B, tag/no tag, form neutral/high, coach effect weak/strong, and equivalent deterministic checks for non-match systems.

The question is not whether every mechanic is perfectly tuned. The question is **whether it genuinely changes the thing the player is told it changes**.

### Classification
Every audited system gets exactly one factual status:
- `WORKING`
- `WORKING BUT QUESTIONABLE`
- `PARTIALLY CONNECTED`
- `UI / REPORT ONLY`
- `NO-OP`
- `DEAD / DISCONNECTED`
- `UNVERIFIED`

### Output
Create `docs/SYSTEM_REALITY_AUDIT.md` containing:
- executive counts by classification;
- critical player-facing no-ops/misleading systems first;
- system-by-system implementation path and behavioural evidence;
- what existing tests actually prove;
- weak/fake-confidence tests;
- recommended repair order.

Do **not** mark a system working because code exists or a test is green.

### Audit result (2026-09-29, PR #103)
40 systems were classified: 26 working, 7 working-but-questionable, 2 partially connected, 2 UI/report-only, 1 no-op, 1 dead/disconnected and 1 unverified.

Critical findings:
- A game plan chosen on Selection/Coaching is silently reset to Balanced immediately before a live match starts unless reselected in the pre-bounce box. Simulated rounds are unaffected.
- Moment-card choice policies produced less than half a point of margin difference across the measured sample despite roughly seven cards a match.
- Tagging cuts the target's disposals but did not produce a measurable team-margin effect.
- Through stars had no measurable result effect; Balanced was materially worse than several alternatives in the measured setup.
- Morale has a sizeable hidden match effect, while Coaching's player "form" display is report-only.
- Several plan descriptions quote effects that do not match the engine.
- Existing tests often prove storage/multipliers rather than outcomes; some guarded matchday checks can silently skip under load while the suite still reports pass.

### Gate
The audit itself is complete. Repairs are held for user review. Once released:
1. player-facing `NO-OP`, `UI / REPORT ONLY` (when presented as a mechanic), and serious `PARTIALLY CONNECTED` findings enter the execution queue ahead of unrelated feature expansion;
2. repair priority is player deception/no-op decisions → core gameplay importance → severity → simplest robust fix;
3. desired mechanics are **fixed, not deleted**, merely because their implementation is incomplete, unless the user explicitly changes the design.

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
**Status:** `DONE`  
**Merged:** PR #96 as `26d34a2`; key forward/defender assignments are selectable, play out in named contests, can be changed during matches, and AI can rematch.  
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

---

## ARD-M4-010 — In-match Momentum
**Status:** `DONE`  
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



## ARD-M5-012 — Draft AI asset valuation sanity
**Status:** `TODO`  
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
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

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
**Status:** `TODO`  
**Priority:** `P1`  
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
There is **no explicit combine task in the current canonical roadmap**, so restore it here rather than assuming it is already scheduled.

The Combine should give the draft pool more identity and evidence before selection:
- physical/athletic testing and relevant football testing where the game has meaningful underlying attributes;
- role/archetype clues, strengths and weaknesses;
- scouting uncertainty rather than exact omniscient ratings where appropriate;
- enough information to distinguish prospects with similar projected OVR/POT.

Do not make the Combine another number-vomit screen. Default to interpretable results/relative descriptors, with deeper detail available on inspection. Combine results should inform scouting, not override actual football production or make every athletic outlier a top prospect.

### Acceptance
- list needs are internally consistent and visibly update after each relevant selection;
- the player can explain what the squad lacks without reverse-engineering `can play` vs `NEED`;
- the pre-draft meeting gives useful direction and a few names without prescribing the answer;
- prospect inspection/Combine provides enough evidence for a deliberate choice rather than “pick the biggest POT number”;
- mobile presentation remains fast to scan and does not become another dashboard.


### Post-draft handoff — offseason ins/outs and board expectation
Finishing the National Draft currently drops the user straight into Round 1 of the new season. That skips the natural transition point where a coach should be told **what changed over the offseason and what the club now expects**.

Add a concise post-draft / preseason handoff before the new season hub becomes active.

At minimum show:
- **Ins:** drafted players, free-agent signings, trade arrivals and relevant coaching/staff arrivals;
- **Outs:** retirements, delistings/releases, free-agent departures, trade departures and relevant coaching/staff exits;
- **Draft:** the user's selections in one compact recap;
- **List shape:** only the most important resulting change(s), not another full roster dump;
- **Board expectation for the new season**, plus a short reason for it using the calibrated expectation model;
- any major staff vacancy/appointment that materially affects the club.

This should feel like the club closing the books on one offseason and opening the next campaign, not like another spreadsheet. It should be skippable/compact on repeat seasons but should never silently jump from the final draft pick to Round 1.

Acceptance:
- completing the draft always lands on the offseason summary before Round 1;
- every material player/staff movement made during that offseason appears exactly once;
- board expectation is shown before the first match, with a concise reason;
- the summary survives save/reload without duplicating events;
- mobile portrait remains readable without long scrolling.

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
- **List profile** — a compact league-relative read of what the list is actually good and bad at,
- how we win / how we get beaten,
- in-form players,
- out-of-form players,
- salary-cap information,
- Board Confidence.

Plain-English coaching insight first; supporting numbers second.

Before implementing more, inspect current merged Staff/coaching work and extend it rather than duplicating screens.

---

## ARD-M6-002 — Coaching staff gameplay
**Status:** `DONE`  
**Merged:** Phase 3 PR #62, former-player pathway PR #74, and gameplay-effects PR #77; teaching, tactics and man-management effects are all live.  
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

### Phone-playtest follow-up — coaching-market movement visibility and first-offseason audit
A full 2027 phone playtest produced **no noticeable coaching movement** from the player's perspective.

The coaching market **is implemented and live**: `GameState._close_season_awards()` calls `_coaching_offseason()`, which calls `CoachMarket.offseason()`. That system supports senior-coach sackings/contract expiry, retirements, internal/external promotions, vacancy chains, assistants being poached from the user's club, former-player pathway entrants and generated replacements. Existing long-run tests require steady senior-coach churn over 30 seasons.

So diagnose two separate questions rather than assuming the feature is absent:

1. **Did meaningful movement actually occur in the first off-season?**
   - instrument/log the 2027 close: senior-coach changes, assistant promotions, retirements, contract non-renewals, poaching and vacancies;
   - compare first 1/3/5 off-seasons across many seeds with later-career rates;
   - determine whether first-year guardrails/tenure/contract settings make the opening off-season unrealistically static.

2. **Could the player tell that it occurred?**
   - current movement is mostly emitted as capped coaching news and reflected in Staff records;
   - audit whether those changes are effectively invisible during the off-season flow;
   - surface notable league coaching changes in an appropriate off-season/news summary, with **your club's staff departures/appointments impossible to miss**;
   - the new Off-season wrap (ARD-M6-006) should include relevant coaching Ins/Outs without becoming a league-wide transaction dump.

Do not manufacture churn merely for spectacle. Some off-seasons can be quiet, but an AFL coaching world should visibly evolve over time.

Acceptance:
- measured first-five-season churn is plausible and not accidentally near-zero because of initial-state rules;
- senior-coach turnover, promotions and retirements occur at believable long-run rates;
- any coach leaving the user's staff is clearly surfaced and creates the intended vacancy/appointment interaction;
- notable league senior-coach changes are visible enough that a season-to-season player can recognise the coaching world as alive;
- if 2027 genuinely has zero significant changes in a seed, that can happen naturally, but the system's measured distribution must show it is not the default outcome.



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


### Coach-market movement visibility / frequency audit
**Claude audit required.** Phone playtesting through a complete season/offseason produced no obvious sense that coaches moved clubs at all.

The coaching market **is implemented**: `GameState._close_season_awards()` calls `_coaching_offseason()`, which runs `CoachMarket.offseason()`; the market supports senior-coach sackings/contract expiry, promotions, retirements, poaching from the user's staff, vacancy chains and appointments. Existing automated tests also prove movement can occur over long runs. That does **not** prove the live player experience is working.

Claude must run the final audit and report:
- whether any coach movement actually occurred in the user's first 2027 offseason under normal career conditions;
- league-wide counts per offseason for senior-coach changes, promotions, retirements, contract non-renewals, internal promotions and assistants poached;
- how often an entire offseason legitimately has little/no visible movement;
- whether the movement rate is football-plausible over 10–30 seasons;
- whether movement happens but is effectively invisible because it is buried in the news feed / staff screen;
- whether the user's own staff can realistically be poached often enough to matter without becoming churny;
- whether senior-coach turnover is too conservative in early seasons because of first-season/tenure protections.

Do not tune merely to guarantee a coaching carousel every year. Some quiet offseasons are believable. The requirement is that the system produces credible movement over time **and the player can actually notice important changes**.

If the underlying rate is healthy, improve presentation rather than forcing extra churn:
- include notable coaching ins/outs in the post-draft offseason summary;
- surface major senior-coach appointments/sackings clearly;
- surface any coach poached from the user's club as an explicit event requiring a response.

Acceptance:
- Claude provides measured movement distributions before changing rates;
- a multi-season career produces a believable coaching market with neither stasis nor constant churn;
- significant coaching changes are visible to the player;
- the user's first offseason being quiet is explainable by the measured system rather than assumed correct because tests pass.

## ARD-M6-003 — Board Confidence
**Status:** `DONE / FOLLOW-UP TODO`  
**Merged:** PR #84 as `48a805d`; confidence now moves relative to expectations, surfaces qualitative states, and explains why it changed.  
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

### Phone-playtest follow-up — expectation fairness is part of the lose-state contract
Board goals are **not randomly assigned** in the current implementation. At the start of each season, `GameState._open_board_season()` ranks every club by `Squad.strength()` and passes that rank into `ClubLife.board_goal()`:
- strength rank 1–4 → **Finish top four**;
- next finals-band clubs → **Make finals**;
- ranks 11–14 → **Finish top 12**;
- bottom group → **Win at least seven games**.

That is deterministic, but it still needs a fairness audit. A single pre-season squad-strength ranking can be wrong or too brittle, particularly for a rebuilding/young list, a newly redrafted club, a side carrying major injuries, or a roster whose OVR/role model does not translate cleanly to wins. The bucket boundaries are also abrupt: moving one underlying strength rank can materially change the season-long demand.

This matters more than ordinary flavour because **being sacked is currently the game's explicit hard career-ending lose state**: the Hub stops the career and tells the player to start a new one. Therefore the game must never kill a long save because an opaque or miscalibrated expectation was assigned.

Audit expectations against:
- pre-season list strength **and how well that metric predicts realised wins/ladder position**;
- previous-season finish and multi-year trajectory once history exists;
- age profile / rebuilding vs building vs contending phase;
- major known injuries/unavailability at the point the goal is set;
- recent list turnover and whether the club has deliberately moved into a rebuild;
- finals structure/wildcard context;
- uncertainty: boards should use a realistic **range/band of expectation**, not pretend the model knows the exact ladder order.

First-season/redraft careers need special scrutiny because there is no prior club trajectory: do not make “model ranks this list fourth” automatically equivalent to a punitive top-four mandate unless calibration proves that is fair.

The board may still be demanding. The goal is **earned pressure, not arbitrary safety**.

Acceptance:
- identical roster/context always yields the same explainable expectation; no hidden random assignment;
- pre-season expectation bands are calibrated against large simulated samples so “top four”, “finals”, etc. correspond to credible outcome distributions rather than one-point rank boundaries;
- rebuilding clubs are not routinely given top-four/finals-or-bust goals simply because of noisy raw list strength;
- genuine contenders can still receive demanding goals;
- the player can see a concise reason for the goal (e.g. list quality, last season, trajectory) without number vomit;
- two otherwise similar clubs do not receive radically different goals without an explainable difference;
- sacking remains a meaningful lose state only if the expectations feeding it are demonstrably fair and the warning path gives the player a real chance to recover;
- long-save probes verify the human is not disproportionately sacked due to expectation-model error.

---

## ARD-M6-004 — Contracts / trades / free agency
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

Build toward a complete AFL list-management ecosystem.

### Contract negotiation — important decisions need ceremony and guardrails
The current off-season UI lets the user tap `1 yr / 2 yr / 3 yr / 4 yr` and immediately executes `GameState.resign_player()` at a fixed `Contracts.asking_salary()`; Release is similarly immediate. That is too abrupt for one of the core dynasty/list-management decisions.

For expiring players, tapping a contract option should open a **dedicated negotiation screen/sheet** rather than instantly resolving the deal. The negotiation should make the decision feel consequential without turning every fringe player into paperwork.

The user must be able to negotiate **salary as well as term** with the player in question. The player's current asking salary is an anchor, not an immutable price.

Design direction:
- show player identity, age, current OVR/POT, current salary, requested salary, requested/available term, cap room after the proposed deal and list context;
- let the user propose a salary + term combination;
- the player can accept, reject, or counter based on understandable factors such as ability/value, age, morale, market demand, role/security and contract length;
- longer security can reasonably trade against salary in some cases; stars/young guns should have more leverage than fringe veterans;
- negotiation must not become a hidden dice casino. If randomness is used at all, keep it bounded and seeded, with the player's expectations legible enough that the user can reason about the offer;
- failed offers should not instantly destroy the relationship unless the offer is genuinely insulting or repeated bargaining warrants a consequence;
- preserve the possibility that a player walks to free agency if agreement cannot be reached;
- AI clubs should negotiate under equivalent cap/value constraints rather than magically signing everyone at fixed prices;
- **Release / delist** actions should have an explicit confirmation step with the consequences stated before execution;
- consider a lightweight "accept asking price" shortcut for routine deals so the system has ceremony where it matters without contract-admin busywork.

Guardrails:
- understandable and streamlined,
- AI follows same core constraints,
- no contract-admin busywork,
- important list decisions must not resolve from a single accidental tap,
- do not attempt all player movement systems in one mega-PR.

Acceptance:
- tapping an expiring player's contract no longer instantly commits the deal;
- salary and term are both negotiable;
- the user can see cap consequences before confirming;
- accepted/rejected/countered offers follow transparent football-list logic;
- Release cannot happen accidentally;
- save/reload preserves an in-progress negotiation or safely returns to the pre-offer state without duplicating the transaction;
- routine deals remain quick enough that managing 40 players does not become tedious.

Split into smaller authorised subphases when started.


### Contract/off-season copy cleanup
Phone playtesting exposed awkward/dehumanising wording at the top of Trades & Contracts: **“Anything you leave undecided is re-signed for two seasons if the cap allows.”** “Anything” appears to refer to players/contracts and reads strangely.

Use human, football-specific language. Preferred direction:
- **“Any out-of-contract players you leave undecided will be re-signed for two seasons if the cap allows.”**
- or a shorter equivalent such as **“Undecided out-of-contract players will be re-signed for two seasons if the cap allows.”**

Audit nearby off-season transactional copy for the same problem: refer to **players, contracts, offers, picks and trades** explicitly rather than vague object-language like “anything”, “done”, or generic system wording where a football term would be clearer.

Acceptance: the screen reads naturally to a footy fan, never describes players as generic objects, and preserves concise mobile copy without becoming wordy.
### Free-agent offers, compensation and browsing
The same negotiation standard applies to **external free agents**, not only the user's own expiring players. The current Free agents tab presents `Sign 1 yr / Sign 2 yr / Sign 3 yr` buttons and immediately executes `GameState.sign_free_agent()` at the fixed asking salary. A free agent cannot reject, counter or compare the offer with any market alternative. That makes a major list acquisition feel like buying an item from a shop.

Required direction:
- tapping a free agent opens the same dedicated offer/negotiation flow used for re-signings;
- salary **and** term are proposed by the user;
- the player may accept, reject or counter based on his value, age, requested security, morale/market situation and competing interest;
- no player is guaranteed to join merely because the club has enough cap room;
- show the cap impact before confirmation;
- allow a quick **meet asking price** path where appropriate, but it is still an offer the player can accept rather than an instant transaction;
- keep negotiation legible and bounded: no hidden slot-machine bargaining.

**Free-agency compensation picks:** there is currently no compensation-pick system in the contract/free-agency code or national-draft order path. Add one as part of the mature free-agency model rather than pretending the current release/sign flow already represents AFL free agency. The compensation band should be driven materially by the contract the departing player actually receives — especially salary and term — with age/value/eligibility context as appropriate. Do not expose an opaque real-world formula verbatim; give the player a clear projected compensation consequence before a qualifying player signs elsewhere, and ensure AI clubs are evaluated under the same rules. Compensation picks must be inserted into the national draft order deterministically and survive save/reload. Delisted/unrestricted pool players who should not attract compensation must be distinguishable from qualifying free agents rather than every released player automatically generating a pick.

### Free-agent list usability
The Free agents list needs lightweight sort controls suitable for phone browsing:
- **OVR**
- **POT**
- **Age**
- optionally the existing composite/value order as the default

Allow reversing the selected sort where useful. Keep the controls compact; do not add a spreadsheet toolbar.

The screen must also **preserve scroll position after an action**. Right now `OffseasonScene._build()` reconstructs the tab after every signing/re-signing and creates a fresh `ScrollContainer`, which sends the user back to the top of a long list. Capture the current tab's vertical scroll before rebuilding and restore it after the UI is rebuilt (clamped if the list shrank). The same principle should apply to other repeated off-season actions that rebuild the current list.

Additional acceptance:
- signing a free agent never happens from a single immediate term tap;
- free agents can reject/counter offers and salary is genuinely negotiable;
- qualifying departures can generate correctly ordered compensation picks based materially on the accepted contract;
- the Free agents tab can be sorted by OVR, POT and Age;
- after signing/rejecting/negotiating with a player midway down the list, the user remains at approximately the same scroll position instead of being thrown back to the top.

### Trade market redesign — picks, asset value and club strategy
The current Trade tab is a prototype rather than a credible AFL trade market. Phone playtesting exposed several linked problems:
- only players can be traded; **draft picks and future picks are absent**;
- each side is arbitrarily capped at **two players**;
- tapping any player rebuilds the screen and jumps the user back to the top, making package construction unpleasant;
- the AI can accept implausible consolidation trades. A concrete example: Adelaide accepted **Jordan Sweet + Ryan Lester for Arki Butler (72 OVR / 92 POT)** even though Sweet was a worse ruck than Adelaide's existing option and Lester was an old defender near the end of his career. A rebuilding/neutral real club should not surrender an elite young asset merely because two lesser player values add up;
- the current need bonus only counts how many players of a role remain (`RUCK < 3`, etc.). It does **not** ask whether the incoming ruck is actually better than the club's existing rucks, so a worse player can receive a positional-need premium.

#### Tradable assets
Support AFL-style packages containing:
- players;
- the club's **current-year National Draft selections**;
- tradable **future National Draft selections**;
- combinations of any of the above on either side.

Remove the hard-coded `pick up to 2` asset limit. Do not replace it with another arbitrary two-item cap; allow realistic multi-asset packages while keeping the phone UI manageable.

Every tradable asset must have a **numerical trade value** used consistently by the trade engine and inspectable enough that the player can understand why a deal is close or far apart. This is a decision aid, not salary=value:
- player trade value should include current football ability, age/career runway, POT/upside, recent/previous-season form and production, injury/availability and durability context, role scarcity/list fit, contract salary **and remaining term**, and relevant honours only insofar as they represent football value;
- salary can raise or lower trade attractiveness depending on whether the contract is good or burdensome; it must never be the player's whole value;
- draft-pick value should be based on pick/round and expected draft position, with future picks valued from the originating club's projected range with uncertainty rather than pretending a future first is already an exact number;
- a package of two mediocre/old assets must not automatically equal one elite young cornerstone simply because raw values add. Apply a credible **consolidation/star premium** or equivalent nonlinear rule so the side giving up the best asset needs a reason to do so.

Do not expose a giant spreadsheet. A compact `Trade value` number per selected asset/package is acceptable because the user has explicitly requested numerical asset values, but keep the primary interaction football-readable.

#### Draft-pick ownership and AFL future-pick rules
Implement actual pick ownership as persistent career state: year + round/selection identity + originating club + current owner. Traded picks must flow into the correct National Draft order and remain owned after save/reload.

Research and model the current AFL men's future-pick framework rather than inventing a generic sports rule. **As of the 2025 rule change, clubs may trade selections from the current National Draft and the following two National Drafts.** The official AFL framework also retains protections including the rolling requirement to use at least **two first-round selections in four years**; trading first-round selections requires board approval; and the furthest future year has additional first-vs-second/third-round holding restrictions. Re-verify the current official AFL rules when implementing in case they change, then encode the football rule itself rather than hard-coding a one-season-only approximation. Board approval can be treated as an eligibility rule rather than pointless confirmation busywork.

The current career begins in 2027, so in a 2027 trade period the normal asset horizon should be the 2027, 2028 and 2029 National Drafts if the contemporary rule is unchanged.

#### Club list-management phase / strategy
AI trade value must depend on what the club is trying to do, using only its own public/roster information — never hidden user intent.

Give each club a simple, recalculated list-management phase such as:
- **Rebuilding:** materially values high/current and future draft picks plus elite young/high-POT players; is reluctant to trade premium youth for established older stars; may move veterans for picks/youth.
- **Building/rising:** values a mixture of young core and targeted established needs.
- **In the premiership window / contending:** places less marginal value on future picks and is more willing to trade good picks/youth depth for established players who improve the best 22 now.

Derive this from evidence such as recent ladder/expectation, list quality, age profile, elite-young core and competitive trajectory. Do not assign permanent hand-authored personalities. Recalculate as careers evolve.

A club's position need must be **quality-aware**, not only headcount-aware. If a club already owns a better ruck, receiving an inferior ruck should not get a generic need premium just because it has fewer than three players tagged RUCK.

#### Trade fairness / long-save exploit audit
Treat the Sweet + Lester → Arki Butler acceptance as a concrete regression case. Audit repeated attempts to acquire elite young players/high picks using bundles of older/middling players. The long-save game must resist the familiar management-sim exploit where the human consolidates junk into stars every off-season and becomes unbeatable after a few years.

Acceptance:
- the Butler example is rejected absent substantial additional premium value;
- elite young/high-POT players and premium picks are genuinely expensive, especially to rebuilding clubs;
- contenders can rationally pay picks for established stars;
- rebuilders can rationally sell veterans for picks/youth;
- a worse player at an already-strong position does not receive a fake need premium;
- trade difficulty may change how hard a fair deal is to close, but cannot make obviously irrational deals acceptable;
- repeated long-save AI-vs-user trade probes do not let the user turn low-value bundles into a superteam.

#### Trade UI / navigation
Rebuild the trade interaction around **selected packages**, not two enormous full-list dumps:
- compact selected-assets summary for `You give / You get`;
- browse/add players and picks with useful sort/filter controls;
- clear package value and concise acceptance feedback;
- confirmation before committing a completed trade;
- preserve the current club, package selection **and vertical scroll position** whenever the UI rebuilds after adding/removing an asset. The current `_pick_grid()` calls `_build()` on every tap, which recreates the ScrollContainer and repeatedly throws the user back to the top.

The same scroll-preservation rule now applies across Contracts, Free agents and Trade.


---


## ARD-M6-006 — Off-season wrap and new-season launch
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

### Trigger
Completing the National Draft currently calls `finish_intake_draft()` → `_start_next_season()` immediately. The game therefore jumps straight from the final draft pick into Round 1 of the new season with no transition, despite a large amount of list-management state having just changed.

### Intent
Give the off-season a proper conclusion and the new season a deliberate beginning.

After the National Draft is completed — and **before** the player is dropped into the normal Round 1 hub — show a concise **Off-season wrap / New season briefing**.

### Ins / Outs summary
Summarise what actually changed at the user's club across the whole off-season, not only the draft:
- **Ins:** traded-in players, free-agent signings, National Draft selections and any other genuine list additions;
- **Outs:** trades out, delistings/releases, free-agent departures, retirements and other permanent list exits;
- show draft pick number next to drafted players where useful;
- include notable staff changes in a separate coaching line/block when they occurred;
- if nothing happened in one category, omit it rather than showing empty furniture.

Reuse persistent transactional state rather than reconstructing it from guesses. `offseason_log` already captures some releases/signings/trades, draft history carries selections, retirement/intake summary contains retirements, and coach records/news capture coaching movement. Extend the smallest durable season-transition ledger needed so the wrap survives save/reload.

### Board expectation reveal
The same transition should reveal the board's **upcoming-season expectation** after the new list has been assembled and the expectation model has run.

Show:
- the actual goal in plain football language;
- a short reason for it, grounded in the expectation-fairness model (e.g. list quality, previous finish/trajectory, rebuild/contending state);
- current job-security state only if materially relevant.

This is the moment the player should learn “the board expects finals/top four/seven wins”, not by stumbling across it later in Coaching.

Do not turn this into another dashboard. The purpose is:
**What changed? What does the club expect now? Then begin the season.**

### Presentation
Give the transition enough ceremony to feel like the end of one management phase and the start of another, while staying phone-friendly:
1. Off-season complete.
2. Ins / Outs.
3. Any notable coaching movement at your club.
4. Board expectation for the new season.
5. **Begin season**.

A one-screen scroll or short staged flow is fine. No forced slideshow.

### Acceptance
- finishing the draft never silently drops the player into Round 1;
- every genuine player addition/removal from that off-season can be accounted for in the wrap;
- draft picks are correctly identified;
- notable staff changes are surfaced if they occurred;
- the board's new-season goal and a concise reason are shown before Round 1 begins;
- save/reload at the transition cannot duplicate transactions or skip the briefing;
- long saves retain a clear year-to-year sense of roster change without number vomit.

## ARD-M6-005 — Options / settings
**Status:** `DONE`  
**Merged:** PR #86 as `ebc570d`; one Settings sheet now serves the menu and career hub, with relevant current options and destructive-action confirmation.  
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

## ARD-M6-006 — League-relative List Profile
**Status:** `DONE (2026-09-30), awaiting director review`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

Add a compact **List profile** section to the Coaching menu so the player can understand what kind of list they have built before choosing a game plan or deciding what to improve through training, trades or the draft.

Show five plain-English dimensions:
- **Contest**
- **Control**
- **Running power**
- **Pressure**
- **Aerial power**

### Core rule — league-relative or it is meaningless
Every label must be relative to the **current league**, not an absolute attribute threshold. As lists evolve over a long save, the comparison must evolve with them.

Use short qualitative labels such as **Elite / Strong / Average / Weak** (and an equivalent bottom-end label only if needed). Do not expose the underlying score by default.

### Player-facing purpose
The profile should answer: **“What is my list actually good at, and where is it weak?”**

It should help the player:
- make an informed game-plan choice without the game recommending the answer;
- identify weaknesses worth targeting in the trade period or draft;
- decide what kinds of players/attributes to develop through training;
- see a list identity emerge over time rather than simply chasing higher OVR.

### Guardrails
- No raw 0–100 team scores or number-vomit presentation.
- No radar chart unless a later UI test proves it is clearer than the words.
- Do **not** display “recommended plan” or otherwise solve the tactical choice for the player.
- Keep **Aerial power** distinct from **Control**: Control is retaining/using possession; Aerial power is winning the ball in the air.
- Derive each dimension from football-relevant player qualities already present in the simulation wherever possible; do not invent a parallel rating system.
- Before implementation, inspect `PlanFit.gd`, synergies and other existing team-strength calculations and reuse/extend them rather than creating contradictory definitions.
- The Coaching screen remains the primary home for this information.

### Built (2026-09-30)
- **Rules:** `scripts/sim/ListProfile.gd`.
  - Each strength ranks your match-day side, as you have picked it, against every club's side this week (`GameState.league_grounds`).
  - The words fall by share of the league: roughly the top 17% is Elite, then Strong to 44%, Average to 72%, and Weak below that. In an 18-club league that is 3 / 5 / 5 / 5.
  - A rank moves whenever any list in the league changes. No score is shown.
- **Definitions** (the engine's own, not a parallel system):
  - Contest, Running power and Pressure are `PlanFit.score` for Win contest, Attacking and Defensive.
  - Control is disposal (what beats a press in MatchSim) with discipline (what avoids clangers), across the side minus the ruck.
  - Aerial power is the side's six best marks.
- **Screen:** Coaching opens on "List profile", ahead of "How we play".
  - Five rows show a strength and a word.
  - Tapping a row says what that strength is and who leads it in your side.
  - No numbers, no radar, no recommended plan.
- **2027 league:** every word is used, and every club has a distinct mix. For example, Adelaide is elite everywhere except Running power, while Collingwood is Weak in Contest and Running power.
- **Tests:**
  - `test_roles` `_test_list_profile`:
    - the words spread across the league;
    - better ball-winners make Contest Elite;
    - the same list reads Weak in the air once every other club's marks improve;
    - Aerial power and Control move independently;
    - three strengths equal the plans' own scores.
  - `run_career_ui_tests`: five thumb-sized rows, no digits or advice, and a tap reveals the detail.

### Acceptance
- The five labels change meaningfully when the underlying list changes.
- The same raw list can move between labels as the league around it improves or declines.
- A player can use the profile to reason about tactics and recruiting priorities without being told which move is optimal.
- The display remains compact and readable on a narrow Android portrait screen.

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
**Status:** `PARTIAL`  
**Merged foundation:** PR #100 as `12aae17`; career-game milestones (50/100/150 etc.) and club-tenure context are live, while first-goal/career-high style milestones remain future work.  
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

### End-of-season awards presentation — fanfare, not summary cards
The current Season Review collapses Brownlow, Coleman, Rising Star, club best & fairest and All-Australian into a single static awards panel. That is too flat for awards that should feel like major season payoffs. Keep the **season story/campaign recap separate** from awards night.

- **Brownlow Medal:** give it a bespoke round-by-round count. Reveal votes round by round, update the leaderboard as the count progresses, build tension late, then clearly crown the winner. The underlying Brownlow already accrues 3-2-1 votes from home-and-away matches in `Awards.tally_match()`; presentation should reveal those existing votes rather than re-roll or invent anything. Allow sensible pacing/skip controls so repeat long careers do not become tedious, but the default first-time experience should have ceremony and escalation rather than immediately exposing the final totals.
- **Club best & fairest:** give the user's club its own bespoke count/ceremony, again progressing through the season rather than dumping the final `bf` totals. The current model already accrues 5-4-3-2-1 within each side every match, finals included. Reveal those existing votes progressively, with the club winner feeling like a genuine end-of-year moment. This is a club event, distinct from the Brownlow night.
- **All-Australian:** give the final team a bespoke unveiling at season's end instead of a compact list. Reveal the side in stages/lines (e.g. defence, midfield/ruck, forwards, interchange) with enough pause and presentation that selections feel prestigious. Do not expose the internal selection formula or turn it into a number dump.
- **Coaches' votes:** implement as an in-season accumulating recognition system, visible through appropriate leader/record surfaces as the year progresses. **Do not** give coaches' votes another bespoke end-of-season countdown; by season's end the winner can be acknowledged briefly because the interest came from watching the race accrue during the season.
- **Coleman Medal:** the race should also accumulate visibly throughout the season, just like coaches' votes and the existing ladder Coleman panel. It does **not** need its own bespoke countdown ceremony at season's end because the user has already watched the race develop week by week. Give the final Coleman winner a short, prestigious presentation/mention during the Brownlow ceremony.
- **Rising Star:** no separate ceremony required. Award/present the Rising Star during the Brownlow ceremony as part of the broader league awards night, with enough prominence to feel meaningful but without interrupting the Brownlow count's pacing.
- Do not force every honour into its own ceremony: the distinct marquee experiences are the Brownlow count, the user's club B&F count, and the All-Australian unveiling; Coleman and Rising Star live naturally within the Brownlow awards-night presentation.

Presentation guardrails:
- fanfare should come from pacing, reveal, hierarchy and football context, not particle spam or UI clutter;
- no fake suspense: reveal deterministic stored results only;
- skippable/acceleratable for experienced players while preserving a satisfying default flow;
- save/reload must not double-award, re-roll votes, or change winners;
- each ceremony should work cleanly on a phone and should not require dense tables.

Acceptance: Brownlow and the user's B&F can be watched as progressive counts with evolving leaders and a final winner reveal; All-Australian is unveiled progressively by line/position; coaches' votes accrue through the actual season and need no separate countdown; the ordinary Season Review no longer substitutes a single static card for these major moments.

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
**Status:** `PROTOTYPE BUILT — awaiting phone playtest`  
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

### Prototype (2026-09-30)
Started on the director's direction, ahead of the §1.11 gate. The director asked for a *cinematic* scene, not an enhanced moment card.
- **Where:** the late-game centre-bounce call (MatchSim's `bounce` moment: Q4, a margin within two goals, at a centre bounce). No other moment changed.
- **The scene (`scripts/ui/match/StoppageVignette.gd`, about 4 s, a tap skips to the freeze):**
  - the match cuts in with letterbox bars;
  - a low camera behind your end pushes in on the centre square;
  - the real rucks and centre-square midfielders, in club colours, jog into their set-up, and anyone running on empty arrives last;
  - the umpire walks in and bounces the ball, and the rucks go up;
  - it freezes at the top of the contest, with a flash and the key names.
- **The call:** it slides up over the frozen frame with one or two commentary lines in words and no numbers (how the stoppages have gone, who is out on their feet), then MatchSim's own options. Choosing fades the scene back into the match.
- **Authority:** it is presentation only. It reads MatchSim's state (players on the ground, energy, clearances and hit-outs) and MatchSim resolves the call. There is no second simulation.
- **Tests:** `run_matchday_tests.gd` `_bounce_close_up` covers the following:
  - MatchSim raises the call;
  - only the stoppage players from this match appear;
  - it plays in and then freezes, and the options stay disabled until the freeze;
  - the commentary comes from the match, with no stats;
  - MatchSim takes the call;
  - the scene cuts back to the match.
- **Review:** `tools/visual/capture_vignette.gd` renders a contact sheet of the beats on a phone.
- **Not built:** templates, other families, or a framework. These wait for the playtest below.

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
- Open-play scoring is structurally possible in MatchSim, and PR #50 made open-play shots remain live in presentation; the broader scoring-model variety under M3-001 is still partial.
- In-match Momentum is now a real capped/fading MatchSim mechanic, and the meter reads engine state directly (PR #102).
- Free kicks exist in simplified form.
- Concussion now enforces a minimum two-match absence with AI parity and save persistence (PR #51).
- Wildcard finals/top-10 finals structure already exists; do not add another wildcard-finals feature.
- Matchday squad has historically been 18 + 4 interchange and needs migration to 18 + 5 unless already changed.
- "Play through" now favours possession-chain/transition involvement without generic shooter bias (PR #48).
- Player/team metres gained are accumulated from actual forward ball movement (PR #55).
- Effective disposals and Disposal Efficiency are tracked from actual disposal outcomes (PR #55).
- OOB/out-on-full/throw-in/last-disposal have not historically existed as a complete event path.
- Forward-50 spoils are now explicit loose-ball events with player/team credits; general-play spoils remain incomplete (PR #83).
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


## ARD-M8-009 — Plausible fictional player names
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `SAFE`

### Trigger
The first generated National Draft immediately breaks immersion with names such as **Fia Drift, Sora Jumble, Gavi Cobble, Hani Orbit, Gilo Orbit and Ivo Orbit**. Several obviously invented surnames repeat within a tiny class.

### Current implementation reality
This is not random bad luck. `GameDB.gd` currently uses a deliberately fantastical alias pool of only **49 first names and 50 surnames**, including `Orbit`, `Jumble`, `Fizz`, `Puddle`, `Gossamer`, `Cobble`, etc. Every first/last combination is shuffled deterministically, so full-name collisions are avoided initially, but the very small surname pool makes repeated surnames unavoidable and the vocabulary itself does not resemble Australian footballers. Generated future prospects have no real-name fallback, so this problem becomes more visible with every long save.

### Direction
Replace the fantasy-word alias system with a large, plausible contemporary Australian player-name generator.

Requirements:
- names should read like believable human names in an Australian national competition;
- use a broad contemporary Australian mix of first names and surnames rather than a narrow Anglo-only list or fantasy syllables;
- greatly expand the pools so a 50-player draft class does not visibly recycle surnames;
- avoid repeated full names across an active career;
- avoid more than an occasional repeated surname within one draft class unless it is intentionally linked to a future family-lineage mechanic;
- generation remains deterministic for a career/seed and stable through save/reload;
- real current players can still use the player's chosen real-name/fictive-name setting, but **generated future players must always receive plausible names**;
- do not use numbered placeholders or artificial sci-fi/fantasy vocabulary;
- future father-son/family systems may intentionally reuse a surname and should be able to bypass the ordinary duplicate-avoidance rule.

### Validation
Generate at least 20 full draft classes and inspect:
- surname repetition per class;
- full-name collisions across decades;
- obviously non-human/novelty combinations;
- name-length/wrapping on 360–390 px screens.

Acceptance: a draft list should look like a plausible list of Australian football prospects at a glance; repeated surnames are uncommon enough to feel notable rather than procedural; long saves do not devolve into obvious recycled-name patterns.

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

## Design idea — Unicorn as a synergy wildcard

**Status: IDEA / hold for synergy-system design review.**

Explore making the **Unicorn** player archetype a wildcard for list synergies: a Unicorn could satisfy a required player/archetype slot for any synergy, reflecting an unusually versatile football skill set and making that player a flexible piece in the club's "party" composition.

Guardrail: this should **not** mean a Unicorn automatically strengthens every synergy at once or becomes a universal best-in-slot player. The intended value is composition flexibility — potentially satisfying one missing synergy requirement — while the player's actual position, attributes and football performance still matter.

This is deliberately not implementation-ready. Revisit it alongside the broader synergy-system assessment arising from the new game-first / party-CRPG design philosophy.

---

## Design idea — “Spin the MRO wheel”

**Status: VERY MAYBE / idea only.**

Explore a tongue-in-cheek MRO presentation called **“Spin the MRO wheel”**, playing on the familiar footy-fan joke that Match Review Officer suspension outcomes can feel unpredictable or inconsistent.

This is primarily flavour/presentation, not a request to make the underlying MRO system genuinely arbitrary. If ever used, the actual disciplinary logic should remain coherent enough for gameplay while the presentation can wink at the perceived randomness familiar to football supporters.

Hold this idea for the eventual MRO/tribunal design work. Do not implement it merely because it is recorded here.

---

# 10. Roadmap Maintenance Log

- **2026-09-30:** Clarified AI parity as a global design rule: AI must never be psychic. It may infer and react to observable/scouted information, but must not read hidden player choices or concealed simulation state to counter the player.
- **2026-09-30:** Audit repair sprint (A–G) merged in #104–#111; statuses and measurements are in the audit appendix.

- **2026-09-29:** Merged PR #102 (real Momentum) and PR #103 (System Reality Audit). ARD-M4-010 and §1.12 are now DONE. The Current Execution Queue now starts with a user-review hold on the audit repair pass, led by the live-match plan reset and other measured no-op/questionable systems.

- **2026-09-29:** Added an authoritative Current Execution Queue so Claude does not infer priority from milestone numbering alone. The queue now finishes #102, runs the P0 System Reality Audit, closes the phone playtest gate, then moves through core match agency, football authenticity, team management, management depth, and finally flavour/polish. Added §1.12 as the canonical System Reality Audit gate after the display-only Momentum discovery.

- **2026-09-29:** Status-sync pass after merged work was allowed to drift: recorded M1-005, M1-009, M1-011, M3-010, M4-002, M4-008, M4-009, M6-002, M6-003 and M6-005 as completed; M3-003 and M7-003 as partial; and M4-010 as actively in progress on PR #102. Refreshed stale current-state notes so agents do not rebuild already-finished systems.

- **2026-09-29:** Added a very-maybe MRO flavour idea: “Spin the MRO wheel”, a tongue-in-cheek nod to footy-fan perceptions of inconsistent suspension outcomes. Presentation joke only; do not make the underlying system arbitrary.

- **2026-09-29:** Recorded a design idea for Unicorn players to act as flexible synergy wildcards. Hold for the broader synergy-system design review; avoid making Unicorn a universal automatic buff.

- **2026-09-29:** Tightened ChatGPT workflow ownership for concurrent PRs: inspect the whole open-PR set and establish merge order before merging, then re-check/sync remaining branches immediately after each merge so stale CI and preventable merge conflicts do not accumulate.

- **2026-09-29:** Extended the party-RPG lens to matches: each match is a quest/encounter testing the player's party, and emergent storytelling is a core design goal. Matches should generate legible arcs, turning points and memorable individual moments that the player can recount afterward without scripted drama.

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
