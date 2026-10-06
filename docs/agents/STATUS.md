# Agent status board

Read this at the start of every task. Send changes to your own line to the
low agent, who keeps this file from 2026-10-06 (other agents can't push to its branch).
The director decides; the high agent directs the agents.
_Updated 2026-10-06 (refresh 18). Since the last board merged: #309 (Create a player), #409 (the crowd at a watched match), #413 (player home states), #414 (centre ball-up copy), #416 and #418 (intercept evidence), #417 (roadmap: match visualisation and weather) and #420 (STYLE-02 typeface prototype recorded)._

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
- #360 Create a club screen (approved; the lead's sync is being tested) and #385 club marker A (approved; retargets to main once #360 is in).
- #419 ARD Signwriter typeface (a draft prototype; the director is playing it; light captures are on the PR) and #408 type specimen.
- #422 centre bounce framing (medium; waits on the director's look), #394 hair review, #303 defensive forward.
- #342 and #291 (the lead is putting them to the director).

**Own-words confirmations:** none open.

**Decisions made, being built:** the intercept evidence is merged (data, no code). All recorded in ROADMAP §9.1.

## Merge queue (low agent runs it: green CI on the exact head + clean against main)
- In flight on CI: #421 (shard re-time) and #424 (trades evidence), both mine and docs/CI only.
- Waiting on the lead's sync: #360 (CONFLICTING with main after #309 merged), then #385 retargets to main (its CI failed on `roles`: the Coleman race fits without scrolling at 360x740; the owner re-runs after the retarget).
- Waiting on a W7 or a sync: #393 (ruck/DEF calibration, W7 from the lead), #383 (the trade market, CONFLICTING with main; its home requests use #413), #303 (CONFLICTING; medium item 13).
- #342 (codex docs, CONFLICTING in ROADMAP only) and #368 (kit options, draft, CONFLICTING) need their owners. #291 is the director's Codex research: do not merge.
- Gates: no appearance PR without the director's explicit approval in the PR or chat; no PR touching save, rollover, shared sim, recruitment or identity without a reviewer's comment on the PR.

## In progress
- **Lead:** the Create a club chain (#360, #385); the trade market (#383); the hair review (#394).
- **Medium:** the ruck/DEF calibration (#393); centre bounce framing (#422); STYLE-02 type roles (#423, waits on the lead's review).
- **Low:** the merge queue, STATUS and the triage, the shard re-time (#421) and the next items the medium agent queues.

## Open PRs and dependencies
Checked 2026-10-06 about 07:50 UTC. None has been quiet for 24 hours or more (oldest: #291, last touched the evening of 2026-10-05).
| PR | owner | CI | conflict | waits on |
|---|---|---|---|---|
| #360 | lead | green | yes | the lead's sync, then merge |
| #385 | lead | red (`roles`, Coleman race at 360x740) | no | #360, then retarget and re-run |
| #383 | lead/medium | running | yes | W7, then a sync |
| #393 | medium | green | no | W7 from the lead |
| #303 | lead | green | yes | a sync (medium item 13) and the director's look |
| #394 | lead | green | no | the director (hair review) |
| #408 | lead | green | no | the director (type specimen) |
| #419 | art/lead | green | no | the director (playing the typeface) |
| #422 | medium | green | no | the director's look |
| #423 | medium | running | no | the lead's review |
| #421, #424 | low | running/green | no | CI, then low merges |
| #342 | codex | green | yes | its owner (ROADMAP sync) and the director |
| #368 | draft | green | yes | its owner |
| #291 | director | green | no | do not merge; the director |

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
