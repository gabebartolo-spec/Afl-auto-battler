# Agent status board

Read this at the start of every task. Send changes to your own line to the
low agent, who keeps this file from 2026-10-06 (other agents can't push to its branch).
The director decides; the high agent directs the agents.
_Updated 2026-10-06 (refresh 21). Since refresh 20: #438 (match view truth fixes), #445 (tactical timeline), #442 (hair overlays), #383 (trades at real volume), #439 and #450 (weather data and evidence), #452 (CI skips drafts and tool-only changes), #440 and #446 (audits), #463 (set-shot audit) and the docs PRs #459, #460 and #461 (the 2026 rules). Roadmap status lines for the merges are in the docs PR that carries this refresh._

## Lanes
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
Checked 2026-10-06 about 10:45 UTC; none has been quiet for 24 hours.
| PR | owner | CI | conflict | waits on |
|---|---|---|---|---|
| #458 | lead | queued | no | CI |
| #455 | medium | queued | no | CI |
| #303 | medium | stale | yes (`MatchSim.gd`) | medium's sync |
| #464, #465 | medium | drafts | no | the audit tables (low posts them) |
| #385 | medium | green | yes | its owner's sync |
| #449 | lead | draft | n/a | the lead's local run |
| #368 | art | draft | yes | the art agent's rebuild |

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
