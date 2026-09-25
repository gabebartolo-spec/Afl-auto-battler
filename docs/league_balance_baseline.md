# League competitive-balance baseline (engine at b261e79, 2026-09-25)

Shards: bcareer.json, bdrafted_a.json, bdrafted_b.json, bdrafted_c.json, bdrafted_d.json, bsens.json, career.json, drafted_a.json, drafted_b.json, drafted_c.json, drafted_d.json, real_a.json, real_b.json, sens_a.json, sens_b.json  
Total shard runtime: 6751 s (sum over shards)

## Drafted league: career draft, your picks by the board policy (Season/MatchSim)

Draft seeds: 16; seasons: 48 (201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216)

Distinct leagues (same 18 lists regardless of club names count once): 16

### Preseason strength distribution (per league)

| Measure | Mean | Min | Max |
|---|---|---|---|
| Squad.strength spread (strongest − weakest) | 9.30 | 6.61 | 14.34 |
| Squad.strength SD across clubs | 2.60 | 2.01 | 3.45 |
| Selected-22 mean OVR spread | 2.66 | 2.00 | 3.09 |
| Selected-22 mean OVR SD across clubs | 0.60 | 0.50 | 0.66 |

### Match outcomes (home and away, n = 10368)

| Measure | Value (95% CI) |
|---|---|
| Home win (decided games) | 58.4% (57.4–59.3) |
| Draw rate | 1.1% (0.9–1.3) |
| Stronger side wins (Squad.strength, decided) | 56.4% (55.4–57.3) |
| Stronger side wins (selected-22 OVR, decided) | 48.7% (47.7–49.7) |

Favourite win rate by preseason gap:

| Squad.strength gap | Fav wins | n | | Selected-22 OVR gap | Fav wins | n |
|---|---|---|---|---|---|---|
| 0.0–1.0 | 51.5% (49.4–53.7) | 2123 | | 0.0–0.5 | 50.8% (49.4–52.1) | 5376 |
| 1.0–2.0 | 52.5% (50.4–54.7) | 2012 | | 0.5–1.0 | 49.3% (47.4–51.2) | 2653 |
| 2.0–3.0 | 56.4% (54.0–58.7) | 1769 | | 1.0–1.5 | 46.5% (43.2–49.9) | 834 |
| 3.0–4.0 | 53.8% (51.3–56.3) | 1508 | | 1.5–2.0 | 38.3% (34.1–42.6) | 507 |
| 4.0–6.0 | 61.7% (59.4–63.8) | 1849 | | 2.0–3.0 | 39.6% (35.6–43.7) | 558 |
| 6.0+ | 68.6% (65.7–71.4) | 995 | | 3.0+ | 18.2% (5.1–47.7) | 11 |

| Margin measure | Value |
|---|---|
| Mean / median / 90th percentile | 26.6 / 22 / 55 |
| 40+ points | 23.5% (22.7–24.3) |
| 60+ points | 7.6% (7.1–8.1) |
| 80+ points | 1.8% (1.6–2.1) |
| 100+ points | 0.4% (0.3–0.6) |

### Preseason strength → season outcome

| Measure (per season, mean ± SD across seasons) | Value |
|---|---|
| Pearson r: Squad.strength vs wins | 0.43 ± 0.23 |
| Pearson r: Squad.strength vs percentage | 0.47 ± 0.20 |
| Spearman ρ: strength rank vs ladder position | 0.41 ± 0.23 |
| Pooled R² of wins on league-centred strength | 0.22 |

Skill vs luck (same lists replayed with new season seeds; 16 leagues with 2+ seasons):

| Measure | Value |
|---|---|
| Luck SD of a club's season wins (within-club) | 2.35 wins |
| Skill SD (between-club, net of luck) | 2.18 wins |
| Share of season-win variance that is skill | 46.3% (per league: 5–72%) |

Excluding your (board-policy) club - the 17 AI-drafted clubs only:

