### Audit repair sprint (2026-09-29, from `docs/SYSTEM_REALITY_AUDIT.md`)
**Status:** `DONE` (merged 2026-09-30). Each repair is recorded, with its measurements, in the audit's appendix.
- **A. Live-match plan reset (P0):** the plan you take into a live match is the plan at the first bounce, proven by driving the live start. PR #104.
- **B. Test harness:** every suite has a check floor, deliberate skips say so, and a self-test proves missing checks fail the run. PR #106.
- **C. Moment cards:** calls last a real passage of play and are situational (surge v hold, set-shot choices). PR #105.
- **D. Tagging:** a real trade. A specialist tagger on their star is worth close to a goal; a good midfielder sent to tag, or a tag on an ordinary player, costs you. The AI tags only with a specialist on the ground. PR #108.
- **E. Plans:** Balanced is the safe call, counters are sized to one or two goals, and list fit decides whether a plan pays. Through stars goes through your best three. Each plan has one description, written from the engine. PR #110.
- **F. Morale, form and coaching:** the profile says what morale is doing; "Form" is now "Recent games"; coaching tactics sharpen a plan's upside, measurably but secondarily. PRs #107 and #111.
- **G. Loose ends:** the coach table is built before a live week's other matches, and dead code is gone. The AI's tactical read is measured and recorded as low-impact. PR #109.
- **Open, for the director:** a valuable AI read would have to infer your plan from observed play (no psychic AI); Controlled tempo's list-fit split is unclear; "Fire them up" is still a free gain.

### Playtest test
For each important decision, verify the player can answer:
- What decision am I making?
- What information am I using?
- What do I expect to happen?
- Afterward, can I tell whether it mattered?

If those questions cannot be answered, that decision loop is not complete.

### Implementation approach
Treat each observed failure as a reproducible problem. Diagnose simulation authority vs visualisation/presentation before changing architecture. Prefer small fixes where sufficient; do not launch a movement-engine rewrite without evidence that local fixes cannot solve the problem. Use the user's phone playtest observations as the acceptance signal alongside targeted regression tests.

---

