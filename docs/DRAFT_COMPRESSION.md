# Why the career draft compresses club strength

This was a controlled experiment and was **measurement only**. Game code,
balance constants, player data, MatchSim, home advantage and career
progression are all unchanged. Each draft variant runs in the tooling only.
Every season is played through the shipped `Season` → `MatchSim`.

> **Note (later change).** The draft measured here as "shipped" is the draft
> *before* club-specific evaluation. That change is described in
> [DRAFT_EVALUATION.md](DRAFT_EVALUATION.md). The experiment's variants still
> reproduce, because a non-empty tooling model leaves club evaluation out
> unless it names `eval_sd`. The tooling variant `current` now means today's
> draft.

The generated tables are in
[`docs/draft_compression_report.md`](draft_compression_report.md). The
harness itself is described in [LEAGUE_BALANCE.md](LEAGUE_BALANCE.md).

## Method

`tools/balance/draft_variant.gd` subclasses the shipped `Draft`. Each variant
changes **one** mechanism:

| Mechanism | Variants |
|---|---|
| Pick order | snake (shipped); linear (the same order every round); a fresh random order each round |
| AI scoring | need weighting halved / removed; replacement (VORP) term removed; soft cap penalty removed; hard cap ×10; best available by worth only |
| Mechanical drafts | best available, no cap, snake or linear. This is the "pure order" control. |
| Valuation noise | every club misjudges every player by a fixed, seeded Gaussian error of SD 2 / 4 / 8 rating points |
| Drafting competence | each club draws its own error SD from U[0, 4], U[0, 8] or U[0, 12] |
| Human | the shipped AI with one naive human (the `board` policy), against an all-AI league |

- The two-ruck rule and the hard budget check always apply.
- At shipped settings the subclass reproduces the shipped draft pick for pick. The CI smoke suite pins this.

**Draft sweep.** 16 drafts per variant measure the preseason spread and the
list shape.

**Seasons.** Each variant plays 12–24 seasons in 4 leagues through the
unchanged engine.

- An all-AI shipped draft is deterministic up to club labels. The labels carry fixture and venue assignments, so deterministic variants are replayed under 4 draft seeds (4 labellings).
- The sample is 396 seasons and 89,892 matches in total, about 4.6 CPU-hours.

**Skill share.** The same lists are replayed with new season seeds.
Skill is the between-club variance of wins net of luck. ± is the standard
error across leagues, typically 3–7 points, so differences under about 10
points are not reliable.

## Results (condensed)

| Model | Sel-22 OVR SD | Squad.strength SD | Skill share | Skill SD (wins) | Stronger side wins | r(strength, wins) | r(OVR, wins) | Lists outside real band |
|---|---|---|---|---|---|---|---|---|
| **Real 2026 lists** (engine ceiling) | 2.31 | 2.19 | 68% ±1 | 3.20 | 62.0% | 0.66 | 0.57 | 0% |
| **Shipped, all-AI** | 0.28 | 2.24 | 41% ±5 | 1.95 | 53.8% | 0.30 | -0.07 | 0% |
| Shipped, naive human | 0.59 | 2.52 | 47% ±9 | 2.22 | 55.9% | 0.45 | -0.23 | 6% |
| Linear order | 0.72 | 1.53 | 35% ±6 | 1.61 | 52.8% | 0.27 | 0.10 | 0% |
| Random order each round | 0.41 | 2.02 | 46% ±4 | 2.23 | 56.1% | 0.41 | 0.14 | 0% |
| Need weighting halved | 0.37 | 2.36 | 37% ±6 | 1.84 | 54.1% | 0.32 | 0.02 | 0% |
| No need weighting | 0.45 | 2.77 | 45% ±4 | 2.10 | 56.7% | 0.40 | 0.05 | **56%** |
| No VORP term | 0.38 | 1.68 | 39% ±4 | 1.98 | 54.0% | 0.29 | 0.01 | 0% |
| No cap penalty (= hard cap ×10) | 0.35 | 2.47 | 38% ±3 | 1.89 | 52.0% | 0.25 | 0.16 | 0% |
| Best available (cap kept) | 0.48 | 2.26 | 45% ±3 | 2.12 | 56.2% | 0.43 | 0.35 | **56%** |
| Mechanical snake (BPA, no cap) | 0.34 | 2.24 | 45% ±2 | 2.06 | 56.9% | 0.46 | 0.11 | **67%** |
| Mechanical linear (BPA, no cap) | 0.56 | 2.49 | 57% ±3 | 2.62 | 57.5% | 0.56 | 0.50 | **39%** |
| Noise SD 2, all clubs | 0.52 | 2.47 | 52% ±7 | 2.45 | 58.2% | 0.48 | 0.21 | 0% |
| Noise SD 4, all clubs | 0.65 | 2.37 | 49% ±9 | 2.29 | 56.5% | 0.40 | 0.26 | 1% |
| Noise SD 8, all clubs | 1.07 | 2.73 | 46% ±4 | 2.27 | 56.8% | 0.39 | 0.28 | 2% |
| Competence U[0,4] | 0.89 | 2.61 | 50% ±9 | 2.33 | 58.2% | 0.48 | 0.47 | 2% |
| Competence U[0,8] | 1.65 | 3.04 | 54% ±7 | 2.60 | 59.6% | 0.60 | 0.52 | 1% |
| Competence U[0,12] | 2.29 | 3.65 | 69% ±3 | 3.69 | 64.9% | 0.73 | 0.71 | 3% |
| Competence U[0,8] + need halved | 1.67 | 3.14 | 51% ±4 | 2.51 | 59.4% | 0.59 | 0.53 | 2% |
| Competence U[0,8] + linear | 1.70 | 3.07 | 69% ±7 | 3.14 | 61.8% | 0.65 | 0.62 | 1% |
| Competence U[0,8], naive human | 1.80 | 3.03 | 72% ±3 | 3.07 | 61.4% | 0.65 | 0.53 | 8% |

