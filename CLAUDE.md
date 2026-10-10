# AFL Auto-Battler: working rules

Read in full at session start: `docs/roadmap/open-requirements.md` (open director requirements, owner,
status); the roadmap index is `docs/ROADMAP.md`. Must-read files stay under 60 KB (CI: `tools/check_doc_sizes.py`).

Godot 4 / GDScript. Run `tools/run_tests.sh` (or `tools/run_tests.sh draft_ui`
for one suite) before pushing.

## The design bible comes first (director, 2026-10-09)

Read [docs/DESIGN_BIBLE.md](docs/DESIGN_BIBLE.md) before design or feature work.
It is the ultimate truth for what this game is. Both Claude accounts and every
role work from it.

- **Authority.** Where this file, the roadmap or any other document disagrees
  with the bible, the bible wins: report the conflict and correct the other
  document. The roadmap still owns execution, status and order.
- **Nobody edits the bible without the director.** Each change needs the
  director's explicit consent for that change. Propose it; do not make it.
- **Assess before you build.** Before starting a feature, say in a line or two
  whether it deserves to exist against the bible's feature test and which intent
  it serves. The director's say is final.
- **What can affect the sim.** What the coach says or decides can affect the
  sim. How the club looks or sounds never does. Weather is the one exception
  (the condition affects play; its look does not).
- **Art is checked before the director sees it.** Inspect your own output first.
  Never ask for approval on work with a visible fault: skin through a jumper,
  broken anatomy, a bizarre animation, a ball that hovers or moves independently
  of the player using it, a ground that breaks AFL conventions.
- **Balance is the director's to call.** An agent may report that the numbers
  are close to real AFL. Balance is settled only when the director's own
  playtest also passes. Never declare it done.

## Project philosophy (permanent)

**Designed by a person, developed with AI, never designed by AI.** The director
supplies the vision, taste, AFL knowledge, priorities and final judgement.

- **Mobile first, portrait first.** An Android phone in portrait is the
  reference design; desktop is secondary. No hover-only information, thumb-sized
  targets, deliberate scrolling, natural Android Back.
- **No number vomit.** Show a number only when it helps the player understand
  or decide. No hidden modifiers, coefficients or diagnostics; detail lives
  behind deliberate drill-downs.
- **Visual references are selective.** AFCM is not a visual aspiration. Preserve the established editorial design; clean screens must still expose the facts needed for the current choice. Read the focused chapters linked from [genre research](docs/GENRE_ENJOYMENT_RESEARCH.md); director decisions and scoped accepted extensions are recorded in roadmap §9.2.
- **No UI vomit.** One clear job per screen. If two elements answer the same
  question, keep the better one. Do not build UI just because data exists.
- **No generic AI-template design** (details below).
- **Natural AFL language.** Write what a coach, recruiter, commentator, player
  or supporter would actually say. No pseudo-football, engine terms or
  software-documentation prose.
- **Gameplay before analytics.** Revisit hidden simulation mechanics only when
  play exposes a real problem, a feature needs it, or the director asks.
- **Make the rules transparent; don't make the decision.** Show opponent
  facts, player identities and capabilities, and let every rule be looked up
  exactly (what a synergy needs, what a role does). Let the player decide the
  response: no "best choice" labels, suggested line-ups, recommendation
  prompts, optimal matchup hints or "one more X" checklists on the main
  surface - there may be several reasonable answers with trade-offs.
- **Restraint is a feature.** A good idea is not automatically a good addition.
  Prefer the simplest thing that creates the football fantasy.
- **Challenge the director** when an idea conflicts with this philosophy, is
  poorly scoped or has a simpler alternative. Say so, then propose better.
- **A roadmap is context, not authorisation.** Do not start a roadmap item,
  branch, PR or follow-up until it is explicitly assigned. When an assigned
  task is done: stop, report, recommend the next step, wait.

## Verification (director, 2026-10-06, from the #291 assessment)

- **Real taps.** A UI flow is proven with a real tap at the control's position on screen, not only by calling its handler (`emit_signal("pressed")`): overlays and hit areas that block a finger only show up that way. New or changed touch flows get at least one real-tap check.
- **The right art loaded.** A capture or test of a vignette or figure proves the intended sheet or atlas loaded, not a fallback.
- **Change approach after repeated failure.** After two similar failed fixes of the same problem, stop patching: gather different evidence (a capture, a trace, a measurement) and rethink the approach before trying again.

## UI and writing

The shared visual language lives in `scripts/ui/UiKit.gd`; use it before
inventing anything local.
The visual identity rules (tokens, type roles, the component kit, screen templates,
art and proof rules) are in [docs/VISUAL_STYLE_GUIDE.md](docs/VISUAL_STYLE_GUIDE.md);
read it before touching any screen or vignette. Its evidence is
[docs/research/VISUAL_AUDIT_2026-10-10.md](docs/research/VISUAL_AUDIT_2026-10-10.md).

