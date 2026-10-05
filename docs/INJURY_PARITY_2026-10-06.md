# Injuries: simulated rounds vs played matches (2026-10-06)

Roadmap §1.11, "Autosim vs played-match injury-rate parity audit". The phone
impression was that players get hurt more when the round is simulated than when
it is played. **They don't. Parity holds, and balance is unchanged.**

## How injuries work today

- `MatchSim._plan_injuries()` rolls every player in the 22 once, at the first
  bounce, from `injury_rng`. That stream is seeded from the match seed alone
  (`seed * 13 + 7`), so the plan is fixed before anyone coaches anything.
- A planned injury happens at its minute if the player is on the ground, or
  has already been on. A bench player who never comes on is never hurt.
- `Injuries.apply_match()` writes `res["injuries"]` onto the lists. It falls
  back to the old after-the-siren roll only for a result with no injury record
  at all, which current results always carry. A round's other results are
  not saved mid-round, so a reload cannot strip that record either.

Neither path has an injury multiplier. The only inputs that differ between a
watched and a simulated match are:
1. **The seed.** A watched match uses `Season.next_seed(99)`, while Sim round
   uses the fixture's index. So a watched match is a different roll of the
   same dice, not a replay.
2. **Moments and the coach-box rotation call.** These only change who is on
   the ground when a planned injury comes due.

## Measurement

`tools/audit/injury_parity_impl.gd`: four drafted leagues, strength
neighbours paired, 25 seeds a pairing, 900 matches (1,800 team-games) per
mode, all from identical lists and selections. Side 0 is "you".

| mode | injuries / team-game | / player-game | starters / game | off the bench / game | mean weeks | concussion share |
|---|---|---|---|---|---|---|
| Sim round (auto) | 0.696 | 0.0317 | 0.0316 | 0.0321 | 2.82 | 7.1% |
| Played, Normal rotations | 0.696 | 0.0317 | 0.0316 | 0.0321 | 2.82 | 7.1% |
| Played, Rotate hard | 0.697 | 0.0317 | 0.0316 | 0.0322 | 2.82 | 7.1% |
| Played, Ride the stars | 0.696 | 0.0317 | 0.0316 | 0.0321 | 2.82 | 7.1% |
| Played, watched-match seed | 0.652 | 0.0296 | 0.0288 | 0.0333 | 2.78 | 6.0% |

- **Same fixture, same seed:** Sim round and a played match (default calls)
  hurt the identical players, for the identical weeks, in **900 of 900**
  matches.
- **Rotation policy:** Rotate hard brought one extra bench player on in time
  to be hurt (1,254 vs 1,253 injuries). Ride the stars changed nothing. Exposure
  is effectively the same because 99.9% of planned injuries happen in every
  mode.
- **Watched-match seed:** the lower row is a different draw of the same dice,
  not a bias. `tools/audit/injury_seed_impl.gd` builds 3,000 matches (6,000
  team-games) under four seed schemes and finds planned injuries of 0.720,
  0.705, 0.708 and 0.701 per team-game. The spread of ±0.01 is about one
  standard error; the watched scheme sits mid-pack.
- **Severity mix** (1 / 2 / 3–4 / 5–8 / 9+ weeks) is 38 / 28 / 18 / 12 / 4% in
  every mode.

## Regression coverage

- Existing: `test_injuries` "A match played and the same match simulated
  hurt the same players" (30 seeds, same-seed identity).
- New: "Every injury on a list after a simulated round is one the match
  recorded" (six real Sim-round weeks of a career). Also new: "A match that
  recorded no injuries hurts nobody afterwards, however fragile" (no second
  roll on top of MatchSim's record). Both fail if `apply_match` re-rolls.

## Likely source of the impression

Salience, plus variance. A simulated round reports the whole week's injuries
in one list after the fact. A watched match spreads them through the feed.
Injury counts per team-game have a standard deviation of about 0.83, so a run
of bad weeks in either mode is ordinary.
