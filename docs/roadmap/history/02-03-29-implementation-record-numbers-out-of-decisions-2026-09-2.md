### Implementation record — numbers out of decisions (2026-09-29, branch `claude/no-numbers`)
Design audit §4.9: set-shot odds, a kicker's attribute numbers, a tired star's legs percentage and a trade offer's percentage sat on decision cards.
- **Set shot:** each option reads in words.
  - The shot: "He should kick it" / "Better than even" / "A coin toss" / "A tough shot" / "A long shot".
  - Play on: "The pass usually sticks, then he shoots from closer: a coin toss."
  - The bomb: "Now and then it falls for a goal; more often a behind or they rebound it."
  - The kicker: "Your call. X is a reliable kick, and he is tiring."
  - The odds underneath are unchanged.
- **Tired star:** "Your star's legs are gone." (no percentage).
- **Trade refusal:** "your offer is a little short / well short of what they give up".
- **Rotation text:** "Your stars stay on until they are cooked." (was "80+ players").
- **Kept, deliberately:** the expected-points readout in the full-time Stats tab (a drill-down), and training costs (a price you pay is a fact you decide on).
- **Tests:** the set-shot test now requires words and no odds.

### Implementation record — momentum is real (2026-09-29, branch `claude/momentum`)
The match screen's momentum meter was display-only: the screen computed its own number from the events it showed, and the engine had no momentum. That is an incomplete feature, fixed here.
- **Engine (`MatchSim.momentum`, -1 away .. 1 home):**
  - A goal swings it 0.40 toward the scorers, a behind 0.10. The swing shrinks near the cap and grows when it turns the other side's run.
  - It keeps 93% each chain (halves in about nine chains, five or six minutes) and halves at a break. Capped at ±1.
  - Its only effect: the side it favours wins up to 4% more of the ball at stoppages and loose balls (`contest_winner`). The home-ground edge is 3%.
- **Meter:** every event carries the engine's value (`"mom"`), and the meter shows exactly that.
- **Measured over 600 matches:**

  | | Without momentum | With momentum |
  |---|---|---|
  | Scorers kick the next goal | 51.1% | 51.8% |
  | Same, after three in a row | 53.6% | 53.6% |
  | Goals a match | 25.1 | 25.4 |
  | Margin spread (SD) | 35.9 | 36.7 |

  Momentum averages 0.25 and spends 3% of a match above 0.6. The first setting tried (a faster fade, 88% a chain) barely moved and was not visible on the meter.
- **Tests:** `test_match_game.gd::_test_momentum`:
  - full momentum wins about 4% more of the ball;
  - a run of goals is capped;
  - one goal the other way arrests a strong run, two turn it;
  - it fades within ten passages;
  - events carry it;
  - the scorers kick the next goal under 56% of the time.

  `test_match_visual.gd`: the meter shows the engine's value and nothing of its own.

