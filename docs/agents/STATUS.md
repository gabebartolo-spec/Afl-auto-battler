# Agent status board

Read this at the start of every task. Send changes to your own line to the
medium agent, who keeps this file (other agents can't push to its branch).
The director decides; the high agent directs the agents.
_Updated 2026-10-06 against main `75dabe8` (#233 merged)._

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
1. **audit.yml** (low): being written; its own small PR, ahead of sharded `tests.yml`.
2. #231 club-palette: waiting on high to sync main and set **`matchday 348`** (#233 merged as `75dabe8`).
3. #234 coach-alumni, #238 effort-tags (green), #239 vignette art inventory (green; docs).
4. Medium's audits #235, #236, #237, #240, #241: independent, any order. Each appends one sentence to a different §1.11 ROADMAP bullet. #235 raises `injuries` 29 → 31.

## Open PRs and dependencies
| PR | owner | notes |
|---|---|---|
| #231 | high | `clubs.csv` colours; conflicts with #233 on the `matchday` floor (348) |
| #234 | high | `CoachPathway`, `CoachSheet`; clean |
| #235 #236 #237 #240 | medium | audits; docs + `tools/audit` (+ `test_injuries` in #235) |
| #238 | low | ROADMAP effort tags and lanes; dry-run clean against all |
| #239 | art | `docs/VIGNETTE_ART_INVENTORY.md` (M8-007 step 1, docs only) |
| #228, #206 | none | stale/superseded; the low agent recommends the director close them |
| #232 | codex | research docs; conflicting |

## Pending director decisions
- Goalkicking attribute saturates at 99 (#237): give scoring metrics headroom? Balance-gated.
- Key match-up engine tilt at elite v elite (#240): the lead chose a copy-only fix; engine left alone.
- Close #228 and #206; bulk-delete about 225 merged or superseded branches (the low agent's list).
- Synergy rework strength targets: waiting on medium's synergy evidence (in progress).

## Working rules
- One Godot process per agent at a time. Isolate user data: `APPDATA=<your scratch dir>`.
- Revert `.import` churn before committing. Never commit another agent's untracked files.
- Merge notes go in the PR body or a `[MERGE NOTE]` comment: hot files, floors raised, ordering, ROADMAP lines.
- Owners sync their own branches. A floor conflict resolves to the sum of the increments.
