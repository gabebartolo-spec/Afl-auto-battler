# Competitive balance (2026-10-04)

The phone playtest (ROADMAP 9.1) won three premierships in a row while barely
touching training or list management. The first pass (§1-6) asked **why**
before changing any number, then fixed the one cause the evidence pinned
down. The second pass (§7-12) measured an actively managed career against
autopilot, as the playtest item asks, and made the changes the director chose
from that evidence. Everything below was measured through the shipped code.

## Verdict

| Suspect | Verdict | Evidence |
|---|---|---|
| A systemic edge for being the user club | **Found and fixed: morale.** Only your players' morale ever moved, and it moves match form. | [1](#1-morale-a-free-edge-in-every-match-for-your-club-only-fixed) |
| AI clubs out-coach a passive human | Real, by design: rivals use every match-day lever, a passive human uses none. It hid the morale edge in autopilot careers. | [2](#2-match-day-coaching) |
| Neglecting the list costs too little | **Confirmed; changed in the second pass.** A passive club kept its whole list on rolled-over deals and stayed under the cap. Now an unsettled starter tests the market and weekly cards give nothing for free: an autopilot list slides from 9th to 16th strongest in five seasons. | [3](#3-what-neglecting-the-list-costs), [9](#9-contracts-changed) |
| AI drafting is age-blind | **True, partly exploitable, not a dynasty on its own.** Drafting with age in mind builds the strongest opening list, which fades within three or four seasons without list management. Not changed here. | [4](#4-ai-drafting-and-age) |
| List Profile "Elite" too easy | **Contradicted as a cause.** It is a rank (Elite: the top four of eighteen). Four Elite words and two Strong is a 0.6%-of-seasons profile: the playtest list was genuinely dominant. | [5](#5-what-the-code-contradicts) |
| Synergies pile up | **Not reproduced league-wide.** About 1.4 of 6 per club, flat over five seasons. | [5](#5-what-the-code-contradicts) |
| Training, fatigue, development, ageing favour you | **Contradicted.** One rule set for every club; the small user-only extras are listed. | [5](#5-what-the-code-contradicts) |
| An age-28, 89-POT generated player | **Explained and fixed:** expansion lists gave every age a draft prospect's ceiling; a generated player past draft age now gets the ceiling a listed player of his age has. | [6](#6-generated-players-expansion-lists) |
| Trades buy flags | **Confirmed and changed.** Only you could buy a rebuilding club's starters, and a contract-value bug skewed every price; contending rivals now compete for them. | [7](#7-active-management-against-autopilot), [11](#11-trades-changed) |
| You out-draft the rivals | **Confirmed and reduced.** Rival scouting error 0-4 (was 1-5): a top-four opening list in 9 of 40 careers, down from 19. | [10](#10-opening-draft-what-rivals-know-changed) |
| A passive coach concedes the routine calls | **Changed.** Your assistant makes them by the rivals' rules; worth nothing either way. | [12](#12-match-day-your-assistant-changed) |

## Tooling

| File | Role |
|---|---|
| `tools/balance/dynasty.gd` | Library. A whole career through the shipped code: the career draft (your picks by policy), `GameState.advance()` through every round and final, the off-season (rivals' contracts, trades and free agency; your club on autopilot, or managed with `manage`), the National Draft (your picks as a rival would make them) and the rollover. Records every club's preseason strength, ladder, List Profile words, synergies, ages, payroll and morale. |
| `tools/balance/dynasty_run.gd` | CLI: seeded careers to JSON (`--manage none\|list\|full`). |
| `tools/balance/dynasty_report.py` | Report: your club and the league by season, ladder against list, premierships by preseason strength rank, repeat premiers; `--compare` sets runs side by side. |
| `tools/balance/match_ab.gd` | Paired match probe: your matches against every rival on the same seeds under two or more settings of one thing (morale, match-day coaching, or moment cards), so the difference is that thing alone. |

```sh
godot --headless --path . --script tools/balance/dynasty_run.gd -- \
    --seeds 301,302,303,304,305,306,307,308 --policy upside --seasons 5 [--coach] \
    [--manage list] --out run.json
python3 tools/balance/dynasty_report.py run.json
python3 tools/balance/dynasty_report.py --compare none.json list.json full.json
godot --headless --path . --script tools/balance/match_ab.gd -- --mode morale --seed 301 --reps 10
```

**Your club in a career** is on autopilot: default training plans, the
auto-selected side, no trades, no free agents, no contract talks. That is the
playtest's "barely engaging" career. Draft policies:

- `board`: a seeded pick among the five best-rated legal players (a human who
  drafts for this season);
- `ai`: your picks made by the rival AI (without its scouting error);
- `upside`: a seeded pick among the five legal players with the best expected
  rating over this season and the next two, from the game's own development
  bands (a human who drafts for the next three years).

`--coach` adds match-day engagement: your match is played through the live
path with your side coached the way MatchSim coaches a rival club (a loose
interceptor from the first bounce, a plan each quarter from the score and
what it has seen, match-ups re-set at the breaks; moment cards take their
default call). Engaged with matches, not with the list.

`--manage` works the list every off-season as an attentive human would, by
simple stated rules on what the screens show (§7): `list` settles contracts
and chases free agents, `full` also trades up.

**Reproducible.** A career replays exactly from its draft seed: the harness
sets `GameState.replay_seed`, which seeds every new draft and season that
the game otherwise seeds from the clock, and the career seed that picks each
generated class. The first-pass runs and §7 predate this: a career varied
run to run (even its first season, whose first weekly card was drawn under
the clock), so read them over many seeds, never one.

## 1. Morale: a free edge in every match, for your club only (fixed)

**The rule** (`ClubLife.morale_after_match`): after a match, everyone who
played gains morale, +4 after a win and +1 after a loss; a fit player left out
loses 3 (a star 6), softened by the man-managers. Nothing pulls it back toward
settled, and it carries over between seasons.

**The effect** (`MatchSim.fit`): morale adds up to ±0.03 to every effective
attribute of a player on the ground: +3% at 100, nothing at the settled 70.

**The asymmetry.** The rule ran only for your club
(`GameState._board_after_round`). Every rival player stayed at 70 for ever, so
your regulars climbed into the 85-100 band within weeks and stayed there,
season after season, whatever you did. ROADMAP 1.4 names form and morale
among the effects that must follow the same rule for every club.

**How big** (`match_ab.gd --mode morale`, seed 301: your matches against all
17 rivals, ten each, home and away alternating, identical seeds):

| Your side's morale | Mean margin | Win share |
|---|---|---|
| 70 (settled, as every rival) | +1.7 | 53.2% |
| 85 | +5.8 | 55.9% |
| 100 | +9.3 | 59.7% |

About 7.6 points a match: a home-ground advantage in every game. (The
System Reality Audit measured +2.4 ± 1.5 for a whole side at 100 on an
older engine.)

**Fix.** `GameState._rival_morale_after_round`: every rival club's players
take each week by the same rule as yours, softened by that club's own
man-managers. Your club's handling is unchanged. Regression check in the
`club` suite: after a round, every rival player who played moved by exactly
+4 or +1 and every fit rival left out lost morale.

Selected-side morale in a five-season career (seed 301, engaged coach),
preseason → season's end:

| Season | Yours, before | Rivals, before | Yours, after | Rivals, after |
|---|---|---|---|---|
| 1 | 70 → 100 | 70 → 70 | 70 → 100 | 70 → 91 |
| 2 | 97 → 94 | 70 → 70 | 97 → 92 | 89 → 90 |
| 3 | 97 → 97 | 70 → 70 | 99 → 95 | 93 → 90 |
| 4 | 95 → 99 | 70 → 70 | 97 → 98 | 91 → 88 |
| 5 | 95 → 92 | 70 → 70 | 95 → 83 | 91 → 88 |

Because playing always lifts morale and nothing pulls it back, a settled
side now sits near the top at every club: the effect cancels between clubs
and still bites on players left out. Whether morale should drift back
toward settled, so it reflects recent form rather than selection alone, is
a design question for later, not a balance fix.

## 2. Match-day coaching

Rival clubs coach every match: a loose interceptor from the first bounce, a
game plan picked each quarter from the score and what they have seen, and
match-ups re-set at the breaks. You have the same levers (the plan, the coach
box, match-ups) but only if you use them: a simulated week plays the plan
and match-ups you saved (Balanced and none by default) and never adjusts
them during the match.

`match_ab.gd --mode coach`, seed 301, both at morale 70:

| Your side | Mean margin | Win share |
|---|---|---|
| Balanced, no match-ups (a passive human) | +1.7 | 53.2% |
| Coached as a rival club is coached | +8.1 | 58.2% |

A live match also gives your side moment cards that rival sides never get.
Played on their default calls they carry no measurable edge
(`match_ab.gd --mode moments`, seeds 301-303, 850 matches each way: +0.1
points a match): every default but the set shot is "no change", and the set
shot's chance is the one the engine would have used.

This is not a parity bug: the AI uses levers the human also has. But it
explains why autopilot careers barely showed the morale edge: autopilot gave
away about 6.4 points of coaching and got about 7.6 back from morale. A human
who coaches kept the whole morale edge. After the fix a passive human concedes
the coaching gap in full; the roadmap's P1 item to handle routine match-ups
automatically would close part of it legitimately.

## 3. What neglecting the list costs

A passive club decides nothing in the off-season, and an undecided expiring
player is re-signed for two seasons at his asking price whenever the cap has
room (`GameState._close_free_agency`). Rivals delist roughly the bottom half
of their expiring players every year (`Contracts.ai_release_reason`).

| Autopilot career (7 seeds each, 5 seasons) | Strength rank, season 1 → 5 | Ladder, season 1 → 5 | Premierships | Best-22 age, season 1 | Payroll / cap, season 1 → 5 |
|---|---|---|---|---|---|
| `board` (drafted for now: an old list) | 9.4 → 18.4 | 7.0 → 14.1 | 0 of 35 | 28.9 | 0.95 → 0.81 |
| `ai` (a typically aged list) | 7.4 → 6.1 | 11.1 → 5.9 | 4 of 35 | 27.5 | 0.88 → 0.93 |

Means over seeds 301-307; rank and ladder among 18 to 20 clubs (expansion
clubs join from 2028). Rivals' payroll sits at 0.87-0.92 of the cap.

An old list fades without management, as it should. A typically aged list
does not: it holds its rank for five seasons while the passive club never
loses a player to the cap. Rivals' yearly churn refreshes their depth but does
not lift their best 22 past a club that churns nothing. That is the
playtest's complaint in the code: the management layer exerts little pressure.
It is a design question, not a constant to tune (see What remains).

## 4. AI drafting and age

The rival AI's career-draft worth is 75% OVR and 25% POT with no age term
(`Draft._worth`): a 31-year-old rated 80 is worth about what a 23-year-old
rated 80 with POT 86 is. The National Draft uses scouted worth with 65% POT
over a pool of teenagers, where age barely varies.

Does drafting for age beat it? The `upside` drafter (autopilot list, before
the morale fix; seeds 301-305):

| Season | Strength rank | Best-22 rating vs league mean | Best-22 age (league) |
|---|---|---|---|
| 1 | 5.0 | +1.5 | 25.2 (27.1) |
| 2 | 5.4 | +1.9 | 25.4 (26.5) |
| 3 | 7.6 | +1.0 | 25.9 (26.4) |
| 4 | 10.8 | +0.2 | 26.4 (26.0) |
| 5 | 13.6 | -1.2 | 26.7 (25.9) |

Drafting with age in mind builds the strongest opening list of the three
policies (rank 5.0, against 7.4 for the rival AI's own logic and 9.4 for the
naive drafter): the age-blind rivals leave good young players on the board.
But it is not a dynasty on its own. Four of the five lists had faded by
season 5 (ranks 19, 18, 18 and 11; the fifth held at 2) as the rivals'
churn and drafting made the league younger around a list nobody managed.
The edge lasts about as long as the playtest's run of three flags. Rival
draft valuation is not changed
here: out-drafting the AI on public information is a decision the player
makes, and the edge fades without list management. An age term in the
rivals' career-draft worth belongs to the drafting pass, with the scouting
question under Also noted.

## 5. What the code contradicts

- **List Profile.** `ListProfile.gd` ranks each dimension across the league:
  Elite is a share under 17% (the top four of eighteen clubs), Strong the
  next band; there is no rating threshold to inflate. Across 1,632
  club-seasons of the autopilot careers, four or more Elite words came up in
  2.2% of them, and even the season's strongest list reached four only about
  one season in seven. The playtest's profile (four Elite, two Strong)
  appears in 0.6% of club-seasons: a genuinely dominant side, not a lenient
  band. Whether Elite should mean the top three, or two, is a one-constant
  wording choice (`ELITE`); make it after re-measuring dominance on a played
  save without the morale edge.
- **Synergies.** Six exist. Across the autopilot careers a club's selected 18
  switches on about 1.4 of them, flat across five seasons (1.52 → 1.36 and
  1.42 → 1.43 in the two policies), and four or more in about 1% of
  club-seasons. Nothing inflates league-wide. Whether a deliberately built
  list unlocks too many is the separate synergy design item.
- **Training and development.** Your plans and the rivals' spend through the
  same `_spend_with_weights`, capped at POT and at the season's start rating
  plus 3; the default Position plan is exactly the rivals' weighting, so
  ignoring training costs nothing - and gains nothing. Measured: in season 1
  your list and the rivals' each gain about 2.9 points of rating in-season
  through training; later the passive list gains less (about 1-1.5 by
  season 5 against the rivals' 1.8) because it ages while the rivals renew.
  Off-season development and decline (`Prospects.age_player`,
  `Potential.growth`) use one table for every club, and
  `Prospects.renormalise_league` re-anchors the league to the 2026 baseline
  every year, club-blind. User-only extras: the development
  budget (zero-sum, neutral at Standard) and weekly-card XP (+8 for the
  default closed session, +12 heavy week, +26 development week), which only
  reaches the same season cap sooner.
- **Fatigue.** `Workload.advance_week` is one rule for every club; your
  recovery budget is neutral at Standard. The rival auto-pick rests tired
  players; a selection you saved yourself keeps its players in until you
  change it. That, not hidden protection, is why your side can look more
  tired. The weekly cards add your-club-only heavy legs or fresh legs.
- **League strength.** Preseason strength spread stays between about 2 and
  3.4 points (standard deviation) across five seasons with no trend; the
  strongest list wins about one premiership in five and strong sides repeat
  (year-to-year strength-rank correlation 0.79), so dynasties remain
  possible.

## 6. Generated players (expansion lists)

`Prospects.generate_expansion_list` draws ages 18 to 30 (a fifth aged 27-30)
and projected every player as a draft prospect (`Prospects.project`), so each
got a draftee's ceiling (`Potential._draftee_potential`: rating plus 13-22 by
list rank) whatever his age. That is the age-28, 89-POT player, and
`Potential.growth` kept pulling him toward it until he turned 28.

**Fix.** From age 20 (draft classes are 18 and 19) a generated expansion
player takes the rule every listed AFL player already has: his rating plus
the room his age leaves (`Potential.AGE_HEADROOM`), with the usual roll.
Youngsters keep a prospect's ceiling. New expansion lists only: a saved
career keeps the ceilings its players were given, as POT never moves once
set. Regression check in the `expansion` suite.

Expansion lists for two clubs in 2028 and 2030 (288 players):

| Age at entry | Players | Room above rating, before → after | POT 85+, before → after |
|---|---|---|---|
| 17-20 | 125 | 17.5 → 16.0 | 41 → 28 |
| 21-23 | 62 | 17.1 → 9.8 | 20 → 0 |
| 24-26 | 66 | 17.4 → 3.9 | 23 → 0 |
| 27-30 | 35 | 17.4 → 1.5 | 12 → 0 |

Still open (the P0 provenance item): a generated veteran's history says he
came out of the under-18s in the expansion year.

## 7. Active management against autopilot

The playtest item asks for exactly this measurement. The managed club follows
stated rules on what the screens show (age, rating, POT, as its expected
rating next season), through the same GameState calls the screens make
(`dynasty.gd`, `_manage`):

- **Contracts:** keep an expiring player who will be in next season's best 26,
  or a kid (22 or under) with six points or more to grow, at his asking price
  over the term he asks for; let the rest go.
- **Free agency:** bid for up to four players who would make next season's
  22: the term each asks for, 10% over his asking price and 5% over the best
  offer, a final offer 5% over the leader when outbid.
- **Trades** (`full` only): from each rival, the best player 30 or under who
  would walk into next season's side (3 points or more above its 22nd best).
  Open with the pick a contender misses least, ask what they would need (the
  trade screen's counter) and agree if it is spare: a pick, a player outside
  next season's 26 who is not a kid, or one starter at least 3 points worse
  than the target. At most two trades an off-season.

Same eight draft seeds (`upside` drafter, coached on match day), five seasons,
code as of `727e4eb` (after the first pass, before the second):

| 8 careers, 40 seasons each | Autopilot | Contracts + free agency | + trading up |
|---|---|---|---|
| Strength rank, season 1 → 5 | 6.8 → 10.9 | 6.8 → 5.8 | 6.8 → 3.4 |
| Best-22 rating vs league, season 5 | +0.2 | +2.3 | +2.8 |
| Mean ladder position | 7.7 | 6.5 | 6.0 |
| Top-four finishes | 11 | 18 | 20 |
| Premierships | 2 | 4 | 11 |
| ... after season 1 (of 32 seasons) | 0 | 2 | 9 |
| Back-to-back premierships | 0 | 0 | 3 |
| Payroll / cap, season 5 | 0.97 | 0.89 | 0.92 |
| Per off-season: re-signed, released, signed, traded | - | 8.4, 3.4, 1.3, 0 | 8.4, 3.1, 1.3, 0.6 |

Season 1 is the same list in every column (its two flags came from the
opening draft and match-day coaching). After it:

- **Management now matters.** The unmanaged list slides from 6th to 11th
  strongest and wins nothing in 32 seasons; settling contracts and chasing
  free agents keeps it near the top. That answers the playtest's question in
  the direction it wanted, after the first-pass morale fix.
- **Trades are the biggest lever.** Eighteen trades in 32 off-seasons gave
  nine flags and three back-to-backs. The typical deal was a rebuilding
  club's 87-91 rated 27-29-year-old for one of yours rated 78-84 in his
  mid-20s plus a late pick: WCE's 93/91 aged 26 for a third-round pick and a
  90/88 aged 25; Fremantle's 87/85 aged 28 for a third-round pick and a 79/78
  aged 26.

**Why trades bought flags** (a pricing probe after one season, seeds 301 and
306, `TradeValue` broken down per player):

1. **Only you bought starters.** Rival-to-rival trades only ever moved
   players outside the seller's starting side (`GameState._fringe`), so a
   rebuilding club's stars were on sale to you alone, never contested.
2. **A rebuilder prices by years left, not football now.** It weighs this
   season's football at 0.35 and the future at 1.0, and a player's future is
   his value times the share of a career he has left (all of it to 26, a
   seventh by 32). Adelaide
   (rebuilding) rated your 83/82 aged 25 at 3.58 and its own 87/85 aged 28
   at 2.91: it would have swapped them straight up. A contender gains four
   rating points in its side; the price is a slightly worse, slightly younger
   starter, not its future.
3. **A bug made it worse.** `TradeValue.contract_factor` still read the
   salary gap on the old 1-10 points scale, clamped to ±4: in dollars every
   contract was fully over- or under-paid, ±12% on a long deal (Adelaide's
   star counted 0.88, your player 1.04).

## 8. Weekly cards: nothing for free (changed)

An unanswered card used to take a default answer, and most defaults leaned
your way: a recovery week (morale +3, fresher legs, fewer injuries), a closed
session (+8 XP), the group lifting when a player was told to earn his spot.
After the morale fix they kept your selected side about seven morale points
above the rivals' (§1), and rivals face no such calls.

Now (director's call, "neutral defaults"; `ClubLife.pick_event`,
`GameState._settle_week_event`) an unanswered card changes nothing. Where not
acting has a natural consequence, that consequence stands: a sore star nobody
rests plays sore, a star's contract request waits for the off-season, the
board's patience thins after a losing run. Saying nothing about an
off-field incident costs board confidence (-4), and the card says so. Checks
in the `club` suite.

## 9. Contracts (changed)

**Early extension requests** (director's call, "rarer, stars only";
`ClubLife.extension_wanted`). Any player rated 72 or more and out of contract
at season's end could ask, each once a season. Now only a star (80 or more,
the line MatchSim calls a star) asks, and only one player a season; the
early-signing premium is unchanged. Measured over the first season of six
autopilot careers (seeds 301-306): 1.8 asks a season before (up to three),
0.7 after (never more than one).

**Your best 22 test the market** (director's call, "stars test the market";
`GameState._close_free_agency`, `_market_test`). An expiring player you never
settled used to re-sign for two seasons at his asking price whenever the cap
had room: a passive club never lost anyone. Now one of your best 22 left
unsigned tests free agency as it closes: your standing offer is his asking
price over the term he wants, rivals make theirs, and he takes the offer he
likes best (money, security, his role, how the club finished), as any free
agent does. Others still re-sign for two seasons when the cap allows. At the
list minimum nobody leaves (he re-signs, as a rival's player does). The
off-season screen says so. Checks in the `contracts` suite.

## 10. Opening draft: what rivals know (changed)

You see every established player's rating exactly; each rival drafts through
its own opinion, a zero-mean error whose size (SD) is drawn per club from
`Draft.AI_EVAL_SD_MIN`..`MAX` (1-5 rating points before this pass). The spread of scouting
sharpness is what separates rival lists (DRAFT_EVALUATION.md), and its size
is what you gain by simply taking the best player left. The director chose
to shrink it; the sizes measured (40 career drafts each, seeds 301-340, your
club's preseason strength rank of 18 and its best 22 against the league):

| Rival error SD | Best available (`board`) | With an eye on age (`upside`) |
|---|---|---|
| 1-5 (today) | rank 6.6, top four in 19; +2.1 | rank 6.4, top four in 19; +1.6 |
| 0-4 | rank 8.9, top four in 9; +1.6 | rank 8.4, top four in 13; +1.0 |
| 0.5-2.5 (half) | rank 10.1, top four in 6; +1.2 | rank 9.7, top four in 8; +0.7 |
| none | rank 13.0, top four in 1; +0.7 | rank 11.6, top four in 1; +0.1 |

(A club drafting exactly as the rivals do ranks about 8.6.) With no error the
rivals' need-based drafting beats taking the best player left.

The error also shapes the all-AI league, and the calibration targets
(DRAFT_EVALUATION.md) bound how far it can shrink (16 leagues x 3 seasons
each, `draft_experiment --mode season`):

| Rival error SD | Strength SD | Stronger side wins | Skill share | r(strength, wins) | Premier from top-3 strength |
|---|---|---|---|---|---|
| 1-5 (before) | 2.36 | 58.3% | 59.0% | 0.49 | 39.6% |
| **0-4 (now)** | **2.22** | **57.6%** | **53.4%** | **0.44** | **35.4%** |
| 0.5-2.5 (half) | 1.96 | 56.0% | 56.2% | 0.35 | 35.4% |
| Target | | 57-61% | 45-60% | 0.45-0.65 | about 40-60% |

The director first chose half the range; it took most of the edge away but
flattened the league below the targets (rival lists too alike, results
closer to coin flips). Asked again, the director chose **0-4**
(`Draft.AI_EVAL_SD_MIN` 0, `MAX` 4): some rivals now scout almost perfectly,
some still poorly, the edge from taking the best player left drops by about
two thirds (rank 6.6 to 8.9, top four in 9 of 40 careers instead of 19), and
the league stays within or at the edge of every target. A careful human
still out-drafts the rivals on average, and rivals still draft only on
what their own scouts think.

## 11. Trades (changed)

**Contract value fixed.** `TradeValue.contract_factor` reads the gap between
a player's pay and his market price on the market's 1-10 scale
(`Contracts.salary_score`, about $120k a point), as free agency and
compensation already do: a few thousand dollars either way counts for
nothing, $250k under on a three-year deal adds about 6%, and the ±12% cap
stays for the heaviest deals. Check in the `contracts` suite.

**Contenders can buy a rebuilder's starters** (director's call, "rivals buy
stars too"; `GameState._trade_pool`). A contending rival may now go after
anyone on a rebuilding club's list, as you can, at the off-season's trade
market, which opens before you act. Every other pairing still sees only the
players outside the seller's starting side. Nothing else changed: the buyer
bids from its own valuation, the seller takes a bid only if it values it
enough, a club does one deal at most and the league at most three. Checks in
the `contracts` suite: only a contender buying from a rebuilder takes a
starter, and the market still replays identically.

**How far a contender keeps asking** (director's call, "up to 15";
`GameState.TARGET_TRIES`). A buyer goes down its wish list, most valuable
first. With three asks the change did nothing: in six first off-seasons
(seeds 301-306) no rival bought a starter, because every contender's first
asks were the same young stars no rebuilder sells (Sydney's 94-rated
24-year-old in one league, Brisbane's 93-rated 24-year-old in another). A
search down the list (four first off-seasons, each contender's first deal):

| Asks | Off-seasons with a deal | What the deals looked like |
|---|---|---|
| 9-10 | 2 of 4 | an 87-rated 28-year-old for two first-round picks; an 83-rated 29-year-old for a first and a player |
| 11-15 | all 4 | add 89-rated 30-year-olds for a first and a player; an 81-rated 25-year-old and an 80-rated 28-year-old for two firsts each |
| 19-21 | - | 79-81 rated players, three of them for two firsts each |

With fifteen asks, the first off-season of six autopilot careers (seeds
301-306) brought 15 rival trades, 11 of them a contender buying a
rebuilding club's starter (none with three asks): Geelong, the Bulldogs,
St Kilda, Adelaide, Carlton, Richmond, Port Adelaide and Gold Coast each
paid two first-round picks, or a first-round pick and a player. Rival
contenders now spend their futures on the same stars you would, before
you can.

## 12. Match day: your assistant (changed)

Rival clubs pick a loose defender for every match and move a key defender a
forward has beaten; a passive coach made neither call (§2). Now (director's
calls: "assistant takes routine calls", "everywhere; yours always win")
your assistant makes them for your side by the same rules
(`MatchSim._assistant_calls`), in simulated rounds and live matches: a loose
defender from the first bounce, and at each break the next defender onto a
forward who won most of his contests. Anything you set yourself stays yours
for the match: your set-up before the bounce, a match-up you change, the
loose defender you pick (or no one). The coach box shows his set-up as your
starting point and says so. Checks in the `coach_effects` and `matchday`
suites.

What it is worth (`match_ab.gd --mode assistant`, your side on Balanced with
no match-ups set, with and without him; 170 matches each way per seed):

| Seed | Without | With |
|---|---|---|
| 301 | +1.7 | +1.9 |
| 302 | -8.4 | -11.5 |
| 303 | +7.8 | +4.5 |
| 304 | +1.1 | +1.7 |
| 305 | +4.2 | +4.9 |
| 306 | -2.8 | +1.6 |

On average -0.1 points a match: nothing either way. The routine calls are a
convenience, not an edge; the six points a passive coach concedes (§2) come
from the game plan, the pep talk and the tag, which stay your calls.

## Also noted

- **League Draft information.** You see every rating exactly; each rival
  drafts through its own scouting opinion (`Draft._eval_error`, deliberate so
  rival lists differ; DRAFT_EVALUATION.md). Taken up in the second pass, §10.
- **Weekly cards.** Their default answers leaned your way. Changed in the
  second pass, §8.
- **A rival coach's rematch rule** (`MatchSim._ai_rematch`) moves a key
  defender when his forward won "two in three" of three or more contests;
  the code compares against 0.67, so exactly two of three (0.667) does not
  trigger it. Left as it is; your assistant uses the same rule (§12).

## Before and after (first pass)

The career closest to the playtest: the `upside` drafter, `--coach`
(engaged on match day), the list on autopilot. Same seeds before (main) and
after (this change), five seasons each.

| Seeds 301-308, 40 seasons each | Before | After |
|---|---|---|
| Your selected side's morale at season's end (rivals') | 97 (70) | 96 (89) |
| Ladder against list (negative: higher than the list says) | -3.3 ± 0.7 | -1.5 ± 0.8 |
| Mean ladder position | 5.7 | 7.8 |
| Finals appearances | 35 | 28 |
| Top-four finishes | 18 | 14 |
| Premierships | 3 | 3 |
| Back-to-back premierships | 0 | 0 |

Removing the morale edge costs an engaged club about two ladder places,
four top-four finishes and seven finals appearances in 40 seasons.
Premierships are too rare to separate the two, and neither run produced a
repeat premier: the harness's drafters never build a list good enough to
dominate for three years by itself. The playtest's three flags took a strong
opening list (a careful human out-drafts the age-blind rivals, §4), the
morale edge on top of it (§1) and a list that cost nothing to keep together
(§3). The first is the player's own skill and stays; the second is fixed;
the third is the open design question below.

Your side still finishes about one and a half places above its list after
the fix. Part of that is morale again: the weekly cards' default answers (a
recovery week, the group lifting when a player is told to earn his spot)
keep your selected side about seven points above the rivals' (96 v 89),
worth a point or two a match by the table in §1. Those cards are your
decisions and rivals face no equivalent; see What remains.

Passive careers, before the fix (seeds 301-307): the autopilot club finished
about one place higher than its list (-0.8 ± 0.6 across `board` and `ai`),
the morale edge net of the coaching it gave away (§2).

## Before and after (second pass)

The three careers of §7 again, same eight seeds, five seasons, on the code
after every second-pass change (`0beb192`) against the code before it
(`727e4eb`). The opening draft changed too (§10), so season 1 differs.

| 8 careers, 40 seasons each | Autopilot before → after | Contracts + free agency | + trading up |
|---|---|---|---|
| Strength rank, season 1 | 6.8 → 9.5 | 6.8 → 9.5 | 6.8 → 9.5 |
| Strength rank, season 5 | 10.9 → 16.1 | 5.8 → 7.2 | 3.4 → 4.1 |
| Best-22 rating vs league, season 5 | +0.2 → -1.7 | +2.3 → +2.0 | +2.8 → +1.9 |
| Mean ladder position | 7.7 → 11.3 | 6.5 → 8.1 | 6.0 → 7.2 |
| Finals appearances | 29 → 16 | 32 → 26 | 31 → 29 |
| Top-four finishes | 11 → 7 | 18 → 13 | 20 → 15 |
| Premierships | 2 → 2 | 4 → 5 | 11 → 3 |
| ... after season 1 (of 32 seasons) | 0 → 2 | 2 → 5 | 9 → 3 |
| Back-to-back premierships | 0 → 0 | 0 → 1 | 3 → 0 |
| Per off-season: your trades; trades between rivals | - | - | 0.6 → 0.3; 2.9 |

What changed, and what it does not show:

- **Neglect now costs.** The autopilot list used to hold near the top
  third; now its unsettled starters test the market and leave (it signs
  five free agents a season to fill the list), and it slides from 9th to
  16th strongest, last or close to it in three careers by season 5. Its two
  flags came early, from a list still good enough (Sydney in season 2, Gold
  Coast in season 3).
- **Working the list is what keeps a club up.** Settling contracts and
  chasing free agents takes the same opening lists from 9th to 7th
  strongest; trading as well takes them to 4th, eight places clear of
  autopilot. The gap between doing nothing and doing the work is now much
  wider than the gap between the two kinds of work.
- **Trades no longer buy flags on their own.** Rival contenders now buy a
  rebuilder's stars at the start of each off-season (2.7-2.9 rival trades a
  season), so you find fewer for sale and make half as many deals. The
  trading club still builds the strongest lists (top three strength in 14 of
  40 seasons, top of the ladder after the home and away season five times)
  but won three flags, not eleven.
- **Premierships stay earned, and dynasties stay possible.** The strongest
  list does not always win: Richmond (seed 305) were top of the ladder three
  times in four seasons with either kind of management and won once.
  Essendon (seed 306, contracts and free agency) went from 13th strongest to
  back-to-back premiers. Flags in 40 seasons are too few to rank the two
  managed careers against each other (5 and 3 is within luck); the ladder
  and strength columns are the reliable measure.
- **Part of the drop is the draft.** Every career now starts from a weaker
  opening list (rank 9.5, not 6.8, §10), which lowers every column after
  it; the season-5 gap between autopilot and management is the change in
  list management alone.

The playtest's question was whether three flags in a row came too easily to
a club that barely touched its list. In the harness, an autopilot club now
fades out of contention within three or four seasons, a club that works its
list stays a contender, and repeat premierships take a good list kept
together on purpose. That is measured evidence, not a playtest: confirm it
on the phone.

## What remains

1. **Confirm on the phone.** Play a few seasons both ways: barely touching
   the list, and working it. The harness's managed club follows simple rules
   (§7); a human will do better or worse.
2. **Autopilot may now be harsh for a casual player.** An unmanaged list
   ends 16th strongest. The off-season screen says who is out of contract
   and what testing the market means; whether that is enough warning is a
   playtest question, not a constant to tune now.
3. **The cap still never binds** (payroll 0.91-0.93 of it in every career).
   A good list costing more to keep is still an option if success needs a
   price; nothing above needed it.
4. **Special match-ups** (ROADMAP: key match-ups) and the link to "X is
   hurting you"; the routine calls are done (§12).
5. **The rematch rule's "two in three"** compares against 0.67, so exactly
   two of three does not trigger it (Also noted).
6. **Expansion-list history.** A generated veteran's entry record still says
   he came out of the under-18s in the expansion year.
7. **List Profile, synergies and extreme margins:** re-measure on a played
   save now that your side no longer carries a hidden +3%.
8. **Trade E (long-save audit)** is still unassigned; the trade market's
   long-run behaviour (picks spent, lists churned over ten seasons) belongs
   there.
