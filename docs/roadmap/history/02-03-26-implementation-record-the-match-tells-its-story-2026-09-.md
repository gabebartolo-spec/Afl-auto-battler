### Implementation record — the match tells its story (2026-09-29, branch `claude/match-story`)
Design audit §4.3: the feed showed only scores, injuries happened after the siren off screen, and full time listed team facts but not the moments the match turned on.
- **Injuries happen in the match (`MatchSim._plan_injuries`, `_check_injuries`):**
  - Each player's roll is the same one as before (`Injuries.roll`, same chance and severity), drawn from the match's own injury dice so play is otherwise unchanged. It comes with a minute of the match.
  - At that minute he goes off for good and the best bench player for his spot comes on. A matched key defender's forward goes to the next defender.
  - `Injuries.apply_match` records the match's injuries on the lists. A result without that record falls back to the old roll.
  - Measured over 200 matches: 0.71 injuries a side a match, the same rate as before.
- **Feed (`MatchNotes.story_feed_line`):**
  - A player going off hurt, and who replaces him (always shown).
  - A goal from an intercept that takes or levels the lead ("From Moore's intercept.").
  - A missed set shot in a close last quarter.
  - At most one intercept and one miss line a quarter; about 2 lines a match in all, most of them injuries.
- **Full time, "How it went" (`MatchNotes.turning_points`):** leads with the score that put the winners in front for good (when they had been behind or level after quarter time), a star who went off hurt before the last quarter, and your missed set shot late in a close loss. Team facts fill the rest, three sentences at most. Quiet games stay quiet: nothing is invented.
- **Left out on purpose:** a player's third clearance in a quarter (clearances are not logged as events); momentum (a separate audit item, §4.7).
- **Tests:** `test_match_game.gd` (`_test_in_match_injuries`, `_test_match_story`). Calibration, league balance, balance, injuries, save, matchday and match visual suites pass.

