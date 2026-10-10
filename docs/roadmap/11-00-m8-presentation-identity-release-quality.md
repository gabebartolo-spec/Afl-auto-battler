# M8 — Presentation, Identity & Release Quality

Goal: make the game coherent, readable and robust enough to ship/play for very long careers.

## ARD-M8-001 — Club colour markers
**Status:** `DONE`  
**Merged:** PR #57 as `f549755`; verified on main 2026-09-28 (full suite green).  
**Priority:** `P1`  
**Autonomy:** `SAFE`
**Outcome (2026-09-28, PR #57):** `UiKit.club_marker(code)` draws the club's real colours as vertical bands: two for most clubs, three where the third is a genuine club colour (`GameDB.THREE_COLOUR_CLUBS`: Adelaide, Brisbane, Gold Coast, GWS, Port, St Kilda, Bulldogs, Tasmania, Canberra). A faint edge keeps navy and black readable. `club_badge` uses it, so the ladder, hub, results, draft, season review and match change together; no logos. Regression: `tests/test_matchday.gd::_test_club_markers`.

Replace tiny single-colour squares with compact multi-colour markers.

Examples:
- Melbourne: navy + red,
- Western Bulldogs: blue + red + white,
- Adelaide: navy + red + yellow.

Use simple bands/segments/stripes, not imported logos.

Reuse one component/helper across ladder, fixtures, matchups and reports.

---

## ARD-M8-002 — Visual identity: remove generic green
**Status:** `DONE`  
**Priority:** `P1`  
**Autonomy:** `SAFE` if theme-level
**Merged:** PR #58 as `6ff1ae0`; verified on main 2026-09-28 (full suite green).  
**Outcome (2026-09-28, PR #58):** a small pass, not a redesign; red (`ACCENT`) was already the only action colour. Green used as decoration now goes neutral. Training selection uses the shared outline. Your draft picks get a neutral surface. The Premiers line, "Week off" and "Your best" are plain text. The quarter-by-quarter winner is bold. Season-review club lines are bold. Real states keep green (won, needs met, a rise, form, cap room, re-signed). Regression: `test_matchday.gd::_test_no_green_decoration` (no UI script paints a green highlight surface). The broader palette direction above stays as guidance for future screens.

Direction:
- charcoal / near-black base,
- warm off-white text,
- rusty football red/orange main accent,
- warm grey / stone / cream secondary,
- club colours for variation.

Green only for semantic success/positive state where useful.

Avoid:
- emerald/teal/cyan generic AI-game accents,
- purple-blue gradients,
- glows,
- excessive rounded cards,
- arbitrary decorative coding.

Target feel:
**Australian sporting editorial / old footy record / modern newspaper.**

Prefer shared theme changes over manually touching hundreds of controls.

---

