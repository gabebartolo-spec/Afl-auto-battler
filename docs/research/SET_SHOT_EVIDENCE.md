# Set shots, pack contests and crumbs: what is published

Evidence for ARD-M4-013. Research only; every number names its source, and anything
without a public source is listed at the end, not guessed.

Sources:
- [ABC] Atkinson and Lawson, "Is goalkicking accuracy in the AFL at its lowest point? What makes players miss their shots at goal?", ABC News, 13 June 2025, https://www.abc.net.au/news/2025-06-13/afl-analysis-cody-and-sean-on-goalkicking-accuracy/105412832. Champion Data, 2021 to 2025.
- [AND] Anderson et al., "Factors Affecting Set Shot Goal-kicking Performance in the Australian Football League", https://pubmed.ncbi.nlm.nih.gov/29886806/ (full text https://vuir.vu.edu.au/37434/7/05-14-18%20AFL%20Goal%20Kicking%20Submitted.pdf).
- [SDI] "Shots at goal in Australian Football: Historical trends, determinants of accuracy and common strategies", Journal of Science and Medicine in Sport 27(5): 354-359 (2024), https://www.sciencedirect.com/science/article/pii/S1440244024000756. 20 AFL seasons.
- [WH] Wheeloratings.com, the Champion Data player download (https://www.wheeloratings.com/afl_stats.html), fetched 2026-10-06 and stored as `docs/research/wheelo/afl_player_stats_<year>.json`. Per-game averages; players with 10 or more games; a game-weighted mean. Reproduced by the tables below from those files.

## Set shots: conversion by distance and angle [ABC]

Goals per shot, set shots, 2021 to 2025. Accuracy includes misses. Angle is more than 30 degrees, wide more than 60 degrees. Wide angles at very short and very long range are left out by the source for lack of shots; the source's long-range row (over 50 m) has three cells.

| Distance | Wide left | Angle left | Straight | Angle right | Wide right |
|---|---|---|---|---|---|
| 0 to 10 m | | 81% | 100% | 87% | |
| 10 to 20 m | 66% | 86% | 96% | 80% | 55% |
| 20 to 30 m | 44% | 66% | 85% | 64% | 39% |
| 30 to 40 m | 37% | 51% | 71% | 51% | 31% |
| 40 to 50 m | 28% | 38% | 54% | 39% | 22% |
| Over 50 m | | 28% | 33% | 24% | |

Shots in general play (not set shots), same source and period:

| Distance | Wide left | Angle left | Straight | Angle right | Wide right |
|---|---|---|---|---|---|
| 0 to 10 m | | 72% | 89% | 67% | |
| 10 to 20 m | 21% | 54% | 63% | 50% | 22% |
| 20 to 30 m | 20% | 40% | 51% | 37% | 20% |
| 30 to 40 m | 21% | 29% | 38% | 29% | 18% |
| 40 to 50 m | 23% | 31% | 39% | 29% | 25% |
| Over 50 m | | 25% | 34% | 25% | |

- **By distance alone** [AND]: kicking accuracy fell with distance, from 97% (0 to 15 m) to 36% (50 m or more). Key forwards were more accurate.
- **What predicts a shot** [SDI]: arc angle and shot type predict a shot's outcome with 60.3% classification accuracy; the total number of shots a match and shot accuracy have not changed in two decades.
- **Set against general play, in the tables above:** at 20 to 30 m straight, a set shot goals 85% and a general-play shot 51%. Over 50 m, set 33% and general 34%. So the set-shot advantage is real up to about 40 m and gone at long range.

## What share of shots are set shots [WH]

From the Champion Data expected-score shot counts of players with 10 or more games: set shots 5,951 and general-play shots 4,908 in 2026 (55% set), and 5,450 against 4,642 in 2025 (54% set).

## Goals per shot by position [WH], 2026 (2025 in the second table)

| Position | Shots a game | Goals per shot |
|---|---|---|
| Key forward | 3.26 | 53% |
| General forward | 2.08 | 49% |
| Mid-forward | 1.34 | 48% |
| Midfielder | 0.99 | 44% |
| Ruck | 0.91 | 47% |
| General defender | 0.29 | 37% |
| Key defender | 0.16 | 43% |

2025: key forward 2.92 shots and 56%; general forward 1.98 and 49%; mid-forward 1.60 and 44%; midfielder 0.90 and 42%.

## Marks, spoils and crumbs by position [WH]

| Position | Marks inside 50 a game | Contested marks a game | Spoils a game | Crumbing possessions a game | Crumbs, share of ground-ball gets |
|---|---|---|---|---|---|
| Key forward | 2.10 | 1.09 | 0.99 | 0.66 | 29% |
| General forward | 0.84 | 0.20 | 0.38 | 1.16 | 33% |
| Mid-forward | 0.47 | 0.17 | 0.34 | 1.09 | 23% |
| Midfielder | 0.32 | 0.17 | 0.47 | 1.09 | 20% |
| Ruck | 0.48 | 0.72 | 1.87 | 0.48 | 14% |
| General defender | 0.09 | 0.26 | 1.67 | 0.99 | 29% |
| Key defender | 0.08 | 0.79 | 4.93 | 0.71 | 26% |

2026 per-game averages, 472 players. In 2025 (462 players) the shape is the same: general forwards 1.12 crumbing possessions and 33% of their ground-ball gets, key forwards 0.60 and 26%, key defenders 5.17 spoils a game. A crumb is "a type of groundball-get that is won by a player at ground level after a marking contest" (AFL stats glossary, https://www.afl.com.au/news/144837/stats-glossary-every-stat-explained).

- **Small forwards crumb most:** the general forwards (the closest position in the data to small forwards) are first for crumbing possessions a game (1.16) and for crumbs as a share of their ground-ball gets (33%), ahead of midfielders (1.09 and 20%) and key forwards (0.66 and 29%).
- **Spoilers:** key defenders spoil 4.93 times a game, five times a key forward (0.99).

## Not found (left out)

- How often a set shot is played on rather than kicked from the mark. [AND] defines the cases it excluded (the player moved off his line or the umpire called play on) but the public excerpts give no rate.
- How often a long kick inside 50 is "bombed" into the pack instead of shot at. Champion Data records an inside 50 bomb kick metric (INSIDE_50_KICK_BOMB, https://docs.api.afl.championdata.com/blog/) but publishes no rate.
- How often a long kick inside 50 into a pack is marked, spoiled or comes to ground, as shares of entries. No public source gives the split; only the counts by position above.
- The share of all goals that are crumbs or ground-ball goals after a spoil. The data has crumbing possessions and goals separately, not goals from crumbs.
