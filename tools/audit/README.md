# Audits

Headless audit scripts, run with
`godot --headless --path . --script tools/audit/run_audit.gd -- <name>_impl <args>`
(see the header of each `*_impl.gd` for its arguments).

## Seeding an audit

An audit that compares two runs (a lever on against off, a change against main)
only means something if both runs play the same career. Seed every run, the same
way.

- `GameState.reset()` rolls a fresh `career_seed` from the global random number
  generator. Left alone, every run is a different career, and a paired run is not
  a pair.
- Set both seeds after `reset()` and before `start_season()`:

  ```gdscript
  GameState.reset()
  GameState.career_seed = seed
  GameState.replay_seed = seed
  GameState.start_season(club, GameState.draft.list())
  ```

  `career_seed` drives the prospect classes, scouting reads and the coach market.
  `replay_seed` drives the draft and season rolls (the clock is used when it is 0).
  Seeding only `Draft.new(..., seed)`, or only one of the two, leaves part of the
  career random.
- Changing the seed after `reset()` does not rebuild a draft class that `reset()`
  has already made. #383 makes `start_season` remake the first class from your
  seed; until it is on main, set the seeds before the first class is read.
- `run_audit.gd` seeds the global RNG (`AUDIT_SEED`, default 2026), so `reset()`'s
  seed repeats run to run (#428).
- Never use the clock as a seed. A test or audit that does is flaky by design.
- Paired runs only pair if every run in both arms sets both seeds. Check this
  before reading a difference: the same seed in two runs should print the same
  first-season ladder.

## Audits

- `factsgrowth_impl` (#554, G7): a long autopilot career (args `seed club seasons`, default 301 MEL 20); one `FACTS` line a season with `career_facts` rows, its bytes and its share of the save file, then `TIMING` (save and load, facts kept vs emptied, same career) and `SUMMARY`.
- `traitdecay_impl` (#440): one eight-season career from a seeded upside draft, printing one `DECAY` line a season: the synergies switched on across the league, then the count of players holding each synergy trait, real and generated players apart. `AUDIT_SEED` sets the career seed (default 301), so runs with the same seed pair.

- `role_alloc_impl`: every 2027 list's listed position (real_pos) against the first and second positions the numbers give, the player types each role produces, named cases and each club's coverage by line. No arguments.
- `underrated_impl`: the opening pool's 2026 OVR against each player's 2024-25 level; short 2026 seasons re-rated as if held for 22 games; and a games-weighted 2026/2025/2024 view. No arguments.
- `unicorn_impl`: Unicorns at the career start and who could become one (POT 90+, the missing line within reach). No arguments.

## Captures on GitHub

`capture.yml` (#474) runs one `tools/visual/<tool>.gd` on GitHub's runner under a virtual display, so a capture never needs a window or the local Godot slot:

```
gh workflow run capture.yml --ref <branch> -f tool=capture_match -f args="--seed 42 --kind goal --nth 2"
gh run download <run-id> -n capture-capture_match
```

`tool` is the script name without `.gd`; `args` is what it reads after `--` (the workflow adds `--out`). It uses software rendering, so it is right for layout, colour and motion, not for frame times.
