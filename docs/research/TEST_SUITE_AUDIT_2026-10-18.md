# Test suite audit, 2026-10-18

Asked by the director (2026-10-18 22:3x): "do an audit of the tests we do, are any of them superfluous? are we
wasting time being overly fastidious on easily avoidable things?" Read-only audit by `testaudit` against main
`90363c8f` (#814). Real timings from Tests run 39119858455 (main push, 2026-10-18, green) and PR run 39121980374.

## Summary (for the director)

- **The tests themselves are mostly worth keeping.** Of 53 suites, 50 protect something a player would see or a
  save he would lose. One suite (`league_balance`) tests a developer tool, not the game, and can leave the pull
  request check. Two (`save`, `match_game`) are each so long that they set the pace of a whole CI run and should be
  split in two.
- **The waste is in the machinery around the tests, not in the tests.** Five things cost us the most time:
  1. **CI waits for its slowest shard, and the shards are planned from stale timings.** The slowest of five
     shards took 31.7 minutes while another took 10.3 (run 39119858455). Planned from today's real numbers, every
     shard would take about 18 minutes. **About 14 minutes lost on every CI run.**
  2. **The check-count floors.** Every pull request that adds a test has to do arithmetic on a shared count
     file. 114 of the last 162 merged PRs touched it. Tonight two PRs counted the same 31 checks, main went red,
     and every open PR failed until hotfix #822. The floors have not caught a real defect since they were added on 2026-09-29 (e2799845).
     **About 10 builder minutes per PR that adds tests, plus incidents like tonight's.**
  3. **A five-minute queue before any test starts.** Every PR runs the match-day suite alone first and only then
     starts the five shards. **5.6 minutes on every PR run** (run 39121980374).
  4. **Checks that enforce a rule you reversed tonight.** 21 checks fail a screen that shows a number. You ruled
     on 2026-10-18 that every decision gate shows its size and odds. Each gate PR that meets one of these checks
     goes red and needs another fix and another CI cycle (**about 38 minutes each**). That already happened once: the
     odds lint built in #780 that morning was deleted in #817 that evening.
  5. **Five hand-kept lists per new suite.** Each new suite has to be added to five registries, and these conflict
     after every merge (lead handoff). A builder kept the 30-day "fresh timings" rule green by changing the date
     without measuring anything (#755).
- **First change:** re-plan the shards from tonight's real timings (one small PR, nothing loses coverage). Second:
  replace the floors with a check that every test function ran (section 4).
- **Rules that do earn their keep:** real taps, W7 reviews and the script-error rule. Each has caught real defects
  (section 6).

## 1. Every suite

Checks = base floor plus pending deltas (`tests/expected_checks.txt` + `tests/floor_deltas/*.txt`). File s =
`tools/ci_suite_timings.json`. Real s = run 39119858455 artifact `suite-timings-*`.
Total: 22,827 checks; 5,350 real suite-seconds per run (89 runner-minutes) against 3,866 in the timings file.

| Suite | Checks | File s | Real s | Protects | Verdict |
|---|---:|---:|---:|---|---|
| draft | 7901 | 25 | 59 | League draft rules: cap, snake order, rival picks and their reasons | KEEP (156 `_check` sites; the count is loops) |
| draft_ui | 1233 | 8 | 75 | Draft screen layout, filters, a real click on a draftable row | KEEP (caught #805 row pushed off screen) |
| assets | 115 | 19 | 10 | Shipped figure sheets, vignettes, banners and music load and play | KEEP (the "right art loaded" rule) |
| intake | 2243 | 22 | 31 | National Draft class, projection, rollover | KEEP |
| intake_ui | 532 | 4 | 14 | National Draft on the shared draft screen, real taps | KEEP (merging into draft_ui saves under 10 s) |
| expansion | 503 | 48 | 61 | Tasmania 2028, Canberra 2030, Club Forge club in a career | KEEP |
| finals | 106 | 89 | 57 | Wildcard bracket, extra time, draws on the ladder | KEEP (owns the draw rule) |
| save | 143 | 33 | 586 | Save/load, reload plays like straight, old-save migration, safe write | KEEP, SPLIT into reload and migration suites; grew from 29 s (`tests/README.md:45`) to 586 s |
| chronology | 31 | 11 | 15 | 2026 is history, careers start 2027 | KEEP |
| career | 71 | 262 | 468 | Games, goals and club stints across seasons | KEEP; profile it (6.6 s per check) |
| coaches | 346 | 56 | 66 | Six coaching jobs a club, records, Staff screen | KEEP |
| coach_market | 81 | 105 | 117 | Coach hiring, sacking, retirement, approaches | KEEP |
| coach_pathway | 57 | 5 | 5 | Retired players becoming coaches | KEEP |
| coach_effects | 36 | 9 | 8 | What coaching does | KEEP |
| career_ui | 415 | 77 | 75 | Menu, save flow, hub, sheets fit, type roles, real taps | KEEP |
| potential | 52 | 5 | 8 | POT rules, youth pace, pick values | KEEP |
| ratings | 39 | 3 | 4 | Overall rating model | KEEP |
| ai | 38 | 91 | 71 | Rival clubs' drafting, selection, training | KEEP |
| training | 144 | 40 | 52 | Plans, stat guide, projects, teaching | KEEP |
| selection | 54 | 8 | 9 | Picking 22, rucks, named side, synergies | KEEP |
| matchup | 282 | 79 | 98 | Opponent facts, hub, finals path, poster | KEEP; retire no-digit checks when the match-up gate ships |
| matchday | 1015 | 66 | 170 | Feed, breaks, full time, call panes, the match screen | KEEP; move its club-ink checks to nameink |
| calls | 8 | 20 | 10 | Main ruck default, play-through order, tag stays | KEEP |
| roles | 345 | 12 | 20 | Roles, wings, taggers, captaincy and culture screens | KEEP; retire no-digit checks per gate |
| injuries | 31 | 86 | 98 | Injury rate, healing, tribunal, played = simulated | KEEP |
| awards | 50 | 52 | 42 | Brownlow, Norm Smith, B&F, comeback records | KEEP |
| achievements | 153 | 52 | 41 | Club achievements | KEEP |
| contracts | 293 | 119 | 237 | Contracts, free agency, trades, picks, reasons | KEEP |
| league | 60 | 56 | 76 | Difficulty dials, trade margin, news | KEEP |
| club | 255 | 170 | 123 | Board, morale, event cards, backing, firsts | KEEP |
| match_game | 435 | 453 | 566 | Match engine rules: legs, calls, rucks, set shots, tagging | KEEP, SPLIT for parallel shards |
| pressure | 21 | 58 | 65 | Pressure acts and rating | KEEP |
| workload | 50 | 22 | 19 | Workload budget and recovery | KEEP |
| fitness | 68 | 15 | 10 | Season conditioning plans and screens | KEEP |
| preseason | 222 | 150 | 277 | Pre-season blocks, time trial, AI parity, taps | KEEP |
| plan_know | 96 | 60 | 116 | Plan familiarity, drilling, fade | KEEP |
| planpane | 152 | 40 | 7 | Game-plan pane and calls record | KEEP (split from matchday to stay under the 900 s limit, #755) |
| match_visual | 280 | 346 | 316 | Live match view is presentation only; discs, labels, shapes | KEEP |
| match_motion | 34 | 130 | 66 | Call shapes visible, motion limits, ball-up spacing | KEEP |
| league_balance | 23 | 231 | 157 | Smoke test of the `tools/balance` developer harness | MOVE to the Audit workflow or main pushes only; its draw check repeats finals |
| calibration | 17 | 131 | 88 | 400 seeded matches against real 2026 averages, within 7% | KEEP (realism is the director's call) |
| balance | 13 | 163 | 108 | Three seasons: no rating inflation, stars survive | KEEP |
| stats | 540 | 10 | 53 | Season stats, leaderboards, awards races, table recipe | KEEP; loosen two pixel bands (section 3) |
| story | 716 | 30 | 331 | Story deck, trust, arcs, finals cards, save round trip, dice untouched | KEEP; turn the four-word-phrase check into a warning |
| back_nav | 393 | 140 | 245 | Back on every screen by click, Escape, mouse and Android Back | KEEP (found four defects, #670) |
| scroll | 154 | 30 | 18 | Scroll keeps place, swipes start on buttons | KEEP |
| family | 107 | 15 | 6 | Family ties on profile and draft card | KEEP |
| keyboard | 461 | 30 | 14 | Phone keyboard keeps focus and text, web keyboard | KEEP |
| nameink | 21 | 10 | 5 | Names in running text wear club ink, readable on dark | KEEP; absorb matchday's ink rules |
| rowgap | 182 | 60 | 49 | Figure beside its name, match sheets on one page | KEEP |
| trainrep | 100 | 60 | 44 | Monthly training report, switch off, taps | KEEP |
| international | 1873 | 20 | 77 | International prospects over 150 seeded years | KEEP |
| namelink | 237 | 30 | 7 | A name opens the profile by real touch; drag still scrolls | KEEP |

Big counts are loops, not breadth: `draft` has 156 `_check` call sites and reports 7,901 checks, because
per-item asserts sit inside loops (`tests/test_draft.gd:228-230`, `tests/test_intake.gd:52-54`). One check can be one
player. That is harmless for coverage. It only hurts the floor arithmetic (section 4).

## 2. Duplicates

| Same assertion | Location A | Location B | Action |
|---|---|---|---|
| A draw gives both clubs two points on the ladder | `tests/test_finals.gd:402` | `tests/test_league_balance.gd:187-189` | Drop B (leaves PR CI with league_balance anyway) |
| Every club's ink reads at 4.5:1 on the dark page | `tests/run_nameink_tests.gd:112` | `tests/run_matchday_tests.gd:1407` | Keep one in nameink |
| A name is never painted in a red club's raw ink | `tests/run_matchday_tests.gd:1440,1458,1480` | `tests/run_nameink_tests.gd:64-66` (markup) | Move the matchday trio into nameink |
| Same seed, same match | `tests/test_match_game.gd:99,588` | `tests/test_match_visual.gd:201` | Cheap (one match each); leave |
| Build number has one source | `.github/workflows/tests.yml:98-101` (plan) | `tools/run_tests.sh:182-190` (extras) | Run it once, in plan |
| Floors written twice | `tests/expected_checks.txt` | `tests/README.md:37-80` "Floor" and "CI s" columns (stale: draft 7807 v 7808, career_ui 280 v 309, matchday 504 v 552) | Delete the README columns |
| Tap targets of 44 px | `tests/run_matchup_tests.gd:258`, `run_matchday_tests.gd:3053`, `run_stats_tests.gd:893` | UI review "sweep" (`.github/workflows/ui-review.yml:8-16`) | Keep both: the sweep is information, not a gate |

Season simulations are the real overlap in time, not in assertions: `save`, `career`, `balance`, `expansion`,
`coach_market` and `contracts` each play their own full seasons (20, 19 and 26 season-loop sites in
`test_save.gd`, `test_career.gd` and `test_contracts.gd`). They assert different things. Sharing one simulated
career between suites would save minutes but would couple their failures. Splitting the suites for parallel
shards gets the time back with less risk.

## 3. Fastidious checks: catches against false alarms

| Check | Where | Real defect caught | Failed on harmless change | Recommendation |
|---|---|---|---|---|
| No two finals cards share a four-word phrase | `tests/test_finals_cards.gd:822-844` | None found: `git log -S` shows only the commit that added it (#709) | #815 story suite red twice (`intl_usa_visit`/`finals_week_off`, lead handoff line 43) | Loosen: print the clash as a warning for the writer, fail only for two cards that can show in the same week |
| No digit on a screen or line (21 sites) | `run_career_ui_tests.gd:771,796`; `run_draft_ui_tests.gd:555`; `run_matchday_tests.gd:198,308,375`; `run_matchup_tests.gd:83-85,102`; `test_matchup.gd:53,295`; `run_roles_tests.gd:80,703,730,966`; `test_coaches.gd:291,298`; `test_story.gd:174,286,2107,2262`; `test_draft.gd:672` | They enforced the old "no number vomit" reading | Contradict bible §4 as changed 2026-10-18 (#812, #814); #817 deleted the odds lint for the same reason | Retire each one in the PR that ships its gate's odds. Keep the non-gate ones (Staff rows, form line) until the director rules |
| PC quarter break fits 608 px with 8 px spare | `run_matchday_tests.gd:1535` | Yes: the break needed 613 of 608 px for Fremantle (#755, d1cd23a0 message) | None found | Keep "fits"; the extra 8 px margin is a judgement, keep unless it fails without a visible fault |
| "Change" sits 0-14 px after its sentence, every gap within 4 px | `run_matchday_tests.gd:3348-3378` | Written with the layout in #795; no later catch | None found | Keep (one PR old, encodes the shown layout) |
| Stats table 700-900 px wide, club column 170-200 px | `run_stats_tests.gd:1055-1060` | None found (`git log -S` shows only #509) | None found | Loosen to "no clipped text, no empty column": the sweep measures clipping. Director's say (layout he approved) |
| Adelaide's name colour is exactly FFC83A | `run_nameink_tests.gd:113` | Protects the director's Crows-gold decision (#771) | None | Keep |
| Exact sentences (58 `== "..."` with 6+ words, 50 long `contains`) | most in `test_story.gd`, `test_matchday.gd`, `test_contracts.gd` | Protect approved copy | Cost one line per copy edit | Keep |
| Font sizes are UiKit roles | `run_career_ui_tests.gd:2101-2128` | Source scan, cheap | None found | Keep |
| Check-count floors | `tools/run_tests.sh:97-112` | Section 4 | Section 4 | Replace |
| Timing evidence under 30 days old | `tools/check_ci_balance.py:23-25` | None: the date was moved 2026-10-06 to 2026-10-14 with no new run (#755, d1cd23a0; `source_run` still 37460575183) | Each new suite types in its own timing: 17 of 53 suites were added after the cited source run 37460575183 (2026-10-06); file story 30 and save 33 against real 331 and 586 | Drop (section 5) |

## 4. The check-count floor system

**What it is.** Each suite prints "N checks". `tools/run_tests.sh:97-112` fails the suite when N is under the base in
`tests/expected_checks.txt` plus every `tests/floor_deltas/*.txt` delta. `tools/test_run_tests.sh` proves that a short or
unfloored suite fails.

**What it was built to catch.** Under machine load matchday ran 290 of 293 checks and still passed
(`docs/SYSTEM_REALITY_AUDIT.md:425-431`). The same change added `--fixed-fps 60`, which fixed that cause outright.

**What has actually caught silent truncation.** The script-error rule (`tools/run_tests.sh:90-93`, #46, 2026-09-28)
found three suites cut short on main (save 36 to 49, intake 511 to 2158, club 44 to 48). The floor did not.
Searching every commit message and doc for "went missing" finds one floor failure, and it was a false alarm:
c6f35800 (finals floor set from "one lucky run").

**What it costs.**
- 114 of 162 merged PRs from #643 to #814 edited `expected_checks.txt` or `floor_deltas`.
- 145 delta files sit on main. They have never been folded: `tools/fold_floor_deltas.sh` has never been run on main.
- 63 commits mention floor arithmetic in their subject, for example 39aec51a "count the pending floor delta once,
  not twice" and 189a463f "the safe lower bound until CI counts".
- Tonight #810 (+33) and #806 (+51) both absorbed the same 31 uncounted checks. Main went red at 7,870 run against a
  7,901 floor, every open PR failed shard 4 until hotfix #822, and three builder lives went on floor arithmetic
  (lead evidence; lead handoff lines 45, 61, 93).
- The written rules disagree. `.claude/skills/afl-godot-tests/SKILL.md:61-64` says "raise only that suite's line";
  `tests/floor_deltas/README.md` says add a delta file. Tonight's rule (lead handoff line 93: "a delta must equal
  the branch's OWN new checks, counted from the test code") cannot be followed in a loop suite: 156 call sites in
  `test_draft.gd` produce 7,901 checks.

**The simplest replacement that keeps the catch: count test functions, not assertions, and keep the count in the
suite's own file.**
1. Each `tests/test_*.gd` `run()` calls its tests through one helper: `_t("_test_rules")` instead of
   `_test_rules()`. The helper records the name and fails if the function made zero checks. That catches an
   empty loop or an early return.
2. After `run()`, the thin runner compares the recorded names with every `_test_*` method in the script
   (`get_method_list()`). A test function that exists but is never called fails loudly by name. Inline runners
   (15 suites, among them `run_back_nav_tests.gd` and `run_assets_tests.gd`, have no `_test_` functions) rename their
   sections to `_test_*` and use the same helper.
3. The summary line becomes "Draft tests: 20 of 20 functions, 7901 checks, 0 failures". `tools/run_tests.sh`
   fails on "functions short", keeps the timeout, the "no result" and the script-error rules, and keeps `SKIP:`.
4. Delete `tests/expected_checks.txt`, `tests/floor_deltas/`, `tools/fold_floor_deltas.sh`, and the floor columns
   in `tests/README.md`. Point `tools/test_run_tests.sh` at a fixture suite that defines an uncalled `_test_x`.
5. Correct `SKILL.md:55-64` and `tests/floor_deltas/README.md` in the same PR.

Migration is mechanical (one `sed` per file for step 1) and touches no assertion. What it gives up: a function
that loses some checks but keeps at least one (for example a loop over 18 clubs that drops to 16). The answer is
a size assertion before the loop, and most of those loops already have one (`test_draft.gd:221`). A PR that
adds a test edits only its own test file, so two PRs never conflict over a shared count. Function count changes
rarely, and only in the file being edited.

## 5. CI process

**Wall-clock per PR today.** plan 7 s, then preflight (matchday alone) 335 s, then the slowest shard, then test 8 s
(run 39121980374). The slowest shard on run 39119858455 was shard 3 at 1,902 s against shards of 615-1,151 s. A
green PR therefore takes about 37.5 minutes plus queue time. Main push run 39119858455 took 34.4 minutes with no
preflight.

| Step | Paid for itself? | Evidence | Verdict |
|---|---|---|---|
| plan: docs-only and draft skip | Yes | #814's run 39120276633 took 2.4 min; #823's run 39122973509 took 18 s | Keep |
| plan: every suite in a shard (`tools/check_ci_shards.sh`) | Cheap guard, no recorded catch | 74 lines; reads `ci_shards.txt` with no `\r` strip and the repo has no `.gitattributes` (the CRLF gotcha) | Replace with an automatic plan (below) |
| plan: must-read doc sizes | Yes, director rule | `tests.yml:94-95` | Keep |
| plan: one build number | Yes, director decision #799 | Runs twice (section 2) | Keep once |
| plan: shard balance gate, 120% of mean, timings under 30 days | No | Gate passes on estimates while the real imbalance was 172% (1,902 s against a 1,106 s mean, run 39119858455); the date was moved without measurement (#755); 17 of 53 timings postdate the cited source run | Drop; keep only the observed-imbalance warning (`check_ci_balance.py:34-50`) |
| preflight: matchday before any shard | Saves runner minutes only when matchday fails | 335 s on the critical path of every PR run (39121980374); shards already stop early on PRs (`tests.yml:155,182`) | Replace with the compile preflight of #816 (3 s measured) inside plan |
| shards | Yes, the tests | | Re-plan from real timings |
| extras: dataset, seeds, export data, harness, offline promise | Yes, off the critical path (95-103 s, in parallel) | `validate_data.py` and `check_export_data.sh` guard shipped data | Keep; the harness self-test goes with the floors |
| test: required aggregate | Yes | Branch protection | Keep |
| UI review sheets and sweep | Yes, information only | The sweep found the stats `#` header and ladder rows under 44 px (`run_stats_tests.gd:872`, #819) | Keep; it competes for runners (lead cancelled three sheet runs at 21:05) |
| 900 s suite timeout | Hangs read as timeouts | Three PRs in one night hung to 900 s on an autoload class (`.claude/skills/afl-godot-tests/references/learnings.md:10-22`) | #816's compile preflight turns each hang into a fail within seconds |

**Automatic shard plan.** The plan job reads the last green main run's `suite-timings-*` artifacts (or a JSON that
main refreshes after each green push). It gives a suite with no timing 60 s and splits by longest-first. That
removes `tools/ci_shards.txt`, `check_ci_shards.sh`, the hand-kept timings, the 30-day rule and the 120% gate:
four of the five registries a new suite needs. Hand layouts from tonight's numbers, matchday included because
the preflight goes:

- 5 shards, about 1,070 s each: `save club balance league match_motion stats roles chronology intake_ui namelink` /
  `match_game matchday calibration career_ui expansion training workload scroll fitness potential ratings` /
  `career contracts plan_know draft_ui pressure rowgap intake keyboard selection family` /
  `story back_nav league_balance injuries ai draft trainrep awards assets coach_effects nameink` /
  `match_visual preseason coach_market matchup international coaches finals achievements calls planpane coach_pathway`.
- 6 shards: about 890 s each. 8 shards: about 650 s each, which needs `save` (586 s) and `match_game` (566 s)
  split first.

One run's timings vary between runners. Averaging the last three green main runs keeps the plan steady.

## 6. Local process rules: evidence either way

| Rule | Source | Catches | Cost | Verdict |
|---|---|---|---|---|
| Run `tools/run_tests.sh` before pushing | `CLAUDE.md` line 6 | The skill already narrows it to touched suites (`SKILL.md:26-28`) | The full set is 89 runner-minutes; tonight there is no local Godot at all (lead handoff, "NO GODOT ORDER") | Reword CLAUDE.md to "the suites you touched; CI runs the rest" |
| Real taps for touch flows | `CLAUDE.md` Verification | #805: "A draftable player is on screen for the click" caught the #806 reason line pushing the row off screen (lead handoff line 61); `back_nav` found four defects (#670) | One `Tap.tap` per flow | Keep |
| Script error fails the suite | `tools/run_tests.sh:90-93` | Three truncated suites on main (#46) | None | Keep |
| W7 review by a fresh builder for save or sim changes | lead handoff lines 32-33 | #684 migration fix 93c64d23; #806 fixes 1db899a6 (a reason resting on a hidden rating, the free-agency list not resetting, drafts differing with the switch) | One builder life per save/sim PR | Keep |
| Lint captures before the lead sees them | `token_rules.md` rule 17 (#809, today) | Too new to judge: no capture has run under the no-Godot order | Seconds per capture | Keep; review after a week of use |
| Floor delta "counted from the test code" | lead handoff line 93 | None | Cannot be done in a loop suite | Retire with section 4 |
| Merge main before the one push; union the registries | lead handoff lines 33-34 | Prevents red merges | One merge per squash, mostly for registries | Shrinks once floors and shard lists go |
| Change approach after two failed fixes | `CLAUDE.md` Verification | ovalcalls7 stopped patching the ball-up spacing (lead handoff, #800) | None | Keep |

## 7. Proposals, ranked

Minutes are per CI run (wall-clock) or per builder life (builder time). One builder life is about one PR and one to
three CI runs.

| # | Proposal | Saves | Risk | Who decides | Recommendation |
|---|---|---|---|---|---|
| 1 | Re-plan the five shards from real timings now; then make the plan automatic and drop the 120% gate and the 30-day rule | About 14 min per CI run (31.7 down to about 18) | None to coverage; one run's timings vary, so average three | Lead | Do first: one PR touching `tools/ci_shards.txt` and the timings JSON |
| 2 | Replace check-count floors with "every test function ran and made a check" | About 10 builder minutes per test-adding PR (114 of 162 PRs); no more #822-style red main | Partial loop shrinks need a size assertion | Lead | Do second, one mechanical PR |
| 3 | Drop the matchday preflight; put #816's compile check in plan | 5.6 min per PR run; a hang becomes a fail in seconds instead of 15 min | More runner minutes burnt when matchday fails | Lead | Do with #1 |
| 4 | Retire the 21 no-digit checks on decision gates as each gate ships | One red CI cycle (about 38 min) per gate PR that trips one | None: the rule is reversed | Lead for gates; director for non-gate screens | Brief each gate lane to delete its check |
| 5 | Move `league_balance` to the Audit workflow or main pushes only | 157 runner-seconds per run | A harness break is found on main, not the PR | Lead (developer tool) | Do |
| 6 | Split `save` and `match_game` into two suites each | Unlocks 8 shards, about 11 min per run | None | Lead | Do after #1 and #2 (registration is cheap then) |
| 7 | Turn the four-word-phrase check into a writer's warning | One red story run per new card batch (#815, twice) | Two cards could repeat a phrase in one season | Lead, tell the director | Do |
| 8 | Add `.gitattributes` (`*.txt *.sh text eol=lf`) | The CRLF class of failures in `check_ci_shards.sh` and the floor reader (`run_tests.sh:99` strips no `\r`) | None | Lead | Do |
| 9 | Fold duplicates (draw rule, club-ink rules into nameink, version check once, README floor columns) | Seconds; fewer places to edit | None | Lead | Do opportunistically |
| 10 | Loosen the stats column pixel bands to "no clipping" | One false red per table tweak | A layout he approved could drift | Director | Ask only if it fires |

Not proposed: dropping `calibration` or `balance` from PR CI. They cost 196 s off the critical path once
re-planned, and they guard realism, which is the director's to call.

## What this audit did not do

No Godot run and no suite profiling: per-function timings inside `save` (586 s) and `career` (468 s) are the next
measurement. Timings come from one green main run (39119858455) and one PR run (39121980374), using 4 gh calls.
PR bodies were not read. Catch evidence comes from commit messages, `git log -S`, the lead handoff and the docs.
A catch recorded nowhere would be missed.
