# League competitive balance: measurement

How competitive is the league a career actually plays? A career does not
start from the real 2026 club lists: every club re-drafts the 669-player pool
in the career draft. This document describes the measurement harness for that
league and records the baseline it produced. **It is measurement only** - no
rating, rule or constant was changed to produce it.

The baseline below predates club-specific draft evaluation. For the same
harness re-run after that change, see
[league_balance_after_club_eval.md](league_balance_after_club_eval.md) and
[DRAFT_EVALUATION.md](DRAFT_EVALUATION.md). Pass `--policy ai` explicitly for
all-AI shards: the default is `board`.

The full generated baseline (every table) is
[`docs/league_balance_baseline.md`](league_balance_baseline.md).

## Tooling

| File | Role |
|---|---|
| `tools/balance/league_balance.gd` | Library. Drafts, plays and measures through the shipped code: `Draft`, `Squad`, `Season` → `MatchSim`, `GameState`, `Prospects._shift_player`. No football is simulated here. |
| `tools/balance/league_balance_report.gd` | CLI. Runs seeded shards to JSON, and merges shards into a markdown report. |
| `tools/balance/draft_variant.gd`, `draft_experiment.gd`, `draft_experiment_report.py` | The draft-compression experiment: one draft mechanism changed at a time, in the tooling only. See [DRAFT_COMPRESSION.md](DRAFT_COMPRESSION.md). |
| `tests/test_league_balance.gd` | CI smoke suite (`league_balance` in `tools/run_tests.sh`, ~1 min). Checks the harness is reproducible and still exercises the real code; asserts **no** balance target. |

### What each league source exercises

| Source | Draft | Season | Between rounds |
|---|---|---|---|
| `drafted` | Real career draft: rivals pick with the game's AI; your club picks by `--policy` | `Season.play_round` / finals (the path `Sim Round` uses) | nothing (no injuries, training, morale) |
| `career` | same | `GameState.start_season` + `GameState.advance()` for every round and final | everything a normal first season does: injuries, rival and your in-season training (default plans), morale, weekly events, board |
| `real` | none - the real 2026 club lists | as `drafted` | nothing |
| `sensitivity` | as `drafted` | one club v every other, home and away | - |

**Your club's picks (`--policy`).** In the real game you make your own picks.
The harness models two drafters:

- `ai` - you pick exactly like the AI. Before club-specific evaluation the
  draft was then **deterministic up to the random pick order**: every seed
  produced the same 18 lists under different club names. Now each seed is a
  different league. The smoke suite pins both properties.
- `board` (default) - a simple human: at each of your turns, a seeded random
  pick among the top 5 players on the draft board sorted by overall that the
  board allows (`Draft.can_pick_player`). Your picks change every later AI
  pick, so seeds give genuinely different leagues (16 of 16 distinct).

The `board` drafter is deliberately naive (best available by OVR, ignoring
structure). The report therefore also shows every measure with your club
removed (AI-drafted clubs only).

### Strength measures

- **`Squad.strength()`**: the auto-selected side's contest/attack/defence blend.
  The board ranks clubs by it. Across the real 2026 lists it correlates with
  the real 2026 wins at r = 0.88.
- **Selected-22 mean OVR**: the mean overall of the 22 the engine fields.

## Running it

```sh
R=tools/balance/league_balance_report.gd
godot --headless --path . --script $R -- --source drafted --policy board --leagues 201,202,203,204 --seasons 3 --out bdrafted_a.json
godot --headless --path . --script $R -- --source real --seasons 8 --season-base 900000 --out real_a.json
godot --headless --path . --script $R -- --source career --policy board --leagues 201,202 --out bcareer.json
godot --headless --path . --script $R -- --source sensitivity --policy board --leagues 201,202,203 --ks 0,1,2,3,4,6,8,10 --reps 2 --out bsens.json
godot --headless --path . --script $R -- --report bdrafted_a.json,real_a.json,bcareer.json,bsens.json --md report.md
```

Shards are independent processes, so a large run can use every core.
Merging is instant.

### Seeds (all explicit)

- Drafted league `L`: `Draft.new(pool, clubs, L)`; the board drafter's RNG is
  seeded `L * 31 + 7`.
- Season `s` of league `L`: season seed `L * 1000 + s + 1` (0-based `s`).
- Real-list season `s`: `--season-base + s + 1`.
- Career mode: season seed `L * 1000 + 1`. `GameState` seeds a season from
  the clock, so the harness sets `season.seed` before round 1 (the fixture
  does not depend on it) and redraws round 1's event card from it.
- Sensitivity match seed: `L * 7919 + rep * 100003 + opponent_index * 211 + venue`.
  It is identical for every k.

## Baseline sample (2026-09-25, engine at b261e79)

