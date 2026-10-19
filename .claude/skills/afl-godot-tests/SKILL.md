---
name: afl-godot-tests
description: How to run, add and debug this project's Godot test suites and CI without tripping over the other agents on the same machine. Use it whenever you run tools/run_tests.sh or a Godot --script, add or change a test suite or a check floor, read a red or cancelled CI run, start a long audit, or see a test fail that might not be your change's fault - even if you think you already know how to run the tests. Extends the general game-architecture skill (tests and CI shape) with this repo's runners, floors and shards.
---

# Running Godot tests in the AFL project

Four agents share one Windows machine, one Godot install and (by default) one
Godot user-data folder. Most "mystery" test failures here come from that
sharing or from clock-seeded randomness, not from the change under test. This
skill is the routine that avoids both.

## The command

```bash
APPDATA="<your scratchpad>/appdata-<task>" \
GODOT=/c/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe \
SUITE_TIMEOUT=900 tools/run_tests.sh --quick matchday assets
```

- **APPDATA, always.** Every worktree's `user://` is the same folder (it is
  keyed by the project name), and the suites write `user://test_career.save`.
  Another agent's run can delete or rewrite it mid-suite. Windows Godot reads
  `APPDATA`; `XDG_DATA_HOME` (which run_tests.sh sets for Linux CI) does
  nothing here. Use a scratch folder per task.
- **Name the suites you touched** (1-3 while iterating). `tests/README.md` maps
  suites to areas. CI runs everything; a full local run (~20 min) is for wide
  changes or for checking `main` itself.
- **`--quick`** (first argument) is the local loop: no re-import when `.godot`
  exists and no dataset, seeds, export or harness checks; CI runs those. Drop
  it after pulling new assets or scripts other agents added (the import must
  rerun). `SUITES_ONLY=1` alone skips only the extras.
- **Long runs go in the background** (`run_in_background`), one long Godot run
  per agent at a time. Record the task id or PID. Stop only what you started:
  never `taskkill /IM` or kill Godot by image name - the other agents' runs die
  too.

## A fresh worktree

`git worktree add -b claude/<topic> ../Afl-auto-battler-<topic> origin/main`,
then copy `.godot/` in from another checkout so the first run doesn't spend
minutes re-importing.

Test runs rewrite `*.import` files (line endings only) and leave untracked
`.uid`/`.import` files for scripts other people added. Neither belongs in your
commit:

```bash
git diff --name-only | grep '\.import$' | xargs git checkout --
```

Commit the `.uid` of any `.gd` you created. Stage files by name, never
`git add -A`, and read `git diff --cached --stat` before committing.

## Adding a suite or checks

- Runner: `tests/run_<name>_tests.gd`. Its suite keeps `_check` and the
  two-line `_t` beside it (copy them from any suite; the helper is
  `tests/functions_ran.gd`), calls every test as `_t("_test_x")` (`await
  _t("_test_x", [size])` where it awaits), ends with
  `print(Ran.line("<Name>", self))` and quits 1 on any failure.
- Nothing to register: the runner file is the suite. `tools/run_tests.sh`, the
  compile preflight and CI all discover `tests/run_*_tests.gd`
  (`tools/list_suites.sh`); CI puts a suite with no timing on the lightest shard
  at about 60 s (`python3 tools/ci_shards.py` shows where). Add a row to
  `tests/README.md`. Re-plan all shards weekly from a green main run with
  `tools/plan_ci_shards.py` (its header says how); never edit the plan by hand.
- **Every test function runs and checks something** (this replaced the check
  floors on 2026-10-18). The summary reads "Draft tests: 20 of 20 functions,
  7901 checks, 0 failures". A `_test_*` function that is defined but never
  called through `_t`, or that makes no check (an empty loop, an early
  return), fails by name, and `tools/run_tests.sh` fails a line that is
  "functions short" or has no function count. Adding a test means adding the
  function and its `_t` line in your own suite file: there is no shared count
  to raise. A loop over data that could shrink (18 clubs, 22 players) gets a
  size check before the loop, because a function that drops from 18 checks
  to 16 still passes.
- **Seeds:** a test that starts a season or draft sets
  `GameState.replay_seed` first. `GameState._clock_seed` otherwise uses the
  clock, so every run plays a different match and a check can pass or fail on
  the opponent it drew.
- **Autoloads in a `--script`:** a script that names an autoload-dependent class
  at compile time (GameDB, UiKit, StoppageVignette...) fails to compile before
  the autoloads exist. `load()` it inside `_run()` after `await process_frame`,
  and give typed variables to values returned from a `load()`ed script
  (`var n: int = SV.figure_frame(...)`).

## When a test fails

Work through these before blaming your change:

1. **Did it fail on `main` too?** Check out `origin/main` in a scratch worktree
   and run the same suite isolated.
2. **Is someone else running Godot?** `Get-CimInstance Win32_Process` with a
   Godot filter shows command lines. A save/settings-looking failure during
   another run is usually the shared `user://` - rerun with APPDATA.
3. **Does it pass on a rerun?** Then it's nondeterministic. Find the clock
   seed (or other unseeded randomness) and pin it; a flaky check is a seed to
   fix, not a rerun to hope for.
4. **"1 resources still in use at exit"** and ObjectDB leak warnings are noise.
   A `SCRIPT ERROR` is not: run_tests.sh fails a suite whose log has one even
   when every check passed.

After two or three similar fixes have failed, stop patching and gather different
evidence: a minimal reproduction, the last good commit, the runtime state.

## CI

- `tests.yml`: `plan` → twelve `shard` jobs (`tools/ci_shards.py` lays out
  `tools/ci_shards.txt` plus any suite added since the last re-plan, about
  10-12 min; PRs skip `balance`/`league_balance` and run `calibration` only
  when `scripts/sim/` or `data/` changed; those three run nightly at 03:00
  Melbourne; a main push identical to its PR's green tree skips the shards) →
  `extras` (dataset, export, harness) → `test`, the required aggregate, which
  posts last. While shards run, "no `test` result yet" is normal.
- Read a failure with `gh run view <id> --log-failed`. A job **cancelled with no
  steps** never started (runner or a newer push), which isn't a test result.
- Don't push to a branch while its CI runs: the push cancels about eight minutes
  of work.
- Long audits don't run locally: `gh workflow run audit.yml --ref <branch>
  -f impl=<tools/audit name> -f env="K=V" -f args=""`, then
  `gh run download <id> -n audit-<impl>`.

When you report a CI failure to its owner, give: branch, commit, run id, the
failing suite and check, whether it also fails on `main`, and who acts next.

## Learnings

Proven findings for this project live in `references/learnings.md`. Read it before using this
skill; add to it only what proved effective, with evidence.
