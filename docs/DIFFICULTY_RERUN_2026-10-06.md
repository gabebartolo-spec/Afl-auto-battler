# Difficulty evidence rerun after #228 (2026-10-06)

This reruns #217's autopilot headline (`docs/DIFFICULTY_EVIDENCE_2026-10-05.md`)
on `main` at `3bafc22`, after #228 (card defaults: an unanswered card now gives
nothing; early extensions OVR 80+ and one a season; rival morale; trade value)
and everything else merged since. It uses the same seven careers:
`career_impl <policy> 1 <club> 5`, run on GitHub via `audit.yml`.

**Caveat:** `career_impl`'s draft is the League Draft (`Draft` with clubs
runs `_init_league_draft`). `greedy` and `light` pick off #222's scouted board;
only `ai` sees exact ratings (your club gets no evaluation error). Year one
still shows rank 1 because `career_impl` ranks by best-22 mean OVR, which a
scouted drafter keeps high even when its `Squad.strength` rank is around 8
(`DRAFT_EDGE_EVIDENCE_2026-10-06.md`). #228's `dynasty.gd` ranks by
`Squad.strength` and is the better harness for the managed-list comparison.

## List strength rank at each season start (of 18–20), then and now

| career | #217 (2026-10-05) | now | finishes then | finishes now |
|---|---|---|---|---|
| ai, MEL | 1, 2, 10, 16, 20 | 1, 4, 14, 18, 20 | 4, 4, 13, 8, 5 | 13, 16, 13, 19, 15 |
| ai, COL | 1, 9, 12, 14, 18 | 1, 8, 15, 18, 20 | 9, 14, 10, 12, 10 | 5, 8, 18, 14, 18 |
| ai, GEE | 1, 2, 6, 5, 7 | 2, 7, 9, 13, 17 | 11, 6, 6, 5, 4 | **1**, 5, 10, 6, 6 |
| greedy, MEL | 1, 13, 16, 19, 20 | 1, 8, 18, 19, 19 | 8, 16, 12, 11, 17 | 17, 18, 16, 20, 20 |
| greedy, COL | 1, 13, 18, 19, 20 | 1, 12, 18, 17, 20 | 5, 12, 8, 11, 14 | **2**, 15, 16, 20, 19 |
| light, MEL | 1, 11, 17, 19, 20 | 1, 13, 17, 18, 19 | **1**, 10, 10, 15, 16 | 7, 12, 13, 14, 12 |
| light, COL | 1, 12, 18, 19, 20 | 1, 12, 18, 19, 20 | 2, 14, 15, 8, 7 | 7, 17, 18, 19, 19 |

Finishes are ladder positions. In the "now" column, bold marks the season's
premiers (Geelong finished 1st and won; Collingwood finished 2nd and won). In
the "then" column, light MEL's bold 1 was a minor premiership (top of the
ladder) without the flag. Now: two premierships in 35 seasons, both in year
one. Then: none, plus that one minor premiership.

## Headline

- **Neglect is punished harder than before.** Unmanaged lists still slide to
  rank 17–20 by year five, and the ai policy now does so too: Geelong, which
  #217 had holding around 5–7, now reaches 17. Finishes in years 3–5 are worse
  for every career but light MEL.
- **The off-season remains where an unmanaged list falls away:** −3.6 a year
  for you on average (−1.2 to −5.7) against −2.2 for the AI. #217 had −2.0 to
  −5.0 against −1.3 to −2.4.
- **Early-extension cards fell from about 1.7 a season to 0.5** (17 in 35
  seasons), as #228 intended (OVR 80+, one a season). Accepting them ("light")
  still doesn't slow the decline.
- **In-season development is still at parity:** yours +1.6 to +2.9 a season
  against an AI mean of +1.6 to +2.6.
- **Margins** (8,281 career matches, all clubs): 100+ in 0.75% (62), 120–149
  in 10, 150+ in 2 (the biggest 158). #217 had 100+ at about 0.5% and none
  150+. Career play, with lists that drift apart over five years and expansion
  clubs, produces more mismatches than a single drafted season (0.55% 100+ in
  the extreme-margin audit).

The director's earlier call ("the unmanaged collapse is about right, so leave
it and make active play less dominant instead") still describes the shape. The
collapse is now slightly steeper, and the year-one edge from the career draft
is unchanged. Two caveats: ranks here are best-22 OVR ranks (see above), and the card change means autopilot now
forgoes the free development weeks it used to get from unanswered cards.
