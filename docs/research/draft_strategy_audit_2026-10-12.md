# Draft strategy audit: do AI clubs that build from scratch end up weaker than the real 2026 lists?

Roadmap row 37 (director, 2026-10-12). **Audit only: no balance change is made or proposed here.**
Script: `tools/audit/draft_strategy_impl.gd`; tables: `tools/audit/draft_strategy_agg.py`.
Runs: 8 audit runs on CI at commit adb868c9 (see "Runs" at the end).

## Method

1. **Autopilot careers** of 10 seasons, 4 seeds (11 to 14), two starts with the same seeds and the same user club per seed: *redraft* (the League Draft, all 18 clubs built from scratch by the AI) and *real* (the real 2026 lists, the real 2026 class through the 2026 National Draft, then play on). Every later National Draft is run by the AI in both. The user's own club is left unmanaged in an autopilot career, so it is dropped from every end-of-season table (17 AI clubs per seed, 68 club-seasons per row).
2. **Measures** per club: best 23 (mean OVR of the top 23), depth (players 24-38, and 24-32 like for like once lists shrink), age brackets (under 23, 23 to 29, 30+), mean POT of the under-23s, and the engine's own squad strength (`Squad.strength()`, the figure the board ranks clubs by). League means are over seeds, with the standard error over the 4 seeds.
3. **Baselines**: A is the real 2026 lists before the 2026 draft (retired gone, delisted free, club-tied draftees on). Gaps to A at season ends mix the league's in-season growth with the list effect, so the clean comparison is **B minus C**: redraft career minus real-list career at the same moment, paired by seed.
4. **Draft quality**: every AI pick is logged against the best player still on the board, by *worth* (35% OVR + 65% POT from the true ratings, the National Draft's own blend), then split into scouting noise alone, noise plus positional need, and the rest. Every pick is followed one and three seasons on.
5. **Not exercised**: trades and free agency run as the game runs them for AI clubs (not varied); no match-day effect of list differences (strength is measured, not played); four seeds; the user club is not a test of how a human drafts.

## The answer, in plain words

**Lists built from scratch by the AI are not meaningfully weaker than the real lists.**

- At the start of season 1 the redraft league has the same best 23 as the real lists (67.69 against 67.21 before the 2026 draft, 67.67 after it). That is largely forced: both leagues draw on nearly the same pool (best 414 players: 67.76 against 67.74 mean OVR), so the league average cannot move much. What the draft can change is how the pool is shared.
- Redraft minus real-list career, same seeds, best 23: **-0.08 ± 0.07 at the end of season 1, -0.56 ± 0.20 at season 5, +0.14 ± 0.11 at season 10.** Squad strength: -0.56 ± 0.26, 0.00 ± 0.31, -0.05 ± 0.11. A real but small gap through seasons 2 to 3 (-0.4) that closes.
- Depth is the one steady gap. Players 24 to 32: **-1.19 ± 0.05 at season 1, -0.84 ± 0.20 at season 5, -0.68 ± 0.29 at season 10** (24 to 38: -0.89, -0.59, -0.63). Redraft lists also run older: **+0.6 to +0.9 more players aged 30+** at every moment (season 5: +0.61 ± 0.19), and 3.1 fewer under-23s at the start (the redraft pool has no untried listed kids; this closes by season 5).
- Parity is different, not weaker. Real lists are uneven (SD of best 23 across clubs 2.4, best to worst club 8.5 OVR before the 2026 draft). A redraft is much flatter at the start (SD 1.06, best to worst 4.0), then settles near the real-list careers (season 10: 1.68 against 1.77).
- **Both arms** end up about 2.5 OVR above the real 2026 lists at season ends (redraft +2.43 ± 0.08 at season 5, real-list career +2.98 ± 0.13; at season 10 +2.59 against +2.46). That is the league's own in-season growth and renormalisation, not an AI-draft effect: it appears equally when the lists are the real ones.
- **The real-list careers drift away from the real lists fast.** Club order held at season 5 has a rank correlation of only 0.21 with the 2026 order (0.14 at season 10). The weak real lists rise (RIC +7.1, ESS +5.8, WBD +5.1, WCE +4.4 by season 5) and the strong ones come back (SYD +0.8). In 10 seasons AI list management erases the real-world advantages and disadvantages.

**The weak spot is list size and depth, not the draft's top end.** AI lists start at 40 (redraft) or 42 (real) players and fall to 36 to 38.5 by the end of season 1, 33.7 at season 2, and sit on the 32-player floor from season 3 (32.1 to 33.2 for the rest of the decade), in both arms. The National Draft adds only about 2.4 to 3.1 players per club per year (44 to 56 picks per class, 18 clubs), against about seven leaving at the first rollover. The real lists carry 38 to 44. Depth (players 24 to 32) therefore falls from 54 to about 51.4, and under-23 numbers from 13 to 16 at the start to about 8.

## Draft quality (D)

- **How often the AI takes a clearly worse player.** National Draft picks 11 to 30: the pick is on average **5.4 worth-points** below the best player left, and **49% of picks are 5 or more points below** (29% are 8 or more); 4.8 better players are still on the board. Picks 1 to 10: gap 2.8, 23% at 5 or more. Picks 31 to 60: 3.0, 25%. All National picks pooled: about 3.9 points, 34% at 5 or more. In OVR and POT at picks 11 to 30: the pick is 64.9 / 76.5 against 69.2 / 82.8 for the best left.
- **It gets worse as a career goes on:** mean gap 2.0 in the first two drafts (2027 and 2028), 3.0 to 3.7 in 2029 to 2031, 5.3 to 5.7 in 2032 to 2034. The share at 5 or more rises from 12% to 55%.
- **Where it comes from** (10-season totals, picks 11 to 30): scouting noise alone costs 0.69 of the 5.44; noise plus positional need 2.12; the other 3.3 is the scarcity bonus (value over replacement) by elimination, because need and noise are the only other terms in the intake score (cap and club-opinion terms are off in the intake draft). The early drafts are mostly need and noise (1.6 of 2.0); the late-career gap is the scarcity bonus.
- **It does not hurt the players it picks.** Three seasons on, drafted players are not behind the real under-23s: at age 22 they are **70.3 OVR against the real 2026 lists' 57.9 (+12.4)**, 100% still on a list, and a top-10 pick gains +9.3 (71.0 at the pick, 80.4 three seasons on). So the AI's choices are visibly off the board's best, but the classes and the development curve more than carry them. Read the size of that +12 with care: the real 21 to 23 year olds on the 2026 lists average 56 to 60 (below the real 2026 class's 61.1 at the draft), while a drafted player in the sim gains +6.5 in three seasons. That is a question about the youth development model and how real kids were rated, not about the AI's drafting, and it is the director's to judge.
- Class strength: the real 2026 class (top 10: 66.8 OVR / 87.9 POT) sits near the generated classes (2028 on: top 10 69 to 72 / 84 to 86); the 2027 class is the strongest of the decade (75.6 / 89.6).

