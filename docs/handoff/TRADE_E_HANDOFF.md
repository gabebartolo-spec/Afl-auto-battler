# Trade E (long-save trade audit): handoff, 2026-10-05

Where the cloud session stopped, so a local session can pick it up. Branch
`claude/arena-game-review-mcp8ig`. Main was merged into it at `6eff920` (full
suite passed on the merge).

## Done and committed on this branch

- **Harness** (`tools/balance/dynasty.gd`, `dynasty_run.gd`):
  - Every off-season records the trade market (`snap["market"]`): each trade
    with both clubs' phases and the assets in plain terms, each club's
    tradeable picks, and a National Draft ownership check
    (`mgmt["draft_check"]`).
  - Traded players' later ratings are recorded (`snap["traded"]`).
  - New `--manage exploit` policy: offers every rival bundles of ordinary and
    older players for its best young talent.
- **Report**: `tools/balance/trade_audit_report.py careers.json ...`.
- **Fix, commit `cb654c4`.** A star in his rehab year is valued at the
  rating he comes back at.
  - What it does: `TradeValue.rating(p)` adds `Potential.REHAB_PULL` of the
    POT gap for `rehab` players. `now_rating`, `future_rating`, `fit`,
    `_bar_rating` and `contract_factor` all use it.
  - Tests: two new checks in the `contracts` suite pass (210 checks, 0
    failures). The bundles check no longer counts a rehab star as
    "ordinary".
  - **Not yet run:** the full suite on this commit. The cloud run was
    stopped at 6 of 35 suites, all passing. Run `tools/run_tests.sh`
    before merging.

## Not committed: director-approved, untested

The director chose **"Rule, 60%"**: project growth with the game's own
development rule to age 28, and count 60% of it. The same caution as for
teenagers.

- The change is in `docs/handoff/trade_e_growth.patch`: `TradeValue.future_rating`
  plus the `GROWTH_COUNTED := 0.6` constant.
- Apply it with `git apply docs/handoff/trade_e_growth.patch`.
- Then run `tools/run_tests.sh contracts`, then the full suite. Fix any
  checks that assumed the old model.
- Then re-measure (next section).
- Why: the old model counted no growth past 24½, but `Potential.growth`
  closes 15-22% of the POT gap every year to 28, with a 2-point minimum
  step. A 78/90 22-year-old was valued as an 82 but becomes about 90.
  - Probe, listed players, growth credited by age:

    | Age | Trade model | Development rule, 3 seasons |
    |---|---|---|
    | 22-25 | 0-3 points | 4-6 points |
    | 19-20 | agrees | agrees |

  - Deals still seen after the rehab fix included rebuilding Adelaide giving
    a 78/90 22-year-old for an 86/83 31-year-old, a 77/74 30-year-old and a
    second-round pick.

## Measurements so far

Careers: seeds 301-306, `upside` drafter, 10 seasons each. Outputs were in
the cloud scratchpad and are lost, so re-run them if needed.

```
godot --headless --path . --script tools/balance/dynasty_run.gd -- \
    --seeds 301,302,303 --policy upside --seasons 10 --manage exploit --out ex_a.json
python3 tools/balance/trade_audit_report.py ex_a.json ex_b.json
python3 tools/balance/dynasty_report.py --compare none.json list.json exploit.json
```

**The rivals' market** (your club on autopilot; 54 off-seasons, before and
after the rehab fix): healthy. Every brief §9 check passes.

| Check | Result |
|---|---|
| Rival trades per off-season | 2.9 (1-3), never zero |
| Who trades with whom | mostly contenders and builders buying from rebuilders, and builders from contenders |
| Contenders selling a starting star | none |
| Rebuilders spending a top-nine pick on a veteran | none |
| Most first-round picks one club holds for one draft | 3 |
| List sizes | 32-44 (the limit is 44) |
| Draft slots checked | about 2,710, none with the wrong club |

- **"Repeat winners"** are rebuilders selling 30-year-old stars to
  contenders for two first-round picks, as designed.
- **Minor:**
  - Building clubs sometimes pay a #10 pick for a 67-68-rated 24-year-old.
  - One rival was 0.1% over the cap for one season out of 1,080. The
    likely cause is that re-signing at the list minimum ignores the cap.

**The exploit policy** (junk for young stars):

| | Before the rehab fix | After the rehab fix |
|---|---|---|
| Accepted deals | 12 of about 6,500 tries | 5 |
| Seeds 301-303, late-career strength rank | 1.7-6 | 8-10, the same as plain list management |

- Before the fix, 4 of the 12 deals were the same rehab star (62/92, aged
  23, then rated 86-88), in four of the six leagues.
- **Still open: seeds 305-306.** The exploit club reached #1 and won flags
  with no trades at all after the fix, which suggests that contracts and
  free agency compound over a long save.
  - The no-trade control for seeds 304-306 (`--manage list`) was started
    but not finished. Run it to confirm.
  - That is a free-agency question (main's roadmap already lists
    "free-agency advantage" as a TODO), not Trade E.

## Next steps

1. Run the full suite on `cb654c4` (the rehab fix).
2. Apply the growth patch, test it, and commit it.
3. Re-run exploit and none (seeds 301-306, 10 seasons), plus the list
   control for 304-306. Compare with the numbers above.
4. Write up Trade E (a section in `docs/COMPETITIVE_BALANCE.md`, or its own
   doc) and update the roadmap's trade-valuation item and §10 log.
5. Push, then open the PR to main and merge when CI is green (the director
   asked for push and merge).
6. Still waiting on a director decision: main recorded "League Draft board
   shows scouted estimates" (TODO). This branch already cut the rival
   scouting error to 0-4 for the same first-season edge. Doing both may
   overcorrect, so ask which to keep.

## Status at archive (2026-10-05, 09:30 UTC)

- **PR #228** (this branch to main) is open and **not merged**.
- **Full suite** passed locally on the rehab fix (35 of 35 suites).
- **CI failed on the merged head `4ce353e`**: one check in the matchday
  suite, "No one is ringed before you have made a call".
  - Cause: main's #221 rings the players your calls involve. This branch's
    assistant picks the loose defender (and match-up changes at the breaks)
    for you, so the rings counted his calls as yours.
- **Fix pushed after `4ce353e`, untested locally.** `MatchSim.coach_call(side,
  fwd_id)` says whether the coach made a call himself; MatchRings rings the
  loose defender and in-match match-up changes only when it is true.
- **To finish:**
  1. Run `tools/run_tests.sh matchday match_visual coach_effects`.
  2. Once CI on PR #228 is green, merge it.
