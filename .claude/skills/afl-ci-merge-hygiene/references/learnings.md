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
