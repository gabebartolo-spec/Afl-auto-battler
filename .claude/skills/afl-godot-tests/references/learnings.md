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