| Measure | Value |
|---|---|
| Squad.strength SD across clubs (mean) | 2.36 |
| Stronger side wins (Squad.strength, decided, AI v AI) | 55.2% (54.2–56.2) |
| Pearson r: Squad.strength vs wins | 0.35 ± 0.26 |

Skill vs luck, AI-drafted clubs only (same lists replayed with new season seeds; 16 leagues with 2+ seasons):

| Measure | Value |
|---|---|
| Luck SD of a club's season wins (within-club) | 2.37 wins |
| Skill SD (between-club, net of luck) | 1.92 wins |
| Share of season-win variance that is skill | 39.8% (per league: 2–73%) |

Outcome frequency by preseason strength rank (1 = strongest):

| Rank | Premiership | Finals (top 10) | Wooden spoon |
|---|---|---|---|
| 1 | 14.6% | 89.6% | 2.1% |
| 2 | 25.0% | 81.2% | 0.0% |
| 3 | 6.2% | 79.2% | 2.1% |
| 4 | 4.2% | 60.4% | 0.0% |
| 5 | 0.0% | 64.6% | 0.0% |
| 6 | 4.2% | 62.5% | 2.1% |
| 7 | 4.2% | 58.3% | 4.2% |
| 8 | 10.4% | 72.9% | 0.0% |
| 9 | 4.2% | 62.5% | 2.1% |
| 10 | 2.1% | 68.8% | 0.0% |
| 11 | 4.2% | 54.2% | 0.0% |
| 12 | 4.2% | 45.8% | 6.2% |
| 13 | 6.2% | 45.8% | 6.2% |
| 14 | 4.2% | 25.0% | 4.2% |
| 15 | 2.1% | 39.6% | 10.4% |
| 16 | 4.2% | 33.3% | 14.6% |
| 17 | 0.0% | 33.3% | 10.4% |
| 18 | 0.0% | 22.9% | 35.4% |

(Each rank has 48 club-seasons: one per season.)

Your club (the board-policy drafter; with policy ai, the first pick of the order):

| Draft seed | Season seed | Club | Strength rank | Ladder | Wins |
|---|---|---|---|---|---|
| 201 | 201001 | RIC | 18 | 18 | 8 |
| 201 | 201002 | RIC | 18 | 16 | 8 |
| 201 | 201003 | RIC | 18 | 18 | 5 |
| 202 | 202001 | GEE | 17 | 17 | 9 |
| 202 | 202002 | GEE | 17 | 16 | 8 |
| 202 | 202003 | GEE | 17 | 13 | 10 |
| 203 | 203001 | MEL | 18 | 18 | 2 |
| 203 | 203002 | MEL | 18 | 18 | 3 |
| 203 | 203003 | MEL | 18 | 18 | 2 |
| 204 | 204001 | RIC | 14 | 17 | 8 |
| 204 | 204002 | RIC | 14 | 13 | 10 |
| 204 | 204003 | RIC | 14 | 14 | 10 |
| 205 | 205001 | MEL | 4 | 15 | 9 |
| 205 | 205002 | MEL | 4 | 7 | 13 |
| 205 | 205003 | MEL | 4 | 6 | 14 |
| 206 | 206001 | SYD | 18 | 16 | 8 |
| 206 | 206002 | SYD | 18 | 18 | 5 |
| 206 | 206003 | SYD | 18 | 18 | 5 |
| 207 | 207001 | FRE | 15 | 18 | 4 |
| 207 | 207002 | FRE | 15 | 17 | 7 |
| 207 | 207003 | FRE | 15 | 18 | 7 |
| 208 | 208001 | WBD | 2 | 5 | 14 |
| 208 | 208002 | WBD | 2 | 1 | 18 |
| 208 | 208003 | WBD | 2 | 10 | 12 |
| 209 | 209001 | PAD | 17 | 18 | 7 |
| 209 | 209002 | PAD | 17 | 11 | 11 |
| 209 | 209003 | PAD | 17 | 18 | 9 |
| 210 | 210001 | GCS | 13 | 12 | 11 |
| 210 | 210002 | GCS | 13 | 7 | 13 |
| 210 | 210003 | GCS | 13 | 15 | 9 |
| 211 | 211001 | BRL | 18 | 18 | 3 |
| 211 | 211002 | BRL | 18 | 17 | 8 |
| 211 | 211003 | BRL | 18 | 18 | 8 |
| 212 | 212001 | GCS | 16 | 15 | 9 |
| 212 | 212002 | GCS | 16 | 18 | 8 |
| 212 | 212003 | GCS | 16 | 16 | 10 |
| 213 | 213001 | NTH | 18 | 18 | 5 |
| 213 | 213002 | NTH | 18 | 16 | 7 |
| 213 | 213003 | NTH | 18 | 14 | 9 |
| 214 | 214001 | SYD | 5 | 12 | 10 |
| 214 | 214002 | SYD | 5 | 8 | 12 |
| 214 | 214003 | SYD | 5 | 7 | 14 |
| 215 | 215001 | BRL | 17 | 16 | 7 |
| 215 | 215002 | BRL | 17 | 15 | 10 |
| 215 | 215003 | BRL | 17 | 18 | 5 |
| 216 | 216001 | WCE | 18 | 18 | 7 |
| 216 | 216002 | WCE | 18 | 18 | 3 |
| 216 | 216003 | WCE | 18 | 18 | 6 |

