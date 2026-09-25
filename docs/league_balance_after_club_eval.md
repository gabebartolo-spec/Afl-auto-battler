# League balance after club-specific evaluation

The baseline harness ([LEAGUE_BALANCE.md](LEAGUE_BALANCE.md)) re-run with the same seeds after club-specific draft evaluation shipped (U[1,5]). Compare with [league_balance_baseline.md](league_balance_baseline.md). Real-list shards are the baseline's (no draft; engine unchanged). Sensitivity was not re-run (engine unchanged).


Shards: /tmp/claude-0/-home-user-Afl-auto-battler/1390778d-3e0d-57a9-9763-59c1ed245edc/scratchpad/after/bcareer.json, /tmp/claude-0/-home-user-Afl-auto-battler/1390778d-3e0d-57a9-9763-59c1ed245edc/scratchpad/after/bdrafted_a.json, /tmp/claude-0/-home-user-Afl-auto-battler/1390778d-3e0d-57a9-9763-59c1ed245edc/scratchpad/after/bdrafted_b.json, /tmp/claude-0/-home-user-Afl-auto-battler/1390778d-3e0d-57a9-9763-59c1ed245edc/scratchpad/after/bdrafted_c.json, /tmp/claude-0/-home-user-Afl-auto-battler/1390778d-3e0d-57a9-9763-59c1ed245edc/scratchpad/after/bdrafted_d.json, /tmp/claude-0/-home-user-Afl-auto-battler/1390778d-3e0d-57a9-9763-59c1ed245edc/scratchpad/after/career.json, /tmp/claude-0/-home-user-Afl-auto-battler/1390778d-3e0d-57a9-9763-59c1ed245edc/scratchpad/after/drafted_a.json, /tmp/claude-0/-home-user-Afl-auto-battler/1390778d-3e0d-57a9-9763-59c1ed245edc/scratchpad/after/drafted_b.json, /tmp/claude-0/-home-user-Afl-auto-battler/1390778d-3e0d-57a9-9763-59c1ed245edc/scratchpad/after/drafted_c.json, /tmp/claude-0/-home-user-Afl-auto-battler/1390778d-3e0d-57a9-9763-59c1ed245edc/scratchpad/after/drafted_d.json, /tmp/claude-0/-home-user-Afl-auto-battler/1390778d-3e0d-57a9-9763-59c1ed245edc/scratchpad/after/real_a.json, /tmp/claude-0/-home-user-Afl-auto-battler/1390778d-3e0d-57a9-9763-59c1ed245edc/scratchpad/after/real_b.json  
Total shard runtime: 5082 s (sum over shards)

## Drafted league: career draft, your picks by the board policy (Season/MatchSim)

Draft seeds: 16; seasons: 48 (201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216)

Distinct leagues (same 18 lists regardless of club names count once): 16

### Preseason strength distribution (per league)

| Measure | Mean | Min | Max |
|---|---|---|---|
| Squad.strength spread (strongest − weakest) | 9.42 | 5.82 | 12.41 |
| Squad.strength SD across clubs | 2.53 | 1.82 | 3.24 |
| Selected-22 mean OVR spread | 4.65 | 4.14 | 5.14 |
| Selected-22 mean OVR SD across clubs | 1.11 | 0.82 | 1.31 |

### Match outcomes (home and away, n = 10368)

| Measure | Value (95% CI) |
|---|---|
| Home win (decided games) | 59.4% (58.5–60.4) |
| Draw rate | 1.2% (1.0–1.4) |
| Stronger side wins (Squad.strength, decided) | 57.4% (56.4–58.3) |
| Stronger side wins (selected-22 OVR, decided) | 53.2% (52.2–54.1) |

Favourite win rate by preseason gap:

