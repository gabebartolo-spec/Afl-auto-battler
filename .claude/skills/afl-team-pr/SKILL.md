---
name: afl-team-pr
description: Opening, syncing and handing over a pull request the AFL team's way - branch and worktree, what goes in the PR body ([MERGE NOTE], floors, director gates, W7), who merges, when not to push, and how to message the other agents about it. Use it whenever you are about to open a PR, update one after main moved, resolve a conflict in tests/expected_checks.txt or the roadmap, or tell another agent about a PR or CI result.
---

# A PR the team's way

Four agents work in parallel on one repo: the lead (high effort) directs and
does the hardest items, the medium agent takes bounded work and reviews, the
low agent owns CI, merges and the status board, and the art agent owns the
figures and asset pipeline. The director decides. PRs are how work meets, so
they carry everything the merger and the director need without anyone rereading
your conversation.

## Before you start

Work only on what was assigned (CLAUDE.md: a roadmap entry is context, not
authorisation). Branch from current main in your own worktree:

```bash
git fetch -q origin
git worktree add -b claude/<topic> ../Afl-auto-battler-<topic> origin/main
```

See afl-godot-tests for running suites, import churn and floors.

## The PR body

Plain language for the director first, then the detail:

1. **What the player sees, and why** - one short paragraph, football words.
2. **What changes** - the mechanism, briefly.
3. **Evidence** and **Not exercised** - see afl-proof-evidence.
4. **Tests** - suites run locally and their counts.
5. **[MERGE NOTE]** - for the merger:
   - hot files touched (MatchSim, GameState, ROADMAP, expected_checks...);
   - floors: `suite base → new (+increment)`;
   - ordering with other open PRs, and who syncs;
   - **W7 needed?** (save, rollover, shared sim, recruitment, identity - see
     afl-lifecycle-review) and who reviews;
   - **Director gate?** Any change in appearance (§9.5) waits for the
     director's visual approval; anything needing a phone check says so.
     Green CI doesn't clear either.
6. End with the attribution line the session's instructions give.

## After opening

- **You don't merge.** The low agent merges on green once gates and reviews
  are cleared. Say in the PR if it must wait.
- **Don't push while its CI runs** unless you must; ask for a sync instead.
- **Sync your own branch** when main moves under it (`git merge origin/main`);
  nobody else can push to it.
  - **Floors:** a conflict in `tests/expected_checks.txt` resolves to base plus
    both increments, checked against the real count.
  - **ROADMAP:** keep both sides.
  - Then re-run the touched suites.
- **Hand over at task boundaries:** update `../agent-handoffs/<role>.md`
  (task, branch and commit, open decisions, running jobs) so a fresh session
  can pick it up.

## Messages to other agents

Send a CI failure or a conflict straight to the branch's owner. Every message
names its PR and commit and says what you need or what you found. No
"received" or "noted" messages, no repeating the queue back. Tell the lead
about decisions, blockers, substantive findings and changes of priority.

Say which state you're in: working, running a check, awaiting director review,
blocked, or available. Waiting on a result or an approval is a valid state; don't
invent work to look busy. Never ask another agent to do something your own
session was refused permission for: take it to the director.

## Learnings

Proven findings for this project live in `references/learnings.md`. Read it before using this
skill; add to it only what proved effective, with evidence.
