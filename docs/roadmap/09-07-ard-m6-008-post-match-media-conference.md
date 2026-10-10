## ARD-M6-008 — Post-match media conference
**Status:** `VERIFY` — the post-match media conference is on `main` (PR #183 closed, carried by #208); a phone playtest remains. _(reconciled 2026-10-05)_  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

### Intent
After a match, the coach faces the press in a short, dramatic vignette: a journalist puts a pointed question (a heavy loss, a star's poor form, an umpiring flashpoint, a selection call, a winning streak) and the player answers by choosing one of a few multiple-choice responses. What the coach says publicly can move **player morale** and **board happiness**.

### Direction
- Treat this as part of the existing club-life/event system (weekly `ClubLife` events, morale and Board Confidence, ARD-M6-003), not a parallel system: same morale/board plumbing, same consequence rules.
- Questions come from what actually happened in the match and season (margin, result run, a named player's game, injuries, ladder position, board expectation), so the conference reads as a response to this week rather than random flavour.
- Every answer is a real trade-off with a consequence the player can understand: e.g. backing an out-of-form player publicly lifts his morale but costs a little board patience if the side keeps losing; criticising the group may sting morale but satisfy a frustrated board. No answer that is simply "correct", no option that does nothing, and no hidden coefficients on the main surface.
- Show the outcome in football language afterwards (e.g. "The playing group appreciated the support", "The board wanted more accountability"), not as numbers.
- Short and skippable: a few lines, two to four answers, one tap. It must not appear after every match; it should feel like an occasion (big wins/losses, milestones, controversy), and the same question must not repeat in a short span.
- Mobile first: readable at 360-390 px, thumb-sized answers, natural Android Back.

### Design bible alignment — director decisions, 2026-10-09
**Status:** `TODO`, unassigned. Recorded from the [design bible](DESIGN_BIBLE.md); do not start without assignment.

- A press answer is **a dice roll based on logic**, not a fixed transaction. The same comment can land two ways: criticise a young player and his morale may drop, or his resolve may tighten. This replaces "in a direction the copy promises" below wherever the two disagree.
- The player must be able to tell beforehand that a comment carries risk. The conference tests media literacy, relationship management and board compliance.
- Answers move player morale, board expectations **and relationships with the press** (the journalists of RPG-002).
- The effect on the named player is visible afterwards, for better or worse, so the coach can adjust or carry on.
- Still to design before building: how the risk is shown without number vomit, what decides which way an answer lands, and where the player sees the result.

### Guardrails
- No fake choices: every answer changes morale and/or board standing in a direction the copy promises (see the System Reality Audit's fake/no-op choice rule).
- Effects are modest and decay; the media conference cannot outweigh results, selection or coaching.
- Natural AFL language: what a coach would actually say at a press conference.

### Acceptance
- Conferences appear only after notable matches and never repeat the same question within a short span.
- Each answer has a measurable effect on morale and/or board happiness, matching its copy, verified by targeted tests.
- Skipping is always possible and has a defined, neutral outcome.
- Narrow Android portrait layouts remain usable.

### Research refinement — 2026-10-05

**Dependencies:** current ClubLife, morale/board effects, actual match/season context and phone checks. Preserve M1-011's DONE event trade-off foundation; verify M6-008's merged conference before adding content.

**Smallest scope:** improve one existing question and its answer-to-effect mapping. Use a short, pointed football question with logical consequences and room for restrained humour; keep its immediate response readable.

**Exclusions:** a new dialogue engine, personality quiz, compulsory weekly conferences, arbitrary permanent coach buffs or the unselected later-callback prototype. Do not duplicate #220/#226's backing promise/payoff.

**Acceptance:** each answer applies its promised existing effect once; costs remain understandable, skip stays neutral, named people and circumstances come from current facts, and quiet matches need no conference. Do not claim real players' private intent or let amusing wording conceal an ignored answer.

**Validation:** every answer and skip, thin/changed context, repetition suppression, saved effect state and repeat delivery; Android reading, touch and Back. Observed players should explain why the answer fits and what changed. New later callbacks require selection of RC-005 first.

---

