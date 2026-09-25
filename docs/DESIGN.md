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
numbered placeholders such as `Squadmate 001` are never shown. The main-menu
**Player Labels** toggle switches to the real AFL name on its own, such as
`Jordan Dawson`. It does not prefix a fictional alias or a "plays like"
comparison, and it does not change IDs, ratings, draft logic or match results.
Players with no real-world counterpart (generated future draft classes) keep
their fictional name in both modes. Draft history resolves labels by player ID
so switching the mode never leaves an old name in a row or tooltip. This is a
product presentation choice, not legal advice or a licensing determination.

---

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
produce one — it is not invented. The tag is `MID/FWD`. Match-day selection
fills each slot from primary players first, then from the secondary. The
on-ground copy's `role` is the slot, so the oval still groups them; `list_tag`
keeps the natural tag for the list screen. Draft filters and the two-ruck rule
treat either role as cover. Position totals stay primary-only, so they still
sum to the list size.

### Overall & salary
`overall` blends role-weighted attributes with `star` (Brownlow signal) and
`durability`, then shrinks toward 40 for low-game players. That raw blend tops
out around 80, because it is an average of attributes that rarely all peak
together. `scale_overall` stretches it so the best 2026 players land near 90
(Bontempelli 92, Nick Daicos and Heeney 91, Bailey Smith 90) while the middle
of the pool stays in the 50s. The stretch is monotonic, so Brownlow order holds.
`value` (1–10) is the draft salary-cap cost, banded off the stretched overall.
No new player-data source is involved.

**Validation.** The derived top-10 reproduces the actual 2026 Brownlow order for
the harvested clubs — Daicos (47 votes) → Bailey Smith (36) → Cripps (27) →
Rankine (25) → Dawson → Ashcroft (27) → Neale → Serong → Walsh → Jackson.

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

### Half-time assistant coach report
Interactive matches pause at half-time with an assistant coach report inside the
Q3 coach box (`scripts/sim/CoachReport.gd`, pure analysis, no RNG draws). It
names your three best and three quietest players, the same two groups for the
opposition, and the opposition's actual Q1/Q2 gameplans with their engine
effects — read from `MatchSim.tactics_history`, not inferred. `MatchSim`
also snapshots team and player totals after each quarter (`quarter_teams`), so
the report can show per-quarter opposition output (points, inside 50s, tackles,
clearances) and flag what a Q1→Q2 plan change produced. Best/worst uses the
same influence weighting as the full-time best-on-ground list; "quiet" is
ranked by actual-vs-expected influence for the player's rating, so a down star
surfaces ahead of a depth player having a par game. Team edges (clearances,
territory, pressure, ruck, errors, conversion) feed second-half keys that map
to real coach-box answers (tag the danger man, run play through a quiet star,
Win contest, Controlled tempo, Attack corridor, Defensive press). The report
is re-viewable from the Q4 coach box and the full-time screen, including after
Skip to full time, by reconstructing half-time from the Q2 snapshot.

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
  players and strong games earn more; unused players still get a squad share.
  The training menu lists the whole squad. Spend a player's own XP on any of
  the 13 attributes. Cost rises with the current stat and with career games.
  The old post-match screen only rolled five random names, which is why it
  looked empty.
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
* **Rollover** — `finish_intake_draft()` merges each club's intakes into its
  list (rookie jumper numbers assigned from 41 up), ages every player by a
  year, applies the development bands (young grow, old decline), retires the
  oldest/lowest-rated (floor: 32 per club), adds the next year's generated
  intake class (`Prospects.generate_class`), and builds a fresh 24-round
  season. `GameDB.reload()` on career reset restores the pristine 2026 data
  because mid-career mutations are in place. Undrafted prospects carry into
  next year's pool and age out at 22.

---

## 5. Platform

Godot 4.7, `mobile` renderer, `canvas_items` stretch with `expand` aspect and
unrestricted sensor orientation (`DisplayServer.SCREEN_SENSOR`, value 6).
`ScreenLayout` updates the logical viewport from the actual window size and
pixel density on resize; it never scales a desktop-width canvas down to a
portrait phone. The draft, hub, ladder, list, match and season review apply OS
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
    HubScene.gd        season hub: next match, ladder snapshot, round controls
    MatchScene.gd      scoreboard, oval, commentary, full-time box score
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
