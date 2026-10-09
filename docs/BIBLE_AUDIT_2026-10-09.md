# Design documents audited against the design bible (2026-10-09)

Asked for by the director. Scope: `CLAUDE.md`, `README.md`, `docs/DESIGN.md`,
`docs/MATCH_VIEW.md` and `docs/ROADMAP.md` (§0 to §1.10, the items the bible
touches, §9.3 to §9.5), checked against [DESIGN_BIBLE.md](DESIGN_BIBLE.md).

**Result:** the existing documents already agree with most of the bible. One
real contradiction, four gaps, two questions only the director can settle, and
two places where the bible itself is behind the game.

**Not audited:** the roadmap is about 7,000 lines. Sections outside the scope
above were searched by keyword (zero-effect rules, authority claims, weather,
journalists, sim controls), not read line by line. The research chapters and
evidence documents were not audited; they record findings, not rules.

## Changed in this PR

| # | Finding | Where | What changed |
|---|---|---|---|
| 1 | The roadmap called itself the single source of truth, and nothing named the bible | ROADMAP header, §0.1.1; CLAUDE.md; DESIGN.md; README | The bible outranks them on design. The roadmap keeps execution, status and order |
| 2 | **Contradiction.** Press answers "change morale and/or board standing in a direction the copy promises". The bible says an answer is a dice roll: the same comment can lift or drop a player | ARD-M6-008 | Bible decisions recorded above the guardrails as `TODO`, unassigned. Built behaviour is unchanged |
| 3 | No rule that an agent says whether a feature deserves to exist before building it | CLAUDE.md | Added "Assess before you build" |
| 4 | No rule against asking the director to approve visibly broken art. "The right art loaded" covers fallbacks only | CLAUDE.md | Added the art check and the named faults |
| 5 | The balance gate says how to measure, not who calls balance settled | CLAUDE.md, ROADMAP §1.10 | Numbers close to real AFL and the director's playtest; an agent never declares it done |
| 6 | The pre-timeskip survey was not on the roadmap | ARD-M1-007 | Added as `TODO`, unassigned, with the director's open question |

## Already in line, nothing changed

- **Agency as the core pillar.** ROADMAP §0.2 ("fun and agency over simulation
  purity") and DESIGN.md's career direction say the same.
- **Decisions move the odds, never the certainty.** §0.2: a good decision "does
  not need to guarantee a win"; MatchSim "retains uncertainty".
- **Show the rules, not the answer.** CLAUDE.md and DESIGN.md: no best-move
  recommendations.
- **No number vomit, football language.** CLAUDE.md, ROADMAP §1.7 and §1.8.
- **Look and sound never affect the sim.** §9.3 flavour work has zero gameplay
  effects; appearance options are cosmetic only.
- **Weather matters.** ARD-M4-016 (director decisions 2026-10-06): wet, windy
  and hot affect play, calibrated against real numbers; the look has zero result
  effect.
- **Structural moves change the visual sim.** ARD-M8-003 already requires that
  calls such as Flood the backline visibly alter team shape.
- **The ground shows what happened.** MATCH_VIEW.md: the view "decides how each
  event looks, never whether it happens".
- **Journalists have personalities.** RPG-002 names five.

## For the director to decide

1. **The execution queue and the bible's current focus disagree.** §0.4.1 makes
   the Season stats patch the single highest priority. The bible's biggest
   game-feel improvement is the visual sim reacting to coaching moves
   (ARD-M8-003, with M4-001, M4-002 and M4-004 for agency tuning). The queue was
   not reordered here. Does the bible's focus move to the top, or follow the
   stats patch?
2. **Two standing rules contradict each other.** ROADMAP §0.1 (2026-09-28)
   gives Claude standing authority to pick up ready roadmap items and merge
   them. CLAUDE.md says a roadmap entry is not authorisation and nothing starts
   until assigned. The bible does not settle this. Which one stands?
3. **"Auto-battler".** README and DESIGN.md open by calling the game an
   auto-battler in which you watch every match. The bible says active
   participation sets the game apart. Is that framing still right? Left as is.
4. **"Game first, simulation second".** §0.2 says this; the project description
   says agency and simulation integrity take equal importance. The bible says
   agency is the core pillar and the game is objective. Left as is.

## Proposed bible updates (need the director's consent, not made)

- The open question "How does weather affect a match?" is already answered by
  ARD-M4-016. It can come off the bible's open list.
- "Journalists have personalities" could name RPG-002's five approved types.
