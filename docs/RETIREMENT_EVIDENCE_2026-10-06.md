# Retirements: who retires, and who a coach could persuade (2026-10-06)

Evidence for the director's "Retirement persuasion" item (BALANCE-GATED).
Measured on `main`; measurement only.

## Method

`tools/audit/retirement_impl.gd` (branch `claude/retirement-audit`, run on
GitHub via `audit.yml`). It plays four League Draft careers (seeds 1–4, every
club drafting as an AI would, you are MEL), five seasons each, so 16 season
rollovers. Before each off-season, every listed player and free agent is
snapshotted:

- age, OVR, POT and career games;
- what injury state is recorded (`injury_weeks`, `injury_kind`, `rehab`);
- morale and the form it gives (`ClubLife.form`);
- whether he is in his club's best 22;
- his position's selection bar (`TradeValue.selection_bars`, the weakest
  player his club picks there).

Each rollover's retirees (`Prospects.age_league`) are matched to those
snapshots. The rule that retired each one is read from
`Prospects.should_retire` on his aged age and OVR.

**The rule today** (after ageing): OVR ≤ 32 always retires; age 37+ always
retires; age 35–36 retires on a 70% roll whatever his OVR; age 33–34 with
OVR < 42 retires on a 30% roll. At most 8 a club, and never below the minimum
list size.

## Who retires

290 retirements in 16 rollovers: **about 18 a season league-wide, or one a club**.

- **A defect: veterans signed in the off-season retire at the same rollover.**
  80 of the 290 (28%) were free agents at season's end, were signed in the
  off-season's free agency (`_close_contracts`, which runs before ageing),
  and retired at that same rollover without playing a game for their new
  club. In seed 1 that's 21 of 72 (examples: a 36-year-old OVR 77 signed by
  Carlton; a 37-year-old OVR 48 signed by Richmond). A list spot and cap are
  spent on a player who leaves before the season. Fixing the order (age the
  free-agent pool, or retire 35+ free agents, before free agency) is
  separate from persuasion and worth doing first.
- **Of the 210 retirees who were on a list at season's end:**
  - By rule: age 35–36 roll 182, age 37+ 25, OVR floor 2, age 33–34 roll 1.
    Retirement is almost entirely the age-35 roll, which ignores how good he
    still is.
  - Age: 35 (99), 36 (72), 37 (20), 38 (13), 39–40 (5), 34 (1).
  - End-of-season OVR: p10 49, median 65, p90 82, max 87. Career games: median
    299.
  - **72% were still in their club's best 22** (151 of 210). Against the
    position bar (OVR minus the weakest player his club picks there): p10
    −16, median 0, p90 +19, max +29. Examples that retired on the 35–36 roll:
    OVR 85 forwards at 36 with 320+ games, sitting 24–29 above their club's
    bar, and an OVR 87 forward at 35.

## Candidate eligibility lines for "healthy OVR"

These count retirements a season that a coach could try to persuade, from the
210 on lists:

| line | league-wide a season | per club a season | your club (MEL) a season |
|---|---|---|---|
| in the best 22, or within 2 of his position's bar | 10.3 | 0.57 | 0.75 |
| in the best 22 and at or above the bar | 6.9 | 0.39 | 0.50 |
| 5+ above the bar | 4.7 | 0.26 | 0.38 |
| 10+ above the bar | 3.3 | 0.18 | 0.19 |
| OVR 75+ | 3.7 | 0.20 | 0.19 |
| OVR 80+ | 1.8 | 0.10 | 0.06 |

A line around "in the best 22 and at or above the bar" makes the decision come
up roughly every other season for a club. "5+ above the bar" makes it about
every third season and keeps it about players who still matter. That's a
director call.

## What is recorded to explain a refusal

- **Injury:** only the current state at season's end (`injury_weeks`,
  `injury_kind`) and `rehab` (an injury-shortened season). Among the 164 on
  the broadest line: 8 injured at season's end, 5 in rehab. **There is no
  career injury history** (nothing counts past injuries), so "his body's had
  enough" can only cite this season's injury.
- **Morale:** recorded, but on `main` it carries no signal for rival players.
  Retirees' morale is 70 at p10, median and p90 (5 distinct values), because
  rival morale doesn't move until #228's `_rival_morale_after_round` lands.
  Form is derived from morale (`ClubLife.form`), so it's flat too.
- **Usable today:** age, career games (a 300-gamer's milestone is a genuine
  reason), OVR against his position bar (still in the side or not), and this
  season's injury or rehab.
