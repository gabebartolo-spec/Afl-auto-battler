# Fixture sizes: 18, 19, 20 and 21 clubs

Research only, for ARD-M7-009's "21-club fixture support" (Club Forge can add a
21st club). No code changed. Written from `scripts/sim/Season.gd` on main,
2026-10-06; the counts below come from running the same algorithm on 18 to 21
placeholder clubs.

## What the generator does today

`Season.build_fixture()` takes `round_robin(clubs)` (circle method, one club
held still, the rest rotating) and then repeats its first rounds with home and
away flipped until there are `REGULAR_ROUNDS` = 24 rounds.

- **18 clubs:** 17 rounds, then the first 7 flipped: 9 matches a round, every
  club plays 24. Seven opponents are met twice, the same seven for a given club
  by position in the list (the rest once).
- **20 clubs (Canberra, 2030):** 19 rounds, then the first 5 flipped: 10
  matches a round, every club plays 24. Fine.
- **19 clubs (Tasmania, 2028 and 2029):** an odd count adds a virtual `BYE` to
  the rotation, so each round has 9 matches and one club rests, and the
  round-robin takes 19 rounds. The 5 flipped rounds repeat the first five
  rests. Result: 14 clubs play 23 games and 5 clubs play 22. `test_expansion`
  accepts "22 or 23" (the comment in `Season.gd`, "every club still plays 24
  games", is wrong for odd counts).
- **21 clubs:** 21 rounds, then 3 flipped: 18 clubs play 23 and 3 clubs play 22.
  Same defect as 19 clubs, nothing new.

Other things the same run shows, which matter to a 21st club:

- **Byes follow the club list order.** The first club in `GameDB.CLUB_ORDER`
  rests in round 1 and then again in round 20 (19 clubs) or 22 (21 clubs), so it
  has two byes while most clubs have one; the other early-rested clubs repeat
  theirs too. The user's club is whichever club the user picks, so the club
  that gets the extra rest is a matter of alphabet, not design.
- **Home games are unbalanced for everyone.** The venue rule
  `(round + pairing) % 2` gives 7 to 17 home games for 18 clubs, 5 to 19 for 20
  clubs, 3 to 20 for 21 clubs. The real league is 11 to 12. This is already the
  case at 18 clubs, so it is a fixture question first and an expansion question
  second.
- **The ladder is points, then percentage.** Clubs with fewer games have fewer
  points, so unequal games are unfair on the ladder, not only on the schedule.
- **Finals** are a fixed top 10 (`FINALISTS`); with 21 clubs that is fewer than
  half the league. Not a fixture defect, but a design check for 20 and 21.

## What a 21-club season needs

1. **Equal games for every club.** With 21 clubs and one rest a round, the
   number of rounds has to be a multiple of 21, so 24 rounds cannot be equal.
   Two equal options:
   - **21 rounds, 20 games each:** a single round-robin, one bye each. Simplest,
     fair, but a shorter season than 18 and 20 clubs have (24).
   - **24 rounds, 22 games each:** most rounds with one club resting and nine
     rounds with three resting (15 rounds of 10 matches and 9 rounds of 9), so
     each club has exactly two byes. Equal games at 22 (the same arithmetic works
     for 19 clubs: 17 rounds of 9 matches and 7 rounds of 8). Each club meets 20
     opponents once and two of them twice.
   The choice is a design decision for the director (season length versus
   byes); the second keeps 24 rounds, the first is the easiest to build and
   test.
2. **A fair, rotating bye.** Each club the same number of byes; none in round 1
   or the last two rounds; no club always early or always late; the placement
   chosen by the season seed, not by the club's place in the list or by who the
   user is. If the user's club rests, the round must still play for the AI
   clubs and the Hub must say so (the 19-club case already exercises this).
3. **No advantage to the user's club.** The user's club must not be the club
   that receives the fixed first-in-list bye, the extra bye, the better home
   count or the easier repeated opponents. The same algorithm for every club;
   the seed varies placement.
4. **Balanced venues.** Replace the parity rule with an assignment that gives
   each club within one home game of half its games, and no club more than
   two home games in a row, for every club count.
5. **Opponent repeats chosen fairly** (the extra games in the 22-game option, and
   the 18 and 20 club repeats): not always the same positional opponents, and
   rivalry-neutral unless a rivalry fixture is intended.
6. **Finals size:** decide whether 10 stays for 21 clubs (it does not need to
   change for the fixture, but the director may want 8 for a league of 21).

## Test plan (19, 20 and 21 clubs, and 18 as the control)

Use `Season.new(codes, lists, seed)` with real club codes and the shipped list
data; no match simulation is needed to check the fixture.

- **Equal games:** every club plays the same number of games (a single value
  across the league) for 18, 19, 20 and 21 clubs. This fails today for 19 and 21.
- **Round shape:** every round has `floor(n / 2)` matches or fewer by design, no
  club twice in a round, no `BYE` code in the fixture, every club is in the
  `fixture` at most once a round.
- **Byes:** each club has the same number of byes; none in round 1 or the last
  two rounds; the club with the most byes is not the first in `CLUB_ORDER`; the
  byes of two seeds differ and the same seed repeats exactly.
- **User neutrality:** across 20 seeds and every possible user club, the user's
  club never has more byes, fewer games or a worse home count than the league's
  median club.
- **Opponents:** every pair meets at least once (171, 190 and 210 pairs for 19,
  20 and 21 clubs), and no pair meets more than twice.
- **Venues:** home games per club within one of half its games; no more than
  two home games in a row.
- **Ladder:** with equal games, ladder points are comparable (no club is ahead
  only by having played more).
- **Flow:** a full season with 21 clubs (including the user on a bye) plays to a
  premier through `GameState`; save and reload mid-season, including on a bye
  round, restores the same round and results.
- **Existing tests:** `test_expansion` asserts "22 or 23 games" for 2028 and a
  24-round fixture; those assertions change with the chosen design, and the 18-
  and 20-club behaviour stays as a regression check.

Not covered here: the Club Forge UI, naming, the draft and list consequences of a
21st club, and ground availability (the grounds in `data/forge_locations.json`
are a separate question).
