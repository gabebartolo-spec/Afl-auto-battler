---
name: afl-ci-merge-hygiene
description: How to avoid red CI, cancelled runs and merge conflicts in the AFL auto-battler repo, and what to do the moment one happens - a triage tree built from every failed Tests run of 2026-10-06 to 10-08. Use it before pushing or syncing any branch, when merging origin/main into a branch, when editing tests/expected_checks.txt, tools/ci_shards.txt or the roadmap, when a Tests run is red or cancelled, when two PRs fail the same check, and when you take over from the other Claude account. Extends the general github-hygiene skill (~/.claude/skills) with this repo's files and history; general lessons go there.
---

# CI and merge hygiene (AFL auto-battler)

Built from 150 Tests runs (85 green, 22 red, 41 cancelled). Update the
"Seen so far" table whenever you meet a new cause - that is how this skill stays
true. This repo copy is the only one; the general rules it builds on are in the
`github-hygiene` skill (`~/.claude/skills`, both Claude accounts).

## Before you push

1. **Never push while your CI runs.** A push cancels the run (concurrency
   group per ref) and throws away ~8 minutes. A docs-only commit on a PR whose
   shards are running cancels them too (#522: a roadmap-only push cancelled the
   code run). Batch edits, push once. Check `gh run list --branch <b> --limit 2`.
2. **After `git merge origin/main`, run the suites main just brought in**, not
   only yours. A merge of two green branches can be red: set-share (#484) + the
   Stats patch (#509) were each green, the merge failed `stats`
   ("running bounce ... runs say 2"). Look at `git diff ORIG_HEAD --stat` for
   `tests/run_*_tests.gd` and for scripts your branch also edits.
3. **Adding or removing a suite?** Register it in all four places (see
   afl-godot-tests) and refresh `tools/ci_shards.txt` timings from a complete CI
   run. Missing this failed the `plan` job on five stats-* branches in a row
   ("every suite needs exactly one shard and a measured timing").
4. **Seed anything that plays a match, draft or season** (`GameState.replay_seed`
   or `SUITE_SEED`). Clock-seeded checks pass or fail on the opponent drawn.
5. **Stage files by name**; drop line-ending-only `*.import` changes. Commit the
   `.uid` of every `.gd` you add.
6. Art/sheet changes: the `assets` suite compares the club-design sheet to the
   figures. Regenerate the sheet from the same pipeline commit as the figures
   in the same push (#522: sheet and figures out of step failed `assets`).

## Merge conflicts

- **`tests/expected_checks.txt` was in almost every conflict** (stats-hub, stats-book,
  set-share, kick-fix). Now use floor deltas (below). A leftover conflict: resolve to
  *base + both increments*, confirm against a real count. Never lower a floor.
- ROADMAP/docs: keep both sides. `StatsHubScene.gd`, `MatchSim.gd`, capture tools
  are the other hot files; a PR touching them says so in its [MERGE NOTE].
- Sync early: merge `origin/main` when you start work on a hot file and again
  just before marking ready, not for the first time on merge day.
- Only the branch owner pushes to the branch. A support session sends the
  owner the exact conflict list and resolution, or does it in the owner's
  worktree only if the owner has said so.

## When a run is red - triage in this order

1. `gh run view <id> --log-failed | grep "##\[error\]"` - the suite and check.
2. **Same check red on 2+ unrelated PRs, or on a `main` push?** It is main (or
   the runner), not the PRs. Do not touch the PRs; fix main once. On 10-06
   `matchday` "No position is shut out" was red on main and on 12 PRs until (most likely) the
   clock-seeded suites were pinned (C15, #320-#336).
3. **Cancelled?** Look at the job list: no steps = never started; or a newer
   push superseded it. Not a test result. Rerun only if nothing newer exists.
4. **Fails on your branch only?** Reproduce on `origin/main` in a scratch
   worktree, same suite, isolated `APPDATA`. If main is green, it is your
   change or the merge (see Before you push 2).
5. **Passes on rerun?** Flaky = unpinned randomness. Fix the seed; a rerun is
   not a fix. Record it below.
6. **Two similar failed fixes** -> stop; get new evidence (diff of the sheet,
   the exact numbers, last green sha) before a third push.
7. Tell the branch owner: branch, sha, run id, suite and check, whether main
   fails too, who acts next. One message, no acknowledgements.

## Seen so far

| Cause | Examples | Prevention |
|---|---|---|
| Clock-seeded check red on main, infects every PR | matchday "shut out of big ratings" x12 (10-06) | seed suites; triage rule 2 |
| Rare seed in a lifecycle check | contracts rival-takes-starter, league_balance draft, match_game playtest call | pin the seed; add the failing seed as a case |
| New suite not in shards/timing | stats-hub/ladder/fixture/events, 5 runs | register + re-time, `bash tools/check_ci_shards.sh` before push |
| Floor drift ("checks went missing") | contracts 232 of 233 | floor = base + your increment, verified |
| Merge of two green PRs red | set-share + Stats patch (`stats` bounce count) | run the suites main brought in |
| Sheet and figures out of step (inferred from the fix commit) | kit-sleeves-v2 `assets` | regenerate together |
| UI check at two sizes (cause not yet investigated) | stats-book "players kept" 1280x720 + 390x844 | run the suite at both sizes locally |
| Push cancels running CI | 41 cancelled; 20 are `main` | one push per CI cycle; see proposals |
| Data/ratings change reshuffles seeded line-ups | #530 rating lift: match_game, selection, training, potential | full suite before pushing; measure with/without before touching a check |
| New `data/*.csv` without a `keep` import | #546: `dataset and harness checks` (check_export_data.sh) | commit `<file>.csv.import` with `importer="keep"`; a local Godot import can write `csv_translation`, so open the file and check |

## CI changes made (director yes, 2026-10-08, PR claude/ci-floors-and-main-runs)

- Pushes to `main` each get their own concurrency group and are never cancelled;
  PR runs still cancel when superseded.
- Floors: do not edit an existing suite's line in `tests/expected_checks.txt`.
  Add `tests/floor_deltas/<branch>.txt` with `<suite> +N`; floor = base + all
  deltas. The merger runs `tools/fold_floor_deltas.sh` now and then. A new suite
  still gets its own new line. (Applies once that PR is on main.)

## Handing over to the other Claude account

The accounts never run at once and share `~/.claude` (skills, handoffs).
Before ending a turn after changes:
1. Rewrite `~/.claude/handoffs/<project path>.md` (hook-enforced, <120 lines).
2. It must let a cold session act in five minutes: open PRs with sha and run id,
   what each waits on (CI, W7, director look), worktree paths, the CI/merge
   queue in order, decisions made, and the live peers (`ListAgents`).
3. Verify claims against GitHub right before writing (`gh pr list`,
   `gh run list`): a handoff naming a merged PR as open wastes the next hour.
4. Anything the next session must not repeat goes in "Seen so far", not only
   in the handoff.

## Learnings

Proven findings live in `references/learnings.md`. Read it before using this skill; add to it
only what proved effective, with evidence (see the global rule in ~/.claude/CLAUDE.md).
