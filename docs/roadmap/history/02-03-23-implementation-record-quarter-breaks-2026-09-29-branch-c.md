### Implementation record — quarter breaks (2026-09-29, branch `claude/quarter-breaks`)
The director's playtest named quarter breaks as the most obtuse decision. The break now follows the gate's loop: the problem, what your last calls did, then the response.
- **What's happening:** the quarter's facts as before: stoppages, territory, the opposition player hurting you, wayward kicking, their plan, moments.
- **What your calls did (new, `MatchNotes.calls_lines`):** one line per call you made, with the stat that call is about, against the quarter before. Examples:
  - "Defensive press: they had 6 inside 50s and kicked 1 goal, from 11 and 4 in the first."
  - "Win contest: clearances 9 to 6, from 5 to 8 in the first."
  - "Tag on Walsh: 4 disposals, from 11 in the first."
  - "Through Bontempelli: …"
  - The problem and the call that answers it use the same words (stoppages and Win contest, a player hurting you and the tag). There is no verdict and no "best call".
- **Your calls:** the game plan and the tag stay in view. Play through, pep talk, rotations, legs and the synergy line sit behind one "More calls" tap.
- **Full time:** a "Your calls" section lists the same lines quarter by quarter (at most five) for a match you played live.
- **Tests:** `run_matchday_tests.gd` checks:
  - the break leads with what's happening;
  - what your calls did, with the tag, is shown;
  - plan and tag are in view and the rest one tap away;
  - More calls opens the rest.
- **Screens:** quarter time at 390 px reviewed.
- **Next in this gate:** decision inputs before the match (selection and the standing plan), and synergy clarity.

