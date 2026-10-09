# Lever-truth audit, part 2: contracts, trades, the draft and scouting

ROADMAP §0.4.1 item 2: every gameplay lever must work and its copy must tell the truth. Part 1 (training, plans, tags, projects) is `LEVER_TRUTH_AUDIT.md`. This part covers the off-season levers. **Findings only: nothing here changes a rule.**

## Method

Tool: `tools/audit/levers2_impl.gd`, run on GitHub through `audit.yml` (branch `claude/lever-audit-2`). One League Draft career per seed (`dynasty.gd`'s upside draft; the club on autopilot at matches, an attentive human in the off-season). Seeds 301–306, 5 seasons each, so 6 careers and 30 seasons per arm. Arms are paired on seed: one switch changes, everything else is identical. Printed per run: `SEASON`, `CAP`, `PICK` (every National Draft pick with the AI's price for the slot), `TRACK` (draftees, probe pairs and re-signed kids each season), `PROBE` (trade offers asked of every rival and never made), `OFFSEASON`, `SUMMARY`.

| Arm | Switch | Run |
|---|---|---|
| Baseline | none (trade list, term ask, recruiting Standard) | 37975590404 |
| Trade full | `L2_TRADE=full` | 37975594523 |
| Trade exploit | `L2_TRADE=exploit` | 37975598636 |
| Short kid terms | `L2_TERM=short` (kids 23 or under re-signed for one season) | 37975601880 |
| Long kid terms | `L2_TERM=long` (four seasons) | 37975605350 |
| Recruiting 0 | `L2_RECRUIT=0` | 37975609309 |
| Recruiting 3 | `L2_RECRUIT=3` | 37975613715 |

Smoke run: 37954355236. Ladder numbers below are the mean finishing position over the 5 seasons (lower is better); "diff" is the paired arm minus baseline by seed, mean ± standard error over 6 seeds.

## 1. Contracts: length and price

**Claims.**
- `Contracts.stance`: "He'd give a little on salary for the security he wants." Given the term he wants or longer he gives up to a fifth of his price; shorter than he wants costs more.
- A kid's salary is fixed for the whole term while he improves, so a long cheap deal on a young player should pay off.
- Trade requests need `contract_years > 1`, so a long deal enables a player asking out.

**Measured** (60 kids aged 23 or under re-signed per arm):

| | Short (1 season) | Baseline (3 seasons, what he asks) | Long (4 seasons) |
|---|---|---|---|
| Salary at re-signing, mean | $644k | $529k | $529k |
| Rating at signing, one season on | 67.5 → 68.3 | 67.0 → 68.9 | 67.0 → 68.9 |
| Salary one season on | $644k (new deal due) | $529k | $529k |
| Players asking out, 6 careers | 17 | 20 | 20 |
| Ladder, diff vs baseline | +0.13 ± 0.98 | | −0.03 ± 0.03 |

- A three-year deal is about 18% cheaper than a one-year deal ($529k against $644k). The discount is real and it is the stated one.
- **Longer than he asks gives no extra discount**: the four-year arm signs at exactly the three-year price and plays out almost identically to baseline. The copy says "for the security he wants", which is accurate, but a player reading "longer = cheaper" would expect more from four years than three.
- The salary does not move while the kid improves (about +1.9 rating in the first season on the same $529k). That part of the implied payoff is real.
- One-year terms cost 22% more per kid, re-sign about a third more often (256 against 190) and make no measurable difference to the ladder in 6 careers.
- Asking out is not driven by term in this sample: the long arm equals baseline and the short arm is 3 lower, well inside the noise.

**Verdict: true as worded; the term-to-price link stops at the term he asks for.** **Suggested fix:** none needed for the stance line. If a longer deal is meant to be worth more to the club, the discount would have to continue past his asked term; otherwise say nothing about longer than asked.

## 2. Trades: does the AI accept lopsided offers?

**Claims.**
- The trade screen's phase lines (`OffseasonScene.gd`): rebuilders "guard young talent and want players for the future"; contenders "want players who help them win now."
- A trade needs both sides to be fair in the AI's value.

**Measured** (baseline run; offers asked of every rival and never made):

| Probe | Result |
|---|---|
| Their best player for 2 to 5 of your best spares (quantity for quality), 432 probes | **0 accepted** in every phase (building 133, contending 131, rebuilding 168) |
| An old star (30+) for their best kid (22 or under, POT 6 or more above rating), 792 probes | Contending accept 62% (132/212); building 47% (120/256); rebuilding 13% (42/324) |
| Why the rest said no | Rebuilding: 135 of 324 "rebuilding cornerstone", 124 "well short". Building and contending: mostly "well short" |
| The same pairs followed afterwards | The kid gained +3.3 rating after one season and +5.4 after two; the old star lost −3.2 and −6.7 (fewer old stars left to count by the second season) |
| One pick alone, round 1, 432 probes | 329 buy nothing; the 103 that buy something average 70 rating, best 81 |
| One pick alone, rounds 2 and 3 | Buys nothing in 346/432 and 394/432; the rest average 65 |

