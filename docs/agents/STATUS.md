# Agent status board

Read this at the start of every task. Send changes to your own line to the
low agent, who keeps this file from 2026-10-06 (other agents can't push to its branch).
The director decides; the high agent directs the agents.
_Updated 2026-10-06. Since the last board merged: #371 (STYLE-07, PC fullscreen readable), #378 (player origin data), #382 (scars removed), #387, #389 and #401 (STYLE-08 light inventory), #390, #392 (nicknames and interests), #395 (headlines), #396, #398 (Stat Guide in words), #400 (milestone banners), #402, #403, #405 (crowd sounds), #406 (club memories), #407 (live score colours), #411 (dark-hair lift) and #412 (flags evidence)._

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
- #385 club marker A (a prototype stacked on #360; approved by the director, merges after #360 is in), #360 Create a club screen (approved; merges after #309), #309 Create a player (approved; needs the lead's sync).
- #408 type specimen (the lead has the question), #394 hair review, #303 defensive forward.
- #409 FL-004 crowd at a watched match (medium, a prototype): the director listens before it merges.

**Own-words confirmations:** none open.

**Decisions made, being built:** the intercept evidence (data, no code). All recorded in ROADMAP §9.1.

## Merge queue (low agent runs it: green CI on the exact head + clean against main)
- In flight on CI: #413 (player home states from the origin data) and #414 (copy: centre ball-up, 2026 rules).
- Green and waiting on a W7 or a sync: #393 (ruck/DEF calibration, medium, W7 from the lead), #383 (the trade market, W7 from medium; its home requests use #413), #309 and #303 (owner syncs), #409 (medium merges main in).
- #342 (codex docs) and #368 (kit options, draft) need their owners. #291 is the director's Codex research: do not merge.
- Gates: no appearance PR without the director's explicit approval in the PR or chat; no PR touching save, rollover, shared sim, recruitment or identity without a reviewer's comment on the PR.

## In progress
- **Lead:** the Create a player and Create a club chain (#309, #360, #385); the trade market (#383); the hair review (#394).
- **Medium:** the crowd at a watched match (#409); the ruck/DEF calibration (#393).
- **Low:** the merge queue, the intercept evidence, the shard re-time after a green main run, then the next items the medium agent queues.

## Open PRs and dependencies
| PR | owner | notes |
|---|---|---|
| #413, #414 | low | player home states; copy: centre ball-up |
| #409 | medium | FL-004 crowd; prototype, the director listens |
| #393, #383 | medium and lead | ruck/DEF calibration and the trade market; waiting on a W7 |
| #385, #360, #309 | lead and medium | club marker A on the Create a club screen on the Create a player form; merge in that order from the bottom |
| #408, #394, #303 | lead | type specimen, hair review, defensive forward |
| #342 | codex | favourite-club bios, ROADMAP only; needs a sync |
| #368 | draft | kit options |
| #291 | director | Codex research and playbook; do not merge |

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