| Squad.strength gap | Fav wins | n | | Selected-22 OVR gap | Fav wins | n |
|---|---|---|---|---|---|---|
| 0.0–1.0 | 51.1% (49.0–53.2) | 2194 | | 0.0–0.5 | 50.7% (48.8–52.6) | 2589 |
| 1.0–2.0 | 54.3% (52.1–56.4) | 2099 | | 0.5–1.0 | 53.7% (51.7–55.7) | 2434 |
| 2.0–3.0 | 57.1% (54.8–59.4) | 1728 | | 1.0–1.5 | 54.8% (52.5–57.0) | 1861 |
| 3.0–4.0 | 58.1% (55.5–60.6) | 1453 | | 1.5–2.0 | 56.1% (53.2–58.9) | 1156 |
| 4.0–6.0 | 62.1% (59.9–64.4) | 1749 | | 2.0–3.0 | 55.9% (53.3–58.5) | 1390 |
| 6.0+ | 68.6% (65.6–71.3) | 1021 | | 3.0+ | 46.0% (42.3–49.7) | 694 |

| Margin measure | Value |
|---|---|
| Mean / median / 90th percentile | 26.6 / 22 / 55 |
| 40+ points | 23.5% (22.7–24.4) |
| 60+ points | 7.7% (7.2–8.2) |
| 80+ points | 1.7% (1.5–2.0) |
| 100+ points | 0.4% (0.3–0.5) |

### Preseason strength → season outcome

| Measure (per season, mean ± SD across seasons) | Value |
|---|---|
| Pearson r: Squad.strength vs wins | 0.48 ± 0.16 |
| Pearson r: Squad.strength vs percentage | 0.57 ± 0.15 |
| Spearman ρ: strength rank vs ladder position | 0.48 ± 0.18 |
| Pooled R² of wins on league-centred strength | 0.24 |

Skill vs luck (same lists replayed with new season seeds; 16 leagues with 2+ seasons):

| Measure | Value |
|---|---|
| Luck SD of a club's season wins (within-club) | 2.34 wins |
| Skill SD (between-club, net of luck) | 2.25 wins |
| Share of season-win variance that is skill | 47.9% (per league: 22–75%) |

Excluding your (board-policy) club - the 17 AI-drafted clubs only:

| Measure | Value |
|---|---|
| Squad.strength SD across clubs (mean) | 2.50 |
| Stronger side wins (Squad.strength, decided, AI v AI) | 57.1% (56.1–58.2) |
| Pearson r: Squad.strength vs wins | 0.49 ± 0.18 |

Skill vs luck, AI-drafted clubs only (same lists replayed with new season seeds; 16 leagues with 2+ seasons):

| Measure | Value |
|---|---|
| Luck SD of a club's season wins (within-club) | 2.34 wins |
| Skill SD (between-club, net of luck) | 2.16 wins |
| Share of season-win variance that is skill | 46.1% (per league: 25–69%) |

Outcome frequency by preseason strength rank (1 = strongest):

| Rank | Premiership | Finals (top 10) | Wooden spoon |
|---|---|---|---|
| 1 | 29.2% | 97.9% | 0.0% |
| 2 | 14.6% | 89.6% | 0.0% |
| 3 | 2.1% | 81.2% | 4.2% |
| 4 | 12.5% | 87.5% | 0.0% |
| 5 | 10.4% | 52.1% | 4.2% |
| 6 | 14.6% | 72.9% | 0.0% |
| 7 | 6.2% | 66.7% | 2.1% |
| 8 | 2.1% | 56.2% | 2.1% |
| 9 | 0.0% | 50.0% | 10.4% |
| 10 | 2.1% | 45.8% | 2.1% |
| 11 | 0.0% | 52.1% | 2.1% |
| 12 | 2.1% | 52.1% | 4.2% |
| 13 | 0.0% | 33.3% | 8.3% |
| 14 | 4.2% | 43.8% | 12.5% |
| 15 | 0.0% | 35.4% | 12.5% |
| 16 | 0.0% | 35.4% | 4.2% |
| 17 | 0.0% | 18.8% | 12.5% |
| 18 | 0.0% | 29.2% | 18.8% |

