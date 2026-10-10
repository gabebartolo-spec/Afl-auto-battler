## ARD-M6-006 — League-relative List Profile
**Status:** `VERIFY` — implementation is merged; director/phone review remains.  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

Add a compact **List profile** section to the Coaching menu so the player can understand what kind of list they have built before choosing a game plan or deciding what to improve through training, trades or the draft.

Show five plain-English dimensions:
- **Contest**
- **Control**
- **Running power**
- **Pressure**
- **Aerial power**

### Core rule — league-relative or it is meaningless
Every label must be relative to the **current league**, not an absolute attribute threshold. As lists evolve over a long save, the comparison must evolve with them.

Use short qualitative labels such as **Elite / Strong / Average / Weak** (and an equivalent bottom-end label only if needed). Do not expose the underlying score by default.

### Player-facing purpose
The profile should answer: **“What is my list actually good at, and where is it weak?”**

It should help the player:
- make an informed game-plan choice without the game recommending the answer;
- identify weaknesses worth targeting in the trade period or draft;
- decide what kinds of players/attributes to develop through training;
- see a list identity emerge over time rather than simply chasing higher OVR.

### Guardrails
- No raw 0–100 team scores or number-vomit presentation.
- No radar chart unless a later UI test proves it is clearer than the words.
- Do **not** display “recommended plan” or otherwise solve the tactical choice for the player.
- Keep **Aerial power** distinct from **Control**: Control is retaining/using possession; Aerial power is winning the ball in the air.
- Derive each dimension from football-relevant player qualities already present in the simulation wherever possible; do not invent a parallel rating system.
- Before implementation, inspect `PlanFit.gd`, synergies and other existing team-strength calculations and reuse/extend them rather than creating contradictory definitions.
- The Coaching screen remains the primary home for this information.

### Built (2026-09-30)
- **Rules:** `scripts/sim/ListProfile.gd`.
  - Each strength ranks your match-day side, as you have picked it, against every club's side this week (`GameState.league_grounds`).
  - The words fall by share of the league: roughly the top 17% is Elite, then Strong to 44%, Average to 72%, and Weak below that. In an 18-club league that is 3 / 5 / 5 / 5.
  - A rank moves whenever any list in the league changes. No score is shown.
- **Definitions** (the engine's own, not a parallel system):
  - Contest, Running power and Pressure are `PlanFit.score` for Win contest, Attacking and Defensive.
  - Control is disposal (what beats a press in MatchSim) with discipline (what avoids clangers), across the side minus the ruck.
  - Aerial power is the side's six best marks.
- **Screen:** Coaching opens on "List profile", ahead of "How we play".
  - Five rows show a strength and a word.
  - Tapping a row says what that strength is and who leads it in your side.
  - No numbers, no radar, no recommended plan.
- **2027 league:** every word is used, and every club has a distinct mix. For example, Adelaide is elite everywhere except Running power, while Collingwood is Weak in Contest and Running power.
- **Tests:**
  - `test_roles` `_test_list_profile`:
    - the words spread across the league;
    - better ball-winners make Contest Elite;
    - the same list reads Weak in the air once every other club's marks improve;
    - Aerial power and Control move independently;
    - three strengths equal the plans' own scores.
  - `run_career_ui_tests`: five thumb-sized rows, no digits or advice, and a tap reveals the detail.

### Acceptance
- The five labels change meaningfully when the underlying list changes.
- The same raw list can move between labels as the league around it improves or declines.
- A player can use the profile to reason about tactics and recruiting priorities without being told which move is optimal.
- The display remains compact and readable on a narrow Android portrait screen.

---


