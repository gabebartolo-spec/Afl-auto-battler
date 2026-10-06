# Agent status board

Read this at the start of every task. Send changes to your own line to the
low agent, who keeps this file from 2026-10-06 (other agents can't push to its branch).
The director decides; the high agent directs the agents.
_Updated 2026-10-06. Since the last board merged: #321-#323, #326-#330, #332-#335 (docs #324, #329, #334, #335 from other agents). On main now: the run-through banners (#326, #330), the free-kick possession fix (#321), the role and team-match references (#327, #332), C15 seed batches 1 to 3._

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
- Open and reviewable: #336 (C15 awards and injuries seeds), #337 (C15 batch 4: intake, chronology, coach_pathway, intake_ui, career_ui; intake_ui floor 493 to 500), #338 (six audit-script .uid files).
- #331 (18 + 5 interchange): the lead's PR, CI being fixed for a match-day floor. When it merges low marks #325 ready (ROADMAP wording, drafted) and merges it on green, then seeds selection (roles and match_game stay with #331).
- Held for the director's look: #303 (break-screen call; its match_game floor becomes 254 against the real count, main is 243), #309 (Club Forge Create a player), #299 (draft: vignette fixes). #291 is the director's Codex research: do not merge.
- Gates: no further visual or appearance PR without the director's explicit approval in the PR or chat; no PR touching save, rollover, shared sim, recruitment or identity without a reviewer's comment on the PR (not a relayed approval).
- On main, awaiting the director's look: #276 press conference, #277 Training-row alignment.

## In progress
- **P0, lead:** ARD-M5-001 18 on the ground plus 5 interchange (23 side), #331 (code, copy, README, DESIGN), plus the Club Forge Create a club engine.
- **Medium:** the fair-fixture fix (19 clubs give unequal games, byes follow club-list order, home games run 7 to 17; docs/FIXTURE_SIZES_NOTE.md #328) and the location-tag research. The 21-club format goes to the director. Reviews low's PRs.
- **Low:** the C15 seed batches (#336, #337), audit-script .uid files (#338), then #325 and selection once #331 lands.

## Open PRs and dependencies
| PR | owner | notes |
|---|---|---|
| #331 | lead | 18 + 5 interchange, 23 in all; CI fixing a match-day floor |
| #325 | low | draft, ROADMAP match-day wording; ready after #331 |
| #336, #337 | low | test-only seed batches |
| #338 | low | six .uid files |
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
