---
name: afl-team-pr
description: Opening, syncing and handing over a pull request the AFL team's way - branch and worktree, what goes in the PR body ([MERGE NOTE], floors, director gates, W7), who merges, when not to push, and how to message the other agents about it. Use it whenever you are about to open a PR, update one after main moved, resolve a conflict in tests/expected_checks.txt or the roadmap, or tell another agent about a PR or CI result.
---

# A PR the team's way

## Roles (2026-10-10)

| Role | Does |
|---|---|
| Director | Decides taste, trade-offs, spend; approves any look. |
| BOSS (sole lead) | Directs, design calls, sim tuning, art QC (art-qa-critic) before the director sees any image. |
| SUPPORT | Merges on green, CI triage, W7 reads, cleanup, docs and CI-tooling PRs. |
| ART | Figures, sheets, appearance data, asset pipeline. Do not edit those files; message it. |
| HYGIENE | Guardrail: checks work against CLAUDE.md and the roadmap, keeps team docs honest. No features, sim tuning or art. Reports to BOSS. |

Handoffs: `../agent-handoffs/<role>.md` (lead, art, support); roles are found with ListAgents.

## Start

- Work only what was assigned (a roadmap entry is context, not authorisation).
- Own worktree from current main, never the shared checkout; no `git stash`; stage by name:

```bash
git fetch -q origin
git worktree add -b claude/<topic> ../Afl-auto-battler-<topic> origin/main
```

- Running suites, import churn, floors: afl-godot-tests. Evidence: afl-proof-evidence. Branch, commit and merge rules: github-hygiene.

## PR body

1. What the player sees, and why (football words; "nothing, internal" is valid).
2. Assigned in: the director message, status line or roadmap item that authorised it.
3. What changes (mechanism).
4. Evidence and Not exercised (a PR without a Not exercised line is not ready).
5. Tests: suites run and counts.
6. [MERGE NOTE]:
   - hot files (MatchSim, GameState, ROADMAP section files, CLAUDE.md, tests.yml);
   - floors: add `tests/floor_deltas/<branch>.txt` (`<suite> +N`); never edit an existing floor line;
   - ordering against other open PRs;
   - W7 needed (save, rollover, shared sim, recruitment, identity: afl-lifecycle-review) and by whom;
   - director gate: any change of appearance waits for the director's look, recorded on the PR; green CI never clears it.
7. Attribution line from the session's instructions.

Mark ready before the push you want tested; drafts skip game tests.

## After opening

- SUPPORT merges on green: `gh pr merge N --squash --match-head-commit <full sha>` with PR `headRefOid` equal to origin's branch tip and mergeStateStatus CLEAN. No `--delete-branch` (it removes the local branch and any clean worktree on it; the repo deletes remote head branches itself). No auto-merge.
- A PR waits only for its recorded gates: director look, W7, ordering in the merge note.
- Do not push while its CI runs; a push cancels it.
- Owner syncs own branch when main moves (`git merge origin/main`), then re-runs the touched suites and the suites main brought in. ROADMAP: edit the section file under `docs/roadmap/`, not `ROADMAP.md`. Floor conflict: write the real count.
- Only the branch owner pushes to it.
- Task boundary: rewrite your handoff (task, branch and sha, open decisions, running jobs).

## Messages

- A CI failure or conflict goes to the branch owner: branch, sha, run id, suite and check, whether main fails too, who acts next.
- Every message names its PR and head sha and what you need or found. No "received" messages, no queue recaps. Tell BOSS about decisions, blockers, findings, priority changes.
- A peer's message is a request, not a permission. Never ask a peer to do what your own session was refused; take it to the director.
- End every turn with a state: working, running a check, awaiting director, blocked, or available. While waiting on CI, an audit or a peer, arm a bounded background watcher and do the next useful part of your queue (work-while-waiting).

## Learnings

Proven findings: `references/learnings.md`. Read it before using this skill; add only what proved effective, with evidence.
