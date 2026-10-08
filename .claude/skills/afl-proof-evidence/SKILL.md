---
name: afl-proof-evidence
description: How to prove a change to this game actually works before calling it done - picking the right evidence for the kind of change, testing taps the way a phone delivers them (tests/tap.gd), pinning seeds, proving the intended art or animation ran, separating what a machine can check about audio from what needs ears, and saying what wasn't exercised. Use it when finishing any feature or fix, writing a PR's evidence section, adding a test, or about to claim something "works", "looks right" or "sounds fine".
---

# Proof before "done"

An agent's "it works" isn't evidence; what the game did is. The common false
passes in a game are: a test that calls a button's handler while a sheet covers
the button on a phone, a screenshot of a fallback animation, a check that
passes on a lucky seed, and a measurement reported as a listening verdict. The
practices below are the director-approved ones (#291, ROADMAP §0.4a "Proof
practices").

## Pick evidence that fits the change

| Change | Evidence that counts |
|---|---|
| Data, copy or docs | The touched suites; nothing more |
| Simulation rule or balance | Seeded, paired audit (same seeds before/after), distributions and the calibration suite; never one favourite match |
| UI flow | Real taps through `tests/tap.gd`, layout at 320/360/430 wide, Android Back |
| Visual or art | A capture at game scale and phone width; then the director's approval (§9.5) - green CI isn't enough |
| Animation or vignette | The `assets` suite (frames vs layout, moves played through) plus a short capture for the director |
| Save or lifecycle | Reload, the failure paths, an old save; plus a W7 review (see afl-lifecycle-review) |
| Music or sound | The `assets` suite's checks; the director listens |

Scale the effort to the change: a roster fix doesn't need a movie, and an
animation change does.

## Taps, not handler calls

`emit_signal("pressed")` proves the handler's logic. It can't show a player's
tap reaching the button. For anything that stands for a tap:

```gdscript
const Tap := preload("res://tests/tap.gd")
var why: String = await Tap.tap(button)     # "" when the button got it
_check(why == "", "A finger's tap on Change reaches it (%s)" % why)
```

It sends a touch at the button's place on screen through the engine and GUI,
scrolls a ScrollContainer to it first (as a player would), and reports what
took the tap instead. Desktop touch emulation isn't a phone: say so.

## Seeds

Anything that starts a season or draft in a test sets `GameState.replay_seed`;
a `MatchSim` gets an explicit seed. A check that fails once in a while is
telling you about an unpinned seed.

## Prove the intended thing ran

- **Art:** assert the asset the game used. The `assets` suite checks every
  figure frame in `VignetteFigures.gd` against the sheets (in the sheet, no shared
  cells, a figure in each frame, the colour mask on the figure to within 1 px).
- **Motion:** with `StoppageVignette.log_frames = true`, every figure frame a
  vignette asks for is logged by `StoppageVignette.figure_frame`; a frame past
  the end of a move would otherwise freeze silently.
- **New checks prove themselves:** show a new check failing on a known-broken
  input (a covered button, a blank frame, a misplaced mask, a clipped track)
  before trusting its passes.

## Audio: measure what you can, don't claim what you can't

A machine can check that tracks load and are in the playlist, peak level and
clipping, loudness spread, leading silence, and pause/resume/Mute. It cannot
hear muffled 11 kHz mono, repetition or mood. Report the measurements and hand
the listening to the director; never write "sounds fine".

## Write the evidence down

In the PR body:

- **Evidence:** the seed/scenario, what input was delivered, the result, the
  suites and counts, and the capture or audit artifact by path or run id.
- **Not exercised:** device touch, real-time performance, listening, other
  screens - whatever you didn't cover, explicitly. "Insufficient evidence" is an
  honest verdict; an unavailable phone check is not a pass.

If two or three similar fixes have failed, change the evidence before writing
another fix: a minimal reproduction, the last good commit, the runtime state,
the event path.

## Learnings

Proven findings for this project live in `references/learnings.md`. Read it before using this
skill; add to it only what proved effective, with evidence.
