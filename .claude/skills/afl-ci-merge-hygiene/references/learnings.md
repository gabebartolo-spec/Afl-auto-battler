# Learnings log

Only findings that proved effective: a triage step that found a red run's real cause, or a
habit that verifiably prevented a red or cancelled run. Each entry: `## YYYY-MM-DD · topic`,
then **Finding**, **Evidence** (PR, commit, run id), **Lesson**. Fix SKILL.md instead of
appending when a finding contradicts it; mark entries "promoted" once moved into SKILL.md.

## 2026-10-08 · a "green" run that tested nothing
**Finding:** pushing to a PR while it was still a draft gave a passing `test` check with every
shard skipped (the plan step skips game tests on drafts). Marking it ready afterwards started a
run on the old head, which the push then cancelled. Toggling ready off and on fired a full run.
**Evidence:** #506: run 37748619570 (draft, shards skipped), then 37748797312 (all shards).
**Lesson:** mark a PR ready *before* the push you want tested; read the shard results, not
just the `test` aggregate.

## 2026-10-08 · a latent main bug surfaced by an unrelated sim change
**Finding:** #484 (set shots) failed `stats`: "Every running bounce is on a run with the ball".
The cause was on main: bounces were counted from the unrounded run, but the event stored it
rounded (29.96 m credited 1 bounce, the event's 30.0 m implies 2). The PR's new RNG draws just
landed on such a run.
**Evidence:** run 37750335406; fix e56b88c8 in #484.
**Lesson:** when a check fails on a change that doesn't touch that system, look for a rounding,
ordering or seed-sensitive bug the new dice exposed, before blaming the change.

## 2026-10-08 · floors after a stacked PR merged first
**Finding:** after #467 merged, #484's own match_game checks were already on main, so the merged
floor was main's (346) plus only genuinely new checks (+1), not base + both increments (354).
**Evidence:** #484 local run counted 346; floor set to 347 with one new check; CI green.
**Lesson:** "base + both increments" assumes the increments are distinct; count the real suite
before writing the floor when one PR was stacked on another.

## 2026-10-08 · a data change reaches every seeded match test
**Finding:** #530 changed real players' opening ratings (59 injury-year players lifted). I ran
the suites I guessed it touched (ratings, matchday, calibration, balance, draft, potential,
chronology) and opened the PR while the full local run was still going. CI shard 1 failed
`match_game` (three checks), and fail-fast cancelled shards 2-5, so CI showed one suite only.
The full local run then also found `selection` and earlier `training`/`potential` red. Six
lifts at GEE and COL were enough to change who is selected, and that reshuffles every seeded
GEE-v-COL fixture in the suites.
**Evidence:** run 37808670382 (shard 1 red, 2-5 cancelled); fixes 450e376 (selection),
33aceef (training, potential), 6e26d00 (match_game); local match_game 347/0 after the fix.
**Lesson:** a change to player data, ratings or selection is a change to every seeded match:
run the **full** suite before pushing, not a guessed subset, and don't open the PR until it's
done. CI stops at the first red shard, so it's no substitute.

## 2026-10-08 · a tipped seeded check: measure before you touch it
**Finding:** of the six checks the data change tipped, none was a behaviour regression. Each was a
measurement that only held by coincidence. Crumbs were credited by the slot a player
*finished* in (a late rotation left forward Mannagh in a back's slot; 34 of his crumbs read
as a defender's). A play-through check drew 3000 picks for a player on 1.4% of them (41 v 45
against a x1.14 effect). Six live games were too few for rare moment kinds. A dual-ruck
check compared against the lowest-rated bench player instead of the last-picked one the
rule replaces. A reserves check took the first spare, the one an injury on the day calls up.
Rehab checks measured a gap the new design closes on purpose.
**Evidence:** probes with the change on and off at bigger samples (crumbs by own position: 68%
forwards; 20000 draws: 289 v 321; twelve games: five moment kinds); same commits as above.
**Lesson:** when a data change tips a seeded check, run it with and without the change on a
bigger sample first. If behaviour held, fix what the check measures (own position, sample
size, the player the rule actually reads), not its bar. Never loosen a threshold to get green.

## 2026-10-09 · back-to-back merges to main each get a verdict
**Finding:** before #525, every push to `main` shared one concurrency group with cancel-in-progress,
so quick successive merges cancelled each other (20 of the 41 cancelled runs in 150 were `main`;
several main commits were never tested). #525 gives each main push its own group (its sha) and
never cancels it. The next two merges (#533, #532) ran side by side, both in progress at once.
The floor-delta path also ran: the #525 merge itself was green and a delta file
(`tests/floor_deltas/`) is in use on main.
**Evidence:** #525; main runs efa9e508 (success), 37871766333 (5d9dd0a9) and 37871822739 (5e43b1e6)
in progress together, neither cancelled.
**Lesson:** after a burst of merges, read each main sha's own run; a missing verdict is now a
real gap, not a cancellation. Fold deltas with `tools/fold_floor_deltas.sh` when several pile up.
