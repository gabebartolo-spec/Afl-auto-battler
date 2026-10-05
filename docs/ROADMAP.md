# Aussie Rules Dynasties — Canonical Execution Roadmap

_Last reorganised: 2026-09-28_
_Last sanity-checked: 2026-10-02 against current `main`, merged PRs and the full open-PR set_
_Research/status reconciliation: 2026-10-05 against `main` at `4b9eecc3858e970c46e25366701907f1cb4c6070`; see [genre enjoyment research](GENRE_ENJOYMENT_RESEARCH.md)._

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

## 0.4a Effort tags and parallel work

Effort sizes an item for the agent who picks it up. It is separate from Priority (how much it matters) and Autonomy (how much care it needs), and it is a first-pass estimate: when you learn an item is bigger or smaller than its tag, move it and say why in your PR.

- `LOW` — one focused change to one system or screen, with the player-facing decision already settled here and targeted tests that can prove it. Hours, one small PR. Verifying and closing work that is already on `main` is `LOW`.
- `MEDIUM` — a real feature or fix across a couple of systems (sim, UI, tests), a small save addition, or a measured seeded comparison. One or two PRs; may need a director phone check.
- `HIGH` — cross-system or content-heavy work, balance-gated tuning with open design questions, a data or research build, or anything that takes several PRs or director decisions along the way.

The director runs three agents at once, one per tier. The Low agent also keeps this file and the other docs current (progress, stale text, tags), tracks CI on every open branch and PR, and keeps the repo's branches tidy. Tags live only in the lists below. An item keeps its own section where it is, and a new item gets its tag, here, in the PR that adds it. Last sized 2026-10-06.

**Working alongside the other agents**
- Before taking an item, run `git worktree list` and `gh pr list`. A sibling worktree or an open PR on the same files means someone has it.
- Hot files: `scripts/sim/MatchSim.gd`, `scripts/state/GameState.gd`, `scripts/ui/UiKit.gd`, `scripts/ui/match/MatchNotes.gd`, `tests/expected_checks.txt` and this file. Keep hunks small and rebase on `main` just before you push.
- `tests/expected_checks.txt` has one floor per suite, and two PRs that raise the same suite's floor collide. Raise only the lines for suites you changed.
- In this file, edit only your own item. The maintenance log gets a new line at the top from nearly every PR, so a conflict there is normal: keep both sides.
- Godot is the bottleneck when several agents run it at once. Locally, run only the 1–3 suites your change touches (`tools/run_tests.sh <suites>`); CI runs the rest, as four parallel shards in about ten minutes. Never run the full suite locally. Only one long local Godot run per agent at a time, with its own user data (`APPDATA=<scratch dir>` on Windows), because every checkout shares one `user://`.
- Long audits (more than about five minutes) go to the audit workflow, not your machine: `gh workflow run audit.yml --ref <branch> -f impl=<name> -f env="KEY=VAL"`, then `gh run download <run-id> -n audit-<name>`.
- A new suite needs a line in `tools/ci_shards.txt` as well as a floor in `tests/expected_checks.txt`; CI fails if a suite is in no shard.
- Do not push to a branch while its CI runs unless you must: a push cancels the run and restarts about ten minutes of work. Ask the Low agent for a sync instead. The Low agent owns merges and cannot push to your branch, so sync your own branch when asked.

**`LOW`**
- §9.1 Training scrollbar.
- Verifying and closing work that is already on `main` (the Low agent does this as it finds it).