(Each rank has 48 club-seasons: one per season.)

Your club (the board-policy drafter; with policy ai, the first pick of the order):

| Draft seed | Season seed | Club | Strength rank | Ladder | Wins |
|---|---|---|---|---|---|
| 201 | 201001 | RIC | 7 | 5 | 14 |
| 201 | 201002 | RIC | 7 | 17 | 8 |
| 201 | 201003 | RIC | 7 | 5 | 13 |
| 202 | 202001 | GEE | 1 | 10 | 12 |
| 202 | 202002 | GEE | 1 | 6 | 13 |
| 202 | 202003 | GEE | 1 | 3 | 14 |
| 203 | 203001 | MEL | 7 | 11 | 9 |
| 203 | 203002 | MEL | 7 | 14 | 10 |
| 203 | 203003 | MEL | 7 | 17 | 7 |
| 204 | 204001 | RIC | 1 | 2 | 16 |
| 204 | 204002 | RIC | 1 | 3 | 14 |
| 204 | 204003 | RIC | 1 | 2 | 15 |
| 205 | 205001 | MEL | 15 | 18 | 1 |
| 205 | 205002 | MEL | 15 | 18 | 6 |
| 205 | 205003 | MEL | 15 | 18 | 4 |
| 206 | 206001 | SYD | 12 | 14 | 10 |
| 206 | 206002 | SYD | 12 | 17 | 8 |
| 206 | 206003 | SYD | 12 | 7 | 13 |
| 207 | 207001 | FRE | 3 | 18 | 6 |
| 207 | 207002 | FRE | 3 | 18 | 4 |
| 207 | 207003 | FRE | 3 | 14 | 9 |
| 208 | 208001 | WBD | 7 | 5 | 14 |
| 208 | 208002 | WBD | 7 | 12 | 11 |
| 208 | 208003 | WBD | 7 | 13 | 11 |
| 209 | 209001 | PAD | 15 | 18 | 7 |
| 209 | 209002 | PAD | 15 | 4 | 14 |
| 209 | 209003 | PAD | 15 | 11 | 12 |
| 210 | 210001 | GCS | 7 | 10 | 12 |
| 210 | 210002 | GCS | 7 | 6 | 13 |
| 210 | 210003 | GCS | 7 | 8 | 13 |
| 211 | 211001 | BRL | 18 | 18 | 7 |
| 211 | 211002 | BRL | 18 | 18 | 5 |
| 211 | 211003 | BRL | 18 | 18 | 2 |
| 212 | 212001 | GCS | 18 | 18 | 5 |
| 212 | 212002 | GCS | 18 | 16 | 8 |
| 212 | 212003 | GCS | 18 | 14 | 10 |
| 213 | 213001 | NTH | 11 | 9 | 11 |
| 213 | 213002 | NTH | 11 | 7 | 13 |
| 213 | 213003 | NTH | 11 | 12 | 10 |
| 214 | 214001 | SYD | 2 | 15 | 9 |
| 214 | 214002 | SYD | 2 | 3 | 15 |
| 214 | 214003 | SYD | 2 | 4 | 15 |
| 215 | 215001 | BRL | 5 | 4 | 15 |
| 215 | 215002 | BRL | 5 | 10 | 12 |
| 215 | 215003 | BRL | 5 | 14 | 10 |
| 216 | 216001 | WCE | 5 | 17 | 7 |
| 216 | 216002 | WCE | 5 | 15 | 9 |
| 216 | 216003 | WCE | 5 | 14 | 10 |

## Drafted league: all-AI career draft (Season/MatchSim)

Draft seeds: 16; seasons: 48 (101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116)

Distinct leagues (same 18 lists regardless of club names count once): 16

### Preseason strength distribution (per league)

