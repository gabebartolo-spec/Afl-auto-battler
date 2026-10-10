## 1.12 P0 gate — System Reality Audit: does the mechanic actually work?

**Status:** `PARTIAL` — the original audit/repair foundation (#103 and recorded repair sprint) is DONE; the director's new exhaustive gameplay-lever/function-and-copy pass below is TODO  
**Merged:** PR #103 as `ae4eb7b`; audit report is `docs/SYSTEM_REALITY_AUDIT.md`.  
**Priority:** `P0`  
**Autonomy:** `SUPERVISED — DIAGNOSIS FIRST`

### Director-required follow-up — every gameplay lever must work and its copy must tell the truth (2026-10-07)
**Status:** `TODO` — a new follow-up under this existing audit owner, not a duplicate audit system. Retain the existing P0 correctness classification and the Stats patch's single highest priority. **Owner:** Claude performs the measured engineering audit and reports evidence.

**Check ALL gameplay levers:** does any control or choice claim to change something while actually doing nothing, applying the wrong effect or being silently overwritten? Build an exhaustive inventory from current player-facing screens and actual mechanics, covering match preparation/live/break calls and decision branches, lineup/positions/roles/tagging/ruck/interchange, plans/tempo/pep talks, training/individual development/position projects, staff/recruiting, contracts/trades/draft/list decisions, backing/promises, board/media/events, synergies and any other gameplay-affecting choice. Include defaults, neutral choices, toggles, disabled/unavailable states, manual versus auto/sim paths and AI parity where applicable. Identify genuinely presentation-only settings honestly; do not invent gameplay effects for cosmetics.

For each lever:
- Trace **visible control → saved/live authoritative state → actual rule/event calculation → observable consequence**. Check timing, duration, eligibility, expiry, save/load/season transitions and later auto-selection/reset paths as relevant. Flag dead handlers, unused fields, placebo flags, unreachable branches, display-only calculations, effects cancelled by another rule and claims that outlive the effect.
- Prove the claimed effect with meaningful targeted regression checks and seeded matched before/after comparisons where results are stochastic. A handler firing, label changing or nonzero constant is not proof. Verify the intended football process, not merely a noisy difference in final scores. Effects may be conditional, modest or fail in an individual match; distinguish this from a no-op. Reuse trustworthy existing evidence before running new audits.
- **Audit every piece of player-facing lever copy:** names, descriptions, candidate information, tutorials/Stat Guide/help, assistant notes and retrospective reports. Does it accurately describe what the lever really does in **plain, concrete football language**, rather than vague promises such as “adds pressure” or “improves the team”? State the actual action/affected players, when it operates, meaningful conditions and tradeoffs without exposing raw coefficients or promising a guaranteed outcome. For example, a rotation policy should explain who rests sooner versus who stays on longer and the fatigue cost, only if the engine actually implements that behaviour.
- Ensure defaults/neutral options explain their real behaviour, unavailable options explain the real restriction, and retrospective copy reports actual observed evidence without invented causality. Keep distinct levers distinguishable, and do not describe selection eligibility, target frequency or a temporary role assignment as a change to underlying ability.

Deliver an itemised **lever / claimed behaviour / actual implementation / effect evidence / copy mismatch / required fix** register. Record what was exercised and what remains unverified. Repair confirmed no-ops, misleading copy and overwritten effects within existing authorised scope; when the intended mechanic is unresolved, present the concrete design discrepancy for director decision rather than silently inventing a buff or cutting the lever. Preserve existing balance, appearance, lifecycle-review, device and merge gates. Do not mark the exhaustive pass DONE from a few controls or a green full suite.



### Trigger
The Momentum meter existed as a player-facing system even though MatchSim had no real Momentum state underneath it. That was not a design reason to remove Momentum; it exposed a more serious process risk: other "implemented" systems may also be UI-only, disconnected, written-but-never-read, statistically irrelevant, or tested only for existence rather than behaviour.

### Goal
Establish which current player-facing systems are **real**, which are only partially connected, and which do nothing meaningful.

This is an **audit before repair**. Do not start fixing individual findings while still discovering the scope unless a destructive/soft-locking defect makes continued testing unsafe.

### Required end-to-end trace
For every implemented player-facing mechanic, trace:

`player sees/chooses → state created → state stored → engine/system reads it → calculation changes → outcome changes → result is surfaced back`

A break anywhere in that chain is a finding.

At minimum inspect:
- Momentum and Team Form,
- traits and synergies,
- game plans/tactics and quarter-break calls,
- moment/event choices,
- tagging and defensive match-ups,
- Play through / focal-player instructions,
- positions/roles, selection and interchange behaviour,
- attributes and OVR where consumed,
- player form/morale/fatigue,
- injuries/suspensions where implemented,
- training, XP and passive reserves development,
- coaching Teaching/Tactics/Man-management effects,
- draft/scouting uncertainty and list/draft valuation systems,
- salary-cap consequences,
- every other implemented modifier/toggle/meter presented as consequential.

### Look specifically for
- state written but never read;
- return values/modifiers calculated then discarded;
- UI reading one value while MatchSim uses another;
- dead/unreachable branches and placeholder callbacks;
- effects overwritten, normalised away or applied after the result is decided;
- values technically connected but too weak/rare to matter;
- player/AI asymmetry;
- save/load dropping the state;
- report-only statistics presented as mechanics;
- tests that prove a widget/key/function exists but do not prove behaviour changes.

### Empirical verification
Where practical, use controlled paired-seed or identical-state comparisons: mechanic on/off, trait present/absent, plan A/B, tag/no tag, form neutral/high, coach effect weak/strong, and equivalent deterministic checks for non-match systems.

The question is not whether every mechanic is perfectly tuned. The question is **whether it genuinely changes the thing the player is told it changes**.

### Classification
Every audited system gets exactly one factual status:
- `WORKING`
- `WORKING BUT QUESTIONABLE`
- `PARTIALLY CONNECTED`
- `UI / REPORT ONLY`
- `NO-OP`
- `DEAD / DISCONNECTED`
- `UNVERIFIED`

### Output
Create `docs/SYSTEM_REALITY_AUDIT.md` containing:
- executive counts by classification;
- critical player-facing no-ops/misleading systems first;
- system-by-system implementation path and behavioural evidence;
- what existing tests actually prove;
- weak/fake-confidence tests;
- recommended repair order.

Do **not** mark a system working because code exists or a test is green.

### Audit result (2026-09-29, PR #103)
40 systems were classified: 26 working, 7 working-but-questionable, 2 partially connected, 2 UI/report-only, 1 no-op, 1 dead/disconnected and 1 unverified.

Critical findings:
- A game plan chosen on Selection/Coaching is silently reset to Balanced immediately before a live match starts unless reselected in the pre-bounce box. Simulated rounds are unaffected.
- Moment-card choice policies produced less than half a point of margin difference across the measured sample despite roughly seven cards a match.
- Tagging cuts the target's disposals but did not produce a measurable team-margin effect.
- Through stars had no measurable result effect; Balanced was materially worse than several alternatives in the measured setup.
- Morale has a sizeable hidden match effect, while Coaching's player "form" display is report-only.
- Several plan descriptions quote effects that do not match the engine.
- Existing tests often prove storage/multipliers rather than outcomes; some guarded matchday checks can silently skip under load while the suite still reports pass.

### Gate
The audit itself is complete. Repairs are held for user review. Once released:
1. player-facing `NO-OP`, `UI / REPORT ONLY` (when presented as a mechanic), and serious `PARTIALLY CONNECTED` findings enter the execution queue ahead of unrelated feature expansion;
2. repair priority is player deception/no-op decisions → core gameplay importance → severity → simplest robust fix;
3. desired mechanics are **fixed, not deleted**, merely because their implementation is incomplete, unless the user explicitly changes the design.

---

