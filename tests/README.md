# Regression checks

Use the standard Godot 4.7 editor/runtime. The quickest way to run
everything CI runs (import, every suite below, the dataset check and the
intake harness), with a pass/fail table at the end:

```sh
GODOT=/path/to/godot tools/run_tests.sh          # everything
GODOT=/path/to/godot tools/run_tests.sh ai save  # just some suites
```

GitHub Actions (`.github/workflows/tests.yml`) runs the same script on every
pull request and every push to `main`, with Godot 4.7.2 downloaded and cached.
A suite that hangs is stopped after 15 minutes (`SUITE_TIMEOUT`) and fails the
run; a failing run uploads the logs as an artifact.

CI runs the suites as five parallel shards, so a pull request takes about eight
minutes instead of half an hour. `tools/ci_shards.txt` says which suites each
shard runs; `tools/check_ci_shards.sh` fails the run if a suite in
`tools/run_tests.sh` is in no shard, so **a new suite needs a line in
`tools/ci_shards.txt`** (put it in the shortest shard) as well as a floor in
`expected_checks.txt`. One more job runs the dataset, export-data and intake
harness checks once (`EXTRAS_ONLY=1 tools/run_tests.sh`). The required check
named `test` is the last job and passes only when every shard and that job did.

Run only the suites your change touches while you work; CI runs the rest.

**Taps and seeds.** A test that stands for a player's tap uses `tests/tap.gd` (`await Tap.tap(button)` returns "" when the tap reached it). It sends a touch at the button's place on screen, so a covering sheet or an off-screen button fails. A test that starts a season sets `GameState.replay_seed` first: a clock seed makes a different match every run (ROADMAP §0.4a, proof practices). Every suite that starts a season or draft sets `SUITE_SEED` (a `const` in the suite, 2027) as `GameState.replay_seed` in `run()` and resets it to 0 before the summary line (C15). A suite already deterministic another way (explicit `MatchSim` or `Draft` seeds) says so in one line, `## Seeded by design: <why>`; `tools/check_suite_seeds.sh` runs with the dataset checks and fails, naming the suite, if a suite has neither. If a seeded suite fails, fix the code or report it to the suite's owner, do not edit the check to pass.

### Which suite covers what

Pick the suites for the code you changed and run just those (`tools/run_tests.sh <suites>`).
Floor is the fewest checks the suite may run (`expected_checks.txt`; a suite reporting fewer fails the run). Times are seconds on a CI runner, from the first sharded run.

| Suite | Covers | Floor | CI s |
|---|---|---:|---:|
| `draft` | The League Draft model: cap, snake order, rival picks, pick log | 7807 | 24 |
| `draft_ui` | The draft screen's layout and state: containers, widths, rotate and resume | 1130 | 5 |
| `intake` | The National Draft model: the 2026 class, projection, season rollover | 2210 | 6 |
| `intake_ui` | The National Draft on the shared draft screen | 500 | 4 |
| `expansion` | Tasmania in 2028 and Canberra in 2030, and a Club Forge club entering with the career | 488 | 53 |
| `finals` | The wildcard finals bracket, extra time, draws | 109 | 68 |
| `save` | Saving and loading a career, including old-save migrations and the safe write: a failed or interrupted write never loses the career, and a failed swap leaves the newer save readable | 76 | 29 |
| `chronology` | 2026 is history, careers start in 2027, and every system agrees | 31 | 4 |
| `career` | Games, goals and club stints across a dynasty | 71 | 229 |
| `coaches` | The coaching world: six jobs a club, records, grades, the Staff screen | 340 | 35 |
| `coach_market` | Coach moves, hiring, sackings, retirements, assistant contracts | 63 | 95 |
| `coach_pathway` | Retired players becoming coaches, and the record they carry | 57 | 2 |
| `coach_effects` | What coaching does: teaching, tactics, man-management | 36 | 5 |
| `career_ui` | Main menu and save flow, Back, the Hub, Training, selection and trade screens, at 320, 360 and 430 wide | 280 | 70 |
| `potential` | Potential (POT) rules, rehab years, draft pedigree | 36 | 5 |
| `ratings` | The overall rating model | 39 | 2 |
| `ai` | Rival clubs' drafting and selection | 35 | 58 |
| `training` | Training plans and the stat guide | 107 | 32 |
| `selection` | Team selection and named sides | 37 | 4 |
| `matchup` | This week's opponent facts | 95 | 36 |
| `matchday` | Match-day wording: the feed, quarter breaks, full time, the match screen | 504 | 21 |
| `roles` | Roles, wings, taggers and rucks as real jobs | 218 | 8 |
| `injuries` | Injury rates, durability, healing, and played v simulated parity | 31 | 78 |
| `awards` | Brownlow, Coleman, best and fairest, All-Australian | 22 | 49 |
| `achievements` | Club achievements | 153 | 48 |
| `contracts` | Contracts, free agency and trades (seeded: a clock seed once made the pick-limit check flaky) | 233 | 29 |
| `league` | Difficulty and the league news feed | 47 | 52 |
| `club` | The board, morale and the weekly event card | 199 | 103 |
| `match_game` | Legs and rotations, match moments and calls, the rival coach, key match-ups, Play through by job | 346 | 333 |
| `pressure` | Pressure acts and the team Pressure Rating | 21 | 38 |
| `workload` | Workload across the campaign | 32 | 8 |
| `match_visual` | The live match view is presentation only (PitchView, MatchDirector, MatchMotion) | 108 | 210 |
| `league_balance` | Smoke checks for the balance harness in `tools/balance` | 23 | 223 |
| `calibration` | The engine against real 2026 numbers (seeded matches) | 17 | 69 |
| `balance` | A long-career guard: three seasons must not inflate the league | 13 | 149 |
| `assets` | The art and music as shipped: figure-sheet frames against the layout, vignettes playing their moves through, banners, music files, levels and the player | 95 | 3 |