**Lists outside real band** is the share of clubs with a role count outside
the range the real 2026 lists span: RUCK 2–4, MID 12–24, DEF 7–14, FWD 4–9.

The report also has:

- unit spreads
- premiership, spoon and finals concentration
- distinct premiers
- 60+ margins

**Real AFL benchmark.** The source is final home-and-away ladders,
2013–2025 (without 2020) plus 2026 (`tools/balance/afl_ladders.json`). With
luck taken as a coin flip:

- Skill share ranges from 54% (2017) to 78% (2013), pooled 71%.
- Skill SD is 3.73 wins over about 22.4 games.
- Noll-Scully is 1.87.

## Answers

### A. Is the extreme parity mainly an unavoidable consequence of a snake draft?

**No. Pick order is a minor factor.**

Order effects:

- Snake, linear and random-per-round orders give skill shares of 41% ±5, 35% ±6 and 46% ±4. These are not distinguishable.
- Linear does not even widen the league with the shipped AI.
- Under a structure-blind mechanical draft, linear order only reaches 57%. It does so by handing the first picks a permanent edge: a top-3 club won 96% of the premierships. That is a dynasty by pick position, not by drafting.

The cause of the compression:

- 18 clubs draft one shared pool with **identical information and an identical valuation**. Any order then splits the pool almost evenly.
- Under every identical-evaluator variant (all orders, all scoring changes), selected-22 OVR SD stays between 0.28 and 0.72. The real lists have 2.31.
- The compression is "unavoidable" only while every club sees the same numbers.

### B. Does the current AI draft logic actively equalise beyond the snake?

**Barely, and not measurably in results.**

Skill share for each change:

| Variant | Skill share |
|---|---|
| Shipped | 41% ±5 |
| Mechanical snake | 45% ±2 |
| No need weighting | 45% ±4 |
| Best available | 45% ±3 |
| No VORP term | 39% ±4 |
| No cap penalty | 38% ±3 |

That makes at most about 4–5 points of equalisation, within noise.

Where equalisation does show:

- **Need weighting** makes every list the same shape, and it gives the lowest OVR SD (0.28).
- Removing it adds about 0.5 of Squad.strength SD and a few points of skill share. But 56% of lists then fall outside the real role band: 1–5 rucks, 5–17 defenders, 25 midfielders.
- Need weighting is what keeps lists believable. It is not the main source of parity.

The cap is not an equaliser:

- The hard cap never binds. Removing the soft penalty and multiplying the budget by 10 produce the identical league.
- Removing the soft penalty does not widen the league (38%).

What the shipped AI does do:

- It equalises **OVR**, not match strength.
- Its clubs have almost identical OVR (spread 1.05) but different engine make-up: r(OVR, strength) is 0.07.
- Contest SD is 5.2 and mid-line SDs are 7–8. On the real lists these are 3.1 and about 4.