**`MEDIUM`**
- Match audits that need a measured seeded comparison, and a new mechanic only if the evidence demands one: ARD-M3-007 (free-kick rate), M3-008 (50-metre penalties), M3-011 (MRO and suspensions), M4-003 (tagging cost), M4-006 (game-state AI), M4-011 (Team Form), M5-006 (omitted-player development), and the §1.11 audits of run-of-goals calls, AI plan adaptation, key forward v key defender, sim-round blowouts, List Profile v results, and How-we-play maturity and materiality. In review: the autosim v played injury parity audit (#235) and the Coleman plausibility audit (#237).
- Features across sim, UI and tests: ARD-M2-009 (goal accuracy by shot context), M5-005 (emergency designations), M5-007 (selection continuity), M7-003 (career-high milestones need new tracking), M7-005 (history continuity check), M8-005 (5, 10 and 20-year career QA), the Grand Final climax screen, and from §9.1 the Weekly selection brief, Streamline Ins & Outs, My List → My Selection flow, Full List traits and contract-talk frequency.
- Performance and flow: §1.11 battery drain, the residual far-away receiver, vignette reachability, and quarter-break fact selection. The round-sim and Play match timing audit is in review (#236); its recommended background no-presentation sim mode is `MEDIUM`, to start only once MatchSim is quiet.

**`HIGH`**
- Scoring and contests: ARD-M3-001 (later variety), M3-002 (forward archetype scoring), M3-003 (spoils across the ground).
- Coaching and tactics: ARD-M4-001 (decision gates; the tired-star Rest/Keep trade-off is in review, #233), M4-002 (broader key match-ups), M4-004 (structural choices), M4-005 (role instructions), M4-007 (late-game tempo), and from §9.1 Gameplan choice and Key match-ups as interventions.
- Lists and selection: ARD-M5-001 (18 + 5), M5-003 (secondary positions), M5-008 (role-aware form), M5-016 (inherited 2026 lists), the §1.11 role-allocation re-audit, and from §9.1 My List → Shape as a selection surface and Academies / NGA.
- Board, league and balance: ARD-M6-003 (fair expectations), M7-004 (captaincy), M7-006 (weather), M7-007 (ground dimensions), and from §9.1 overall difficulty with active-play levers, synergies as specialisations, and the GOAT prospect.
- Content builds: ARD-M7-008 (custom prospect), M7-009 (expansion and Club Forge), M7-010 (Sir Doug Nicholls Round), M7-011 (AFL knowledge layer), M8-003 (match visualisation), M8-006 (release polish), M8-007 (vignette art-style replacement), the §1.11 Season story and long-save visual wishlist, and AFLW (deferred).

**Waiting on the director** — nobody's to pick up: the phone checks on ARD-M5-014, M5-015, M6-006, M6-008, the awards ceremony, training touch and the playtest fixes marked `VERIFY` in §9.1; the Android launcher icon (M8-008, the app name is already set in the export preset); whether to keep the trade-value discount for unproven potential (§9.1); whether the Key defender plan should be offered to defenders under 191 cm; and whether the temporary Sim to finals button (ARD-M1-007) is still wanted.

## 0.4.1 Current execution queue — overrides milestone order

This is the **authoritative near-term work order**. The milestone catalogue below is not a command to start more work while validated PRs are already in flight.

1. **Close any genuine P0 phone-playtest failures first (§1.11, §9.1).** A newly reproduced soft-lock, broken match flow, fake/no-op choice or major performance regression still jumps ahead of planned feature work.
2. **The former in-flight stack has landed.** _Reconciled 2026-10-05:_ the match-authenticity work (#190 merged; #196 smothers/speccies/50s/MRO/kick-ins), Combine/scouting (#188), the trade/contracts stack (#182 → #191 → #193 → #198, real-money contracts), GPS distance (#195), post-match media (#183), milestones (#186), History & records (#187) and the awards ceremony (#185) were closed as separate PRs and carried onto `main` by the consolidated squash merge #208; #189, #192, #194 and #205 merged directly. Do not reopen or re-create them; treat follow-ups as ordinary work against `main`.
3. **Reconcile the current active work before touching its systems.** At the 2026-10-05 checkpoint #223 (live-call/trade/free-agency evidence), #224 (unproven-potential trade discount), #226 (backed-player payoff, still targeting the oval-rings branch) and #206 (music) are open. #210/#213/#214 repairs and audits, #217 difficulty evidence, #220 backing, #221 rings, #222 scouting estimates and #225 assistant contracts are merged. Preserve remaining phone checks; do not create parallel valuation, promise or payoff systems.
4. **Then resume genuinely unstarted catalogue work** from M3/M4/M5/M7/M8 and the §9.1 playtest findings according to player value and dependencies, rather than roadmap-number order. M5-001 (18 + 5 interchange) remains a separate TODO now that selection changes have settled.

### Queue rules

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

**The human player gets no hidden mechanical advantage over AI-controlled clubs.** Difficulty should come from making better decisions within the same football world, not from rules, buffs or development opportunities that secretly favour the user's club.

Unless a feature is explicitly player-only UX:
- Human and AI clubs obey the same underlying football, list-management, development and competition rules.
- Any mechanic that can improve the human club's players, list or match outcomes must have an equivalent route available to AI clubs under the same underlying rules. This includes training/development, POT and breakout behaviour, form/morale effects, injuries/recovery, contracts, drafting, trading, selection and tactical effects.
- Do not give the human club hidden rating boosts, favourable RNG, easier development ceilings, protected outcomes, cheaper costs, extra information or other mechanical assistance that an AI club cannot receive in the equivalent situation.
- AI clubs obey the same availability, salary-cap, suspension, concussion, selection and match rules.
- AI should be able to make equivalent tactical choices.
- Never give the player a rule loophole unavailable to AI, or vice versa, without documenting why.
- Player-only **interface conveniences** are allowed when they help the human operate the game but do not change the underlying simulation outcome. If an intentional difficulty/accessibility setting ever breaks parity, it must be explicit to the player rather than hidden.
- When implementing or auditing a system that affects competitive outcomes, explicitly check human/AI parity. A mechanic that works only for the user's club is a correctness problem unless the roadmap deliberately documents it as an explicit asymmetric mode.
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

### UI anti-slop reset — current concern
**The current UI policy/implementation has drifted away from the project's anti-slop criteria and needs an explicit corrective pass.**

This concern is specifically about **visual styling language**, not about information density or "visual vomit". A screen can be clean and sparse yet still look slop if it uses the wrong card geometry, corner treatment, colour palette and generic app-template styling.

**Footy Redraft and AFCM are negative references for this specific aesthetic problem.** This is not criticism of their gameplay or information density; they are examples of the kind of generic management-game/mobile-app look this project should avoid.

Anti-slop criteria:
- avoid generic AI-template / app-template visual language,
- avoid soft rounded cards as the default container shape,
- avoid excessive corner radii, pill buttons and chip-heavy composition,
- avoid generic muted-green/teal/blue SaaS-style palettes,
- avoid decorative gradients, glows, glassmorphism and gratuitous shadows,
- avoid every section being enclosed in its own rounded rectangle,
- avoid generic "premium mobile dashboard" aesthetics,
- avoid condensed display fonts or all-caps styling unless genuinely justified,
- use sentence case and natural football language,
- use flatter, sharper, more restrained geometry where possible,
- let typography, spacing, rules/lines and club colours create hierarchy instead of rounded card stacks,
- keep the visual language recognisably football-specific rather than resembling a finance/productivity app,
- maintain mobile-first readability and touch clarity.

The anti-slop test is primarily visual: **if the screen could plausibly belong to Footy Redraft, AFCM, a generic AI-generated sports manager, or a modern SaaS dashboard after swapping the logo, it has drifted too far.**

When revisiting existing UI, Claude should inspect card shape, corner radius, button silhouette, palette, border treatment, typography and spacing before changing information architecture. Do not misread this note as an instruction to simply remove stats or reduce content.

This note is not permission for a broad unreviewed redesign. Apply the anti-slop standard incrementally to authorised UI tasks and record larger systemic cleanup as its own scoped audit/repair item if needed.


### Art-agent tooling permission for bespoke UI
For authorised UI/art work, the art agent may investigate and use **free software only** to create bespoke interface assets, layouts, textures, panels, decorative elements, typography treatments, iconography and other presentation pieces that help the game escape generic app-template aesthetics.

Rules:
- Free/open-source tools are preferred.
- No paid licences, subscriptions, paid plugins, marketplace packs or trials that later charge without separate explicit user approval.
- The art agent may research, download and use suitable free software if its environment permits.
- If the agent cannot install or operate a required free tool directly, it may ask the user to install it and should provide concise instructions.
- Any new tool introduced should have its source/licence noted in the relevant implementation notes.
- Tool adoption must serve the game's bespoke football-game visual identity; do not add software merely because it is fashionable or powerful.
- Generated UI assets still need to obey the anti-slop criteria above and the project's existing licensing/copyright guardrails.

This permission includes software for areas such as vector UI design, raster painting, icon creation, texture generation, layout mockups, motion/UI animation, sprite-sheet work and other custom interface production, provided the software itself is free to use.

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
- **Closed from this list** (checked against `main` on 2026-10-06; the original write-ups are in git history): match-feed club labels (#120); unavailable tag targets (#121); the three-game Coaching gate (`test_club.gd`); recent-games form copy (#117); form-streak colour (#122); the tired-star rotation prompt (#119); week-by-week finals for a club that is out; the Season Review scroll; centre-bounce vignette participants; St Kilda `SKN` → `STK` (data and code, with `CareerSave.RENAMED_CLUBS` and a `test_save.gd` check that an old save loads into the same St Kilda); the pre-match scene on every Play match (#143, `PreMatchVignette`); match-up narrative continuity (`MatchNotes.duel_story`, `test_match_game.gd`); set-shot chances by distance and angle (`MatchSim.set_bands`, calibrated to AFL rates and tested); draw frequency (`test_league_balance.gd`, and finals never end level in `test_finals.gd`); and the 'hurting you' lever (#230, `test_matchday.gd`).
- Match simulation can freeze/stall.
- **Residual far-away receiver / loose-ball wait bug:** phone playtesting still shows occasional pauses where the visualisation waits for a distant predetermined player to reach the ball while nearer players stand off, despite the earlier match-flow repair. Treat this as an unresolved core-flow defect rather than closed work. Capture concrete occurrences and trace whether the delay comes from MatchSim selecting an implausibly distant next actor, MatchDirector/Motion over-honouring a predetermined event actor, or presentation failing to hand the loose ball to a locally plausible contestant. Prefer the smallest fix that preserves MatchSim authority and existing balance; do not silently change football outcomes just to make the animation look smoother. Acceptance: loose-ball sequences no longer visibly stall for a far-away player when a nearby eligible player could plausibly contest/collect, and any unavoidable long run has a football reason visible in the simulation state. Add targeted regression/replay coverage for the previously observed failure pattern.
- List/selection synergies are opaque enough that the user cannot reliably reason about why a combination should work.
- Pre-match and in-match choices feel insufficiently informed: the user is often clicking an option and hoping rather than making a football decision from understandable evidence.
- Results do not provide enough feedback to connect a decision to what subsequently happened, so the player cannot readily learn from wins/losses.
- **How-we-play data maturity / season-learning audit:** once `How we win / How we get beaten` unlocks after three matches, it can feel effectively fixed for the rest of the season instead of becoming a better read as evidence accumulates. Current code is **not literally frozen**: `_note_form_and_team()` adds every match to `season_team`, and `_style_found()` recomputes per-game differences against the current league average whenever the screen is read. The phone screenshots already show small numeric movement (for example ruck edge 12 → 10 hit-outs, turnover concession 7 → 6), so treat this as a quality/confidence problem rather than a stale-state bug unless testing proves otherwise. Audit whether the same top traits become too sticky after the initial three-game sample, whether early outlier games dominate too long, and whether new evidence can realistically promote/demote/reorder traits. The system should become **more trustworthy, not merely more verbose**, as the season grows. Prefer sample-size-aware thresholds/shrinkage or similarly simple statistical treatment over extra UI; if early-season uncertainty needs copy, keep it minimal (for example an 'early read' treatment rather than confidence bars/numbers). Acceptance: after each match the underlying profile is recomputed from all available season data; early three-game identities are appropriately provisional; materially changing team performance can change which traits are surfaced; stable genuine traits become harder to dislodge as evidence grows; and late-season `How we play` is demonstrably more reliable than the first three-game read. Add deterministic season-progression tests at 3, 6, 12 and 20+ games.
- **How-we-win / get-beaten actionability and materiality audit:** the current section can surface trivial deviations as if they explain results — e.g. **2 extra points conceded from turnovers** and **1 fewer point scored from turnovers** are shown under `How we get beaten`. Nobody is meaningfully losing because of a three-point combined seasonal tendency, and the output becomes statistical vomit rather than coaching information. Code inspection shows the root cause: `_style_found()` only requires a **7% relative gap** plus an absolute difference rounding to at least 1. On low-baseline stats, a one- or two-point difference can therefore rank as a major trait, and correlated symptoms can stack (`against` plus `conceded_turnover`) without telling the user what to do. Redesign this section around **material, football-addressable problems/opportunities**, not whichever percentages are furthest from league average. Calibrate metric-specific minimum effect sizes from league distributions and match impact rather than one global relative threshold; suppress trivial differences even if percentage-wise large; collapse redundant/correlated lines into one clearer football diagnosis; and prefer leading/process indicators the player can act on (territory, stoppage control, turnover creation/concession, pressure, ball retention, aerial contests) over tiny score-source noise. Do not assert causation the data cannot support: if the section cannot demonstrate a credible reason a tendency contributes to wins/losses, phrase it as a team tendency or omit it. Each surfaced weakness should have at least one existing or planned football lever the player can plausibly use to address it, without recommending an objectively best button. Acceptance: a line such as +1/-2 points per game never appears as a headline win/loss identity merely because its relative percentage is high; the screen shows at most 2–3 genuinely material, non-duplicative traits; each is understandable and actionable in football terms; and seeded season tests show surfaced traits correspond to meaningful differences in outcomes or underlying play.
- **Quarter-break “What's happening” information vomit / tense problem:** the break screen currently mixes retrospective match facts, opponent-plan history, streaks and resolved in-play moments under a present-tense heading (“What's happening”), producing a dense, feed-like block that is awkward to read and visually ugly. Treat this as a presentation/decision-clarity issue, not a request for more data. Reframe the section as a concise record of **what happened in the quarter/half** and only surface the few facts that materially help the next decision. Avoid replaying resolved event-feed moments (for example a completed set shot) unless they matter tactically. Acceptance: at a break, the user can scan the section in a few seconds, understand the 2–3 most important developments from the period, and distinguish them cleanly from “What your calls did” and the next-quarter controls. Preserve football language; no stat dump and no duplicate story lines. **Status:** heading/tense part fixed in PR #123; the fact-selection/info-density part remains open.
- **List Profile vs actual team strength validation:** the user's side can read as mostly Strong/Average across the five List Profile dimensions while losing every match heavily. The profile is not meant to predict every result, but if a side has no visible Weak area and repeatedly performs like a bottom side, the words may be overstating practical strength or omitting an important determinant of match performance. Audit the relationship between each profile label and realised match performance/results across clubs and repeated seeded matches. Do not turn this into an overall power rating or recommendation. Acceptance: Strong/Elite labels correspond to materially better outcomes in the football area they describe, and a side that is broadly above average across the profile does not routinely behave like a clearly weak team without an explainable cause visible elsewhere.
- **Current-list club identity bug:** `My list` is still colouring each player's guernsey/number tile from `p["club"]`, which in a league re-draft can remain the player's original/source club. On the user's Melbourne list this produces a patchwork of old-team colours even though every player now represents Melbourne. Current-squad screens must use the player's **current club/list context**, not historical source-club metadata. On `My list`, every player should therefore carry Melbourne's red/blue identity (prefer the existing multi-band club marker where practical, not a single stale origin colour). Apply the same rule anywhere else that presents a player as a current member of a club: selection, training, match-day list/profile surfaces. Preserve original/source club only for explicit history/draft-origin contexts. Acceptance: after a league re-draft, no current-list screen visually implies a player still belongs to his former club; a Melbourne list reads consistently red/blue while career/history screens can still show past clubs when relevant. **Status:** fixed and merged in PR #118.
- **Club marker colour accuracy audit:** the round-results screen exposes that a number of club colour markers do not convincingly match their real AFL identities. This screen is not inventing colours locally: `HubScene._results_list()` uses `UiKit.club_badge()` → `club_marker()` → `GameDB.club_marker_colours()`, which reads the hard-coded `primary/secondary/accent` values in `data/clubs.csv`; therefore audit the **source palette for every current AFL club**, not just this popup. Verify genuine club colours, ordering, two-vs-three-colour treatment and sufficiently accurate shades against authoritative club/AFL branding references. Do not use generic approximations simply because they are distinguishable. Obvious shade/order candidates should be checked rather than guessed (for example North Melbourne currently uses a very dark navy-like `#0C2340` as its primary despite its recognisable royal blue/white identity). Keep fictional/future clubs separate from the real-club audit. Acceptance: every 2027 AFL club marker is immediately recognisable to a footy fan across results, ladder, draft, selection and other shared badge surfaces; shared `club_marker` remains the single source of presentation; add a palette regression/snapshot fixture so later UI work cannot silently reintroduce wrong colours. **Status (2026-10-06): fixed in PR #231, pending merge.** Every 2027 AFL club's `data/clubs.csv` palette is corrected to the clubs' sourced Pantone references with director sign-off (North Melbourne, Brisbane and the Bulldogs back to royal blue; Port Adelaide's teal), with Carlton and Melbourne keeping a lifted navy for on-pitch legibility; `club_marker` remains the single presentation source; `test_matchday._test_palette_snapshot` pins all 20 clubs. Fictional/future clubs (Tasmania, Canberra) unchanged. Phone legibility check remains.
- **Authentic away/clash guernseys:** add alternate away/clash kits for real AFL clubs using colours and treatments genuinely associated with those clubs, rather than generic recolours. Examples include Melbourne variants using royal blue and GWS charcoal-based alternates. Research each club's real away/clash/history of alternate guernseys and build a small authentic palette/template set per club that can be used in match presentation and the guernsey system. Preserve recognisable club identity, avoid inventing colours with no real basis, and use alternates contextually when the home kit would clash.

- **Heritage rounds and commemorative guernseys:** add authentic throwback and milestone-season strips for real AFL clubs. Research historically grounded designs, colour balances and eras rather than inventing novelty reskins. Support heritage rounds, anniversary seasons and club-specific commemorative variants where appropriate. Keep the system presentation-led: visual flavour and long-save identity, not arbitrary gameplay buffs.

- **Coach appearance / card customisation:** add restrained visual customisation for the player coach, including portrait style, clothing presentation (for example suit, jacket or polo) and light long-career ageing/progression. Keep the system simple and readable rather than turning the game into a deep avatar editor. Preserve the football-management focus.

- **Finals / premiership presentation variants:** strengthen visual presentation around finals and premiership status. Support finals/event branding, special guernsey markers or badges where appropriate, reigning-premier treatment in the following season, and stronger captain/leader presentation in major moments. Keep this cosmetic/presentational unless a separate gameplay rule explicitly exists.


- **Trophy cabinet / honour board evolution:** make the club hub visibly accumulate history over long saves. Surface premierships, major individual awards, club champions, coaching honours and significant records through a restrained trophy-cabinet / honour-board presentation that grows as the career progresses. The visual state should reflect actual save history, not a static decoration screen, so a 30-year dynasty looks materially different from a new career. Keep it compact and integrated into the club/history experience rather than creating a separate collectible-management minigame.


- **Premiership guernsey history:** preserve the exact club guernsey/logo identity associated with each premiership season so long-save history can visibly show different eras of the club. Link this to the existing guernsey/logo systems rather than storing decorative duplicates.

- **Player career card evolution:** let a player's presentation mature with their career status — rookie, established player, captain/star, retired legend — while keeping the same underlying identity. Changes should be visual and status-driven, not stat buffs.

- **Record-breaker presentation:** when a player or coach claims a major club/league record, give that achievement a persistent visual marker in profiles, history and relevant honour-board surfaces. Keep the treatment selective so genuine records feel important rather than becoming badge spam.

- **Club legends wall:** create a rare, curated visual layer for truly exceptional club figures such as iconic players, premiership captains and dynasty coaches. Entry should be earned by major career achievements/history, not by generic OVR thresholds.

- **Grand Final-specific presentation package:** give the Grand Final a clearly elevated visual treatment through crowd split, event branding, scoreboard framing, team entry/anthem/banner presentation and premiership-dais moments. Keep this focused on ceremony and identity rather than adding arbitrary gameplay modifiers.

- **Draft class visual identity:** give each draft year a simple, recognisable presentation identity so historical draft classes remain easy to browse and distinguish over decades. Tie the presentation to the existing draft/history system rather than creating a separate collectible layer.

- **Save-era photo / archive gallery:** preserve a small set of generated or captured archival moments for major career events such as first premiership, 300th game, record break or famous final. Keep it selective and history-led rather than turning the save into an automatic screenshot dump.

- **Club museum / timeline view:** build a long-save visual timeline combining premierships, coaches, captains, major records, famous finals, logo/guernsey eras, expansion milestones and other significant club history. This should unify existing history systems into one readable visual destination rather than duplicate them.

- **Retirement presentation variants:** scale farewell presentation to the player's actual career. Ordinary retirements should stay quiet; club champions, 300-gamers, record holders, captains and premiership greats should receive stronger presentation grounded in their history.

- **Dynamic crowd identity:** make crowds visually reflect club support, home/away balance, rivalry intensity and finals context through colours, scarves/guernseys and density treatment where practical. Preserve readability and avoid expensive bespoke crowd simulation.

- **Custom club typography / monogram treatment:** support restrained club-specific lettering/monogram identity for numbers, initials, badges and selected presentation surfaces, especially for expansion and user-created clubs. Keep typography readable and consistent with the anti-template visual guardrails.

- **Season poster / yearbook cover:** at season end, create a compact archival season summary presentation featuring major outcomes such as premier, Brownlow, Coleman, ladder context and key storylines from that year. Treat it as a history artifact for long saves, not a stat-vomit report.

- **Stadium identity:** give venues recognisable visual character without building a stadium-construction system. Use venue-aware presentation such as boundary treatment, signage, crowd colour balance, roof/open-air feel and finals/event branding. Reuse shared match-presentation systems and avoid bespoke one-off UI that is expensive to maintain.

- **Generated player visual identity:** give players simple, stylistically consistent visual identities using attributes such as age, hair, skin tone and facial hair, with visible ageing over long careers where practical. Prioritise consistency, readability and long-save flavour over photorealism. Generated visuals must remain stable enough that the same player still feels recognisable across seasons.

- **Club-aware UI skinning:** allow restrained club-aware UI theming so headers, dividers, accent lines and similar presentation elements can reflect club identity. Preserve readability, accessibility and the anti-template visual guardrails; do not let club theming become colour vomit or reintroduce generic green-accent styling.

- **User-designed guernseys:** add optional player-facing guernsey customisation, including home, away and clash variants. Allow users to create or edit club strips while preserving on-field readability and clear team differentiation. This can be especially valuable for expansion/custom clubs, but should not be artificially restricted to them.

- **User-designed logos / badges:** add optional player-facing club logo/badge customisation. Support custom identity for expansion and fictional clubs and allow broader use where technically practical. Keep import/editor UX mobile-friendly and avoid forcing logo creation as a mandatory step.

- **Player role-allocation / draft-position distribution audit — REOPEN:** Gryan Miers is being labelled **Wing** in the user's list even though the source data explicitly lists him as `FWD`, and his real football role is a pure small/creative forward rather than a wing or pressure-forward. **Bodhi Uwland is also being treated as a Key defender despite being a 188 cm medium/rebounding defender who can take lockdown jobs but is not a key-position defender.** Code inspection shows both primary-role and subtype problems. `Ratings.derive_all()` chooses the primary role largely from season-stat role scores, then only applies two hard-coded forward corrections; a player read as `MID` can receive `FWD` only as a secondary role, and `Roles.is_wing()` can then mislabel him from stat shape. Separately, defender subtype classification currently ignores height/size entirely: `PlayerProfile.player_type()` picks between training archetypes, where **Key defender = intercept 3 + pressure 2** and **Rebounding defender = carry 3 + intercept 2**. That means a medium defender with strong intercept/one-percent/pressure numbers can become a 'Key defender' simply because he is less of a ball carrier. Do **not** fix these with one-off Miers/Uwland overrides alone. Re-audit the whole role classifier against football reality and source listed positions, especially MID↔FWD, MID↔DEF, and defender subtypes. Audit whether the current binary Key/Rebounding defender labels are themselves too coarse; a medium/general/lockdown identity may be needed if it better describes real usage, but prefer the smallest model that avoids false key-position labels. Measure source `real_pos` vs derived primary/secondary roles across the full 2026 pool; manually inspect representative archetypes (small forwards/creative forwards, key forwards, rebounding defenders, medium/lockdown defenders, true key defenders, genuine wings, inside mids); quantify draft-pool counts and match-day coverage by role before and after any change. Source listed position, height and actual football usage should be meaningful evidence, with stats used to refine dual-role capability/archetype rather than casually overwriting an unambiguous football role. Preserve legitimate dual-role players. Acceptance: Gryan Miers is a forward; Bodhi Uwland is not labelled Key defender; true key defenders require credible key-position evidence rather than merely high intercept/pressure; known pure forwards/defenders are not routinely converted into midfielders because of disposal volume; genuine wings such as Harvey Langford remain distinguishable from inside mids/forwards; the league draft has a plausible supply of FWD and DEF options without artificial quota stuffing; and regression tests cover representative named and archetypal cases.
- **Android battery-drain audit:** phone playtesting reports that the game drains the phone battery much faster than expected while it is open. **The user did not report abnormal device heating**, so do not treat thermal behaviour as an observed symptom. Profile power-relevant behaviour before optimisation: compare an idle hub/menu, a paused match, a live match at 1x, and accelerated playback. Record actual FPS/refresh rate, CPU frame time, render frame time, draw/redraw frequency, active `_process` callbacks/timers, and whether the app continues doing meaningful work while visually idle. Concrete leads already visible in the repo: `project.godot` does not set an explicit FPS cap / low-processor mode, so a high-refresh Android display may be rendering far more frames than the game needs; `PitchView.gd` calls `set_process(true)` and its `pause()` only flips `playing = false`, so its per-frame callback continues while paused even when little is changing. These are audit leads, not assumed root causes. Compare a sensible capped rate (for example 60 fps, and lower when static if Godot permits cleanly) against current behaviour without degrading match readability or touch response. Acceptance: identify the dominant sources of unnecessary power draw, eliminate avoidable idle/per-frame work, and verify materially lower battery consumption during a normal play session. Do not trade simulation correctness for battery life.
- **Round simulation / Play match performance regression audit:** phone playtesting reports that **Sim round takes far too long**, and the delay after tapping **Play match** appears to get progressively worse as the season advances. Profile this by phase and by season round before optimising: benchmark cold-device runs at R1/R6/R12/R18/R24 for (a) `prepare_interactive_match`, (b) one background `Season.simulate`, (c) a full `Season.play_round`, (d) rival XP/training + `_after_round`, and (e) autosave/serialization; repeat after a long continuous session to distinguish season-state growth from other sustained-runtime effects. **Do not assume thermal throttling from the user's report; heating was not reported.** A concrete architectural cost is already visible: `prepare_interactive_match()` synchronously simulates **every other match in the round before the user's MatchSim is even created**, so tapping Play match blocks on roughly eight full background simulations. Background `Season.simulate()` also runs the full `MatchSim.run()` path, which generates rich match state/events intended for watched/reviewed games even though most rival matches only need their result and stats. Audit whether a non-visual/background mode can suppress presentation-only event/log work while preserving identical football outcomes and award/training stats. Also inspect any season-length-dependent scans/allocations (including `club_form()` walking accumulated results) and save growth. Acceptance: Play match gives immediate transition feedback and reaches the user's match without waiting unnecessarily for unrelated fixtures; Sim round has a measured target suitable for phone use; R24 is not materially slower than R1 except for justified bounded work; background fast-sim produces the same seeded scores/player/team stats needed by the career; and no optimisation changes balance or RNG outcomes. **Status (2026-10-06):** measured on `main` ([evidence](ROUND_TIMING_2026-10-06.md), `tools/audit/round_perf_impl.gd`); nothing grows with the season. Desktop, R1 → R24: Sim round flat at about 0.6 s, the Play match tap about 45 ms (the other matches now run on background threads behind the pre-match scene, so the "eight simulations first" lead is out of date), full time 50–210 ms with no trend; the save grows about 15 KB a round (2.08 → 2.44 MB, save 80 → 105 ms). The remaining cost is flat: one match is about 0.45 s of a desktop core, run in waves of `cores − 1`. Open: a background no-presentation MatchSim mode with identical seeded results, after a native phone timing sizes the win.
- **Vignette playtest reachability problem — BLOCKER FOR THIS PLAYTEST:** the current centre-bounce prototype is still not appearing in organic phone playtests. This now includes a match decided in the final minute, which is strong evidence that the issue may be more than simple rarity. The nominal trigger is a centre bounce in Q4 after 100 match minutes with the margin within 12 points, but `_moment_ready()` also gates moments behind the per-quarter moment cap / chain gap and `_boundary_moment()` checks other moment types first. Audit whether competing Q4 moments, `MAX_MOMENTS_Q`, `MOMENT_GAP`, trigger ordering, or centre-bounce state can make the vignette effectively unreachable even in close finishes. Do not ask for further organic vignette testing until it is deliberately reachable. For prototype validation, add a temporary/manual playtest trigger or otherwise guarantee one vignette opportunity in a normal test match without changing MatchSim's underlying football outcome. Acceptance: a tester can deliberately reach the vignette in one match without needing a lucky close finish; add targeted coverage proving the vignette can actually fire through the real MatchScene flow; production frequency must be reconsidered separately after the scene passes the phone-playtest gate. **Playtest trigger (2026-10-05):** Settings has "Centre-bounce scene every match" (off by default; `GameState.bounce_scene_every_match()` -> `MatchSim.always_offer_bounce`). With it on, the centre-bounce call comes at the first centre bounce of the last quarter of every match you coach, whatever the score or minute, once a match. It sits outside the quarter's calls (their budget and spacing are put back), so every other call still comes when it would, and "Play it straight" leaves the match exactly as it was. Tests: `test_match_game` plays six seeded live matches with it on - every one reaches the call, and played straight each ends with the same score and the same other calls as without it; `run_matchday_tests` checks the setting reaches the match, that a blowout early in the last quarter brings no call without it and the call with it, and that the call opens the scene in the real match screen. The audit of why organic close finishes miss it (calls spent, MOMENT_GAP, ordering) and production frequency remain separate.
- **Vignette player representation / appearance bug:** the current cinematic vignette prototype effectively presents every player with the same white/light-skinned appearance, so Indigenous and other darker-skinned players are visually misrepresented. Treat this as a representation defect in the vignette renderer, not as cosmetic polish. Add neutral **appearance data** for rendering (at minimum skin tone; hair appearance only where the vignette system actually supports it) and use that data instead of a single default player appearance. **Do not create gameplay race/ethnicity attributes and do not infer race or ethnicity from player names.** For the current real-player dataset, curate visual appearance from reliable visual references where practical; for future/generated players, generate a genuinely varied range of appearances independently of ratings, potential, role, personality, discipline, athleticism or any other gameplay trait. Acceptance: vignettes no longer render every player as white; real players are represented credibly without racial labelling or name-based inference; generated-player appearance has visible diversity with no gameplay correlation; and the change remains presentation-only. **In progress (2026-10-05), director's decisions:** six skin tones and a hair colour (`Appearance.gd`), presentation only. Real players: `data/player_appearance.csv`, drafted by Claude from the clubs' official squad photos and reviewed by the director (status draft / unsure / confirmed; unsure = between two tones, top of the review); until a player has a row he wears one neutral look, never a guessed one. Generated players: a look from the id alone, weighted to the curated league's mix (a default mix until 100 rows exist). Review sheet: `tools/visual/capture_appearance.gd --club ADE`. Adelaide is drafted as the pilot; the other 17 clubs follow once its calibration is approved. The 2026 draft class stays neutral until curated.
- **Run-of-goals intervention audit:** in a phone playtest Brisbane kicked eight unanswered goals and, once the run started, the game repeatedly asked after subsequent goals whether to **Throw numbers at it** or **Slow it down**. The user tried interventions and perceived no effect. This may be a legitimate case of being outclassed rather than a broken mechanic, so diagnose before tuning. Audit two things separately: **cadence** (the same run-of-goals prompt should not fire mechanically after every additional goal in one streak; repeated calls need a meaningful cooldown/state change) and **efficacy** (surge/hold should produce measurable short-term effects in the directions their copy promises, without guaranteeing that a weaker side stops the run). Use paired seeded states from the same score/run situation with each option and the no-change/default choice; measure next-N-chain clearances/territory/scoring, opponent scoring, and leg cost. Also verify repeated calls do not stack/reset in a way that makes them misleading or ineffective. Acceptance: each option has a statistically visible, bounded trade-off; a strong opponent can still overwhelm it; and the player is not spammed with the same decision every goal while nothing new has changed.
- **Grand Final / premiership climax presentation:** phone playtesting confirms that `Sim to Grand Final` currently ends on the generic round-results modal: a small **Grand Final** label, `Premiers: Greater Western Sydney`, two score rows and a **Continue** button. Code inspection confirms `_show_results()` is the same generic results overlay used for ordinary rounds, with only one extra `Premiers:` line when the season is over. That is far too unceremonious for the climax of a full season, even when the user's own club has already been eliminated. Give the Grand Final a bespoke end-of-season result presentation with clear escalation and a proper premiership reveal: establish the matchup/result, reveal the winner as premiers, give the final score/margin enough visual weight, and then hand off cleanly into the season-story/awards sequence. Fanfare should come from pacing, hierarchy, club identity and a sense of occasion rather than generic particles or a giant stat dump. If the user fast-forwards the finals, they should still land on this climax rather than an ordinary round popup. Acceptance: the Grand Final can never be mistaken for a routine fixture result; the premier reveal feels like the culmination of the league season on phone; the result is still quick to read/skip on repeat careers; and `Continue` leads into the proper post-season flow rather than making the season simply stop.
- **Season story / campaign recap — separate from awards night:** the existing `Season Review` is mostly a stat sheet plus league awards: finish/record/points, PF/PA/percentage, best win, worst loss, longest win streak, goals, a W/L strip, final ladder, board verdict, awards and achievements. That is useful, but it does **not** yet give the emotional/narrative payoff of finishing a long campaign. Add a concise **Your season / Season story** recap after the Grand Final that tells the story of the user's year in football language, separate from the awards panel. Treat it like completing a major RPG campaign: identify the season's arc rather than dumping every round. Candidate beats include the opening trajectory, longest/biggest winning and losing runs, a genuine finals push or collapse, defining wins/losses, key performers, important injuries that changed the side, major improvers/breakouts, and how the year ultimately ended. **Also include the football identity the player actually coached into the side across the year:** e.g. `We played through the corridor most weeks`, `Nick Daicos was our focal point in most matches`, `We were conservative with legs and rotated hard`, `We usually backed our contested game`, `We changed plans often rather than sticking to one style`. These tendencies must come from actual season usage, not generic flavour text. `MatchSim.result()` already exposes `tactics_history`, `stars`, `interchanges`, `moments`, `impact` and related match data, but `CareerSave.slim_results()` deliberately strips most of that from `season_log` on save/load; therefore if the recap needs to survive a reload, track a **small incremental season-story ledger** as matches finish (plan-quarter counts, play-through/focus usage, rotation philosophy counts, notable streaks/results, significant injuries, player development/performance candidates) instead of retaining giant match logs. Keep it curated: roughly 5–8 memorable beats plus a short `How we played` identity block, not a timeline dump. Do not conflate this with awards night; Brownlow/Coleman/AA/B&F remain separate recognition, while the story answers **what happened to us this season and what kind of side were we?** Acceptance: after a full season, the user can read the recap and recognise their own campaign and coaching habits; tendencies are quantitatively grounded in actual usage (e.g. majority-of-quarter/match thresholds rather than one isolated call); the same recap survives save/reload; major injuries/improvers only appear when genuinely season-defining; and the presentation avoids number vomit while preserving enough concrete detail to feel earned.
- **AI plan adaptation / Controlled-tempo free-counter audit:** phone playtesting showed an opponent repeatedly using **Defensive press** across quarters while trailing, while the user could answer with **Controlled tempo** even with subpar ball users and seemingly counter it for free. Current code explains both concerns: `ai_tactics()` only abandons the AI club's standing plan when the margin crosses a tactics-read threshold (`18 - 8 * read` points), so a naturally defensive side can remain in Defensive press while losing by a smaller margin; meanwhile `PlanFit.gd` explicitly gives Controlled tempo **no list-fit requirement at all** (`fit == 1.0` for every list), even though its identity is about reducing pressure/clangers and should plausibly depend on ball use/composure. Audit, do not just make the AI psychic. Test AI plan choices by quarter, margin, standing-plan identity and recent observed match state using only information available to a coach; determine when a losing side should persist with its style versus chase the game. Separately test Controlled tempo with strong vs weak disposal/decision-making lists against Defensive press. Acceptance: a defensive AI can sensibly persist when appropriate but does not mechanically sit in a losing countered plan all game; Controlled tempo is not an equally effective press-counter for poor ball-use sides; and there remains no hidden direct read of the user's selected plan.
- **Key-forward vs key-defender balance audit:** phone playtesting suggests good key forwards are consistently getting the better of good key defenders. Do not assume a nerf/buff yet; measure it. The current matchup system only sends a small explicit share of inside-50 entries through named key-forward matchups (`KEY_TARGET = 0.06`), while most forward-50 outcomes still come from broader line strength and shooter selection. On explicit duels, forward aerial ability is `70% marking + 30% height` while defender aerial ability is `45% intercept + 30% marking + 25% height`, then layered on top of team forward-mark vs defensive-intercept strength. Audit whether strong key forwards are over-performing overall, whether strong key defenders materially suppress them, and whether the named matchup system is too infrequent to matter. Run seeded matchup matrices across elite/good/average key forwards vs elite/good/average key defenders, tracking target share, mark win rate, shots, goals, spoils/intercepts and matchup-report verdicts. Acceptance: elite forwards can still win games, elite defenders can genuinely contain them, equal-quality matchups are not systematically tilted one way without evidence, and matchup presentation reflects the measured duel rather than reputation.
- **Coleman / individual goalkicker plausibility audit:** Round 18 phone playtesting has **Brodie Kemp leading the Coleman with 48 goals**, ahead of established spearheads. This is surprising enough to audit, but not automatically a bug: the shipped 2026 data already has Kemp at **39 goals from 25 games (1.56/game)** and listed as `FWD`, so the model has genuine source-season evidence that he can score; a redraft can also create unusual opportunity. The current calibration only checks **how concentrated** team goals are (top goalkicker ≈16% of club goals, top three ≈38%), not whether the players who become league-leading scorers are plausibly the best/most-used forwards. Add season-level validation across many drafted leagues: correlate goals/game and Coleman finishes with goalkicking, accuracy, marking/forward role, actual source scoring and team opportunity; inspect outlier Coleman leaders manually; and measure whether middling forwards can routinely become 60+ goal spearheads merely because shooter selection funnels chances to them. Preserve genuine breakout seasons and redraft weirdness — do not hard-code famous names or force the real-world Coleman order. Acceptance: unusual winners remain possible, but league-leading goal seasons are usually produced by players with a credible scoring profile and/or clearly explainable opportunity; strong source scorers are not systematically suppressed; and the long-run Coleman goal totals/distribution remain AFL-plausible. **Status (2026-10-06):** audited over 12 drafted leagues ([evidence](COLEMAN_AUDIT_2026-10-06.md)). Leaders are credible: every winner and top-five finisher is a genuine forward, no 50-goal season came from a sub-1.0-a-game real scorer, simulated vs real goals a game is Spearman 0.66, and Kemp (1.56 a game real) finishing high is legitimate redraft opportunity. **Defect found, not fixed:** `Ratings.build_norm_params` caps `goals_pg`/`marks_inside50_pg` at the whole pool's 98th percentile, so 10 forwards from 2.13 to 3.47 real goals a game all read goalkicking 99. Marking and OVR then decide the Coleman (Treacy, marking 96, wins 6 of 12; Curnow and Gunston one each), and 60+ goal seasons are thinner than real (2 a season vs 6). A headroom fix re-rates forward OVR, so it is BALANCE-GATED and awaits the director.
- **Sim-round score / blowout plausibility audit:** phone playtesting produced some extreme-looking simulated results, including Melbourne 18.13 (121) defeating Port Adelaide 3.6 (24), a **97-point margin**, alongside several low losing totals in the same round. First clarify that Sim round is **not using a separate arcade score generator**: `Season.play_round()` calls `Season.simulate()` → `MatchSim.run()`, the same possession-chain engine used by watched matches, with AI/default tactics rather than live human interventions. Existing league-balance data says drafted leagues currently produce **60+ margins about 6.7–7.8% of matches and 100+ margins about 0.2–0.5%**, versus roughly 15.5% / 1.9% in the referenced real AFL season, so one 97-point result is not by itself evidence that blowouts are too common. Audit the **distribution and causes**, not the screenshot alone: compare full-season simulated score/margin distributions with real AFL and with watched-user matches; track 0–39, 40–59, 60–79, 80–99 and 100+ margins, team scores under 40/50 and over 120/140, quarter-by-quarter runaway frequency, and whether particular tactics/form/momentum/list mismatches create implausible snowballing. Use the same drafted league states and paired seeds where possible to compare `Season.simulate()` with equivalent live/default-call matches and confirm score generation is identical when decisions are held constant. Acceptance: no hidden fast-score path diverges from MatchSim; extreme scores occur at plausible long-run rates and for understandable football reasons; simmed rounds and equivalent watched/default-call matches have matching seeded outcomes/distributions; and any fix targets the actual causal mechanism rather than globally compressing scores.
- **Autosim vs played-match injury-rate parity audit:** phone playtesting gives the impression that the user's players get injured more often when matches are autosimmed than when watched/played. Do not assume this is true; measure it. Code inspection finds **no explicit autosim injury multiplier**: both paths use `MatchSim`, `_plan_injuries()` calls the same `Injuries.roll()` with the same `BASE_CHANCE`, durability and weekly-risk modifiers, and current results always carry an `injuries` record so `Injuries.apply_match()` should not perform the legacy fallback roll a second time. However, there are two real path differences worth testing: (1) an interactively prepared user match currently uses `season.next_seed(99)` whereas a Sim-round user match uses the fixture-index seed, so the same fixture is not an injury-identical replay; and (2) injuries are planned for ground + bench but only actually occur once that player has taken part, so rotation philosophy/manual rests can change how many bench players are exposed. Run large paired tests from identical list/selection/soreness states comparing pure autosim with a live/default-call path, holding rotation policy constant, and report injuries per team-game, per player-game, initial-18 injuries, bench-player injuries, severity mix and concussion rate. Also test Normal/Hard/Ride-stars separately so participation exposure is understood. Acceptance: after controlling for players who actually took the field, autosim and played matches have statistically equivalent injury probability/severity; no result is double-rolled; any genuine difference is traced to an intentional exposure/input difference rather than hidden mode logic. If parity already holds, add a regression test and leave balance unchanged. **Status (2026-10-06):** audited; parity holds, balance unchanged ([evidence](INJURY_PARITY_2026-10-06.md)). Same fixture and seed: Sim round and a played match hurt the identical players in 900 of 900 drafted-league matches, under Normal, Rotate hard and Ride the stars alike (one extra bench exposure in 1,254 injuries under Rotate hard). The watched-match seed (`next_seed(99)`) is a different draw, not a bias (four seed schemes within one standard error). No double roll: new `test_injuries` checks that every injury landing on a list after a Sim-round week is one MatchSim recorded.

### 2026-09-30 full-season phone playtest handoff

This playtest reached the end of the 2027 season, finals, off-season and National Draft. The findings in this section are now the canonical player-observed evidence for the next work. **Do not treat every bullet as an immediate implementation request:** bugs/UX defects can be fixed directly when scoped; anything labelled audit/investigate must be measured by Claude first under the audit-ownership convention above. Prefer coherent batches and keep the P0 match-flow gate ahead of lower-risk presentation/features.

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
Evidence in `docs/TIRED_CALL_AUDIT_2026-10-05.md` (PR #230, pending merge; 288 paired matches). Trigger, feasibility, single application and determinism all hold. But **Rest and Keep produce almost the same match** (59.9% v 59.3% wins, +0.8 margin, his output after nearly equal) because a kept star is rotated off at 25 energy anyway and a rested one comes back once fresh; under Ride the stars the call fires in 88% of matches; the break restates the choice instead of reporting what followed; two card details are slightly inaccurate. **Director decision needed:** make the trade-off real, drop the call or keep it as flavour. Follow-through belongs to M4-009.

**Built (2026-10-06, PR #233 pending merge):** each answer now holds to the break: rested, the star sits out the rest of the quarter (the match in Q4) and starts the next fresh; kept, the rotations leave him on however cooked and he starts the next quarter tired. The card names who comes on and the duration; the break reports what followed. Re-measured on the same 288 matches: his output and next-quarter energy now diverge (0 v 2–3 disposals to the break; 94–98 v 38–52 energy), overall wins 58.3% v 58.9%, with resting better after a Q2 call and keeping better after a Q3 call (small sample). Evidence appended to `docs/TIRED_CALL_AUDIT_2026-10-05.md`. Phone check remains.

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

### Research refinement — 2026-10-05

**Status boundary:** the merged report remains DONE. These checks apply when M4-001/002/003/004 follow-through changes; do not rebuild or add a second report.

**Dependencies / smallest scope:** use existing MatchNotes/CoachReport and authoritative moment/contest records to explain one changed call.

**Exclusions:** more stat panels, a permanent full-report dump, generic praise or claims about an unplayed alternative.

**Acceptance:** concise lines distinguish the applied instruction, observed effect and uncertainty; negative or absent evidence cannot be rewritten as success; quiet matches remain quiet. Named events and statistics agree.

**Validation:** event-to-copy fixtures, short/contradictory samples, watch/skip consistency and phone recall of the match's people/turning point. New replay/archive work remains an unselected candidate.

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
**Status:** `TODO`  
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
**Priority:** `P1`
**Autonomy:** `SUPERVISED`
**Depends on:** §1.11 correctness/phone gate; M1-010's merged chronology; the usable M5-014 National Draft/scouting foundation and M6-004 contract/pick persistence; a verified complete roster/pick manifest. Do not require unrelated parts of those umbrella tickets to be DONE. Full academy/father-son bidding is not a dependency.

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
**Merged:** Phase 3 PR #62, former-player pathway PR #74, gameplay-effects PR #77, plus the ARD-M6-002 coaching-movement visibility/frequency audit direct-landed on 2026-10-01; teaching, tactics and man-management effects are all live.  
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


### Coach-market movement visibility / frequency audit

#### Final audit record (2026-10-01)
- Measured synthetic market: about **3.1 senior-coach changes** and **~17 total job moves per season** across 90 simulated seasons; only 1 season in 30 had no senior-coach change.
- First real 2027 offseasons checked produced 1 senior-coach change and 8–9 total job moves, confirming the underlying market was moving at a plausible rate rather than being stuck.
- The main problem was visibility: coaching items were easy to lose in the wider news feed, and user-staff departures could amount to little more than a tab badge.
- The hub now explicitly surfaces staff departures/vacancies with a path to appoint a replacement, and the off-season wrap names staff departures plus new senior coaches and whom they replaced.
- No churn-rate inflation was added merely to guarantee drama every offseason.

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

### RC-004 verification — the former player on his coach profile (2026-10-06)
**Verified, one repair (PR #234, pending merge).** The existing pathway already keeps the same person: `CoachPathway.snapshot` captures his clubs, games, goals, draft and position at retirement under his own name and alias, and the coach profile (`CoachSheet`) shows a "Playing career" section above his coaching stints; appointment news names his old club. **Missing link repaired:** only Brownlows and Colemans were carried over, though the save's honour roll also names the Rising Star, the Coaches Award winner and your club's best and fairest. The profile now lists those too ("Coaches Award", "Rising Star", "3 Adelaide best and fairests"). Other clubs' best and fairests and All-Australian selections are not kept season to season, so they are not claimed. The chance he goes into coaching still counts Brownlows and Colemans only (no balance change). Checked at 360 px; `coach_pathway` 57 checks.

## ARD-M6-003 — Board Confidence
**Status:** `PARTIAL` — the core confidence system is merged in #84; the explicitly listed smaller follow-up inputs remain optional/open.  
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
- **Player coach career after sacking:** being sacked does not immediately end the save. The player can continue their coaching career at another club if hired.
- The player gets **one second chance** after their first sacking. A subsequent sacking normally ends the coaching career.
- **Premiership reprieve:** winning a premiership earns/restores one additional sacking reprieve ("get out of jail" chance), allowing another continuation after a future sacking.
- Make remaining reprieve status and the consequence of the next sacking clear to the player; do not hide career-ending risk behind an opaque board score.

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
**Status:** `PARTIAL` — contract talks, free agency, compensation, competitive offers, free-agent sorting (#184), the trade redesign (#182 valuation, #191 current picks, #193 future picks) and real-money contracts (#198) are all on `main`; the stack PRs were closed and carried by #208. Open follow-ups are the §9.1 findings (trade value by age/potential, contract-talk frequency). _(reconciled 2026-10-05)_  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

Build toward a complete AFL list-management ecosystem.

### Real AFL money scale
**Status:** `VERIFY` — the salary/cap migration and trade integration are on `main` via #208; retain phone/save follow-up rather than rebuilding the former stack. _(reconciled 2026-10-05)_

The old 1–10 salary/cap-point economy is being replaced at the underlying system level, not merely reformatted:
- playable 2027 starts from the AFL-scale **$18.44m** club cap;
- annual salaries run from a senior floor around **$155k** through to **$1m+** elite contracts;
- first-year draftee contracts use pick-band salary anchors;
- contract/free-agent bidding moves in football-sized increments;
- trade/free-agency/compensation formulas normalise the larger units so salary does not swamp every other factor;
- old point-based saves, counters/offers and in-progress opening drafts migrate deterministically;
- UI uses compact football money such as **$650k / $1.20m / $18.44m**;
- match payments, ASAs and club profit/loss accounting remain deliberately out of scope.

Do not create a separate economy subsystem for this. It is part of ARD-M6-004; its former trade/currency stack is already merged. “Real AFL money” means simulated club salaries and caps, not real-money purchases. The game has zero microtransactions.


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

### Rival free-agency order — no first refusal by club order
**Status:** `DONE` — competing visible offers replaced the proposed club-order/reverse-ladder shortcut and merged in PR #172.

When free agency closes, rival clubs sign free agents by walking the clubs in list order (`season.lists`, i.e. `CLUB_ORDER`): each club in turn takes the best free agents it can afford until it reaches `Contracts.AI_FILL`. The clubs early in that order therefore get first refusal on the whole market. With negotiated contracts and compensation picks, that is now a fairness problem, not trivia.

Evidence (3 careers × 4 off-seasons, 2027-2030, real seasons and drafts, 816 rival signings):
- signing **counts** are spread (2-8% per club), because the early clubs fill their lists quickly;
- signing **quality** is not: **60% of each off-season's ten best free agents go to the first four clubs** in list order, and clubs from 13th in the order onwards sign **none** of them;
- mean OVR signed: Brisbane 70.2, Carlton 66.4, Collingwood 64.4 against roughly 53-57 for the clubs late in the order.

Direction: free agency must resolve competing rival interest without `CLUB_ORDER` giving any club priority. Deterministic, using only facts every club has (ladder, list, cap). No uncontrolled randomness, no special treatment for the human club, no auction or bidding system.

Proposed small fix (inside the current resolution code): rival clubs take turns in **reverse-ladder order, the national draft's order**, each turn signing the best free agent it can fit (list below `AI_FILL`, cap room for his price), one signing per turn, until no club can sign anyone. Acceptance: no correlation between a club's place in `CLUB_ORDER` and the quality of free agents it signs over a multi-season sample; same total signings as today.

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


### Research refinement — 2026-10-05

**Dependencies:** merged contract/trade/FA foundations and reconciliation of #223/#224 before overlapping valuation edits. Do not wait for unrelated media or presentation work.

**Smallest scope:** one demonstrated market exploit or missing decision pressure, measured across several years; reuse §9.1 ownership rather than opening another trade redesign.

**Exclusions:** club profit/loss expansion, MTX, psychic AI, hidden rival money, blanket harder-AI discounts or six routine negotiations every offseason.

**Acceptance:** age, current ability, realistic remaining development, role need, cap and picks create understandable competing choices; estimated/scouted upside is not guaranteed value; AI cannot be repeatedly stripped through the same exploit. Useful weak-role players can remain worth retaining. Current and future contracts/pick commitments persist.

**Validation:** reciprocal packages, young/unproven/prime/veteran assets, different club needs and cap states, save migration/in-progress offers, multi-season hold/trade-heavy/youth/veteran comparisons and Android flow. Report realised value as well as projected value. Existing autopilot evidence does not answer active-market advantage.

---



## ARD-M6-005 — Options / settings
**Status:** `DONE` — core Settings merged in #86; light/dark appearance and the safe New career action merged in PR #205. _(reconciled 2026-10-05)_  
**Merged:** PR #86 as `ebc570d`; one Settings sheet serves the menu and career hub, with relevant current options and destructive-action confirmation.  
**Priority:** `P1`  
**Autonomy:** `SAFE`

### Follow-up (2026-10-02, PR #205)
- Dark / Light is now a real persisted shared-palette choice; changing it rebuilds the current screen immediately.
- Light mode uses warm neutral paper/ink colours while club colours and the football ground remain unchanged.
- Career Settings adds **New career**. It opens setup without deleting the existing save; the existing replacement confirmation remains the destructive gate, so backing out can still resume the save.
- Delete this career retains its explicit confirmation and uses the shared danger treatment.
- **Mute sounds** persists and mutes Godot's Master audio bus, so incoming music and SFX automatically honour it.
- UI scale and reduced motion remain out until they have real systems to control.

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
- **Originally left out:** light/dark, audio, UI scale and reduced motion. PR #205 now adds light/dark and the now-relevant global Mute sounds control; UI scale and reduced motion remain out until they have real systems to control.
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
**Status:** `VERIFY` — implementation is merged; director/phone review remains.  
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


## ARD-M6-007 — Off-season wrap and new-season launch
**Status:** `DONE` — implemented in #158.  
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

## ARD-M6-008 — Post-match media conference
**Status:** `VERIFY` — the post-match media conference is on `main` (PR #183 closed, carried by #208); a phone playtest remains. _(reconciled 2026-10-05)_  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

### Intent
After a match, the coach faces the press in a short, dramatic vignette: a journalist puts a pointed question (a heavy loss, a star's poor form, an umpiring flashpoint, a selection call, a winning streak) and the player answers by choosing one of a few multiple-choice responses. What the coach says publicly can move **player morale** and **board happiness**.

### Direction
- Treat this as part of the existing club-life/event system (weekly `ClubLife` events, morale and Board Confidence, ARD-M6-003), not a parallel system: same morale/board plumbing, same consequence rules.
- Questions come from what actually happened in the match and season (margin, result run, a named player's game, injuries, ladder position, board expectation), so the conference reads as a response to this week rather than random flavour.
- Every answer is a real trade-off with a consequence the player can understand: e.g. backing an out-of-form player publicly lifts his morale but costs a little board patience if the side keeps losing; criticising the group may sting morale but satisfy a frustrated board. No answer that is simply "correct", no option that does nothing, and no hidden coefficients on the main surface.
- Show the outcome in football language afterwards (e.g. "The playing group appreciated the support", "The board wanted more accountability"), not as numbers.
- Short and skippable: a few lines, two to four answers, one tap. It must not appear after every match; it should feel like an occasion (big wins/losses, milestones, controversy), and the same question must not repeat in a short span.
- Mobile first: readable at 360-390 px, thumb-sized answers, natural Android Back.

### Guardrails
- No fake choices: every answer changes morale and/or board standing in a direction the copy promises (see the System Reality Audit's fake/no-op choice rule).
- Effects are modest and decay; the media conference cannot outweigh results, selection or coaching.
- Natural AFL language: what a coach would actually say at a press conference.

### Acceptance
- Conferences appear only after notable matches and never repeat the same question within a short span.
- Each answer has a measurable effect on morale and/or board happiness, matching its copy, verified by targeted tests.
- Skipping is always possible and has a defined, neutral outcome.
- Narrow Android portrait layouts remain usable.

### Research refinement — 2026-10-05

**Dependencies:** current ClubLife, morale/board effects, actual match/season context and phone checks. Preserve M1-011's DONE event trade-off foundation; verify M6-008's merged conference before adding content.

**Smallest scope:** improve one existing question and its answer-to-effect mapping. Use a short, pointed football question with logical consequences and room for restrained humour; keep its immediate response readable.

**Exclusions:** a new dialogue engine, personality quiz, compulsory weekly conferences, arbitrary permanent coach buffs or the unselected later-callback prototype. Do not duplicate #220/#226's backing promise/payoff.

**Acceptance:** each answer applies its promised existing effect once; costs remain understandable, skip stays neutral, named people and circumstances come from current facts, and quiet matches need no conference. Do not claim real players' private intent or let amusing wording conceal an ignored answer.

**Validation:** every answer and skip, thin/changed context, repetition suppression, saved effect state and repeat delivery; Android reading, touch and Back. Observed players should explain why the answer fits and what changed. New later callbacks require selection of RC-005 first.

---

# M7 — Competition Identity & Long Careers

Goal: make decades of play feel like a living AFL world rather than repeated isolated seasons.

## ARD-M7-001 — Rivalries
**Status:** `DONE` — established and dynamic rivalry system merged in PR #180.  
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
**Status:** `DONE` — recurring marquee-game identity merged in PR #181.  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

Existing requested feature.

Represent appropriate competition traditions such as King's Birthday and other marquee fixtures.

Presentation/identity first. Avoid arbitrary gameplay bonuses.

---

## ARD-M7-003 — Player milestones
**Status:** `PARTIAL` — career-game foundation merged in #100; the first-goal/goal-threshold expansion (closed PR #186) merged via #208. Career-high style milestones remain future work. _(reconciled 2026-10-05)_  
**Merged foundation:** PR #100 as `12aae17`; career-game milestones (50/100/150 etc.) and club-tenure context are live, while career-high style milestones remain future work.  
**Priority:** `P2`  
**Autonomy:** `SAFE` once career stats are stable

Examples:
- 100th / 200th / 300th game,
- first goal,
- career-high goals,
- notable season/career marks.

Surface lightly during matches and/or weekly flow.

Do not spam routine milestones.

### Research refinement — 2026-10-05

**Dependencies:** stable career/event facts and M7-005 records; reconcile merged #220/#221 and open #226 before touching backed-player recognition.

**Smallest scope:** only a genuinely missing milestone such as a supported career high, using existing presentation.

**Exclusions:** another promise/payoff system, repeated praise, scripted breakthroughs or milestones invented from approximate imported history.

**Acceptance:** recognition names the player and actual achievement, records it once, respects real/fictional-name preference and remains retrievable after club movement or retirement; a quiet game needs no milestone.

**Validation:** first/threshold/tie/repeat-load cases, imported versus simulated history, generated players and phone pacing. Ask whether the player remembers why this person mattered; counts of notifications are not enjoyment.

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

### Research refinement — 2026-10-05

**Dependencies:** current player identity/morale and trustworthy match-state events.

**Smallest scope:** one modest football leadership context with an observable effect.

**Exclusions:** blanket attribute boosts, automatic captain-superstar status, forced comeback stories or a new relationship subsystem.

**Acceptance:** the player understands the captain's role and its bounded limits; age/playing quality does not silently determine all leadership value; the same mechanics apply to AI clubs; captaincy transitions preserve earlier career facts.

**Validation:** equal-personnel/seed comparisons, leading/chasing/quiet contexts, persistence and Android explanation. Distinguish a measured leadership effect from a coincidental late win.

---

## ARD-M7-005 — History, records, leaders & recognition
**Status:** `PARTIAL` — History & records (closed PR #187, via #208), the coaches-award/season-honours program (#189, merged) and the awards ceremony (closed PR #185, via #208) are on `main`; the rest of this umbrella remains open. _(reconciled 2026-10-05)_  
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

### Awards ceremony implementation — 2026-10-02
**Status:** `VERIFY` — awards ceremony foundation merged via #208; native phone pacing/touch/Back verification remains. _(reconciled 2026-10-05)_
- Brownlow, Coleman, All-Australian and club best and fairest are presented over the existing Season Review, with B&F last.
- One reusable stage walk-on/medal vignette reads the actual winner and all 20 clubs' genuine colour bands; it currently reuses BroadcastVignette's silhouette figures. **These legacy figures must be replaced with the new pre-rendered 2.5D style under ARD-M8-007's complete art-style replacement requirement.** No separate scenes per club, fabricated likeness, votes or outcomes.
- All-Australian is scrollable; controls reveal immediately, finish animation, advance, or skip to the review. Replay is read-only; viewed state lives in the already-saved season_awards dictionary.
- Uses existing stored placings (including existing tiebreak order), rather than inventing shared medals or a round-by-round count. B&F currently stores three placings; does not invent fifth/fourth.
- Validation: career_ui 178 checks, save 57 checks, awards 17 checks; zero failures. Actual Godot/OpenGL portrait capture inspected at 360×800. UI regressions cover 320/360/430 widths. Phone check still required for pacing, touch and Android Back.

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

### Research refinement — 2026-10-05

**Dependencies:** Career/Season stored facts, existing milestone/award systems and M6-002 former-player links. Keep #226 backed-player payoff as its current implementation owner.

**Smallest scope:** verify continuity of one player's existing history from recruit to changed playing role, club movement, retirement and any actual coaching entry; repair a missing link/fact before adding presentation.

**Exclusions:** a second archive, generic story cards, guaranteed career arcs, fabricated relationships, duplicate praise or the unselected alumni/bookmark candidates.

**Acceptance:** stable IDs and genuine stints/honours survive decades and reload; an ageing contributor can remain remembered after losing a starting role; records never confuse another player with the same name or new guernsey. Recognise event-supported finals/dynasties without rewriting quiet seasons as dramatic ones. Where context is missing, make an earlier contribution and actual present role inspectable through existing facts, without inventing relationships.

**Validation:** transferred/retired/generated players, imported 2026 history once, repeated reload, real/fictional-name preference and existing coach-player linkage; phone retrieval and multi-season recall. Broader narrative presentation remains review-only unless already accepted elsewhere.

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
- **optional nickname / commentary short name**,
- basic bio fields already supported by the player model,
- height,
- primary position,
- optional secondary position where valid,
- archetype / play style,
- a small set of strengths and weaknesses,
- **dominant foot: Left / Right**,
- **preferred guernsey number**,
- **hair style** from a substantially expanded library, including **Bald**,
- **hair colour**,
- **facial hair** from a dedicated beard/moustache library,
- **facial-hair colour** independently selectable from hair colour,
- **skin tone**,
- **freckles: None / Light / Heavy**,
- **subtle scars: None / Light / Moderate**,
- **boots** with a small set of silhouettes/colour treatments (black, white and restrained club-colour accents),
- **sock height: Tall socks / Short socks**,
- **headband: On / Off**,
- **bandaging: None / Light / Heavy** using restrained football-appropriate placements,
- **tattoos: None / Light / Heavy** using original generic tattoo treatments rather than copied real-player or culturally specific designs.

All appearance choices are cosmetic only **except dominant foot**, which may affect football behaviour as described below. Cosmetic options must not affect ratings, role suitability, stamina, injuries, aggression, personality or any other football outcome.

### Draft integration
- The custom player enters the **first national draft class** of the career, not the opening League Draft of established AFL players.
- They go through the same draft order and AI evaluation as every other prospect.
- The user's club gets no priority access unless a future explicit father-son / academy mechanic genuinely applies.
- No guaranteed draft position.
- No guaranteed selection by the user's club.
- If undrafted, normal undrafted/carry-over rules apply.

### Generation / balance
The user's choices shape **attribute distribution**, not a guaranteed ceiling.

- Generate the player's starting football ability inside a believable draft-prospect band, with a floor high enough that the created player is at least a genuinely usable AFL role-player prospect rather than a novelty dud.
- Archetype, position, height, strengths and weaknesses redistribute that talent into a coherent football profile.
- **Potential is hidden and randomly rolled once when the career is created.** The player cannot choose it, see it exactly, or reroll it.
- Use a bounded distribution: most custom prospects should project somewhere from useful role player through good AFL player; strong/star outcomes should be uncommon; an **S-tier / generational ceiling is deliberately rare but possible**.
- The rare elite outcome must still require normal development and opportunity. High POT is not guaranteed realised ability.
- Do not grant special development speed, durability, consistency, personality, longevity or career outcomes because the player is custom.
- Preserve the roll in the save so reloads cannot fish for a better ceiling.

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
- old saves without custom-prospect data load safely,
- POT is rolled once, survives save/load, cannot be rerolled by reload, respects the usable-role-player floor and can very rarely reach the S-tier ceiling.

---

## ARD-M7-009 — Expansion clubs, Canberra toggle & Club Forge
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

### Intent
Make expansion a major long-career option rather than a background database event. Tasmania remains the grounded 19th club, Canberra is an optional 20th club, and the player may create one additional bespoke club that joins the competition as a 21st side.

### New Career expansion setup
Keep the ordinary New Career flow concise.

- **Tasmania:** scheduled to enter in 2028.
- **Canberra:** optional career toggle, **off by default**, scheduled to enter in 2030 when enabled.
- Persist the Canberra choice at career creation because draft capital, list building, staff, fixtures and future-pick ownership need to prepare before entry.
- Do not allow a mid-save Canberra toggle after expansion preparation has begun.
- A created-club career adds the custom club as a new competition member rather than replacing an existing club.

### Existing-player chronology before expansion
Tasmania and Canberra enter years after the 2027 career baseline. By the time either club enters, **every existing AFL player must have reached that season through the normal career simulation**.

- Do not load a frozen 2027 roster into a 2028/2030 expansion state and then merely add years to displayed ages.
- Age, development, decline, injuries, contracts, trades, free agency, awards, club movement and career history must all reflect the seasons actually simulated before expansion.
- Retirements, delistings, list turnover and replacement-generation need a robust lifecycle that preserves believable league population and career provenance. The exact retirement/delisting implementation is an engineering/design task for Claude when this item is actioned; do not fake continuity with silent respawns or retroactive history.
- Expansion list building must draw from the league state that genuinely exists at the expansion date.
- Long-save validation must prove that players present in 2028/2030 have coherent ages, histories and club stints, and that retired/delisted players are not resurrected accidentally.

### Real-expansion draft model
Use the AFL's confirmed Tasmania list-establishment package as the authenticity baseline rather than inventing a weak generic expansion draft.

For Tasmania:
- 2027 National Draft: picks **1, 3, 5, 7, 9, 11 and 13**, plus the first selection of each subsequent round.
- Picks **5, 7, 11 and 13** are trade-required/rollable according to the real concession concept.
- 2028: concession picks **5 and 9** plus the first selection of each subsequent round and the natural hand; pick 5 is trade-required/rollable.
- 2029: concession picks **5 and 9** plus the natural hand; pick 5 is trade-required.
- Where practical, later expansion work may also model the real package's mature-player access, rookie priorities and other list-building concessions, but first-round capital and real trade ownership are the minimum accepted foundation.

For Canberra:
- There is no confirmed real AFL Canberra expansion package to reproduce, so use the **same design philosophy as Tasmania**: heavy premium draft capital beginning before entry, spread across multiple drafts, with some premium selections required to be traded so the club must mix elite youth with established talent.
- Tune the exact Canberra pick schedule against the game's entry year, draft order and competitive balance rather than pretending a fictional package is an AFL rule.
- AI-controlled Canberra receives exactly the same concessions as a user-controlled Canberra.

Expansion picks must be real persistent tradable assets in the normal trade/draft system. Do not fake concessions as hidden list-strength boosts or spawn a strong list without provenance.

### Main-menu creation destination — Club Forge
Add a bespoke main-menu destination named **Club Forge** as the current working title.

Club Forge is the home for:
1. **Create a club**
2. **Create a player**

It should feel purpose-built rather than like a debug/settings form, while remaining mobile-first and restrained.

### Create a club
Allow one custom club per career in V1.

Player-facing customisation should include, at minimum:
- club name,
- short name / abbreviation,
- **home location chosen from a researched Australian football location library**,
- primary / secondary / accent colours,
- guernsey design using the existing procedural guernsey system,
- shorts / socks where supported,
- simple badge/marker identity built from the same visual language as existing club markers rather than imported trademarked logos.

Do not turn V1 into a full vector-logo editor or stadium builder.

#### Location library — real football geography first
The location picker should not be a generic list of capital cities. Offer major suburbs, regional centres and football towns that do not already have an AFL club representing that exact place. Prefer locations with an established state-league / second-tier football identity when one exists.

Minimum curated coverage should include candidates such as:

- **Victoria:** Port Melbourne, Williamstown, Werribee, Frankston, Sandringham, Coburg and other major VFL/VFA football centres not already represented by an AFL club.
- **New South Wales:** Newcastle, Wollongong/Illawarra, North Shore and other major Sydney/NSW football centres without an AFL club of their own.
- **Queensland:** Southport, Broadbeach, Sunshine Coast/Maroochydore, Cairns and other established QAFL/Queensland football centres outside the existing Brisbane Lions and Gold Coast Suns identities.
- **South Australia:** Norwood, Glenelg, Sturt/Unley, Central District/Elizabeth, South Adelaide/Noarlunga and other established SANFL centres distinct from Adelaide and Port Adelaide.
- **Western Australia:** Peel/Mandurah, Claremont, Subiaco, East Perth, West Perth/Joondalup, Swan Districts/Bassendean and other WAFL centres distinct from Fremantle and West Coast.
- **Tasmania:** Launceston, North Hobart/Hobart-region heritage centres, Devonport and Burnie where appropriate, while respecting the scheduled statewide Tasmania AFL club.
- **ACT:** if the optional Canberra AFL club is enabled, avoid presenting a second generic 'Canberra' identity; use genuine local football districts such as Ainslie, Belconnen, Gungahlin, Tuggeranong, Weston Creek or Eastlake/Kingston where appropriate.
- **Northern Territory:** **Darwin** and **Alice Springs** are mandatory choices. Additional NT football centres may be added where venue/list support is strong.

Examples above are a seed list, not a hard-coded final catalogue. Claude should build the library from researched competition/club data and keep it data-driven so more places can be added without rewriting the creator UI.

Where an existing lower-league club provides useful authenticity (for example **Southport, Norwood, Peel, Williamstown, Werribee, Port Melbourne, Claremont**), use its location, football history, colours/pattern vocabulary and home venue as research input. **Do not ship protected club logos, exact trademarks or unlicensed branded assets merely because the real club informed the preset.** Existing club names/nicknames should only be shipped verbatim if the project is comfortable with the licensing/trademark position; otherwise use the place and football tradition as inspiration while keeping the user's club name editable.

#### Home grounds — researched venue mapping
Each location preset should propose a real Australian-rules football ground wherever a credible venue exists.

Store a stable/common venue identity separately from a changeable sponsorship name where possible, so saves do not become wrong every time naming rights change.

Research anchors already confirmed for implementation include:
- **Norwood:** Norwood Oval / current Coopers Stadium.
- **Peel/Mandurah:** Rushton Park / current Lane Group Stadium.
- **Southport:** Fankhauser Reserve.
- **Port Melbourne:** North Port Oval / current ETU Stadium.
- **Williamstown:** Point Gellibrand Oval / current DSV Stadium.
- **Werribee:** Chirnside Park / current Melbourne Avalon Airport Oval.
- **Alice Springs:** Traeger Park (also presented as TIO Traeger Park in AFLNT material).
- **Darwin:** TIO Stadium as the major venue, with AFLNT also using Gardens Oval, Nightcliff Oval and other genuine NTFL grounds.
- **Canberra districts:** use researched local grounds such as Alan Ray Oval (Ainslie), Aranda Oval (Belconnen), Kingston Oval (Eastlake), Amaroo Oval (Gungahlin), Isabella Oval (Tuggeranong) and Stirling Oval (Weston Creek) where the selected district maps naturally.

Do not invent a stadium where a real football oval exists. If a region has several plausible grounds, offer a small venue choice rather than pretending one is canonical.

#### Guernsey creator — state-league depth
Expand the procedural guernsey system using researched VFL/VFA, SANFL, WAFL, QAFL, NTFL and Tasmanian football design language rather than only AFL templates.

The point is **more construction vocabulary**, not copying protected artwork. Research traditional/home strips and encode reusable primitives such as:
- plain body + trim,
- vertical stripes of configurable count/width,
- hoops,
- sash / reverse sash,
- yoke,
- chest band,
- V / chevron and stacked chevrons,
- side panels,
- shoulder panels,
- central panel / contrasting back,
- split / half-and-half body,
- monogram/letter-zone placeholder where legally safe,
- contrasting cuffs/collar,
- sock hoops/bands,
- independent shorts colour,
- optional heritage-style narrow stripes or broad bars.

Use real second-tier clubs as pattern references. Confirmed research examples include:
- **Norwood:** traditional navy guernsey with red trim and red socks; the club itself documents those colours.
- **Peel Thunder:** teal and navy are the club's documented colours.
- **Williamstown:** royal blue and gold.
- **Werribee:** black and gold.
- **Port Melbourne:** long-standing red/blue identity; North Port Oval is its home.
- **Claremont:** navy and old gold.
- SANFL/VFL/WAFL clubs collectively provide strong references for stripes, hoops, sashes, yokes, bands, chevrons and contrasting trim; Claude should complete a sourced pattern audit before implementing new primitives.

First Nations and commemorative guernseys are useful **research for how clubs layer story and geometry**, but their artwork must not be copied into a generic creator. Indigenous artwork is culturally specific, artist-owned work: do not turn it into a selectable decorative pattern unless an original/licensed design is created for the game.

#### Data model
Keep the creator data-driven:
- location id,
- display place,
- state/territory,
- optional football-region label,
- canonical ground name,
- current/sponsor ground alias where useful,
- latitude/longitude only if later venue/weather systems need them,
- researched colour/pattern inspiration tags,
- optional lower-league heritage reference kept as internal/source metadata rather than necessarily player-facing branding.

This library should be reusable by create-a-club, venue presentation, weather/ground dimensions and future generated-club features.

The created club:
- is an **additional competition member**, never a reskin/replacement of an existing club;
- participates in the same salary cap, list size, contracts, draft, trades, free agency, coaching, injuries, suspensions, development and AI rules;
- gets an expansion-list establishment package comparable in opportunity to the other expansion clubs, with balance measured rather than guaranteed dominance;
- stores its identity and colours in save data so every ladder, fixture, match, report, guernsey, history and long-career record uses the created identity consistently;
- remains valid after reload and across decades of history.

### Create a player
Move/route ARD-M7-008 through Club Forge so character creation and club creation share one bespoke creative destination.

The player creator should expose identity/aesthetic and football-profile choices without exposing exact OVR/POT. Its hidden one-time POT roll, usable-role-player floor and rare S-tier outcome remain owned by ARD-M7-008.

Appearance customisation should include:
- **Hair style** from a much larger library,
- **Bald** as a proper explicit hair option rather than a missing-texture/default state,
- **Hair colour**,
- **Facial hair** from a dedicated beard/moustache library,
- **Facial-hair colour**, independently selectable,
- **Skin tone**,
- **Freckles None / Light / Heavy**,
- **Scars None / Light / Moderate**, kept subtle and believable,
- **Boots** with a compact set of silhouettes and colour treatments,
- **Tall socks / Short socks**,
- **Headband On / Off**,
- **Bandaging None / Light / Heavy**,
- **Tattoos None / Light / Heavy**.

Persist these on the player and use them consistently anywhere visible: creator preview, match figures, vignettes and future portrait/full-body presentation.

These are cosmetic only. They should also be available to generated-player appearance variation where practical so the league does not look uniform. Hair and facial-hair colour may differ occasionally for generated players within a believable natural range.

### Hair / facial-hair library
Expand beyond a token set of cuts. The target should include enough silhouettes that players are recognisable at a glance even at vignette scale.

Hair should cover a useful range such as:
- bald / shaved,
- very short buzz,
- short crop,
- crew cut,
- side part,
- textured short,
- messy medium,
- longer swept-back,
- mullet variants,
- curly/coily short,
- curly/coily medium,
- afro-style volume where supported by the art pipeline,
- long hair / tied-back variants where supported.

Facial hair should be independently selectable where the face/figure resolution supports it:
- clean shaven,
- light stubble,
- heavy stubble,
- moustache,
- short beard,
- full beard,
- goatee / chin beard,
- beard + moustache combinations.

Do not tie beard availability to hairstyle. Hair colour and facial-hair colour should usually harmonise but do not need to be identical in every generated case.

### Appearance variation guardrails
- Headbands should sit naturally with the hairstyle/figure rather than float as an overlay.
- Hair/headband combinations need compatibility rules so bald/shaved and bulky styles do not clip.
- Beards/moustaches must not obscure player numbers, guernsey details or facial readability in close-up vignettes.
- Bandages should use believable football placements such as shoulder/upper arm, wrist/forearm, thigh/knee or lower leg; avoid covering every limb at once unless a deliberately rare heavy preset is selected.
- Tattoos should be **original generic designs**. Do not copy a real player's identifiable tattoo layout, Indigenous artwork, gang symbols, extremist imagery, copyrighted characters/logos or other protected/sensitive designs.
- Use multiple tattoo placements/pattern families so "tattoos on" does not make every player look identical.
- Appearance traits should remain visually legible at vignette scale without becoming noisy or overpowering the guernsey.


### Dominant foot, number and nickname
**Dominant foot** is the one creator choice here that can have modest football meaning.

- Left/right foot should influence preferred kicking side, body orientation and appropriate vignette/animation facing where the presentation supports it.
- It may slightly influence which side a player naturally opens the ground from, but must **not** become a hidden global accuracy bonus or make one foot objectively better.
- Weak-foot use should remain possible; do not hard-lock players from ordinary AFL actions.
- AI/generated players should also have a dominant foot so the system is not a user-only gimmick.

**Preferred guernsey number**:
- allow the user to nominate a number for the custom player,
- if unavailable at the club that drafts/signs him, resolve the conflict transparently using the club's normal numbering rules,
- preserve the preference so the player can receive it later if it becomes available where practical,
- never duplicate active squad numbers.

**Nickname / commentary short name**:
- optional field for a custom player,
- useful for long surnames or personal flavour,
- may appear in commentary/vignettes where natural,
- must not replace the legal/display surname in records, awards, history or contracts,
- generated players do not require nicknames by default.



### 21-club fixture support
A created club may take the competition to **21 clubs**.

- The fixture generator must support odd club counts cleanly.
- Every club must receive an equal number of home-and-away matches.
- Use a fair rotating bye structure; do not give the custom/user club a scheduling advantage.
- Expanding the calendar beyond the current fixture length is allowed if required to keep equal games, sensible opponent coverage and clean bye rotation.
- Revisit finals qualification and wildcard presentation only if the larger league makes the existing structure materially unfair; do not automatically add more finals teams just because the league grew.
- Validate season rollover, draft order, ladder percentages/points, awards, contracts, fatigue and long-save performance with 19, 20 and 21 clubs.

### UX guardrails
- Main menu remains clean: Club Forge is one deliberate destination, not several creator buttons.
- New Career should summarise expansion choices without number-vomit.
- Creation must work comfortably in narrow portrait layouts.
- Colour/guernsey controls should be tap-friendly; avoid dropdown-heavy forms.
- Show enough preview to understand the club/player being created without telling the user the optimal football build.

### Tests
- Canberra off: career remains valid with Tasmania and no ghost Canberra data.
- Canberra on: expansion preparation, entry, draft assets and fixtures survive save/reload.
- Players reaching 2028/2030 have naturally evolved ages, histories and list states rather than frozen-start data with adjusted labels.
- Retirement/delisting/list-turnover handling does not resurrect players or corrupt career history.
- Created club is unique, persists through reload and uses its identity everywhere.
- 19-, 20- and 21-club fixtures give every club equal games and fair byes.
- Custom club obeys the same cap/list/contract/trade/draft/coaching rules as AI clubs.
- Long-run simulation reaches multiple post-expansion seasons without fixture, draft-order, history or save corruption.

---

## ARD-M7-010 — Sir Doug Nicholls Round & Indigenous guernsey library
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

### Intent
Make Sir Doug Nicholls Round a genuine annual competition event, not a cosmetic text label. The round should celebrate Aboriginal and Torres Strait Islander football culture through researched club-specific presentation, special guernseys and matchday visuals while treating the artwork, artists and cultural stories with care.

The implementation should reflect the real AFL model: all clubs wear specifically designed Indigenous guernseys for Sir Doug Nicholls Round, with the real competition treating those guernseys as storytelling pieces created in collaboration with Aboriginal and Torres Strait Islander artists. Since 2014, all AFL clubs have worn dedicated designs for the round; recent editions run across two rounds.

### Extensive research requirement
Before implementation, Claude must perform a **club-by-club historical design audit** covering, where source material is available, every AFL Sir Doug Nicholls / Indigenous Round guernsey from **2014 onward**, plus selected AFLW, VFL/VFLW, SANFL, WAFL, QAFL, NTFL and Tasmanian examples where they materially expand the design vocabulary.

For each researched design, record:
- club and season,
- artist/designer name,
- artist's Nation/community where publicly stated,
- whether a current/former player or family member was involved,
- the story/theme explicitly published by the club/AFL,
- base club colours retained or changed,
- major layout structure,
- reusable geometric/presentation ideas,
- which elements are culturally specific and **must not be copied**,
- source URL / provenance.

Start from official AFL/club sources wherever possible. The AFL's Sir Doug Nicholls Round guernsey galleries, annual all-club roundups and club reveal articles are preferred over fan recreations or merchandise photos without story/provenance.

### Cultural and IP guardrails
Treat the research primarily as **visual-style and design-language study**, not as a source of specific artwork or stories to reproduce.

Claude should learn from the broad visual vocabulary across many Indigenous guernseys — composition, flow, layering, connected forms, asymmetry, curved and concentric geometry, integration with club colours, and the way traditional football structures such as sashes, hoops, panels and yokes are reinterpreted — then create **new original designs** from that learned design language.

- Do not copy, trace or closely reconstruct any real artist's guernsey artwork.
- Do not lift a specific club design and merely recolour or rearrange it.
- Do not reuse Dreaming stories, clan-specific symbols, sacred/culturally restricted imagery or an artist's distinctive composition.
- Do not invent cultural narratives, Nations, symbolism or "meaning" for the game's fictional designs. **The designs do not need lore attached to them.**
- Preserve artist/source attribution in the research record so Claude knows what it studied, even though the shipped design should be original.
- If the project ever ships an exact real-world Sir Doug Nicholls guernsey, obtain the necessary club/artist rights first.
- The default game should use **original, club-specific fictional Indigenous-round guernseys** informed by the broad art style and football-design traditions found in the research, without pretending those designs represent a real community, artist or story.
- Prefer a future collaboration/commission with Aboriginal and Torres Strait Islander artists for a final commercial art pass if practical, but this is not required for prototyping the original in-game style.

### Per-club design depth
Target **5–10 unique Indigenous-round guernseys per club** over time.

For the existing AFL clubs:
- each club gets a rotating library rather than one permanent special strip;
- designs should still read immediately as that club through colour hierarchy, silhouette and recurring club identity;
- avoid simply recolouring the normal home guernsey with dots;
- vary composition meaningfully: pathway/connection structures, meeting-place geometry, river/land-flow layouts, animal/totem-inspired *abstract* structure only where a fictional/original treatment is culturally safe, layered bands, mapped-country-style flow, concentric community structures, side panels, yokes, sashes, hoops/stripes transformed into connected organic systems, etc.;
- no design should claim a real cultural story unless it is licensed from the people who own that story.

Tasmania and optional Canberra should also receive their own researched/original pools once they enter the competition.

For a user-created club:
- provide a small pool of **original fictional Indigenous-round templates** using the same culturally safe design system;
- the user may choose colours and broad composition but should not be asked to invent an Aboriginal story, Nation or sacred symbolism;
- the custom-club design must not borrow exact artwork from an existing real club.

### Seasonal rotation
- Assign each club one Indigenous-round guernsey from its library for that season.
- Rotate with enough memory that the same design does not appear every year.
- Historical/recent designs may be weighted toward club identity, but no one pattern should dominate indefinitely.
- Store the selected season design in the save so reloading cannot change it.
- Long careers should cycle through the library naturally; once exhausted, reuse after a sensible gap unless new designs have been added.

### Sir Doug Nicholls Round scheduling
Implement a designated **Sir Doug Nicholls Round window** in the fixture, modelled on the modern AFL's two-round celebration.

Core rule:
- each club wears its Indigenous-round guernsey for its designated Sir Doug Nicholls match;
- if a club has a **bye in the designated round**, that club wears its special guernsey in **its following match/round instead**;
- in that catch-up match, the opponent **does not** automatically wear its Indigenous-round guernsey unless that opponent also missed its own designated match because of a bye;
- therefore the guernsey state is tracked **per club**, not as a global "everyone this round" renderer switch;
- a club wears the season's special guernsey exactly once for its designated/catch-up appearance unless a future explicit rule says otherwise.

With odd-club competitions (19 or 21 clubs), the bye/catch-up logic is mandatory and must remain deterministic.

### Match and vignette presentation
For the club's actual Sir Doug Nicholls appearance:
- all match vignettes, pre-match figures, close-ups and other player-facing kit renderers must use that club's selected Indigenous-round guernsey;
- the normal home/away/clash readability rules still apply;
- if both clubs are wearing special guernseys, resolve contrast using dedicated Indigenous home/clash variants where available or a restrained alternate treatment;
- after that club's Sir Doug Nicholls appearance, immediately return to normal season guernseys for later matches.

The vignette system must read the **actual match kit assignment**, not independently guess from the calendar. This prevents a player from appearing in the special strip in a normal match or vice versa.

### Round presentation
Keep presentation meaningful but not exploitative:
- clearly label Sir Doug Nicholls Round in fixture/match presentation;
- provide concise, factual educational context about Sir Doug Nicholls and the round;
- where a design is an original fictional game design, say so rather than attaching a fabricated artist/story;
- where licensed real artwork is ever added, display the artist/story attribution prominently and accurately;
- avoid gamified rewards, stat buffs or arbitrary morale bonuses for the round.

Optional later presentation may include special ball/umpire visual treatment if it can be implemented from licensed/original artwork and does not distract from the core guernsey work.

### Data / implementation shape
Create a data-driven guernsey catalogue rather than hard-coded season checks.

Suggested fields:
- design id,
- club code,
- variant type (home / clash / alternate),
- colour mapping,
- procedural pattern primitives / texture reference,
- source/inspiration metadata,
- real-vs-original flag,
- artist attribution where applicable,
- season eligibility,
- copyright/licensing state,
- cultural-review state.

The normal match-kit resolver should receive the seasonal Sir Doug Nicholls assignment and choose the correct visual variant.

### Acceptance
- every active club has at least five distinct Indigenous-round designs available before the feature is marked complete; target 5–10 each,
- every design has provenance/research notes and no unlicensed artwork is shipped accidentally,
- the same club remains visually recognisable across its different special guernseys,
- the special kit is visible in the actual match/vignette presentation and nowhere else,
- bye clubs correctly defer their special kit to their next match without forcing the opponent into one,
- 19-, 20- and 21-club fixtures all handle the rule,
- save/reload preserves the year's design choice and whether the club has already worn it,
- long careers rotate designs instead of showing the same one annually.

### Validation
Test:
- normal two-club Sir Doug Nicholls match,
- one club coming off a bye,
- both clubs coming off byes,
- a club with no bye,
- 19/20/21-club seasons,
- home/away/clash contrast,
- watched match and simulated match,
- every vignette/figure renderer,
- save before round → reload → play,
- save after one club has worn its strip but before another bye club's catch-up,
- multiple seasons of rotation with no accidental annual reroll.

Phone-review at narrow Android widths and visually inspect a representative sample from every club before marking complete.

---

## ARD-M7-011 — AFL knowledge layer: fun facts, records & player stories
**Status:** `TODO`  
**Priority:** `P3`  
**Autonomy:** `SUPERVISED`

### Intent
Investigate low-friction places where the game can teach the player about Australian football history, quirks, records and notable real-player achievements **without turning the UI into trivia spam or a textbook**.

This is deliberately speculative. Claude should first audit the current game flow and propose the smallest set of placements that feel natural, then implement only if the additions clearly improve flavour/understanding without slowing play.

### Research scope
Build a sourced pool of short factual material covering:
- AFL/VFL records and historical milestones,
- unusual rules/history of the competition,
- famous finals/Grand Finals and landmark matches,
- club records and long-standing rivalries,
- notable draft/trade/free-agency stories where the facts are stable and appropriate,
- real-player career achievements for players already present in the game's data,
- positional/statistical curiosities that help explain football concepts,
- venue/history facts tied to grounds already used in-game,
- Sir Doug Nicholls Round / Indigenous football history where appropriate and carefully sourced,
- expansion/history context relevant to Tasmania and other future league changes.

Prefer official AFL, club, Hall of Fame, state-league and other high-quality historical sources.

### Candidate surfaces to investigate
Claude should inspect the current UX and recommend where these can appear **organically**.

**Primary candidate: the existing news feed.** Enrich normal football stories with historical/statistical context only when the current save creates a reason to mention it.

Secondary possibilities:
- season review,
- player profiles,
- career-history / records pages,
- fixture/marquee-round presentation,
- venue presentation,
- achievement unlocks,
- rare post-match cards when a current player matches or breaks a historical mark,
- onboarding/help moments where a fact directly explains a real AFL concept.

Loading screens, halftime and other dead-time trivia are lower priority because they are more likely to feel bolted on.

Do **not** add a permanent scrolling trivia feed, encyclopaedia dump or disconnected "fun fact" carousel merely to expose the research.

### Real-player stories
For real AFL players already represented in the game, allow concise factual callouts such as:
- debut / games / goals milestones,
- premierships,
- Brownlows / Colemans / All-Australians / club awards,
- notable draft origin or club history,
- famous records or one-off achievements,
- unusual career paths.

Rules:
- keep these factual and sourced;
- avoid speculative personality claims, private-life gossip or sensationalism;
- do not fabricate quotes;
- do not overstate disputed stories;
- where a fact can date quickly, store the source/date and avoid presenting stale copy as timeless truth.

### Dynamic use
The strongest version of this feature should connect facts to what the player is already doing **through existing game surfaces**, especially the news feed, rather than creating a separate trivia destination.

Preferred pattern: turn historical/statistical context into an actual piece of football news generated by the save.

Examples:
- **"Essendon has won its first final in X days."** when the save genuinely ends a finals drought;
- a player reaches 300 games → the news item notes the milestone and relevant historical context;
- a forward kicks 10 → the match/news recap notes how rare the feat is or where it sits against known records;
- a club ends a long premiership drought → the premiership story states the exact drought length;
- a team records its biggest win / highest score / lowest score in decades → report it as part of the result story;
- a match is at a historically notable ground → use one concise venue fact only when that venue is already being discussed;
- a current real player reaches an achievement already known in the database → surface it naturally in profile/history/news;
- a created/custom player breaks a real competition record → the news feed can frame it against the previous historical benchmark.

The **news feed should be the primary candidate surface** because it already exists to explain what happened in the football world. Historical facts should make those stories richer, not behave like detached Wikipedia snippets.

This should make the save feel connected to AFL history while preserving the fiction that the player is reading the living football world around their career.

### Achievements
Investigate whether some facts should be attached to achievements/trophies.

Examples:
- win a premiership with a club after an historically long drought,
- break a famous individual season/career record,
- coach a player past a major games/goals milestone,
- complete unusual but authentic football feats.

Achievements should celebrate play, not become the only place historical context exists.

### Presentation guardrails
- **One useful fact at a time.**
- Prefer 1–2 concise sentences.
- No number-vomit.
- No repeated fact every week.
- Track seen/recently-shown IDs so repetition is controlled.
- Facts should never delay a critical interaction.
- Player can dismiss/skip immediately.
- Avoid "Did you know?" copy everywhere; write in natural football language.
- Do not tell the player the optimal move.
- Keep Australian spelling/terminology.

### Data / provenance
Use a data-driven fact library with fields such as:
- fact id,
- category,
- relevant club/player/venue/rule/era tags,
- text,
- source,
- source date,
- confidence/verification state,
- eligible surfaces,
- trigger conditions,
- repeat cooldown,
- historical/current flag.

Facts about real players should key to stable player IDs rather than names alone.

### Veracity standard — footyhead-proof or don't ship it
Claude must be **certain of the factual accuracy** of any real-world historical/statistical claim before it appears in-game.

A knowledgeable AFL supporter will notice a wrong finals drought, record, milestone, venue fact, draft fact or player achievement immediately, and one bad claim damages trust in the whole system.

Rules:
- Prefer primary/authoritative sources: AFL, official club history, Australian Football Hall of Fame, state-league bodies, official venue/history records.
- Where a claim is non-trivial, disputed, depends on VFL/AFL continuity, or could be interpreted multiple ways, verify it against **at least two strong independent sources** before shipping.
- Record the exact basis of ambiguous counts such as "days since", "first since", "longest drought", "AFL era" versus VFL/AFL history, home-and-away versus finals, and club relocations/renames.
- Do not round, simplify or rewrite a statistic in a way that changes its meaning.
- If reliable sources disagree, do not guess. Either omit the fact, qualify it clearly, or leave it out of the player-facing game.
- Time-sensitive facts must be sourced to a clear cutoff date and should not be treated as timeless if later real-world results could make them stale.
- Dynamic claims generated from the save should be calculated from stored game history where possible, with real-world history used only as the baseline.
- Every shipped fact should have enough provenance that Claude or a future maintainer can audit why the game believes it is true.

The quality bar is: **if a true footyhead checks it, the fact should hold up.**

### Acceptance
This item only earns implementation if Claude's audit identifies placements that:
- do not slow the weekly loop,
- add genuine AFL flavour or understanding,
- remain readable on phone,
- avoid repeated trivia spam,
- connect naturally to the player's current match/career state.

### Validation
Prototype a small sourced set first (for example 30–50 facts across players, clubs, venues and records) and test:
- repeat suppression,
- relevance of triggered facts,
- phone readability,
- save/load seen-state,
- current-player ID mapping,
- no stale/incorrect facts after season progression,
- no interference with match/draft input.

If the prototype feels bolted-on, leave the system deferred rather than forcing it into the game.

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
**Status:** `DONE` — the minimal main menu exists and the one-time Hub weekly-loop onboarding merged in PR #208. _(reconciled 2026-10-05)_  
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

### Research refinement — 2026-10-05

**Dependencies:** current save/season lifecycle, player generation/development, Contracts/Draft and Career/CoachPathway; add M5-016 opening-mode coverage when implemented, not as a prerequisite for all QA.

**Smallest scope:** reproducible 5/10/20-year careers across contrasting club strengths and management policies before a longer integrity soak; preserve the existing 100+ year goal without rerunning it after every small change.

**Exclusions:** using simulation as proof of enjoyment, forcing dynasty turnover, universal win-rate targets or hidden balance assistance.

**Acceptance:** identity, ages, role histories, club stints, contracts/picks, honours and existing former-player links remain coherent; old saves load; no duplicate history, roster dead ends or unchecked stat/potential inflation; AI can sustain viable lists across generations. Save growth/loading and sim cost remain acceptable on the target phone.

**Validation:** record commit, seeds, starting clubs, policies, failures and distributions; compare low-admin, hold, youth, veteran and trade-heavy careers. Trace individuals through changing jobs, retirement and actual coaching links. Pair with observed multi-season follow-up on difficult decisions, remembered people and desire to continue.

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
**Status:** `VERIFY` — the prototype/broadcast-vignette foundation is merged (#153); phone playtest still decides whether the vignette library earns expansion.  
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
- Vignette participants must come from MatchSim's authoritative participant selection for that event (for centre bounces, the same ruck contestant and centre-bounce attendees), not a separate presentation-only reconstruction from generic position slots.
- Do not introduce 3D player models, 3D stadium presentation or continuous 3D match recreation.
- Do not build hundreds of unique scenes.
- Tactical readability matters more than graphical fidelity.
- Preserve club colours and player identity where useful without requiring licensed likenesses.
- Player identity includes credible visual diversity: never default every vignette player to the same white/light-skinned appearance. Use appearance data for rendering rather than racial/ethnic gameplay categories or name-based inference.
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

### Figures (2026-10-05)
On the director's direction, the drawn stick figures became pre-rendered 2.5D footballers - still 2D in the game, no 3D models.
- **What:** one sprite sheet (`assets/vignette/figures_*.png`) of rigged footballers rendered offline from a front and a back camera pitched like the vignette's: an average build (midfielders, umpire) and a taller ruck build; idle, jog, ruck leap and the umpire's bounce. `figure.gdshader` recolours them per club at draw time, so one sheet serves all 20 clubs; your players show their numbers. `VignetteFigures.gd` (generated) holds the layout.
- **Where they come from:** the separate `ard-asset-pipeline` repo (`build_vignette_figures.sh --install`), from a CC0 MPFB body; rebuilding reproduces the sheet exactly.
- **Unchanged:** the camera, beats, positions, who is shown and MatchSim's authority. The pre-match scene uses the same figures.
- **Appearance:** each figure wears its player's skin tone and hair colour (`GameDB.player_looks`); see the "Vignette player representation / appearance bug" item for how the data is curated.
- **Guernsey designs:** each club's home kit is a row in `data/clubs.csv` ("guernsey": `<design>:<base>/<pattern>/<pattern 2>[/<shorts>]`, each colour p, s or a - the club's primary, secondary or accent - or a written-out `#RRGGBB`; e.g. Richmond `sash:s/p/a`, Port Adelaide `chevron:s/#FFFFFF/p`). Designs: plain, stripes, hoops, sash, yoke, band, chevrons, panels, chevron, sides, tiers, shoulders, map. The shader draws the design from where each pixel sits on the guernsey; socks take the base colour with a band in the pattern colour; back numbers are edged in the base colour so they read across stripes. Shorts left out are the secondary colour, a shade darker. Club emblems on the guernsey (the GWS "G", the Eagles' eagle) are not drawn. `tools/visual/capture_guernseys.gd` shows every club, front and back (`--scale`, `--clubs`). Brisbane, Gold Coast, GWS, Port Adelaide and West Coast follow the director's reference images; Tasmania wears its 2024 foundation guernsey (`map:p/s/a/p`: myrtle green, the primrose map of Tasmania on the chest with a rose-red T, green shorts); Canberra (an expansion club) has none. Every club's shorts are set, from its home kit: navy for Adelaide, Carlton, Geelong and Melbourne; black for Collingwood, Essendon, Port Adelaide, Richmond and St Kilda; maroon for Brisbane, red for Gold Coast and Sydney, purple for Fremantle, charcoal for GWS, brown for Hawthorn, blue for North Melbourne, West Coast and the Bulldogs, green for Tasmania; Canberra in its navy.
- **Tests:** `_bounce_close_up` checks the figures wear both clubs' colours and the sheet holds every move the scene plays.

### Complete vignette art-style replacement — director requirement, 2026-10-05

**Status:** `TODO` — required migration; the centre-bounce and pre-match conversion does not complete this work.

**Direction:** entirely replace the old vignette art style with the new pre-rendered 2.5D footballer style described above. This applies to every existing vignette and cinematic sequence, including tactical/match moments, broadcast sequences, pre-match scenes and awards/medal walk-ons. No old stick-figure or silhouette-style vignette may remain in the player-facing game.

**Scope:** inventory every vignette renderer, scene, animation and fallback that still uses the old style. Migrate all of them to the shared new figure assets and rendering approach, extending poses or animations where a sequence needs them. Preserve each scene's purpose, pacing, authoritative participants, club guernseys, player numbers and appearance data. Replace the awards ceremony's legacy BroadcastVignette silhouette figures as part of this work. Retire obsolete rendering paths and unused assets once their replacements are verified.

**Acceptance:** the inventory accounts for every existing vignette/sequence and each entry has been migrated and visually checked; no reachable scene or fallback displays the old art style. All scenes consistently use the new style, including awards and less frequent match moments. This is replacement of existing presentation, not approval to expand the vignette library.

**Validation:** deliberately reach or capture every sequence and relevant fallback, compare phone-sized stills and motion, and check transitions, club colours, player appearance and pose coverage. Verify phone performance, skip/touch/Back behaviour and unchanged football outcomes. Obtain director visual review before marking the migration complete; record any untested sequence as outstanding.

### Acceptance test
The feature earns further work only if a phone playtest shows that the player can explain **why the decision is being asked**, form a reasonable expectation before choosing, and finds the moment materially more engaging than the normal presentation.

### Research refinement — 2026-10-05

**Dependencies / status boundary:** keep VERIFY and the §1.11 gate. The merged centre-bounce prototype is the current owner; no new library is authorised by this research.

**Smallest scope:** test the existing scene against its authoritative participants, frozen state, choice and resumed events.

**Exclusions:** 3D, narrative event cards, fabricated movement implying an unapplied tactic or a separate outcome model.

**Acceptance:** viewers can see the football opportunity and trade-off; skip and watch preserve the same choice/resolution; repeated entry/Back does not duplicate or drop a call; positive and negative outcomes both return cleanly to the oval.

**Validation:** participant/event agreement, quiet/invalid contexts, 320/360/430-width review plus native Android touch, pacing, load time and performance. Expansion requires the director's phone finding that this presentation improves meaningful decisions.

---


## ARD-M8-008 — Android app identity: name and launcher icon
**Status:** `VERIFY` — implementation merged in PR #173; verify the installed Android name/icon on the next phone build.  
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

## ARD-M8-009 — Plausible fictional player names
**Status:** `DONE` — implemented in #149.  
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
- key forward / key defender assignments,
- ruck duels,
- star-midfielder influence battles / tags,
- roaming interceptor / spare-defender influence,
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
| GPS / distance covered / km per game / running output | ARD-M2-010 GPS distance covered |
| Player form / match rating by position | ARD-M5-008 Role-aware performance |
| Best on ground / coaches votes / honours / league leaders | ARD-M7-005 History & recognition |
| Injury / visible injury / concussion | ARD-M1-006 + ARD-M3-010 |
| Sim confirmation / skip rounds / don't ask again | ARD-M1-007 Simulation controls |
| Settings / options menu | ARD-M6-005 Options |
| Club colours / green UI / game visual style | ARD-M8-001/002 |
| Android app name / launcher icon / installed app identity | ARD-M8-008 |
| End swaps / wrong-way movement / shot freeze | ARD-M1-004/005 + ARD-M8-003 |
| OOB / last disposal / throw-in / OOF / 50m / frees | M3 AFL Rules & Match Authenticity |
| Wind / rain | ARD-M7-006 Weather |
| Ground size / home ground edge | ARD-M7-007 Venues |
| 22-player side / 4 bench / 5 interchange | ARD-M5-001 |
| Career history / records / Hall of Fame / league leaders | ARD-M7-005 |
| Board satisfaction / job security | ARD-M6-003 Board Confidence |
| Salary cap dollars / realistic salaries / contract money scale | ARD-M6-004 Contracts / trades / free agency |
| VFL / reserves development | ARD-M5-006 Passive reserves |
| OVR correlation / rating predicts strength | ARD-M5-010 |
| Wing/inside-mid/forward identity labels | ARD-M5-009 |
| Create-a-player / self-insert / custom draftee / custom prospect | ARD-M7-008 |
| Cinematic decision scene / tactical close-up / detailed match moment | ARD-M8-007 Cinematic tactical vignettes |
| Draft age filter / rookie-prime-veteran / career-stage filter | ARD-M5-011 |


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

## Design idea — GOAT prospect

**Status: TODO / long-save draft feature.**

In any normal draft, independently of the rare super-draft system, there can be an **exceptionally rare generational / GOAT-level prospect**. This is governed by a **hard spawn cooldown**: once a GOAT prospect is generated, **no other GOAT prospect is eligible to spawn for roughly the next 30 seasons**. After that cooldown expires, eligibility returns; this is not a guarantee that one immediately appears. This must feel extraordinary, not like a recurring draft archetype.

The player must **not be explicitly identified before the draft**. Build anticipation through escalating draft whispers and recruiter/media chatter that allude to unusual ability, development ceiling or combine traits without giving away the prospect's name. The player should have to inspect the draft pool and Combine evidence and make an educated guess about who the rumours describe. Avoid copying the reference game's wording/presentation directly.

If the prospect fulfils that potential, his career economics should reflect genuine superstar scarcity: he eventually commands an **extremely high salary** and becomes **nigh-untradeable** because his club values him accordingly. A trade remains possible only for a genuine **godfather offer**, not through an arbitrary hard lock.

Guardrails: this is **not tied to super drafts**; do not guarantee the GOAT is obvious, Pick 1, or successful; preserve scouting uncertainty and normal career variance; enforce the ~30-season hard spawn cooldown rather than using a simple per-draft random chance that can produce clusters.

---

---

# 9.1 Post-Italy / phone playtest findings — 2026-10-04

**Status: PARTIAL / playtest consolidation.** These findings came from a multi-season Android playtest. Treat the overall difficulty/list-management findings as the main balance priority; fix concrete progression and misleading-UX bugs before adding unrelated feature breadth. Preserve the global rules: no psychic AI, no hidden AI advantages, no best-move hints, mobile-first interaction, and no number-vomit.

## P0 / correctness and trust

- **Mid-season bye falsely enters post-season state — VERIFY (repair merged; phone follow-up).** Observed at Round 15 of 24 while Melbourne was 2nd at 11–3: the Hub said “Season over for you / You missed the top 10” and exposed “Sim to Grand Final / Sim Wildcard Round”. Reproduce a user-club bye, distinguish “no fixture this round” from “no H&A fixtures remaining”, make finals controls impossible before H&A completion, and add regression coverage proving the next H&A match remains available. **Status (2026-10-05):** fixed in merged PR #210; native phone follow-up remains. Cause: an odd (expansion) club count gives the user a home-and-away bye, and the Hub read "no match this week" as "missed the finals". The Hub now shows a bye with a one-round sim; Sim to Grand Final refuses to run before the home-and-away season ends; regression test in the matchup suite.
- **Season fatigue parity audit — VERIFY.** User squad appeared consistently more tired than opposition. Verify AI clubs accumulate and recover fatigue through the season under the same rules and constraints as the user; no hidden fatigue protection. **Status (2026-10-05):** audited in PR #213 (`docs/PLAYTEST_AUDIT_2026-10-05.md`): no parity defect. Every club runs the same Workload/MatchSim rules; the only differences are user-chosen levers (high-performance budget, Heavy/Recovery weeks, a fixed manual side, rotation policy). On default settings the user's match-day load was lower than the AI's (4.4–8.4 vs ~10). Nobody reached "Needs a break", so season workload barely bites, which is relevant to the difficulty finding.
- **Generated-player provenance / age sanity — VERIFY.** A fictional Joshua Robinson appeared age 28 only ~2–3 seasons into the save with 89 POT. Audit all non-draft/list-fill/emergency generation paths, initial ages, club assignment, age × potential logic and career-history provenance. Fictional players should have believable entry history; do not silently spawn implausible veteran high-potential players. **Status (2026-10-05):** fixed in merged PR #213. Only expansion lists create older fictional players, and they were projected like draftees with a draft-rank ceiling (27–30-year-olds got +17–20 POT headroom vs +6.6 for real players; e.g. age 29, OVR 69, POT 91). Past 21 a projected player now gets the age-based ceiling real players use (+1.4–1.8 at 27–30); draft classes are unchanged. Entry history is left as is, since it only shows on draft screens.
- **Training role/classification sanity — VERIFY.** A small defender appeared as a Key Defender after KPD training. Determine whether the underlying role/eligibility actually changed or only the display heuristic changed. Training may improve relevant skills but must not mechanically convert physically unsuitable players into key-position archetypes; audit equivalent role-label transformations. **Status (2026-10-05):** audited and fixed in merged PR #214. Across 1,292 training runs no player changed position and none under the height gates became a key-position type; the label the playtest saw was the training plan shown bare under the name. The Training list now reads "Training as a key defender". Open design question: whether the Key defender plan should be offered to sub-191 cm defenders.
- **Goal-line scramble vignette — VERIFY (fix in PR; phone follow-up).** The current “scramble at the goal line” sequence reads as nonsense. Rework the event/presentation so the underlying football sequence is plausible rather than preserving the vignette for its own sake. **Status (2026-10-05):** fixed in PR #229, pending merge. Cause: the scene was chosen by where the ball ended up, and every score ends at the goals, so any open-play goal with players near the goal square (a 23 m snap, say) was shown as a scramble on the line. It now plays only for the sim's own crumb (a spoil spills to the ground and a small forward snaps it off the deck), goal or behind, and the scene shows that: the contest in front of goal, the spill, the gather and snap, and the ball through the goal posts or between goal and behind post. No change to match outcomes or RNG.
- **Key-matchup copy/data binding — VERIFY (repair merged; phone follow-up).** Observed repeated anonymous text such as “on him”, dangling colons and matchup rows that omit the opponent. Every assignment must clearly identify who is on whom with natural football copy. **Status (2026-10-05):** fixed in merged PR #210; native phone follow-up remains. Every match-up line names both players ("Moore is on Curnow."; cards say "Put Moore on Curnow"); a missing defender reads "Nobody is on Curnow." rather than a gap; id-only name lookups fall back to the current lists so a career-only player is never blank.

## P1 / difficulty, list building and meaningful management

- **Overall difficulty is too low — BALANCE-GATED.** The playtest produced three consecutive premierships despite minimal engagement with training or list management. Audit why neglecting management carries too little cost. Do not solve this with hidden AI boosts, rubber-banding or psychic tactics. Measure low-engagement/autopilot seasons against actively managed seasons; training, development, ageing, contracts, cap pressure, depth, drafting, selection and AI list building must create meaningful long-term consequences without weekly busywork.
- **List-profile top end is too easy to reach — BALANCE-GATED.** By roughly season 3 the user list showed Elite in Contest, Control, Running power and Aerial power and Strong in Pressure and Finishing. Verify league-relative bands against measured list strength before adjusting them; “Elite” should mean genuinely exceptional relative to the competition. The later #217 evidence below found these words already represent league ranks; it supersedes an assumption that the bands are loose. Audit player development/attribute inflation as well as thresholds. Strong sides should normally retain identifiable weaknesses.
- **Synergies should be build specialisations, not completion bonuses — TODO / BALANCE-GATED.** Nearly every synergy was unlocked by season 3. Make activation materially harder and effects materially stronger so pursuing a synergy resembles an RPG build specialisation: roster commitment, meaningful opportunity cost and distinct club identity. A balanced good list should not naturally unlock everything. AI clubs may pursue identities from their actual lists. Keep activation rules/effects transparent without recommending the optimal recruit or build.
- **Extreme-margin calibration — BALANCE-GATED.** A 175–28 win (147 points) is possible football and must remain possible, but audit the frequency of 80+/100+/120+/150+ margins, especially for dominant user teams. Check compounding between ratings, synergies, gameplan, form/momentum and losing-side resistance. Preserve rare massacres; prevent routine runaway percentage farming. Include extreme individual-stat/rating sanity in the same measurement.
- **Trade valuation / potential-by-age audit — VERIFY / BALANCE-GATED.** Review current OVR, realistic remaining development, age, contract, positional need and club strategy together. Potential must be age-adjusted in trade value; an identical POT number cannot imply the same future asset at 17 and 28. Reassess the observed Rozee-for-Robinson example only after the generated-player provenance issue is understood. **Note (2026-10-05):** the inflated POT behind the Rozee-for-Robinson example came from the expansion-list ceiling fixed in PR #213; reassess trade valuation against the merged provenance repair and reconcile open #223/#224 before further edits.
- **Opposition POT information — VERIFY.** Audit whether exact opposition POT is being exposed without sufficient scouting certainty. Preserve the anti-psychic rule; where uncertainty is intended, show an earned estimate/range rather than omniscient exact potential.
- **Full coaching mobility / off-season staff market — VERIFY then TODO if incomplete.** Staff appeared effectively static. Verify contracts, expiries, AI movement, internal promotion, retired-player entry and market circulation. The intended system is a second off-season roster-building layer: retain/release/promote/recruit staff under simple contracts, with assistants pursuing genuine promotions and AI clubs following the same market. Preserve the no-sideways-poaching design; avoid six tedious negotiations every year. **Status (2026-10-05):** verified in PR #214: the market exists (AI senior-coach contracts and sackings, upward promotions, poaching, retirements, a generated pool), but assistants have no contracts, so the user's original assistants stayed for ten seasons in measurement. The light assistant-contract retain/release layer is now merged in #225 (2–3 season terms, short asks, typically 1–2 expiries and one-tap decisions); verify the remaining Android/offseason experience rather than rebuilding it.
- **Contract-talk events currently pre-solve the off-season — BALANCE-GATED.** Early extension requests occur often enough that stars are largely re-signed before the season ends. Reduce frequency and make requests contextual/notable. Most clubs should reach the off-season with meaningful contract decisions unresolved. Early security should have a real price/trade-off; stars should not conveniently remove the hardest cap decisions.
- **Harvey Langford balance adjustment — DONE (merged #213).** Increase Harvey Langford’s player attributes by approximately 15% as an explicit player-data balance correction; do not use this as justification to alter the broader generation model. **Status (2026-10-05):** done in merged PR #213. A named-player `Ratings.ATTR_ADJUSTMENTS` entry scales every attribute ×1.15 (cap 99); OVR 57 → 64, POT 77 → 82, still a MID; nobody else moves. Existing careers keep saved attributes.

## P1 / coaching decisions and weekly flow

- **Gameplan choice still feels like a crapshoot — TODO.** Improve decision information and consequence legibility so the player can form a reasonable tactical hypothesis without being told the best move.
- **Quarter-break opponent-plan reveal — VERIFY (repair merged; phone follow-up).** The break does not consistently reveal the opponent plan used in the quarter that just finished. Make the intended retrospective information reliable. **Status (2026-10-05):** fixed in merged PR #210; native phone follow-up remains. Cause: MatchSim recorded each quarter's plans before the AI chose its plan, so the break showed the previous quarter's plan. The record is now taken after the AI chooses (no RNG or outcome change), and the break always states the plan, including a balanced game.
- **“X is hurting you” must connect to a lever — VERIFY (fix in PR; phone follow-up).** Quarter-break coaching feedback can identify a dangerous opponent when no meaningful response is available. Either surface an appropriate matchup/tag/structural response or do not frame the observation as actionable advice. **Status (2026-10-05):** fixed in PR #230, pending merge. The break says "X is hurting you" only when a call reaches him, and names it: the defender on a key forward ("Moore is on him."), your tagger ("with Sinclair tagging him"), or "He can be tagged." for a midfielder you could tag with a midfielder of yours on the ground. Anyone no call reaches reads as a fact: "X was their best this quarter: 11 disposals." No advice and no best call.
- **“How we get beaten” not learning — VERIFY.** It can still say “Nothing stands out yet” halfway through a season. Audit accumulation, sample requirements and thresholds. By mid-season it should normally identify genuine recurring patterns when evidence exists, but must not invent a trend merely to fill the panel. **Status (2026-10-05):** audited and fixed in merged PR #214. On drafted leagues weak sides are named most of the time; a dominant side usually has no material weakness. The empty read now says so after 10 games instead of "Nothing stands out yet". Thresholds unchanged. Director decision (2026-10-05): the points-from/conceded-on-turnover lines are removed, since a 6-point floor against a 1.5–2 point club spread meant they almost never fired.
- **Weekly selection brief — TODO.** Before selection, surface only a short set of genuine pressures such as “X is pushing for selection”, “X needs a rest”, sustained poor senior form, or a player returning from injury/suspension. Make each item actionable into the relevant change/replacement flow. This is decision support, not an assistant that picks the team.
- **Streamline Ins & Outs — TODO.** Selection should naturally support OUT → IN changes with a small set of suitable eligible replacements, while retaining a path to the full list. Do not declare a “best” replacement.
- **Key match-ups need to be meaningful interventions — TODO.** Routine KPF/KPD pairings should generally be handled automatically rather than manufactured as coaching choices every match. Surface special matchup decisions for genuinely dangerous/hot players, interceptors, small forwards, midfielders, sacrificed attacking defenders, etc. It is acceptable for a match to have no special matchup decision. Connect this system to “X is hurting you” feedback.

## P1 / mobile list and training UX

- **My List → My Selection interaction flow — TODO.** Selecting a player currently requires scrolling to a distant action area. Put relevant actions at/near the selected player. Dropping a player should immediately offer a restrained set of suitable positional/role replacements plus full-list access.
- **My List → Shape should be functional — TODO.** The formation screen is currently cosmetic. Make players directly tappable for move/reposition, swap and drop actions in context, with the same replacement flow. Treat Shape as a candidate primary mobile selection interface rather than maintaining a pretty read-only duplicate.
- **My List → Full List traits — TODO.** Surface distinctive player traits without adding trait-vomit. Prefer a compact trait name/indicator with tap-to-inspect details so the list communicates player identity at a glance.
- **Training touch handling — VERIFY (repair merged; phone follow-up).** Player rows are too eager to register selection while the user is scrolling, causing accidental multi-selects. Add robust scroll-vs-tap/long-press discrimination and test rapid swipes, slow drags, taps and long-press on phone touch input. **Status (2026-10-05):** fixed in merged PR #210; native phone follow-up remains. A press that turns into a scroll (list moved, or finger travelled past the scroll deadzone) is neither a tap nor a long press; still taps and holds behave as before. Covered by a career-UI test; still worth a phone check.
- **Training scrollbar — TODO / mobile polish.** The right-side scrollbar/thumb is awkward to grab. Increase its touch usability if retained, but prioritise normal swipe scrolling so grabbing the scrollbar is rarely necessary.

## P2 / draft pathway depth

- **Academies / NGA and tied prospects — TODO.** Add club academy / Next Generation Academy pathways so some draft prospects carry genuine club ties and enter the normal draft through appropriate bidding/matching mechanics. Academy status must affect real draft/list decisions rather than exist as flavour, obey the same non-psychic scouting uncertainty as other prospects, and become a permanent part of the player's career provenance/history. Implement only after the core draft pipeline is healthy: class depth, Combine/scouting uncertainty and AI drafting/list-building come first.

## 2026-10-05 difficulty evidence and director decisions

- **Difficulty / List Profile / extreme margins / early extensions — evidence, not tuned** (merged PR #217, [difficulty report](DIFFICULTY_EVIDENCE_2026-10-05.md)). Seven five-season autopilot careers (8,281 matches): no policy (AI-style draft, greedy draft, greedy plus accepting every extension) produced a dynasty, with no premierships in 35 seasons. Unmanaged lists start #1 and fall to rank 16–20 by year five through the off-season, while in-season development matches the AI. Your one structural edge is League Draft information (exact board vs AI evaluation error, documented as intended). List Profile words are league ranks, so four Elite words mean genuine dominance, not loose bands. Margins: 100+ in 0.5% of matches, none 150+. Extension cards: about 1.7 a season, and accepting them did not slow the decline. **Working hypothesis, not established causation:** investigate levers the harness does not pull: live-match calls, trades and free agency, and the year-one draft edge. **Director decisions (2026-10-05):** the unmanaged collapse is about right, so leave it and make active play less dominant instead; measure next: live-match call uplift (paired seeds), trade-market exploitability and free-agency advantage. These measurements are in open PR #223 at this checkpoint; #224 addresses unproven-potential valuation. Reconcile their actual heads/results before changing the same systems.
- **Active-play levers — evidence, not tuned** (`docs/LEVERS_EVIDENCE_2026-10-05.md`, PR #223). Live-match calls are worth about +3 points of win rate (counter-reading), and the 216-match Defensive press outlier (67.8% vs 61.1% Balanced) did not hold at 1,080 matches (62.2% vs 59.8%; reading the game 63.3%): it counters Attacking corridor and loses to a pressing AI, so it is not a dominant default. The trade market is exploitable: AI clubs give established stars for unproven teenagers (e.g. 83 OVR age 25 for two 67s aged 18) because `TradeValue.future_rating` treats 60% of a youngster's POT gap as certain. Free agency is not a lever (asking-price bids never lead; the pool is mostly 33+). **Director decisions (2026-10-05):** discount unproven potential in trade value by senior games played (done in PR #224, pending merge: prime-age stars no longer go for unproven kids; a rebuilder can still sell a 29-year-old star for two top kids). **Realised-value follow-up (2026-10-05, in #223):** over three eight-season trader careers the current projection matched the kids' realised peaks (−0.1 on average, n = 23) while #224's discount under-projected them (+1.4); traded stars declined and the trader collapsed to list rank 17–20 either way. Evidence does not support the discount: director to decide whether to close, soften or keep #224; rerun the calls test at about 1,000 matches before any Defensive press tuning (done: not dominant, no tuning recommended); next build after these: assistant contracts (merged #225).
- **Director decision — League Draft board:** your board shows scouted estimates (as the National Draft already does via `DraftScouting`, sharper with recruiting budget) instead of exact consensus ratings, removing the free first-season edge while good drafting still pays. Done in merged PR #222; phone verification remains.
- **Director decision — Opposition POT:** another club's player shows a POT *range* (draft-style scouting) that narrows with his time in the league and your recruiting budget; exact once he is on your list. Done in merged PR #222; phone verification remains.
- **Director decision — Club colours:** Claude proposes corrected primary/secondary/accent for every club with sources and a swatch sheet; apply plus a palette snapshot test only after sign-off. **Done in PR #231, pending merge.** Signed off 2026-10-05: all proposed changes applied to `data/clubs.csv` except Carlton's and Melbourne's navies, which keep the game's lifted navy so they don't read as Collingwood and Essendon on the pitch. Biggest corrections: Brisbane's, North Melbourne's and the Bulldogs' royal blues (were navy) and Port Adelaide's teal (was too green). Sources: Team Color Codes' per-club Pantone references (a third-party summary, not club brand guides). Tasmania and Canberra unchanged. Palette snapshot test in the matchday suite.
- **Director decision — Assistant contracts:** light layer. Assistants sign 2–3 season terms, so typically 1–2 expire per off-season; each is a one-tap Re-sign / Let go with a short ask; AI clubs follow the same rules. Done in merged PR #225; phone verification remains.
- **Director decision — How we play:** the points-from/conceded-on-turnover lines are removed (merged PR #214).



## P2 / presentation polish observed during playtest

- **Money formatting consistency — VERIFY (repair merged; phone follow-up).** Raw values such as “1626750 under the cap”, “970000” and “1115500” were visible in player-facing UI. Use compact AFL-scale currency formatting consistently (for example $1.63m, $970k, $1.12m) without changing underlying values. **Status (2026-10-05):** fixed in merged PR #210; native phone follow-up remains. The raw values came from the early-extension card (asking price and the 15% premium), the Coaching cap line, the cap-room refusal and two news/outcome lines; all now use `Contracts.money()` ($970k, $1.12m).


## Research refinement — competing identities and weekly choices

**Synergy owner:** keep the existing specialisation finding above. **Dependencies:** current Synergies, role/selection and valid match events. **Smallest scope:** measure present activation and outcomes, then refine one specialisation with a visible roster/selection sacrifice. **Exclusions:** another synergy engine, universal buffs, optimal-build/recruit hints or copy of TFT's trait thresholds. **Acceptance:** a balanced good list does not effortlessly activate every identity; several committed builds remain viable against different opponents; actual football strengths and weaknesses correspond to displayed rules. **Validation:** matched talent/cap/age/depth compositions, counter-opponents, activation and event outcomes across multiple seasons, AI parity and phone explanation. Thresholds/quantities remain prototype assumptions until measured.

**Weekly selection owner:** keep Weekly selection brief, Ins & Outs and My List → Shape above as one coherent flow. **Dependencies:** true form/workload/availability and current selection/role eligibility. **Smallest scope:** one real selection pressure with a nearby OUT → IN action and full-list access. **Exclusions:** auto-picked best replacements, constant compulsory changes, extra duplicate list screens or invented reserves statistics. **Acceptance:** quiet weeks are quick; each displayed pressure has evidence; eligible options communicate role/trade-offs without choosing for the player; selection changes preserve scroll/context and the valid named side. **Validation:** injured/suspended/returning/omitted players, no-pressure weeks, rapid and slow Android swipes up and down, tap versus drag, Back, portrait widths and save/resume. Extend existing phone tickets, not a second selection redesign.

# 9.2 Research candidates — awaiting director selection

The detailed evidence, trade-offs and prototype tests are in [GENRE_ENJOYMENT_RESEARCH.md §7](GENRE_ENJOYMENT_RESEARCH.md#7-research-candidates--awaiting-director-selection).

**ARD-RC references are not accepted TODOs, dependencies for shipping, or Claude execution work.** Standing authority applies only after the director selects a candidate and it is merged into the appropriate existing owner. No candidate is added to §0.4.1.

| Reference | Review candidate | Existing owner if selected |
|---|---|---|
| ARD-RC-001 | Optional engine-backed tactical practice preview | M4-004 / M8-007 |
| ARD-RC-002 | A saved match worth remembering, using factual existing report/events | M4-009 / M7-005 |
| ARD-RC-003 | A bounded development commitment with an opportunity cost | M5-003 / existing training |
| ARD-RC-004 | An alumni link across generations using actual former-player coaching records | M7-005 / M6-002 |
| ARD-RC-005 | One existing football answer recalled later, using saved factual context | M6-008 / M7-005 |

Prefer improving the existing experience when that answers the same need. This pass implements no gameplay and sends no implementation assignment.

---

## ARD-M8-009 — Trailer production gate
**Status:** `DEFERRED`  
**Priority:** `P3`  
**Autonomy:** `SUPERVISED`

### Intent
Create a polished trailer for Aussie Rules Dynasties only when the game itself is sufficiently mature that the trailer can represent the real product rather than advertise unfinished systems or placeholder presentation.

This is a **hard-gated late-project item**.

### Start conditions
Claude must **not begin trailer production** until all of the following are true:
- the roadmap is **mostly complete**,
- major visual/presentation work is substantially finished,
- the game's visual polish is close to the intended shipping quality,
- the core loop, matchday presentation, Club Forge/customisation, long-career systems and other major player-facing features intended for the trailer are stable enough to capture,
- there are no known major placeholder visuals that would make the trailer misleading or immediately obsolete,
- the user has given **explicit go-ahead to start trailer work**.

Roadmap status alone does **not** authorise work on the trailer.

### Explicit approval gate
Claude has **no standing authority** to initiate this item.

Even if every technical prerequisite is satisfied, Claude must stop and wait until the user explicitly says to proceed with the trailer.

Do not:
- begin editing,
- capture footage,
- install trailer-production tools,
- create music specifically for the trailer,
- render title cards,
- assemble cuts,
- or open a trailer PR

before that explicit approval.

### High-effort agent responsibility
A high-effort Claude run should periodically reassess whether the project has reached the point where a trailer is sensible.

When Claude believes the roadmap is mostly complete and visual polish has reached a strong enough level, Claude should **tell the user that it believes the trailer gate is ready** and briefly explain why.

That message is a recommendation only. It does **not** authorise trailer production.

### Software permission
Once the user explicitly authorises trailer work, Claude may source additional software needed for trailer production under these constraints:

- **Free software only.**
- Open-source tools are preferred.
- No paid licences, subscriptions, trials that will later charge, or purchases without separate explicit user approval.
- Claude may research, download and use suitable free software if its environment permits.
- If Claude cannot install/use a required free tool directly, it should give the user concise instructions for obtaining/installing it and then continue once available.
- Record any new tool and its licence/source in the trailer implementation notes.

Potential categories include:
- video capture,
- editing,
- transcoding,
- audio cleanup/mixing,
- motion graphics,
- image compositing,
- subtitle/title-card production.

Do not lock the roadmap to one editor in advance; choose the simplest suitable free tool at production time.

### Trailer goals
The trailer should sell the actual strengths of the finished game:
- building and shaping a club over decades,
- meaningful matchday coaching decisions,
- recognisable players and evolving careers,
- drafts, trades and list construction,
- expansion/custom-club identity where visually mature,
- polished match vignettes and club visual identity,
- emergent stories rather than scripted fake drama.

Do not manufacture gameplay outcomes that the real game cannot produce.

### Capture rules
- Capture from a build representative of the intended release quality.
- Prefer genuine gameplay and real in-engine presentation.
- Do not hide major limitations with deceptive editing.
- Avoid debug UI, placeholder art and temporary assets.
- Use real game audio/music only if it is cleared for trailer use.
- If custom trailer music is required, it must also comply with the free/licensed-use rule.

### Pre-production deliverable
After the user explicitly approves trailer work, Claude should first produce a short trailer plan before editing:
- target length,
- audience,
- story arc,
- shot list,
- required game states/saves,
- capture list,
- music/audio approach,
- title-card copy,
- output formats,
- distribution targets.

The user should be able to review this plan before significant editing effort is spent.

### Acceptance
The trailer item can only move out of `DEFERRED` after:
1. Claude recommends that the gate is ready,
2. the user explicitly authorises trailer production.

It is complete only when:
- the trailer accurately represents current gameplay,
- footage is visually polished,
- audio levels are clean,
- text is readable on mobile and desktop,
- no unlicensed material is present,
- final exports are produced in suitable release formats,
- the user has reviewed the finished cut.

---

# 10. Roadmap Maintenance Log

- **2026-10-06:** Granted the art agent permission to investigate and use free-only software for bespoke UI/art production, or direct the user to install suitable free tools when required. Paid software, subscriptions, paid plugins and charging trials remain disallowed without explicit approval.

- **2026-10-06:** Clarified the anti-slop warning: the problem is specifically visual style (rounded-card geometry, corner radii, generic palette, button/card silhouettes and app-template aesthetics), not information density or "visual vomit". Footy Redraft and AFCM are explicit negative visual references for this criterion only.

- **2026-10-06:** Added an explicit warning that the current UI policy/implementation has drifted from the project's anti-slop criteria. Reasserted restrained, mobile-first, football-specific UI guidance and instructed future UI work to remove unnecessary cards/chips/boxes/accents rather than layering on more template-style chrome.

- **2026-10-06:** Added ARD-M8-009 as a hard-gated late-project trailer task. Claude may recommend when the roadmap/visual polish are mature enough, but cannot begin trailer work without explicit user approval. Once approved, Claude may source/use free software only, or direct the user to install suitable free tools.

- **2026-10-05:** Tightened ARD-M7-011 with a footyhead-proof veracity standard: real AFL facts must be sourced and auditable, ambiguous/non-trivial claims should be cross-checked against multiple strong sources, and disputed or uncertain claims should be omitted rather than guessed.

- **2026-10-05:** Refined ARD-M7-011 so historical facts/stats should primarily enrich the existing news feed and other natural football stories, e.g. “Essendon has won its first final in X days,” rather than appearing as detached Wikipedia-style trivia. Loading-screen/dead-time fact dumps are explicitly lower priority.

- **2026-10-05:** Added speculative ARD-M7-011 for an AFL knowledge layer. Claude should investigate unobtrusive places to surface sourced fun facts, records, venue/competition history and factual achievements/stories of real AFL players already in the game, with dynamic context and strict anti-trivia-spam guardrails.

- **2026-10-05:** Expanded Club Forge character creation with boots, independent hair/beard colours, skin tone, freckles, subtle scars, dominant foot, preferred guernsey number and an optional nickname/commentary short name. Dominant foot has modest football/presentation meaning; all other additions are cosmetic, and number conflicts must resolve through normal club numbering rules.

- **2026-10-05:** Expanded Club Forge player appearance again: substantially more hairstyles including a proper Bald option, plus independent beard/moustache choices. Hair and facial-hair variation should also feed generated players, with compatibility rules for headbands and vignette-scale readability.

- **2026-10-05:** Expanded player appearance variation in Club Forge: headbands, bandaging and tattoos now join Tall/Short socks as persistent cosmetic options. These can also seed generated-player visual variety; all are gameplay-neutral, with original/non-copied tattoo art and restrained football-appropriate bandage placement.

- **2026-10-05:** Added Tall socks / Short socks as a cosmetic player-appearance variant. It is a toggle in Club Forge character creation, persists per player, appears in match/vignette rendering where visible, and may also be used for generated-player visual variation. No gameplay effect.

- **2026-10-05:** Clarified ARD-M7-010 Indigenous guernsey direction: Claude should learn the broad visual language and art-style vocabulary from extensive real-world research, then create original club-specific designs. The game does not need to copy specific artworks or fabricate cultural narratives/meanings for fictional guernseys.

- **2026-10-05:** Added ARD-M7-010 for a full Sir Doug Nicholls Round system: extensive official-source research of Indigenous guernsey history from 2014 onward, a 5–10 design rotating library per club, per-club bye/catch-up wearing logic, vignette integration, save-stable seasonal kit assignment, and strong cultural/IP safeguards against copying artist-owned or culturally specific artwork without permission.

- **2026-10-05:** Expanded ARD-M7-009 Club Forge with a researched Australian football location/venue library and deeper procedural guernsey vocabulary. Create-a-club should offer major unrepresented suburbs/football centres nationwide, explicitly including Darwin and Alice Springs and preferring established second-tier football locations such as Southport, Norwood and Peel. Added real-ground mapping, stable venue names separate from sponsor aliases, lower-league design research requirements, and licensing/cultural guardrails for club trademarks and First Nations artwork.

- **2026-10-05:** Added ARD-M7-009 for expansion-club career setup: Tasmania 2028, optional Canberra 2030, real Tasmania-style premium draft concessions, a bespoke main-menu Club Forge for create-a-club/create-a-player, support for a 21st custom club and fair odd-club fixtures. Clarified that all AFL players must reach expansion years through normal ageing/development/list turnover rather than frozen-roster age jumps. Updated ARD-M7-008 so a custom prospect has a one-time hidden POT roll with a usable role-player floor and a rare S-tier ceiling.

- **2026-10-05:** Added independent genre enjoyment research covering eight cross-genre references plus Footy Redraft/AFCM, Crusader Kings and Esoteric Ebb, including the director's replayability/trust/storytelling and short-question preferences. Refined existing tactical, role, development, market, history and QA owners with dependencies, exclusions, observable outcomes and validation. Added accepted ARD-M5-016 (inherited end-2026 lists → 2026 National Draft → 2027), separate from review-only ARD-RC-001–005. Reconciled merged #210/#213/#214/#217/#220/#221/#222/#225 and open #206/#223/#224/#226 against main `4b9eecc3858e970c46e25366701907f1cb4c6070`; preserved phone and balance gates. Documentation only; no gameplay merge or Claude assignment.

- **2026-10-04:** Added Academies / NGA and tied-prospect draft mechanics as a later draft-pathway layer, explicitly downstream of core draft depth, Combine/scouting and AI drafting fixes.

- **2026-10-04:** Consolidated the multi-season Android/Italy playtest findings: P0 bye/progression and football-sanity bugs; overall difficulty/list-profile/synergy calibration; fatigue parity, generated-player provenance, trade/potential and coaching-mobility audits; contract/off-season pressure; weekly selection and matchup decision support; mobile selection/training UX; and observed presentation formatting issues.

- **2026-10-05:** Playtest audits part 2 (PR #214, now merged): How we get beaten copy no longer says "yet" once settled; training rows name the plan as a plan; coaching mobility verified, with assistant contracts identified as the missing layer. Evidence in `docs/PLAYTEST_AUDIT_2_2026-10-05.md`.
- **2026-10-05:** Playtest fix batch (PR #210, now merged): mid-season bye no longer enters post-season; match-up copy names both players; the quarter break shows the plan the opposition actually ran; training rows ignore scrolls; player-facing money uses compact AFL formatting. Recorded the three-game Coaching gate, week-by-week finals and Season Review scroll as already fixed on `main`.
- **2026-10-05:** Reconciled statuses for PRs closed without a direct merge. #182, #183, #185, #186, #187, #188, #191, #193, #195, #196 and #198 were carried onto `main` by the consolidated squash merge #208 (verified: their production code and tests are on `main`; #196's separate free-kick helpers were superseded by the #202 contextual-frees work in #208). Marked M2-010, M3-004, M3-005, M3-006, M3-009, M5-002, M5-011, M6-005 and M8-004 DONE; M3-008, M3-011, M5-014 and M6-008 VERIFY (balance evidence / phone playtest remain); M6-004, M7-003 and M7-005 PARTIAL. Recorded #118 and #120 as merged in §1.11, and collapsed the stale finish-the-stack steps in §0.4.1.
- **2026-10-05:** Playtest audits and Langford (PR #213, now merged): expansion lists no longer give seasoned players a draftee's POT ceiling (the generated-player provenance finding); season fatigue parity audited with no defect; Harvey Langford +15% attributes. Evidence in `docs/PLAYTEST_AUDIT_2026-10-05.md`.

- **2026-10-02:** Added the ultra-rare GOAT prospect concept: roughly once per 30 seasons, independent of super drafts, foreshadowed anonymously through draft whispers/Combine clues, with superstar salary and godfather-offer trade economics if he develops.

- **2026-10-02:** Added the requested SAFE roadmap batch to the existing consolidated #208 branch instead of opening another stack: League Draft career-stage filtering (M5-011) and contextual first-Hub weekly-loop onboarding completing the M8-004 menu/onboarding intent. Refreshed stale SAFE-item references: training multi-select (#192) is already merged, the milestone expansion from closed #186 is carried by #208, and Android app identity remains a device-verification item rather than new code.

- **2026-10-02:** Full progress reconciliation against current `main` plus open/merged PRs. Corrected stale statuses for M3/M5/M6/M7/M8, replaced the near-term queue with the actual merge/finish stacks, recorded GPS distance tracking (#195) as ARD-M2-010, recorded real AFL money (#198) under M6-004, and normalised several legacy compound statuses to the canonical status vocabulary.

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


# Stretch Goals

## AFLW full implementation
**Status:** `DEFERRED`  
**Priority:** `P3`  
**Autonomy:** `SUPERVISED`

Long-term stretch goal: implement the AFLW as a fully playable competition, not a token side mode.

Scope should eventually include:
- full AFLW clubs, players, fixtures, ladder, finals, awards, records and history,
- AFLW-specific list management, drafting, contracts, development and competition rules,
- coaching, tactics, match simulation, presentation and long-save continuity,
- club and league history that can develop independently over decades,
- shared underlying systems with the AFL implementation where practical, without forcing AFL rules or data onto AFLW,
- AFLW-specific research and validation for rules, competition structure, list sizes, season format, venues, uniforms and historical context.

Guardrail: do not begin this until the core AFL game is stable and the shared systems are mature enough that AFLW can be implemented as a proper parallel competition rather than a shallow reskin.
