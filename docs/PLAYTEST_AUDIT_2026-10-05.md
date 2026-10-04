# Playtest audits — 2026-10-05

Two VERIFY findings from the 2026-10-04 multi-season phone playtest (roadmap §9.1), measured on `main` at `abbfe94`. Finding 1 was a real defect and is fixed in this PR; finding 2 needs no change. Reproduce with:

```
godot --headless --path . --script tools/audit/run_audit.gd -- provenance_impl
godot --headless --path . --script tools/audit/run_audit.gd -- fatigue_impl
```

---

## 1. Generated-player provenance / age sanity

**Finding:** a fictional Joshua Robinson appeared aged 28 with 89 POT only 2–3 seasons into a save.

### Every path that creates a fictional player

There are exactly two (`Prospects.gd`; nothing else sets `generated`):

| Path | Who | Ages |
|---|---|---|
| `generate_class` | each year's National Draft class | 17–19 (over-agers to ~21) |
| `generate_expansion_list` | Tasmania (2028) and Canberra (2030) first-season lists, 36 each | 45% 18–21, 35% 22–26, **20% 27–30** |

AI list filling, free agency and trades only move existing players.

### Measurement (POT headroom = POT − OVR)

| Pool | Age | n | mean OVR | mean POT | mean headroom | POT 85+ |
|---|---|---|---|---|---|---|
| Real 2026 AFL players | 18–21 | 146 | 54.1 | 71.6 | 17.5 | 6 |
| | 22–26 | 260 | 60.6 | 68.4 | 7.9 | 34 |
| | 27–30 | 263 | 64.1 | 70.7 | **6.6** | 33 |
| Tasmania 2028 expansion | 18–21 | 15 | 63.0 | 79.0 | 16.0 | 3 |
| | 22–26 | 16 | 64.3 | 81.8 | 17.5 | 5 |
| | 27–30 | 5 | 66.2 | 85.8 | **19.6** | 3 |
| Canberra 2030 expansion | 18–21 | 16 | 62.7 | 80.4 | 17.8 | 3 |
| | 22–26 | 10 | 65.4 | 85.2 | 19.8 | 6 |
| | 27–30 | 10 | 63.2 | 80.4 | **17.2** | 2 |
| Generated draft classes 2027–29 | 18–21 | 146 | 60.5 | 76.0 | 15.5 | 22 |

Typical individual cases (Tasmania 2028 / Canberra 2030): age 29, OVR 69, **POT 91**; age 28, OVR 71, POT 91; age 27, OVR 71, POT 92, each with no senior history.

### Cause

`generate_expansion_list` treats every expansion player as a fresh draftee:

- `draft_year = year` and `draft_rank = 1..36` (list order), with junior under-18 stats and no prior career;
- `project()` rates him like a top-36 draft pick by rank, with no age term beyond +1 for over-agers;
- `Potential._draftee_potential` sets headroom from rank alone: `22 − 0.25 × (rank − 1)`, so about 13–22 points regardless of age.

A 29-year-old therefore gets the ceiling of an 18-year-old pick. Draft classes are fine: the ages there are genuinely junior.

Joshua Robinson's exact origin can't be pinned from here, because fictional names are assigned per career. But Tasmania enters in 2028, the second season of a 2027 career, and this is the only path that makes a high-POT player that old.

### Fix (made in this PR)

`Potential._draftee_potential` now gives a projected player older than 21 (`MAX_PROSPECT_AGE`) the ceiling any player his age gets (`_headroom(age)`, the formula real players use) instead of a draft-rank ceiling. Draft classes are 18–19, so they never reach this path.

| Pool | Age | Headroom before | Headroom after |
|---|---|---|---|
| Tasmania 2028 | 22–26 | 17.5 | 4.5 |
| | 27–30 | 19.6 | 1.8 |
| Canberra 2030 | 22–26 | 19.8 | 6.3 |
| | 27–30 | 17.2 | 1.4 |
| Generated draft classes | 18–21 | 15.5 | 15.5 (unchanged) |

Example: the age-29, OVR 69 player who had POT 91 now has POT 70. Seasoned expansion players sit slightly below real veterans (6.6), because real ceilings also count a past best season, which a generated player doesn't have.

Not changed: **entry history.** Provenance fields (junior team, under-18 stats, draft year) only appear on draft screens, which expansion players never pass through, and a 28-year-old with no AFL games reads correctly as a mature-age state-league recruit. Expansion OVR is also unchanged (around the league baseline, as documented).

Existing careers keep the potentials already in their saves; new expansion clubs get the corrected ceilings.

This also bears on the §9.1 *Trade valuation / potential-by-age* item: the observed Rozee-for-Robinson trade was valued on an inflated POT.

---

## 2. Season fatigue parity

**Finding:** the user's squad appeared consistently more tired than the opposition.

### Rules: shared, with three user-only levers

The season load model (`Workload.advance_week`) and in-match fatigue (`MatchSim`) run the same code for every club, and both sides default to Normal rotations. Differences exist only where the user has a choice:

| Lever | User | AI clubs |
|---|---|---|
| High-performance budget → weekly recovery | 0.90–1.20× by funding level (Standard 1.00×) | 1.00× |
| Week-event training card | Heavy session (+6 load, start at 88 energy) or Recovery week (+8 recovery); **default when simmed: Recovery** | never offered |
| Selection | once set, the side is kept every week | re-picked weekly, freshness-weighted (`Workload.selection_factor`) |
| Rotation policy | Hard / Normal / Ride the stars | Normal |

There's no hidden AI fatigue protection.

### Measurement

A full home-and-away season, rounds 4–23. Load is the workload carried into each match by the players who actually played it.

| Club | Selection | Your mean load | AI mean load | Your mean energy cap | AI mean energy cap |
|---|---|---|---|---|---|
| COL | auto-pick | 6.0 | 10.0 | 97.6 | 96.0 |
| COL | side fixed at R1 | 8.4 | 9.9 | 96.7 | 96.0 |
| MEL | auto-pick | 4.4 | 10.7 | 98.2 | 95.7 |
| MEL | side fixed at R1 | 4.8 | 10.6 | 98.1 | 95.8 |

On default settings the user's side is **fresher** than the AI's, mostly from the default recovery weeks. Nobody, on either side, reached "Needs a break" (load 45) in any scenario.

### Conclusion

There's no parity defect, so no fix is recommended. Likely sources of the impression:

- Your squad's legs are visible (energy, "running on empty", Carrying a load) and the opposition's are not.
- Choosing Heavy sessions, Ride the stars, below-standard high-performance funding, or a fixed side all legitimately add load.

One design observation for the separate *Overall difficulty is too low* finding: across a whole season the workload system barely bites (energy caps stay at 96–98 for everyone), so neglecting rotation and freshness costs little.
