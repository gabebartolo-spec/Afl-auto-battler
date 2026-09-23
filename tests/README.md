# Draft regression checks

Use the standard Godot 4.7 editor/runtime. From the repository root:

```sh
# Registers class_name scripts and imports the bundled fonts on a fresh clone.
godot --headless --path . --editor --import

godot --headless --path . --script tests/run_draft_tests.gd
godot --headless --path . --script tests/run_draft_ui_tests.gd
godot --headless --path . --script tests/run_intake_tests.gd
godot --headless --path . --script tests/run_intake_ui_tests.gd
godot --headless --path . --script tests/run_finals_tests.gd
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
recorded mid-match, each week records the right number of matches, only the
Grand Final is neutral), and that simming the series still crowns a premier.
A non-Godot mirror of the same maths runs in CI-friendly Python:
`python3 tools/intake_harness.py` (data/schema validation + a six-season
intake/development simulation over the real lists).

Both runners exit nonzero on failure. They use the shipped GDScript, not a
Python/JavaScript reimplementation.

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
