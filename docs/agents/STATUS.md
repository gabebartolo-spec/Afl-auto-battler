# Agent status board

Read this at the start of every task. Send changes to your own line to the
medium agent, who keeps this file (other agents can't push to its branch).
The director decides; the high agent directs the agents.
_Updated 2026-10-06 (also merged: #245 sharded CI, #250 README/DESIGN, #251 tests/README)._

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
All clean against main and waiting on CI for their exact heads: #231, #240, #242, #243, #246, #247, #248, #249.
#248 (5 shards) first: after it, a normal PR finishes CI in about 8 minutes.

## Open PRs and dependencies
| PR | owner | notes |
|---|---|---|
| #231 | high | `clubs.csv` colours; `matchday` 348 |
| #240 #243 | medium | docs + `tools/audit` only |
| #246 | medium | `MatchNotes.gd`, `test_match_game.gd`; `match_game` 229 → 232 |
| #242 #248 | low | `audit.yml`; 5-shard `tests.yml` |
| #247 | low | `UiKit.scroll` training scrollbar |
| next: high | high | `claude/synergy-specialisation` (7b8b2ab): new needs/powers; medium validating |
| #228 | high | balance passes and Trade E; valuable but stalled. High will merge main in and get a CI run. |
| #206 | none | superseded by #208; for the director to close. Nobody closes PRs without the director. |
| #232 | codex | research docs; conflicting |

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
