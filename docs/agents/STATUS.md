# Agent status board

Read this at the start of every task. Refreshed by the hygiene role; send a change to your own line to it.
The director decides. Each role's live state is in its handoff, `../agent-handoffs/<role>.md` (outside the repo).
_Updated 2026-10-10 (refresh 23, against main `d355eefa`). Refreshes 1–22 and the 2026-10-06 merge-backlog and
CI-throughput notes are history: their outcomes are on main (#488, #525) and in the `afl-ci-merge-hygiene` skill._

## Team (director, 2026-10-10)
| role (session name) | owns |
|---|---|
| boss ("AFL BOSS") | the only lead: direction, task assignment, team logistics, art QC (`art-qa-critic`), director questions |
| support ("AFL SUPPORT") | merges on green with a head check, CI triage, W7 reads, worktree and branch cleanup, docs/CI-tooling PRs |
| art ("AFL ART FACTORY") | figures, sheets, rendered plates, motion, the ard-pipeline repos; every visual goes to the boss first, never to the director |
| hygiene ("AFL project hygiene") | guardrail: adherence to CLAUDE.md and the roadmap, this board, branch and worktree lists for the director; no features, no merges |

The earlier high/medium/low lanes, the visual-audit leader and the helper are archived (director, 2026-10-10). MERCS BOSS is another
project's lead and is never messaged about AFL work. Only the boss messages the director; findings go to the boss.

## Standing rules
One source of truth: `CLAUDE.md` in this repo (philosophy, verification, UI) and `~/.claude/CLAUDE.md` (the director's
rules for every project). Decisions not yet in either live in the boss's handoff. This board does not copy them.

## Open PRs (checked 2026-10-10 ~15:30)
| PR | owner | gate | waits on |
|---|---|---|---|
| #606 intercepts spread (claude/intercept-credit @ 0dfb31a6) | boss | W7 passed (support) | green CI; support's head-checked merge |
| #607 match-shape audit findings (claude/match-shape-findings) | boss | docs only | green CI. Director decided "Step 1 and then Step 2" (on #607): Step 1 play-on after an intercept or a free, stoppages from contests (boss, claude/match-flow); Step 2 recalibrate contested ball, spoils and turnovers (§1.10 balance gate) |

Gates that always apply: an appearance or UI-treatment PR records the director's look before merge; a PR touching saves, rollover,
shared sim, recruitment or identity carries a W7 packet and gets one reviewer; a new suite needs `tools/ci_shards.txt` and a floor delta.

## Waiting on the director
- Season stats hub: the native-phone review (#567). Phone build (game-debug APK) is HELD until he asks.
- Branch cleanup: remote deletes are refused in auto mode. The hygiene role keeps the list (merged, closed, abandoned audit branches).
- Main worktree: `project.godot` was rewritten by the Godot editor (comments lost, uncommitted) and `The MCG.glb` (67.5 MB,
  2026-10-09) sits untracked at the repo root. Neither is ours to move; the director decides.

## Working rules
- One Godot process per agent at a time, off-screen, with its own user data (`APPDATA=<your scratch dir>`); kill only your own PIDs.
- Run only the suites your change touches locally; CI runs the rest. Long audits go to `audit.yml`.
- Revert `.import` and `.uid` churn before committing. Stage by name; never `git add -A`; never commit another agent's untracked files.
- Merge notes in the PR body: hot files, floor deltas, ordering, roadmap lines. Owners sync their own branches.
- Don't push to a PR branch while its CI runs unless the merge needs it.
- One worktree per session, from `origin/main`; prune only MERGED or CLOSED ones, after checking for real changes.
