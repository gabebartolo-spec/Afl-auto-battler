# Sim round and Play match timing by round (2026-10-06)

Roadmap §1.11, "Round simulation / Play match performance regression audit".
The phone reports were that Sim round takes far too long and that the wait
after Play match gets worse as the season goes on.

**On current `main`, nothing grows with the season.** The tap is already
quick. What remains is the flat per-match cost of MatchSim on a phone.

## Method

`tools/audit/round_perf_impl.gd` plays one home-and-away season (Geelong,
24 rounds) through the real `GameState` flow, twice:
- **Sim round every week:** `GameState.advance()`.
- **Play match every week:** `prepare_interactive_match()` (what the tap
  waits for), then the match stepped quarter by quarter with default calls
  (what MatchScene runs while you watch), then `finish_interactive_match()`.
  Full time covers collecting the round's other matches, recording, training
  and the week's admin.

Autosave is timed separately (`save_career()` after each round), and the save
size is read back. Desktop, 16 cores, headless. Other sessions' audits were
running at the same time, so individual rows carry about ±100 ms of noise.

## Results (ms)

| | R1 | R6 | R12 | R18 | R24 | trend |
|---|---|---|---|---|---|---|
| Sim round (`advance`) | 576 | 590 | 606 | 535 | 683 | flat (range 528–732) |
| Play match tap (`prepare`) | 41 | 44 | 49 | 53 | 44 | flat (41–60) |
| Your match, CPU while watching | 402 | 414 | 382 | 372 | 515 | flat (369–515) |
| Full time (`finish`) | 152 | 94 | 140 | 211 | 106 | flat (46–211) |
| Autosave | 78 | 94 | 89 | 95 | 154 | slight rise |
| Save size (KB) | 2,083 | 2,178 | 2,278 | 2,359 | 2,443 | +17% over the season |

## Reading

- **The Play match tap is fixed.** `prepare_interactive_match` no longer plays
  the round's other matches first. They start on background threads
  (`Season.start_all`) while you coach, and the pre-match scene
  (`PreMatchVignette`: warm-up, final instructions, through the banner) covers
  the moment. The roadmap's lead about "eight full background simulations
  before your match" is out of date.
- **Sim round does not get slower as the season advances.** `club_form()`
  scans at most about 216 results, and nothing in `_after_round` grows
  measurably.
- **The save grows** by about 15 KB a round (`season_log`, tallies), and save
  time rises from about 80 to 100 ms by R24. That's small next to the matches,
  but it is the only cost here with a season trend.
- **One match costs about 0.4–0.5 s of a desktop core.** Sim round runs the
  week's 9 matches across `cores − 1` threads: one wave here, two on an
  8-core phone. A phone core is several times slower, so a Sim round of a few
  seconds is expected from that alone, and it is the same in R1 and R24.

## Recommendation (not started)

The lever is MatchSim's per-match cost, not anything that grows with the
season. The roadmap's own suggestion is the candidate: a background
(non-watched) mode that skips presentation-only work, such as building the
roughly 1,100 event dictionaries and feed strings that only a replay reads,
while drawing the same random numbers in the same order, so scores and stats
stay identical. It touches MatchSim throughout and has to prove identical
seeded results, so it belongs on its own branch once MatchSim is quiet (the
tired-call work is currently editing it). A native phone measurement of one
Sim round would size the win before it is built.
