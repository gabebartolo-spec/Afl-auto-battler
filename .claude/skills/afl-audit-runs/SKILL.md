---
name: afl-audit-runs
description: How to answer a balance or behaviour question in the AFL project with a seeded audit - writing a tools/audit/<name>_impl.gd script, running many careers or matches on GitHub's runners through audit.yml instead of this machine, comparing arms on paired seeds, and collecting the results into an evidence doc. Use it whenever a question needs more than a handful of matches or seasons (calibration, difficulty, flags, levers, rates against real AFL), whenever you'd otherwise run a long Godot loop locally, or before proposing any balance change.
---

# Audit runs

A balance question here is answered with measurements, not one memorable
match: the director decides from distributions, against real AFL where a real
number exists. Long runs belong on GitHub's runners so the four agents' shared
machine stays free (one long local Godot run per agent at most).

## 1. Write the question first

Name the quantity, the comparison and what would change your mind. For example:
"premier's ladder position, sim vs real 2000–25", or "mean ladder finish with
synergy selection vs without, same seeds". Find the real reference first: AFL
Tables season pages (Firecrawl or a short `urllib` script, cached in your
scratchpad), `tools/balance/afl_ladders.json`, `data/raw/`.

## 2. The impl script

`tools/audit/<name>_impl.gd`, run by `tools/audit/run_audit.gd -- <name>_impl
<args>`. Model it on an existing one: `flags_impl` (league seasons),
`levers_coach_impl` (a managed career with toggled levers), `career_impl`, `dynasty`
via `tools/balance/dynasty.gd`.

- `extends RefCounted` with `func run()`. Read args from
  `OS.get_cmdline_user_args()` (`[0]` is the impl name) and switches from
  `OS.get_environment(...)`.
- **Seed everything:** `GameState.replay_seed` and `career_seed`, and seeded
  drafts and `MatchSim`. Take several seeds as one comma-separated arg so one
  job runs many careers.
- **Paired arms:** the same seeds with one thing toggled (an env var such as
  `LEVERS=syn`). Compare within a seed before averaging.
- Print one line per season or match, and a parseable `SUMMARY ...` line per
  career. Keep raw counts (wins, games) as well as rates, so arms can be pooled.
- Measurement only: an impl never changes a rule.
- Smoke-test locally once with a tiny run (1 seed, 1–2 seasons, APPDATA
  isolated; see afl-godot-tests), then commit and push the branch.

## 3. Run it on GitHub

```bash
gh workflow run audit.yml --ref <branch> -f impl=<name>_impl -f env="KEY=VALUE" -f args="301,302,303 6"
```

- One dispatch per arm (or per seed batch); they run in parallel. The job
  timeout is 180 minutes, so size the seed batches to fit.
- Record the run ids. Wait without polling in your turns: a background
  `gh run watch <id>` loop that then downloads each artifact
  (`gh run download <id> -n audit-<name>_impl -D run_<id>`) and greps the
  `SUMMARY` lines.
- A run's artifact is always named `audit-<impl>`; download by run id to keep
  arms apart.

## 4. Report

`docs/<TOPIC>_EVIDENCE_<date>.md`, as in `FLAGS_EVIDENCE_2026-10-06.md`:
- method;
- the real vs sim table;
- what it means for the design question;
- **Not exercised** (what the bots don't do, which formats differ).

Open it as an evidence PR with the impl. When a change is needed, give the
director options with a recommendation; the director picks before you tune.
