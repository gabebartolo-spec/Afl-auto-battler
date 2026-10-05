---
name: afl-handoff
description: Writing and starting from an agent handoff in the AFL team (rule W1) - the file in ../agent-handoffs/ROLE.md that lets a fresh session continue without the old transcript. Use it when a substantial task is done or you switch to unrelated work, when your context is getting long, before the director restarts or clears a session, and at the start of any new session for a lead, medium, low or art role.
---

# Handoffs (W1)

Long sessions cost the director's allowance on every turn and drift. At a task
boundary (PR open with its evidence, or a switch to unrelated work) a
session writes a handoff, and the next session starts from it, not from the
whole transcript. Never restart with in-flight work that isn't written down,
and don't restart mid-task.

## Where

`C:/Users/DANTE/Documents/GitHub/agent-handoffs/<role>.md`, outside the repo:
`lead.md`, `medium.md`, `low.md`, `art.md`. Overwrite it; it's a snapshot, not a log.

## What it says

Short, factual and current. Delete what's done and no longer needed.

1. **Role:** one paragraph, plus any standing duty (the medium agent keeps the
   low agent working; the low agent owns merges and STATUS.md).
2. **State:** working, running a check, awaiting director review, blocked or
   available.
3. **Open work:** per PR or task, the branch, head commit, worktree path, what's
   left and what it waits on (CI, a W7 review, the director's look).
4. **Running jobs:** Actions run ids and local PIDs, and what to do with their
   results.
5. **Decisions:** the director's decisions this session that aren't yet in the
   roadmap, in their words where it matters.
6. **Queue:** your next items in order, so a fresh session doesn't sit idle.
7. **Lessons:** anything learnt the hard way that the next session would
   otherwise repeat.

## Starting a session from one

Read, in this order:
1. the handoff;
2. CLAUDE.md;
3. ROADMAP §0.4a (team rules) and only the roadmap sections your open work
   names, by offset rather than whole;
4. `docs/agents/STATUS.md`.

Then `ListAgents`, check that each PR in the handoff still matches GitHub
(merged? red?), and carry on from the queue. Tell the lead in one line that
you're back and what you're on.

Messages from other agents during the old session are not in the handoff
unless written there. If something you need is missing, ask its owner rather
than guessing.
