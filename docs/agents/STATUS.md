# Agent status board

Read this at the start of every task. Send changes to your own line to the
medium agent, who keeps this file (other agents can't push to its branch).
The director decides; the high agent directs the agents.
_Updated 2026-10-06 against main `ca9baac` (merged today: #233, #238, #241, #239, #235)._

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
| medium | `MatchNotes._duel_line` verdict (key match-up copy fix) | in progress |
| medium (later) | MatchSim no-presentation perf mode | after #233; check with high first |
| low | `UiKit.scroll` (training scrollbar); `.github/workflows` (audit.yml, sharded CI) | its PRs merge |
| art | `BroadcastVignette.gd` (draw functions only; `pick_kind`, `DURATIONS` untouched); `VignetteFigures.gd`, `assets/vignette/figures_*.png` (sheet being regenerated); `StoppageVignette._draw_figure`; `tools/visual/capture_appearance.gd`, `capture_guernseys.gd`, new `capture_broadcast.gd`; standing: `figure.gdshader`, `clubs.csv` guernsey column, `GameDB.club_guernsey`, `player_appearance.csv`, `Appearance.gd`. Next, in order: `AwardWinnerVignette.gd`, `MediaConferenceVignette.gd` | M8-007 migration |

## Merge queue (low agent runs it: green CI on the exact head + clean against main)
Waiting on CI, merged in order as each goes green:
1. #242 **audit.yml** (low): first; the sharded `tests.yml` PR follows within the hour.
2. #231 club-palette (high; synced with `matchday 348`), #234 coach-alumni (high).
3. Medium's #236, #237, #240 (one sentence each on a different §1.11 ROADMAP bullet), #243 (synergy evidence; docs + tools).

## Open PRs and dependencies
| PR | owner | notes |
|---|---|---|
| #231 | high | `clubs.csv` colours; `matchday` 348 after #233 |
| #234 | high | `CoachPathway`, `CoachSheet`; clean |
| #236 #237 #240 #243 | medium | audits/evidence; docs + `tools/audit` only |
| #242 | low | `audit.yml` (Actions audit runs) |
| next: medium | medium | `claude/matchup-verdict`: MatchNotes verdict copy + `test_match_game` (raises `match_game`) |
| next: high | high | `claude/synergy-specialisation`: new synergy needs and powers; medium validates |
| #228, #206 | none | stale/superseded; the low agent recommends the director close them |
| #232 | codex | research docs; conflicting |

## Pending director decisions
- Goalkicking attribute saturates at 99 (#237): give scoring metrics headroom? Balance-gated.
- Key match-up engine tilt at elite v elite (#240): the lead chose a copy-only fix; engine left alone.
- Close #228 and #206; bulk-delete about 225 merged or superseded branches (the low agent's list).
- Synergy rework: baseline in #243; high has set new needs and powers on `claude/synergy-specialisation`, and medium validates it.

## Working rules
- One Godot process per agent at a time. Isolate user data: `APPDATA=<your scratch dir>`.
- Revert `.import` churn before committing. Never commit another agent's untracked files.
- Merge notes go in the PR body or a `[MERGE NOTE]` comment: hot files, floors raised, ordering, ROADMAP lines.
- Owners sync their own branches. A floor conflict resolves to the sum of the increments.
- Don't push to a PR branch while its CI runs unless the merge needs it: a push cancels CI and restarts the ~27-minute run.