## Three most likely causes (read from `scripts/sim/Draft.gd`)

1. **Scarcity bonus in the National Draft (value over replacement).** `_ai_score` adds `AI_VORP_WEIGHT` (1.5) times the edge over the replacement at that position, capped at `AI_VORP_CAP` (10 points). In the League Draft that weight ramps in over two rounds; in the National Draft (`_vorp_weight`) it is full from the first pick. A club reaches for a scarce position over the best player on the board. This is the largest piece of the draft gap by subtraction (about 3.3 of 5.4 at picks 11 to 30) and the piece that grows late in a career, as classes thin at some positions.
2. **Positional need as a flat mark-down.** `_need_weight` in intake mode multiplies the whole score by `INTAKE_COVERED` (0.92) for any position the club already has covered. On a worth of 70 that is 5.6 points, so a covered position's best prospect loses to an uncovered position's lesser one. Noise plus need is about 2.1 of the gap.
3. **Value and potential reads.** The intake draft values a prospect by one flat blend (35% OVR, 65% POT) of a scouted read (`DraftScouting.scouted_worth`: OVR SD 2.2, POT SD 3.5, scaled 0.65 to 1.0 by rank), with no age or horizon (the League Draft's `horizon_worth` is not used here). Scouting noise itself is the smallest piece, 0.7 of the gap. The real issue on this side is volume, not read: with only about 2.4 to 3.1 picks per club per year the draft cannot refill lists that retirements and expiring contracts empty, so lists sit at the 32 floor (`Prospects.MIN_LIST`) from season 3 and depth drops.

## What this means for the buff question

No data here supports a general "AI drafts are too weak" buff: best 23 and squad strength match the real lists within about 0.6 OVR, and drafted players outgrow the real kids. If the director wants one change on this evidence, the candidates are (a) cap or ramp the scarcity bonus in the National Draft like the League Draft does, which would close most of the 5.4-point pick gap, and (b) the size of the intake and the list floor (depth, age profile). Neither is applied; both would need paired seeds and a W7 review. Balance is the director's call.

---

# Tables (generated by `tools/audit/draft_strategy_agg.py`; ± is the standard error over 4 seeds)

Notes. "Best-worst club" is the gap between the strongest and weakest club's best 23 in a league, averaged over seeds. The first draft-year in D2 is the real 2026 class; the 2027 class and later are generated. Depth 24-38 is over the players a list has (a 32-player list has 15 fewer than 38), so depth 24-32 is the like-for-like column.

### Seeds and user clubs
real 11: MEL, real 12: COL, real 13: ADE, real 14: CAR, redraft 11: MEL, redraft 12: COL, redraft 13: ADE, redraft 14: CAR

### A. Real lists, pre-draft 2026 lists (mean over 4 run(s))
| Club | List | Best 23 | Depth 24-38 | Under 23 | 23-29 | 30+ | U23 POT | Squad strength |
|---|---|---|---|---|---|---|---|---|
| ADE | 38 | 69.1 | 53.4 | 8 | 26 | 4 | 69.6 | 69.7 |
| BRL | 43 | 68.0 | 53.9 | 13 | 20 | 10 | 73.0 | 70.1 |
| CAR | 37 | 67.7 | 52.0 | 14 | 15 | 8 | 71.2 | 69.4 |
| COL | 38 | 68.3 | 51.8 | 10 | 17 | 11 | 68.9 | 66.7 |
| ESS | 42 | 62.6 | 51.6 | 20 | 19 | 3 | 70.5 | 62.3 |
| FRE | 39 | 69.2 | 53.5 | 10 | 24 | 5 | 66.9 | 70.9 |
| GCS | 40 | 67.7 | 51.3 | 14 | 20 | 6 | 71.9 | 69.3 |
| GEE | 38 | 69.0 | 53.9 | 11 | 20 | 7 | 71.4 | 69.1 |
| GWS | 44 | 70.0 | 53.7 | 20 | 16 | 8 | 68.7 | 68.3 |
| HAW | 39 | 69.3 | 51.7 | 11 | 21 | 7 | 72.6 | 67.8 |
| MEL | 37 | 67.9 | 51.4 | 12 | 17 | 8 | 69.7 | 68.6 |
| NTH | 40 | 67.0 | 51.9 | 18 | 17 | 5 | 72.0 | 68.2 |
| PAD | 40 | 66.0 | 50.5 | 13 | 24 | 3 | 68.8 | 68.0 |
| RIC | 37 | 61.7 | 50.5 | 16 | 16 | 5 | 71.1 | 64.6 |
| STK | 39 | 66.3 | 52.5 | 14 | 17 | 8 | 71.8 | 68.7 |
| SYD | 42 | 70.2 | 55.1 | 12 | 22 | 8 | 68.3 | 70.4 |
| WBD | 38 | 65.7 | 50.1 | 13 | 22 | 3 | 72.3 | 69.4 |
| WCE | 50 | 64.1 | 53.6 | 26 | 21 | 3 | 68.3 | 66.3 |
| **League mean** | 40 | 67.2 | 52.3 | 14 | 20 | 6 | 70.4 | 68.2 |
| **Spread (SD across clubs)** | 3.2 | 2.42 | 1.41 | 4.4 | 3.2 | 2.5 | 1.78 | 2.13 |

### A. Real lists, season-1 start (mean over 4 run(s))
| Club | List | Best 23 | Depth 24-38 | Under 23 | 23-29 | 30+ | U23 POT | Squad strength |
|---|---|---|---|---|---|---|---|---|
| ADE | 41 | 69.5 | 55.3 | 11 | 26 | 4 | 70.9 | 70.6 |
| BRL | 44 | 68.1 | 54.3 | 14 | 20 | 10 | 73.3 | 70.3 |
| CAR | 40 | 68.1 | 53.9 | 17 | 15 | 8 | 72.2 | 69.4 |
| COL | 41 | 68.8 | 53.3 | 13 | 17 | 11 | 70.1 | 68.2 |
| ESS | 44 | 63.3 | 52.4 | 22 | 19 | 3 | 71.6 | 63.4 |
| FRE | 41 | 69.6 | 54.3 | 12 | 24 | 5 | 68.7 | 71.6 |
| GCS | 43 | 68.5 | 52.6 | 17 | 20 | 6 | 72.8 | 70.1 |
| GEE | 40 | 69.5 | 54.7 | 13 | 20 | 7 | 73.0 | 69.2 |
| GWS | 44 | 70.0 | 53.7 | 20 | 16 | 8 | 68.7 | 68.3 |
| HAW | 41 | 69.5 | 53.1 | 13 | 21 | 7 | 73.7 | 68.0 |
| MEL | 40 | 68.3 | 53.2 | 15 | 17 | 8 | 71.0 | 68.8 |
| NTH | 43 | 67.5 | 53.2 | 21 | 17 | 5 | 72.3 | 69.8 |
| PAD | 43 | 66.9 | 52.0 | 16 | 24 | 3 | 70.7 | 68.4 |
| RIC | 40 | 62.7 | 51.9 | 19 | 16 | 5 | 72.2 | 66.2 |
| STK | 42 | 66.7 | 53.8 | 17 | 17 | 8 | 72.4 | 69.0 |
| SYD | 44 | 70.6 | 55.9 | 14 | 22 | 8 | 70.1 | 70.6 |
| WBD | 41 | 66.4 | 51.8 | 16 | 22 | 3 | 72.8 | 69.7 |
| WCE | 50 | 64.1 | 53.6 | 26 | 21 | 3 | 68.3 | 66.3 |
| **League mean** | 42 | 67.7 | 53.5 | 16 | 20 | 6 | 71.4 | 68.8 |
| **Spread (SD across clubs)** | 2.4 | 2.30 | 1.13 | 3.9 | 3.2 | 2.5 | 1.66 | 1.95 |

Baseline used for the gaps: real pre 2026. Best 23 67.21, depth 52.35, U23 POT 70.39, squad strength 68.21; SD of best 23 across clubs 2.42; best-worst club 8.5.

### B. Redraft careers: AI clubs, league mean over seeds (+/- standard error), gap to the real 2026 lists (A)
| Moment | Seeds | List size | Best 23 | Gap to A | Depth 24-38 | Gap to A | Depth 24-32 | Gap to A | U23 POT | Gap to A | Squad strength | Gap to A | U23 count | 30+ count | SD of best 23 across clubs | Best-worst club |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| S1 start | 4 | 40.00 ± 0.00 | 67.69 ± 0.00 | +0.48 | 52.62 ± 0.01 | +0.27 | 54.08 ± 0.02 | +0.36 | 70.43 ± 0.99 | +0.04 | 68.69 ± 0.04 | +0.48 | 13.33 ± 0.00 | 7.06 ± 0.00 | 1.06 ± 0.11 | 4.0 |
| end S1 | 4 | 36.00 ± 0.04 | 69.52 ± 0.06 | +2.32 | 54.14 ± 0.02 | +1.79 | 55.32 ± 0.03 | +1.61 | 70.43 ± 0.97 | +0.03 | 68.97 ± 0.34 | +0.76 | 12.82 ± 0.07 | 5.47 ± 0.09 | 1.28 ± 0.06 | 4.6 |
| end S2 | 4 | 33.79 ± 0.15 | 70.21 ± 0.03 | +3.01 | 53.66 ± 0.06 | +1.32 | 54.43 ± 0.09 | +0.71 | 72.80 ± 0.17 | +2.41 | 70.33 ± 0.23 | +2.12 | 11.08 ± 0.04 | 5.67 ± 0.02 | 1.97 ± 0.05 | 8.3 |
| end S3 | 4 | 32.44 ± 0.06 | 69.72 ± 0.03 | +2.52 | 52.06 ± 0.19 | -0.29 | 52.34 ± 0.22 | -1.38 | 70.34 ± 0.14 | -0.05 | 70.92 ± 0.23 | +2.71 | 10.62 ± 0.13 | 6.07 ± 0.04 | 1.61 ± 0.12 | 5.7 |
| end S4 | 4 | 32.41 ± 0.03 | 70.20 ± 0.07 | +2.99 | 53.25 ± 0.12 | +0.90 | 53.63 ± 0.14 | -0.09 | 69.41 ± 0.14 | -0.98 | 71.78 ± 0.07 | +3.57 | 12.14 ± 0.06 | 5.71 ± 0.08 | 1.95 ± 0.16 | 7.0 |
| end S5 | 4 | 32.34 ± 0.05 | 69.64 ± 0.08 | +2.43 | 51.71 ± 0.17 | -0.64 | 52.04 ± 0.14 | -1.68 | 69.38 ± 0.25 | -1.01 | 72.27 ± 0.23 | +4.06 | 9.71 ± 0.05 | 6.16 ± 0.10 | 1.74 ± 0.21 | 5.9 |
| end S6 | 4 | 32.12 ± 0.04 | 69.78 ± 0.04 | +2.57 | 51.28 ± 0.25 | -1.07 | 51.39 ± 0.23 | -2.33 | 70.68 ± 0.27 | +0.28 | 72.32 ± 0.14 | +4.11 | 8.16 ± 0.04 | 6.59 ± 0.15 | 1.88 ± 0.25 | 6.9 |
| end S7 | 4 | 33.22 ± 0.11 | 69.81 ± 0.03 | +2.61 | 51.46 ± 0.24 | -0.89 | 52.44 ± 0.21 | -1.28 | 72.31 ± 0.25 | +1.91 | 71.97 ± 0.21 | +3.77 | 7.32 ± 0.06 | 6.21 ± 0.06 | 1.95 ± 0.27 | 7.7 |
| end S8 | 4 | 32.13 ± 0.05 | 69.60 ± 0.12 | +2.39 | 50.86 ± 0.36 | -1.49 | 50.99 ± 0.41 | -2.73 | 71.59 ± 0.28 | +1.19 | 72.02 ± 0.37 | +3.81 | 8.09 ± 0.04 | 7.13 ± 0.03 | 2.16 ± 0.23 | 8.4 |
| end S9 | 4 | 32.63 ± 0.02 | 69.75 ± 0.06 | +2.55 | 51.31 ± 0.19 | -1.04 | 51.84 ± 0.23 | -1.88 | 71.75 ± 0.17 | +1.36 | 72.77 ± 0.43 | +4.56 | 8.04 ± 0.08 | 5.92 ± 0.14 | 2.14 ± 0.11 | 8.4 |
| end S10 | 4 | 32.14 ± 0.10 | 69.80 ± 0.07 | +2.59 | 51.34 ± 0.25 | -1.01 | 51.41 ± 0.21 | -2.31 | 70.89 ± 0.43 | +0.49 | 73.16 ± 0.20 | +4.95 | 8.18 ± 0.09 | 6.32 ± 0.15 | 1.68 ± 0.10 | 6.8 |

### C. Real-list careers: AI clubs, league mean over seeds (+/- standard error), gap to the real 2026 lists (A)
| Moment | Seeds | List size | Best 23 | Gap to A | Depth 24-38 | Gap to A | Depth 24-32 | Gap to A | U23 POT | Gap to A | Squad strength | Gap to A | U23 count | 30+ count | SD of best 23 across clubs | Best-worst club |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| S1 start | 4 | 42.33 ± 0.00 | 67.67 ± 0.00 | +0.46 | 53.49 ± 0.00 | +1.14 | 54.78 ± 0.01 | +1.06 | 71.39 ± 0.01 | +0.99 | 68.78 ± 0.02 | +0.57 | 16.44 ± 0.00 | 6.22 ± 0.00 | 2.30 ± 0.01 | 7.9 |
| end S1 | 4 | 38.49 ± 0.06 | 69.61 ± 0.02 | +2.40 | 55.03 ± 0.02 | +2.68 | 56.51 ± 0.04 | +2.80 | 71.47 ± 0.01 | +1.08 | 69.53 ± 0.20 | +1.32 | 16.29 ± 0.11 | 4.62 ± 0.10 | 2.37 ± 0.08 | 7.8 |
| end S2 | 4 | 33.65 ± 0.08 | 70.59 ± 0.03 | +3.38 | 54.38 ± 0.05 | +2.03 | 55.14 ± 0.09 | +1.42 | 72.17 ± 0.12 | +1.78 | 71.33 ± 0.31 | +3.13 | 12.75 ± 0.07 | 5.01 ± 0.10 | 3.20 ± 0.09 | 10.4 |
| end S3 | 4 | 32.26 ± 0.05 | 70.12 ± 0.05 | +2.91 | 52.75 ± 0.09 | +0.40 | 52.91 ± 0.12 | -0.80 | 69.53 ± 0.18 | -0.87 | 71.49 ± 0.28 | +3.28 | 12.49 ± 0.07 | 5.22 ± 0.05 | 2.51 ± 0.06 | 8.1 |
| end S4 | 4 | 32.58 ± 0.04 | 70.09 ± 0.04 | +2.88 | 53.29 ± 0.15 | +0.94 | 53.71 ± 0.15 | -0.00 | 69.12 ± 0.07 | -1.27 | 72.36 ± 0.13 | +4.16 | 12.58 ± 0.05 | 5.03 ± 0.07 | 2.19 ± 0.03 | 8.1 |
| end S5 | 4 | 32.76 ± 0.08 | 70.19 ± 0.13 | +2.98 | 52.30 ± 0.20 | -0.05 | 52.88 ± 0.13 | -0.84 | 70.17 ± 0.19 | -0.22 | 72.26 ± 0.30 | +4.06 | 9.34 ± 0.06 | 5.55 ± 0.14 | 1.37 ± 0.06 | 5.1 |
| end S6 | 4 | 32.11 ± 0.05 | 69.99 ± 0.06 | +2.78 | 51.36 ± 0.15 | -0.98 | 51.44 ± 0.17 | -2.28 | 70.08 ± 0.40 | -0.32 | 72.74 ± 0.19 | +4.53 | 8.11 ± 0.02 | 6.03 ± 0.05 | 1.31 ± 0.07 | 4.7 |
| end S7 | 4 | 33.17 ± 0.12 | 69.91 ± 0.09 | +2.70 | 51.91 ± 0.03 | -0.44 | 52.90 ± 0.12 | -0.82 | 71.79 ± 0.18 | +1.40 | 72.48 ± 0.19 | +4.27 | 7.21 ± 0.04 | 5.41 ± 0.10 | 1.34 ± 0.06 | 6.0 |
| end S8 | 4 | 32.30 ± 0.11 | 69.64 ± 0.06 | +2.44 | 51.25 ± 0.22 | -1.10 | 51.50 ± 0.28 | -2.22 | 71.28 ± 0.25 | +0.89 | 72.37 ± 0.50 | +4.16 | 8.16 ± 0.05 | 6.39 ± 0.05 | 1.32 ± 0.08 | 5.9 |
| end S9 | 4 | 32.59 ± 0.05 | 69.79 ± 0.04 | +2.58 | 51.49 ± 0.20 | -0.86 | 51.93 ± 0.18 | -1.78 | 72.07 ± 0.27 | +1.67 | 72.95 ± 0.22 | +4.74 | 7.89 ± 0.05 | 5.38 ± 0.11 | 1.43 ± 0.07 | 5.7 |
| end S10 | 4 | 32.17 ± 0.06 | 69.67 ± 0.06 | +2.46 | 51.96 ± 0.10 | -0.39 | 52.09 ± 0.13 | -1.63 | 70.87 ± 0.26 | +0.48 | 73.21 ± 0.16 | +5.00 | 8.21 ± 0.07 | 5.43 ± 0.07 | 1.77 ± 0.06 | 6.9 |

### B minus C, paired by seed (redraft minus real-list career, same seed, same user club), +/- standard error
| Moment | List size | Best 23 | Depth 24-38 | Depth 24-32 | U23 POT | Squad strength | U23 count | 30+ count |
|---|---|---|---|---|---|---|---|---|
| S1 start | -2.33 ± 0.00 | +0.01 ± 0.00 | -0.87 ± 0.01 | -0.70 ± 0.02 | -0.95 ± 0.99 | -0.09 ± 0.05 | -3.11 ± 0.00 | +0.83 ± 0.00 |
| end S1 | -2.49 ± 0.04 | -0.08 ± 0.07 | -0.89 ± 0.04 | -1.19 ± 0.05 | -1.05 ± 0.98 | -0.56 ± 0.26 | -3.47 ± 0.09 | +0.85 ± 0.17 |
| end S2 | +0.14 ± 0.18 | -0.38 ± 0.06 | -0.72 ± 0.07 | -0.71 ± 0.14 | +0.63 ± 0.14 | -1.00 ± 0.47 | -1.67 ± 0.06 | +0.65 ± 0.12 |
| end S3 | +0.18 ± 0.07 | -0.39 ± 0.05 | -0.69 ± 0.20 | -0.57 ± 0.25 | +0.81 ± 0.19 | -0.57 ± 0.24 | -1.86 ± 0.18 | +0.85 ± 0.07 |
| end S4 | -0.17 ± 0.04 | +0.11 ± 0.04 | -0.04 ± 0.12 | -0.08 ± 0.12 | +0.29 ± 0.06 | -0.58 ± 0.18 | -0.43 ± 0.04 | +0.68 ± 0.13 |
| end S5 | -0.42 ± 0.09 | -0.56 ± 0.20 | -0.59 ± 0.24 | -0.84 ± 0.20 | -0.79 ± 0.16 | +0.00 ± 0.31 | +0.37 ± 0.07 | +0.61 ± 0.19 |
| end S6 | +0.01 ± 0.04 | -0.22 ± 0.07 | -0.08 ± 0.17 | -0.05 ± 0.16 | +0.60 ± 0.16 | -0.42 ± 0.21 | +0.05 ± 0.02 | +0.57 ± 0.17 |
| end S7 | +0.05 ± 0.18 | -0.10 ± 0.12 | -0.45 ± 0.26 | -0.46 ± 0.28 | +0.52 ± 0.16 | -0.51 ± 0.13 | +0.11 ± 0.06 | +0.80 ± 0.13 |
| end S8 | -0.17 ± 0.12 | -0.04 ± 0.17 | -0.39 ± 0.35 | -0.51 ± 0.39 | +0.30 ± 0.06 | -0.35 ± 0.74 | -0.07 ± 0.05 | +0.74 ± 0.04 |
| end S9 | +0.04 ± 0.06 | -0.03 ± 0.09 | -0.17 ± 0.21 | -0.10 ± 0.21 | -0.31 ± 0.14 | -0.19 ± 0.28 | +0.14 ± 0.08 | +0.54 ± 0.16 |
| end S10 | -0.03 ± 0.10 | +0.14 ± 0.11 | -0.63 ± 0.29 | -0.68 ± 0.29 | +0.02 ± 0.22 | -0.05 ± 0.11 | -0.03 ± 0.11 | +0.88 ± 0.20 |

### C. Per-club drift of AI management from the real lists (best 23, mean over non-user seeds)
| Club | A (S1 start) | S3 end | S5 end | S10 end | drift S5 | drift S10 |
|---|---|---|---|---|---|---|
| ADE | 69.5 | 73.9 | 72.2 | 69.4 | +2.7 | -0.1 |
| BRL | 68.1 | 69.1 | 69.5 | 71.0 | +1.3 | +2.8 |
| CAR | 68.1 | 69.1 | 70.2 | 68.7 | +2.0 | +0.6 |
| COL | 68.8 | 67.8 | 67.6 | 69.4 | -1.1 | +0.7 |
| ESS | 63.3 | 67.0 | 69.1 | 70.6 | +5.8 | +7.3 |
| FRE | 69.6 | 73.2 | 71.1 | 70.9 | +1.5 | +1.3 |
| GCS | 68.5 | 72.4 | 71.3 | 68.9 | +2.8 | +0.4 |
| GEE | 69.5 | 72.3 | 71.4 | 69.2 | +1.9 | -0.3 |
| GWS | 70.0 | 69.8 | 69.5 | 69.9 | -0.4 | -0.1 |
| HAW | 69.5 | 70.0 | 69.6 | 69.1 | +0.1 | -0.4 |
| MEL | 68.3 | 71.2 | 69.4 | 68.1 | +1.0 | -0.3 |
| NTH | 67.5 | 70.8 | 70.4 | 67.9 | +2.8 | +0.4 |
| PAD | 66.9 | 72.1 | 71.4 | 69.3 | +4.5 | +2.4 |
| RIC | 62.7 | 66.8 | 69.8 | 69.0 | +7.1 | +6.3 |
| STK | 66.7 | 71.6 | 71.0 | 68.1 | +4.2 | +1.3 |
| SYD | 70.6 | 71.8 | 71.4 | 69.7 | +0.8 | -0.9 |
| WBD | 66.4 | 71.2 | 71.4 | 69.7 | +5.1 | +3.4 |
| WCE | 64.1 | 65.9 | 68.6 | 69.9 | +4.4 | +5.8 |

Club order held: rank correlation of best 23 with the start, S5 0.21, S10 0.14. Mean absolute drift S5 2.77, S10 1.93.

### Pools the two starts draw on (mean OVR of the best 414 players, and of all)
- real seed 11: 762 players, best 414 mean 67.74, all mean 60.67
- real seed 12: 762 players, best 414 mean 67.74, all mean 60.66
- real seed 13: 762 players, best 414 mean 67.74, all mean 60.67
- real seed 14: 762 players, best 414 mean 67.74, all mean 60.67
- redraft seed 11: 725 players, best 414 mean 67.76, all mean 60.91
- redraft seed 12: 725 players, best 414 mean 67.76, all mean 60.91
- redraft seed 13: 725 players, best 414 mean 67.76, all mean 60.91
- redraft seed 14: 725 players, best 414 mean 67.76, all mean 60.91

### D1. AI picks against the best player on the board (worth = 35% OVR + 65% POT from true values, no scouting noise; League Draft: the draft's own worth)
| Draft | Pick band | Picks | Gap to best (mean) | of which scouting noise alone | noise + position need | Gap 3+ | Gap 5+ | Gap 8+ | Higher-worth players left (mean) | Pick OVR | Best OVR left | Pick POT | Best POT left |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| National, all careers | 1-10 | 714 | 2.82 | 0.54 | 2.40 | 40% | 23% | 7% | 3.0 | 71.5 | 74.4 | 85.3 | 88.5 |
| National, all careers | 11-30 | 1443 | 5.44 | 0.69 | 2.12 | 62% | 49% | 29% | 4.8 | 64.9 | 69.2 | 76.5 | 82.8 |
| National, all careers | 31-60 | 1510 | 3.04 | 0.71 | 1.66 | 38% | 25% | 13% | 2.6 | 58.4 | 61.0 | 66.2 | 69.9 |
| 2026 class (real-list start) | 1-10 | 37 | 1.43 | 0.61 | 1.89 | 19% | 14% | 0% | 2.0 | 66.8 | 68.6 | 87.9 | 89.6 |
| 2026 class (real-list start) | 11-30 | 83 | 2.58 | 0.74 | 2.08 | 46% | 14% | 0% | 2.7 | 61.2 | 63.0 | 77.8 | 80.9 |
| 2026 class (real-list start) | 31-60 | 44 | 2.12 | 1.44 | 1.89 | 32% | 9% | 0% | 2.8 | 55.4 | 56.5 | 67.0 | 69.7 |
| League Draft (redraft) | 1-10 | 40 | 1.27 | - | - | 8% | 5% | 2% | 4.2 | 87.5 | 91.5 | 92.6 | 96.0 |
| League Draft (redraft) | 11-30 | 80 | 3.41 | - | - | 46% | 29% | 14% | 13.3 | 81.5 | 90.5 | 89.8 | 95.4 |
| League Draft (redraft) | 31-60 | 120 | 3.22 | - | - | 33% | 25% | 12% | 13.6 | 78.8 | 89.5 | 86.5 | 91.8 |
| League Draft (redraft) | 61-end | 2640 | 3.63 | - | - | 49% | 27% | 10% | 40.2 | 59.2 | 78.3 | 66.6 | 79.3 |

### D2. Class strength by draft year (picks per career; redraft and real-list careers pooled)
| Draft year | Picks | Top 10 picks: OVR / POT | All picks: OVR / POT | Mean age |
|---|---|---|---|---|
| 2026 (real class) | 41 | 66.8 / 87.9 | 60.9 / 77.2 | 18.8 |
| 2027 | 45 | 75.6 / 89.6 | 67.7 / 78.8 | 19.6 |
| 2028 | 52 | 69.9 / 86.1 | 61.4 / 72.8 | 19.7 |
| 2029 | 50 | 69.1 / 84.1 | 61.7 / 72.9 | 19.6 |
| 2030 | 47 | 71.6 / 84.9 | 63.8 / 74.6 | 19.8 |
| 2031 | 52 | 70.9 / 84.0 | 63.7 / 73.4 | 19.4 |
| 2032 | 50 | 71.1 / 84.2 | 64.1 / 74.5 | 19.5 |
| 2033 | 52 | 71.0 / 84.6 | 63.3 / 73.4 | 19.6 |
| 2034 | 55 | 72.2 / 85.8 | 63.5 / 73.9 | 19.6 |
| 2035 | 56 | 72.1 / 84.8 | 63.1 / 72.2 | 19.6 |

### D3. Drafted players three seasons on, against the real 2026 lists' players of the same age
| Age three seasons on | Drafted | Still on a list | OVR of those still listed | Real 2026 lists, same age: players | Real OVR | Gap |
|---|---|---|---|---|---|---|
| 20 | 25 | 100% | 71.4 | 80 | 53.9 | +17.5 |
| 21 | 136 | 100% | 68.3 | 73 | 56.3 | +12.0 |
| 22 | 1361 | 100% | 70.3 | 46 | 57.9 | +12.4 |
| 23 | 1192 | 100% | 69.7 | 71 | 59.5 | +10.2 |
| 24 | 223 | 98% | 68.6 | 58 | 61.0 | +7.6 |
| 25 | 4 | 100% | 53.2 | 44 | 62.6 | -9.3 |

Same cohort by class (three seasons on, those still listed):
| Class | Drafted | OVR at the pick | Age at the pick | OVR three seasons on | Age then | Rise |
|---|---|---|---|---|---|---|
| 2026 (the real class) | 161 | 61.1 | 18.8 | 68.8 | 20.8 | +7.7 |
| 2027 (first generated) | 357 | 67.7 | 19.6 | 72.5 | 22.6 | +4.8 |
| 2028 and later (generated) | 2413 | 63.0 | 19.6 | 69.5 | 22.6 | +6.5 |

Same cohort by pick band (three seasons on; OVR/POT at the pick are for those still listed):
| Pick band | Drafted | Still listed | OVR at the pick | OVR three seasons on | POT at the pick | Rise |
|---|---|---|---|---|---|---|
| 1-10 | 593 | 100% | 71.0 | 80.4 | 85.5 | +9.3 |
| 11-30 | 1206 | 100% | 64.7 | 72.0 | 76.6 | +7.3 |
| 31-60 | 1142 | 99% | 58.3 | 62.0 | 66.4 | +3.7 |

Real 2026 lists by age (players, OVR, POT): 18: 6, 57.2, 69.5; 19: 50, 54.3, 73.6; 20: 80, 53.9, 69.1; 21: 73, 56.3, 71.2; 22: 46, 57.9, 67.8; 23: 71, 59.5, 69.0; 24: 58, 61.0, 67.1; 25: 44, 62.6, 68.3; 26: 293, 65.1, 66.0

## Runs

`gh workflow run audit.yml --ref claude/draft-audit -f impl=draft_strategy_impl -f args="<redraft|real> <seed> <club> 10"`, commit adb868c9. Run ids (artifact `audit-draft_strategy_impl`): redraft seed 11 (user MEL) 38239547442, real 11 38239554822, redraft 12 (COL) 38239562820, real 12 38239570906, redraft 13 (ADE) 38239578015, real 13 38239586015, redraft 14 (CAR) 38239593354, real 14 38239599970. Earlier batches of the same seeds on earlier commits of the script gave identical numbers (the audit is deterministic), with the extra columns added later; a 4-season batch (38238637767 to 38238687541) produced the first noise-plus-need split.

Aggregate: `python -I tools/audit/draft_strategy_agg.py <dir of downloaded logs>`.
