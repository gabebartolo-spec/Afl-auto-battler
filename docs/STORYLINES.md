# Storylines: the kid you backed

**Status: design sketch.** Not assigned, not built. The calls under "Settled" were
the director's, made in the 2026-10-05 brainstorm; everything else is proposal.
`docs/ROADMAP.md` is untouched (see "Where this would live").

## Why

The target is a realistic sports-RPG: satisfying strategic gameplay, realistic and
deep (yet accessible, not overbearing) simulation, and emergent storytelling,
without compromising the simulation. MatchSim already supplies outcomes. What an
RPG adds is stakes: a person, something at stake for them, and a consequence that
persists. None of that needs a new dice roll in MatchSim.

The itch that started this: match day does not feel like your people are out
there. Every token on the oval is the same disc, club colours and a jumper number
(`PitchView._draw_tokens`). The live feed carries at most two story lines a
quarter (`MatchNotes.MAX_STORY_LINES`), in practice mostly injuries. The vignette
personalises one moment a match at best.

The pass mark is the siren test from the roadmap (section 0.2): straight after
the siren, can the player tell the story of the match, its turning points and the
people who defined it, in a few sentences?

## Rules the slice keeps

- MatchSim is untouched. The same seeded match gives the same score and calls
  with the feature on or off, the way the centre-bounce tests already prove it.
- Words, not numbers, on every new surface.
- Every line comes from stored facts. Nothing is invented, and no line claims a
  cause the log cannot show.
- Silence is fine. A match with nothing to say says nothing.
- A hard cap of three storylines a match.
- Cards ask a question; storylines never do. The card is the choice; the
  storyline is its context and consequence on match day. No line appears in both
  selection and the pre-match beat.
- Opposition facts (an ex-player of yours, a long record at your club) come from
  public records the player could look up. The AI does not use storylines.

## The slice, beat by beat

