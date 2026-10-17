# Agent teams (Claude Code)

Claude Code agent teams let one session act as lead and spawn teammates that each hold their own context, message each other, and share a task list. They are experimental, off by default, and use far more tokens than one session. This note says how to use them here without breaking the existing team rules. It is a tool note, not a rule: `CLAUDE.md` and the design bible still govern everything.

## Where it fits

- The team structure on `docs/agents/STATUS.md` does not change. BOSS stays the only lead and the only role that messages the director. A team is something BOSS (or another role) starts inside its own session for one bounded job, then shuts down.
- Teammates load `CLAUDE.md`, skills and MCP servers like any session, so the bible rules reach them. They do not see the lead's conversation: put the task, the files and the evidence bar in the spawn prompt.
- Teammates are not roles. They do not merge, do not open PRs unless assigned, and do not message the director. Findings go to the lead.

## Turn it on (per session, not committed)

Set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in your shell, or in `~/.claude/settings.json` on the machine that runs the session. It is deliberately not in this repo's `.claude/settings.json`: with it on, any subagent Claude names launches as a teammate, which would change delegation for every role on both accounts. To turn it off again, set it to `0`.

Optional: `claude --teammate-mode auto` for split panes under tmux or iTerm2. The default in-process mode works anywhere.

## Teammate roles in this repo

Defined in `.claude/agents/`, usable as `Spawn a teammate using the <name> agent type to ...`:

| agent type | does | edits? |
|---|---|---|
| `bible-auditor` | checks one set of docs, screens or copy against `docs/DESIGN_BIBLE.md` and reports conflicts | no, read-only |
| `balance-skeptic` | owns one balance hypothesis and tries to disprove the others, with evidence | no, reports only |
| `feature-gate` | assesses a proposed feature against the bible's feature test | no, advisory |

For art checks, use the existing `art-qa-critic` (see `STATUS.md` and `docs/VISUAL_STYLE_GUIDE.md`). It is not redefined here.

## Ground rules for every team

1. **Assigned work only.** A roadmap item is context, not authorisation. The spawn prompt names what was assigned and by whom.
2. **One owner per file.** Two teammates on one file overwrite each other. Hot files (`MatchSim`, `GameState`, roadmap section files, `CLAUDE.md`, `tests.yml`, `tests/expected_checks.txt`) get one owner or none. Teammates that write code each use their own worktree and branch (`afl-team-pr`); no `git stash`.
3. **Nobody edits the bible.** Teammates propose, under "For the director". Plan approval in a team is granted by the lead without review, so it is not a director gate.
4. **The director's calls stay the director's.** A teammate never declares balance settled, art approved or a feature accepted.
5. **Start with 3 to 5 teammates**, review and audit work first. Size tasks to a clear deliverable.
6. **Shut the team down at the task boundary**, then rewrite the lead's handoff (`afl-handoff`). Teams do not survive `/resume`: persist anything that matters to a doc or the handoff.
7. **Cost.** If one session would do, use one session. Teams earn their tokens on parallel review, competing hypotheses and separate modules.

## Starter prompts

Bible adherence audit (read-only):

```text
Spawn 4 teammates using the bible-auditor agent type. Each audits one area against docs/DESIGN_BIBLE.md and reports conflicts: (1) docs/ROADMAP.md and docs/roadmap/, (2) docs/DESIGN.md and docs/MATCH_VIEW.md, (3) docs/VISUAL_STYLE_GUIDE.md and screen copy under scripts/ui/, (4) docs/COMPETITIVE_BALANCE.md and the other balance docs. Nobody edits anything. When all have reported, synthesize one list of conflicts, grouped as real conflicts, wording drift and "For the director".
```

Balance drift (reports evidence only):

```text
Spawn 4 teammates using the balance-skeptic agent type to investigate why the sim's numbers drift from real AFL. Name them for their hypothesis; I will give each one. Have them message each other with evidence against the others' hypotheses, like a scientific debate. Use existing docs/*_EVIDENCE_* files first; run a seeded audit through the afl-audit-runs skill only where the question needs it. Nobody changes tuning. Report which hypotheses survived, with sources, and what was not exercised.
```

Feature gate panel (advisory):

```text
Spawn 3 teammates using the feature-gate agent type. Each assesses this proposed feature against the bible's feature test: <feature>. One argues for building it, one argues against, one proposes the simplest alternative. Report a verdict and anything that needs the director.
```

Art QC pair (uses the existing critic):

```text
Spawn two teammates: one using the art-qa-critic agent type to inspect <figure or vignette capture> for the faults CLAUDE.md lists (skin through a jumper, broken anatomy, odd animation, a ball that hovers or moves on its own, a ground that breaks AFL conventions), and one to fix what the critic finds. They message each other until the critic passes it. The art goes to the lead, never straight to the director.
```

## Troubleshooting

- Teammates did not appear: the task may have been too small for a team. Ask for "an agent team" explicitly. If Claude used subagents instead, say so and ask again.
- Too many permission prompts: pre-approve common operations in permission settings before spawning.
- Lead starts doing the work itself: tell it to wait for the teammates to finish.
- A task looks stuck: the teammate may have finished without marking it done. Check, then update it or nudge the teammate.

Source: Claude Code docs, "Orchestrate teams of Claude Code sessions".
