# Match shape audit: turnovers, contests and how chains start (2026-10-10)

Director's question (2026-10-10): "Investigate more turnovers." Teams take about 53 intercepts a
game against a real 63. This audit measures where the gap comes from, and proposes changes for
the director to decide on. **Nothing here changes the game.**

Evidence: `intercept_impl` (two drafted leagues, 414 matches, no loose men), run 38022347344 on
claude/match-shape-audit (#606's constants plus an audit-only print of every team stat). The chain
counter (`MatchSim.audit_chains`, #606) counts every chain start by how it began, how the chain
before it ended, and whether the ball changed sides. Real figures: Champion Data via Wheelo Ratings,
`docs/research/wheelo/afl_player_stats_2025.json`, per team a game over 432 team-games.

## 1. The match against real AFL (per team a game)

| | sim | real 2025 | |
|---|---|---|---|
| disposals | 373.8 | 354.8 | close |
| inside 50s | 52.3 | 51.7 | close |
| goals / behinds | 12.9 / 9.6 | 12.3 / 8.8 | close |
| tackles | 57.8 | 60.2 | close |
| clearances | 37.9 | 37.6 | close |
| hitouts | 37.8 | 39.3 | close |
| frees for | 17.4 | 19.4 | close |
| kick-ins | 9.4 | 10.6 | close |
| marks | 97.4 | 88.5 | +10% |
| **contested possessions** | **88.2** | **130.5** | **-32%** |
| **uncontested possessions** | **289.3** | **216.1** | **+34%** |
| **spoils** | **17.5** | **30.6** | **-43%** |
| **intercepts** | **53.0** | **63.5** | **-17%** |
| **intercept marks** | **9.7** | **15.0** | **-35%** |
| clangers | 53.5 | 57.2 | -6% |

The totals the game was calibrated on (disposals, inside 50s, scores, tackles, clearances) are
right. What's off is the *kind* of football: too clean, with too few contests and turnovers and
too much uncontested ball.

## 2. Where intercepts come from

Every general-play change of possession is already credited (#606 tested a credit-only rule for the
one uncredited case; it added nothing). Per team a game: 28.1 turnover chains played on, 20.2
turnovers followed by a ball-up, 0.8 before a centre bounce, 0.4 loose balls won. The rest of the
changes of possession are frees, kick-ins, ball-ups and centre bounces, which Champion Data doesn't
count as intercepts. **So more intercepts needs more real turnovers, not more credit.**

## 3. A defect found: a won ball is thrown up again 42% of the time

`MatchSim._play_one_chain` draws `stoppage_share` (0.42, Ratings.T) for every chain except a kick-in,
whatever the chain before it ended with. So after an intercept or a free kick, 42% of the time the
next chain is a ball-up instead of the winner playing on:

| what happened | per team a game | then |
|---|---|---|
| an intercept, then a ball-up | 20.2 | the side that **lost** it wins it straight back 10.1 times |
| a free kick, then a ball-up | 7.2 | the side that **gave away** the free wins it back 3.6 times |

In real football the interceptor plays on or takes his kick, and the free is taken. Consequences:
- about 10 intercepts a team a game are undone at once by a ball-up that shouldn't exist;
- stoppage-led scoring is inflated and turnover scoring deflated. Points by source today: stoppages
  and centre bounces 43.8 of 87.2 (50%), turnovers and general play 26.2 (30%). ROADMAP M2-008
  recorded real AFL at about 40% from turnovers and named this cause ("how the engine starts chains");
- a free kick sometimes changes nothing.

Also seen: after a tackle the feed calls "ball up" (`outcome: stoppage`), the next chain is a ball-up
only when the same 42% roll says so; otherwise play resumes as general play with no ball-up.

## 4. Proposal (for the director)

**Step 1: a won ball is played on (recommended first).** After an intercept or a free kick the next
chain starts with the side that won it, never a random ball-up. Stoppages come from where they
really do: a tackle the feed calls a ball-up is one, and the remaining stoppage rate is raised so the
total stays near today's (about 98 stoppage contests a game, matching real ruck contests). Expected
effect: turnover scoring rises toward the real ~40%, counter-attack football from an intercept
becomes real, and free kicks always count. Intercept totals hardly move (they are credited either
way). Proof: the calibration suite, the score totals held, the score-source split, and the loose
man's tiers re-run, since it changes outcomes.

**Step 2: more contest (larger, after Step 1).** Recalibrate toward real contested possessions (88 to
130), spoils (17 to 31), intercept marks (10 to 15) and turnovers (53 to 63), holding disposals,
inside 50s, scores and marks at real. Several Ratings constants move together (with
`tools/sim_harness.py`, which mirrors them); every calibration check and the loose man's tiers are
re-proven. It changes how every match feels: more contested, scrappier play.

Not proposed: chasing the intercept number alone. It follows from Steps 1-2 if the turnovers are real.
