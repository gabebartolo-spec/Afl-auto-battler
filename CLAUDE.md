# AFL Auto-Battler: working rules

The design bible, the roadmap index and the open director requirements (owner, status) load in
full at session start ("Always loaded" below). Must-read files stay under 60 KB (CI: `tools/check_doc_sizes.py`).

Godot 4 / GDScript. Run `tools/run_tests.sh` (or `tools/run_tests.sh draft_ui`
for one suite) before pushing.

## Always loaded

Claude Code imports these core documents in full at every session start (the `@` lines below),
so they are part of this file: read them as rules, never skim or skip them.

@docs/DESIGN_BIBLE.md
@docs/ROADMAP.md
@docs/roadmap/open-requirements.md

## The design bible comes first (director, 2026-10-09)

[docs/DESIGN_BIBLE.md](docs/DESIGN_BIBLE.md) is loaded in full at session start (above).
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
- **Numbers belong at the decision gate (director, 2026-10-18).** Each option
  states its upside, its downside, the size and the odds, in football words, as
  percentages, and never which is better. Off the gate, show a number only when it
  helps the player understand or decide; no hidden diagnostics on the main
  surface, detail behind deliberate drill-downs.
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
every fact in its own card, generic dashboard grids, big corner radii, excess separators, decorative stat boxes and icons. Prefer flat,
editorial layouts: typography, alignment, spacing, restrained surfaces.

**Readability is a pillar (design bible, director 2026-10-13).** It applies to
every screen. Sections feel distinct: club colours and strategic bold set them
apart, because text that is all one colour and weight harms readability. A
player's or club's allegiance is obvious at a glance, without reading the name.
No text the coach needs is overlooked: nothing he decides on sits in uniform
grey. Club colour must stay readable (check contrast for dark clubs on the dark
page) and must not be mistaken for GOOD/BAD or the primary action.

**Colour, type, components, copy.** The exact rules are in
[docs/VISUAL_STYLE_GUIDE.md](docs/VISUAL_STYLE_GUIDE.md): colour and where it goes
(§2.1-2.2), type roles (§2.3), the component kit (§3), copy (§5). Before adding a
pill, card, badge or progress bar, ask whether typography, spacing or alignment
could say it. Font changes are project-wide decisions.

**Consistency.** Reuse what works; don't invent a mini design system per
screen, and don't copy a template-looking pattern because it exists. Apply
these rules whenever a screen is materially touched, without turning that into
an uncontrolled redesign.

**Review test.** Without the AFL names and logos, would the screen still look
like this game, or like any AI-generated sports-management app? If the latter,
simplify it. Authored and restrained, not weird; never at the cost of
usability.

## Assigned flavour and styling work (director, 2026-10-06)

- **Flavour FL-001-FL-008:** scope and status in [ROADMAP §9.3](docs/roadmap/21-9-3-approved-flavour-and-culture-work-director-decisions.md#93-approved-flavour-and-culture-work--director-decisions-2026-10-06). Every addition has zero gameplay effects and must look distinct from real game information; new ritual/farewell vignette scenes are authorised (shared 2.5D art, tactical-scene gates kept).
- **Styling STYLE-01-STYLE-08:** scope in [ROADMAP §9.5](docs/roadmap/23-9-5-approved-visual-styling-work-director-interview-2026.md#95-approved-visual-styling-work--director-interview-2026-10-06). Dark Android first. Light theme parked (director 2026-10-13: "im also happy to abandon 'light mode' for now"): no new light-theme work, captures or tests; the code stays. A visual treatment merges only after the director approves its look; green CI is not enough.
- The Training player-row name/secondary-line stack is a confirmed vertical-alignment defect.

## Skills

Learnings and spin-off skills follow the global rules in `~/.claude/CLAUDE.md` (only the lead adds a learning, with evidence). A project skill is named `afl-<topic>` and says which general skill it extends.
