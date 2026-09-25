# Club-specific player evaluation in the career draft

Before this change, all 18 rival clubs valued every player with one shared,
perfect ranking. [DRAFT_COMPRESSION.md](DRAFT_COMPRESSION.md) showed that
this, rather than the snake order, is why the career draft flattens club
strength. Rival clubs now each hold their own imperfect opinion of every
player.

Nothing else changed. That includes MatchSim, home advantage, the OVR
formula, list size, the salary cap, player data and development, the draft
board and the human's picks.

## Implementation (`scripts/sim/Draft.gd`)

- `_ai_score(code, p)` builds the rival club's value from its own opinion:
  - Before: `worth = _worth(p)`.
  - Now, for each position the player can fill: `worth = _worth(p) + need × _eval_error(code, p)`.
  - The rest of the scoring is unchanged: over-replacement, need weights and the cap penalty.
  - The replacement level still uses the shared worths.
- `_eval_error(code, p)` is the club's opinion minus the shared worth:
  - It is a Gaussian error with SD `club_eval_sd(code)`, capped at ±2.5 SD.
  - It is 0 for your club, 0 in the intake (national) draft, and 0 outside a league draft.
- `club_eval_sd(code)` is how sharp that club's scouting is. It is uniform on
  `[AI_EVAL_SD_MIN, AI_EVAL_SD_MAX]` = **[1, 5]** rating points.
- `_need_weight` has one new guard: a club with three rucks gives a fourth a
  weight of 0. The reason is under "Unintended effects" below.
- Everything is a pure function of `(draft seed, club code, player id)`:
  - It uses a string hash with a murmur3 finaliser, then Box–Muller for the Gaussian.
  - Nothing is stored, so saves are unchanged. A saved draft reloads with the same opinions (its seed is saved).
  - The same seed replays the same draft.
  - Opinions never change during a draft.

### What the error is and isn't

- **Zero-mean.** No club rates everyone up or down. The regression suite
  checks that every club's average error over the pool is within ±0.5.
- **Stable.** One draft, one opinion per club and player.
- **Weighted by need.** An opinion counts in full for an open starting spot,
  60% for depth and 20% for surplus. The club's scouts drive the picks that
  build its 22, and late depth picks follow the consensus.
- **Invisible to the player.** Ratings, potential and the board are
  untouched, and the tests check ratings before and after a draft. Your club
  gets no error.

## Calibration

The tooling (`tools/balance/draft_variant.gd`, `draft_experiment.gd`)
drafts with any SD range. At `[0, 0]` it reproduces the pre-change draft
exactly: league signature `8ec8c9…` for seed 1.

Two things from the calibration matter:

- **Differentiation comes from differences in scouting sharpness, not from the noise itself.** All three shapes below have the same mean error of 3:

  | Shape | Seasons (leagues) | Skill share | Skill SD | Stronger side wins | r(strength, wins) | r(OVR, wins) |
  |---|---|---|---|---|---|---|
  | Before (shared ranking) | 24 (4) | 41.1% ±5 | 1.95 | 53.8% | 0.30 | -0.07 |
  | Every club SD 3 | 48 (16) | 38.6% ±4 | 1.88 | 54.2% | 0.32 | 0.18 |
  | U[2, 4] | 48 (16) | 43.7% ±4 | 2.12 | 56.1% | 0.44 | 0.24 |
  | **U[1, 5] (shipped)** | 48 (16) | **53.6% ±3** | **2.53** | **59.0%** | **0.56** | **0.39** |

  If every club is equally fallible, errors wash out over 37 picks and the league stays flat. It is sharper and duller scouting that separates clubs.
- **A wider range adds pathologies without a measurable gain in the season numbers.** Draft quality over 16 drafts each (consensus rank = the pre-change shared ranking):

  | Draft | Consensus top-10: latest pick | Top-30 player sliding 25+ places, per draft | Worst slide of a top-30 player | Reaches of 30+ places in rounds 1–3, per draft | Most rucks |
  |---|---|---|---|---|---|
  | Before | 12 | 0.00 | 13 | 2.0 | 3 |
  | U[0.5, 3] | 17 | 0.00 | 23 | 1.4 | 5\* |
  | **U[1, 5]** | 24 | 1.00 | 38 | 2.4 | 3 |
  | U[1.5, 6] | 32 | 1.88 | 51 | 3.8 | 4\* |
  | U[2, 7] | 49 | 2.56 | 51 | 4.4 | 4\* |

  \* Before the fourth-ruck guard. The U[0.5, 3] row is from the first calibration round, which applied the opinion in full whatever the need. Early rounds are almost identical either way, because need is 1 there.