| Measure | Mean | Min | Max |
|---|---|---|---|
| Squad.strength spread (strongest − weakest) | 9.10 | 6.42 | 12.34 |
| Squad.strength SD across clubs | 2.49 | 1.66 | 3.11 |
| Selected-22 mean OVR spread | 3.24 | 2.23 | 4.41 |
| Selected-22 mean OVR SD across clubs | 0.95 | 0.76 | 1.23 |

### Match outcomes (home and away, n = 10368)

| Measure | Value (95% CI) |
|---|---|
| Home win (decided games) | 59.9% (58.9–60.8) |
| Draw rate | 1.2% (1.0–1.4) |
| Stronger side wins (Squad.strength, decided) | 57.6% (56.6–58.5) |
| Stronger side wins (selected-22 OVR, decided) | 55.5% (54.6–56.5) |

Favourite win rate by preseason gap:

| Squad.strength gap | Fav wins | n | | Selected-22 OVR gap | Fav wins | n |
|---|---|---|---|---|---|---|
| 0.0–1.0 | 51.0% (49.0–53.1) | 2226 | | 0.0–0.5 | 54.0% (52.1–56.0) | 2519 |
| 1.0–2.0 | 53.8% (51.5–56.1) | 1839 | | 0.5–1.0 | 53.4% (51.5–55.3) | 2600 |
| 2.0–3.0 | 56.0% (53.8–58.1) | 2008 | | 1.0–1.5 | 53.6% (51.4–55.7) | 2013 |
| 3.0–4.0 | 58.4% (55.8–61.0) | 1389 | | 1.5–2.0 | 58.0% (55.5–60.4) | 1539 |
| 4.0–6.0 | 63.8% (61.6–66.0) | 1886 | | 2.0–3.0 | 61.7% (59.0–64.4) | 1259 |
| 6.0+ | 70.5% (67.4–73.4) | 897 | | 3.0+ | 65.3% (58.3–71.6) | 193 |

| Margin measure | Value |
|---|---|
| Mean / median / 90th percentile | 26.6 / 22 / 55 |
| 40+ points | 23.7% (22.9–24.5) |
| 60+ points | 7.5% (7.0–8.0) |
| 80+ points | 1.8% (1.5–2.0) |
| 100+ points | 0.3% (0.2–0.5) |

### Preseason strength → season outcome

| Measure (per season, mean ± SD across seasons) | Value |
|---|---|
| Pearson r: Squad.strength vs wins | 0.50 ± 0.17 |
| Pearson r: Squad.strength vs percentage | 0.56 ± 0.16 |
| Spearman ρ: strength rank vs ladder position | 0.48 ± 0.17 |
| Pooled R² of wins on league-centred strength | 0.26 |

Skill vs luck (same lists replayed with new season seeds; 16 leagues with 2+ seasons):

| Measure | Value |
|---|---|
| Luck SD of a club's season wins (within-club) | 2.22 wins |
| Skill SD (between-club, net of luck) | 2.48 wins |
| Share of season-win variance that is skill | 55.5% (per league: 37–71%) |

Outcome frequency by preseason strength rank (1 = strongest):

| Rank | Premiership | Finals (top 10) | Wooden spoon |
|---|---|---|---|
| 1 | 25.0% | 93.8% | 0.0% |
| 2 | 12.5% | 93.8% | 0.0% |
| 3 | 4.2% | 66.7% | 2.1% |
| 4 | 12.5% | 79.2% | 2.1% |
| 5 | 0.0% | 68.8% | 6.2% |
| 6 | 16.7% | 72.9% | 4.2% |
| 7 | 6.2% | 54.2% | 0.0% |
| 8 | 2.1% | 56.2% | 6.2% |
| 9 | 8.3% | 66.7% | 2.1% |
| 10 | 2.1% | 60.4% | 6.2% |
| 11 | 6.2% | 64.6% | 2.1% |
| 12 | 0.0% | 35.4% | 2.1% |
| 13 | 0.0% | 33.3% | 4.2% |
| 14 | 0.0% | 45.8% | 6.2% |
| 15 | 2.1% | 35.4% | 12.5% |
| 16 | 2.1% | 31.2% | 8.3% |
| 17 | 0.0% | 27.1% | 10.4% |
| 18 | 0.0% | 14.6% | 25.0% |

