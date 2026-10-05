# Active-play levers — 2026-10-05

Follow-up to `docs/DIFFICULTY_EVIDENCE_2026-10-05.md`, which showed an unmanaged list cannot build a dynasty. The director asked to measure the levers an active human pulls: **live-match calls**, **the trade market** and **free agency**. **Evidence only: nothing is tuned.**

Reproduce:

```
godot --headless --path . --script tools/audit/run_audit.gd -- calls_impl   # CALLS_REPS=30 for 1,080 matches
godot --headless --path . --script tools/audit/run_audit.gd -- career_impl trader|fa <seed> <club> 5   # 8 seasons for the realised-value ledger
```

## 1. Live-match calls

`tools/audit/calls_impl.gd`: 216 paired matches between neighbours in strength on four drafted leagues. You play at home; the opposition is an AI club picking its own plans. Every policy plays the same sides and seeds. No moment cards fire: the harness leaves `moment_side` unset, as for any simulated match, so these figures are the plans alone (set shots, tired stars and the other cards are not in them).

| Your calls | Win % | Mean margin |
|---|---|---|
| Balanced all match (no calls) | 61.1% | +7.1 |
| Counter their last plan at each break (what the break shows you) | 64.4% | +8.9 |
| Attacking corridor all match | 54.2% | +5.2 |
| **Defensive press all match** | **67.8%** | **+14.0** |
| Contested all match | 62.5% | +9.5 |
| Controlled tempo all match | 59.5% | +8.0 |
| Through the stars all match | 56.7% | +7.2 |

- **Reading the calls is worth about 3 points of win rate**, a real but modest lever. That's the intended scale: a good plan helps without guaranteeing anything.
- **Defensive press all match is the outlier**: +6.7 points of win rate and double the margin. At n = 216 that is about two standard errors, so worth confirming on a larger sample before acting. If it holds, Defensive press is a dominant default against the AI.
- A per-match "best plan in hindsight" figure (98.8%) is **not** a finding: each plan sends the match down a different random path, so the best of six afterwards is just the luckiest.

### Rerun at 1,080 matches (director's request)

Same set-up, five times the sample (`CALLS_REPS=30`):

| Your calls | Win % | Mean margin |
|---|---|---|
| Balanced all match (no calls) | 59.8% | +7.5 |
| Counter their last plan at each break | 63.3% | +10.9 |
| Attacking corridor all match | 56.6% | +5.7 |
| Defensive press all match | 62.2% | +12.0 |
| Contested all match | 59.8% | +9.6 |
| Controlled tempo all match | 56.5% | +6.4 |
| Through the stars all match | 59.5% | +8.5 |

By the plan the AI opened with (win %):

| AI opens with | Balanced | Counter | Defensive press |
|---|---|---|---|
| Contested (n = 180) | 55.6% | 57.2% | 55.8% |
| Attacking corridor (n = 240) | 55.6% | 71.7% | 68.3% |
| Defensive press (n = 270) | 47.6% | 50.9% | 44.4% |
| Balanced (n = 390) | 72.7% | 69.6% | 73.7% |

- **Defensive press is not dominant.** The 216-match outlier shrank from +6.7 to +2.4 points over Balanced, about one and a half standard errors, and it sits below reading the game (+3.5).
- **It behaves like a counter, not a default.** It beats an AI opening in Attacking corridor (+12.7 points) and loses ground against an AI that also presses (−3.2). That is the trade-off the plans are meant to have.
- **Its margin is still the widest of the fixed plans** (+12.0 against +7.5). It wins by more when it wins rather than winning much more often; worth watching in the extreme-margin numbers, not a reason to tune.
- **Reading the game remains the real lever**, worth about 3.5 points of win rate and +3.4 on the margin.
- Paired seeds share a start, not a path: each plan consumes the random stream differently from the first call onwards.

## 2. Trade market

`career_impl trader`: an AI-style draft, then each off-season a bot makes up to four trades. Each one is a deal an AI club accepts (`GameState.evaluate_trade`) that raises your next-season best 22. That's age-adjusted: nobody over 30, and players past 29 decline.

| Seed | List rank, trader | List rank, no trades | Finishes, trader |
|---|---|---|---|
| 1 (MEL) | 1, 1, 6, 13, 19 | 1, 2, 10, 16, 20 | 2 (premiers), 1, 8, 7, 9 |
| 2 (COL) | 1, 2, 3, 7, 16 | 1, 9, 12, 14, 18 | 16, 18, 14, 16, 18 |

