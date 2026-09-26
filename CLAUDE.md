# AFL Auto-Battler: working rules

Godot 4 / GDScript. Run `tools/run_tests.sh` (or `tools/run_tests.sh draft_ui`
for one suite) before pushing.

## UI and writing: avoid the generic "AI template" look (permanent rule)

Functional clarity comes first, but every screen should look designed for this
AFL game, not assembled from common dashboard patterns.

**Visual identity.** Avoid dark green/charcoal rounded cards everywhere, gold as
the universal accent, nested rounded rectangles, piles of pills/chips/badges,
every fact in its own card, generic dashboard grids, arbitrary gradients, glows,
big corner radii, excess separators, decorative stat boxes, decorative icons.
Add no new colour, font treatment, radius, shadow, chip or card style unless it
serves hierarchy or function. Prefer flatter, editorial layouts: typography,
alignment, spacing, restrained surfaces, clear sections.

**Colour.** Keep the global palette restrained so club colours, match
information and important states provide the colour. Accent only for selected
state, the primary action, genuinely important status, or club identity. Do not
colour ordinary labels. Gold is not "important".

**Typography.** Weight and size before colour. Sentence case unless AFL
convention says otherwise (OVR, POT). No ALL CAPS headings/buttons everywhere,
no wide letter spacing, no condensed bold body copy, no tiny uppercase
metadata labels everywhere, few weights per panel. Font changes are
project-wide decisions, never made while building a feature.

**Components.** Before adding a pill, card, badge or progress bar, ask whether
typography, spacing or alignment could say it without another box. Rounded
panels mean real grouping, not decoration.

**Copy.** Write like an Australian football game, not SaaS: concise, ordinary
football language a coach, commentator, recruiter or supporter would use. No
"Plenty of room", "Unlock your potential", "Key insights", "What this means".
Do not explain simulation mechanics (percentages, internal rules) unless the
player needs them for a decision; do not repeat what context already shows.

**Numbers.** Show only numbers needed to understand the situation, compare
choices or decide. Detail lives behind deliberate drill-downs.

**Consistency.** Inspect existing UI first and reuse what works; do not invent a
mini design system per screen. But do not copy an existing template-looking
pattern just because it exists: when touching such a screen, improve it
incrementally.

**Review test.** If the AFL names and logos disappeared, would the screen still
look like this game, or like any AI-generated sports-management app? If the
latter, simplify and give it more deliberate typographic/layout character.
Authored and restrained, not weird; never at the cost of usability.
