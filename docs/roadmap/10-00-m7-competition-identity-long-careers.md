# M7 — Competition Identity & Long Careers

Goal: make decades of play feel like a living AFL world rather than repeated isolated seasons.

## ARD-M7-001 — Rivalries
**Status:** `DONE` — established and dynamic rivalry system merged in PR #180.  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

This was an existing user-requested roadmap feature and must not be re-added as a "new idea".

Support:
- established club rivalries,
- dynamic/emergent rivalries where justified by repeated finals, close games, player movement, etc.

Use mainly for:
- atmosphere,
- scheduling/context,
- history,
- presentation.

Avoid arbitrary large stat buffs.

---

## ARD-M7-002 — Marquee games
**Status:** `DONE` — recurring marquee-game identity merged in PR #181.  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

Existing requested feature.

Represent appropriate competition traditions such as King's Birthday and other marquee fixtures.

Presentation/identity first. Avoid arbitrary gameplay bonuses.

### Director addition — Gather Round
**Status:** `TODO` — follow-up under this existing marquee-fixture owner; the completed general marquee-game implementation remains DONE.

Add **Gather Round** to the season calendar, fixture identity and match presentation. Represent the round as a shared league event staged at appropriate host venues, rather than simply adding a label to normal home-ground fixtures.

Implementation scope:
- Inspect the current fixture/event system and source the appropriate round and host venues for supported real starting seasons. Reference: [official AFL Gather Round](https://www.afl.com.au/gather-round) and [AFL host agreement update](https://www.afl.com.au/news/1513707/south-australia-locks-in-gather-round-for-a-further-three-years). South Australia is the current reference; do not hard-code one year's round number, dates or nine-match total into every future season.
- Assign actual event venues consistently across fixtures, match prep, live matches and relevant vignettes; distinguish nominal home/away designation from the venue actually used. Audit existing home-ground/familiarity handling rather than accidentally giving a relocated team a normal home-venue advantage.
- Give the round a clear, restrained Gather Round identity in the calendar/Hub, match intro and reports, with host-ground atmosphere through existing art/venue systems. No arbitrary event stat buffs.
- Preserve valid season totals, opponent scheduling, byes and finals progression. Define a coherent policy for generated future seasons and expansion/odd club counts, including Tasmania, optional Canberra and custom clubs; do not force every club to play simultaneously when the league has an odd number of teams.
- Persist the event/venue identity through save/reload and use backward-compatible defaults for existing careers.

Acceptance: Gather Round is recognisable and correctly hosted; the user's match and the rest of the league agree on the event round/venues; ordinary fixtures remain intact; no duplicated/missing games or false season-end on a bye. Validate normal and expanded leagues, host/non-host clubs and reloads. Keep any venue/home-advantage simulation change under the existing balance gate (ARD-M7-007).

---

