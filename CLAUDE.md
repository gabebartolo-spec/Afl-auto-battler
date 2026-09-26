# AFL Auto-Battler: working rules

Godot 4 / GDScript. Run `tools/run_tests.sh` (or `tools/run_tests.sh draft_ui`
for one suite) before pushing.

## Project philosophy (permanent)

**Designed by a person, developed with AI, never designed by AI.** The director
supplies the vision, taste, AFL knowledge, priorities and final judgement.

- **Mobile first, portrait first.** An Android phone in portrait is the
  reference design; desktop is secondary. No hover-only information, thumb-sized
  targets, deliberate scrolling, natural Android Back.
- **No number vomit.** Show a number only when it helps the player understand
  or decide. No hidden modifiers, coefficients or diagnostics; detail lives
  behind deliberate drill-downs.
- **No UI vomit.** One clear job per screen. If two elements answer the same
  question, keep the better one. Do not build UI just because data exists.
- **No generic AI-template design** (details below).
- **Natural AFL language.** Write what a coach, recruiter, commentator, player
  or supporter would actually say. No pseudo-football, engine terms or
  software-documentation prose.
- **Gameplay before analytics.** Revisit hidden simulation mechanics only when
  play exposes a real problem, a feature needs it, or the director asks.
- **Restraint is a feature.** A good idea is not automatically a good addition.
  Prefer the simplest thing that creates the football fantasy.
- **Challenge the director** when an idea conflicts with this philosophy, is
  poorly scoped or has a simpler alternative. Say so, then propose better.
- **A roadmap is context, not authorisation.** Do not start a roadmap item,
  branch, PR or follow-up until it is explicitly assigned. When an assigned
  task is done: stop, report, recommend the next step, wait.

## UI and writing

The shared visual language lives in `scripts/ui/UiKit.gd`; use it before
inventing anything local.

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
