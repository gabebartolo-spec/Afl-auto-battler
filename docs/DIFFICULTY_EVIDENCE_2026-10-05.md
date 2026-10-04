# Difficulty evidence — 2026-10-05

Four balance-gated findings from the 2026-10-04 multi-season playtest (roadmap §9.1): overall difficulty too low, List Profile top end too easy, extreme margins, and early contract extensions. Measured on `main` at `abbfe94`. **Evidence only: nothing is tuned.** Every lever below changes results and needs a director decision.

Reproduce: `godot --headless --path . --script tools/audit/run_audit.gd -- career_impl <policy> <seed> <club> <seasons>`.

## Method

`tools/audit/career_impl.gd` plays real careers: the League Draft, then five seasons of every round, finals, the National Draft and rollover, with every default left alone (simmed weeks, default event choices, automatic re-signing at the off-season close). There are three user policies:

| Policy | Your drafting | Your management |
|---|---|---|
| **ai** | exactly as an AI club would | none |
| **greedy** | best-rated player you can take (a typical human) | none |
| **light** | greedy | plus accept every early-extension card |

Seven careers in all (Melbourne, Collingwood, Geelong; 35 seasons; 8,281 matches).

## 1. Overall difficulty: neglect *is* punished

Your list strength rank (mean OVR of the best 22) at the start of each season, out of 18:

| Career | 2027 | 2028 | 2029 | 2030 | 2031 | Finishes |
|---|---|---|---|---|---|---|
| ai, MEL | 1 | 2 | 10 | 16 | 20* | 4, 4, 13, 8, 5 |
| ai, COL | 1 | 9 | 12 | 14 | 18 | 9, 14, 10, 12, 10 |
| ai, GEE | 1 | 2 | 6 | 5 | 7 | 11, 6, 6, 5, 4 |
| greedy, MEL | 1 | 13 | 16 | 19 | 20* | 8, 16, 12, 11, 17 |
| greedy, COL | 1 | 13 | 18 | 19 | 20* | 5, 12, 8, 11, 14 |
| light, MEL | 1 | 11 | 17 | 19 | 20* | **1**, 10, 10, 15, 16 |
| light, COL | 1 | 12 | 18 | 19 | 20* | 2, 14, 15, 8, 7 |

\* Expansion clubs bring the league to 19–20 lists.

- **No policy produced a dynasty:** no premierships in 35 seasons, and one minor premiership (top of the ladder), in year one.
- **In-season development is equal:** your list rose +1.7 to +3.0 a season against the AI's +1.8 to +2.7. There's no hidden training edge.
- **The off-season is where an unmanaged list falls away:** −2.0 to −5.0 a year for you against −1.3 to −2.4 for the AI. AI clubs trade and sign free agents; an unmanaged user only re-signs and drafts. The greedy draft loses the most, because it buys older stars who decline.

**The one structural user edge: League Draft information.** In every career your club starts with the #1 list, even when it drafts exactly as an AI club would. AI clubs judge every player with a deliberate 1–5 rating-point error (`Draft._eval_error`); your board shows the exact consensus rating. This is documented and intended (`docs/DRAFT_EVALUATION.md`: "A human who drafts well now gains more from it"). It buys a strong first season, not a dynasty.

**Conclusion:** the playtest's three straight premierships "with minimal engagement" cannot come from autopilot, the training model or extension cards. They must come from the levers a playing human pulls that this harness does not: **live-match calls**, **trades and free agency**, and a year-one draft edge that management then preserves. Those are the next things to measure (see "Next evidence").

## 2. List Profile top end

The Profile words are **league ranks** (`ListProfile.word`: the top share of clubs is Elite), not fixed thresholds. Four Elite words means your side ranks near the top of the league in four of six areas. In year one the greedy draft gives 2–4 Elite; by year five unmanaged lists show 0–1 Elite and 2–4 Weak.

So "Elite in four areas by season 3" is a symptom of genuine list dominance, not loose banding. Tightening the bands would only relabel a dominant list; it wouldn't make the game harder. Recommend no change to the bands; address dominance at its source (§1).

## 3. Extreme margins

| | 0–39 | 40–59 | 60–79 | 80–99 | 100–119 | 120–149 | 150+ |
|---|---|---|---|---|---|---|---|
| All matches (8,281) | 75.1% | 16.3% | 6.2% | 2.0% | 0.4% | 0.1% | **0** |
| Your matches (867) | 71.9% | 18.1% | 7.3% | 2.3% | 0.2% | 0.2% | **0** |

The biggest margin was 134. For comparison, the real AFL season referenced in `LEAGUE_BALANCE.md` has about 1.9% of margins at 100+. Blowouts are, if anything, *rarer* than real football, and your matches look like everyone else's. The playtest's 175–28 needed a dominant list (§1). Recommend no margin-specific change; measure margins again once dominance is addressed.

## 4. Early contract extensions

Your club drew 0–4 early-extension cards a season (mean 1.7). Accepting every one ("light") did not slow the decline. The cards don't pre-solve an off-season on their own: most expiring decisions are still left for the off-season close, where undecided players are re-signed for two seasons automatically if the cap allows. Recommend no frequency change on this evidence. The trade-off of early security (a +15% price, `ClubLife.early_price`) is already in place.

## Decisions for the director

**Answered 2026-10-05:** (1) scouted estimates on your League Draft board; (2) measure live-match calls, the trade market and free agency; (3) the unmanaged collapse is about right.

1. **League Draft information:** keep the exact board (a skill reward), or show your club scouted estimates, as the National Draft already does (`DraftScouting`)? The latter removes the structural edge but keeps drafting skill.
2. **What to measure next:** the levers this harness does not pull, which is where a dynasty must come from:
   - live-match calls, by paired seeded matches (default calls vs a scripted sensible coach);
   - trades and free agency, i.e. whether the AI accepts lopsided trades (ties to *trade valuation by age*, already partly explained by the expansion-POT fix in #213).
3. **Unmanaged lists collapse hard** (rank 20 by year five). Intended consequence, or too harsh?
