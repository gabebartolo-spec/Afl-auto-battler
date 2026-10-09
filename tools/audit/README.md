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
- `boot_leak_impl` (ROADMAP 1.11): the figure sheets' boot-colour leak under VRAM compression: Godot's own BPTC and ASTC imports, decompressed, run through the figure shader's weight maths beside the lossless PNGs, at texel centres and half way between texels. No arguments; `LEAK` lines and a `SUMMARY`.
- `interrupt_impl` (G1): an autopilot career that leaves every ask unanswered and records, each week before the match, what is waiting: the event card, a press question and a tribunal challenge, plus the news items added. Arguments: seed, club code, seasons (`interrupt_impl 1 MEL 3`). Results and the proposed pacing rule are in `docs/research/RPG_G1_INTERRUPTION_AUDIT.md`.
- `staff_identity_impl` (RPG-006): paired autopilot careers where your club's staff is given one character each season (`base`, `teach`, `tactics`, `manage`, `fair`) and every other club is left alone; prints young players' rating gain, list gain, ladder, margin and morale per season. Arguments: arm, seed, club, seasons (`STAFF_SEEDS=a,b,c` runs one career each). Results in `docs/research/RPG006_STAFF_IDENTITY_AUDIT.md`.
- `tactics_pair_impl` (RPG-006): the same matches played twice with the same seeds, the home side's tactics at the top of their range and at the bottom, printing the paired margin difference and its standard error, overall and per pairing. Argument: seeds per pairing (default 40). Results in `docs/research/RPG006_STAFF_IDENTITY_AUDIT.md`.

## Captures on GitHub

`capture.yml` (#474) runs one `tools/visual/<tool>.gd` on GitHub's runner under a virtual display, so a capture never needs a window or the local Godot slot:

```
gh workflow run capture.yml --ref <branch> -f tool=capture_match -f args="--seed 42 --kind goal --nth 2"
gh run download <run-id> -n capture-capture_match
```

`tool` is the script name without `.gd`; `args` is what it reads after `--` (the workflow adds `--out`). It uses software rendering, so it is right for layout, colour and motion, not for frame times.