By area:

- `MatchSim.gd`, `MatchNotes.gd`: `match_game`, `matchday`, `roles`; add `pressure` for pressure changes. `calibration` and `balance` only when you changed scoring or ratings (they are the slow ones).
- `UiKit.gd` or any screen: `career_ui`, plus that screen's own suite (`draft_ui`, `intake_ui`, `matchday`, `match_visual`).
- The draft, prospects or potential: `draft`, `intake`, `potential`, `ai`.
- Contracts, money or trades: `contracts`, `save`.
- Anything stored on a player or a club: `save` as well, so an old career still loads.
- Coaches and staff: `coaches`, `coach_market`, `coach_pathway`, `coach_effects`.

To run suites one at a time, from the repository root:

```sh
# Registers class_name scripts and imports the bundled fonts on a fresh clone.
godot --headless --path . --editor --import

godot --headless --path . --script tests/run_draft_tests.gd
godot --headless --path . --script tests/run_draft_ui_tests.gd
godot --headless --path . --script tests/run_intake_tests.gd
godot --headless --path . --script tests/run_intake_ui_tests.gd
godot --headless --path . --script tests/run_finals_tests.gd
godot --headless --path . --script tests/run_save_tests.gd
godot --headless --path . --script tests/run_career_tests.gd
godot --headless --path . --script tests/run_coaches_tests.gd
godot --headless --path . --script tests/run_career_ui_tests.gd
godot --headless --path . --script tests/run_potential_tests.gd
godot --headless --path . --script tests/run_ai_tests.gd
godot --headless --path . --script tests/run_training_tests.gd
```

The intake suites cover the 2026 draft-class file (56 prospects: unique ids/
ranks/aliases, role validity, projection band, ruck cover, valid tied-club
tags), the projection maths (rank taper, date maths, idempotent re-projection),
the reversed-ladder intake flow (snake rounds, truncation when the pool runs
dry, capped-club skips, contiguous logs), and the full rollover (year
advance, list merges with jumper numbers, ageing + retirement bounds, the
generated 2027 class, determinism, and reset restoring the pristine 2026
data). The UI suite runs the shared DraftScene in intake mode across the same
ten viewports. The finals suite checks the bracket opens straight after
round 24, that a qualifying club plays every final live through the same
prepare / quarter-by-quarter / finish path the match screen uses (nothing is
recorded mid-match, each week records the right number of matches, the
higher seed hosts every final but the Grand Final, which is always at the
MCG, where only an MCG club has a home-ground edge, in either slot), that
simming the series still crowns a premier,
that a level final goes to extra time (one siren, a fifth period, the tie
broken) while a home-and-away draw stays a draw, and that the finals status
(alive / week off / knocked out) and outcome line are right each week.

The career suite checks career records against the match results
themselves: one season (finals included, every club), three seasons in a row,
a star changing clubs (two stints), a save in Grand Final week and reloads
before and after the close and the rollover (never counted twice), career
draftees' draft keys (potential unchanged, first season counted from zero),
the 2026 dataset (every player known, totals equal their stints,
`p["history"]` untouched) and older saves (loaded, nothing invented, the
seasons they played marked unknown, tracked normally afterwards).

