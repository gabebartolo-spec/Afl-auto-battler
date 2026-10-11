# Season fitness audit (2026-10-11)

Evidence for the season conditioning model (spec: agent-handoffs/lead/season_fitness_spec.md;
code: `scripts/sim/Conditioning.gd`; audit: `tools/audit/conditioning_impl.gd`). All runs are
seeded and paired: the same seeds played with and without the change. Every figure is a mean
± one standard error. Balance is not settled by this; it is one input.

## How the curve reaches a match

A club's plan gives one number a week, from -1 (building hard) to +1 (at its peak). Steady is 0
every week and stamps nothing, so a Steady club plays exactly the game as it was. The number
reaches a match only through three stamps on each listed player:

| Lever | At the peak (c = 1) | Building hard (c = -0.5) |
|---|---|---|
| Tiring rate (`cond_drain`, the MatchSim drain line) | 15% slower | 7.5% faster |
| Legs off the energy cap (`cond_cap`) | up to 8 of the season's load given back, never above fresh | 2 off |
| Soft-tissue risk (`cond_injury`) | x0.75 | x1.125 |

The tiring multiplier also scales the match exertion that Workload carries into next week, on
purpose: a side building hard carries more load from week to week, a peaked side less (dev-sim
review of #650).

The department (high performance: Minimal, Standard, Strong, Elite) sets the peak's height
(0.6, 0.8, 0.9, 1.0 of the full peak) and how precisely it lands (timing spread 4, 3, 2, 1 weeks).

## Byte-identical when everyone is Steady

`checksum` (one seeded home-and-away season, 207 matches, every result hashed):
hash 333725435 on main, on the hooks-only commit and on the full model with every club Steady
(runs 38078963346 at 1ae70caf, 38081921687 at fb2f1a06). Main has moved since; the PR body carries
the current pair of runs.

## Step 0: what each lever is worth in a match

`sens`: 1,500 paired matches an arm (six fixed pairings x 250 seeds), every home player stamped.

| Arm | Home margin a match | Home injuries a match | Run |
|---|---|---|---|
| Tiring x1.15 | -2.30 ± 0.96 | +0.01 ± 0.00 | 38080405718 |
| Tiring x0.85 | +0.37 ± 0.94 | -0.01 ± 0.00 | 38081138037 |
| 4 legs off the cap | -3.13 ± 0.99 | +0.00 ± 0.00 | 38080412319 |
| 12 legs off the cap | -5.00 ± 1.06 | +0.01 ± 0.00 | 38080407468 |
| Soft-tissue risk x1.25 | inside its error | +0.18 ± 0.03 | (n=240 run) |
| The game's peak stamps, fresh legs | +0.10 ± 0.95 | -0.19 ± 0.01 | 38081904955 |
| The game's building stamps | -1.92 ± 0.98 | +0.10 ± 0.01 | 38081906814 |
| The game's develop stamps | +0.52 ± 0.98 | -0.05 ± 0.01 | 38081908418 |
| The peak stamps, both sides carrying a load of 40 | +9.47 ± 1.08 | -0.07 ± 0.01 | 38082752462 |

What it says: tiring faster and losing legs cost points; tiring slower on fresh legs is worth
almost nothing (fresh is fresh). A peak's upside therefore lives in the legs a season's load has
taken, which is why the peak gives back up to 8 legs of load (747da280).

## The finals edge, with the legs sides actually carry in September

The load-40 row above overstates a peak: it loads every player on both sides to 40. At the end of
a real home-and-away season the 22 most loaded players on each top-eight list carry
7.58 ± 0.20 (cap about 97), so a peak has little load to give back.

`finals TIER 9` (head 8977fcca): nine all-Steady seasons to the end of round 24, then the top
eight play each other (every ordered pair, three match seeds) twice, the home side unstamped and
then carrying a Peak for September stamp at its department's seeded timing in finals weeks
24-27; 1,512 paired games an arm.

| Arm | Finals margin a game | Home injuries a game | Mean curve | Run |
|---|---|---|---|---|
| Standard department, the game's levers | **+3.44 ± 1.00** | -0.14 ± 0.01 | 0.73 | 38099654768 |
| Elite department, the game's levers | **+4.97 ± 1.00** | -0.19 ± 0.01 | 0.99 | 38099656420 |
| Standard, tiring lever doubled (0.30) | +4.64 ± 1.03 | -0.14 ± 0.01 | 0.73 | 38099658093 |
| Standard, tiring lever 0.50 | +7.11 ± 1.01 | -0.17 ± 0.01 | 0.73 | 38099660016 |

What it says: a side that peaks on time against a Steady side gets about half a goal a finals
game at a Standard department and close to a goal at Elite, and loses fewer players. That sits
in the spec's "a few points a game" (BOSS's aim, 2 to 4) at Standard; Elite is a point above it,
inside one error. The levers are kept as they are: **BOSS accepted 2026-10-11** (Elite is a paid department and should be worth more); revisit if play shows finals decided by fitness. A bigger tiring lever would buy a bigger
edge (about +1.2 points for each extra 0.15).

