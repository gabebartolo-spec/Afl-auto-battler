# M6 — Coaching, Board & List Management

Goal: strengthen the management loop around the football.

## ARD-M6-001 — Coaching hub
**Status:** `DONE`  
**Merged:** PR #81 as `6a9abc73`; verified on main 2026-09-28.  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

### Implementation record (2026-09-28, branch `claude/coaching-hub`)
- **Navigation:** the hub's bottom row is Training · My list · Coaching · Sim round (after the season: Season review · Training · Coaching · Main menu). An open staff job shows on the tab ("Coaching · 1"). The hub's quiet Staff link is gone; its board line shows only when your job is at risk (a final warning or confidence under the warning line).
- **Coaching screen** (`CoachingScene.gd`, one scrolling page):
  - **How we play:** the club's standing game plan (the six quarter-break plans), with its plain-English summary. Every match of yours starts on it, played live or simmed, and the break calls change it from there (`GameState.club_plan`, `Season.plans`, set on the pending match).
  - **How we win / how we get beaten:** up to three lines each from the season's team numbers against the average club, biggest difference first. There's nothing until three games in, and a line needs a 7% gap and at least one a game. The words come first, then the number, e.g. "We get beaten at the stoppages: 5 fewer clearances a game than the average side."
  - **Form:** up to three players in form and three out of form. A player's Player Rating over his last three games is set against his own season average. He must have five games, and the gap must be at least 15. Tap a player for his profile.
  - **List and cap:** list size, payroll and cap room in one line, plus My list.
  - **The board:** confidence, their goal, any final warning.
  - **Staff:** one line per job, which opens the coach's profile (a vacant job opens Staff). The Staff screen is one button away for appointments and other clubs.
- **Saved:** `club_plan`, `form_log` (last three ratings plus the season sum), `season_team` (season team totals for every club). Form and team totals reset each season.
- **Score sources (M2-008):** the season also keeps points scored and conceded from turnovers and from stoppages (centre bounces included), so the lines can say "They hurt us on the turnover: 6 more points a game conceded from it than the average side." The Phase 5 effects copy (what teaching, tactics and man-management do) stays on each coach's profile, one tap from every staff line, rather than repeated on the hub.
- **Tests:** `test_club.gd::_test_coaching_hub` checks that:
  - the plan is valid, yours only, and reaches a simmed match;
  - style lines only appear after three games, with at most three each;
  - form reads last three against the season, with a five-game minimum;
  - everything survives a save.
- **UI test:** `run_career_ui_tests.gd` covers the Coaching tab, the board and staff on it, choosing a plan, and Back. The matchup suite confirms the four-button footer fits a phone.

Bottom navigation target:
`Training · My list · Coaching · Sim round`

Coaching should become the home for:
- staff,
- gameplan templates,
- "How we play",
- **List profile** — a compact league-relative read of what the list is actually good and bad at,
- how we win / how we get beaten,
- in-form players,
- out-of-form players,
- salary-cap information,
- Board Confidence.

Plain-English coaching insight first; supporting numbers second.

Before implementing more, inspect current merged Staff/coaching work and extend it rather than duplicating screens.

---