## Drafted league: all-AI career draft (Season/MatchSim)

Draft seeds: 16; seasons: 48 (101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116)

### Preseason strength distribution (per league)

| Measure | Mean | Min | Max |
|---|---|---|---|
| Squad.strength spread (strongest − weakest) | 6.79 | 6.79 | 6.79 |
| Squad.strength SD across clubs | 2.30 | 2.30 | 2.30 |
| Selected-22 mean OVR spread | 1.05 | 1.05 | 1.05 |
| Selected-22 mean OVR SD across clubs | 0.29 | 0.29 | 0.29 |

### Match outcomes (home and away, n = 10368)

| Measure | Value (95% CI) |
|---|---|
| Home win (decided games) | 58.9% (57.9–59.8) |
| Draw rate | 1.3% (1.1–1.5) |
| Stronger side wins (Squad.strength, decided) | 54.9% (53.9–55.8) |
| Stronger side wins (selected-22 OVR, decided) | 49.3% (48.3–50.3) |

Favourite win rate by preseason gap:

| Squad.strength gap | Fav wins | n | | Selected-22 OVR gap | Fav wins | n |
|---|---|---|---|---|---|---|
| 0.0–1.0 | 50.5% (48.5–52.5) | 2372 | | 0.0–0.5 | 49.5% (48.3–50.6) | 7233 |
| 1.0–2.0 | 53.9% (51.6–56.3) | 1774 | | 0.5–1.0 | 48.4% (46.3–50.5) | 2192 |
| 2.0–3.0 | 53.1% (50.8–55.4) | 1833 | | 1.0–1.5 | 53.2% (46.3–60.0) | 201 |
| 3.0–4.0 | 55.3% (52.9–57.6) | 1702 | | 1.5–2.0 | - | 0 |
| 4.0–6.0 | 59.6% (57.4–61.7) | 2051 | | 2.0–3.0 | - | 0 |
| 6.0+ | 64.2% (59.9–68.3) | 503 | | 3.0+ | - | 0 |

| Margin measure | Value |
|---|---|
| Mean / median / 90th percentile | 26.2 / 22 / 54 |
| 40+ points | 23.0% (22.2–23.8) |
| 60+ points | 6.7% (6.3–7.2) |
| 80+ points | 1.6% (1.4–1.9) |
| 100+ points | 0.2% (0.2–0.3) |

### Preseason strength → season outcome

