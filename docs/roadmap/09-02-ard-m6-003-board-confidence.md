## ARD-M6-003 — Board Confidence
**Status:** `PARTIAL` — the core confidence system is merged in #84; the explicitly listed smaller follow-up inputs remain optional/open.  
**Merged:** PR #84 as `48a805d`; confidence now moves relative to expectations, surfaces qualitative states, and explains why it changed.  
**Priority:** `P1`  
**Autonomy:** `BALANCE-GATED`

### Implementation record (2026-09-28, branch `claude/board-confidence`)
- **Relative to expectations:** each result moves the board by what the season's goal asks (`ClubLife.GOAL_STEPS`, [win, loss]).
  - Top four: +2 / −3.
  - Finals: +2 / −2.
  - Top 12: +2 / −2.
  - Win seven games: +3 / −1.
  - Plus one for a 40-point margin either way. After three losses in a row each further loss costs one more.
  - This replaced ±3 (±4 for a thrashing) whoever you were.
  - The season verdict (+20 met, −25 missed, +30 a flag) and the warning and sacking rules are unchanged.
- **States, not a percentage:** Very secure (80+), Secure (62+), Stable (45+), Under pressure (30+), In trouble. They show on the Coaching hub and the season review. The Hub's at-risk line reads "Board: Under pressure · goal". The number stays behind the scenes.
- **Why it moved:** after every match, a sentence, e.g.
  - "The loss to Carlton puts a top-four finish under threat."
  - "Four losses in a row: the board is getting restless about a finals spot."
  - The promise card and the season verdict set their own sentences.
- **Balance (54 club-seasons, every club as yours, same results, old v new):**
  - average move a match 3.3 v 2.4;
  - confidence at the end of the home-and-away season 58.9 v 60.4;
  - after the verdict 62.4 v 64.0;
  - clubs that missed their goal and ended in trouble 14 v 16 of 18.
  - Sacking (a second missed goal after a warning) is unchanged.
- **Not in this change:** smaller inputs (finals runs, player development, cap health, trend). Those come once play shows the base model is right.
- **Tests:** `test_club.gd::_test_board_confidence` covers:
  - steps against the goal;
  - no ordinary result moving more than three;
  - the losing run;
  - draws, the five states and the reason sentences;
  - a reason after a real round.

Persistent qualitative hierarchy satisfaction.

Player-facing states may be:
- Very Secure,
- Secure,
- Stable,
- Under Pressure,
- In Trouble.

Primary input: results relative to expectations.

Smaller inputs may include:
- finals performance,
- long losing streaks,
- player development,
- salary-cap health,
- trajectory/trend.

Rules:
- slow movement,
- explain why it moved,
- no opaque random swings,
- sacking/job-security consequences come later after balance proves the confidence model.
- **Player coach career after sacking:** being sacked does not immediately end the save. The player can continue their coaching career at another club if hired.
- The player gets **one second chance** after their first sacking. A subsequent sacking normally ends the coaching career.
- **Premiership reprieve:** winning a premiership earns/restores one additional sacking reprieve ("get out of jail" chance), allowing another continuation after a future sacking.
- Make remaining reprieve status and the consequence of the next sacking clear to the player; do not hide career-ending risk behind an opaque board score.

### Phone-playtest follow-up — expectation fairness is part of the lose-state contract
Board goals are **not randomly assigned** in the current implementation. At the start of each season, `GameState._open_board_season()` ranks every club by `Squad.strength()` and passes that rank into `ClubLife.board_goal()`:
- strength rank 1–4 → **Finish top four**;
- next finals-band clubs → **Make finals**;
- ranks 11–14 → **Finish top 12**;
- bottom group → **Win at least seven games**.

That is deterministic, but it still needs a fairness audit. A single pre-season squad-strength ranking can be wrong or too brittle, particularly for a rebuilding/young list, a newly redrafted club, a side carrying major injuries, or a roster whose OVR/role model does not translate cleanly to wins. The bucket boundaries are also abrupt: moving one underlying strength rank can materially change the season-long demand.

This matters more than ordinary flavour because **being sacked is currently the game's explicit hard career-ending lose state**: the Hub stops the career and tells the player to start a new one. Therefore the game must never kill a long save because an opaque or miscalibrated expectation was assigned.

Audit expectations against:
- pre-season list strength **and how well that metric predicts realised wins/ladder position**;
- previous-season finish and multi-year trajectory once history exists;
- age profile / rebuilding vs building vs contending phase;
- major known injuries/unavailability at the point the goal is set;
- recent list turnover and whether the club has deliberately moved into a rebuild;
- finals structure/wildcard context;
- uncertainty: boards should use a realistic **range/band of expectation**, not pretend the model knows the exact ladder order.

First-season/redraft careers need special scrutiny because there is no prior club trajectory: do not make “model ranks this list fourth” automatically equivalent to a punitive top-four mandate unless calibration proves that is fair.

The board may still be demanding. The goal is **earned pressure, not arbitrary safety**.

Acceptance:
- identical roster/context always yields the same explainable expectation; no hidden random assignment;
- pre-season expectation bands are calibrated against large simulated samples so “top four”, “finals”, etc. correspond to credible outcome distributions rather than one-point rank boundaries;
- rebuilding clubs are not routinely given top-four/finals-or-bust goals simply because of noisy raw list strength;
- genuine contenders can still receive demanding goals;
- the player can see a concise reason for the goal (e.g. list quality, last season, trajectory) without number vomit;
- two otherwise similar clubs do not receive radically different goals without an explainable difference;
- sacking remains a meaningful lose state only if the expectations feeding it are demonstrably fair and the warning path gives the player a real chance to recover;
- long-save probes verify the human is not disproportionately sacked due to expectation-model error.

---