**Not boring (director, 2026-10-08: "dark mode doesn't need to be boring
mode").** The UI must have life. Approved pillars: club colour as atmosphere
(your club's colours carry your screens, both clubs' on match day), big type
and motion (the scoreboard face for headline facts; count-ups, reveals,
transitions), and the 2.5D art and textures of the ground beyond the match.
Proposed, to be shown on the hub first: each screen leads with one hero
element. Gradients and glows, colourful
(club-tinted) surfaces and bold decoration (turf, chalk, crowd motifs) are
now allowed when used deliberately; they override the restraint rules below
where the two conflict. Still never at the cost of readability or usability.

**Visual identity.** Avoid dark green/charcoal rounded cards everywhere, gold as
the universal accent, nested rounded rectangles, piles of pills/chips/badges,
every fact in its own card, generic dashboard grids, gradients, glows, big
corner radii, excess separators, decorative stat boxes and icons. Prefer flat,
editorial layouts: typography, alignment, spacing, restrained surfaces.

**Colour.** A restrained warm-neutral palette so clubs, match information and
real states provide the colour. Accent (red) only for the primary action;
selection is a light outline; GOOD/BAD only for genuine state. Ordinary labels
are TEXT or MUTED. Gold is not "important".

**Typography.** Weight and size before colour, from UiKit's type scale.
Sentence case unless AFL convention says otherwise (OVR, POT, Grand Final). No
ALL CAPS labels, wide letter spacing, condensed body copy or tiny uppercase
metadata. The condensed face is for scores. Font changes are project-wide
decisions.

**Components.** Before adding a pill, card, badge or progress bar, ask whether
typography, spacing or alignment could say it. Panels mean real grouping, have
no border, and no radius above `UiKit.RADIUS`. Secondary buttons are outlines.

**Copy.** Concise football language. Do not explain simulation mechanics
(percentages, internal rules) unless the player needs them to decide; do not
repeat what context already shows.

**Consistency.** Reuse what works; don't invent a mini design system per
screen, and don't copy a template-looking pattern because it exists. Apply
these rules whenever a screen is materially touched, without turning that into
an uncontrolled redesign.

**Review test.** Without the AFL names and logos, would the screen still look
like this game, or like any AI-generated sports-management app? If the latter,
simplify it. Authored and restrained, not weird; never at the cost of
usability.

## Explicitly assigned flavour work — 2026-10-06

The director reviewed and included FL-001–FL-008 for Claude's queue. Read [ROADMAP §9.3](docs/roadmap/21-9-3-approved-flavour-and-culture-work-director-decisions.md#93-approved-flavour-and-culture-work--director-decisions-2026-10-06) for scope, dependencies, statuses and validation. Audit decorative appearance so it is distinct from actual game information. Necessary new ritual/farewell vignette scenes are explicitly authorised; use the shared 2.5D art and preserve tactical-scene gates. Every addition has zero gameplay effects. This approval does not mark any implementation complete or authorise unrelated research candidates.


## Explicitly assigned visual styling — 2026-10-06

The director included all eight STYLE-01–STYLE-08 work packages after the complete interview. Read [ROADMAP §9.5](docs/roadmap/23-9-5-approved-visual-styling-work-director-interview-2026.md#95-approved-visual-styling-work--director-interview-2026-10-06). Dark Android is primary; wide-screen and light maintenance follow. The Training **player-row** name/secondary-line stack is a confirmed vertical-alignment defect, independent of broad restyling. Inspect the current implementation/art branch before repairing audit-snapshot findings.

The art agent has higher authority than ChatGPT on visual direction; Claude implements its treatment and reports constraints. **All final decisions go through the director.** Scope approval permits scoped prototypes/reviewable implementation, not final font, palette, geometry or layout selection. Obtain final director appearance approval before completing/merging visual treatments; ordinary green CI is insufficient. Preserve gameplay, information, touch/Back, existing 2.5D art and correctness/performance gates. No new scene authority or competing design system is added. No rejected style candidates remain.

## Skills improve over time (director, 2026-10-08, all projects, both accounts)

- **Learnings, with an evidence bar.** Any agent may add a finding to a skill's
  `references/learnings.md`, but only once it has proved effective: a quality-check method that
  caught or prevented a real defect; a recurring failure whose fix was verified afterwards by a
  test, capture or green CI; or a measured time saving. Each entry names the date, project,
  evidence (PR, commit, run or capture) and the general lesson. No hunches or untested ideas. If a
  finding contradicts the skill, correct the skill itself instead of appending a note. A lesson
  that keeps holding true is promoted into the skill's main text.
- **Project spin-off skills.** An agent may create a project-specific skill in this repo, named
  `afl-<topic>`, when a general skill needs project-only detail. It says which general skill it
  extends, and general lessons still go back into the general skill so other projects benefit.
