# Coleman and goalkicker plausibility (2026-10-06)

Roadmap §1.11, "Coleman / individual goalkicker plausibility audit". The phone
case was Brodie Kemp leading the Coleman with 48 goals at Round 18.

**Leaders are credible and middling forwards do not become spearheads. One
real defect:** elite forwards saturate the goalkicking attribute at 99, so
the engine cannot tell a 3.5-goal-a-game forward from a 2.1. Among them, the
Coleman goes to whoever leads on marking and OVR. Nothing is changed here;
the fix is a ratings change for the director (below).

## Method

`tools/audit/coleman_impl.gd`: 12 drafted leagues (draft seeds 41–52), one
home-and-away season each through `Season.play_round` → MatchSim, the same
path as Sim round. The Coleman counts the home-and-away season only. Games
are rounds in which a player took the field (the match roster). "Real" means
the player's 2026 season in the shipped data (`gl / gm`).
`tools/audit/gk_cap_impl.gd` reads the goalkicking attribute across the
pool.

## Coleman leaders

| league | leader | goals | per game | real per game | goalkicking / marking / OVR | share of club goals |
|---|---|---|---|---|---|---|
| 41 | Josh Treacy | 89 | 3.71 | 2.15 | 99 / 96 / 93 | 27% |
| 42 | Josh Treacy | 65 | 2.71 | 2.15 | 99 / 96 / 93 | 20% |
| 43 | Ben King | 62 | 2.58 | 2.61 | 99 / 71 / 77 | 20% |
| 44 | Shannon Neale | 65 | 2.71 | 2.08 | 99 / 82 / 91 | 17% |
| 45 | Josh Treacy | 61 | 2.54 | 2.15 | 99 / 96 / 93 | 21% |
| 46 | Josh Treacy | 74 | 3.08 | 2.15 | 99 / 96 / 93 | 21% |
| 47 | Josh Treacy | 64 | 2.67 | 2.15 | 99 / 96 / 93 | 17% |
| 48 | Jack Gunston | 59 | 2.46 | 3.47 | 99 / 77 / 82 | 16% |
| 49 | Shannon Neale | 104 | 4.33 | 2.08 | 99 / 82 / 91 | 32% |
| 50 | Josh Treacy | 73 | 3.04 | 2.15 | 99 / 96 / 93 | 22% |
| 51 | Jye Amiss | 61 | 2.54 | 2.48 | 99 / 85 / 85 | 20% |
| 52 | Charlie Curnow | 65 | 2.71 | 3.13 | 99 / 86 / 89 | 22% |

The winning tally averaged 70.2 (min 59, median 65, max 104). The real
2026 leader (Curnow) kicked 75, finals included.

## What holds

- **Credible profiles lead.** Every winner and every top-five finisher is a
  genuine key or general forward. Top-five finishers averaged 2.20 real goals
  a game against 1.52 for all forwards, and goalkicking 94.7 against 66.5.
- **No middling forward becomes a spearhead.** Zero 50-goal seasons came from
  a player under 1.0 real goals a game (8+ real games).
- **Strong real scorers are not suppressed.** Of 228 player-seasons from real
  2.0+ goals-a-game scorers, 2 kicked under 1.0 a game.
- **The model tracks real scoring:** across 1,219 forward player-seasons,
  simulated goals a game against real goals a game gives Spearman 0.66
  (Pearson 0.62), and against the goalkicking attribute 0.71.
- **Kemp's case is legitimate.** He was 1.56 a game in real 2026 (39 from
  25) and listed FWD, and he finished 2nd or 3rd here twice (59 goals). A
  redraft can hand him the opportunity.

## The defect: the goalkicking attribute saturates

`Ratings.build_norm_params` scales each per-game rate linearly against the
**98th percentile of the whole pool** and clamps at 1.0. For
`goals_pg` and `marks_inside50_pg`, that pool is mostly midfielders and
defenders, so every forward in the top 2% clamps:

| goalkicking | players (8+ real games) |
|---|---|
| 99 | 10 |
| 95–98 | 4 |
| 90–94 | 7 |

The ten at 99 range from 3.47 real goals a game (Gunston) to 2.13
(Waterman, Naughton). Curnow (3.13), Morris (2.76), King (2.61) and Treacy
(2.15) all read the same 99. Once goalkicking is equal, marking and overall
decide who gets and converts the shots. Treacy has the highest marking of
the group (96) and the highest OVR (93), so he **wins 6 of 12 Colemans**,
while the two most prolific real scorers (Gunston and Curnow) win one each.
Logan Morris, 2nd in real 2026, never finishes top three.

The same compression explains the shape of the season tallies:

| per league season | 60+ goals | 50–59 | 40–49 | 30–39 |
|---|---|---|---|---|
| simulated (home and away) | 2.0 | 6.1 | 17.1 | 32.8 |
| real 2026 (finals included) | 6 | 7 | 10 | 29 |

The middle is fat and the top thin. With the elite indistinguishable on
goalkicking, goals spread across the capped group rather than concentrating
on the true outliers, and the occasional runaway (Neale 104, 32% of his
club's goals) comes from team opportunity rather than a scoring edge.

## Recommendation (BALANCE-GATED, director's call; not started)

Give the scoring metrics headroom above the 98th percentile. For example,
normalise `goals_pg` and `marks_inside50_pg` against the pool maximum (or the
99.5th percentile) for the goalkicking attribute only, so 3.5 and 2.1 goals a
game no longer both read 99. This re-rates every key forward's goalkicking
and therefore forward OVR (goalkicking is 0.30 of the forward core), so it
needs the normal balance gate: OVR-vs-strength calibration (ARD-M5-010),
league scoring, the Coleman distribution above, and a check that the 98th-
percentile cap is not saturating other attributes the same way (`ruck` from
hit-outs is the obvious candidate).
