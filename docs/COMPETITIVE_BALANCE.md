# Competitive balance: first pass (2026-10-04)

The phone playtest (ROADMAP 9.1) won three premierships in a row while barely
touching training or list management. This pass asked **why** before changing
any number, then fixed the one cause the evidence pinned down. Everything
below was measured through the shipped code.

## Verdict

| Suspect | Verdict | Evidence |
|---|---|---|
| A systemic edge for being the user club | **Found and fixed: morale.** Only your players' morale ever moved, and it moves match form. | [1](#1-morale-a-free-edge-in-every-match-for-your-club-only-fixed) |
| AI clubs out-coach a passive human | Real, by design: rivals use every match-day lever, a passive human uses none. It hid the morale edge in autopilot careers. | [2](#2-match-day-coaching) |
| Neglecting the list costs too little | **Confirmed, design-level.** A passive club keeps its whole list on rolled-over deals and stays under the cap; a typically aged list holds its strength for five seasons. | [3](#3-what-neglecting-the-list-costs) |
| AI drafting is age-blind | **True, partly exploitable, not a dynasty on its own.** Drafting with age in mind builds the strongest opening list, which fades within three or four seasons without list management. Not changed here. | [4](#4-ai-drafting-and-age) |
| List Profile "Elite" too easy | **Contradicted as a cause.** It is a rank (Elite: the top four of eighteen). Four Elite words and two Strong is a 0.6%-of-seasons profile: the playtest list was genuinely dominant. | [5](#5-what-the-code-contradicts) |
| Synergies pile up | **Not reproduced league-wide.** About 1.4 of 6 per club, flat over five seasons. | [5](#5-what-the-code-contradicts) |
| Training, fatigue, development, ageing favour you | **Contradicted.** One rule set for every club; the small user-only extras are listed. | [5](#5-what-the-code-contradicts) |
| An age-28, 89-POT generated player | **Explained:** expansion lists give every age a draft prospect's ceiling. Not fixed here. | [6](#6-generated-players-expansion-lists) |

## Tooling

| File | Role |
|---|---|
| `tools/balance/dynasty.gd` | Library. A whole career through the shipped code: the career draft (your picks by policy), `GameState.advance()` through every round and final, the off-season (rivals' contracts, trades and free agency; your club decides nothing, so undecided contracts roll over), the National Draft (your picks as a rival would make them) and the rollover. Records every club's preseason strength, ladder, List Profile words, synergies, ages, payroll and morale. |
| `tools/balance/dynasty_run.gd` | CLI: seeded careers to JSON. |
| `tools/balance/dynasty_report.py` | Report: your club and the league by season, ladder against list, premierships by preseason strength rank, repeat premiers. |
| `tools/balance/match_ab.gd` | Paired match probe: your matches against every rival on the same seeds under two or more settings of one thing (morale, match-day coaching, or moment cards), so the difference is that thing alone. |

```sh
godot --headless --path . --script tools/balance/dynasty_run.gd -- \
    --seeds 301,302,303,304,305,306,307,308 --policy upside --seasons 5 [--coach] --out run.json
python3 tools/balance/dynasty_report.py run.json
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

**Caveat.** Career runs are not bit-reproducible: the career draft is seeded,
but some later path still varies run to run. Read every result over many
seeds, never one.

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
and projects every player as a draft prospect (`Prospects.project`), so each
gets a draftee's ceiling (`Potential._draftee_potential`: rating plus 13-22 by
list rank) whatever his age. That is the age-28, 89-POT player, and
`Potential.growth` keeps pulling him toward it until he turns 28. His history
says he came out of the under-18s in the expansion year. Not changed here: it
belongs to the P0 generated-player provenance item (age-aware ceilings and a
believable entry history).

## Also noted

- **League Draft information.** You see every rating exactly; each rival
  drafts through its own scouting opinion (1-5 rating points of error,
  `Draft._eval_error`, deliberate so rival lists differ; DRAFT_EVALUATION.md).
  A careful human therefore out-drafts every rival on the same information.
  Unchanged; a candidate for the drafting pass.
- **Weekly cards.** Their default answers lean your way: a recovery week
  (morale +3, fresher legs, fewer injuries) and a closed session (+8 XP).
  After the morale fix they leave your selected side about seven morale
  points above the rivals'. Choices the AI has no equivalent of. Unchanged.

## Before and after

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

## What remains

1. **List-management pressure: a design decision, not a constant.** Neglect
   costs little for structural reasons: a passive club re-signs everyone at
   the asking price, the cap never binds (payroll averages 0.81-0.95 of
   it), and rivals' yearly churn does not lift their best 22 past a club that
   churns nothing. Pressure that stays inside the same football world:
   - an expiring player you have not dealt with weighs the market (rivals
     with room bid) instead of rolling over automatically;
   - a good list costs more to keep, so the cap starts to bind on success;
   - rivals manage their lists for strength - keep the useful veteran, buy
     the position they lack - so a club that works at its list pulls away
     from one that does not.
   Recommended next step: measure an actively managed career against the
   autopilot one (the playtest item asks for exactly this), then choose the
   smallest of these that makes the difference felt.
2. **The coaching gap for a passive human** (about 6 points a match). The
   roadmap's match-ups item (routine pairings handled for you, special
   match-ups surfaced) would close part of it legitimately.
3. **Expansion-list history.** A generated veteran's entry record still says
   he came out of the under-18s in the expansion year.
4. **League Draft information.** You see exact ratings; rivals draft through
   their own scouting error.
5. **Morale's shape and the weekly cards.** Playing always lifts morale and
   nothing pulls it back; the weekly cards' default answers keep your side
   about seven points above the rivals' (a point or two a match), and rivals
   face no equivalent club-life calls.
6. **List Profile, synergies and extreme margins:** re-measure on a played
   save now that your side no longer carries a hidden +3%.
7. **Harness determinism:** find the path that still varies run to run, so a
   career replays exactly.