| Measure (per season, mean ± SD across seasons) | Value |
|---|---|
| Pearson r: Squad.strength vs wins | 0.35 ± 0.17 |
| Pearson r: Squad.strength vs percentage | 0.42 ± 0.16 |
| Spearman ρ: strength rank vs ladder position | 0.34 ± 0.18 |
| Pooled R² of wins on league-centred strength | 0.12 |

Skill vs luck (same lists replayed with new season seeds; 16 leagues with 2+ seasons):

| Measure | Value |
|---|---|
| Luck SD of a club's season wins (within-club) | 2.29 wins |
| Skill SD (between-club, net of luck) | 1.98 wins |
| Share of season-win variance that is skill | 42.8% (per league: 23–66%) |

Outcome frequency by preseason strength rank (1 = strongest):

| Rank | Premiership | Finals (top 10) | Wooden spoon |
|---|---|---|---|
| 1 | 2.1% | 75.0% | 2.1% |
| 2 | 25.0% | 93.8% | 0.0% |
| 3 | 12.5% | 70.8% | 0.0% |
| 4 | 16.7% | 89.6% | 0.0% |
| 5 | 14.6% | 85.4% | 2.1% |
| 6 | 2.1% | 37.5% | 4.2% |
| 7 | 0.0% | 22.9% | 18.8% |
| 8 | 2.1% | 52.1% | 4.2% |
| 9 | 14.6% | 79.2% | 2.1% |
| 10 | 0.0% | 33.3% | 4.2% |
| 11 | 0.0% | 54.2% | 2.1% |
| 12 | 4.2% | 83.3% | 0.0% |
| 13 | 0.0% | 12.5% | 20.8% |
| 14 | 2.1% | 37.5% | 6.2% |
| 15 | 0.0% | 75.0% | 2.1% |
| 16 | 2.1% | 31.2% | 4.2% |
| 17 | 0.0% | 20.8% | 18.8% |
| 18 | 2.1% | 45.8% | 8.3% |

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
| Squad.strength spread (strongest − weakest) | 10.27 | 7.29 | 14.34 |
| Squad.strength SD across clubs | 2.82 | 2.18 | 3.45 |
| Selected-22 mean OVR spread | 2.64 | 2.00 | 2.95 |
| Selected-22 mean OVR SD across clubs | 0.60 | 0.50 | 0.66 |

### Match outcomes (home and away, n = 1728)

| Measure | Value (95% CI) |
|---|---|
| Home win (decided games) | 59.2% (56.9–61.5) |
| Draw rate | 1.1% (0.7–1.7) |
| Stronger side wins (Squad.strength, decided) | 57.7% (55.3–60.0) |
| Stronger side wins (selected-22 OVR, decided) | 51.1% (48.7–53.5) |

Favourite win rate by preseason gap:

| Squad.strength gap | Fav wins | n | | Selected-22 OVR gap | Fav wins | n |
|---|---|---|---|---|---|---|
| 0.0–1.0 | 48.7% (43.4–54.0) | 337 | | 0.0–0.5 | 51.0% (47.7–54.2) | 910 |
| 1.0–2.0 | 52.0% (46.4–57.5) | 306 | | 0.5–1.0 | 52.5% (47.9–57.0) | 461 |
| 2.0–3.0 | 54.7% (48.8–60.5) | 276 | | 1.0–1.5 | 51.9% (42.5–61.0) | 108 |
| 3.0–4.0 | 64.4% (58.4–69.9) | 261 | | 1.5–2.0 | 54.3% (42.7–65.4) | 70 |
| 4.0–6.0 | 65.6% (60.3–70.6) | 323 | | 2.0–3.0 | 42.9% (33.8–52.4) | 105 |
| 6.0+ | 64.1% (57.3–70.3) | 206 | | 3.0+ | - | 0 |

