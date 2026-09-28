# AFL Auto-Battler — Design

An auto-battler where the "battles" are simulated AFL matches. You draft a full
44-player list from **real 2026 AFL season statistics**, then play a 24-round
home-and-away season plus finals on an animated oval.

Built for **Godot 4.7** (GDScript), targeting **PC and mobile**.

---

## 1. Data

`data/players_2026.csv` — real 2026 AFL season totals per player, harvested from
[AFL Tables](https://afltables.com/afl/stats/2026.html). Target depth is the top
~30 players per club by disposals (≈540 players across all 18 clubs).

Columns (all season totals unless noted):

| Col | Meaning | Col | Meaning |
|-----|---------|-----|---------|
| `club` | Club code (see `data/clubs.csv`) | `br` | **Brownlow votes** |
| `num` | Jumper number | `cp` | Contested possessions |
| `last`/`first` | Name parts | `up` | Uncontested possessions |
| `gm` | Games played | `cm` | Contested marks |
| `ki`/`hb`/`di` | Kicks / handballs / disposals | `mi` | Marks inside 50 |
| `mk` | Marks | `onepct` | One percenters |
| `gl`/`bh` | Goals / behinds | `bo` | Bounces |
| `ho` | Hit-outs | `ga` | Goal assists |
| `tk` | Tackles | `pctp` | % of game played |
| `rb`/`if50` | Rebound 50s / inside 50s | `cl` | Clearances |
| `cg` | Clangers | `ff`/`fa` | Free kicks for / against |

`data/clubs.csv` holds club names, guernsey colours (for the pitch renderer) and
home grounds.

`data/player_history_2026.csv` - each 2026 player's AFL Tables slug, draft
pedigree, rated recent seasons (`seasons`, POT's input) and `career`: every
AFL season from 2004 to 2025 as club stints, `CLUB:first:last:games:goals`
separated by `;` (finals included; a season split by a mid-season move counts
at each club). `""` means no senior game before 2026; `"?"` would mean an
unmatched player whose past is unknown (none today). Built by
`tools/build_history.py` from one AFL Tables page per season, not one per
player.

`data/draftees_2026.csv` - the 2026 national-draft class (56 prospects).
Columns: `rank,first,last,pos,pos2,pos_detail,height_cm,dob,state,team,league,`
`tied_club,tied_type,u18_gm,u18_di,u18_gl,u18_mk,u18_tk,u18_if50,u18_ho,note,`
`data_src`. `rank` is the consensus board (Rookie Me Central's August-2026 top
50, plus six notable names it missed); `pos`/`pos2` are the engine's four
roles; `u18_*` are per-game averages at the level quoted in the scouting
notes (Talent League / SANFL / WAFL); `tied_club` + `tied_type` mark
father-son/NGA prospects. These players have no AFL season line, so they skip
`Ratings.derive_all` and use the projection in `Prospects.gd` instead.

### Attribution
Player statistics are factual season data compiled from AFL Tables, a long-running
volunteer-maintained archive. The AFL, its clubs and Champion Data do not endorse
this project, and no player imagery or club badges are reproduced.

### Fictional / real player labels
The shipped data keeps each real name for the optional real-name view, but the
player presentation defaults to a deterministic shuffle of generated random names
(`Ari Bramble`, `Bex Cinder`, and so on). Every player gets a generated name —
numbered placeholders such as `Squadmate 001` are never shown. **Player
names** (New career setup, or Settings on the main menu) switches to the real AFL name on its own, such as
`Jordan Dawson`. It does not prefix a fictional alias or a "plays like"
comparison, and it does not change IDs, ratings, draft logic or match results.
Players with no real-world counterpart (generated future draft classes) keep
their fictional name in both modes. Draft history resolves labels by player ID
so switching the mode never leaves an old name in a row or tooltip. This is a
product presentation choice, not legal advice or a licensing determination.

---

### Chronology
* **Source data: the completed 2026 AFL season.** Ratings come from real
  2026 statistics; every real player's career record runs through 2026
  (`player_history_2026.csv` to 2025, plus his real 2026 games and goals at
  the club he played them for, added when a career starts); the 2026 draft
  class is part of that world.
* **Career start: 2027** (`GameDB.START_YEAR`). Ages are as of 1 March 2027
  from date of birth (`GameDB.age_at_start`). The 2027 League Draft pool is
  the 2026 league plus the 2026 class (drafted before the season, on the same
  terms as everyone; its real father-son/NGA ties do not apply to a full
  redraft). The first in-career national draft, after 2027, drafts the
  generated 2027 class, made at career start the way every rollover makes
  next year's. No 2026 development or retirements are simulated: 2027 starts
  from the 2026 ratings, one year older.
* **Coaching source: Round 1 2026**, carried by continuity into 2027 (see
  Coaching staff).
* **Old saves** keep their own timeline: a career begun in 2026 by an older
  build still plays and drafts its 2026 class; only new careers start in 2027.

## 2. Ratings — turning season stats into game attributes

Every player is reduced to 1–99 attributes plus a **role** and a **salary value**.

### Sample-size shrinkage
Raw per-game rates are shrunk toward the *average player's* rate so a 2-game
sample can't produce a 99-rated freak:

```
rate = (season_total + K * league_player_rate) / (games + K),   K = 5
```

The shrink target must be the **per-player** league rate (`tools/sim_harness.py:
player_league_rates`), *not* the per-team-game rate. Shrinking an individual
toward a whole team's output (364 disposals/game) inflates fringe players above
Nick Daicos — this was a real bug caught by the harness.

### Normalisation
Each rate maps to 0..1 by capped linear scaling against the **98th percentile**
of the pool. Percentile *rank* is deliberately avoided: most stats are zero for
the majority of players (hit-outs, bounces, marks inside 50), so a rank hands a
high score to a zero. Brownlow votes use a cap of 1.0 (the true max) because
exact ordering at the very top matters — a record 47 votes must beat 36.

### Attributes
`disposal`, `contested`, `marking`, `pressure`, `intercept`, `carry`,
`goalkicking`, `accuracy`, `creating`, `ruck`, `discipline`, `durability`, `star`
— each a weighted blend of normalised rates.

### Role
Computed, not hand-tagged:

* **RUCK** — only if `hitouts/game >= 7`; otherwise ineligible.
* **FWD** — goals, marks inside 50, goal assists.
* **MID** — disposals, contested possessions, clearances.
* **DEF** — rebound 50s, one percenters, marks, low goals.

Highest score wins. Across the harvested pool this yields ~2 rucks per club,
which matches reality.

A second role is added only when the season numbers clear a gate, not from a
ratio of the two scores (that flags most of the pool). Examples the gates catch:
Heeney, Bontempelli, Nick Daicos, Rankine and Pickett as MID/FWD; Greene as
FWD/MID; Sicily, Blakey and Josh Daicos as DEF/MID. Butters (5 goals) and Cripps
stay MID. DEF/FWD is allowed by the same gates, but the 2026 pool did not
produce one — it is not invented. The tag is `MID/FWD`.
A midfielder on the numbers also keeps the line his club lists him in
(`real_pos`) as a second position when his own numbers back it up
(`Ratings.listed_secondary`): a listed forward with 0.35 goals or 0.5 marks
inside 50 a game, a listed defender with 2 rebound 50s plus one percenters a
game. That gives 71 MID/FWD and 13 MID/DEF their line back (forward-eligible
players 141 -> 212, defence 224 -> 237). First positions, ratings and types
are untouched; listed forwards with no forward numbers (McKercher, Delana,
Scerri) stay midfielders. Match-day selection
fills each slot from primary players first, then from the secondary. The
on-ground copy's `role` is the slot, so the oval still groups them; `list_tag`
keeps the natural tag for the list screen. Draft filters and the two-ruck rule
treat either role as cover. Position totals stay primary-only, so they still
sum to the list size.

Two classifier misreads are corrected by hand (`Ratings.ROLE_CORRECTIONS`:
Maurice Rioli and Cody Weightman, listed and played as forwards).

**Known issue, deferred (a Ratings/classification task of its own).** The
broad classifier is still biased to MID: the role scores are not on one scale
(MID rewards disposals, contested ball and clearances that every busy player
racks up; FWD leans on goals most players kick few of), so ~85 listed forwards
and 21 listed defenders read MID - pressure forwards can even read as Wings or
Taggers. Letting the listed position (`real_pos`) lead fixes it, but broad role
also drives OVR (`Ratings.rate_overall` scores the role's core and position
stretch), so that fix moves 122 players, changes 110 OVRs (4 by 10+) and pulls
the forward median ~7 below midfield. It also shows the FWD core undervalues
pressure forwards: pressure is not in it although the engine rewards team
pressure. Classification and the forward rating need to be settled together.

### Match-day roles (`scripts/sim/Roles.gd`)
Only jobs the engine rewards:

* **Wing** (MID). Two of the five midfield spots are the wings. The centre
  square (three) alone counts for the side's contested ball
  (`Squad.mid_contest`); on the wing a player gets 1.6x the transition ball
  (`MatchSim.pick_carrier`) and 0.4x the stoppage ball. A natural wing -
  running game (carry, disposal) well ahead of ball-winning against 2026
  midfielders - suits it; a ball-winner is wasted there. Auto-pick puts the
  two midfielders the stoppage misses least on the wings.
  On the oval the named wings take the wing slots (the match roster carries
  each player's `line`), holding width (about 30 m off centre against 7 m
  for the centre square), following the ball up and down the ground, and
  setting up on the wings at centre bounces. The wing marking travels with
  the player, not the position: when a wing rotates off, his replacement
  plays in the engine as a centre-square midfielder until the wing returns
  (a rule to revisit with rotations, not a presentation issue).
* **Tagger** (MID). Pressure in the top 30% of midfielders and well ahead of
  both his ball-winning and running. With a tagger on the ground, a tagged
  opponent keeps 42% of his ball instead of 55%.
* Everyone else reads as Inside midfielder, Key/Rebounding defender or Ruck
  (the Training vocabulary; a defender with fewer than six games of record
  is just a Defender - a few games cannot tell the two apart), or - for forwards - Key forward, Small forward or
  Forward (`PlayerProfile.forward_type`, a label only: ratings are untouched).
  Goals never make a key forward: it takes height (evidence, not a cut-off:
  184 cm counts nothing, 196 cm in full, ~192 cm the rule of thumb) weighed
  60/40 with his marking against other forwards. A small forward is short and
  plays below the pack. The rest, or anyone without a height, is a Forward -
  broad rather than wrong (Toby Greene).

Deferred until the engine can tell them apart: tap vs mobile ruck (only the
ruck attribute and contested ball reach a ruck's game), swingman (any player
already plays anywhere; `role2` covers genuine dual-position players), tall vs
small defenders, unicorns.

### Overall & salary
`overall` = 0.70 × role core + 0.22 × `star` (Brownlow signal) + 0.08 ×
`durability`, put on one position scale, shrunk toward 40 for low-game
players, then stretched (`scale_overall`) so the best 2026 players land near
90 while the middle of the pool stays in the 50s. `value` (1–10) is the draft
salary-cap cost, banded off the overall.

**Role core** (`Ratings.ROLE_WEIGHTS`) is what the match engine rewards a
player in that role for, not what a stats sheet does:

| Role | Core |
|---|---|
| MID | contested 0.55, carry 0.14, disposal 0.13, pressure 0.10, goalkicking 0.04, accuracy 0.04 |
| DEF | intercept 0.40, pressure 0.35, carry 0.15, contested 0.10 |
| FWD | goalkicking 0.30, pressure 0.20, marking 0.15, accuracy 0.15, creating 0.12, carry 0.08 |
| RUCK | ruck 0.90, contested 0.10 |

The weights come from measuring the engine: one attribute lifted by 20 for
every player in a role on one side of a GEE v COL match (neutral venue,
2,500 matches each; baseline GEE +20.6), and the change in margin recorded.
Re-measured after zonal pressure (forwards press the defensive half,
rushed disposals, pressure acts). A difference under ~1 point is noise.

| Role | +20 is worth (points of margin) | Worth ~0 |
|---|---|---|
| MID (5) | contested +12.9, pressure +6.7, carry +4.1, disposal +3.1, accuracy +2.9 | goalkicking (+0.9), marking, creating |
| DEF (6) | pressure +5.6, intercept +5.4, carry +4.5, contested +1.8 | disposal (+1.2), marking |
| FWD (6) | goalkicking +4.3, pressure +3.1, accuracy +2.4, marking +2.2, creating +1.9, carry +1.0 | disposal, contested |
| RUCK (1) | ruck +4.7 | contested, pressure |

The forward core follows the measurement: a forward who presses and sets
up goals is now rated for it, so pressure small forwards rise (Greene 72 to
79, Curtis 68 to 75) and key forwards who neither tackle nor create ease
back (McKay 72 to 66, Georgiades 82 to 76). The midfield core takes a
smaller pressure share than measured (0.10) so it stays a stoppage rating
first. The defensive and ruck cores are unchanged: the measurement would
lift carry for defenders, but that reflects where the engine lets
defenders carry rather than a football case for rating rebounders above
key defenders.

The old core gave a ruck 30% disposal and 20% intercept, a defender 26%
disposal and a forward 30% disposal - none of which the engine uses for
those roles - so drafting and selecting on OVR chased the wrong players.

**Position scale** (`Ratings.position_stretch`). Each position's raw blend is
mapped piecewise-linearly at its 10th, 50th and 98th percentiles (2026, 12+
games) onto fixed targets - the positions' spreads as they were - and one for
one outside that band. Medians stay level with the midfield median, the
elite of every position reaches the high 80s (the non-midfield 98th
percentile sits 85% of the way to the midfield one), and the low tail stays
clear of the retirement floor.

**Saves.** OVR is derived data. `GameState._recompute_ratings()` rebuilds
every player's `overall` and `value` from his attributes on load, and moves
his POT and season-start mark by the same amount, so a save from an older
formula never keeps stale ratings. `data/player_history_2026.csv` (the past
seasons POT reads) is rebuilt with `python3 tools/build_history.py --offline`
whenever the formula changes.

**Validation.** On the same selected 22s, the new rating predicts season wins
better than the old in every league tested (drafted leagues, AI clubs:
r 0.35 → 0.46; real 2026 lists: r(OVR, `Squad.strength`) 0.80 → 0.87), and
the "a 3+ OVR favourite wins 47%" drafted-league anomaly is gone (55%).
Spearman of OVR with 2026 Brownlow votes (5+ votes) rises from 0.46 to 0.51;
Daicos (47 votes) rates highest.

### Prospect projections (no AFL stats)

Draft-class players arrive with a target overall from a rank taper (consensus
#1 → low 70s, back of the draft → high 40s), shaped by reported U18
production, height and age. A role template sets the attribute *shape*; a
bisection then shifts every attribute uniformly until `rate_overall` lands on
the target, so prospects are expressed in exactly the same units as real
players and feed the same engine. `Ratings.effective_games()` carries the
"sample" override: projections skip the small-sample confidence shrink, and a
player who has completed a simulated season keeps a full-season sample so a
fringe 2026 games count cannot suppress them forever. `tools/intake_harness.py`
mirrors these constants the way `sim_harness.py` mirrors the match engine.

**Class quality.** Generated future classes (never the real 2026 class) get a
quality tier, rolled once per career and draft year from `career_seed` (a
random number saved with the career) and the year, so a reload never re-rolls
a class and two careers need not share their superdrafts
(`Prospects.class_tier`). Tiers and their rates: weak 10%, below average 20%,
normal 50%, strong 17%, superdraft 3% (about one a generation in a 30-40 year
career). A tier moves three things, all tapering from pick 1 to nothing by
rank 30 (`Prospects.CLASS_TIERS`): the draft-night rating of the top end
(super +4.5, strong +2, weak -3), the depth a little (super +2, weak -1.5),
and the extra POT room of the best prospects (super +9, strong +3, weak -3).
The prospects themselves - who they are, their positions, their own rolls -
are seeded by the year alone, so busts, role spread and ordinary late picks
stay. Measured over 400 generated years and in 28-year rollovers with one
class forced to each tier: a super class produces about six players who peak
at 80+ where a normal one produces none to two, with a top 20 peaking about
4 points higher; league mean OVR stays at 60.4 either way (re-anchoring), and
twenty years on the league's count of 80+ players is the same whatever that
class was - a cohort advantage, not inflation. The tier of every generated
class is recorded in `class_tiers` for a future draft-history view; the game
does not announce it. `tools/intake_harness.py` mirrors the normal tier only.

---

## 3. Match engine

A match is a sequence of **possession chains**, not a tick-based clock.

```
4 quarters x N chains
  each chain:
    starts at a stoppage (centre bounce / ball-up)  -> ruck contest, hit-outs, clearance
      or continues from where the last chain died   -> turnover / defensive exit
    loop touches (max 11):
      pick carrier  (weighted by zone: intercept deep, carry mid, goalkicking inside 50)
      kick or handball, mark chance
      defensive pressure -> tackle: attacker retains (contest) or ball up
      clanger chance -> free kick against
      effective disposal -> metres gained -> advance field position
      crossing the forward-50 arc -> resolve_forward50()
    resolve_forward50: shooter + defender picked by rating
      mark / spoil contest -> goal | behind | rebound 50
```

Field position is metres from the centre square (`-85 .. +85`), forward-50 arc at
`±35`. Each side fields **18** in a 6-6-6 shape (6 DEF, 6 MID — the ruck counted
with midfield — and 6 FWD) plus 4 interchanges.

Restarts: a goal or a quarter break -> centre bounce. A behind -> the other
side kicks in from its goal square (fp 4.5 m inside its goal line, first
disposal a kick), uncontested: no ruck contest, hit-out or clearance. Any
other stoppage is balled up where play stopped, and MatchSim logs a `ballup`
event there. A chain that starts inside its forward 50 goes through the
normal inside-50 entry on its first disposal. Re-calibrated for this with
existing constants only: `stoppage_share` 0.50 (was 0.38: the behind restarts
no longer supply ruck contests), `metres_gain_mean` 8.8 (8.0),
`max_touches_per_chain` 14 (11) and `rebound_from` -18 (-16), since kick-in
chains start 80 m from goal.

Stoppage win probability is a strength differential divided by `contest_swing`
(360) and clamped to `[0.40, 0.60]`, plus a small home-ground bonus and a
territory nudge. Clamping matters: an unclamped stoppage contest compounds over
165 chains and produces absurd 70-point average margins.

### Determinism
The sim takes a seed and generates the **entire event log up front**. The pitch
view then replays it. That decouples simulation from presentation, so speed
controls, pause and "skip to result" are free, and any match can be re-watched.
The view only interprets the log (how an event looks, never whether it
happens) with its own random stream: see `docs/MATCH_VIEW.md`.

### Calibration
Carrier picks fade a player out of the next possession once they have already
had a realistic game (`usage_multiplier`: unfocused fade from 18 disposals,
focused from 21). "Run play through" is a 1.14x early weight on that player,
not a 1.55x magnet, so a focused game stays in the low 30s (hard ceiling mid-30s
in the probe) instead of 50–80. Team disposal volume is unchanged — the fade
only changes who is chosen. The same curve is in `tools/sim_harness.py`.

`tools/sim_harness.py` runs the engine over hundreds of matches and compares the
output against the per-team-per-game averages implied by the real harvested data.
With all 18 clubs loaded and the usage fade on, disposals, kicks, handballs,
marks and inside 50s stay within a few percent of the 2026 totals. Behinds and
rebound 50s sit lower (about 0.86–0.87) because a different carrier changes
later rolls; they were already the soft stats before the fade.

A 200-match check against the full 18-club file (seed 1234): disposals 1.01,
kicks 1.00, handballs 1.01, marks 1.02, inside 50s 1.00, score 0.94. Behinds
0.86 and rebound 50s 0.87 are the outliers. Average margin about 29 points.

> `tools/sim_harness.py` is a **tuning harness, not shipped game code**. It is a
> deliberate Python mirror of `scripts/sim/MatchSim.gd`. When a constant changes
> in one, change it in the other.

### Matchday screen
The live match answers five questions at a glance: the score, the clock, who
leads ("Demons by 7"), what just happened, and what your calls are ("Your
plan: Defensive press · tagging Walsh"). It is presentation only
(`scripts/ui/match/MatchNotes.gd`): every line is read from MatchSim's event
log or its quarter snapshots, never decided by the screen.

- **Feed.** Goals (their own row), behinds, the breaks ("Quarter time:
  Melbourne by 7"), your coach's calls, and runs of three or more goals in a
  row. Routine play (marks, kicks, tackles, entries, rebounds, clangers)
  stays on the oval. A result word ("defeated") only ever describes a final
  result. The clock is the minute of the quarter, like a ground's.
- **Quarter breaks.** What happened, then your calls. Up to three facts
  about the quarter (their midfield on top at the stoppages, most of the ball
  going forward, a player hurting you, wayward kicking), what they played,
  how your tag and your calls came off - then the gameplan, tag, player to
  play through, pep talk and rotations, each described in football words
  (the exact percentages stay in the assistant's report). Legs read in words:
  fresh, tiring, running on empty. The break surfaces the problem; it never
  names the answer. The calls are taps, not dropdowns: gameplan, pep talk
  and rotations are short lists shown in full; Tag and Play through show
  "none" and the four players most in the game so far (before the bounce,
  the best rated), plus "Other player..." for the whole side on the ground.
  The order is a convenience - nobody is filtered out.
- **Full time.** The conclusion, easy to scan: the result first and big
  (won or lost by how much, both scores), then what it means (finals, the
  ladder, who is next), "How it went" (up to three reasons from the result: a
  run of unanswered goals, a quarter that swung it, the stoppages, territory
  read against the result, kicking, pressure), the best players - three of
  yours and their best - with their game in a few words and their rating,
  three key team numbers and your week (injuries, and how many players
  improved - who and how is in Training, the one place the weekly training
  result is spelled out). Full time is one review with three tabs and one
  way out (Continue): Summary is home; Stats has the quarter table, every
  team stat, every player of both clubs (a tab per club, sorted by rating or
  any column, a tap for the rest of his line) and what your calls were
  worth; Report has the assistant's half-time report at a glance, with the
  full report opening in place. Back on Stats or Report returns to Summary.
- **Player rating** (`MatchNotes.rating`). One whole number for one match on
  a fantasy-style scale - an ordinary game 50-80, a strong one 80-105, best on
  ground 110 and up, a freak game 150+ - built only from that match's box
  score (never OVR, value or potential). Points: kick 2, handball 1, mark 3,
  tackle 3, goal 14, behind 1, hit-out 3, inside 50 1, forward-50 delivery
  (the engine's `goal_assists`, credited on every entry) 3, rebound 50 3, one
  percenter 1, clanger -2, free against -1 more (a free against is always
  also a clanger, so -3 in all); floored at 0. Not AFL Fantasy's weights on
  purpose: the engine gives forwards about 9 touches a game and rucks about a
  third of real hit-outs, so with fantasy weights forwards were a side's best
  player 1 time in 200. Tuned over 400 simulated matches (17,600 player
  games): median 70, 90th percentile 111, 99th 143; each position's 90th
  percentile sits at 101-118, and a side's best player is a midfielder about
  half the time, a defender 30%, a forward 14%, a ruck 6%. A clearance earns
  nothing extra (it is always followed by the disposal it produces).
- **Sim round.** Simming skips watching, not the aftermath. The round popup
  leads with your match (won or lost by how much, both scores, your best
  player and rating, a new injury, the ladder move and next opponent) and a
  "Review match" button; the rest of the round sits underneath. Review opens
  the same full-time review (Summary, Stats, Report) as a watched match, from the
  result already played (`GameState.last_match`): nothing is simulated,
  applied or paid again. The hub keeps "Last match: ..." under your season
  line to reopen it, and the save keeps enough of that match (result, box
  scores, rosters, team stats, quarter snapshots, scoring events;
  `CareerSave.review_result`) to review it after a reload.

### Half-time assistant coach report
The assistant's report is one tap away at half time and at full time
(`scripts/sim/CoachReport.gd`, pure analysis, no RNG draws). It
names your three best and three quietest players, the same two groups for the
opposition, and the opposition's actual Q1/Q2 gameplans with their engine
effects — read from `MatchSim.tactics_history`, not inferred. `MatchSim`
also snapshots team and player totals after each quarter (`quarter_teams`), so
the report can show per-quarter opposition output (points, inside 50s, tackles,
clearances) and flag what a Q1→Q2 plan change produced. Best/worst uses the
same influence weighting as the full-time best-on-ground list; "quiet" is
ranked by actual-vs-expected influence for the player's rating, so a down star
surfaces ahead of a depth player having a par game. Team edges (clearances,
territory, pressure, ruck, errors, conversion) feed "What stands out": the
problems and strengths in the assistant's words, never the call to make. At
full time the report is rebuilt from the Q2 snapshot, including after Skip to
full time.

It opens at a glance (`CoachReport.glance`): the half-time score; "Match
read", the two clearest edges ("Fremantle lead the hit-outs, 31 to 9") and
their gameplan only if it changed or was not Balanced; your best two and up
to two who need a lift (only a genuinely quiet half, 4+ below expectation),
each with his game in words; their two most dangerous; and up to three
second-half notes in plain words (no numbers, nothing Match read or the
player sections already say). Everything above - plans by quarter, the team
table, shot conversion, every best and quiet player with his numbers and
"vs par" - is behind "Full report"; Back steps out one level at a time.

---

## 4. Game structure

* **Draft** — all 18 clubs start empty and share a random snake order, one
  player pool and one salary cap. Every list has the same target size:
  `min(44, floor(pool_size / club_count))`, currently **37**. The human selects
  on their turns; rivals select between turns. Coverage needs and cap pressure
  make the draft a decision rather than a queue. Only two rucks are mandatory.
  `Draft.pick_history` records successful selections in sequence (overall pick,
  round, destination club, player ID/name, original club, role, rating, cost).
  Failed selections never create a record. Player ownership comes from this
  log, **not** the player's original `club` field. History lives in GameState's
  draft instance, independent of UI rebuilds.
* **Season** — 24-round home-and-away fixture (each club meets every other at
  least once, plus return rounds balancing home games; an odd club count
  rotates a virtual BYE in the circle method), then the **wildcard finals**:
  top 10 advance; week 1 is WC1 7v10 and WC2 8v9; the winners reseed by
  original ladder position into the 7th and 8th seeds and meet 5th and 6th in
  the elimination finals while 1-4 play the qualifying finals; then SF → PF → GF.
* **Career records** — every player carries `p["career"]` (`Career.gd`),
  kept apart from `p["history"]` so potential never moves: `games` and `goals`
  (finals included), `stints` (`[club, first, last, games, goals]`, an
  unbroken run at one club: a season lost to injury does not split it, a
  spell elsewhere does), `through` (the last season counted) and `unknown`
  (`[from, to]` spans that could not be counted). Real players start with
  their AFL careers to 2025; draftees, generated and expansion players start
  at nothing. `GameState._close_season_awards` adds the season from the awards
  tally for every listed player, before free agency releases anyone, and
  `_start_next_season` repeats the call as a safety net; `through` makes a
  second call a no-op, so a reload around the close or the rollover never
  counts a season twice. A season is credited to the club he played his last
  game of it for (trades happen between seasons, so this is exact in
  practice). Career draftees get the same draft keys real players carry
  (`drafted_year`, `drafted_type`, and `drafted_pick` for a national pick;
  `draft_pick` / `draft_round` are kept), set after POT is fixed so POT is
  unchanged. Saves from before this record (`career_version` missing) load
  with each player's dataset career, and the seasons the save had already
  played are marked unknown rather than guessed; their totals show "—".
* **Coaching staff** (`Coaches.gd`, `data/coaches_2026.csv`) — six jobs at
  every club: senior coach, senior assistant, midfield & ruck, forwards,
  defence, development. At your club the senior coach is you; the other
  five are NPCs. Each coach is one record in `GameState.coaches[cid]` (cid,
  real/generic name, former_player_id, skills {teach, tactics, manage} 55-92,
  spec MID/RUCK/FWD/DEF/DEV or "" for the whole game, status club / free /
  away / out, club, job, free_from, stints, former_sc, note, origin, played).
  A club's staff is read from the records (club + job), never stored beside
  them, and records never carry the id + attr + role that CareerSave takes
  for a player. Skills show only as grades (Elite 86+, Strong 78+, Good 68+,
  Fair) and role fit (senior coach 45% tactics / 35% man-management / 20%
  teaching; senior assistant 35/35/30; line coaches 60% teaching / 25 / 15
  and -8 outside their line; development 70% teaching / 30%
  man-management, -3 for a line specialist, -6 for a whole-game coach).
  What they do on the field is in *Coaching effects* below.
  The seed is the Round 1 2026 world, built by `tools/build_coaches.py` from
  the research in `data/research/coaches_round1_2026.csv` (research only):
  103 real coaches in jobs, 5 generated where no real person defensibly
  fills the job (senior assistant at Brisbane, Gold Coast, Melbourne and
  West Coast; defence at Geelong), 35 outside a job (former senior coaches,
  the clubs' state-league senior coaches, one ruck coach per club), and 47
  researched people left out. Assignments follow each club's 2026
  announcements: a director of coaching takes the senior assistant job when
  the titled senior assistant also runs a line (Adelaide, Port Adelaide,
  Sydney); where two coaches share a line, the one whose brief covers
  structure, transition or ball movement is the senior assistant (Carlton,
  GWS, Richmond). Your club's real senior coach becomes free when your
  career starts. Coach aliases use their own first names (never a player's)
  with the shared surnames, in a fixed order, so a seeded coach has the same
  alias in every career; real-name mode shows the real person, and a
  generated coach keeps his alias. The seed is the researched Round 1 2026
  world, kept as the historical source; a career (from 2027) carries it
  forward by continuity - everyone stays where the research put them, a
  stint's first year is that 2026, your club's senior coach coached 2026 and
  makes way for you in 2027 - and claims no real 2027 appointment. The
  profile claims nothing before Round 1 2026. Staff screen: hub > Staff (your six jobs,
  then any club's).
* **The coaching market** (`CoachMarket.gd`, Coaching Phase 3) — the world
  moves once a season, at its close (`GameState._coaching_offseason`), in
  this order: coaches develop (the job's main skill +0-2, another +0-1,
  slower above 80, a mild decline from 60) and the population is shifted
  back to a 70 average; reputation moves (senior coaches with results,
  assistants with service); coaches retire (from 64, certainly by 70); AI
  senior coaches are judged against the same goal the board sets you, from
  where their list ranked preseason - two failed seasons (not counting a
  first season, not within three seasons of a flag) is the sack, at most
  five a year, and an expiring 2-4 season contract is renewed after a good
  year; then every vacancy is filled, senior jobs first, so a promotion's
  vacancy is filled after it. Employed coaches move only for a promotion
  (dev < line < senior assistant < senior coach), after two seasons in a
  role, and about half take a step up when offered below senior coach; a
  former senior coach out of work can take any job. Senior coach needs a
  former senior coach, a senior assistant of two seasons, a big-name
  outsider, or an exceptional line coach (never a development coach).
  Clubs rank candidates 45% role fit, 25% reputation, 10% experience at the
  level, 10% a natural next step (more for the club's own senior
  assistant), 5% a club link and 10% seeded chance, less a penalty for a
  senior coach sacked in the last three years; a coach is not rehired by a
  club that sacked or released him within five years. An outside senior
  coach replaces the senior assistant half the time. Out-of-work coaches
  leave after four seasons (the notable - ever a senior coach, a seeded
  coach, ever at your club, or eight seasons coaching - go to
  `coach_archive`), and generated state-league coaches (32-48, new to AFL
  coaching with the same starting skills as a former player) top the market
  up - fewer as former players come through the pathways, never below 20. Expansion clubs hire all six jobs the
  offseason before their first season. Your club: at most two assistants
  poached a year (promotions only); open jobs wait in `staff_vacancies`
  with a shortlist of four on the Staff screen (Appoint, or Auto-fill with
  the AI's own pick), you can release assistants in the offseason, and
  anything still open is auto-filled when the next season starts. 50-season
  probe (synthetic results, before Phase 4): 3.3 senior coach changes a
  season, 33% of them internal, 1.4 sackings, Elite 3.9% of skills, no job
  ever unfilled, nobody moving more than twice in three years.
* **Coaching effects** (`CoachEffects.gd`, Coaching Phase 5) - three small,
  capped modifiers read straight from the coach records (nothing saved). A
  skill counts from a Good coach (70): level = (skill - 70) / 20, -0.75..1.
  **Teaching** scales a player's match XP (the one place it is paid,
  `_grant_xp`, your club and the rivals alike): 6% x his line coach's fit
  for the job (midfield & ruck for mids and rucks), 5% x the development
  coach's fit for a player 22 or under or not on the ground (2% otherwise),
  2% x the senior assistant's teaching; the total is capped at -5%..+10%, and
  the reserves keep their half rate. **Tactics** is the club's tactical brain
  (senior coach 60% / senior assistant 40%; your assistant at your club, as
  the calls are yours): a game plan's effects, costs included, are executed
  at 1 +/- 15% x level, and an AI club reading the match reacts to a margin
  of 18 - 8 x level points, counters your plan after one quarter (level 0.4+)
  or two, never if poor, and tags from half time if sharp. AI clubs now pick
  their plan each quarter in every match (they did only in the one you
  watch); with no plan in play tactics change nothing. **Man-management**
  spares part of the morale a fit player loses when left out (and a promised
  game not given): up to 40% at elite (senior assistant 60%, his line coach
  40%), nothing from a poor man-manager - it never makes anyone unhappier.
* **Former players become coaches** (`CoachPathway.gd`, Coaching Phase 4) -
  when a playing career ends (retired at the rollover, or delisted and not
  picked up in free agency) the player is captured before he leaves the
  lists: a compact `played` snapshot (games, goals, club stints, draft, listed
  position, retirement year, in-save Brownlows and Colemans) and nothing
  else - no ratings, contract, training, injuries or stat tables. One roll,
  seeded by the career and his id, decides once whether he coaches: 19%, 22%
  from 150 games, 25% from 250, a point per major award, capped at 30% (this
  game's endings are mostly long-serving veterans, about 19 a season). If he
  does he becomes `C_P_<player id>` with his real name and exactly his
  fictional alias, spends one to three seasons in the pathways (out of sight,
  a season longer when the market is flooded) and then joins the ordinary
  market. Fame is not coaching ability: his skills come from his coach id
  (52-72, most near 62), independent of his playing career; his playing name
  lifts his starting reputation and washes out over his first nine seasons
  coaching; clubs he played for rate him a little higher (half of the 5% club
  link). Specialty is his playing line, a development specialist about one in
  five, now and then a whole-game coach from a 200-game career. Former-player
  coaches are archived with their playing career after three seasons
  coaching, a 200-game career, or 100 games for your club. The coach profile
  shows the playing career, then the coaching career. News: a notable former
  player (150+ games, or one of yours) joining the coaching ranks, and his
  first appointment ("who played 241 games for Adelaide"). 50-season probe
  at the measured career-end volume: 23% of endings go into coaching, a third
  of those are hired (almost all first as development coaches), 91% of them
  reach a line job, 44% senior assistant, 25% senior coach; former players
  hold 38% of jobs and a third of new appointments after twenty seasons;
  games played and starting skill correlate at 0.03. A real 32-season
  career (actual results, retirements and clubs) goes further: 615 careers
  ended, 23% went into coaching, and by 2058 former players held 102 of the
  119 jobs (86%), with several reaching senior coach by the usual path
  (development, line, senior assistant). The real career is the evidence to
  trust; if the share keeps climbing, the coaching rate is the lever.
* **Team form** — each club's form (-1..1) is derived from its results this
  season (`Season.club_results`, so it is never saved separately and resets
  at every rollover): the last five, weighted 0.30 / 0.25 / 0.20 / 0.15 / 0.10
  from the most recent (`ClubLife.FORM_WEIGHTS`), win +1, loss -1, draw 0.
  Five straight wins is the cap; one loss after it is +0.40, two -0.10.
  `Season.simulate` and the interactive match set `Squad.form`, and MatchSim
  uses it in exactly two places: the clanger rate (x `1 - 0.05 f`,
  `FORM_COMPOSURE`) and the stoppage-win chance (`+0.010 (f0 - f1)`,
  `FORM_CONTEST`; the home-ground edge is 0.030). Neither draws from the RNG,
  and form 0 leaves the engine exactly as it was, so calibration (which never
  sets form) and the Python harness (which has no form) are unchanged. The
  coach report credits it as "team form". Mirror matches (2,000 each): Hot v
  Steady wins 52.5% (neutral 49.4%), Cold v Steady 46.6%, Hot v Cold 57.4%;
  the home ground alone is 60.5%. Over 32 paired seasons (16 real-list, 16
  drafted) it widened the season-wins SD by 0.19 (3.52 to 3.71) with no rise
  in premiership concentration or long streaks.
* **Expansion** — clubs carry an `enter` year in `data/clubs.csv`; every
  fixture, ladder, draft, selection and finals path iterates
  `GameDB.active_clubs(year)` rather than the all-time club list, so a new club
  (Tasmania 2028, Canberra 2030) is inactive before its year and fully active
  from it. Its debut list is generated at the rollover into its first season
  (`Prospects.generate_expansion_list`), aged and renormalised like any other.
* **List management** — the Best 22 screen draws the selected 18 on an oval in
  match-day shape (full back through full forward) with the four interchange
  players in a bay underneath. Tap a guernsey for the rating.
* **Training** — after every game, every player on your list gains XP. Named
  players and strong games earn more (a full senior game is 37 XP: squad 4 +
  selected 6 + on the ground 3 + performance up to 24, and most senior
  players hit the cap). A fit player left out of the 22 plays in the
  reserves in the background and earns `RESERVES_XP_SHARE` (0.5) of a full
  senior game, 19 XP. There is no reserves match, fixture, stats or
  selection. Injured and rested/suspended players (`Ratings.available`) get
  only the squad share of 4. Every club is paid on the same scale; your
  club's figures are scaled by the difficulty's XP multiplier.
  **Plans** (`GameState.TRAIN_PLANS`) spend that XP after every game, and
  each is a kind of footballer, not a stat recipe:
  - *Position plan* (default; rival clubs use it too) trains the role core
    OVR is built from, `Ratings.ROLE_WEIGHTS`.
  - Archetypes, offered only to players of that role (or second role):
    Inside midfielder (contested, disposal), Wing (carry,
    disposal, creating), Key defender (intercept, pressure), Rebounding
    defender (carry, intercept), Key forward (marking, goalkicking,
    accuracy), Small forward (goalkicking, accuracy, carry, creating - never
    marking, so he can stay a Crumber), Ruck (ruck, contested). A
    dual-role player gets both roles' archetypes; his Position plan trains
    his first role and the picker says which ("Position plan (ruck)").
  - *Manual* pauses development: XP banks until spent by hand.
  Every plan attribute must be in the role's core or behind a trait the
  role can earn (`GameState.stat_useful_for_role`; tested). The old Star
  power plan and the single-stat focuses are gone (saves
  fall back to Position plan), as is the club-wide plan picker (a club plan
  could train forwards' skills into defenders). A point costs
  `TRAIN_COST_SCALE` (1.25) × the base price, so now that no XP is wasted a
  season's development stays where it was.
  The Training list shows each player's OVR, focus and development state
  ("Developing", "Near his ceiling", "At his ceiling");
  the player view leads with his development focus and what it means on the
  field, with stats and hand training behind one button. After a game the
  results say what training changed (OVR rises, traits unlocked, potential
  reached), not how many stat points were bought.
* **National draft (end of season)** — `GameState.begin_intake_draft()`.
  Father-son/NGA prospects (`tied_club` in the CSV) land at their clubs first;
  the open pool is then drafted over `ceil(pool/18)` snake rounds (max 4) in
  **reversed-ladder order**, worst club first, and the draft simply ends when
  the pool runs dry — the last clubs' spare turns never happen, mirroring the
  real draft's final partial rounds. It is the same `Draft` object in
  `intake_mode`: the salary cap is a formality (rookie contracts), the two-ruck
  rule does not re-apply to an intake, and a club at the 44-man cap has its
  turn skipped rather than stalling the board. Rival AI picks between your
  turns exactly like the career draft, and the shared DraftScene shows the
  recruiting-club filter, projected OVR tooltips and scouting notes.
* **Inspecting a player before a pick** — on both draft boards, tapping a
  player (or a pick in the history) opens his details; only the Draft / Sign
  button at the foot of them, or the row's own draft button, picks him.
  The details are read-only (`scripts/sim/PlayerProfile.gd`): OVR (projected
  for prospects) and POT with a development word, cap cost or rookie
  contract, his type (the Training archetype his attributes fit best), up to
  three strengths graded Elite / Strong / Good against 2026 players of his
  role - only attributes carrying at least 10% of the role's OVR core
  (`Ratings.ROLE_WEIGHTS`) count - one weakness if he is in the bottom
  quarter of his role at something that matters, his traits explained, and
  a few per-game numbers from his real season (or his U18 / state-league
  season, ranking, pathway and scouting note for a prospect). The full
  ratings sit behind a button. `Draft.pick_block_reason` says why a player
  cannot be picked (taken, not your turn, cap, two-ruck rule, list full).
  Back closes the details before leaving the draft.
* **Rollover** — `finish_intake_draft()` merges each club's intakes into its
  list (rookie jumper numbers assigned from 41 up), ages every player by a
  year, applies the development bands (young grow, old decline), retires the
  oldest/lowest-rated (floor: 32 per club), adds the next year's generated
  intake class (`Prospects.generate_class`), and builds a fresh 24-round
  season. `GameDB.reload()` on career reset restores the pristine starting data
  because mid-career mutations are in place. Undrafted prospects carry into
  next year's pool and age out at 22.

---

## 5. Platform

Godot 4.7, `mobile` renderer, `canvas_items` stretch with `expand` aspect and
unrestricted sensor orientation (`DisplayServer.SCREEN_SENSOR`, value 6).
`ScreenLayout` updates the logical viewport from the actual window size and
pixel density on resize; it never scales a desktop-width canvas down to a
portrait phone. The hub is one scrolling page led by this week - the
opponent, at most three facts about them (Matchup: their lines ranked against
the league, their danger man, a key player missing, a run of results), your
own injured stars, any week event, then Pick the side / Play match - with your
season, the news and the full ladder below at natural height. After a round
the results say where you now sit and who is next.
The draft, hub, ladder, list, match and season review apply OS
safe-area insets. Touch/mouse emulation works both ways. Phone layouts stack
cards and drop ladder columns rather than forcing a desktop min-width. Scores
and club names use non-wrapping labels, so a tight row cannot collapse into a
column of single letters. Match overlays are added to the tree before their
anchors are set, and the dialog is capped to the viewport and scrolled, so the
full-time card covers the speed controls. Skip to full time rolls any quarters
that have not been simulated, using the last coach-box plan, then drains the
event log. Rotating the match reflows the oval and the feed without rebuilding
the pitch.

The draft workspace uses portrait tabs or side-by-side panels at ≥760 UI units
when wider than tall. Below 680 UI units high, it compacts its header and scrolls
filters inside the panels, so expanded controls cannot push the footer off
screen. A breakpoint rebuild only replaces view nodes: picks, history, filters,
search text/caret, active tabs and scroll offsets are retained. Player/log rows
are paginated in batches of 60, with access to the entire pool and history.
The pool's position row does two jobs: a compact All, then one card per
position with your count and what you still need; tapping a card filters the
pool (again, or All, shows everyone). There is no second position row above it.
The main actions, tabs and position counters have ≥44 UI-unit touch targets.

The shared kit uses dark green panels, warm off-white text, terracotta actions,
position-specific colours and bundled Barlow typography. Keyboard focus remains
visible and labels distinguish needs from covered positions without relying
on colour alone.

UI is built **programmatically in GDScript** rather than in `.tscn` files. It
keeps the checked-in scene count tiny, avoids fragile hand-edited scene text,
and makes responsive layout straightforward.

---

## 6. Repository layout

```
project.godot          Godot 4.7 project (PC + mobile), four autoloads
icon.svg
data/
  players_2026.csv     real 2026 player season stats - 669 players, 18 clubs
  draftees_2026.csv    the 2026 national-draft class - 56 projected prospects
  clubs.csv            clubs, guernsey colours, home grounds
  *.csv.import         pins Godot's csv importer to "Keep File"
scripts/
  core/
    GameDB.gd          autoload; loads both CSVs, derives ratings, indexes by club
    Router.gd          autoload; scene stack with go / back / replace
    ScreenLayout.gd    autoload; logical viewport density and safe-area insets
  sim/
    Ratings.gd         season stats -> 13 attributes, role, overall, salary value
    Squad.gd           44-player list -> best 18 + bench -> team strengths
    MatchSim.gd        the match engine, plus the event log the oval replays
    CoachReport.gd     half-time assistant report (form + opposition gameplans)
    Matchup.gd         this week's opponent in 2-3 football facts, from the engine's sides
    Season.gd          24-round fixture, ladder, finals bracket
    Draft.gd           salary cap, board filters, the 17 AI lists, intake mode
    Prospects.gd       rank projections, season ageing, generated intake classes
  state/
    GameState.gd       autoload; the season you are playing
  ui/
    UiKit.gd           shared widgets and layout helpers
    PitchView.gd       the animated oval (pure _draw(), no textures) + camera
    match/MatchDirector.gd  reads the event log into visual beats (docs/MATCH_VIEW.md)
    match/MatchMotion.gd    player steering: acceleration, braking, reaction delay
    Main.gd            menu
    DraftScene.gd      club selection + draft board
    HubScene.gd        the week: opponent + facts, your side's news, the match; then ladder
    MatchScene.gd      scoreboard, oval, match feed, quarter breaks, full time, Match stats (PlayerStatsTable)
    LadderScene.gd     full ladder + finals bracket
    ListScene.gd       your list, best 22, attributes, real season numbers
    SeasonReviewScene.gd  the flag, your record, final ladder, awards, club achievements
scenes/                seven thin .tscn wrappers - a root Control + its script
tools/
  sim_harness.py       calibration harness (run this after any engine change)
  intake_harness.py    projection/intake/rollover harness + draft-class CSV checks
  scrape_afltables.py  re-harvests the dataset, with the <6-game 2025 fallback
  validate_data.py     checks 220 club x column aggregates vs published totals
  visual/capture_match.gd  renders match-view frames and movement trails (review)
```

## 7. Status

| Area | State |
|---|---|
| Real 2026 dataset | Done — 669 players, all 18 clubs, 220/220 aggregate checks pass |
| Ratings model | Done, validated against the Brownlow order |
| Match engine | Done — disposals on the 2026 total; behinds and rebound 50s a little low |
| Godot port of engine | Done — `scripts/sim/`, same RNG call order as the harness |
| Draft / season / ladder / finals | Done — `Draft.gd`, `Season.gd`, `GameState.gd` |
| 2026 draft class + end-of-season intake | Done — `data/draftees_2026.csv`, `Prospects.gd`, `Draft` intake mode, career rollover |
| Animated oval + UI | Done — all seven screens build their trees in code |

### Note on testing

The draft UI and model were exercised in Godot 4.7.2's actual web renderer, not
an HTML recreation. Regression scripts under `tests/` check every logged
selection, snake order, ownership, cap/list invariants, position needs, all four
draft tabs and rotation across ten viewports. Browser touch tests additionally
cover signing, filters, resume and the season handoff. Native mobile sensor
rotation, software keyboards and notches still require device checks; see
`tests/README.md`.