The save suite reloads a career at every stage (mid-season, mid-draft, mid
national draft, second season) and checks it is the same career: the next
round replays identically after loading, training survives, shared player
dicts stay shared, generated draft classes come back, a half-played live
match is never saved, and a file from another save version is ignored. The
career UI suite drives the main menu (Continue, Settings, the New Career setup
and its confirmation)
and the back button on the hub, ladder, a live match and the menu.

The potential suite checks every player and prospect has a POT (generated
ones within the position caps), recent history flags the injured stars for a
rehab year that closes most of the gap at the first rollover (and only
because of that history), a young top pick gets a higher ceiling than the
same player as a rookie listing, growth never passes POT, training is cheaper
below POT, earlier picks carry more POT, and POT, history and pedigree
survive a save (older saves get POT filled in).

The AI suite runs all-AI career drafts (every club two or three rucks, no
club hoarding good rucks while another has none, the best ruck and an elite
player in round one), checks the national-draft AI prefers potential, and
plays rounds to check rivals train after games, never well past potential,
and never with your players' XP.

The training suite checks the Position plan trains most of the list after a
game (a ruck only ruck stats), Manual banks XP, a single-stat focus touches
only that stat, switching a player's or the club plan spends banked XP at
once, a player's own plan beats the club plan, plans survive a save, and every
stat has a full guide entry. The career UI suite also checks the one-time
training intro, the stat guide (and Back closing it) and the plan picker.

The achievements suite checks every club's achievement is detectable from
stats the game already tracks (`tests/run_achievements_tests.gd`, part of
`tools/run_tests.sh`).

The league-balance suite smoke-tests the competitive-balance harness in
`tools/balance/` (seeded career draft reproducible, seasons replay exactly,
a +10 OVR list beats +0 on identical seeds). It asserts no balance target;
the full drafted-league measurement is a manual run described in
`docs/LEAGUE_BALANCE.md`.

`tools/check_export_data.sh` (also run by `tools/run_tests.sh`) guards the
exported build's data path, which the editor and the suites above never see:
every `data/*.csv` must use the `keep` importer, and a real exported `.pck`,
run on its own, must load every player with an age and date of birth
(`tests/export_data_check.gd`). A CSV left on Godot's default translation
importer is silently dropped from exports.

Every runner points saves and settings at `user://test_*` files and turns
autosave off, so running the tests never touches a real career.
`tools/run_tests.sh` also gives each run its own user data folder (a temp
`XDG_DATA_HOME`, removed afterwards), so two runs at once - two worktrees,
two branches - cannot overwrite each other's test saves. Running a single
runner by hand still uses Godot's normal user folder.
A non-Godot mirror of the same maths runs in CI-friendly Python:
`python3 tools/intake_harness.py` (data/schema validation + a six-season
intake/development simulation over the real lists).

Both runners exit nonzero on failure. They use the shipped GDScript, not a
Python/JavaScript reimplementation.

### Adding a suite

1. Write `tests/test_<name>.gd` and a runner `tests/run_<name>_tests.gd` (copy a small one such as `run_league_tests.gd`, which points saves and settings at test files).
2. Add `<name>` to `ALL_SUITES` in `tools/run_tests.sh`.
3. Add its floor, the count it prints, to `tests/expected_checks.txt`. When an existing suite gains checks, don't edit its line: add `tests/floor_deltas/<branch>.txt` with `<suite> +N` (see `tests/floor_deltas/README.md`); the floor is the base plus all deltas, so PRs don't collide.
4. Add it to the shortest shard in `tools/ci_shards.txt`, then run `bash tools/check_ci_shards.sh`. It prints `ok: N suites in M shards, each exactly once`, or says what is missing.
5. Add a row to the table above.

CI's `plan` job runs the same check, so a suite left out of every shard fails the run instead of quietly skipping CI.

**A floor counts rules, not data.** A `_check` inside a loop over players, matches or list entries makes the count move whenever the engine or a seed changes how many there are, and the floor then fails for no real reason (it happened three times in one day: "Needs a lift" in matchday, "No player on two lists" in expansion, and a floor recount on the fair fixture). Write one check per case: collect the failures in the loop, then check once.

```gdscript
var twice := []
for p in players:
	if seen.has(p["id"]):
		twice.append(p["id"])
	seen[p["id"]] = true
_check(twice.is_empty(), "No player is on two lists: %s" % str(twice))
```

### Long audits on GitHub (`audit.yml`)