| Run | Leagues | Seasons | Matches (H&A) | Seeds |
|---|---|---|---|---|
| Drafted, board policy | 16 distinct | 48 (3 each) | 10,368 | 201-216 |
| Drafted, all-AI policy | 1 (relabelled 16×) | 48 | 10,368 | 101-116 |
| Career first season, board | 8 | 8 | 1,728 | 201-208 |
| Career first season, all-AI | 1 (relabelled) | 8 | 1,728 | 101-108 |
| Real 2026 lists | 1 | 16 | 3,456 | 900001-900016 |
| Sensitivity, board | 6 subjects × 8 k × 68 | - | 3,264 | 201-203, 104-106 |
| Sensitivity, all-AI | 3 subjects × 8 k × 68 | - | 1,632 | 101-103 |

Runtime: 6,751 s summed over 15 shards, about 30 minutes of wall clock on 4
cores. One season takes about 40 s and one career draft about 5 s.
Proportions are shown with Wilson 95% intervals. The skill/luck split
replays the same lists with new season seeds: within-club variance is luck,
and variance of club means beyond that luck is skill.

## Headline results

| Measure | Drafted (board), AI clubs only | Drafted (board), all clubs | Drafted (all-AI) | Real 2026 lists in engine | Real AFL 2026 |
|---|---|---|---|---|---|
| Selected-22 OVR SD across clubs | - | 0.60 | 0.29 | 2.38 | - |
| `Squad.strength` SD across clubs | 2.36 | 2.60 | 2.30 | 2.25 | - |
| Skill SD of season wins | 1.92 | 2.18 | 1.98 | 3.14 | ≈4.5* |
| Share of season-win variance that is skill | 40% | 46% | 43% | 67% | ≈78%* |
| Stronger side (strength) wins | 55.2% | 56.4% | 54.9% | 61.5% | - |
| r(strength, wins) per season | 0.35 | 0.43 | 0.35 | 0.64 | 0.88 (real lists v real wins) |
| Home win (decided) | - | 58.4% | 58.9% | 58.8% | 59.3% |
| Draws | - | 1.1% | 1.3% | 1.2% | 1.4% |
| Median / 90th-pct margin | - | 22 / 55 | 22 / 54 | 24 / 57 | 26 / 67 |
| 60+ / 100+ margins | - | 7.6% / 0.4% | 6.7% / 0.2% | 8.4% / 0.5% | 15.5% / 1.9% |

\* Real AFL: one season, 23 games, from `data/raw/standings_2026.json`,
treating luck as a coin-flip binomial. It is a rough estimate with a wide
interval.

**Controlled sensitivity** (median club of each board-policy league, paired
seeds). Rounding in the refit means the realised selected-22 change is less
than the nominal k:

| Nominal +k | Realised sel-22 OVR Δ | Win % | Δ margin (paired) |
|---|---|---|---|
| 0 | 0 | 47.2% | 0 |
| +1 | +0.3 | 48.9% | +2.1 ± 1.6 |
| +2 | +1.6 | 52.2% | +6.4 ± 1.6 |
| +3 | +2.4 | 56.2% | +6.1 ± 1.6 |
| +4 | +3.6 | 57.7% | +9.7 ± 1.7 |
| +6 | +5.4 | 69.2% | +19.7 ± 1.8 |
| +8 | +7.5 | 74.4% | +25.2 ± 1.8 |
| +10 | +9.5 | 77.3% | +30.6 ± 1.9 |

The same median club wins 58% at home and 36% away at +0. Home ground is
worth roughly as much as +4 to +5 whole-list OVR.

## Reading the baseline (descriptive, not a target)

- **The draft compresses rating spread about 4-8×.** Selected-22 OVR SD is
  0.29 (all-AI) or 0.60 (board) against 2.38 for the real lists. Engine
  sensitivity is about +3 win-percentage points per realised OVR point, so
  OVR gaps of this size are worth at most a few percentage points.
- **The engine is less decisive than the real game, even with real lists.**
  It retains about half the real skill variance (3.14² ≈ 9.9 against
  ≈4.5² ≈ 20 wins²), and blowouts are about half as frequent. (Against
  the 13-season benchmark in [DRAFT_COMPRESSION.md](DRAFT_COMPRESSION.md),
  rather than 2026 alone, it keeps about 64% of the per-game variance.)
- **In a drafted league, OVR does not measure match strength.** Clubs with a
  higher selected-22 OVR win no more often (48.7%). The naive board drafter
  finishes near the bottom despite the highest OVR, because the engine
  rolls role-specific attributes (`Squad` line aggregates and per-player
  attributes), and OVR weights them differently.
- **Preseason `Squad.strength` explains little of a drafted season:**
  pooled R² 0.12-0.25.

A balance target has not been chosen. Candidate targets for discussion (for
example, a skill share of about 60-75%, the stronger side winning about 62-68%,
60+ margins around 12-15%) are proposals only.
