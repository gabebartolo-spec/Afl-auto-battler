---
name: afl-lifecycle-review
description: The W7 semantic review for changes that touch a career's lifecycle - the save schema, season rollover or off-season, shared simulation rules (MatchSim, Ratings, Traits), recruitment (draft, trades, free agency, contracts) or player identity (ids, names, club moves, retirement). Use it when you are asked to review such a PR, when you open one (to write its review packet), or when a change you're making turns out to reach one of these areas, even if nobody said "W7".
---

# Lifecycle review (W7)

A career here runs for decades: players are drafted, traded, injured, retire
and come back as coaches, and the save carries all of it across rollovers.
Two changes can each pass their tests and still be wrong together - a
development project survived a club move until a review caught it. Tests check
what their author thought of; this review checks the consequences nobody wrote
a test for.

One reviewer, not three. The reviewer judges the contract and its
consequences, not the PR's explanation of itself.

## If you're the author: the review packet

Put this in the PR body (ROADMAP §0.4a, W7):

- **Transitions affected** - which of the list below the change touches.
- **Invariants** - what must stay true across each (e.g. "a retiring player is
  never offered in free agency", "an old save with no `.bak` still loads").
- **Evidence** for each invariant: the test, audit or reproduction that shows
  it, and anything not exercised.

## If you're the reviewer

1. **Read the packet, then put it aside.** Work out the affected transitions
   from the diff yourself; the packet may miss one.
2. **Walk the transitions.** For each that the changed state passes through,
   ask whether it carries over, resets or transfers correctly:

   | Transition | Typical questions |
   |---|---|
   | Save and reload | Is the new state saved, and an old save without it loaded with a sane default? Does a failure mid-write leave a loadable career? |
   | Season rollover / off-season | Is it aged, reset or carried over at the right step, once? |
   | Club move (trade, free agency, delisting) | Does it follow the player, stay with the club, or get cleared? |
   | Retirement (and coaching pathway) | Removed from lists, markets and selection; history kept? |
   | Injury | Does selection, workload or value treat an injured player consistently? |
   | Draft and expansion clubs | Do new players and new clubs get the field initialised? |
   | Name change / real-names toggle | Is identity keyed by id, not display name? |

   For a rule keyed on a player field (height, age, role, a trait), also check
   that the players the game *generates* - draft classes, expansion lists,
   rookies - actually reach the new thresholds. A rule for small forwards
   means nothing if generated forwards are never small (#286's review found
   exactly that).
3. **Check parity and determinism.** The AI clubs get the same rules and
   information as the player's club (no psychic or exempt opponents). Seeded
   runs stay reproducible; nothing new reads the clock.
4. **For simulation changes, check calibration.** Run `calibration` and the
   touched suites; for scoring or rate changes, ask for (or run) a seeded,
   paired audit (same seeds before and after) and look at distributions, not
   one match.
5. **Prove what you suspect.** A suspected defect becomes a small test or a
   scripted reproduction before you report it - "I think" is not a finding.

## The report

Post the review as a comment on the PR (the record), and send its owner a short
message with the verdict and any defect (the lead too if it blocks a merge). Per area: **fine**,
or **defect** with the reproduction, what goes wrong for the player, and the
smallest fix you'd suggest. Name what you didn't check. Don't rewrite the PR
yourself; open a fix PR only when the owner or lead asks. If the PR has
already merged (a review after the fact), a defect goes straight to a small fix
PR with the reproduction as its test, since there's nothing left to request
changes on. Keep it short: the
owner needs decisions and repros, not a retelling of the diff.

## Learnings

Proven findings for this project live in `references/learnings.md`. Read it before using this
skill; add to it only what proved effective, with evidence.
