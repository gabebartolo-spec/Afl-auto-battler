# Agent status board

Read this at the start of every task. Send changes to your own line to the
low agent, who keeps this file from 2026-10-06 (other agents can't push to its branch).
The director decides; the high agent directs the agents.
_Updated 2026-10-06 (refresh 22). Since refresh 21: #303 (defensive forward), #455 (synergy short), #464 (synergy audits), #470 (snaps check as a share), #468 and #466 (docs). Since refresh 20: #438 (match view truth fixes), #445 (tactical timeline), #442 (hair overlays), #383 (trades at real volume), #439 and #450 (weather data and evidence), #452 (CI skips drafts and tool-only changes), #440 and #446 (audits), #463 (set-shot audit) and the docs PRs #459, #460 and #461 (the 2026 rules). Roadmap status lines for the merges are in the docs PR that carries this refresh._

## Temporary merge-backlog policy — director instruction, 2026-10-06

ChatGPT is managing the existing merge backlog during the Claude usage pause. Preserve all actual updates: do not delete branches, discard commits, overwrite another agent's work, lower test floors to hide missing checks, or bypass required validation.

Until this backlog pass finishes, do not launch new speculative/exploratory audits. Keep the latest required PR checks, necessary balance evidence and before/after baseline comparisons. Re-run only a demonstrated failed check or a specifically identified missing merge gate; avoid duplicate whole-suite runs on unchanged commits. Existing independent seed runs are not duplicates merely because they share a branch.

Cancellation record: capture-tool Tests run **37459603200** was superseded by conflict-resolved head checks **37462314537**; older kick-lane calibration audit **37460764077** was stopped while the newer branch-head audit **37460892048** continues. These cancellations stop execution only; source branches/commits are retained, and no completed evidence is deleted. Any distinct older calibration comparison can be resumed later if needed.

## Lanes
### Director note for Claude: CI delays are limiting playtests (2026-10-06)

The director requests high-priority consideration of CI throughput: the merge/check backlog is now materially limiting hands-on playtests. Consider further free improvements based on measured queue, setup/import and suite times. Avoid repeated full runs on unchanged code; batch fixes before pushing, use failed-job reruns only for justified transient failures, and fix reproducible failures locally before another push. Preserve all actual updates, required checks, assertions and test floors.

Codex PR #488 rebalances the existing five jobs using a complete 36-suite timing sample (longest estimated suite workload 778 → 604 seconds). It adds a required scheduling gate: every suite needs timing evidence, evidence must be refreshed within 30 days, and no estimated shard may exceed 120% of average workload. Each run preserves suite timings, and the final job warns when actual shard imbalance exceeds 135%; a noisy runtime measurement alone must not fail game validation. Claude should evaluate subsequent runs and improve this policy if it is creating unnecessary work rather than reducing waiting. This is an engineering priority, not permission to bypass validation.

| agent (session) | owns |
|---|---|
| high ("high effort tasks - Boss") | lead: direction, task assignment, synergy/position work |
| medium ("medium effort tasks") | medium tasks, measured audits, this board, team information flow |
| low ("low effort tasks") | CI and merges, the merge queue, low-effort tasks, effort tags |
| art ("art agent") | vignette figures, guernseys and shorts, player appearance, asset pipeline; now: ARD-M8-007 broadcast family migration (in progress) |

## File claims (don't edit another agent's claim; message them)
| agent | files | until |
|---|---|---|
| high | lead: assigns and directs; current branches as listed under Open PRs | ongoing |
| medium | STYLE-01/02/04/05/06 engineering in `UiKit.gd` and the touched screens, landing order in the style inventory | after the director approves the art agent's dark-slice sheet |
| medium (later) | MatchSim no-presentation perf mode | check with high first |
| low | none now (`.github/workflows`, `tools/ci_shards.txt`, `UiKit.scroll` and the Training-row fix #277 are all merged); STATUS.md and the merge queue | ongoing |
| art | `BroadcastVignette.gd` (draw functions only; `pick_kind`, `DURATIONS` untouched); `VignetteFigures.gd`, `assets/vignette/figures_*.png` (sheet being regenerated); `StoppageVignette._draw_figure`; `tools/visual/capture_appearance.gd`, `capture_guernseys.gd`, new `capture_broadcast.gd`; standing: `figure.gdshader`, `clubs.csv` guernsey column, `GameDB.club_guernsey`, `player_appearance.csv`, `Appearance.gd`. Next, in order: `AwardWinnerVignette.gd`, `MediaConferenceVignette.gd` | M8-007 migration |

## Waiting on the director
Asked of the director one decision at a time (team rule 5). Open now:
- #303 defensive forward: the director said merge as built (forwards only); it waits on medium's sync with main. #449 match-day weather (a draft; the lead captures after a local run).
- #385 club marker A: approved, merge on green once its owner syncs.
- Nothing else open: #438, #442, #445 and #383 are merged.

**Own-words confirmations:** none open.

**Decisions made, being built:** synergies (widen the player spread; show "N short" on Team selection), the ruck/DEF rework after #393's revert, match-day weather (#449). All recorded in ROADMAP §9.1.

## Merge queue (low agent runs it: green CI on the exact head + clean against main)
- Merged today: #438, #445, #442, #383, #440, #446, #463 and the docs PRs. In the queue, on green: #458 (ruck rework, lead's W7 on the PR), #455 (synergy short), then #303 after its sync.
- #385 (approved) waits on its owner's sync with main; #303 conflicts in `MatchSim.gd` and needs medium; #368 (kit options, a draft being rebuilt by the art agent) needs its owner.
- Gates: no appearance PR without the director's explicit approval in the PR or chat; no PR touching save, rollover, shared sim, recruitment or identity without a reviewer's comment on the PR.

## In progress
- **Lead:** match-day weather (#449); the ruck rework (#458).
- **Medium:** #303's sync; #455; the synergy decay audits (#464 and #465, drafts).
- **Art:** the kit-options rebuild (#368).
- **Low:** the merge queue, STATUS, roadmap status lines, the set-shot audit baseline (run dispatched on main) and the synergy-count tables for #464 and #465.

## Open PRs and dependencies
Checked 2026-10-06 about 11:30 UTC. CI is queued behind the audits on most of these.
| PR | owner | CI | mergeable | waits on |
|---|---|---|---|---|
| #474 capture.yml | lead | queued | clean | CI; merges first (a dispatch workflow only works from main) |
| #465 draft classes at real list proportions | medium | green (rerun on main queued) | clean | CI on main, then low merges |
| #469 the Sherrin ball | art | green | clean | the director's own words on the PR |
| #472 pitch AA (step 1) | medium | rerun queued | clean | CI; the director said "Keep it" |
| #478 whole-game AA | medium | queued | stacked on #472 | #472 first, then retarget to main; director approved |
| #476 idle-audit tool | medium | queued | clean | CI |
| #458 ruck clearances | medium | queued | clean | CI (synced after #470) |
| #385 club marker A | medium | queued | clean | CI; director approved |
| #475 the two demonstrations | lead | queued | clean | CI and the director's look |
| #471 set shots in the match view | lead | queued | clean | the director's look; held |
| #467 set shots (sim) | medium | green | clean | the lead's W7; draft |
| #477 perf baseline and roadmap lines | low | queued | clean | CI |
| #462 intercepts by zone | lead | queued | **conflicting** | the lead's sync and audits; held |
| #449 match-day weather | lead | draft | **conflicting** | the lead's sync; calibrated, draft |
| #473 weather look | art | green | clean | draft, after #449 |
| #368 kit options | art | draft | **conflicting** | the art agent's rebuild |

## Pending director decisions
- Difficulty: autopilot slides to rank 18 by year 5; routine contract work holds about 6th; flags need trading (0 of 40 for contracts + FA, 3 for full management). Evidence: medium's managed-vs-autopilot doc. Is that the intended curve?
- Goalkicking attribute saturates at 99 (#237): give scoring metrics headroom? Balance-gated.
- Running machine stays under the +8% bar at ×0.50 (high kept ×0.50).
- STYLE-01–08: approve the art agent's dark-slice sheet; medium then engineers it.
- #206 close; one-command branch cleanup (low agent's list).

## Working rules
- One Godot process per agent at a time. Isolate user data: `APPDATA=<your scratch dir>`.
- Revert `.import` churn before committing. Never commit another agent's untracked files.
- Merge notes go in the PR body or a `[MERGE NOTE]` comment: hot files, floors raised, ordering, ROADMAP lines.
- Owners sync their own branches. A floor conflict resolves to the sum of the increments.
- Don't push to a PR branch while its CI runs unless the merge needs it: a push cancels CI and restarts it.
- A new test suite needs a line in `tools/ci_shards.txt`, or CI's plan job fails.
- Before you next sync main, move aside any UNTRACKED copies of these 8 generated files, because main now tracks them and git will refuse the sync: `tools/audit/coleman_impl.gd.uid`, `gk_cap_impl.gd.uid`, `injury_seed_impl.gd.uid`, `round_perf_impl.gd.uid`, and `assets/audio/music/{draft_room_rain,hub_after_hours,long_season,matchday_morning}.wav.import`. Move them out of the repo, merge main, and keep the committed ones. Revert Godot `.import` churn with `git ls-files -m | grep '\.import$' | xargs git restore --`.
- #274 tracks four more generated files; move aside untracked copies of `tools/audit/{kf_kd,synergy_career,synergy,synergy_on}_impl.gd.uid` the same way.
- `audit.yml` dispatches run independently since #261, so there are no more lost runs. A branch made before #261 keeps the old workflow until it merges main.
