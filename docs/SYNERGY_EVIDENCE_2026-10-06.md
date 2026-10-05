# Synergy activation and effect: baseline (2026-10-06)

Evidence for §9.1, "Synergies should be build specialisations, not completion
bonuses". Measured on `main` before the rework, so the rework can be judged
against it. Evidence only; no changes.

**Headline.** After one season of ordinary development, a typical club runs
two synergies and a top-4 list two or three. Engine room (100% of top-4 lists)
and tall-small are near-defaults, while lockdown unit and running machine are
rare. A club's synergy package is worth about +10 points and +11% win against
an evenly matched side. The playtest's "nearly every synergy by season 3" did
not reproduce: an engaged trainer peaked at 4 of 6.

## Method

- `tools/audit/synergy_impl.gd` (sample size from `SYN_DRAFTS`, `SYN_REPS`;
  `SYN_EFFECT=0` for activation only). It covers four drafted leagues (seeds
  21–24), 72 club-lists, and each club's best side from `Ratings.select_side`
  via `Squad` (the on-ground 18 MatchSim reads). Snapshots are taken at the
  start and after one career season through `GameState` (development and
  training happen; injuries are healed before selecting). Top 4 is the four
  strongest lists in each league.
- Effect: strength neighbours, 8 seeds × both home orientations × 9 pairings
  × 4 leagues = 576 paired Sim-round matches. Each match is played twice from
  the same seed: as is, and with side 0's synergies zeroed after
  construction. The difference is therefore the synergies alone.
- `tools/audit/synergy_career_impl.gd`: real League Draft careers (you are
  MEL, drafting like an AI), 4 seasons, seeds 1–3, under two policies:
  `ai` (defaults) and `trainer` (each preseason, every player trains the plan
  weighting the stat of the trait he is nearest, per `Traits.near`). The
  trainer is an approximation of an engaged human, not a recording of one.

## Activation (share of clubs with the synergy on)

| synergy | needs | start | after one season | top 4 start → after | one trait short (start) |
|---|---|---|---|---|---|
| Engine room | 2 Contested bull (18) | 35% | 71% | 50% → 100% | 42% |
| Tall-small forward line | 1 Aerial + 1 Crumber (forward line) | 39% | 61% | 38% → 69% | 53% |
| Intercept wall | 2 Interceptor (defence) | 31% | 35% | 25% → 19% | 43% |
| Lockdown unit | 3 Lockdown (18) | 10% | 14% | 6% → 0% | 19% |
| Supply line | 2 Ball magnet + 1 Playmaker (18) | 28% | 19% | 69% → 69% | 42% |
| Running machine | 3 Engine (18) | 10% | 10% | 13% → 6% | 21% |

Synergies on per club (0 / 1 / 2 / 3+): all clubs 18 / 35 / 29 / 18% at the
start and 7 / 21 / 38 / 35% after a season. Top-4 lists go from 6 / 19 / 50 /
25% to 0 / 0 / 44 / 56%.

## Carriers at or above k in the counted line, after one season

All clubs | top-4 lists (k = 5 and 6 are 0% unless shown):

| trait (line) | >=1 | >=2 | >=3 | >=4 | top-4 >=1 / 2 / 3 / 4 |
|---|---|---|---|---|---|
| bull (18) | 93% | 71% | 46% | 18% (>=5 3%) | 100 / 94 / 88 / 44 (>=5 6) |
| aerial (fwd) | 76% | 46% | 15% | 1% | 81 / 38 / 25 / 0 |
| crumber (fwd) | 83% | 49% | 17% | 3% | 81 / 56 / 6 / 0 |
| interceptor (def) | 74% | 33% | 8% | 0% | 69 / 19 / 6 / 0 |
| lockdown (18) | 76% | 40% | 15% | 1% | 69 / 38 / 0 / 0 |
| ball magnet (18) | 74% | 32% | 10% | 4% | 94 / 75 / 25 / 13 |
| playmaker (18) | 71% | 31% | 6% | 1% | 81 / 31 / 6 / 0 |
| engine (18) | 69% | 32% | 10% | 4% | 56 / 25 / 6 / 0 |

At the start: bull 76 / 35 / 11 / 3, aerial 76 / 46 / 15 / 1, crumber
54 / 18 / 4 / 0, interceptor 74 / 31 / 7 / 0, lockdown 68 / 29 / 10 / 3,
ball magnet 83 / 42 / 14 / 4, playmaker 71 / 29 / 6 / 1, and engine
68 / 31 / 10 / 3. Position-plan development drives the season's growth in
bulls (1.25 → 2.29 per 18) and crumbers (0.82 → 1.58).

## Effect (side 0 as is vs its synergies zeroed, same seed)

| side 0 had | matches | win % change | margin change |
|---|---|---|---|
| any synergy on | 472 | +10.8 | +10.4 |
| Engine room | 200 | +11.5 | +12.3 |
| Tall-small forward line | 224 | +11.8 | +9.3 |
| Intercept wall | 176 | +15.9 | +13.8 |
| Lockdown unit | 56 | +11.6 | +11.5 |
| Supply line | 160 | +15.0 | +13.5 |
| Running machine | 56 | +8.9 | +18.1 |
| no synergy (control) | 104 | 0.0 | 0.0 |

The per-synergy rows include matches where others were also on. Clubs with
any synergy average about 1.8 active, so one synergy is worth roughly +5–6
points and +6% win. The lockdown and running-machine rows (n = 56) are noisy.

## Career view (synergies on at each season start, 2027 → 2030)

| seed | `ai` (defaults) | `trainer` | league AI clubs, mean (max) |
|---|---|---|---|
| 1 | 3, 3, 2, 1 | 3, 3, 2, 3 | 1.2–1.6 (2–3) |
| 2 | 1, 2, 2, 3 | 1, 2, 3, 2 | 1.4–1.7 (3–4) |
| 3 | 3, 2, 3, 3 | 3, 4, 4, 3 | 1.2–1.7 (3–4) |

Good traits on the whole list: you held 11–24 (usually 15–20), against 12–15
for the AI mean, even when drafting like an AI. The trainer adds about one
synergy (intercept wall or lockdown unit) over the defaults. No career
reached 5 or 6 of 6.