(Each rank has 48 club-seasons: one per season.)

## Real 2026 club lists (Season/MatchSim)

Draft seeds: 1; seasons: 16 (one list set)

### Preseason strength distribution (per league)

| Measure | Mean | Min | Max |
|---|---|---|---|
| Squad.strength spread (strongest − weakest) | 8.43 | 8.43 | 8.43 |
| Squad.strength SD across clubs | 2.25 | 2.25 | 2.25 |
| Selected-22 mean OVR spread | 8.18 | 8.18 | 8.18 |
| Selected-22 mean OVR SD across clubs | 2.38 | 2.38 | 2.38 |

### Match outcomes (home and away, n = 3456)

| Measure | Value (95% CI) |
|---|---|
| Home win (decided games) | 58.8% (57.2–60.5) |
| Draw rate | 1.2% (0.9–1.6) |
| Stronger side wins (Squad.strength, decided) | 61.5% (59.9–63.1) |
| Stronger side wins (selected-22 OVR, decided) | 59.8% (58.2–61.4) |

Favourite win rate by preseason gap:

| Squad.strength gap | Fav wins | n | | Selected-22 OVR gap | Fav wins | n |
|---|---|---|---|---|---|---|
| 0.0–1.0 | 54.2% (50.8–57.6) | 804 | | 0.0–0.5 | 47.5% (41.2–53.8) | 236 |
| 1.0–2.0 | 55.3% (51.7–58.9) | 732 | | 0.5–1.0 | 52.0% (47.8–56.1) | 554 |
| 2.0–3.0 | 61.2% (57.3–64.9) | 629 | | 1.0–1.5 | 56.7% (51.4–61.9) | 335 |
| 3.0–4.0 | 62.8% (58.5–66.9) | 508 | | 1.5–2.0 | 60.7% (55.8–65.3) | 399 |
| 4.0–6.0 | 71.9% (68.0–75.5) | 552 | | 2.0–3.0 | 59.1% (54.6–63.3) | 486 |
| 6.0+ | 83.2% (77.3–87.9) | 191 | | 3.0+ | 65.7% (63.2–68.2) | 1406 |

| Margin measure | Value |
|---|---|
| Mean / median / 90th percentile | 27.7 / 24 / 57 |
| 40+ points | 26.0% (24.5–27.4) |
| 60+ points | 8.4% (7.6–9.4) |
| 80+ points | 1.6% (1.3–2.1) |
| 100+ points | 0.5% (0.3–0.8) |

### Preseason strength → season outcome

| Measure (per season, mean ± SD across seasons) | Value |
|---|---|
| Pearson r: Squad.strength vs wins | 0.64 ± 0.10 |
| Pearson r: Squad.strength vs percentage | 0.68 ± 0.07 |
| Spearman ρ: strength rank vs ladder position | 0.61 ± 0.11 |
| Pooled R² of wins on league-centred strength | 0.41 |

Skill vs luck (same lists replayed with new season seeds; 1 leagues with 2+ seasons):

| Measure | Value |
|---|---|
| Luck SD of a club's season wins (within-club) | 2.19 wins |
| Skill SD (between-club, net of luck) | 3.14 wins |
| Share of season-win variance that is skill | 67.2% (per league: 67–67%) |

Outcome frequency by preseason strength rank (1 = strongest):

