# 0. How to Use This Roadmap

## 0.1 Authority

When the user says **"add this to the roadmap"**, update this file.

Before adding a new item:

1. Search this file for the concept and its synonyms.
2. Check the **Duplicate / Merge Map** at the end.
3. Extend the existing task if it is the same system.
4. Create a new task only if it has a genuinely different player-facing purpose or implementation boundary.
5. Do not create duplicate tasks because the wording changed.

### Visual authority — director clarification, 2026-10-06

The art agent has higher authority than ChatGPT on visual direction. All final decisions go through the director. For the explicitly included STYLE-01–08 work (§9.5), Claude may prepare the scoped prototypes and reviewable implementation; final visual treatment and completion require director approval. This newer visual gate takes precedence over ordinary standing merge authority for unapproved appearance changes.

### Optional Art Agent resource shelf — director clarification, 2026-10-06

**Reference material only — these are not requested changes.** The director asked that the following free resources be available to the Art Agent if helpful at any point. This shelf creates no implementation task, priority, dependency, acceptance requirement or obligation to adopt an asset, add sound, change the renderer, or build tooling. Standing development authority must not be interpreted as an instruction to action this list. The Art Agent may consult it when useful within already authorised work; existing visual authority and director approval still apply.

Potential resources, assessed against the current Godot / MPFB / Blender / pre-rendered figure pipeline:

