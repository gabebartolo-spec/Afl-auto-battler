### Implementation record — traits and synergies you can feel (2026-09-29, branch `claude/traits`)
Design audit §4.5: synergies worked in code but most were too small to feel, and a trait never said when it was at work.
- **Measured first:** each synergy was forced on and off over paired seeded matches (800 per synergy, noise about ±2 points).
  - Before: Engine room +7 points a match, Lockdown unit +5.6, Tall-small forward line +4.2, Intercept wall +3.4, Supply line +2.6, Running machine +0.7.
  - The four weakest were raised toward the audit's "about a goal a match":
    - Tall-small: +8% goal chance on forward-50 shots (was +5%).
    - Intercept wall: -9% on the opposition's (was -5%).
    - Supply line: +12% metres gained (was +6%).
    - Running machine: tires 30% slower (was 15%).
  - After: Intercept wall +6.4, Tall-small +5.7, Supply line +4.3, Running machine +4.2.
  - No club carries more than three, so there is no stacking cap; the league balance, calibration and balance suites pass.
- **Crumbers at the fall of the ball:** a Crumber is twice as likely to be the one who gathers a spill. Midfielders' weight at a forward-50 spill drops from 0.25 to 0.15, so crumbed goals are mostly forwards' (62%, was 55%, measured over 400 matches).
- **Surfaced (from the log, no numbers):**
  - A Crumber's goal off the pack reads "Crumbing goal" on its feed row.
  - A Big-game player's goal in the last quarter or a final: "X lifts when it matters." (once a match per side).
  - Full time, "Your synergies": the stat each of your active synergies plays on, yours against theirs ("Engine room: clearances 40 to 33.").
- **Not done:** synergies tied to game plans (PlanFit), and trade-off costs on synergies (the audit's risk mitigation). Both wait for play to show a dominant build.
- **Tests:** `test_match_game.gd::_test_traits_surfaced`; the crumb test now has margin.