| Rank | Premiership | Finals (top 10) | Wooden spoon |
|---|---|---|---|
| 1 | 56.2% | 100.0% | 0.0% |
| 2 | 0.0% | 93.8% | 0.0% |
| 3 | 12.5% | 87.5% | 0.0% |
| 4 | 0.0% | 43.8% | 0.0% |
| 5 | 0.0% | 93.8% | 0.0% |
| 6 | 6.2% | 75.0% | 0.0% |
| 7 | 0.0% | 18.8% | 12.5% |
| 8 | 18.8% | 100.0% | 0.0% |
| 9 | 0.0% | 87.5% | 0.0% |
| 10 | 0.0% | 37.5% | 0.0% |
| 11 | 6.2% | 93.8% | 0.0% |
| 12 | 0.0% | 12.5% | 0.0% |
| 13 | 0.0% | 12.5% | 0.0% |
| 14 | 0.0% | 37.5% | 6.2% |
| 15 | 0.0% | 56.2% | 6.2% |
| 16 | 0.0% | 43.8% | 6.2% |
| 17 | 0.0% | 6.2% | 6.2% |
| 18 | 0.0% | 0.0% | 62.5% |

(Each rank has 16 club-seasons: one per season.)

## Career first season: board-policy draft through GameState.advance

Draft seeds: 8; seasons: 8 (201, 202, 203, 204, 205, 206, 207, 208)

### Preseason strength distribution (per league)

| Measure | Mean | Min | Max |
|---|---|---|---|
| Squad.strength spread (strongest − weakest) | 9.43 | 5.99 | 11.49 |
| Squad.strength SD across clubs | 2.56 | 1.82 | 3.23 |
| Selected-22 mean OVR spread | 4.64 | 4.27 | 4.91 |
| Selected-22 mean OVR SD across clubs | 1.08 | 0.98 | 1.31 |

### Match outcomes (home and away, n = 1728)

| Measure | Value (95% CI) |
|---|---|
| Home win (decided games) | 57.1% (54.8–59.5) |
| Draw rate | 1.2% (0.8–1.8) |
| Stronger side wins (Squad.strength, decided) | 57.8% (55.5–60.2) |
| Stronger side wins (selected-22 OVR, decided) | 53.6% (51.2–55.9) |

Favourite win rate by preseason gap:

| Squad.strength gap | Fav wins | n | | Selected-22 OVR gap | Fav wins | n |
|---|---|---|---|---|---|---|
| 0.0–1.0 | 48.7% (43.5–53.9) | 351 | | 0.0–0.5 | 48.8% (44.1–53.6) | 430 |
| 1.0–2.0 | 53.8% (48.7–58.9) | 366 | | 0.5–1.0 | 51.1% (46.5–55.6) | 466 |
| 2.0–3.0 | 59.9% (54.3–65.3) | 297 | | 1.0–1.5 | 62.5% (57.0–67.7) | 312 |
| 3.0–4.0 | 64.3% (57.9–70.1) | 235 | | 1.5–2.0 | 51.5% (44.0–59.0) | 167 |
| 4.0–6.0 | 61.7% (55.8–67.2) | 274 | | 2.0–3.0 | 54.5% (47.6–61.3) | 200 |
| 6.0+ | 65.9% (58.9–72.4) | 185 | | 3.0+ | 58.6% (49.3–67.3) | 111 |

| Margin measure | Value |
|---|---|
| Mean / median / 90th percentile | 26.3 / 23 / 53 |
| 40+ points | 22.3% (20.4–24.4) |
| 60+ points | 6.1% (5.1–7.4) |
| 80+ points | 1.4% (1.0–2.1) |
| 100+ points | 0.1% (0.0–0.4) |

### Preseason strength → season outcome

| Measure (per season, mean ± SD across seasons) | Value |
|---|---|
| Pearson r: Squad.strength vs wins | 0.58 ± 0.12 |
| Pearson r: Squad.strength vs percentage | 0.67 ± 0.08 |
| Spearman ρ: strength rank vs ladder position | 0.58 ± 0.16 |
| Pooled R² of wins on league-centred strength | 0.31 |

Skill/luck decomposition needs 2+ seasons per league (not in this sample).

Outcome frequency by preseason strength rank (1 = strongest):

