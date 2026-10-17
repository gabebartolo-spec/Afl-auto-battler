#!/usr/bin/env python3
"""The odds lint must catch odds and let football through (P-62). Run by tools/run_tests.sh."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_player_facing_odds as lint

SHOULD_FAIL = [
    "A 70% chance of a goal",
    "%d%% to score",
    "Rehab: training %d%% off until then.",
    "There is a 30 per cent chance he plays",
    "Odds of 3 to 1 for the flag",
    "The chance of winning is %d",
    "probability 0.4",
    "Boosts your odds by %.1f",
]
SHOULD_PASS = [
    "{name} has taken his chance",
    "The double chance has done its job.",
    "He's done everything to get right. The medical staff say he's a chance, no more.",
    "Push two up the ground; thinner behind the ball",
    "%d goals, %d behinds",
    "Qualifying final",
    "One percenters",
    "Training is cheaper until then.",
]

failures = 0
for s in SHOULD_FAIL:
    if not lint.offending(s):
        print("missed: " + s)
        failures += 1
for s in SHOULD_PASS:
    if lint.offending(s):
        print("wrongly flagged: " + s)
        failures += 1
# The GDScript reader: a comment and a debug print are not the player's screen.
sample = Path(__file__).resolve().parent / "_odds_lint_sample.gd"
sample.write_text('# a 50% comment\nprint("50% debug")\nvar a = "40% shown"  # tail\nvar b = "fine"\n', encoding="utf-8")
try:
    got = [s for _, s in lint.gd_strings(sample)]
finally:
    sample.unlink()
if got != ["40% shown", "fine"]:
    print("gd_strings read %s" % got)
    failures += 1
print("odds lint self-test: %d failures" % failures)
sys.exit(1 if failures else 0)
