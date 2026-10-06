# Agent status board

Read this at the start of every task. Send changes to your own line to the
low agent, who keeps this file from 2026-10-06 (other agents can't push to its branch).
The director decides; the high agent directs the agents.
_Updated 2026-10-06. Since the last board merged: #331 (18 + 5 interchange, the All-Australian team of 23, dual ruck), #336, #337, #338, #339, #344 (docs and tests from low), #340 and #343 reviewed by medium (see Open PRs)._

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

## Merge queue (low agent runs it: green CI on the exact head + clean against main)
- Low's next merges: #325 (ROADMAP match-day wording, ready now that #331 is on main), the `selection` seed PR, #345 (CI shard rebalance, re-timed after #331 before it merges).
- Open for review: #340 (Club Forge Create a club engine, medium W7), #343 (location tags, medium W7), the medium agent's fair fixture.
- Waiting on the director's look: #303 (break-screen call; its match_game floor becomes 254 against the real count, recount after #331), #309 (Club Forge Create a player), #299 (draft: vignette fixes), and the art agent's Forge hair contact sheet. #291 is the director's Codex research: do not merge.
- Gates: no further visual or appearance PR without the director's explicit approval in the PR or chat; no PR touching save, rollover, shared sim, recruitment or identity without a reviewer's comment on the PR (not a relayed approval).
- On main, awaiting the director's look: #276 press conference, #277 Training-row alignment.

## In progress
- **Lead:** the Club Forge Create a club engine (#340); next from the 18 + 5 follow-ups.
- **Medium:** the fair-fixture fix (19 clubs give unequal games, byes follow club-list order, home games run 7 to 17; docs/FIXTURE_SIZES_NOTE.md #328). Director decision: a 21-club season is 24 rounds, 22 games and two byes a club (ROADMAP §9.1); 18 and 20 clubs keep 23 games, 19 keep 22. Also the location-tag research and reviews of low's PRs.
- **Low:** #325 and the `selection` seeds, the shard rebalance (#345), then the next items the medium agent queues.

## Open PRs and dependencies
| PR | owner | notes |
|---|---|---|
| #325 | low | ROADMAP match-day wording; ready and merged on green |
| #345 | low | CI shard rebalance, draft until re-timed |
| #340 | lead | Club Forge Create a club engine; medium W7 |
| #343 | medium | location tags; medium W7 |
| #303 | medium | break-screen call; director's phone look |
| #309 | lead | Club Forge Create a player; director's look |
| #299 | art | draft, vignette fixes; director's look |
| #291 | director | Codex research and playbook; do not merge |
| #206 | director | superseded by #208; close |

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
