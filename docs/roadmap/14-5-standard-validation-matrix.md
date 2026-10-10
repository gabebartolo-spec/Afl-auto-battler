# 5. Standard Validation Matrix

Use the relevant rows only. These are **feature-specific gates**; the repository-wide full suite is normally delegated to GitHub CI at PR time under §0.6.

| Change type | During coding / feature gate |
|---|---|
| Pure UI | relevant UI tests; inspect only affected portrait layouts; navigation/state preservation; no clipping |
| MatchSim logic | deterministic targeted regression; focused seeded sim comparison if outcomes can change |
| Player statistics | event-level attribution; player/team reconciliation; season aggregation; save/load only if persisted |
| Balance mechanic | start with a cheap baseline/variant sample; scale to a larger seeded run only after the effect stabilises; inspect relevant distributions/side effects |
| Availability/injury/suspension | targeted manual/AI selection rules; decrement rules; save/load if state persists |
| Season/calendar | targeted progression/boundary/rollover scenarios; save/reload if affected |
| Salary/list rule | exact-boundary cases; AI parity; invalid-state recovery; save/reload if affected |
| Persistent schema | old-save default/migration; current-save roundtrip; no data loss |
| Visualisation | affected event/result reconciliation; direction/restart regression; relevant phone view only |
| Long-save feature | run the minimum multi-season probe that exposes the long-run behaviour; expand to 30/50/100 seasons only when the question requires it |
| Docs/copy only | no game suite; docs/Markdown-only PRs skip the expensive Godot CI by path filter |

### Avoid redundant validation

- Do not run the same full suite locally and then again in CI without a specific reason.
- Do not rerun a long balance/career probe after a docs-only or copy-only change.
- After resolving a merge conflict, run the **affected targeted suites** locally; let CI provide the repository-wide regression pass.
- If a CI run fails for an unrelated/flaky reason, inspect the logs and rerun the failed job rather than making Claude repeat every local test.
- A test count is not a goal by itself. Prefer a small test that proves the behaviour over thousands of irrelevant checks during the coding loop.

---

