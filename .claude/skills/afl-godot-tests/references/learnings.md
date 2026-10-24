# afl-godot-tests: learnings log

Only findings that proved effective on this project: a method that caught or prevented a real
problem, a recurring failure whose fix was verified (test, capture or green CI afterwards), or a
change that measurably saved time. Each entry: `## YYYY-MM-DD · topic`, then **Finding**,
**Evidence** (PR, commit, run id or capture path) and **Lesson**. No hunches or untested ideas.
If a finding contradicts SKILL.md, correct SKILL.md instead of appending; mark an entry "promoted"
once it is in SKILL.md. General lessons belong in the general skill in ~/.claude/skills too.

## 2026-10-18 · a test runner that names a class reaching an autoload hangs the suite to the 900 s timeout
**Finding:** three PRs in one night went red the same way. A test script referred to a class by its `class_name`
(`Squad`, `CoachReport`, `Ratings`, `DraftScouting`) whose script chain reaches an autoload (`GameDB`, `GameState`).
Headless, the runner is compiled before the autoloads exist, compilation fails, and the suite neither passes nor
fails: it hangs until the 900 s shard timeout, which reads as "timed out", not as a compile error. Switching the
reference to `load("res://scripts/sim/<Class>.gd")` fixed each one; `intake_ui` went from a 900 s timeout to 18 s.
**Evidence:** #755 (`run_planpane_tests.gd`, fixed by prsync 2026-10-18), #758 (`run_calls_tests.gd`,
`run_matchday_tests.gd`), #746/#752 (`run_intake_ui_tests.gd`; runs 39080490381 and 39080538518 timed out on
`intake_ui`; run 39083106488 after the fix).
**Lesson:** in `tests/run_*_tests.gd` and `tests/test_*.gd`, never name a sim or state class by `class_name` when
its chain can reach an autoload; `load()` the script by path and type the result loosely. When a suite "times out"
on CI at exactly the shard limit having printed nothing, suspect this before a slow test. A preflight that compiles
each runner headless with a short timeout would turn the 900 s hang into a 30 s fail (not built yet).

## 2026-10-18 · count test functions, not checks: the floor registry cost more than it caught
**Finding:** the check-count floors (`expected_checks.txt` plus a delta file per PR) never caught a real
defect: the one "checks went missing" failure on record was a false alarm (c6f35800, a floor from "one
lucky run"), and the truncations that did happen were caught by the script-error rule (#46). Meanwhile
114 of 162 merged PRs (#643 to #814) edited the floors, 145 delta files sat unfolded on main, and on
2026-10-18 #810 (+33) and #806 (+51) both counted the same 31 checks: main went red at 7,870 against a
7,901 floor and every open PR failed until hotfix #822. A floor also cannot be set "from the test code"
in a loop suite (156 call sites in `test_draft.gd` make 7,901 checks).
**Evidence:** test suite audit 2026-10-18 section 4 (`docs/research/TEST_SUITE_AUDIT_2026-10-18.md`,
approved by the director); the replacement, branch `claude/function-count-not-floors`: every suite calls
its tests through `tests/functions_ran.gd`, and `tools/test_run_tests.sh` proves a fixture with an
uncalled `_test_x` and one with a check-less test both fail by name.
**Lesson:** guard "did every test run" with something that lives in the test's own file (a function
that never ran or made no check fails by name), never with a shared number every PR must edit. A guard
that every PR touches will conflict, and a guard that has never caught anything costs more than it saves.

## 2026-10-25, AFL: a stale `.godot` in a worktree reads as a parse error, then a hang
**Evidence:** lead session 30cedf, branch claude/draft-night-trades. The worktree's `.godot` dated from before
PreSeason, Features, DifficultyDials and FamilyTies were merged; `tools/run_tests.sh --quick contracts` failed in 7 s with
`Parse Error: Identifier "PreSeason" not declared` in GameState.gd (no change of mine), and the parallel intake_ui run
hung at 132 MB until `timeout` ended it (the permission classifier refuses `taskkill` of a Godot PID). A full
`godot --headless --path . --editor --import` (10 min) fixed both; a new `class_name` script also needs it before any
suite can see it.
**Lesson:** "Identifier X not declared" for a class you did not touch is the global class cache, not the code: stop,
run the import (drop `--quick` once), then iterate with `--quick`. Run it before the first suite whenever the branch
moved past the cache or you added a `class_name` file; never read the parse error as a defect in the merged code.