**Chosen range: U[1, 5].** Of the settings tested, it is the smallest that
puts the all-AI league inside the season-one range. Narrower shapes with the
same mean error fell short.

- Its draft-quality measures are no worse than U[2, 4] or a uniform SD of 3.
- Wider ranges double the elite slides for no gain the season sample can detect.
- A 24-season first pass could not separate U[0.5, 3] to U[1.5, 6] (all 45–47% ±4–6). The final comparison used 48 seasons each.

Full tables: [draft_evaluation_calibration.md](draft_evaluation_calibration.md).

## Before / after

**Method.** The baseline harness was re-run with the baseline's own seeds:

- Drafted leagues: 16 × 3 seasons, all-AI (seeds 101–116) and board (201–216).
- Career first seasons: 8 each.

Before is [league_balance_baseline.md](league_balance_baseline.md). After is
[league_balance_after_club_eval.md](league_balance_after_club_eval.md).

| Measure | All-AI before | All-AI after | Board (human) before | Board after | Board, AI clubs only before → after | Target |
|---|---|---|---|---|---|---|
| Distinct leagues (of 16) | 1 | 16 | 16 | 16 | | |
| Selected-22 OVR SD | 0.29 | 0.95 | 0.60 | 1.11 | | |
| Selected-22 OVR spread | 1.05 | 3.24 | 2.66 | | | |
| Squad.strength SD | 2.30 | 2.49 | 2.60 | 2.53 | 2.36 → 2.50 | |
| Squad.strength spread | 6.79 | 9.10 | 9.30 | | | |
| Skill share | 42.8% | **55.5%** | 46.3% | 47.9% | 39.8% → 46.1% | 45–60% |
| Skill SD (wins) | 1.98 | **2.48** | 2.18 | 2.25 | 1.92 → 2.16 | 2.2–2.9 |
| Stronger side wins (strength) | 54.9% | **57.6%** | 56.4% | 57.4% | 55.2% → 57.1% | 57–61% |
| Higher-OVR side wins | 49.3% | **55.5%** | 48.7% | 53.2% | | positive |
| r(strength, wins) | 0.35 | **0.50** | 0.43 | 0.48 | 0.35 → 0.49 | 0.45–0.65 |
| Pooled R², wins on strength | 0.12 | 0.26 | 0.22 | 0.24 | | |
| Premierships to top-3 strength | 39.6% | 41.7% | 45.8% | 45.9% | | ≈40–60% |
| Top-5 strength make finals | 82.9% | 80.5% | 75.0% | 81.7% | | |
| Spoons to bottom-3 strength | 31.3% | 43.7% | 60.4% | 35.5% | | |
| Home win / draws / 60+ margins | 58.9% / 1.3% / 6.7% | 59.9% / 1.2% / 7.5% | | | | |

Career first season, through `GameState.advance`, 8 seasons each (small sample):

| Draft | Stronger side wins | r(strength, wins) |
|---|---|---|
| All-AI | 56.9% → 56.7% | 0.44 → 0.42 |
| Board | 57.7% → 57.8% | 0.51 → 0.58 |

An independent 48-season run on other seeds (1–16) gave 53.6% skill share,
59.0% stronger side, r = 0.56 and r(OVR, wins) = 0.39.

## Lists stay believable

Evidence from 16 drafts of the shipped draft
([calibration tables](draft_evaluation_calibration.md)):

- **Roles.** RUCK 2–3, MID 14–17, DEF 9–13, FWD 6–9 on every list. No list is outside the range the real 2026 lists span. Before the change: RUCK 2–3, MID 15–17, DEF 10–12, FWD 6–8.
- **Round one.** It is still the elite:
  - The lowest round-one OVR was 78 (before: 81). Picks 1–10 average consensus rank 8.4 (before 8.1).
  - Round-one mean |rank − pick| is 6.6 (before 5.2).
  - The biggest round-one reach is a consensus-38 player at pick 9 or a consensus-47 at pick 15. Both were made by a club at the dull end of the range (SD ≈ 5).
- **Stars.** No star goes undrafted. The best undrafted player's consensus rank is 659 of 669.
- **Selected 22s and units.**
  - Selected-22 OVR spread is 3.2 across clubs, against 8.2 for the real lists.
  - Unit spreads stay in the range the old draft and the real lists span. Ruck SD rises 7.5 → 11.7, forward goal-kicking 5.2 → 8.3.
  - OVR now tracks Squad.strength: r = 0.49 across clubs, before 0.07.