| Margin measure | Value |
|---|---|
| Mean / median / 90th percentile | 28.1 / 24 / 57 |
| 40+ points | 26.3% (24.3–28.4) |
| 60+ points | 9.0% (7.8–10.5) |
| 80+ points | 2.7% (2.1–3.6) |
| 100+ points | 0.7% (0.4–1.2) |

### Preseason strength → season outcome

| Measure (per season, mean ± SD across seasons) | Value |
|---|---|
| Pearson r: Squad.strength vs wins | 0.51 ± 0.22 |
| Pearson r: Squad.strength vs percentage | 0.58 ± 0.16 |
| Spearman ρ: strength rank vs ladder position | 0.51 ± 0.20 |
| Pooled R² of wins on league-centred strength | 0.25 |

Skill/luck decomposition needs 2+ seasons per league (not in this sample).

Outcome frequency by preseason strength rank (1 = strongest):

| Rank | Premiership | Finals (top 10) | Wooden spoon |
|---|---|---|---|
| 1 | 0.0% | 87.5% | 0.0% |
| 2 | 12.5% | 87.5% | 0.0% |
| 3 | 12.5% | 87.5% | 0.0% |
| 4 | 37.5% | 100.0% | 0.0% |
| 5 | 0.0% | 75.0% | 0.0% |
| 6 | 0.0% | 75.0% | 0.0% |
| 7 | 0.0% | 75.0% | 0.0% |
| 8 | 0.0% | 50.0% | 0.0% |
| 9 | 0.0% | 37.5% | 0.0% |
| 10 | 0.0% | 62.5% | 0.0% |
| 11 | 12.5% | 37.5% | 25.0% |
| 12 | 12.5% | 37.5% | 12.5% |
| 13 | 0.0% | 25.0% | 12.5% |
| 14 | 12.5% | 25.0% | 12.5% |
| 15 | 0.0% | 25.0% | 0.0% |
| 16 | 0.0% | 50.0% | 25.0% |
| 17 | 0.0% | 25.0% | 0.0% |
| 18 | 0.0% | 37.5% | 12.5% |

(Each rank has 8 club-seasons: one per season.)

Your club (the board-policy drafter; with policy ai, the first pick of the order):

| Draft seed | Season seed | Club | Strength rank | Ladder | Wins |
|---|---|---|---|---|---|
| 201 | 201001 | RIC | 18 | 4 | 14 |
| 202 | 202001 | GEE | 17 | 17 | 7 |
| 203 | 203001 | MEL | 18 | 18 | 4 |
| 204 | 204001 | RIC | 14 | 1 | 18 |
| 205 | 205001 | MEL | 4 | 5 | 14 |
| 206 | 206001 | SYD | 18 | 15 | 8 |
| 207 | 207001 | FRE | 15 | 16 | 7 |
| 208 | 208001 | WBD | 2 | 3 | 16 |

## Career first season: all-AI draft through GameState.advance

Draft seeds: 8; seasons: 8 (101, 102, 103, 104, 105, 106, 107, 108)

### Preseason strength distribution (per league)

| Measure | Mean | Min | Max |
|---|---|---|---|
| Squad.strength spread (strongest − weakest) | 6.79 | 6.79 | 6.79 |
| Squad.strength SD across clubs | 2.30 | 2.30 | 2.30 |
| Selected-22 mean OVR spread | 1.05 | 1.05 | 1.05 |
| Selected-22 mean OVR SD across clubs | 0.29 | 0.29 | 0.29 |

### Match outcomes (home and away, n = 1728)

| Measure | Value (95% CI) |
|---|---|
| Home win (decided games) | 59.8% (57.4–62.1) |
| Draw rate | 1.7% (1.2–2.4) |
| Stronger side wins (Squad.strength, decided) | 56.9% (54.5–59.2) |
| Stronger side wins (selected-22 OVR, decided) | 49.9% (47.5–52.4) |

Favourite win rate by preseason gap:

