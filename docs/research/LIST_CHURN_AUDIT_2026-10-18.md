# List churn audit, 2026-10-18

P-81 "List churn stays real" (proposals pass 2, director yes 2026-10-18). Does an AI club move on and bring in about as many players a year as a real AFL club? Measurement only: the audit reports, the director decides (design bible: balance is his call).

## Method

- `tools/audit/list_churn_impl.gd` run through `audit.yml` (CI runs 39063014675,39063028548,39063044176,39063082906). 8 seeded careers (seeds 301, 302, 303, 304, 305, 306, 307, 308), 10 off-seasons each (2027 to 2036), on autopilot: the League Draft, each season played with `advance()`, each off-season run by the calls the game makes (contracts, free agency, trades between rivals, the national draft, the rollover), no management of any list.
- Each club's list is compared from the last week of the season to the new season's list. A player who left is a retirement, a trade (named in the off-season log), a walk (the club wanted him but could not fit him) or a delisting; one who arrived is a draftee, a trade or a free-agent signing. A player released into the market and back on the same club's list is not a change and is left out of both columns.
- Your own club is on autopilot like the others, but it is left out. Counted: 1488 AI club-years (20 clubs).

## The yardstick

**Real AFL: roughly 8 to 12 list changes a club a year** (the lead's brief for this audit; the candidate, C-PC-23, names no number). The audit compares **players leaving a club in a year** (retired + delisted + walked + traded out) with that range, and shows players arriving (drafted + traded in + signed) beside it.

Cross-check from the Wikipedia draft pages for 2021 to 2025 (`<year> AFL draft`, "List changes" and "Trades" tables), counted by table rows on 2026-10-18; the pages are uneven (the 2023 page's tables did not parse and is left out, 2024 and 2025 have no free-agency table), so these are rough:

| Year | Delistings | Retirements | Trade table rows | National draft picks | Exits a club from delistings and retirements alone |
|---|---|---|---|---|---|
| 2021 | 94 | 9 | 10 | not counted | 5.7 |
| 2022 | 89 | 36 | 19 | 61 | 6.9 |
| 2024 | 62 | 31 | 32 | 73 | 5.2 |
| 2025 | 48 | 26 | 29 | 62 | 4.1 |

So the pages show a real club losing about 4 to 7 players a year to delisting and retirement alone; trades, free-agency departures and the rookie list come on top, which is how a figure of 8 to 12 comes about. The 8 to 12 range is the lead's number; this table only checks it is about the right size, it is not a second yardstick.

## Result

Players leaving, per AI club per year (1488 club-years):

| | Mean | Min | 10th pct | Median | 90th pct | Max |
|---|---|---|---|---|---|---|
| **Leaving (out)** | 9.1 | 1 | 6.0 | 9.0 | 12.0 | 16 |
| **Arriving (in)** | 9.3 | 1 | 7.0 | 9.5 | 12.0 | 14 |
| delisted | 6.2 | 0 | 3.0 | 6.0 | 9.0 | 11 |
| walked | 0.1 | 0 | 0.0 | 0.0 | 0.0 | 2 |
| retired | 1.4 | 0 | 0.0 | 1.0 | 3.0 | 9 |
| traded out | 1.4 | 0 | 0.0 | 2.0 | 2.0 | 4 |
| drafted | 2.6 | 0 | 1.0 | 3.0 | 4.0 | 7 |
| traded in | 1.4 | 0 | 0.0 | 2.0 | 2.0 | 4 |
| signed | 5.3 | 0 | 3.0 | 6.0 | 6.0 | 8 |
| list size after | 39.1 | 32 | 36.0 | 39.0 | 41.0 | 44 |

Club-years with players leaving inside 8 to 12: **984 of 1488 (66%)**; below 8: 380 (26%); above 12: 124 (8%).

### By off-season (mean over the AI clubs and seeds)

| Year | Out | In | Delisted | Walked | Retired | Traded out | Drafted | Traded in | Signed |
|---|---|---|---|---|---|---|---|---|---|
| 2027 | 5.6 | 7.8 | 3.4 | 0.2 | 0.5 | 1.4 | 2.6 | 1.4 | 3.8 |
| 2028 | 8.4 | 7.6 | 5.7 | 0.2 | 1.2 | 1.3 | 2.5 | 1.3 | 3.8 |
| 2029 | 8.0 | 8.9 | 5.7 | 0.1 | 0.9 | 1.3 | 2.6 | 1.3 | 5.0 |
| 2030 | 9.6 | 9.4 | 6.7 | 0.1 | 1.3 | 1.6 | 2.4 | 1.6 | 5.4 |
| 2031 | 9.2 | 9.4 | 6.4 | 0.0 | 1.4 | 1.4 | 2.6 | 1.4 | 5.4 |
| 2032 | 9.6 | 9.9 | 6.9 | 0.0 | 1.2 | 1.4 | 2.5 | 1.4 | 6.0 |
| 2033 | 10.1 | 9.9 | 6.8 | 0.0 | 1.7 | 1.6 | 2.7 | 1.6 | 5.6 |
| 2034 | 10.0 | 10.1 | 6.9 | 0.0 | 1.7 | 1.4 | 2.8 | 1.3 | 5.9 |
| 2035 | 10.3 | 10.0 | 6.8 | 0.0 | 2.1 | 1.5 | 2.8 | 1.5 | 5.7 |
| 2036 | 9.7 | 10.3 | 6.8 | 0.0 | 1.4 | 1.5 | 2.7 | 1.5 | 6.1 |

### By club (mean over seeds and years)

| Club | Years | Out | In | Out 10th..90th pct | Flag |
|---|---|---|---|---|---|
| ADE | 80 | 9.7 | 10.0 | 6..12 |  |
| BRL | 70 | 9.3 | 9.5 | 7..12 |  |
| CANB | 56 | 10.1 | 10.6 | 6..13 |  |
| CAR | 80 | 8.7 | 9.1 | 6..12 |  |
| COL | 80 | 8.9 | 9.2 | 6..12 |  |
| ESS | 70 | 9.1 | 9.3 | 5..13 |  |
| FRE | 80 | 8.8 | 9.0 | 5..12 |  |
| GCS | 60 | 9.2 | 9.5 | 6..12 |  |
| GEE | 80 | 8.9 | 9.2 | 5..12 |  |
| GWS | 70 | 9.3 | 9.6 | 6..13 |  |
| HAW | 80 | 8.9 | 9.1 | 6..12 |  |
| MEL | 80 | 9.0 | 9.3 | 6..12 |  |
| NTH | 70 | 9.0 | 9.3 | 5..12 |  |
| PAD | 80 | 9.2 | 9.6 | 6..12 |  |
| RIC | 70 | 9.0 | 9.2 | 6..13 |  |
| STK | 80 | 8.8 | 9.1 | 6..12 |  |
| SYD | 70 | 9.0 | 9.3 | 5..12 |  |
| TAS | 72 | 9.0 | 9.4 | 5..12 |  |
| WBD | 80 | 8.8 | 9.0 | 5..11 |  |
| WCE | 80 | 9.2 | 9.3 | 6..13 |  |

## Flags

Off-seasons whose mean of players leaving is outside 8 to 12: 2027 (5.6), 2029 (8.0).

Clubs with the largest share of club-years outside the range: GWS (44%), ESS (43%), RIC (41%).

No AI club's mean of players leaving is outside 8 to 12.

Seeds that ran: 301, 302, 303, 304, 305, 306, 307, 308.

## Not exercised

- A coach who works the list: your club is on autopilot like the others and is excluded, so trades you start, offers you accept and players you re-sign or let go are not in these numbers.
- Only the off-season list moves: the rookie and pre-season drafts, the mid-season draft, Category B rookies and in-season signings do not exist in the game, so the real figures above include moves the game does not model.
- The real yardstick is a range from the brief and rough page counts, not a season-by-season table for every club; one real club's year (a rebuild, a premiership list) can sit well outside it.
- Careers of 10 seasons from the real 2026 lists: how churn changes over 20 or more seasons is not measured here (see `long_career_impl`).
- Nothing here says what the right amount is for the game: that is the director's call.