## Whole seasons, finals included

`league PLAN TIER 16`: each seed plays the season twice, every club Steady at Standard, then a
seeded half of the clubs on the plan; 144 treated club-seasons. Head 747da280.

| | Peak, Minimal | Peak, Standard | Peak, Elite | Fast start | Develop |
|---|---|---|---|---|---|
| Wins R1-8 | -0.13 ± 0.15 | -0.13 ± 0.15 | -0.14 ± 0.16 | +0.12 ± 0.14 | -0.09 ± 0.15 |
| Wins R9-16 | -0.26 ± 0.15 | -0.16 ± 0.14 | -0.24 ± 0.14 | -0.10 ± 0.16 | -0.31 ± 0.13 |
| Wins R17-24 | +0.04 ± 0.16 | +0.01 ± 0.16 | +0.13 ± 0.15 | +0.00 ± 0.16 | +0.06 ± 0.14 |
| H&A margin a game | -1.52 ± 0.87 | -1.09 ± 0.87 | -0.88 ± 0.77 | -0.40 ± 0.82 | -1.26 ± 0.72 |
| Finals wins | +0.00 ± 0.09 | +0.04 ± 0.11 | +0.08 ± 0.09 | -0.07 ± 0.08 | -0.04 ± 0.09 |
| Finals margin a game (n) | -1.46 ± 4.09 (55) | +1.23 ± 4.50 (51) | +2.52 ± 3.97 (55) | -3.98 ± 3.67 (54) | +1.53 ± 3.41 (59) |
| Soft-tissue injuries a season | +0.35 ± 0.11 | +0.33 ± 0.11 | +0.19 ± 0.11 | -0.15 ± 0.13 | -0.54 ± 0.09 |
| Young players' growth a player | -0.00 | -0.00 | -0.00 | +0.00 | +0.88 ± 0.01 (Steady +2.97) |
| Actual peak week | 23.76 ± 0.30 | 23.97 ± 0.24 | 23.99 ± 0.09 | 1.92 ± 0.18 | none |

Runs: 38082759285, 38082754887, 38082757179, 38082763609, 38082761503.

The league finals margin is too noisy to read (±4 points, about 50 clubs that made the finals in
both runs, half the opponents also on the plan). The finals section above measures the edge
directly instead.

## AI clubs by phase

`phase 12` (the game's own choice, 72 club-seasons a phase; run 38082765637):

| Phase | Plan | Actual peak week | H&A wins | Finals wins | Soft-tissue |
|---|---|---|---|---|---|
| Contending | Peak for September (72) | 23.60 ± 0.30 | +0.14 ± 0.35 | +0.14 ± 0.15 | +0.44 ± 0.15 |
| Building | Steady (72) | none | -0.62 ± 0.39 | -0.19 ± 0.17 | -0.10 ± 0.15 |
| Rebuilding | Develop and manage (72) | none | +0.56 ± 0.38 | +0.06 ± 0.07 | -0.50 ± 0.11 |

Contenders peak late, as the spec asks. In this PR AI plans are off (BOSS, 2026-10-11): every
club plays Steady until the plan screen lets you choose yours; the screen PR turns them on.

## Fixed after qa's early W7 (run 38099601775)

Develop and manage's extra point of season room now needs the plan in force since the
pre-season or the club's bye. A switch to Develop in the last month buys no room (test in the
`fitness` suite). A club that develops from the pre-season, then switches to a peak at round 14,
keeps what its kids already gained; its peak builds only 65% of its height (the late-change cost).

## Open for BOSS

Develop and manage costs -1.26 ± 0.72 points a home-and-away game for +0.88 a young player's
growth (Steady +2.97). It may be the obvious pick for any non-contender; held for the director
with the plan screen.

## Not exercised

- AI departments are fixed at Standard (a known parity gap: AI clubs cannot invest).
- AI clubs revise only at round 14.
- Stamps stay on players over the off-season (harmless: restamped before round 1).
- Your club's weekly training (heavy, closed, development weeks) on top of a plan.
