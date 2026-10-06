# Free kicks against real AFL (ARD-M3-007, 2026-10-06)

Measurement only, on `main`. `tools/audit/freekick_impl.gd` (branch
`claude/freekick-audit`, run on GitHub via `audit.yml`) played 8 drafted
leagues, one home-and-away season each through `Season.play_round`: 1,728
matches (3,456 team-games). Real 2026 figures come from the shipped player
data (`ff`/`fa` per player-game; the role as the game derives it).

**Headline.** The league rate is right, but the causes and who gets them
aren't. Frees per team per match: sim 17.6, real 18.7 (0.94; calibration
already checks this). But **39% of frees are the generic "General
infringement"**, a post-chain clanger roll with no football cause, and **rucks
win and concede half the real rate**. There is no ruck-contest infringement.

## Cause mix (per team per match)

| cause | share | per team a match |
|---|---|---|
| General infringement (generic clanger → free) | 39.3% | 6.43 |
| Holding the ball | 39.1% | 6.39 |
| Marking contest (holding or blocking) | 12.3% | 2.01 |
| High contact | 9.3% | 1.52 |

Caused frees are 93% of frees for; out-on-the-full and last-disposal frees
come through the boundary path and make up most of the rest.

The generic share is `MatchSim`'s post-chain path: a clanger becomes a free
with probability `clanger_is_free × GENERIC_FREE_MULT`, paid as "general".
That's the "generic clanger outcome" ARD-M3-007 says to replace.

## By role (frees for / against a player-game)

| role | sim | real 2026 |
|---|---|---|
| MID | 1.05 / 0.94 | 0.90 / 0.86 |
| FWD | 0.63 / 0.57 | 0.81 / 0.74 |
| DEF | 0.78 / 0.90 | 0.63 / 0.73 |
| RUCK | **0.71 / 0.74** | **1.44 / 1.36** |

Midfielders and defenders are over, forwards under, and rucks about half. The
generic path picks the offender from the whole ground by clanger weight, which
spreads frees toward the high-possession lines. In real AFL, ruck contests
produce a large share of rucks' frees (blocking, holding, third-man up),
forwards earn more in marking contests and leads, and none of that is modelled
apart from the marking-contest cause.

## Who gives frees away

Sim against real 2026 frees-against per game (419 players with 10+ sim games
and 8+ real): Spearman 0.37 (Pearson 0.46). Frees against tracks the
discipline attribute (Spearman −0.50 in the sim). A real undisciplined player
stays relatively undisciplined, but only moderately, since 39% of frees are
assigned by the generic clanger weight.

## Whether a mechanic change is indicated (BALANCE-GATED, lead's decision)

Yes, a targeted one; the league rate shouldn't move:

1. **A ruck-contest infringement cause** at stoppages (the ruck contest
   already resolves `_contestant` against `_contestant`): rucks' free rates
   double toward 1.4 a game, from the generic share.
2. **Shift part of the generic share** into contexts the event model already
   has: more marking-contest frees (forwards' leads and contests), and holding
   the ball in the tackle path. Keep the total near 17.6–18.7.
3. **Leave discipline's influence as it is** (−0.50); it shouldn't dominate.

Validation: this audit before and after, plus the calibration "frees for"
check, plus margins unchanged (frees feed scoring through possession and 50s).

## After the change (contextual-frees PR, 2026-10-06)

The generic free keeps its rate; its cause now follows the chain: a ball-up
chain's free is often the ruck contest (`RUCK_FREE_SHARE`, genuine
ruckmen only, paid at the stoppage; see the revision below); in the receiving side's forward 50 it is
usually a forward held in a marking contest by a defender
(`F50_MARK_FREE_SHARE` 0.85); otherwise incorrect disposal by the player who
erred. New picks use `free_rng` only. Two drafted leagues, same seeds:

| | before | after | real 2026 |
|---|---|---|---|
| frees per team a match | 17.6 | 17.64 | 18.7 |
| general infringement | 39% | 0% | - |
| marking-contest frees per team | 2.01 | 2.53 | - |
| ruck contest frees per team | 0 | 0.99 | - |
| RUCK for / against a game | 0.71 / 0.74 | **1.47 / 1.41** | 1.44 / 1.36 |
| FWD for / against | 0.63 / 0.57 | 0.60 / 0.51 | 0.81 / 0.74 |
| MID for / against | 1.05 / 0.94 | 0.97 / 0.85 | 0.90 / 0.86 |
| DEF for / against | 0.78 / 0.90 | 0.73 / 0.90 | 0.63 / 0.73 |

League scoring on the same base commit (4 drafted leagues, 864 matches):
points a team per match 84.7 → 85.3, goals 12.57 → 12.68, margins unchanged
(100+ 0.2% both). Calibration 17/0.

Not solved here: forwards' total frees-for stays about 0.6 a game (real 0.81).
Their marking-contest frees rose, but some of what they used to get from the
generic pool now goes to rucks. Lifting it further means touching the
marking-contest odds in `resolve_forward50`/`_marking_free`, which belong to
the forward-archetype work.

### Revised after merging main with #286 (forward archetypes)

Paying a ruck free back at the stoppage after the chain had moved up the
ground made the pitch view fly the ball 30 m+ backwards (match_visual). A
ruck free is now paid only when the chain ended within 15 m of the contest
(`RUCK_FREE_REACH`), and `RUCK_FREE_SHARE` rises from 0.48 to 0.90 to keep
the rate. Four drafted leagues (drafts 21-24, 1,728 team-games) on main
with #286:

| | after #286, 0.48 share | revised | real 2026 |
|---|---|---|---|
| frees per team a match | 17.73 | 17.68 | 18.7 |
| ruck contest frees per team | 0.74 | 0.79 | - |
| RUCK for / against a game | 1.26 / 1.24 | 1.32 / 1.28 | 1.44 / 1.36 |
| FWD for / against | 0.62 / 0.51 | 0.63 / 0.52 | 0.81 / 0.74 |

match_game 240/0, match_visual 93/0, calibration 17/0.

## Re-measured on 18 + 5 (2026-10-06)

Source: audit run 37404572905 (branch `claude/htb-audit`, `tools/audit/htb_impl.gd`), on main after #331 (18 on the ground, five on the bench). Four drafted leagues (drafts 21 to 24), one home-and-away season each. Measurement only; the director decides on any calibration.

**Holding-the-ball frees given away, per 100 disposals**, by where the player had the ball:

| role | own 50 | back half | front half | forward 50 | all |
|---|---|---|---|---|---|
| DEF | 2.09 | 2.73 | 2.06 | 1.22 | 2.36 |
| MID | 1.36 | 2.11 | 1.66 | 1.36 | 1.72 |
| FWD | 2.42 | 2.47 | 2.18 | 1.42 | 2.06 |
| RUCK | 1.49 | 1.64 | 1.40 | 0 | 1.48 |

Before #331 the all-ground figures were DEF 2.35 and MID 1.68, so the rates are unchanged.

**Disposals per player-game, the sim against real 2026** (`tools/balance/afl_role_rates.json`):

| role | sim | real 2026 |
|---|---|---|
| DEF | 16.6 | 16.58 |
| MID | 17.6 | 20.46 |
| FWD | 8.4 | 11.72 |
| RUCK | 6.7 | 12.49 |

Disposal counts here are from kick/handball events and miss marked kicks (about 17% low); see [RUCK_MID_DISPOSALS_2026-10-06.md](RUCK_MID_DISPOSALS_2026-10-06.md).

**Reading.** The defenders' excess of holding-the-ball frees is per disposal, and it peaks in the back half. The larger gap to real football is disposal volume for midfielders, forwards and rucks, not the free-kick rate.