| Rank | Premiership | Finals (top 10) | Wooden spoon |
|---|---|---|---|
| 1 | 12.5% | 100.0% | 0.0% |
| 2 | 12.5% | 75.0% | 0.0% |
| 3 | 12.5% | 75.0% | 12.5% |
| 4 | 0.0% | 87.5% | 0.0% |
| 5 | 37.5% | 87.5% | 0.0% |
| 6 | 12.5% | 62.5% | 0.0% |
| 7 | 12.5% | 75.0% | 0.0% |
| 8 | 0.0% | 75.0% | 0.0% |
| 9 | 0.0% | 87.5% | 0.0% |
| 10 | 0.0% | 37.5% | 0.0% |
| 11 | 0.0% | 62.5% | 0.0% |
| 12 | 0.0% | 37.5% | 0.0% |
| 13 | 0.0% | 0.0% | 0.0% |
| 14 | 0.0% | 37.5% | 0.0% |
| 15 | 0.0% | 25.0% | 0.0% |
| 16 | 0.0% | 25.0% | 25.0% |
| 17 | 0.0% | 12.5% | 37.5% |
| 18 | 0.0% | 37.5% | 25.0% |

(Each rank has 8 club-seasons: one per season.)

Your club (the board-policy drafter; with policy ai, the first pick of the order):

| Draft seed | Season seed | Club | Strength rank | Ladder | Wins |
|---|---|---|---|---|---|
| 201 | 201001 | RIC | 7 | 6 | 13 |
| 202 | 202001 | GEE | 1 | 1 | 16 |
| 203 | 203001 | MEL | 7 | 4 | 15 |
| 204 | 204001 | RIC | 1 | 3 | 15 |
| 205 | 205001 | MEL | 15 | 17 | 7 |
| 206 | 206001 | SYD | 12 | 12 | 10 |
| 207 | 207001 | FRE | 3 | 18 | 9 |
| 208 | 208001 | WBD | 7 | 1 | 16 |

## Career first season: all-AI draft through GameState.advance

Draft seeds: 8; seasons: 8 (101, 102, 103, 104, 105, 106, 107, 108)

### Preseason strength distribution (per league)

| Measure | Mean | Min | Max |
|---|---|---|---|
| Squad.strength spread (strongest − weakest) | 8.96 | 6.48 | 10.68 |
| Squad.strength SD across clubs | 2.49 | 1.98 | 3.02 |
| Selected-22 mean OVR spread | 3.48 | 2.82 | 4.41 |
| Selected-22 mean OVR SD across clubs | 0.99 | 0.88 | 1.23 |

### Match outcomes (home and away, n = 1728)

| Measure | Value (95% CI) |
|---|---|
| Home win (decided games) | 58.8% (56.4–61.1) |
| Draw rate | 1.3% (0.8–1.9) |
| Stronger side wins (Squad.strength, decided) | 56.7% (54.3–59.0) |
| Stronger side wins (selected-22 OVR, decided) | 52.0% (49.6–54.4) |

Favourite win rate by preseason gap:

| Squad.strength gap | Fav wins | n | | Selected-22 OVR gap | Fav wins | n |
|---|---|---|---|---|---|---|
| 0.0–1.0 | 52.1% (46.9–57.2) | 363 | | 0.0–0.5 | 49.2% (44.4–54.0) | 415 |
| 1.0–2.0 | 51.7% (46.0–57.3) | 296 | | 0.5–1.0 | 47.6% (42.8–52.4) | 414 |
| 2.0–3.0 | 55.2% (49.9–60.4) | 346 | | 1.0–1.5 | 54.7% (49.3–60.0) | 331 |
| 3.0–4.0 | 57.0% (50.5–63.2) | 230 | | 1.5–2.0 | 52.3% (46.3–58.3) | 262 |
| 4.0–6.0 | 60.4% (55.0–65.6) | 321 | | 2.0–3.0 | 58.0% (51.4–64.3) | 219 |
| 6.0+ | 72.7% (65.0–79.2) | 150 | | 3.0+ | 66.7% (52.5–78.3) | 48 |