| Resource | Possible use, if helpful | Integration notes |
|---|---|---|
| [MakeHuman system assets](https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html) | Suits/shoes for coaches, press attendees and awards guests | Manifest-listed system clothing is CC0 and close to the existing MPFB workflow. Check whether already used in the external art project; fit current bodies/poses and regenerate aligned render passes and masks where needed. |
| [Poly Haven Cotton Jersey](https://polyhaven.com/a/cotton_jersey) | Subtle offline cloth relief | CC0. Cotton ribs are not automatically an AFL technical fabric match. Use restrained normal/roughness detail in Blender; do not feed ordinary PBR maps directly into packed figure shader inputs. |
| [ambientCG Grass003](https://ambientcg.com/view?id=Grass003) | Low-contrast turf variation | CC0. Preserve drawn oval markings/readability; compare repetition, scale and shimmer at phone size. No default requirement to add a pitch texture. |
| [Poly Haven Wood Table 001](https://polyhaven.com/a/wood_table_001), [Kenney Furniture Kit](https://kenney.nl/assets/furniture-kit), [Plastic Monobloc Chair 01](https://polyhaven.com/a/plastic_monobloc_chair_01) | Selected desk/lectern finishes or background furniture | CC0. Match current lighting/palette through offline baking. Plastic chairs suit suburban club settings better than formal awards rooms; existing props need not be replaced. |
| [Studio Small 09](https://polyhaven.com/a/studio_small_09), [Overcast Soil](https://polyhaven.com/a/overcast_soil) | Offline lighting comparisons | CC0 HDRIs. Optional references, not an instruction to ship HDRIs or replace the established light direction. |
| [Kenney UI Audio](https://kenney.nl/assets/ui-audio), [Interface Sounds](https://kenney.nl/assets/interface-sounds), [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Selective quiet interaction/impact sounds | CC0. Audition a small coherent selection, respect mute/volume controls and avoid arcade-like excess. |
| [Small applause — Sclolex](https://freesound.org/people/Sclolex/sounds/261617/), [Camera Shutter — roachpowder](https://freesound.org/s/170229/) | Awards-room applause or press-flash accents | Individual recordings labelled CC0. Not auditioned; trim, convert and balance before considering use. Existing crowd audio is already implemented; its looping bed expects WAV. |
| [Kenney Input Prompts](https://kenney.nl/assets/input-prompts) | Relevant touch/keyboard instruction glyphs | CC0. Only if stylistically useful; this does not request or imply additional control support. |

**Three.js assessment:** [Three.js](https://threejs.org/manual/pages/fundamentals.html) is an MIT-licensed JavaScript browser 3D library. A separate shareable model viewer or promotional showcase could be useful if a future need arises; neither is requested. Do not treat it as a Godot shader pack or a recommended runtime migration. The current game already has a native renderer, and an embedded browser layer or replacement frontend would introduce substantial work with no demonstrated texture, anti-aliasing, FPS, loading or battery benefit.

**Research boundaries:** These are candidates, not proven seamless integrations. Source/licence pages were checked; packages were not imported, audio was not auditioned, and native-device performance was not benchmarked. Retain the downloaded asset's licence/provenance, export only useful subsets and preserve the established art style and packed figure texture contract. Generic sports/character packs are weaker fits; soccer balls are not AFL balls. Quaternius's older pack-level CC0 labels conflict with its current [QAL licence page](https://quaternius.com/license.html), so resolve the actual pack terms before considering source assets in this public repository.

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
- **Roadmap** — `docs/ROADMAP.md` is the canonical execution/source-of-truth document for this project. Design philosophy is owned by the bible (below).
- **Bible / design bible** — `docs/DESIGN_BIBLE.md`, the director's statement of what the game is (2026-10-09). It outranks this file on design and is changed only with the director's explicit consent for each update.
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

**Read the [design bible](DESIGN_BIBLE.md) first (director, 2026-10-09).** It states the vision, the core pillar (player agency), the principles and the feature test, and it outranks this section. The lenses below remain as supporting detail where they agree with it. The bible's feature test (a feature must be justifiable by its intent) is the one that decides whether a feature belongs; the two "useful test" questions below are aids to it.

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

## 0.4a Effort tags and parallel work

Effort sizes an item for the agent who picks it up. It is separate from Priority (how much it matters) and Autonomy (how much care it needs), and it is a first-pass estimate: when you learn an item is bigger or smaller than its tag, move it and say why in your PR.

- `LOW` — one focused change to one system or screen, with the player-facing decision already settled here and targeted tests that can prove it. Hours, one small PR. Verifying and closing work that is already on `main` is `LOW`.
- `MEDIUM` — a real feature or fix across a couple of systems (sim, UI, tests), a small save addition, or a measured seeded comparison. One or two PRs; may need a director phone check.
- `HIGH` — cross-system or content-heavy work, balance-gated tuning with open design questions, a data or research build, or anything that takes several PRs or director decisions along the way.

The director runs three agents at once, one per tier. The Low agent also keeps this file and the other docs current (progress, stale text, tags), tracks CI on every open branch and PR, and keeps the repo's branches tidy. Tags live only in the lists below. An item keeps its own section where it is, and a new item gets its tag, here, in the PR that adds it. Last sized 2026-10-06; completed-foundation references reconciled 2026-10-07.

**Working alongside the other agents**
- Before taking an item, run `git worktree list` and `gh pr list`. A sibling worktree or an open PR on the same files means someone has it.
- Hot files: `scripts/sim/MatchSim.gd`, `scripts/state/GameState.gd`, `scripts/ui/UiKit.gd`, `scripts/ui/match/MatchNotes.gd`, `tests/expected_checks.txt` and this file. Keep hunks small and rebase on `main` just before you push.
- `tests/expected_checks.txt` has one floor per suite, and two PRs that raise the same suite's floor collide. Raise only the lines for suites you changed. When resolving a collision, the floor is the base plus both PRs' increments, checked against the suite's actual count on the merged result. Do not take the higher of the two, and never lower a floor to get green CI. Put the base and your increment in the merge note.
- In this file, edit only your own item. The maintenance log gets a new line at the top from nearly every PR, so a conflict there is normal: keep both sides.
- Godot is the bottleneck when several agents run it at once. Locally, run only the 1–3 suites your change touches (`tools/run_tests.sh <suites>`); CI runs the rest, as five parallel shards in about eight minutes. Never run the full suite locally. Only one long local Godot run per agent at a time, with its own user data (`APPDATA=<scratch dir>` on Windows), because every checkout shares one `user://`.
- Long audits (more than about five minutes) go to the audit workflow, not your machine: `gh workflow run audit.yml --ref <branch> -f impl=<name> -f env="KEY=VAL"`, then `gh run download <run-id> -n audit-<name>`.
- A new suite needs a line in `tools/ci_shards.txt` as well as a floor in `tests/expected_checks.txt`; CI fails if a suite is in no shard.
- Do not push to a branch while its CI runs unless you must: a push cancels the run and restarts about eight minutes of work. Ask the Low agent for a sync instead. The Low agent owns merges and cannot push to your branch, so sync your own branch when asked.

**Team workflow (director-approved research findings W1–W7, 2026-10-06)**
- **Fresh sessions at task boundaries (W1).** When a substantial task is done (PR open, evidence in its body), or you switch to an unrelated task, write a short handoff and start a fresh session from it. Don't drag the whole transcript along.
  - **Where:** the handoff goes in `../agent-handoffs/<role>.md`, outside the repo.
  - **What it says:** the task; branch and commit; files you own; unfinished changes; acceptance evidence and where it lives; open decisions; dependencies; running jobs (local PIDs or Actions run ids).
  - **Starting fresh:** begin from the handoff, CLAUDE.md, this section and the roadmap section you need, read by offset rather than whole.
  - **Context size:** aim for roughly 50–100k for routine work, and look into growth past 150k. These are working targets, not billing limits; a hard task may need more.
  - **Never** restart a session with undocumented in-flight work. **Don't** restart mid-task, either.
- **Direct, actionable messages (W2).** Send a CI failure or a conflict straight to the branch's owner. Relay someone else's news only if you add interpretation, a dependency or a correction. Don't send "received" or "noted" acknowledgements, queue echoes or repeated inventories. Every message names its PR or task and commit. The lead gets decisions, blockers, substantive findings and changes of priority.
- **Say which state you are in (W3).** The states are: working, running a check, awaiting director review, blocked, available. Waiting is a valid state when what remains depends on a result or an approval; don't make work to look busy.
  - **Reading CI:** sharded CI posts its aggregate `test` check last, so "no `test` result yet" while shards run is not "CI never started". Read the shard jobs.
- **Event-driven monitoring (W4).** Rely on the app's CI events, background-task completion and the existing PR watcher. Don't poll in model turns. A CI report gives:
  - branch, commit and run id;
  - the failed suite or check;
  - whether it also fails on `main`;
  - the next owner.
- **Own your processes (W6).** Stop only processes you started: TaskStop your background task, or kill by the PID you recorded. Never kill Godot (or anything else) by image name; other agents run it on the same machine. Record the PID or Actions run id of every long run.
- **Semantic review for lifecycle changes (W7).** A change that touches the save schema, season rollover or off-season, shared simulation rules, recruitment, or player identity gets a short review by another agent before merge.
  - **Review packet:** the PR body names the lifecycle transitions it affects (club move, rollover, save and reload, retirement, injury) and the invariants that must hold.
  - **Reviewer's job:** check the contract and its consequences, not just the explanation. One reviewer, not three.
  - **Why:** a textually clean merge can still be wrong together. For example, a project survived a club move until review caught it.

**Proof practices (director-approved #291 adopt items, 2026-10-06)**
- **Taps, not handler calls, for touch flows (C1/C3).** A UI test that stands for a player's tap uses `tests/tap.gd`. The touch goes in at the button's place on screen and through the GUI, so an overlay, sheet or off-screen button fails the test. `emit_signal("pressed")` still suits checks of the handler's logic alone.
- **Prove the intended art ran (C2/C11).** A check on art or motion asserts the asset the game actually used, not just that a picture appeared.
  - **Example:** the `assets` suite checks every figure-sheet frame against `VignetteFigures.gd`, and that each vignette plays its moves through (`StoppageVignette.figure_frame` logs a frame asked for past the end of a move).
  - **Self-test:** a new check is shown failing on a known-broken input (a blank frame, a misplaced mask, a covered button, a clipped track) before it is trusted.
- **Audio evidence (C12).** The `assets` suite checks what a machine can check:
  - every track loads and is in the playlist;
  - no clipping, no gap at the start, the tracks at one level;
  - pause for a match, resume, next track, Mute.
  How the music sounds (fidelity, repetition, mood) is the director's to judge by ear. Never report "sounds fine" from a measurement.
- **Change the evidence after repeated failure (C7).** After two or three similar fixes have failed, stop patching. Gather different evidence first: a minimal reproduction, the last good commit, the actual runtime state or the event path. This is a trigger to change method, not a time limit.
- **Never the clock in a test (C15).** A test that starts a season or draft sets `GameState.replay_seed` (or uses a seeded `MatchSim`), so a run can't pass or fail on which opponent it drew. Older suites still on the clock are fixed when touched. A flaky failure is a seed to pin, not a rerun.
- **Say what wasn't exercised.** A PR's evidence names what it didn't cover (device touch, real-time performance, listening) instead of leaving it implied.

**`LOW`**
- §9.5 STYLE-03 colour pairings and STYLE-08 light maintenance; light maintenance follows the approved dark slice. STYLE-01's alignment repair (#277) and STYLE-07's shared desktop-scaling repair (#371) are DONE; any fresh recurrence needs current evidence. Art-agent direction and final director appearance approval apply.

- §9.3 FL-001 football voice and incidental humour.
- Verifying and closing work that is already on `main` (the Low agent does this as it finds it). The §9.1 Training scrollbar is done and waits only on a phone check.

**`MEDIUM`**
- Director-requested free texture/artefact/AA work (ARD-M8-007, LS-02/03/05, A4) and §1.11 frame-rate/loading/battery optimisation are `P1` high priority. Baseline and targeted fixes first; coordinate active art/performance ownership and existing review/device gates.
- ARD-M8-007 free shader polish (`P1`, high priority): existing-pass character treatment, ground shading and small contact-shadow improvements; optional local effects/outlines only after measured comparison. Reuse LS/STYLE ownership and phone gates.
- §9.5 STYLE-01 bespoke controls, STYLE-02 typography, STYLE-04 oval/match composition, STYLE-05 headers/number marks and STYLE-06 integration with existing 2.5D scenes. Coordinate hot files and existing M8-007 ownership; no competing redesign or new-scene permission.

- §9.3 FL-002/004/005/006/008 foundations are DONE (#400/#405/#409/#392/#395/#406). Do not schedule those shipped slices as fresh MEDIUM work. Their explicit newer follow-ups (e.g. favourite-club bio facts under FL-005) and outstanding acceptance/device checks remain open under the same owners.
- §9.4 RPG-001 connected backing story (start here: verify the Backing flow first), RPG-005 selective role observations, RPG-006 coaching identity through existing choices (audit before changing anything) and RPG-007 build-aware recruiting discussions.
- Match audits that need a measured seeded comparison, and a new mechanic only if the evidence demands one: ARD-M3-007 (free-kick rate), M3-008 (50-metre penalties), M3-011 (MRO and suspensions), M4-003 (tagging cost), M4-006 (game-state AI), M4-011 (Team Form), M5-006 (omitted-player development), and the §1.11 audits of run-of-goals calls, AI plan adaptation, sim-round blowouts, List Profile v results, and How-we-play maturity and materiality. Done since sizing: the autosim v played injury parity audit (#235, parity holds), the Coleman plausibility audit (#237) and the key forward v key defender audit (#240: defenders contain; the verdict-copy fix is #246).
- Features across sim, UI and tests: ARD-M2-009 (goal accuracy by shot context), M5-005 (emergency designations), M5-007 (selection continuity), M7-003 (career-high milestones need new tracking), M7-005 (history continuity check), M8-005 (5, 10 and 20-year career QA), the Grand Final climax screen, and from §9.1 the Weekly selection brief, Streamline Ins & Outs, My List → My Selection flow, Full List traits and contract-talk frequency.
- Performance and flow: §1.11 battery drain, the residual far-away receiver, vignette reachability, and quarter-break fact selection. The round-sim and Play match timing audit is done (#236: nothing grows with the season, and the Play match tap is about 45 ms); the background no-presentation sim mode it recommends is `MEDIUM`, to start only once MatchSim is quiet.

**`HIGH`**
- §9.3 FL-003 sourced venue atmosphere and FL-007 rituals/farewells, including necessary new shared-style vignette scenes.
- §9.4 RPG-002 recurring journalists and remembered media, RPG-003 private selection and role conversations (with the starred M5-003 development conversations), RPG-004 hybrid synergies, RPG-008 connected season narrative, RPG-009 restrained living characters and RPG-010 automatic familiarity as team synergy. §9.4 sets the order: Backing first, then one private scene and one media topic, synergy work reconciled before RPG-004 and RPG-010, and one combined balance audit at the end. Dependencies from the lead: RPG-004 and RPG-010 wait for the synergy-specialisation PR to merge; RPG-003's starred M5-003 note waits for the dev-project (learning a position) PR. None of the §9.4 items starts until the director assigns it.
- Scoring and contests: ARD-M3-001 (later variety), M3-002 (forward archetype scoring), M3-003 (spoils across the ground).
- Coaching and tactics: ARD-M4-001 (decision gates; the tired-star Rest/Keep trade-off is done, #233), M4-002 (broader key match-ups), M4-004 (structural choices), M4-005 (role instructions), M4-007 (late-game tempo), and from §9.1 Gameplan choice and Key match-ups as interventions.
- Lists and selection: M5-008 (role-aware form), §1.11 additive retraining/selection-fit follow-ups (M5-001 and M5-003 foundations are DONE), M5-016 (inherited 2026 lists), the §1.11 role-allocation re-audit, and from §9.1 My List → Shape as a selection surface and Academies / NGA.
- Board, league and balance: ARD-M6-003 (fair expectations), M7-004 (captaincy), M7-007 (ground dimensions; weather is implemented under M4-016 apart from its explicit residual scope), and from §9.1 overall difficulty with active-play levers, synergies as specialisations, and the GOAT prospect.
- Content builds: ARD-M7-008 (custom prospect), M7-009 (expansion and Club Forge), M7-010 (Sir Doug Nicholls Round), M7-011 (AFL knowledge layer), M8-003 (match visualisation), M8-006 (release polish), M8-007 (vignette art-style replacement), the §1.11 Season story and long-save visual wishlist, and AFLW (deferred).

**Waiting on the director** — nobody's to pick up: the phone checks on ARD-M5-014, M5-015, M6-006, M6-008, the awards ceremony, training touch and the playtest fixes marked `VERIFY` in §9.1; whether to keep the trade-value discount for unproven potential (§9.1); whether the Key defender plan should be offered to defenders under 191 cm; whether the temporary Sim to finals button (ARD-M1-007) is still wanted; and the trailer (ARD-M8-010), which is hard-gated and only starts on the director's explicit go-ahead.

## 0.4.1 Current execution queue — overrides milestone order

**Reconciled 2026-10-10 against live main at `d355eefa`** (previous passes 2026-10-09 at `fa84f7be` and 2026-10-07 at `7ebb7d5c`; PR states below were read from GitHub). Read each item's latest implementation/remaining-work note before acting on older playtest wording. Requirements and director decisions below remain acceptance criteria; a completed foundation is not a new TODO, and an open PR or a merge into an integration branch is not completion on main.

1. **Single highest priority: the complete Season stats / Stats menu patch (§1.11).** Authorised for 2026-10-07. **Merged to main as #509 on 2026-10-08** (`e3d6715c`); its parts #513 event counters, #511 fixture, #512 ladder and #514 season/player stats had merged into the integration branch on 2026-10-07. Follow-ups on main since: #527 (stats open in the phone layout; don't-argue and evaded-tackle metrics), #528 (box score: worm, quarter-by-quarter scoreboard, tappable goals and players) and #529 (TV mode, momentum meter; Finals bracket prototype). **Built and verified against the acceptance list (lead, 2026-10-09, on main `fa84f7be`); waiting on the director's phone review.** All ten mandatory statistics are recorded from MatchSim events for every match, AI v AI included (`StatBook.KEYS`; `add_match` runs for every result each round). Derived rates come from counts, with an explicit no-rate when the denominator is zero (`StatBook.RATES`: contested-possession %, hitout win % over ruck contests, accuracy %, the set-shot/open-play split, the kick ratio). Player Stats shows all of them, with totals and per game, sorting, and club/position/age/role/trait/games filters. Ladder, Awards (Coleman, coaches' votes, rolling All-Australian marked provisional, Rising Star; Brownlow sealed), Fixture (box score or preview) and the Trophy room (tenure only, three groups) are built. Since `fa84f7be`: #575 (Season stats in the gameday style, PC layouts), #593 (LadderScene retired; the ladder lives in Season stats), #594 (Players as leaderboards, Team stats three views) and #605 (segmented lines, spanner headings; director approved the look) are on main. Still open as written: the Stat guide streamline and the first-visit tutorials, and the native-phone review. The earlier HOLD on merging into main was written before #509 landed; #509 is now on main, and new Stats work still needs an assigned item. Do not mistake #507's completed match-stats layout for the complete Season stats patch.
2. **Remaining P0 correctness/playtest regressions.** Preserve unresolved ball-collection pauses, disposal/turnover clarity, held-ball defects, creator controls/preview, training/development layout and other specific unverified requirements in §1.11. The existing team builder, draft filters/age, Forge paint flow, draft scroll fix, custom-club staffing, guernsey-number repair, centre-ball-up cap and tag eligibility are already on main; validate a reported recurrence or a missing acceptance path before rebuilding them. **Match flow after an intercept or a free (director, 2026-10-10, from the match-shape audit on #607): Step 1, the winner plays on and stoppages come from contests (a free that became a random ball-up 42% of the time was a no-op mechanic, so it sits here as correctness; §1.11 flow, disposal and possession clarity); then Step 2, recalibrate contested ball, spoils and turnovers toward real football under ARD-M3-003 and the §1.10 balance gate. Boss's branches; measured before and after.**
3. **Combine is high priority and integral to postseason → National Draft (ARD-M5-014).** The scouting foundation is merged; the newly required complete navigable statistics menu remains TODO. Coaching hierarchy and opportunity-based retention/succession remain TODO under M6-002. Coordinate existing off-season owners.
4. **Finish current branches within their scope.** #508 coaching descriptions/plan wrap (merged 2026-10-07), #506 kick/held-ball animation (merged 2026-10-08) and #484 set-shot share (merged 2026-10-08) are on main; #368 kit options was closed and rebuilt as #522 (long sleeves and sock hoops, merged 2026-10-08 after the director approved the look). Merged does not close the native-phone check or §1.11 acceptance where those items name one. Also merged since the last pass, 2026-10-08/09: #520 Sir Doug Nicholls Round guernsey audit, #522, #523 season skip about a third faster, #530 playtest build (club-colour UI, Combine, coaching approaches, Unicorns, injury-aware ratings), #532 six real home guernseys, #535 Tripo club badges, #536 Create-a-player preview, #537 FL-003 MCG, #538 team oval fit, #539 Back arrow, #541 game plans show their list strength, #545 FL-003/FL-007 decisions. Still open: #540 FL-007 milestone farewell (needs the director's look) and #546 favourite club (FL-005 addition). Confirm current heads and gates before proceeding. Do not reopen the already merged #467/#471 set-shot sequences, #475 shape demos, #479 six-plan consolidation, or #449/#473 weather foundation.
5. **Verify the draft/potential repair before proposing another rebalance.** #494 is on main: club horizons, age/career contribution, attainable veteran POT and tighter scouting reads are implemented. The director's original examples, five-season competitive checks and remaining calibration/playtest obligations are retained in §1.11; the broad outcome is not declared DONE solely because the repair landed.
6. **Then remaining approved catalogue work**, under existing FL/STYLE/RPG owners and dependencies. STYLE-07's base desktop-scaling repair is DONE; STYLE-01 alignment and STYLE-02 typeface foundations are merged. Remaining visual treatment, texture/material/performance work, native-phone checks and director approvals stay open where specified. The wider RPG programme's assignment/approval rules and the trailer's explicit start gate still apply.

**Historical priority declarations:** older wording that calls desktop scaling, Club Forge, AI drafting or potential inflation “highest” records the earlier director escalation, not a second current top-priority item. Stats alone holds the highest-priority position. The merged repairs are recorded at their canonical items; unresolved acceptance criteria survive this cleanup.

**Retained director quality/performance priority (`P1`):** free shader polish, texture improvement, artefact reduction, anti-aliasing and frame-rate/loading/battery work remain high priority under M8-007 LS/A4 and §1.11. The pitch/2D AA foundations (#472/#478) and seam repair (#491) are already merged; further data/filtering/material/performance acceptance stays open. Establish native baselines and verify current defects, then address local AA/filtering and unnecessary work before optional costly effects. Coordinate in-flight owners and preserve director appearance/native-device gates.

**Standing director UI rule (2026-10-07):** retire oversized sparse scrolling player rows from team editing and do not reuse them in future UI. Use compact contextual selectors with the shared field builder; its remaining entry-point/interaction checks stay under §1.11.

### Queue rules

Apply these within the latest explicit director priority override above; they do not create a competing highest-priority item.

- A newly observed **P0 correctness, soft-lock, fake/no-op mechanic or core-fun failure** jumps ahead of planned feature work.
- Findings from the System Reality Audit that are player-facing no-ops or materially misleading become repair work **before** unrelated new systems.
- Within a queue tier, honour explicit dependencies and choose the smallest high-value coherent task.
- Do not chase roadmap completion percentage. The objective is a good game, not a finished checklist.
- Do not use a lower milestone number as justification to work on a lower-value task.
- When a queue item is completed/merged, update this section so the next task is obvious without interpretation.

## 0.4.2 Research integration — career first

The director's priorities are visual simulation, creative team building, consistent careers over decades, evolving player roles, better emergent storytelling and meaningful coaching throughout matches and seasons. **Zero microtransactions; commercialisation is outside the objective.** Club salaries/budgets are in-game football resources.

The [genre enjoyment research](GENRE_ENJOYMENT_RESEARCH.md) studies eight cross-genre references plus Footy Redraft, AFCM, Crusader Kings and Esoteric Ebb. The director values Footy Redraft's stories and AFCM's list decisions, but finds the former solvable through known best recruits and the latter too inscrutable, with weak narrative thrust in long saves. Treat these as director experience, not claims that a competitor's engine is defective.

Refine the existing owners rather than adding another catalogue:

- match-driven gates and visible consequences: M4-001/002/003/004/006/009;
- competing roles, development and specialisations: M4-005, M5-003/006/008 and §9.1;
- list pressures and active-market measurements: M6-004 and §9.1;
- evolving individuals, genuine recognition and continuity: M7-003/004/005, the existing M6-002 former-player pathway and M8-005;
- visual evidence: existing match presentation and M8-007, still behind the phone gate;
- short questions with logical consequences: existing M4-001 gates and M6-008 media, preserving M1-011's DONE event foundation. Crusader Kings informs factual character continuity; Esoteric Ebb informs answer feedback and restrained humour. Neither authorises a new relationship or dialogue framework.

A coach should understand the problem, choose a feasible response, see its application and observe consequences that may help, hurt or remain inconclusive. A good choice need not win the match. Do not substitute hidden bonuses, best-move recommendations or arbitrary scripted drama.

**Accepted new work:** ARD-M5-016, inherited end-of-season 2026 lists followed by the 2026 National Draft and first playable season 2027. It follows correctness/phone gates and its source/save prerequisites.

**Unselected ideas:** ARD-RC references in §9.2 and the research report are candidates for director review. They are not TODO execution tasks and standing authority does not authorise them before selection. This documentation pass does not assign Claude work or merge gameplay.

## 0.5 Claude execution contract

### Audit ownership convention

When the user says **audit / investigate / check this**, treat that as a **Claude-owned engineering task**, not merely a note for ChatGPT. ChatGPT may inspect the code first, sharpen the hypothesis, record likely leads and keep the roadmap organised, but **Claude must run the final measured audit, make the implementation diagnosis/recommendation, and report the evidence**. The user remains the final design authority. Do not mark an audit complete solely from ChatGPT's preliminary code read.

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