- **League 1, seed 1, round one:**

  | Pick | Club (SD) | OVR (consensus rank) | Role |
  |---|---|---|---|
  | 1 | COL (2.2) | 92 (1) | MID/FWD |
  | 2 | GWS (3.2) | 87 (10) | FWD/MID |
  | 3 | MEL (4.0) | 90 (4) | MID |
  | 4 | ESS (2.4) | 91 (3) | MID/FWD |
  | 5 | WCE (2.0) | 86 (13) | DEF/MID |
  | 6 | PAD (2.4) | 88 (9) | RUCK/MID |
  | 7 | GEE (4.8) | 85 (12) | MID |
  | 8 | HAW (4.9) | 87 (6) | FWD |
  | 9 | SKN (4.8) | 81 (38) | FWD |
  | 10 | NTH (2.7) | 91 (2) | MID/FWD |
  | 11 | ADE (3.7) | 83 (26) | FWD |
  | 12 | BRL (2.1) | 88 (8) | DEF |
  | 13 | CAR (1.8) | 87 (7) | DEF/MID |
  | 14 | FRE (2.7) | 88 (5) | MID |
  | 15 | WBD (5.0) | 80 (47) | MID/DEF |
  | 16 | RIC (4.8) | 82 (25) | MID |
  | 17 | GCS (2.7) | 87 (11) | MID |
  | 18 | SYD (4.2) | 86 (17) | MID |

## Unintended effects found

1. **Rucks ran out (fixed).**
   - The last ~66 picks of a career draft come from the dregs: about 58 midfielders and 8 weak rucks.
   - With club opinions, 5–7% of clubs took a 4th, sometimes 5th, of those rucks. Even with no opinion on surplus picks, some clubs still took a 4th.
   - The pool could then run out of rucks before a human who had left the second ruck late. The two-ruck rule then blocked that human's final pick. The save suite's "loaded draft can be completed" check caught it on one seed.
   - Fix: a club with three rucks never values a fourth. The pre-change draft never produced a fourth ruck, so it is unaffected (same league signature).
   - Regression test: `tests/test_ai.gd`, a ruck-light human on the seed that stranded one.
2. **Scouting sharpness works as a club trait.** Across 16 drafts, r(club SD, selected-22 OVR) = −0.75.
   - Clubs with sharp scouting build better lists; that is where the new spread comes from.
   - It is not a modifier on any value: each error is zero-mean and player-specific.
   - But a club drawn near SD 5 usually drafts one of the weaker lists.
   - U[2, 4] softens this (r = −0.49), but leaves the league short of the target range.
3. **The naive human drafter benefits.** It drafts by the visible OVR board, which is the consensus ranking, while rivals now err.
   - Its club's mean strength rank goes 14.2 → 8.4 and its wins 8.4 → 10.3 (league mean 12). It makes the finals in 42% of seasons, up from 17%.
   - Career path: rank 13.2 → 6.6.
   - Nothing about the human's club or picks changed. The advantage comes only from rivals being imperfect. A human who drafts well now gains more from it.
4. **Draft time** is about 30% slower: about 6.5 s against about 5 s for a full all-AI career draft, from the per-candidate hashing.

## Tests

- `tests/test_ai.gd` `_test_club_evaluation`:
  - Evaluation is deterministic from the seed and differs with another seed.
  - Two clubs value the same players differently (≥30 of the top 60) and order the top of the pool differently.
  - No club has a net bias. Club SDs are distinct and in range, and errors are capped.
  - Your club and the intake draft get no error.
  - The same seed replays an identical draft, and different seeds give genuinely different drafts.
  - Player ratings are unchanged.
  - Every list is full, has two rucks and fits the cap.
  - A ruck-light human can finish, and no rival takes a fourth ruck.
- `tests/test_league_balance.gd`:
  - A shared valuation still gives one relabelled league; club evaluation gives a different league per seed.
  - The tooling at shipped settings reproduces the shipped draft.
- The existing suites are unchanged and pass: `draft`, `ai` (two or three rucks per club, Gawn in round one, an elite pick one), `save`, `intake`, `expansion`, `balance`, `calibration` and the rest.

## Reproducing

```sh
R=tools/balance/draft_experiment.gd
godot --headless --path . --script $R -- --mode draft  --variant current --policy ai --leagues 1,...,16 --out d_current_ai.json
godot --headless --path . --script $R -- --mode season --variant current --policy ai --leagues 1,...,8 --seasons 3 --out s_current_ai.json
# the pre-change draft, and the other shapes: --variant eval_off | evn_2_4 | evn_3_3 | ...
python3 tools/balance/draft_experiment_report.py <dir> --md report.md
python3 tools/balance/draft_quality.py d_eval_off_ai.json d_current_ai.json
# before/after with the baseline harness and seeds: see LEAGUE_BALANCE.md (pass --policy ai / board)
```
