# Agent status board

Read this at the start of every task. Send changes to your own line to the
medium agent, who keeps this file (other agents can't push to its branch).
The director decides; the high agent directs the agents.
_Updated 2026-10-06 against main `898b248` (recently merged: #247, #252, #256, #257, #259)._

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
| high | `Traits.gd`; `Ratings.gd` (positions, selection); GameState training section (`TRAIN_PLANS`..`_spend_with_weights`, `_grant_match_xp`); `TrainingScene.gd`; `SelectionScene.gd`; MatchSim synergy constants | branch `claude/dev-project` |
| medium | `MatchNotes._duel_line` / `duel_verdict` (key match-up copy) | #246 merges |
| medium (later) | MatchSim no-presentation perf mode | after #233; check with high first |
| low | `UiKit.scroll` (training scrollbar); `.github/workflows` (audit.yml, sharded CI) | its PRs merge |
| art | `BroadcastVignette.gd` (draw functions only; `pick_kind`, `DURATIONS` untouched); `VignetteFigures.gd`, `assets/vignette/figures_*.png` (sheet being regenerated); `StoppageVignette._draw_figure`; `tools/visual/capture_appearance.gd`, `capture_guernseys.gd`, new `capture_broadcast.gd`; standing: `figure.gdshader`, `clubs.csv` guernsey column, `GameDB.club_guernsey`, `player_appearance.csv`, `Appearance.gd`. Next, in order: `AwardWinnerVignette.gd`, `MediaConferenceVignette.gd` | M8-007 migration |

## Merge queue (low agent runs it: green CI on the exact head + clean against main)
- #258 FL-001 slice 1 (mid-CI).
- #228 (high): failing one club check; high to fix.
- Medium: #240, #243, #246 (waiting on CI or merge).

## Open PRs and dependencies
| PR | owner | notes |
|---|---|---|
| #228 | high | balance passes and Trade E; Draft.gd AI_EVAL_SD change dropped (director); failing one club check |
| #240 #243 | medium | docs + `tools/audit` only |
| #246 | medium | `MatchNotes.gd`, `test_match_game.gd`; `match_game` 232 |
| #258 | ? | FL-001 slice 1 |
| next: high | high | `claude/synergy-specialisation` (validated: league scoring unchanged); `claude/dev-project` (medium's review sent) |
| #232, #206 | director | research docs; #206 superseded by #208 |

Roadmap IDs: the ARD-M8-009 clash is fixed in #259 (the trailer gate is now ARD-M8-010).

## Pending director decisions
- Goalkicking attribute saturates at 99 (#237): give scoring metrics headroom? Balance-gated.
- Key match-up engine tilt at elite v elite (#240): the lead chose a copy-only fix; engine left alone.
- #206: superseded by #208 (MusicManager and tracks already on main); recommend the director close it.
- Branch cleanup: 237 merged or superseded branches need one director-run command (low agent has the list). Nobody else deletes branches.
- Synergy rework: baseline in #243; high has set new needs and powers on `claude/synergy-specialisation`, and medium validates it.

## Working rules
- One Godot process per agent at a time. Isolate user data: `APPDATA=<your scratch dir>`.
- Revert `.import` churn before committing. Never commit another agent's untracked files.
- Merge notes go in the PR body or a `[MERGE NOTE]` comment: hot files, floors raised, ordering, ROADMAP lines.
- Owners sync their own branches. A floor conflict resolves to the sum of the increments.
- Don't push to a PR branch while its CI runs unless the merge needs it: a push cancels CI and restarts it.
- A new test suite needs a line in `tools/ci_shards.txt`, or CI's plan job fails.
- Before you next sync main, move aside any UNTRACKED copies of these 8 generated files, because main now tracks them and git will refuse the sync: `tools/audit/coleman_impl.gd.uid`, `gk_cap_impl.gd.uid`, `injury_seed_impl.gd.uid`, `round_perf_impl.gd.uid`, and `assets/audio/music/{draft_room_rain,hub_after_hours,long_season,matchday_morning}.wav.import`. Move them out of the repo, merge main, and keep the committed ones. Revert Godot `.import` churn with `git ls-files -m | grep '\.import$' | xargs git restore --`.
- `audit.yml` runs one audit per ref and impl at a time. A third dispatch cancels the pending one, so chain dispatches.
