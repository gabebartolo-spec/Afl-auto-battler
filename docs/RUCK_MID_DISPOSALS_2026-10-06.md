# Where rucks' and midfielders' disposals go (18 + 5), 2026-10-06

Diagnosis only. Nothing in the game changes here; the director decides on any calibration.

- **Script:** `tools/audit/ruckmid_impl.gd`.
- **Run:** audit run 37405960786 on main after #331 (18 + 5).
- **Sample:** three drafted leagues (drafts 21–23), one home-and-away season each.
- **Method:** every match is stepped chain by chain, so the script samples time on ground.
- **Real 2026 figures:** from `tools/balance/afl_role_rates.json`.

## Per player-game, sim (real 2026)

| stat | DEF | MID | FWD | RUCK |
|---|---|---|---|---|
| disposals | **20.1** (16.6) | 21.3 (20.5) | 10.3 (11.7) | **7.9** (12.5) |
| kicks | 11.6 (10.6) | 11.7 (10.6) | 5.8 (7.1) | 4.4 (6.2) |
| handballs | 8.4 (6.0) | 9.6 (9.9) | 4.5 (4.6) | 3.6 (6.3) |
| clearances | 0.25 (0.53) | 3.9 (3.2) | 0.47 (0.67) | **5.2** (3.6) |
| hitouts | 0.0 (0.08) | 0.18 (0.02) | 0.10 (0.48) | 22.4 (21.1) |
| marks | 4.6 (5.1) | 4.5 (3.6) | 4.0 (3.6) | 2.0 (2.5) |
| tackles | 1.9 (1.8) | 4.4 (3.6) | 1.8 (2.2) | 2.6 (2.6) |
| inside 50s | **0.55** (1.55) | 3.8 (3.4) | 3.5 (2.2) | 0.65 (1.9) |
| rebound 50s | 4.8 (3.2) | 0.53 (1.48) | 0.10 (0.34) | 0.29 (0.98) |
| centre bounce attendances | 0.6 | 10.4 | 1.4 | 16.1 |
| time on ground (share of chains) | 83% | 76% | 82% | **65%** |

The data has no contested and uncontested possession split, neither in the sim's box score nor in `afl_role_rates.json`, so that comparison can't be made.

## Stoppage chains (49,070 clearances)

| role | wins the clearance | has the chain's first disposal |
|---|---|---|
| DEF | 5% | **36%** |
| MID | 65% | 35% |
| FWD | 9% | 25% |
| RUCK | 22% | **4%** |

**The clearance winner has the chain's first disposal 6% of the time.**

## What it says

1. **The ruck wins clearances but doesn't get the disposal.**
   - The sim credits the clearance in `MatchSim._stoppage` and stops there.
   - The chain's first disposal comes from a fresh `pick_carrier` over everyone on the ground, weighted by line (`CARRY_ROLES`).
   - So the player who won the ball out of the stoppage almost never disposes of it.
   - In AFL a clearance is the disposal out of the stoppage. If the clearance winner kept the ball, a ruck's 5.2 clearances a game would be roughly the 4.5 disposals he is short of real.
   - He is also over real on clearances (5.2 against 3.6), because CLEARANCE_ROLES weights RUCK equal to MID.
2. **Defenders pick up what the ruck loses.**
   - DEF have 36% of first disposals from stoppages.
   - DEF have full weight in the middle zone (`CARRY_ROLES["middle"]` DEF 1.0).
   - They run 3.5 disposals over real.
   - Their inside 50s (0.55 against 1.55) and rebounds (4.8 against 3.2) show their ball is won and used too deep.
3. **The ruck is off the ground more:** 65% of chains, against 76–83% for the other lines. That is about 15% fewer chances. It is a smaller share of his gap than point 1.
4. **Midfielders are about right in volume:** 21.3 against 20.5 disposals, with clearances and tackles a little high.

## A correction to the earlier holding-the-ball re-measure

The disposals per player-game in "Re-measured on 18 + 5" (FREE_KICKS_2026-10-06.md, #355) were counted from kick and handball events. A kick that is marked is logged as a `mark` event, not a `kick` event, so those counts miss every marked kick. They come out about 17% below the box score, about evenly across lines: DEF 16.6 against 20.1, MID 17.6 against 21.3, FWD 8.4 against 10.3, RUCK 6.7 against 7.9.

- **Holds:** the comparison between lines and the reading that the defenders' extra holding-the-ball frees are a per-disposal effect. The per-100 holding-the-ball rates there use the same event count, so they read about a sixth high in absolute terms.
- **Does not hold:** the statements that midfielders are under real and that team disposals are about 12% low. From the box score, a side's disposals are about real (roughly 365 a team a match against 367), and the gap is that the ruck's share goes to defenders.

## Not done

No change to the sim. Any of the following is a director decision, and each would need a calibration and finals re-run:

- the clearance winner keeping the first disposal;
- the clearance weights;
- the defenders' middle-zone carrying weight;
- the ruck's rotations.

## After: the clearance winner takes the first disposal (director, 2026-10-06)

The director chose option 1. `MatchSim.clearance_keeps` makes it the rule on claude/clearance-keeps; the old rule is kept only as the audit baseline.

**Runs:** 37407388468 (new rule) and 37407395096 (old rule), four drafted leagues (21–24), `ruckmid_impl`.

**Per player-game:** new rule (old rule), real 2026

| stat | DEF | MID | FWD | RUCK |
|---|---|---|---|---|
| disposals | 19.2 (20.1), real 16.6 | 22.6 (21.3), real 20.5 | 9.5 (10.3), real 11.7 | **12.0** (8.0), real 12.5 |
| clearances | 0.25 (0.25), real 0.53 | 3.8 (3.9), real 3.2 | 0.47 (0.48), real 0.67 | 5.3 (5.2), real 3.6 |
| inside 50s | 0.62 (0.54), real 1.55 | 4.3 (3.9), real 3.4 | 2.8 (3.5), real 2.2 | 1.5 (0.66), real 1.9 |
| marks | 4.4 (4.6), real 5.1 | 4.7 (4.5), real 3.6 | 3.8 (4.0), real 3.6 | 2.7 (2.0), real 2.5 |
| holding the ball against, per 100 disposals | 2.07 (1.95) | 1.35 (1.39) | 1.75 (1.70) | 1.03 (1.26) |

- **The clearance winner keeps it:** he has the chain's first disposal 83% of the time (6% before).
- **First disposal from a stoppage, by line:** DEF 14%, MID 56%, FWD 13%, RUCK 17%. Before: DEF 36%, MID 35%, FWD 25%, RUCK 4%.

**What moved**
- **Ruck:** his disposals are now about real (12.0 against 12.5). His inside 50s and marks moved towards real too.
- **Defenders:** they lose a disposal (20.1 to 19.2) but are still 2.6 over real. Their holding-the-ball rate is unchanged within noise (about 2 per 100).
- **Midfielders:** they gain 1.3 disposals and are now 2.2 over real.
- **Forwards:** they lose 0.8 and are 2.2 under real.
- **Unchanged:** time on ground (ruck 65%), hitouts and tackles.

**Not changed, for the director:**
- The ruck still wins too many clearances (5.3 against 3.6), because `CLEARANCE_ROLES` gives RUCK the same weight as MID. Trimming that weight would bring both the ruck and the midfield nearer real.
- Defenders' middle-zone carrying (2.6 disposals over) and forwards' volume are the other gaps.
- Calibration (17 checks) still passes under the rule.
