### Implementation record — the draft shows your side against the league (2026-09-29, branch `claude/draft-shape`)
Design audit §4.6: the league draft decides most of a first season, but while drafting the player saw only position counts. The director's first season began with an unfixable ruck hole.
- **Change:** from eight picks, the draft's My list shows "Your side so far, against the league". It gives one line each for midfield, ruck, attack and defence, in the words the selection screen uses ("Ruck: among the weakest."). It compares your picks with every club's picks so far, through the same engine line values (`Matchup.standing`).
- **Not done, deliberately:** no suggested player, no "draft a ruck", no projected ladder, no numbers. The need counts stay. The intake draft is left alone, since rookies rarely change a side.
- **Tests:** `run_draft_ui_tests.gd::_test_side_shape`: none before eight picks; four lines in words after.

### Implementation record — "With us" and milestones (2026-09-29, branch `claude/with-us`)
Design audit §4.8 (and ARD-M7-003, lightly): the game had each player's full career, awards and flags, but never said what he had done for *your* club.
- **Profile:** "With us since 2027: 87 games, 42 goals. Best and fairest 2029. Premiership 2030." (`GameState.with_us_text`). It counts every spell at your club, this season included. Best and fairests come from the honour roll; flags are the premierships won while he was on the list. It is shown for your own players only.
- **Milestones:** 50, 100, 150 and so on, in career games (the AFL convention). "Jack Viney plays his 100th game." is marked on the hub and selection in the week he reaches it, in ordinary text (injury notes stay red). Nothing on other weeks, and nothing for a career not on record in full.
- **Not done:** best games from Player Ratings (no per-match history is kept), and a club best-and-fairest moment. Both need new data.
- **Tests:** `test_selection.gd::_test_with_us_and_milestones`.

