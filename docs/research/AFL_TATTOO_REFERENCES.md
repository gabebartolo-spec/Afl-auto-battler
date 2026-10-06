# AFL tattoo references and implementation notes
Reviewed 6 October 2026. Research and actionable handoff for Claude; no tattoo art or game implementation was changed.

## Scope and conclusion
This focused pass documents 13 named AFL players, including historical players, from AFL/club reporting and the AFL Players' Association. It is a reference library, not a complete census of the current roster. Dates below establish when a tattoo was documented, not that the player's entire collection is unchanged today.

Use general subject matter, scale and placement as reference for independently drawn game artwork. Do not trace a player's tattoo, copy its composition or recreate a branded character. For real-player rendering, record the evidence and whether an original substitute is used; do not claim that an approximation is the person's exact tattoo. The director's requested motifs remain rose, snake, barbed wire, bird, 666, love heart, Southern Cross stars and Asian-script lettering. This pass does not establish that every requested motif is worn by a particular AFL player.

## Documented examples
The first seven entries are compact paraphrases from the [AFLPA's 2014 tattoo feature](https://www.aflplayers.com.au/news-feed/stories/afl-ink-the-stories-behind-some-of-footys-best-known-tattoos). They are historical references, not automatic additions to 2026 player data.

| Player | Documented subject/placement | Use for this game |
|---|---|---|
| Leroy Jetta | Family memorial portraits on shoulder-blade area; children's names on chest | Family lettering is a motif reference; omit actual relatives' portraits/names from generic art. |
| Lance Franklin | Family portraits, flower and skull; heritage motifs in sleeves | Independently drawn flower/skull shapes; exclude exact portraits and heritage artwork. A reported flower is not proof of a rose. |
| Dustin Martin | Family/tribal wording on neck, shared family phrase on chest; skull/cash on hand and forearm | Reference placement/density; do not copy tribal wording, exact lettering or composition. |
| Travis Cloke | Back wings and personal wording; leg text | Original wing motif; avoid his exact back piece. |
| Nathan Jones | Grandfather portrait on forearm, family name and sleeve | Reference forearm coverage; no portrait reconstruction. |
| Dane Swan | Knuckle words, dense sleeves and leg imagery; premiership tattoo on leg | Separate small lettering from dense coverage; premiership tattoo precedent, not evidence for a universal bicep location. |
| Dayne Beams | Sleeve acquired when young | Density/placement reference only; source does not establish a motif list. |

Further sources:

| Player | Evidence | Adaptation / exclusion |
|---|---|---|
| Nathan Broad | Full-back Native American portrait, tattoo studio identified in [AFL report, 2019](https://www.afl.com.au/news/148873/move-over-dusty-there-s-a-new-king-of-ink-at-tigerland) | Exclude the exact portrait and culturally specific design. Back coverage illustrates a placement that is mostly hidden by a guernsey; it is not a priority for match-scale art. |
| Tom Liberatore | Simpsons imagery on both biceps and a food-bar tattoo in [Bulldogs report, 2019](https://www.westernbulldogs.com.au/news/248989/libba-flying-as-he-prepares-for-comeback-crozier). [AFL's watchlist](https://www.afl.com.au/news/132048/jlt-watchlist-eye-catchers-missing-faces-whats-new) identifies Cadbury packaging. | Exclude Simpsons characters and branded packaging. The useful reference is varied small, separate motifs rather than identical full sleeves. An original unbranded food/object illustration is possible. |
| Izak Rankine | Hand family wording, forearm astronaut/church/flag-colour composition and thigh wording, explained in [his AFL Q&A, 2024](https://www.afl.com.au/news/1110553) | Family wording, dates and an independently designed astronaut are general motif ideas. Do not reconstruct his specific composition or family/cultural story. The older [AFL feature](https://www.afl.com.au/news/118715/inside-the-suns-rankine-king-family-and-fried-rice) also reports birthday numerals behind his ear and a Thai protective symbol on his hand; that symbol is not random decoration. |
| Nick Watson | Japanese characters reported as spelling his surname on his arm in [AFL feature, 2025](https://www.afl.com.au/news/1266730/hold-onto-your-hats-the-wizard-has-a-few-more-tricks-in-store-for-2025). A [2026 interview](https://www.afl.com.au/news/1596265/inside-the-wizards-nick-watson-wild-ride-footys-new-rockstar-on-finals-fame-and-fashion//amp) reports short wording on his left hand. | Direct precedent for the requested Asian-script lettering category. Sources establish the reported lettering, not a verified transcription of its glyphs. Have a competent language reader check actual characters and meaning before drawing original lettering. Do not invent pseudo-writing. |
| Cam Rayner | Marvel Thor tattoo acknowledged in [his AFL Q&A, 2024](https://www.afl.com.au/news/1196014/cals-qa-brisbane-lion-cam-rayner-on-lessons-from-cotch-star-wars-unleashing-his-best) | Exclude the Marvel depiction. This source is not permission to reproduce it. |
| Mark Ricciuto | Shoulder-blade creature design after missing the 1997 flag; a premiership tattoo after playing in the 1998 win, in [AFL interview](https://www.afl.com.au/news/534596/interview-with-mark-ricciuto) | Strong distinction between belonging to a winning club and being a recognised premiership player. Use the career event, not whole-club membership, for the requested cosmetic feature. Do not copy his creature artwork. |

## Rights and asset method
Original tattoo artwork can itself be protected, even without a trademarked character. The wearer may not own its copyright. Arts Law specifically discusses reproduction of tattoo art in video games and notes that minor changes are not necessarily enough. Therefore independently author motif drawings, keep their source/licence records, and exclude unlicensed reproductions. [Arts Law: Tattoos, Intellectual Property, and the Law](https://www.artslaw.com.au/information-sheet/tattoos-intellectual-property-and-the-law/); [Australian Copyright Council: Tattoos & Copyright](https://www.copyright.org.au/browse/book/ACC-Tattoos-%26amp%3B-Copyright-INFO126/).

For this project:
- Draw fresh rose, snake, barbed-wire, bird, heart and constellation arrangements; do not use a tattoo photo as a tracing texture or copy a distinctive arrangement.
- Use original ordinary numerals/lettering with the existing usable font/art pipeline. No logos, branded characters or recognisable packaging.
- Keep family portraits, specific tribal/cultural designs and sacred/protective symbols out of the generic random library. Plain language lettering is a separate director-approved category, with characters and meanings checked.
- Photo/article access is research access, not an artwork licence. A player's consent to their likeness does not automatically clear the tattooist's artwork.
- Store a small asset record: design ID, original artist/creation route, reference URLs, licence/permission if relevant, supported placements and render substitutions.
- None of these rules assigns personality, aggression, ethnicity or football ability based on tattoos.

## Premiership-year tattoos — director decisions
Some players get a premiership tattoo. Others never do. Once a player gets one, every later premiership they win adds a year. The requested placement is the bicep, building into a year sleeve over a successful career. This is the game's chosen treatment; sources do not establish that all real players use that exact format or location.

Claude implementation:
1. Reuse recognised player premiership honours after a completed Grand Final. Do not award tattoos to the entire winning club list, predict wins, or count preseason/state-league flags as AFL flags.
2. Make an eligible player's initial adoption optional. Store the cosmetic decision once, independently of football RNG, with no repeated offers/chores or rerolls after loading. The adoption frequency is not specified by the director; use a restrained configurable rate and report it.
3. After adoption, append each later actual winning year automatically. No fresh chance roll for later flags. Deduplicate by competition/year; preserve chronological years.
4. Retain the tattoo and its years through transfers, save/reload and later careers within the same save. An entirely new career has its own simulated history.
5. Draw ordinary year digits using original/licensed game artwork on the bicep. Add further years as a coherent sleeve; keep them readable in close previews and avoid illegible miniature text or guernsey overlap.
6. Preserve imported confirmed tattoos where sourced. Do not infer a real player's existing tattoo from their premiership count alone. Starting-history tattoo import and new simulated tattoos are distinct.
7. Zero gameplay effects: no OVR, morale, leadership, loyalty or contract bonuses.
8. Validate first adoption/non-adoption, later flags, repeated result processing, transfers, save/reload, multiple clubs and several years. Cosmetic creation must not change football results or RNG.

## Follow-up scope for Claude
Integrate the director's motifs and dreadlocks into the existing appearance library and shared art contract. Use these references rather than repeating this research. Prioritise exposed biceps/forearms and close vignette readability; dense hidden back pieces add little at ordinary match scale.

No complete roster tattoo audit or asset rights clearance is claimed. The official [Oleg Markov tattoo-tour video](https://www.collingwoodfc.com.au/video/1819592/oleg-markovs-tattoo-tour-part-ii-the-black-and-white-show?modal=true&publishFrom=1751433735001&type=video&videoId=1819592) is a potential later visual reference; its actual footage was not viewed in this pass, so no motifs were inferred from its title. Likewise Daniel Rioli's [2019 stated tattoo plans](https://www.afl.com.au/news/49179/rioli-has-whole-body-crossed-in-hope-for-cousins-future) are plans, not proof of completed ink. Do not turn either into confirmed appearance data.