### C. Would heterogeneous or noisy club evaluation create useful inequality?

**Heterogeneous competence yes. Uniform noise only a little.**

Uniform noise (every club equally fallible):

- It reshuffles who gets lucky: up to 100% distinct premiers.
- Skill share rises only to 46–52%. Errors average out over 37 picks, and every club is equally wrong.

Competence that differs by club:

- Skill share is 50% for U[0,4], 54% for U[0,8] and 69% for U[0,12].
- Selected-22 OVR SD rises to 0.9, 1.65 and 2.29. U[0,12] is essentially the real lists' 2.31.
- OVR becomes meaningful again: r(OVR, wins) is 0.47–0.71.
- Lists stay believable, with 1–3% outside the real band.

This is the only mechanism tested that adds inequality while keeping list construction believable. The inequality is systematic: good evaluators build good lists. Scale:

- A mean error SD of 4 (U[0,8]) is a plausible spread in how well clubs judge established players.
- U[0,12], a mean of 6, is at the generous end.

### D. Is selected-22 OVR hiding considerable meaningful variation?

**Yes: OVR hides a lot of variation. But much of it is sideways trade-offs, which the engine only partly turns into wins.**

In the shipped all-AI league:

- OVR SD is 0.28, yet Squad.strength SD is 2.24, the same as the real lists (2.19).
- Unit spreads are larger than on the real lists: ruck 7.5, mid contest 6.9, mid carry 8.2.

What predicts club skill (mean wins over replayed seasons, centred within league):

| | Pooled over all drafted leagues (1,512 clubs) | Shipped all-AI only (72 clubs, adjusted R²) |
|---|---|---|
| Selected-22 OVR | 0.22 | ≈0.01 |
| Squad.strength | 0.39 | ≈0.22 |
| Contest / attack / defence | 0.43 | ≈0.21 |
| The 11 line aggregates | 0.51 | ≈0.39 |
| Ceiling (skill share of the target) | 0.76 | 0.77 |

How to read this:

- In the shipped league, OVR explains nothing of club strength.
- The line aggregates explain about half of what is explainable.
- The same Squad.strength spread as the real lists buys a 54% stronger-side win rate, against 62% for the real lists. The drafted variation is mostly trade-offs, such as strong contest with weak defence. In one shipped league (seed 1), the strongest clubs by Squad.strength have contest 80–83 and defence 48–49, while the weakest-contest club has 63 and 57. It is not better or worse clubs.
- `Squad.strength` also weights the lines differently from how MatchSim rewards them. The 11-line fit beats it.
- The unexplained third comes from fixture and venue labels, the bench, discipline, traits and per-player rolls.

### E. How much differentiation can draft and list construction alone recover before touching MatchSim?

**Up to about the engine's real-list level, and no further.**

With believable lists:

| Draft | Skill share | Stronger side wins |
|---|---|---|
| Shipped | 41% | 54% |
| Competence U[0,8] | 54% | 60% |
| Competence U[0,12], or U[0,8] with linear order | 69% | 62–65% |

The engine ceiling:

- Real lists in the unchanged engine give 68%, a 62% stronger-side win rate, and 60+ margins of about 9%.
- Draft changes cannot push past that ceiling without making lists that don't look like a real list.
- Removing structure (no need, BPA, mechanical) buys only 45–57%, and it breaks list shape.

The engine's own compression, revised:

- Measured against a 13-season benchmark rather than the 2026 season alone, it is milder than the baseline suggested.
- Per-game win% skill SD is 0.133 with real lists against 0.166 for the real AFL. That keeps about 64% of the real talent variance, not half.

### Human draft effect

- The naive board drafter moves skill share from 41% ±5 to 47% ±9: within noise.
- With competence U[0,8] it moves 54% ±7 to 72% ±3.
- The effect comes mostly from the human's own club, which drafts a structurally lopsided list and ends near the bottom (see the baseline). Up to 29 midfielders and 0 primary forwards appear on a board-policy list.
- Excluding the human club, the baseline measured 40% for the AI-drafted clubs alone: the same as the all-AI league.

## Benchmark for a league that redrafts the whole pool (recommendation, not implemented)

Why the mature AFL is the wrong target for season one:

