# Agent status board

Read this at the start of every task. Send changes to your own line to the
medium agent, who keeps this file (other agents can't push to its branch).
The director decides; the high agent directs the agents.
_Updated 2026-10-06 against main `4b715b7`._

## Lanes
| agent (session) | owns |
|---|---|
| high ("high effort tasks - Boss") | lead: direction, task assignment, synergy/position work |
| medium ("medium effort tasks") | medium tasks, measured audits, this board, team information flow |
| low ("low effort tasks") | CI and merges, the merge queue, low-effort tasks, effort tags |
| art ("art agent") | vignette figures, guernseys and shorts, player appearance, asset pipeline |

## File claims (don't edit another agent's claim; message them)
| agent | files | until |
|---|---|---|
| high | `Traits.gd`; `Ratings.gd` (positions, selection); GameState training section (`TRAIN_PLANS`..`_spend_with_weights`, `_grant_match_xp`); `TrainingScene.gd`; `SelectionScene.gd`; MatchSim synergy constants | branch `claude/dev-project` |
| #233 owner | `MatchSim.gd`, `MatchNotes.gd` | #233 merges |
| medium | `MatchNotes._duel_line` verdict (key match-up copy fix) | starts after #233 merges |
| medium (later) | MatchSim no-presentation perf mode | after #233; check with high first |
| low | `UiKit.scroll` (training scrollbar); `.github/workflows` (audit.yml, sharded CI) | its PRs merge |
| art | `assets/vignette/figures_*`, `VignetteFigures.gd`, `figure.gdshader`, `clubs.csv` guernsey column, `GameDB.club_guernsey`, `player_appearance.csv`, `Appearance.gd` | standing |

## Merge queue (low agent runs it: green CI on the exact head + clean against main)
1. **audit.yml / sharded CI** (low): first when opened; unblocks Actions audit runs.
2. #233 tired-tradeoff: green.
3. #231 club-palette: after #233, the owner syncs main and sets **`matchday 348`** in `tests/expected_checks.txt`.
4. #234 coach-alumni, #238 effort-tags (green), #239 vignette art inventory (green; docs).
5. Medium's audits #235, #236, #237, #240: independent, any order. Each appends one sentence to a different §1.11 ROADMAP bullet. #235 raises `injuries` 29 → 31.

## Open PRs and dependencies
| PR | owner | notes |
|---|---|---|
| #231 | high? (confirm) | `clubs.csv` colours; conflicts with #233 on the `matchday` floor (348) |
| #233 | high? (confirm) | MatchSim, MatchNotes; floors `match_game` 229, `matchday` 347 |
| #234 | high? (confirm) | `CoachPathway`, `CoachSheet`; clean |
| #235 #236 #237 #240 | medium | audits; docs + `tools/audit` (+ `test_injuries` in #235) |
| #238 | low | ROADMAP effort tags and lanes; dry-run clean against all |
| #239 | art? (confirm) | `docs/VIGNETTE_ART_INVENTORY.md` |
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