| Squad.strength gap | Fav wins | n | | Selected-22 OVR gap | Fav wins | n |
|---|---|---|---|---|---|---|
| 0.0–1.0 | 52.5% (47.6–57.3) | 404 | | 0.0–0.5 | 49.5% (46.7–52.3) | 1194 |
| 1.0–2.0 | 54.9% (49.1–60.5) | 288 | | 0.5–1.0 | 51.5% (46.4–56.7) | 359 |
| 2.0–3.0 | 56.8% (51.1–62.4) | 292 | | 1.0–1.5 | 48.6% (33.0–64.4) | 35 |
| 3.0–4.0 | 60.2% (54.5–65.7) | 289 | | 1.5–2.0 | - | 0 |
| 4.0–6.0 | 59.9% (54.6–65.0) | 337 | | 2.0–3.0 | - | 0 |
| 6.0+ | 60.7% (50.3–70.2) | 89 | | 3.0+ | - | 0 |

| Margin measure | Value |
|---|---|
| Mean / median / 90th percentile | 27.1 / 23 / 55 |
| 40+ points | 25.4% (23.4–27.5) |
| 60+ points | 7.8% (6.6–9.1) |
| 80+ points | 2.1% (1.5–2.9) |
| 100+ points | 0.5% (0.2–0.9) |

### Preseason strength → season outcome

| Measure (per season, mean ± SD across seasons) | Value |
|---|---|
| Pearson r: Squad.strength vs wins | 0.44 ± 0.14 |
| Pearson r: Squad.strength vs percentage | 0.50 ± 0.14 |
| Spearman ρ: strength rank vs ladder position | 0.40 ± 0.15 |
| Pooled R² of wins on league-centred strength | 0.20 |

Skill/luck decomposition needs 2+ seasons per league (not in this sample).

Outcome frequency by preseason strength rank (1 = strongest):

| Rank | Premiership | Finals (top 10) | Wooden spoon |
|---|---|---|---|
| 1 | 25.0% | 87.5% | 0.0% |
| 2 | 25.0% | 100.0% | 0.0% |
| 3 | 12.5% | 75.0% | 0.0% |
| 4 | 0.0% | 87.5% | 0.0% |
| 5 | 37.5% | 75.0% | 0.0% |
| 6 | 0.0% | 37.5% | 0.0% |
| 7 | 0.0% | 50.0% | 12.5% |
| 8 | 0.0% | 25.0% | 0.0% |
| 9 | 0.0% | 62.5% | 0.0% |
| 10 | 0.0% | 50.0% | 0.0% |
| 11 | 0.0% | 62.5% | 12.5% |
| 12 | 0.0% | 87.5% | 0.0% |
| 13 | 0.0% | 25.0% | 25.0% |
| 14 | 0.0% | 25.0% | 12.5% |
| 15 | 0.0% | 62.5% | 0.0% |
| 16 | 0.0% | 37.5% | 0.0% |
| 17 | 0.0% | 12.5% | 37.5% |
| 18 | 0.0% | 37.5% | 0.0% |

(Each rank has 8 club-seasons: one per season.)

Your club (the board-policy drafter; with policy ai, the first pick of the order):

| Draft seed | Season seed | Club | Strength rank | Ladder | Wins |
|---|---|---|---|---|---|
| 101 | 101001 | GCS | 1 | 12 | 10 |
| 102 | 102001 | SYD | 1 | 5 | 13 |
| 103 | 103001 | FRE | 1 | 7 | 14 |
| 104 | 104001 | NTH | 1 | 1 | 17 |
| 105 | 105001 | SYD | 1 | 1 | 18 |
| 106 | 106001 | ADE | 1 | 6 | 14 |
| 107 | 107001 | NTH | 1 | 2 | 14 |
| 108 | 108001 | GWS | 1 | 3 | 15 |

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

## Controlled sensitivity (board-policy drafted leagues): one club's whole list shifted by +k OVR

Subjects (median-strength club of each drafted league): 201/ADE, 202/FRE, 203/WBD, 104/ADE, 105/FRE, 106/PAD. Every k plays the same opponents at the same venues with the same seeds.

