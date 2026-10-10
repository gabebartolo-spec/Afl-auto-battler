# 7. Claude Task Prompt Template

When the user says something like **"do ARD-M2-002"**, this roadmap should contain enough information to work from. If a standalone prompt is useful, use this:

```text
IMPLEMENT ROADMAP ITEM: <TASK ID — TITLE>

Repo: gabebartolo-spec/Afl-auto-battler
Engine: Godot 4.7.2

Read docs/ROADMAP.md first and treat it as the source of truth.

Before coding:
1. Inspect the current implementation and existing tests.
2. Confirm whether the roadmap's current-state note is still accurate.
3. Search for overlapping systems so you extend rather than duplicate.
4. Give a short implementation plan.

Implementation rules:
- Stay inside the authorised roadmap item's scope.
- Prefer the smallest robust change.
- Do not refactor adjacent architecture unless genuinely required.
- MatchSim remains the authority for football outcomes.
- Stats must derive from real sim events.
- AI follows the same football rules unless explicitly stated otherwise.
- Preserve save compatibility.
- Mobile-first for UI.
- Do not add number-vomit UI.
- Use natural AFL terminology.
- If the task expands materially beyond its roadmap scope, stop and explain before proceeding.

Validation:
- Add targeted regression tests.
- During coding, run only relevant/targeted suites.
- Push the coherent PR for the repository-wide full-suite gate; GitHub CI owns that by default.
- Do not duplicate a green CI full suite with an equivalent local full-suite run unless §0.6 gives a reason.
- If simulation outcomes change, perform the smallest useful roadmap Balance Assessment and scale the sample only when needed.
- If persisted data changes, run old-save/default + save/reload checks.
- If UI changes, verify only the affected narrow Android portrait layouts.
- Once pushed, ChatGPT may own CI monitoring/log review/reruns/merge verification so Claude can keep coding.

Roadmap maintenance:
- Update this item's status/implementation note only after the work is actually completed.
- Do not mark DONE until merged and verified.
- Do not create duplicate roadmap entries for consequences of this same system.

Git:
- Keep commits logical.
- Standing authority applies: merge clean completed PRs after required validation passes.
- A stale historical "do not merge" line is not a blocker unless the user placed a newer task-specific HOLD.

Final handoff:
1. What changed.
2. Behaviour before vs after.
3. Files changed.
4. Tests added/updated.
5. Targeted test result + GitHub CI full-suite result (do not duplicate equivalent runs).
6. Balance evidence if applicable.
7. Save-compatibility evidence if applicable.
8. Remaining risks/deferred work.
9. Commit hash(es).
10. PR status.
```

---

