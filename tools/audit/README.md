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
- Changing the seed after `reset()` is safe for the first draft class:
  `start_season` remakes it from your seed when it was made from another (#383).
- `run_audit.gd` seeds the global RNG (`AUDIT_SEED`, default 2026), so `reset()`'s
  seed repeats run to run (#428).
- Never use the clock as a seed. A test or audit that does is flaky by design.
- Paired runs only pair if every run in both arms sets both seeds. Check this
  before reading a difference: the same seed in two runs should print the same
  first-season ladder.

## Audits

- `list_churn_impl` (P-81): 10-season autopilot careers (args `seeds seasons`, default 301 10); one `CHURN` line per club per off-season (delisted, walked, retired, traded out, drafted, traded in, signed; the user club is marked `user 1` and left out), then `SUMMARY`. `python3 tools/audit/list_churn_agg.py --date D --runs IDS --out docs/research/LIST_CHURN_AUDIT_D.md run_*/audit.log` writes the doc, with the real yardstick (8 to 12 list changes a club a year). Dispatch it on `audit.yml`, not locally.
- `factsgrowth_impl` (#554, G7): a long autopilot career (args `seed club seasons`, default 301 MEL 20); one `FACTS` line a season with `career_facts` rows, its bytes and its share of the save file, then `TIMING` (save and load, facts kept vs emptied, same career) and `SUMMARY`.
- `traitdecay_impl` (#440): one eight-season career from a seeded upside draft, printing one `DECAY` line a season: the synergies switched on across the league, then the count of players holding each synergy trait, real and generated players apart. `AUDIT_SEED` sets the career seed (default 301), so runs with the same seed pair.
- `gen_traits_impl` (row 104): generated players' special traits against the real 2026 players', on seeded classes (career seed 4242 + year); run it on main and on the branch for a before/after. Args `[classes=30] [grow=5]`. One `RATE` line per trait: the real share, then the share at the draft, grown five seasons, and "matched" (the grown share per 4-point OVR band weighted by the real players' OVR mix, the like-for-like rate for a re-anchored league). About 30 s locally.

- `listed_positions_impl` (row 91): one `ROW id|club|name|listed|role|role2|overall|potential|gm` line per real player, then `CROSS listed>role` counts and the median OVR of each first position. Run it on two checkouts and join on id to list every player whose position or OVR moved. No arguments.
- `role_alloc_impl`: every 2027 list's listed position (real_pos) against the first and second positions the numbers give, the player types each role produces, named cases and each club's coverage by line. No arguments.
- `underrated_impl`: the opening pool's 2026 OVR against each player's 2024-25 level; short 2026 seasons re-rated as if held for 22 games; and a games-weighted 2026/2025/2024 view. No arguments.
- `unicorn_impl`: Unicorns at the career start and who could become one (POT 90+, the missing line within reach). No arguments.
- `stories_impl` (club-life stories, phase 1): the long-save proof for the week's story cards. An autopilot career answering every card with a seeded choice (args `seed club seasons`, default 1 MEL 10); one `STORY` line a season, a `REPEAT` line per card, then `SUMMARY`: cards seen, distinct cards, the most repeated, by category, arcs started / done / lapsed, the levers the answers moved, and players by trust band.
- `interrupt_impl` (G1): an autopilot career that leaves every ask unanswered and records, each week before the match, what is waiting: the event card, a press question and a tribunal challenge, plus the news items added. Arguments: seed, club code, seasons (`interrupt_impl 1 MEL 3`). Results and the proposed pacing rule are in `docs/research/RPG_G1_INTERRUPTION_AUDIT.md`.
- `coach_rate_impl` (row 71, T5.Q15): seeded autopilot careers; after each rollover, the share of the league's coaching jobs (and senior coach jobs) held by former players of the league. Arguments: seed, club, seasons (default 1 MEL 32, the last rollover into 2058); `COACH_SEEDS=a,b,c` runs one career each (two 32-season careers take about 1 h 40 min on a runner, three about 2 h 20 min of the 180-minute limit). Results in `docs/COACH_RATE_EVIDENCE_2026-11-06.md`.
- `staff_identity_impl` (RPG-006): paired autopilot careers where your club's staff is given one character each season (`base`, `teach`, `tactics`, `manage`, `fair`) and every other club is left alone; prints young players' rating gain, list gain, ladder, margin and morale per season. Arguments: arm, seed, club, seasons (`STAFF_SEEDS=a,b,c` runs one career each). Results in `docs/research/RPG006_STAFF_IDENTITY_AUDIT.md`.
- `tactics_pair_impl` (RPG-006): the same matches played twice with the same seeds, the home side's tactics at the top of their range and at the bottom, printing the paired margin difference and its standard error, overall and per pairing. Argument: seeds per pairing (default 40). Results in `docs/research/RPG006_STAFF_IDENTITY_AUDIT.md`.
- `draft_strategy_impl` (row 37): seeded 10-season autopilot careers, `mode seed club seasons`; mode `redraft` or `real` (the row 37 draft logic is the only logic since 2026-11-03). Prints LIST / DP / DC / AGE lines; `draft_strategy_agg.py <dir>` makes the tables. Latest: docs/research/AI_DRAFT_AUDIT_2026-11-03.md (supersedes draft_strategy_audit_2026-10-12.md).
- `brownlow_impl` (Brownlow realism): seeded home-and-away seasons through `Season.play_round`, votes from the game's own `Awards.tally_match`, set ratings on (it refuses to run with `AFL_SKIP_OVR_ROWS`). Args `mode first last`: `real` (the real 2026 lists), `drafted` (a career draft each season) or `ratings` (no matches: each set rating against his best line, unset players whose other line beats their overall by 5+, generated rucks grown five seasons). Prints a `ROW` per player a season (votes, tackles, pressure acts, hit-outs, the influence stats, and his votes under each other way to give the 3-2-1 in `ALT`: the old weights, the fit with the result, and the fit drawn as umpires vote), `WIN`, `WSH`/`WSA` (votes to the winning side) and `VRD` (the coach's full-time read). `python tools/audit/brownlow_report.py [--votes old|fitwin|umpire] A.log [B.log]` marks winner, 2nd, 5th, 10th, men polled, the ruck share, vote share by line and tackles and pressure acts per player IN/NEAR/OUT of `tools/balance/afl_brownlow.json`, with Blicavs and Gawn watched. 20 seasons take about 6 minutes a mode.
- `rotations_season_impl` (competent-AI rotations): seeded autopilot seasons (args `seeds club`, default 301,302,303 MEL); one `ROT` line per season: ladder points SD, top/bottom, injuries per game, mean workload, rotation plans run, premier. Run it on two code states and compare by seed.

## Captures on GitHub

`capture.yml` (#474) runs one `tools/visual/<tool>.gd` on GitHub's runner under a virtual display, so a capture never needs a window or the local Godot slot:

```
gh workflow run capture.yml --ref <branch> -f tool=capture_match -f args="--seed 42 --kind goal --nth 2"
gh run download <run-id> -n capture-capture_match
```

`tool` is the script name without `.gd`; `args` is what it reads after `--` (the workflow adds `--out`). It uses software rendering, so it is right for layout, colour and motion, not for frame times.
