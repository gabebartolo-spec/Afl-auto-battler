# Managed lists against autopilot, on today's main (2026-10-06)

The director asked whether the autopilot slide to rank 17–20 is right, in the
light of what a club that works its list achieves. Measurement only.

## Method

- **#228's own comparison design**, rerun on today's `main` through
  `tools/audit/dynasty_impl.gd`, a wrapper around `tools/balance/dynasty.gd`
  that adds league margins. It ran on GitHub (`audit.yml`, branch
  `claude/managed-careers`). Eight League Draft careers (seeds 301–308), the
  `upside` drafter on #222's scouted board, coached on match day, five seasons
  each: 40 seasons and 9,464 matches per policy.
  - `none`: autopilot; expiring contracts settle the default way.
  - `list`: each off-season, settle contracts and chase free agents.
  - `full`: `list` plus trading up.
  - Rank is `Squad.strength` among 18–20 clubs; ladder is the home-and-away
    finish.
- **`career_impl` single-lever bots** (seed 1, MEL and COL): `trader` (a trade
  bot each off-season) and `fa` (asking-price free-agent bids), against the
  autopilot rerun (`DIFFICULTY_RERUN_2026-10-06.md`).

## Autopilot against a managed list (dynasty, 8 careers each)

| policy | strength rank Y1 / Y2 / Y3 / Y4 / Y5 | ladder Y1 / Y2 / Y3 / Y4 / Y5 | premierships (of 40) | top-four finishes (of 40) |
|---|---|---|---|---|
| autopilot | 6.8 / 8.8 / 11.5 / 15.1 / **18.4** | 6.4 / 9.1 / 10.5 / 16.0 / 17.0 | 0 | 7 |
| contracts + free agency | 6.8 / 7.5 / 6.4 / 6.9 / **6.4** | 6.4 / 8.2 / 6.2 / 8.2 / 6.4 | 0 | 17 |
| + trading up | 6.8 / 7.1 / 6.5 / 7.6 / **8.8** | 6.4 / 6.5 / 7.0 / 5.0 / 6.9 | 3 (Y4, Y4, Y5) | 20 |

Per managed off-season: about 8.5 re-signed, 3.2 released, 3 free-agent bids
(1.2 signed). Trades with `full` average just 0.1 a season.

**Margins** (every match in those leagues), 60+ / 80+ / 100+ / 120+ / 150+:
autopilot 10.2 / 3.1 / 0.63 / 0.10 / 0.01%; list 9.3 / 2.6 / 0.53 / 0.06 /
0%; full 9.4 / 2.8 / 0.48 / 0.07 / 0.01%. They're essentially the same: how
you manage doesn't change how lopsided the league's matches are.

## Then and now (#228's table at `727e4eb`)

| | autopilot | contracts + FA | + trading up |
|---|---|---|---|
| strength rank Y1 → Y5, then | 6.8 → 10.9 | 6.8 → 5.8 | 6.8 → 3.4 |
| strength rank Y1 → Y5, now | 6.8 → **18.4** | 6.8 → 6.4 | 6.8 → 8.8 |
| premierships, then (of 40) | 2 | 4 | 11 |
| premierships, now (of 40) | 0 | 0 | 3 |
| trades per off-season, then → now | – | – | 0.6 → 0.1 |

## Single-lever bots (career_impl, seed 1): best-22 OVR rank Y1–Y5

| club | autopilot (`ai`) | `trader` | `fa` |
|---|---|---|---|
| MEL | 1, 4, 14, 18, 20 | 1, 3, 10, 18, 20 | 1, 12, 18, 19, 20 |
| COL | 1, 8, 15, 18, 20 | 1, 1, 3, 12, 20 | 1, 1, 3, 15, 20 |

One lever alone delays the slide by a season or two but doesn't stop it; both
bots still finish at rank 20.

## Where the gap comes from

**Contracts.** Settling contracts each off-season (about 8.5 re-signings and 3
releases, plus a free agent a year) alone holds a club around 6th for five
years, while autopilot slides to 18th. Trading up now adds flags (3 in 40
seasons) rather than rank, since only about 0.1 trades a season get through
after #224's discount and #228's trade fixes; it was 0.6. Free agency or trades
on their own don't stop the slide. In-season development is at parity
throughout.

## Reading for the director

- The autopilot slide to 17–20 is steeper than at #228 (10.9 → 18.4). But a
  club that does the routine off-season work holds around 6th, so the slide
  measures neglect of contracts, not an unwinnable game.
- Winning flags now needs more than routine management: none in 40 seasons
  for contracts + FA, 3 for full management. Before #224/#228 that was 4 and 11.
- Whether "routine management holds 6th, flags need more" is the intended
  difficulty is the director's call.
