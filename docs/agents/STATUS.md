# Agent status board

Read this at the start of every task. Send changes to your own line to the
low agent, who keeps this file from 2026-10-06 (other agents can't push to its branch).
The director decides; the high agent directs the agents.
_Updated 2026-10-06. Since the last board merged: #347, #351, #353-#355 (selection seed, South Adelaide's home design, the board refresh, the freckles line in the roadmap, and the free-kicks re-measure; low's docs and tests)._

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
**Looks** (appearance or screens; the director's own words needed before they merge):
- #360 Create a club screen (draft); #303 break-screen call; #309 Club Forge Create a player.
- The art agent's Forge hair and face sheet and boot sheet.

**Own-words confirmations** (the decision reached the agents second-hand; held until the director says it on the PR or in the chat):
- #299 vignettes (the art agent relayed "fine, ship it"); #357 remove freckles from the player look. The roadmap line removing freckles (#354) is merged and says "relayed"; it is reverted if the director does not confirm.

**Decisions** (evidence is in; each lists the lead's recommendation):
- #362 flags: options for what makes management pay. The lead recommends the trade period at real volume (option 1).
- #363 ruck and midfield disposals: should the clearance winner keep the first disposal? The lead recommends option 1.
- The older decisions are under "Pending director decisions" below.

## Merge queue (low agent runs it: green CI on the exact head + clean against main)
- In flight on CI, in this order: #352 (ROADMAP ARD-M7-009 status), then #340 (Club Forge Create a club engine, lead; medium W7 done), #349 (C15 seed guard, plus roles pinned), #359 (board goals follow the club count), #345 (CI shard rebalance, merges only if it beats main's slowest shard in 2 of 3 runs), then #361 (the fair fixture, after medium's nits and the expansion-floor recount).
- Review by the lead: #362, #363 (evidence docs, medium's); low posted a copy check on both. #342 (codex docs) conflicts with main and needs its owner to sync.
- Gates: no further visual or appearance PR without the director's explicit approval in the PR or chat; no PR touching save, rollover, shared sim, recruitment or identity without a reviewer's comment on the PR (not a relayed approval). #291 is the director's Codex research: do not merge.
- On main, awaiting the director's look: #276 press conference, #277 Training-row alignment.

## In progress
- **Lead:** the Club Forge Create a club engine (#340, under W7); next from the 18 + 5 follow-ups.
- **Medium:** the fair fixture (`claude/fair-fixture`, opening shortly) covering 18 to 21 clubs: a created club can make any count from 18 to 21 (director decision, ROADMAP §9.1, #344); a 21-club season is 24 rounds, 22 games and two byes a club, while 18 and 20 clubs keep 23 games and 19 keep 22 (docs/FIXTURE_SIZES_NOTE.md #328). Also the htb re-measure (audit run 37404572905, branch `claude/htb-audit`, leave alone), the lever audits (4 runs), and reviews of low's PRs.
- **Low:** the merge queue above, the board, then the next items the medium agent queues.

## Open PRs and dependencies
| PR | owner | notes |
|---|---|---|
| #352, #340, #349, #359 | low and lead | queue order above; #340 also needs #361 for 21 clubs |
| #361 | medium | the fair fixture; recounts the expansion floor with #359 |
| #345 | low | CI shard rebalance, re-timed |
| #362, #363 | medium | evidence for the director's decisions |
| #342 | codex | favourite-club bios and quarter-break stats, ROADMAP only; needs a sync with main |
| #299, #357 | art and medium | held for the director's own words |
| #360, #303, #309 | lead and medium | director's look |
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