| Margin measure | Value |
|---|---|
| Mean / median / 90th percentile | 26.7 / 23 / 54 |
| 40+ points | 23.7% (21.7–25.7) |
| 60+ points | 7.0% (5.9–8.3) |
| 80+ points | 1.7% (1.2–2.5) |
| 100+ points | 0.5% (0.2–0.9) |

### Preseason strength → season outcome

| Measure (per season, mean ± SD across seasons) | Value |
|---|---|
| Pearson r: Squad.strength vs wins | 0.42 ± 0.28 |
| Pearson r: Squad.strength vs percentage | 0.47 ± 0.28 |
| Spearman ρ: strength rank vs ladder position | 0.39 ± 0.27 |
| Pooled R² of wins on league-centred strength | 0.21 |

Skill/luck decomposition needs 2+ seasons per league (not in this sample).

Outcome frequency by preseason strength rank (1 = strongest):

| Rank | Premiership | Finals (top 10) | Wooden spoon |
|---|---|---|---|
| 1 | 0.0% | 87.5% | 0.0% |
| 2 | 37.5% | 62.5% | 0.0% |
| 3 | 0.0% | 75.0% | 0.0% |
| 4 | 0.0% | 62.5% | 0.0% |
| 5 | 12.5% | 62.5% | 0.0% |
| 6 | 0.0% | 87.5% | 0.0% |
| 7 | 0.0% | 75.0% | 0.0% |
| 8 | 0.0% | 75.0% | 0.0% |
| 9 | 12.5% | 62.5% | 0.0% |
| 10 | 0.0% | 50.0% | 0.0% |
| 11 | 0.0% | 50.0% | 12.5% |
| 12 | 0.0% | 25.0% | 12.5% |
| 13 | 12.5% | 37.5% | 0.0% |
| 14 | 25.0% | 50.0% | 0.0% |
| 15 | 0.0% | 25.0% | 12.5% |
| 16 | 0.0% | 12.5% | 0.0% |
| 17 | 0.0% | 75.0% | 25.0% |
| 18 | 0.0% | 25.0% | 37.5% |

(Each rank has 8 club-seasons: one per season.)

Your club (the board-policy drafter; with policy ai, the first pick of the order):

| Draft seed | Season seed | Club | Strength rank | Ladder | Wins |
|---|---|---|---|---|---|
| 101 | 101001 | GCS | 4 | 7 | 14 |
| 102 | 102001 | SYD | 13 | 1 | 16 |
| 103 | 103001 | FRE | 11 | 14 | 10 |
| 104 | 104001 | NTH | 2 | 5 | 14 |
| 105 | 105001 | SYD | 14 | 4 | 15 |
| 106 | 106001 | ADE | 2 | 7 | 13 |
| 107 | 107001 | NTH | 5 | 1 | 18 |
| 108 | 108001 | GWS | 5 | 12 | 10 |

## Real AFL 2026 benchmark (data/raw)

Home and away games: 207

| Measure | Value |
|---|---|
| Home win (decided) | 59.3% (52.5–65.8) |
| Draw rate | 1.4% (0.5–4.2) |
| Mean / median / 90th percentile | 32.2 / 26 / 67 |
| 40+ points | 34.3% (28.2–41.0) |
| 60+ points | 15.5% (11.2–21.0) |
| 80+ points | 3.9% (2.0–7.4) |
| 100+ points | 1.9% (0.8–4.9) |

Season wins (23 games): SD across clubs 5.08; coin-flip luck alone would give 2.40, so skill SD ≈ 4.48 and the skill share ≈ 77.7% (one season: a rough estimate).

Squad.strength of the real 2026 lists vs the real 2026 wins (18 clubs): Pearson r = 0.88.

