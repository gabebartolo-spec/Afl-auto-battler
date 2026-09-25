# The live match view

`MatchSim` plays the whole match before the oval moves. Its event log is the
truth: who had the ball, how far up the ground (`fp`, metres, side 0 attacking
+x, goal lines at +-85) and what they did. The match view never changes that.
It decides how each event *looks*, never *whether* it happens.

| Layer | File | Job |
|---|---|---|
| Truth | `scripts/sim/MatchSim.gd` | the event log (unchanged by the view) |
| Interpretation | `scripts/ui/match/MatchDirector.gd` | turns each event into a beat: ball flights, who leads, who chases, stoppage and restart staging, team structure |
| Motion | `scripts/ui/match/MatchMotion.gd` | steering: acceleration and braking limits, arrive, reaction delay, oval bounds |
| Rendering | `scripts/ui/PitchView.gd` | draws the oval, players, ball (height + shadow), camera; releases events to the match screen |

## Rules the view keeps

- It never writes to an event or to `MatchSim`. PitchView keeps its own copy of
  the event list. Appended segments (interactive matches) go to that copy only.
- Every event is released through `event_played` exactly once, in log order,
  at the moment it visibly happens. For example: a mark when the ball is
  caught, a goal when it crosses the line, a tackle on contact.
- The ball's x on release is the logged `fp`. Across-the-ground position (y),
  flight time and height are presentation choices.
- Randomness comes from the director's own `RandomNumberGenerator`, seeded
  from home, away and label. The global stream and `MatchSim.rng` are never
  touched.
- `skip_to_end()` applies the rest at once without replaying the feed, then
  emits `finished` synchronously (as before).

## What the movement is based on

Frames from real footage were inspected:
- the 2021 Grand Final broadcast clips;
- an overhead drone of a full-ground intra-club match;
- club "ball movement" packages;
- the *AFL Explained* diagrams (zones, loose man, wings) and the *Understanding
  Footy* defensive-clearance breakdown.

What that showed, and what the view does about it:

- **Most of the ground holds shape.** At any moment 6 to 12 players work around
  the ball. The rest stand in their structure and drift with play. Each token
  has a slot in its side's attacking frame (full back to full forward). The
  slot shifts line by line with the ball (midfield most, defenders and
  forwards less) and compresses when defending.
- **Everyone has an opponent.** Paired slots (FB/FF, BPL/FPL, wing/wing and so
  on) put players in twos. When defending, a player stands goal-side of his
  opponent, and one half-back plays loose in the hole between ball and goal.
- **Around the ball**, the nearest two defenders press (one on the ball, one
  goal-side) and the nearest two attackers offer options. These roles are
  chosen once per beat, so they don't flick between neighbours.
- **Receivers lead and defenders trail.** The next three events are known, so
  their players start moving early. The receiver runs to where the ball will
  land and his opponent follows a step behind. A tackler closes from behind
  before the tackle.
- **Centre bounces are 6-6-6**, with at most four per side in the square,
  wingers on the wings and defenders goal-side. Players stand still before
  the bounce, then there's the ruck contest and the tap.
- **Kick-ins after a behind:** the kicker is in the goal square and the other
  side sets a three-line zone.
- **Ball-ups** come from MatchSim's explicit `ballup` event, logged where play
  stopped. The ball reaches that spot, a pack of three a side plus the rucks
  forms, the umpire throws it up, and the ruck taps it to the player who
  wins it. The view infers no stoppages of its own. After a tackle with no
  logged ball-up, the ball is won where it fell.
- **Kicks arc and handballs stay flat.** Flight time grows with distance and
  stretches, within limits, to give the receiver time to arrive. Forward-50
  entries land in a marking contest.
- **Movement** has acceleration, braking and reaction delays, so starts, stops
  and turns take time and paths curve. Sprint speed comes from the `carry`
  rating (presentation only).

## Pace

Presentation time runs `MatchDirector.TEMPO` (1.65) times faster than the
movement model's clock. A full match takes about 4 to 5 minutes at the default
4x and about 2 to 2.5 minutes at 8x.

## Checking it

- `tests/test_match_visual.gd` (in `tools/run_tests.sh`) covers:
  - the log, score and stats are unchanged after playback;
  - no event is mutated;
  - events are released in order at every speed and frame length;
  - no NaNs and no player off the oval;
  - no jumps;
  - the ball is at the logged spot on release;
  - global RNG isolation;
  - appended segments;
  - the PitchView API contract.
- `tools/visual/capture_match.gd` renders a contact sheet and a movement-trail
  image for any window of a match. Run it under `xvfb-run`; the header lists
  the options.
