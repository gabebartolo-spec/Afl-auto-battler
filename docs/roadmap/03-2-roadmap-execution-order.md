# 2. Roadmap Execution Order

The sequence below is deliberate. Later milestones depend on cleaner football events, statistics and selection semantics from earlier milestones.

| Milestone | Purpose | Why it comes here |
|---|---|---|
| **M1 — Correctness & Low-Risk UX** | Remove known sanity bugs, soft-locks and misleading UI | Stabilises the existing game before adding more systems |
| **M2 — Match Event & Stat Foundation** | Make the sim record the football information later features need | Reports, roles, scouting and tactics need trustworthy event data |
| **M3 — AFL Rules & Match Authenticity** | Expand scoring, marking, pressure, restarts and presentation | Builds richer football on top of reliable event semantics |
| **M4 — Tactical Matchday Layer** | Meaningful coaching decisions, match-ups and game-state AI | Requires M2/M3 context to avoid arbitrary buffs |
| **M5 — Selection, Roles & Development** | Make list/position/development decisions deeper and more intuitive | Benefits from corrected roles and richer match stats |
| **M6 — Coaching, Board & List Management** | Strengthen the management game outside matches | Best added once weekly football loop is trustworthy |
| **M7 — Competition Identity & Long Careers** | Rivalries, history, records, weather, venues and milestones | Long-save flavour relies on stable career/stat data |
| **M8 — Release Polish & Long-Save QA** | Onboarding, accessibility, performance and 100-year robustness | Finalises systems after core design settles |

Do not rigidly wait for an entire milestone to finish before touching the next one. Dependencies matter more than labels. A self-contained later task may proceed if its prerequisites are already satisfied.

---