| +k OVR | Sel-22 OVR | Strength | Win % (95% CI) | Home win % | Away win % | Mean margin ± SE | Δ margin vs k=0 ± SE (paired) | n |
|---|---|---|---|---|---|---|---|---|
| +0 | 66.8 | 66.0 | 47.2% (42.4–52.0) | 58.3% | 36.0% | -2.5 ± 1.5 | +0.0 ± 0.0 | 408 |
| +1 | 67.1 | 66.3 | 48.9% (44.1–53.7) | 61.8% | 36.0% | -0.4 ± 1.6 | +2.1 ± 1.6 | 408 |
| +2 | 68.4 | 67.3 | 52.2% (47.4–57.0) | 60.5% | 43.9% | +3.9 ± 1.6 | +6.4 ± 1.6 | 408 |
| +3 | 69.2 | 68.1 | 56.2% (51.4–61.0) | 68.6% | 43.9% | +3.6 ± 1.6 | +6.1 ± 1.6 | 408 |
| +4 | 70.4 | 69.1 | 57.7% (52.9–62.4) | 68.1% | 47.3% | +7.1 ± 1.6 | +9.7 ± 1.7 | 408 |
| +6 | 72.2 | 70.7 | 69.2% (64.6–73.5) | 78.4% | 60.0% | +17.2 ± 1.6 | +19.7 ± 1.8 | 408 |
| +8 | 74.3 | 72.3 | 74.4% (69.9–78.4) | 83.6% | 65.2% | +22.7 ± 1.6 | +25.2 ± 1.8 | 408 |
| +10 | 76.3 | 74.0 | 77.3% (73.0–81.1) | 86.5% | 68.1% | +28.1 ± 1.7 | +30.6 ± 1.9 | 408 |

(Draws count as half a win.)

## Controlled sensitivity (ai-policy drafted leagues): one club's whole list shifted by +k OVR

Subjects (median-strength club of each drafted league): 101/BRL, 102/GCS, 103/CAR. Every k plays the same opponents at the same venues with the same seeds.

| +k OVR | Sel-22 OVR | Strength | Win % (95% CI) | Home win % | Away win % | Mean margin ± SE | Δ margin vs k=0 ± SE (paired) | n |
|---|---|---|---|---|---|---|---|---|
| +0 | 66.6 | 66.0 | 43.6% (37.0–50.5) | 54.4% | 32.8% | -3.5 ± 2.3 | +0.0 ± 0.0 | 204 |
| +1 | 67.0 | 66.3 | 43.1% (36.5–50.0) | 54.4% | 31.9% | -5.3 ± 2.5 | -1.9 ± 2.2 | 204 |
| +2 | 68.3 | 67.4 | 48.0% (41.3–54.9) | 59.8% | 36.3% | -3.1 ± 2.4 | +0.4 ± 2.3 | 204 |
| +3 | 69.1 | 68.1 | 51.0% (44.2–57.8) | 58.3% | 43.6% | +1.9 ± 2.4 | +5.4 ± 2.2 | 204 |
| +4 | 70.3 | 69.0 | 61.8% (54.9–68.2) | 70.6% | 52.9% | +8.9 ± 2.5 | +12.4 ± 2.4 | 204 |
| +6 | 72.4 | 70.6 | 60.3% (53.4–66.8) | 67.6% | 52.9% | +10.1 ± 2.5 | +13.6 ± 2.7 | 204 |
| +8 | 74.3 | 72.2 | 69.6% (63.0–75.5) | 81.4% | 57.8% | +17.6 ± 2.4 | +21.0 ± 2.6 | 204 |
| +10 | 76.0 | 73.6 | 83.1% (77.3–87.6) | 90.2% | 76.0% | +32.9 ± 2.6 | +36.4 ± 2.8 | 204 |

(Draws count as half a win.)