- **Trading props up list strength for two to three years.** A determined trader holds a top-3 list where an untraded one slides to 9th–12th.
- **Ratings bought without list shape don't win.** In seed 2 a top-3 list finished 14th–18th: the bot ignores positions.
- **The exploitable pattern: "kids for a prime star".** For example, GWS gave **Jordy Carr (83 OVR, age 25) for two 18-year-olds rated 67 and 68**, and St Kilda gave a 76-rated 28-year-old for one 71-rated 20-year-old.
- **Cause:** `TradeValue.future_rating` credits 60% of a young player's gap to POT as if it were certain, with no allowance for players who never reach it. On the steep value curve (`(rating/70)^5`), two unproven 18-year-olds then outweigh an established star.
- **Proposed fix (needs sign-off):** discount the future part by how proven the player is (for example by senior games played), so an 18-year-old's ceiling counts for less until he has shown it. This also interacts with #222: rival POT is now a range, which makes these targets harder to spot.

## 2b. Realised versus projected trade value (director's follow-up)

The research's market card asks for realised value, not only projected. `career_impl trader <seed> <club> 8` now keeps a ledger: every player in a completed trade, what `TradeValue.future_rating` projected for him at the trade, and his peak OVR and senior games afterwards. Three eight-season careers (seed 1 MEL, 2 COL, 3 GEE) were run twice: with the current valuation and with #224's unproven-potential discount (same seeds; the trades differ once the valuation does). Peaks are measured to the end of 2034, so later trades have shorter windows.

| Traded players, by age at the trade | Current valuation: projected → peak | With #224: projected → peak |
|---|---|---|
| Kids you gave away (21 and under) | 69.9 → 69.8 (−0.1, n = 23) | 66.1 → 67.4 (+1.3, n = 22) |
| Stars you got (28 and over) | 73.5 → 73.5 (n = 18) | 74.0 → 74.0 (n = 17) |

- **The current projection is accurate for kids.** Players like Elias Colombo (67, POT 85 at 18, projected 77.8) peaked at 79; across 23 kids the average miss is a tenth of a point. The 60% credit does not over-value youth on this evidence.
- **#224's discount under-projects them.** With it, the same kind of kid beats his projection by more than a point (Colombo projected 75.2, still peaked at 78).
- **The stars do what their age says.** They never improve, and by the end most have dropped 10 to 15 points or left the game (Jarrod Simic 81 at 29, 66 and gone five years later; Elijah Lewis 83, 70 and gone).
- **The "kids for a star" trade is a short-term deal, not an exploit.** The kids went on to 100 to 160 senior games each. The trader won early (premierships in year one or two in some careers) and then collapsed to list rank 17 to 20 in both valuations.
- **Implication for #224 (needs a decision):** realised outcomes do not support discounting unproven potential. If the concern is that a human can buy a premiership window cheaply, that is a question about what a rebuilding club should accept for its future, not about projection error. Options: close #224, soften it, or keep it as a deliberate difficulty choice.
- Sample: three careers, about 23 kids per valuation. Directionally clear, not precise.

## 3. Free agency

`career_impl fa`: each off-season you bid the asking price, plus any premium, for up to four of the best free agents better than your 22nd player.

- **You never won a bid at asking price.** In every case a rival's offer led ("Hawthorn's offer leads"), because AI clubs bid above asking for the players they want.
- **The free-agent pool is old:** of 16 bids, 15 were for players aged 33–35. Lists collapsed as fast as with no management (rank 16–18 by year five).
- **Free agency is not a dynasty lever.** A human would have to overpay, which is the intended price.

## Conclusion and decisions

The levers that matter, in order: **the trade market** (exploitable through youth over-valuation), **the year-one draft edge** (removed by #222), then **live-match calls** (modest: about 3.5 points for reading the game; the Defensive press outlier did not hold at 1,080 matches). Free agency is not a lever.

For the director:

1. **Trade valuation:** discount unproven potential in `TradeValue` (proposal above)?
2. **Defensive press:** rerun calls at about 1,000 matches to confirm before any tuning? **Done:** it did not hold (+2.4 points, a counter to Attacking corridor rather than a dominant default). No tuning recommended.
