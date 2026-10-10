# 8. Night-Shift / Autonomous Batch Rules

Claude has standing authority to work through ready roadmap tasks unattended.

Use the autonomy labels as risk guidance, not as ceremonial gates:
- `SAFE`: proceed.
- `SUPERVISED`: proceed when the roadmap already resolves the design; stop only for a genuine unresolved player-experience choice or unexpectedly broad architecture change.
- `BALANCE-GATED`: implement and measure autonomously; merge only when the balance evidence passes the roadmap's acceptance standard.

For each task:
- inspect first,
- skip/stop if unexpectedly architectural or genuinely ambiguous,
- one logical concern per commit where practical,
- use targeted tests during the coding loop and delegate the routine full-suite PR gate to GitHub CI / ChatGPT where available,
- do not idle solely waiting for CI when an independent next task can safely proceed,
- merge clean validated work rather than leaving finished PRs idle,
- do not make speculative balance changes without measurement,
- do not "clean up" unrelated code,
- do not create a second implementation of an existing system,
- leave a clear handoff for anything skipped.

Preferred unattended work:
- local correctness fixes,
- clear UI bugs,
- stat plumbing with unambiguous attribution,
- settings/confirmation UX,
- regression tests,
- shared visual-theme fixes.

Poor unattended work:
- new economy,
- broad ratings rebalance,
- new tactical model,
- contracts/trades,
- Momentum tuning,
- major selection architecture,
- rules requiring uncertain interpretation,
- large save-schema migration.

---

