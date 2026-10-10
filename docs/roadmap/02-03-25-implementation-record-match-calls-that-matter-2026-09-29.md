### Implementation record — match calls that matter (2026-09-29, branch `claude/match-calls`)
- **Playtest finding:** the director lost four straight matches by 40+ and found game-plan choice "meaningless button clicking". Measured on a Demons list without Gawn v Collingwood (80 matches a plan):
  - AI clubs countered your last plan at every break, and it was never wrong. With that switched on, no plan beat Balanced, and a press or contest plan cost 4-5 points of margin.
  - Plans ignored the list: only Through stars cared who played.
- **Changes:**
  - `PlanFit`: each plan leans on the players who carry it (a press on pressure players, corridor footy on runners, the contest on ball-winners and a ruck, controlled tempo on good kicks and marks). Its upside scales with how they compare with the league; its costs do not, so a plan the list does not suit is a real risk.
  - AI clubs play the plan their own list suits as their usual game, shown on selection ("Their usual game: Defensive press"), and adjust only to the scoreboard. The automatic counter of your last plan is gone.
  - The plan chooser (selection, Coaching, quarter breaks) names who in your side makes the plan work and how they compare: "Your pressure players are among the best: ...". No verdict, no suggested plan.
  - Tags follow football: only their midfielders can be tagged, the note names the midfielder who goes to him (your tagger, or the one with the most pressure), and the AI tags only your midfielders.
- **Measured after (same set-up):** Balanced 66%, +12; Defensive press 95%, +35; Win contest without a ruck 62%, +9. Before, those were 65%/+11, 56%/+8 and 59%/+7. League balance, calibration and balance suites pass.
- **Also from the playtest (separate PR, `claude/honest-feedback`):** a hit-out scores 1 in the Player Rating (it was 3), and Needs a lift follows the Player Rating shown on screen.