| Arm | Trades made, 6 careers | Ladder diff vs baseline |
|---|---|---|
| Baseline (trade list) | 0 | |
| Trade full | 1 | 0.00 |
| Trade exploit | 9 | −1.9 ± 1.0 (better) |

- **The quantity exploit is closed**: no pile of spares ever bought a star.
- **The old-star-for-kid trade is open and costly to the AI**: contenders and building clubs hand over their best kid for an old star about half the time or more, and the kid then grows by five rating points in two seasons while the old star loses six or seven. The phase lines are true in direction (rebuilders refuse 87%), but they do not warn that a contender will sell its future.
- The exploit arm is worth about two ladder places on average (not significant at 6 careers; 4 of 6 seeds improved, 2 slightly worse).

**Verdict: the phase copy is true; the "fair trade" claim is overstated** for old stars against young talent with contenders and building clubs. **Suggested fix:** a director call, not a copy fix. Options: leave it (it is a legitimate, discoverable trade), make contenders and building clubs apply the rebuilding-style guard to their best kid, or price a kid's growth into `TradeValue` more strongly. Part 1's balance document (`COMPETITIVE_BALANCE.md` §7, §11) already covers exploit mode.

## 3. The draft: what a pick is worth

**Claim.** The AI prices a pick by its slot (`TradeValue.pick_value`); an early pick should be worth more than a late one.

**Measured** (baseline: every National Draft pick in 6 careers over 4 drafts, then followed with `TRACK`):

| Slot | n | AI price (building club) | Rating / POT on draft night | Rating after 1 season | after 2 | after 3 | Games per season (after 1) |
|---|---|---|---|---|---|---|---|
| 1–5 | 120 | 1.85 | 72 / 87 | 76.8 | 79.7 | 82.8 | 21.2 |
| 6–15 | 240 | 1.40 | 69 / 83 | 73.5 | 75.8 | 78.1 | 22.3 |
| 16–30 | 360 | 0.93 | 64 / 75 | 67.5 | 69.9 | 71.4 | 21.5 |
| 31 and later | 438 | 0.55 | 58 / 67 | 61.8 | 62.1 | 60.8 | 16.6 |

- Three seasons on, an early pick is about 11 rating points better than a mid-first-round pick, and 22 better than a late pick. The AI price ratio between pick 1–5 and 16–30 is about 2.0, so the price follows the value in direction, and it is not exaggerated.
- Late picks (31 on) stop developing: the average slips from 62.1 to 60.8 in the third season and they play about 5 fewer games a season.
- Your club's own picks are drawn from the same pool and sit in the 16–30 band on average (mean slot 25).

**Verdict: true.** **Suggested fix:** none. Late picks are real depth, not stars; copy that suggests otherwise would be false, and none was found.

## 4. Scouting (the recruiting budget)

**Claim.** Recruiting is the only scouting lever: "Prospect scouting uncertainty is 25% wider than standard / 20% narrower / 35% narrower" (`ClubBudget.benefit_text`). It changes how wide the POT range you are shown is; it does not change the prospect (`GameState.pot_view`, `DraftScouting.pot_read`).

**Measured** (your club's own picks and its results):

| | Level 0 | Standard | Level 3 |
|---|---|---|---|
| Your picks, n | 68 | 70 | 70 |
| Mean slot | 24.8 | 25.0 | 25.3 |
| Mean POT of your picks | 74.2 | 74.8 | 74.0 |
| Mean rating two seasons on | 68.2 | 69.3 | 68.3 |
| Ladder, diff vs Standard | −0.87 ± 0.41 | | +0.23 ± 0.88 |

- No outcome effect: the autopilot drafts on the true ratings, as the AI does, so the budget has nothing to act on. That is the expected result for a lever that only changes what the player is shown.
- The level 0 arm finishes about one place better than Standard (−0.87 ± 0.41). That is the opposite of what a "weaker scouting" setting should do, and it is not explained here. The runs do not show why; with 6 careers it may be noise.

**Verdict: true as worded, and untestable here.** The copy promises a narrower or wider range on screen, not a better pick, and says no more. **Suggested fix:** none for the copy. Whether a human actually drafts better with a narrower range needs a play test, not an autopilot audit.

## Summary of verdicts

| Lever | Verdict | Fix, if any |
|---|---|---|
| Contract term and price | True as worded; no extra discount past the term he asks | None needed |
| Trade phase lines | True in direction | None |
| Trade fairness | Overstated for old star for best kid with contenders and building clubs | Director call: guard, re-price, or leave |
| Draft pick value | True | None |
| Scouting (recruiting budget) | True as worded; effect is display only | None; play test if wanted |

## Not exercised

- Six seeded careers of five seasons on autopilot matches: this separates large effects (draft value, the quantity exploit being shut) but not small ones (ladder differences of one place).
- The bot manages the off-season one way (`dynasty.gd`'s attentive human); a human may play these levers better or worse.
- Probes ask, never trade: acceptance is measured, consequences are inferred from the tracked players.
- The exploit arm made 9 trades in 6 careers; its ladder gain is suggestive, not proven.
- A human reading the narrower scouting range is not simulated.
- Real AFL contract and draft rates are not compared here.
