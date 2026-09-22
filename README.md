# AFL Auto-Battler

An auto-battler where the battles are **simulated AFL matches**. You draft a full
44-player list from **real 2026 AFL player statistics** — all 669 players across
all 18 clubs — then play a 24-round home-and-away season and a real finals
series, watching every match on an animated top-down oval.

Godot **4.7** / GDScript — targeting **PC and mobile**.

```
data/players_2026.csv      669 players, all 18 clubs, real 2026 season stats
data/clubs.csv             club names, guernsey colours, home grounds
scripts/sim/               ratings model, match engine, squad, season, draft
scripts/core/              GameDB (data loader), Router (navigation)
scripts/state/             GameState (the season you are playing)
scripts/ui/                the oval animation and every screen
scenes/                    seven thin .tscn wrappers - all UI is built in code
tools/sim_harness.py       calibration harness (Python mirror of the engine)
docs/DESIGN.md             full design + engine docs  <- read this
```

## Running it

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build, not
   the .NET one — this is pure GDScript).
2. Open the editor, click **Import**, select this folder's `project.godot`, **Open**.
3. Press **F5**.

That's it — there are no addons, no assets to build and no network calls.

**One thing to know about the CSVs.** Godot ships a `.csv` importer that treats
spreadsheets as translation files. That is not what we want here; `GameDB` reads
both CSVs directly with `FileAccess` at runtime. The checked-in
`data/*.csv.import` files pin the importer to **Keep File (exported as is)** so
the data survives export untouched. If Godot ever offers to re-import them as
translations, pick *Keep File* again in the Import dock.

## How a career plays

| Step | What happens |
|---|---|
| **Choose a club** | You take over one of the 18. The other 17 keep the lists they actually fielded in 2026, so the ladder is genuinely competitive. |
| **The draft** | Sign 44 players from the whole competition under a salary cap sized at 58% of the cost of the 44 best players. You must carry at least two ruckmen. Filter by position, club or name, and sort by rating, price, goals or disposals. |
| **Home and away** | 24 rounds, a full double round-robin. Each round you can **Play Match** and watch it on the oval, or **Sim Round** and just read the results. |
| **Finals** | Top eight play the real AFL bracket: qualifying and elimination finals, semis, prelims, Grand Final at a neutral venue. Level scores are resolved by ladder position, exactly as the AFL does it. |
| **Review** | The flag, your record, best win, worst loss, longest streak and a game-by-game form strip. |

### The oval

`scripts/ui/PitchView.gd` draws the ground entirely with `_draw()` — no sprites,
no textures, so it scales cleanly from a phone to a 4K monitor. Mown stripes are
polygons clipped to the ellipse, and the 22 players on each side are the real
18 selected for that match, arranged 1 ruck / 7 mids / 5 defenders / 5 forwards
in club colours with their guernsey numbers.

The match is simulated in full before you see it, as a log of ~1,100 events
(every disposal, mark, tackle, inside 50, clanger and shot). The pitch replays
that log: the ball travels to the recorded field position, both structures shift
up and down the ground with it, the carrier is ringed in gold, and goals flare.
Routine handballs tick by quickly; scores and quarter breaks get room to land.
Speed controls run 1x–8x with a skip-to-full-time button — about ninety seconds
at the default 4x.

`docs/preview_match.png` is a static render of exactly this screen, frozen on a
real simulated goal, produced by `tools/render_preview.py` (which shares
PitchView's geometry constants and can also emit an SVG). It is what the game
draws, not a concept sketch:

![The match screen](docs/preview_match.png)

## Simulation quality

The engine is calibrated against real 2026 numbers rather than guessed at.
`tools/sim_harness.py` derives per-team-per-game averages straight from the
harvested player data, runs hundreds of simulated matches, and reports the gap:

```
Stat / team / game     REAL 2026       SIM   ratio
------------------------------------------------
Score (pts)                 88.0      88.1    1.00
Goals                       13.1      13.3    1.01
Disposals                  364.6     363.6    1.00
Marks                       93.4      92.3    0.99
Inside 50s                  52.4      54.5    1.04
Clearances                  35.7      35.1    0.98
Hit-outs                    33.8      33.7    1.00
Free kicks for              18.0      17.9    1.00
```

Every ratio sits between 0.98 and 1.04. The derived player ratings independently
reproduce the real 2026 Brownlow ordering — Nick Daicos (a record 47 votes) →
Bailey Smith (36) → Patrick Cripps → Izak Rankine → Jordan Dawson →
Will Ashcroft.

The dataset itself is checked by `tools/validate_data.py`, which compares 220
club × column aggregates against the totals AFL Tables publishes. 219 pass; the
one failure is Hawthorn's Brownlow-vote column, which is off by 10 and is not
used by the ratings or the engine.

## The engine

```
Ratings.gd    real season stats -> 13 attributes on a 1-99 scale, a position
              classification, an overall rating and a draft salary value
Squad.gd      a 44-player list -> best 18 + bench -> the handful of team
              strengths the engine actually rolls against
MatchSim.gd   a match as 4 quarters of possession chains: stoppage, contest,
              carry, mark, tackle, inside 50, shot, clanger, free kick
Season.gd     24-round fixture (circle-method round-robin), ladder with the
              real AFL tiebreak order, and the full finals bracket
Draft.gd      the salary cap, the board filters, and the 17 AI lists
```

Every match is seeded, so a result is reproducible. `MatchSim.gd` is a direct
port of `tools/sim_harness.py` and must keep the same RNG call order — that file
is where the constants were tuned, so **run the harness after any change to the
match engine**:

```bash
python3 tools/sim_harness.py               # calibration report
python3 tools/sim_harness.py --sample      # one narrated match
python3 tools/sim_harness.py --ratings     # dump ratings to data/ratings_preview.csv
python3 tools/validate_data.py             # dataset integrity check
```

## Exporting

**Desktop.** Project → Export → add *Windows Desktop*, *Linux/X11* or *macOS*,
then Export Project. Nothing here needs a native library, so the defaults work.

**Android / iOS.** Add the export preset, install the matching export templates,
and point the preset at your debug keystore (Android) or signing identity
(iOS). The project is already configured for mobile: the renderer is set to
`mobile`, ETC2/ASTC texture compression is on, the window is `sensor_landscape`,
and touch/mouse emulation is enabled both ways so the same UI works with a
finger or a cursor. The layout reflows below 900px wide — on a phone the
commentary feed stacks under the oval instead of beside it.

`export_presets.cfg` is deliberately not checked in: it holds machine-specific
paths and signing material. Generate it in the editor.

## Note

Godot cannot run in the sandbox this was built in (no engine binary, no outbound
network), so the game itself is not playtested here — the simulation logic is,
via the harness, and the GDScript was checked with a structural linter for
balanced syntax, indentation, reserved-word collisions and cross-file member
references.

Real player and club names are used for a personal, non-commercial fan project.
No club badges, guernsey designs or player imagery are reproduced — guernseys are
two circles in each club's registered colours. See `docs/DESIGN.md` §1.