A seeded audit in `tools/audit/` that takes more than a few minutes should not tie up a machine. Dispatch it against any branch:

```sh
gh workflow run audit.yml --ref <branch> -f impl=<name> -f env="KEY=VAL KEY2=VAL2" -f args=""
gh run watch
gh run download <run-id> -n audit-<name>
```

- `impl` is the file in `tools/audit` without `.gd`, the same word you pass to `tools/audit/run_audit.gd` after `--`. `args` is anything the script reads after it (optional).
- `env` is space-separated `KEY=VALUE` pairs the script reads with `OS.get_environment`; values cannot contain spaces. Both are checked before the run starts.
- The run summary shows the last 60 lines of the log; the whole log is the artifact `audit-<name>`, kept 14 days.
- Every dispatch runs on its own, so variants of one audit can go at once. There is a 180 minute limit and a read-only token: the workflow only measures and never pushes or comments.
- It runs the audit script as it is on the branch you pass to `--ref`.
- For a short audit, run it locally: `godot --headless --path . --script tools/audit/run_audit.gd -- <name>`, with `APPDATA=<scratch dir>` on Windows so it does not share saves with another run.

## Automated coverage

**Model:** initial rival selections; contiguous global pick numbers and rounds;
reversed and back-to-back snake turns; destination versus original club;
rejected/duplicate picks leaving history and cap unchanged; live position
counts and clamped needs; complete small and real-data league drafts; unique
ownership; equal list sizes and salary caps; taken-player filters and upcoming
pick numbers; fictional generated labels (no numbered placeholders), real-name
mode showing the AFL name on its own, and stable ID-based name resolution.

**UI:** all four draft tabs at 390×844, 844×390, 320×568, 360×800, 430×932,
768×1024, 1024×768, 667×375, 915×412 and 1280×800. Tests check the actual viewport
size, panel/footer bounds, ≥44-unit touch targets, position counts, every filter
surviving resize, no-results recovery, disabled premature season starts and
reopening without replaying AI selections.

The two suites also ran in a Godot **4.7.2 web runtime** during this update:
**4,203 model checks** and **1,076 UI checks**, zero failures. Browser automation
added **352 checks**, including actual touch taps to choose a club and sign a
player, opening rival picks, keyboard-controlled dropdowns, rotation with
active filters, draft resume, older-pick pagination and the handoff to the
existing season hub. Additional touch regressions verified swipes starting on
club cards, player info, role badges and draft buttons, plus the rival log:
they scroll without signing players, while a tap still signs exactly one.
HiDPI checks also confirm a 2× phone canvas retains a 390×844 logical viewport.
The web preview runs the game's GDScript/scene files, not an HTML mock-up.

## On-device smoke test

Native Android/iOS exports still need this pass (browser viewport resizing
cannot verify a hardware orientation sensor or OS safe-area values):

1. Start in portrait, choose a club, and check the whole league's opening picks.
2. Tap DEF / MID / RUCK / FWD counters to filter; tap again to clear. Sign a
   player. Confirm your counts/cap and every subsequent rival pick update.
3. Scroll the pool with a finger starting on a player row. It must scroll, not
   accidentally sign someone. Draft actions should remain at least 44 UI units.
4. Search with the software keyboard open, then rotate. Check the query/caret,
   selected position, club/sort filters, availability toggle and roster survive.
5. Rotate with Picks / My list / Order open. The pool and activity panel should
   split on sufficiently wide landscape screens, otherwise use tabs. On short
   screens scroll to reach filters rather than losing the action footer.
6. Verify notches, the status bar and the home/gesture indicator do not overlap
   the draft's back button, tabs or Start Season action.
7. Toggle **Filters → Available only** off. Taken players must show their new
   club/pick, and must not be draftable again.
8. Complete a valid list, open older rival picks, then start the season.

Position targets are **guidance**, except for the existing two-ruck rule. This
UI change intentionally does not rebalance the draft AI, salary cap, positional
classification or match engine.


## Weekly workload

`tools/run_tests.sh workload save selection finals` checks accumulated effort,
recovery, duplicate-week protection, match energy limits, stepped-match parity,
automatic/manual selection, save replay, older saves, finals byes, Grand Final
recovery, offseason reset, and readiness copy at 360-pixel portrait width.

`godot --headless --path . --script tools/workload_probe.gd` measures 128
paired matches (same squads and seeds; one home squad fresh versus loaded),
then reports readiness across a regular season with automatic selection.
It uses the shipped Godot engine, not a second simulation.