1. **The decision.** Backing a young player is recorded in a small ledger on the
   player, and "a game" becomes a run of three games. Backing comes from the
   young-gun card (`ClubLife._young_gun`, applied in `GameState` under `"blood"`)
   or from a "back for three games" tap on selection for any player with few senior
   games. Today the promise lasts one round (the `expects_game` block in
   `GameState`'s after-round code).
2. **The reminder (selection).** One factual line beside the player: "You
   promised Calder a run: game two of three." No advice.
3. **The storyline (before the bounce).** `GameState.milestone_notes` grows a few
   kinds, all derived from stored facts. This slice needs two, a debut and a
   promised run. Milestones already exist; old club and comeback follow.
4. **The oval.** A light-outline ring on storyline players and on the people you
   have decided about (tagger, spare, play-through, key match-ups). A surname
   caption when a ringed player has the ball, and on goal-scorers. Tokens already
   carry name and number (`MatchDirector._make_token`) and the director already
   tracks the actor (`MatchDirector.actor`), so this is presentation only.
5. **The payoff.** A feed line for the first goal (`MatchScene._on_event` is the
   one hook). Full time mentions each storyline that resolved, only when the log
   supports it. The player sheet's "With us" line records the debut and that you
   backed it (`GameState.with_us_text`).

Saves need no schema work: `CareerSave` encodes player keys generically (it skips
only `rates` and `norm`), so a ledger on the player persists.

## Settled (director, 2026-10-05)

- The first slice is players on match day.
- The weekly event cards stay. Storylines are a separate beat beside them, under
  the rule that cards ask and storylines never do.
- A promised run is three games.
- The oval gets a light-outline ring on storyline players and decision-people, and
  a surname caption for ringed players and goal-scorers only.
- Selection shows what you have committed to (promises, milestones). The pre-match
  beat, while the match loads, shows what the day is about. No line appears in
  both places.
- Backing comes from the young-gun card plus a "back for three games" tap on
  selection for any player with few senior games.
- Old-club storylines use a long record (100+ games at the other club) first, and
  in-career ex-players (20+ games for the other club) as the league builds its own
  history, both under the priority order and the cap of three.
- In the coach slice, a sacked coach with a lifeline gets a choice of a few clubs
  with different problems, facts only.

## Frequency probe

A read-only headless probe (a throwaway script run in a copy of the project;
nothing in the repo changed): a drafted league, four seasons (2027 to 2030), 94
matches each, for Melbourne, Geelong and Collingwood, with an autopilot coach who
never trades, releases or decides a card. Ranges are across the three runs, which
agreed closely.

Share of your matches with at least one storyline of each kind:

| Kind | Share of matches | Note |
|---|---|---|
| Debut | 6 to 7% | about one and a half matches a season |
| Milestone | 32% | already live; the most frequent kind |
| Comeback (out four weeks or more) | 10 to 14% | |
| Old club, naive (any past stint at the other club) | 86 to 93% | 2.3 to 2.7 a match: wallpaper |
| Old club, long record (100+ games at the other club) | 55 to 64% | fades each season |
| Old club, in this career (20+ games for the other club) | 1 to 3% | too rare early; the autopilot never trades |

Distinct storyline players a match (debut, milestone and comeback plus the old
club kind named):

| Old club kind | Silent | Exactly one | Three or more | Mean a match |
|---|---|---|---|---|
| Naive | 3 to 9% | 12 to 19% | 52 to 65% | 2.8 to 3.2 |
| In this career | 49 to 54% | 34 to 37% | 3 to 4% | 0.6 to 0.7 |
| In this career plus long record | 20 to 22% | 23 to 44% | 16 to 30% (four or more: 7 to 13%) | 1.4 to 1.8 |

For the last row the mean falls from about 1.9 to 2.3 a match in 2027 to about 1.1
to 1.4 in 2030, and the silent share rises from 8 to 21% to 25 to 29%.

What it says:

- **The naive old-club kind is wallpaper in a redrafted league.** Nearly every
  player faces the real club they came from. It should not ship as "played there
  before".
- **The league starts with borrowed history and earns its own.** A long-record
  version gives early seasons their texture (real careers), then fades as those
  careers recede, while in-career ex-players grow with trades and free agency. The
  in-career kind is too rare to lean on in the first seasons. A real career, which
  trades and releases, will fill it faster than this autopilot did.
- **A cap of three is a safe ceiling.** With the long-record definition it trims
  only 7 to 13% of matches; most matches carry none to two.
- **The decision beat is thin.** The young-gun card appeared three times in four
  seasons in all three runs, and only once with a player who had no senior game
  yet. A debut turns up in about one and a half matches a season. The headline loop
  will be rare, and the first-goal payoff (2 to 5 a season for your players, from
  league news) is the more frequent beat.
- **It will not be reachable organically in a short playtest.** Plan a playtest
  trigger the way the bounce scene has one (Settings, "Centre-bounce scene every
  match").

Caveats: one run per club, four seasons, an autopilot coach, and the thresholds
(100 and 20 games) are the probe's choices, not the game's. The probe script is not
in the repo; it can be added under `tools/` if you want it kept.

## Open calls

1. **"Few senior games".** The threshold for the selection tap. The probe can
   count how many players in a typical 22 fall under each candidate number.
2. **A broken run.** What it costs: the existing morale sting once, or once for
   each game the player is left out while fit.
3. **Old-club thresholds.** Whether 100 games (long record) and 20 games
   (in-career) are right.
4. **Priority within the cap.** Suggested: your own history first (a backed debut,
   a promised run, a debut, an ex-player of yours facing you), then a milestone, a
   comeback, a long-record old club. Milestones are the most frequent kind, so
   ranking them first would crowd the rest out.
5. **Rings.** The most there can be at once, and the look (a thin light outline,
   per the selection rule in `UiKit`).
6. **Playtest trigger.** A Settings switch that guarantees a storyline in a match.
7. **Wording.** Candidates below.

## Candidate lines

For the director to cut and rewrite. Written without numbers where possible, with
no pronouns, and with no claim of cause. "Calder", "Walsh", "Hartigan" are
stand-ins.

**Selection** (commitments)
- You promised Calder a run: game two of three.
- Calder's run: two of three.
- Calder's run is done.

**Pre-match beat** (the day)
- A first AFL game for Calder.
- Calder debuts.
- A first AFL game for Calder, on your say-so. (for a backed debut)
- Hartigan is back after eleven weeks.
- Hartigan returns.
- Walsh returns to face Collingwood. (long record)
- Kennedy returns to face you. (an ex-player of yours)

**Feed** (payoffs)
- First AFL goal for Calder.
- Calder's first AFL goal.
- A goal for Viney in the 100th game.
- Walsh goals against the old club.

**Full time** (only when the log supports it)
- Calder kicked two on debut.
- A quiet first game for Calder.
- Calder's three-game run is done.
- Hartigan got through the return.
- A win in Viney's 100th. / A loss in Viney's 100th.

**Player sheet** ("With us")
- Debuted in Round 7, 2028, on your say-so.
- First goal in Round 9, 2028.

## Next slice (proposal): the coach's record and the lifeline

The director's direction: a light coaching record with elements of a full career.
A sacked coach can get a chance at a weaker club; only one second chance, and a
premiership renews it.

What exists today:

- The data for a light record is already kept: the honour roll
  (`GameState.honour_roll`: year, premier, runner-up, your finish) and the board's
  history (`board["history"]`: year, goal, met, position, verdict).
- NPC coaches already carry a reputation with words (`Coaches.rep_word`: Big name,
  Well regarded, Respected, Little known), moved each off-season by results
  (`CoachMarket._reputation`: a senior coach's goal met +4, missed -4, finals +2, a
  flag +10). Its own docstring: reputation opens doors, it does not make anyone a
  better coach.
- A sacked senior coach is already "a harder sell" for three years
  (`SACKED_SC_PENALTY_YEARS`), and a club will not rehire a coach it sacked within
  five (`SACKED_CLUB_COOLDOWN`).
- The season close runs the board's verdict and then the coach market, back to
  back (`GameState._close_season_awards`), so the market can answer a sacking in the
  same off-season.
- Being sacked today is a hard stop: `HubScene._sacked_card` offers "Start a new
  career". The board's "final warning" is already a first life: warned, then
  sacked.
- `my_club` is assigned in three places (loading a save, reset, `start_season`)
  and referenced about 230 times, so re-binding is contained. The work is the
  derived state: board, staff slot, department budget, selection, week event and
  any per-club saved state.

Proposal:

- **The record (read-only, derived).** Seasons coached, finals, flags, goals met,
  plus a reputation word on the NPC scale, moved by the same rule. Shown on the
  Coaching hub and the season review. Plus "how you coach" from the season-story
  ledger already on the roadmap.
- **The lifeline.** One in hand from the start; a premiership restores it (never
  more than one). Sacked with it: the sacked card becomes job offers, a few clubs
  the market would plausibly let you have (struggling clubs with a vacancy; at
  least one guaranteed), each with facts only (list age in words, cap room, the
  board's goal for you, recent finish). Sacked without it: the career ends with an
  epilogue of your record instead of "Start a new career".
- **What carries, what resets.** Carries: record, reputation, style (default plan,
  rotation habit). Resets: players, promises, board confidence (a fresh start with
  a goal calibrated to that list).
- **Layers.** Warned, sacked, lifeline, new club, warned, sacked, end.
- **Thin first cut.** The record and the epilogue, with no club switch. Then the
  switch, after an audit of per-club derived state.

Settled: the offers are a choice of a few clubs with different problems, facts
only. Open calls: (1) does a flag only restore the lifeline, or also protect for a
while, as AI flag-winners are (`PREMIER_PROTECTION`, three seasons)? (2) can the
lifeline club be an expansion club when the timing allows? (3) what the epilogue
says.

## Where this would live (for the director to confirm)

Nothing has been added to `docs/ROADMAP.md`. If and when this is assigned, the
natural homes are:

- ARD-M7-003 (Player milestones): the storyline kinds (debut, comeback, old club)
  extend `milestone_notes`.
- The "Season story / campaign recap" item in section 1.11: the ledger and the
  "With us" callbacks.
- ARD-M8-003 and ARD-M8-007 (match visualisation, vignettes): the ring and the
  caption.
- ARD-M6-003 (Board Confidence): the coach's record and the lifeline change the
  sacking lose-state contract.