- The real AFL's spread is accumulated: years of unequal drafting and development, trades, injuries, and list cycles where rebuilding clubs deliberately give up the present.
- A full redraft removes all of that. Every club drafts to win now, from one pool, at the same time.
- Season one should therefore sit **below** the mature AFL (pooled 71%, range 54–78%). It should also sit above a coin-flip league, where drafting would not matter.

The reasoning for the range:

- **Floor.** The pure identical-evaluator draft gives about 40–45%. Below that, the ladder is mostly luck and the player's draft is barely visible.
- **Ceiling.** The most even real AFL seasons were 2017 (54%) and 2019 (60%). A fresh redraft with no inherited cycles should not start more unequal than an even real season.
- **Headroom.** Development, ageing, trades and the player's own management should grow the spread towards the mature 65–75% band over roughly 3–5 seasons.

**Recommended initial post-draft range (season one, about 23 games):**

| Measure | Range | Shipped now (all-AI / naive human) |
|---|---|---|
| Skill share of season-win variance | **45–60%** | 41% / 47% |
| Skill SD of wins | 2.2–2.9 (win% SD ≈ 0.10–0.13) | 1.95 / 2.22 |
| Preseason stronger side wins | 57–61% | 54% / 56% |
| r(preseason strength, wins) | 0.45–0.65 | 0.30 / 0.45 |
| r(selected-22 OVR, wins) | clearly positive (≥0.4) | -0.07 / -0.23 |
| Premierships won by a top-3 preseason club | about 40–60%, with many distinct premiers | 54% / 42% |

What this means for the shipped draft:

- By skill share it sits at or just under the bottom of this range. The draft is less broken than the OVR spread (8× compressed) suggests.
- The clearer defect is that **OVR does not predict results in a drafted league**. That is the D finding.
- Competence U[0,8] lands mid-range with believable lists: 54%, 60% and 0.60.

Nothing above has been implemented.

> **Update (OVR alignment).** The OVR formula has since been re-weighted to
> what the engine rewards per role ([DESIGN.md](DESIGN.md), "Overall &
> salary"). On the same selected 22s the new rating predicts wins better
> (AI clubs in these drafted leagues: r 0.35 → 0.46), and the 3+ OVR anomaly
> is gone. In the full career-draft pipeline, re-run with the same seeds
> (24 board-policy seasons, 12 all-AI, 4 career), r(selected-22 OVR, wins)
> moved only 0.17 → 0.22 (board), 0.34 → 0.34 (all-AI) and 0.38 → 0.25
> (career, 4 seasons, ±0.1). Clubs now draft on an engine-truthful rating, so
> drafted lists come out closer in engine strength (`Squad.strength` SD
> 2.5 → 2.1) and every preseason measure predicts less: `Squad.strength`
> itself, built from the engine's own inputs, reaches only r ≈ 0.3-0.5 with
> wins in a drafted league. The ≥ 0.4 target is capped by that, not by the
> rating - it belongs with engine decisiveness and the draft spread.

## Reproducing

```sh
R=tools/balance/draft_experiment.gd
# preseason sweep, one variant (names: VARIANTS in draft_experiment.gd)
godot --headless --path . --script $R -- --mode draft --variant comp8 --policy ai --leagues 1,2,...,16 --out d_comp8_ai.json
# seasons: deterministic variants use 4 draft seeds (labellings)
godot --headless --path . --script $R -- --mode season --variant current --policy ai --leagues 1 --seasons 12 --out s_current_ai.json
godot --headless --path . --script $R -- --mode season --variant current --policy ai --leagues 2,3,4 --seasons 4 --out s_current_ai_b.json
godot --headless --path . --script $R -- --mode season --variant comp8 --policy ai --leagues 1,2,3,4 --seasons 3 --out s_comp8_ai.json
godot --headless --path . --script $R -- --mode season --variant real --leagues 1 --seasons 12 --out s_real.json
python3 tools/balance/draft_experiment_report.py <dir with the shards> --md report.md
```

Seeds:

- Draft seed L; the board drafter uses L × 31 + 7.
- Club noise: each club's error SD is drawn from `L * 7717 + 13`, and its per-player errors from `hash("L|CLUB")`.
- Random-per-round order uses L × 104729 + 3.
- Season s of league L uses L × 1000 + s + 1.

Board-policy leagues use 201–216 for drafts and 201–204 for seasons. All-AI leagues use 1–16 and 1–4.
