## 1.5 Save compatibility

For persistent-state changes:
- Existing saves must load.
- New keys require safe defaults.
- Do not rename/remove persisted keys without migration.
- Add/load an older save fixture where practical.
- Perform save → reload → continue-season roundtrip testing.
- Never silently overwrite an existing career when creating a new one.

## 1.6 Mobile-first UI

Primary target is Android portrait.

Minimum validation:
- 360px-ish narrow portrait.
- 390px-ish common portrait.
- 412px-ish wider portrait.

Rules:
- no one-character-per-line label wrapping,
- no critical clipped controls,
- no accidental horizontal scrolling,
- touch targets should be comfortably tappable,
- critical state must not rely on hover,
- avoid dense tables on primary screens,
- detailed numbers belong in drill-down/stat screens.

## 1.7 No "number vomit"

Primary screens should answer:
- what is happening,
- what matters,
- what can I do.

Deep analytics can exist in secondary screens. Do not turn coaching, reports or matchday UI into debug dashboards.

### UI anti-slop reset — current concern
**The current UI policy/implementation has drifted away from the project's anti-slop criteria and needs an explicit corrective pass.**

This concern is specifically about **visual styling language**, not about information density or "visual vomit". A screen can be clean and sparse yet still look slop if it uses the wrong card geometry, corner treatment, colour palette and generic app-template styling.

**Footy Redraft and AFCM are negative references for this specific aesthetic problem.** This is not criticism of their gameplay or information density; they are examples of the kind of generic management-game/mobile-app look this project should avoid.

Anti-slop criteria:
- avoid generic AI-template / app-template visual language,
- avoid soft rounded cards as the default container shape,
- avoid excessive corner radii, pill buttons and chip-heavy composition,
- avoid generic muted-green/teal/blue SaaS-style palettes,
- avoid decorative gradients, glows, glassmorphism and gratuitous shadows,
- avoid every section being enclosed in its own rounded rectangle,
- avoid generic "premium mobile dashboard" aesthetics,
- avoid condensed display fonts or all-caps styling unless genuinely justified,
- use sentence case and natural football language,
- use flatter, sharper, more restrained geometry where possible,
- let typography, spacing, rules/lines and club colours create hierarchy instead of rounded card stacks,
- keep the visual language recognisably football-specific rather than resembling a finance/productivity app,
- maintain mobile-first readability and touch clarity.

The anti-slop test is primarily visual: **if the screen could plausibly belong to Footy Redraft, AFCM, a generic AI-generated sports manager, or a modern SaaS dashboard after swapping the logo, it has drifted too far.**

When revisiting existing UI, Claude should inspect card shape, corner radius, button silhouette, palette, border treatment, typography and spacing before changing information architecture. Do not misread this note as an instruction to simply remove stats or reduce content.

This note is not permission for a broad unreviewed redesign. Apply the anti-slop standard incrementally to authorised UI tasks and record larger systemic cleanup as its own scoped audit/repair item if needed.


### Art-agent tooling permission for bespoke UI
For authorised UI/art work, the art agent may investigate and use **free software only** to create bespoke interface assets, layouts, textures, panels, decorative elements, typography treatments, iconography and other presentation pieces that help the game escape generic app-template aesthetics.

Rules:
- Free/open-source tools are preferred.
- No paid licences, subscriptions, paid plugins, marketplace packs or trials that later charge without separate explicit user approval.
- The art agent may research, download and use suitable free software if its environment permits.
- If the agent cannot install or operate a required free tool directly, it may ask the user to install it and should provide concise instructions.
- Any new tool introduced should have its source/licence noted in the relevant implementation notes.
- Tool adoption must serve the game's bespoke football-game visual identity; do not add software merely because it is fashionable or powerful.
- Generated UI assets still need to obey the anti-slop criteria above and the project's existing licensing/copyright guardrails.

This permission includes software for areas such as vector UI design, raster painting, icon creation, texture generation, layout mockups, motion/UI animation, sprite-sheet work and other custom interface production, provided the software itself is free to use.


### Font-sourcing permission
The art agent may also research, download and use **free fonts** for the game's UI and visual identity under the same free-only rules.

Requirements:
- Prefer fonts with clear permissive licences suitable for game distribution, such as OFL or similarly explicit free-use licences.
- No paid font licences, subscription font services, marketplace font packs, or trials that later charge without separate explicit user approval.
- Record the font source and licence in implementation notes.
- Do not use a font merely because it is trendy; it must support the game's bespoke football-game identity and anti-slop criteria.
- Avoid condensed display fonts, generic SaaS/productivity typography, or over-stylised novelty fonts unless there is a specific justified use.
- Verify legibility at narrow Android portrait widths and in match/vignette overlays.
- If the art agent cannot install/access a suitable free font directly, it may ask the user to install it and should provide concise instructions.

Font choices should reinforce the principle that the interface feels like a **game**, not an application.

