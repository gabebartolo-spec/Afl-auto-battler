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

### Attribution
Player statistics are factual season data compiled from AFL Tables, a long-running
volunteer-maintained archive. Real player and club names are used for a personal,
non-commercial fan project — the AFL, its clubs and Champion Data do not endorse
it and no player imagery or club badges are reproduced.

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

### Overall & salary
`overall` blends role-weighted attributes with `star` (Brownlow signal) and
`durability`, then shrinks toward 40 for low-game players. `value` (1–10) is the
draft salary-cap cost, banded off `overall`.

**Validation.** The derived top-10 reproduces the actual 2026 Brownlow order for
the harvested clubs — Daicos (47 votes) → Bailey Smith (36) → Cripps (27) →
Rankine (25) → Dawson → Ashcroft (27) → Neale → Serong → Walsh → Jackson.

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
`±35`. Each side fields **18** (1 RUCK, 7 MID, 5 DEF, 5 FWD) plus 4 interchanges.

Stoppage win probability is a strength differential divided by `contest_swing`
(360) and clamped to `[0.40, 0.60]`, plus a small home-ground bonus and a
territory nudge. Clamping matters: an unclamped stoppage contest compounds over
165 chains and produces absurd 70-point average margins.

### Determinism
The sim takes a seed and generates the **entire event log up front**. The pitch
view then replays it. That decouples simulation from presentation, so speed
controls, pause and "skip to result" are free, and any match can be re-watched.

### Calibration
`tools/sim_harness.py` runs the engine over hundreds of matches and compares the
output against the per-team-per-game averages implied by the real harvested data.
Current state (400 matches, 7 clubs harvested):

| Stat / team / game | Real 2026 | Sim | Ratio |
|---|---|---|---|
| **Score (pts)** | 88.0 | 88.1 | **1.00** |
| Goals | 13.1 | 13.3 | 1.01 |
| Behinds | 9.2 | 8.5 | 0.92 |
| Disposals | 364.6 | 363.6 | 1.00 |
| Kicks | 213.2 | 208.9 | 0.98 |
| Handballs | 151.4 | 154.8 | 1.02 |
| Marks | 93.4 | 92.3 | 0.99 |
| Tackles | 56.2 | 52.1 | 0.93 |
| Inside 50s | 52.4 | 54.5 | 1.04 |
| Clearances | 35.7 | 35.1 | 0.98 |
| Hit-outs | 33.8 | 33.7 | 1.00 |
| Rebound 50s | 38.4 | 34.7 | 0.90 |
| One percenters | 40.4 | 40.9 | 1.01 |
| Clangers | 53.2 | 52.8 | 0.99 |
| Free kicks for | 18.0 | 17.9 | 1.00 |

Average margin 26 pts, 30% of games decided by ≤12 points. Margin will widen
once the weaker clubs (West Coast, Richmond) are harvested, which is when it
should be re-checked against the real ~33 pt league average.

> `tools/sim_harness.py` is a **tuning harness, not shipped game code**. It is a
> deliberate Python mirror of `scripts/sim/MatchSim.gd`. When a constant changes
> in one, change it in the other.

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
  least once, plus 7 extra matches balancing home games), then the **AFL final
  eight**: top 4 get the double chance, 1QF/2QF → SF → PF → GF.
* **List management** — select your 22 each week (18 on ground + 4 interchange),
  with injury/rotation to be layered on.

---

## 5. Platform

Godot 4.7, `mobile` renderer, `canvas_items` stretch with `expand` aspect and
unrestricted sensor orientation (`DisplayServer.SCREEN_SENSOR`, value 6).
`ScreenLayout` updates the logical viewport from the actual window size and
pixel density on resize; it never scales a desktop-width canvas down to a
portrait phone. The draft also applies OS safe-area insets. Touch/mouse
emulation works both ways.

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
    Season.gd          24-round fixture, ladder, finals bracket
    Draft.gd           salary cap, board filters, the 17 AI lists
  state/
    GameState.gd       autoload; the season you are playing
  ui/
    UiKit.gd           shared widgets and layout helpers
    PitchView.gd       the animated oval (pure _draw(), no textures)
    Main.gd            menu
    DraftScene.gd      club selection + draft board
    HubScene.gd        season hub: next match, ladder snapshot, round controls
    MatchScene.gd      scoreboard, oval, commentary, full-time box score
    LadderScene.gd     full ladder + finals bracket
    ListScene.gd       your list, best 22, attributes, real season numbers
    SeasonReviewScene.gd  the flag, your record, final ladder
scenes/                seven thin .tscn wrappers - a root Control + its script
tools/
  sim_harness.py       calibration harness (run this after any engine change)
  scrape_afltables.py  re-harvests the dataset, with the <6-game 2025 fallback
  validate_data.py     checks 220 club x column aggregates vs published totals
```

## 7. Status

| Area | State |
|---|---|
| Real 2026 dataset | Done — 669 players, all 18 clubs, 219/220 aggregate checks pass |
| Ratings model | Done, validated against the Brownlow order |
| Match engine | Done and calibrated (every tracked ratio within 0.98–1.04) |
| Godot port of engine | Done — `scripts/sim/`, same RNG call order as the harness |
| Draft / season / ladder / finals | Done — `Draft.gd`, `Season.gd`, `GameState.gd` |
| Animated oval + UI | Done — all seven screens build their trees in code |

### Note on testing

The draft UI and model were exercised in Godot 4.7.2's actual web renderer, not
an HTML recreation. Regression scripts under `tests/` check every logged
selection, snake order, ownership, cap/list invariants, position needs, all four
draft tabs and rotation across ten viewports. Browser touch tests additionally
cover signing, filters, resume and the season handoff. Native mobile sensor
rotation, software keyboards and notches still require device checks; see
`tests/README.md`.
