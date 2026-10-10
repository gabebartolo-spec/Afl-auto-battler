## ARD-M8-005 — Long-career QA
**Status:** `TODO`  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED`

Test decades-long / 100+ year careers.

Watch for:
- save growth,
- duplicate career history,
- stale records,
- impossible list states,
- generated-player degradation,
- coaching-history corruption,
- draft/salary-cap dead ends,
- season rollover bugs,
- performance degradation.

Use automated long-run simulation wherever practical.

### Research refinement — 2026-10-05

**Dependencies:** current save/season lifecycle, player generation/development, Contracts/Draft and Career/CoachPathway; add M5-016 opening-mode coverage when implemented, not as a prerequisite for all QA.

**Smallest scope:** reproducible 5/10/20-year careers across contrasting club strengths and management policies before a longer integrity soak; preserve the existing 100+ year goal without rerunning it after every small change.

**Exclusions:** using simulation as proof of enjoyment, forcing dynasty turnover, universal win-rate targets or hidden balance assistance.

**Acceptance:** identity, ages, role histories, club stints, contracts/picks, honours and existing former-player links remain coherent; old saves load; no duplicate history, roster dead ends or unchecked stat/potential inflation; AI can sustain viable lists across generations. Save growth/loading and sim cost remain acceptable on the target phone.

**Validation:** record commit, seeds, starting clubs, policies, failures and distributions; compare low-admin, hold, youth, veteran and trade-heavy careers. Trace individuals through changing jobs, retirement and actual coaching links. Pair with observed multi-season follow-up on difficult decisions, remembered people and desire to continue.

---

