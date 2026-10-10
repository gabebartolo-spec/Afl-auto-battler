## ARD-M7-010 — Sir Doug Nicholls Round & Indigenous guernsey library
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

### Intent
Make Sir Doug Nicholls Round a genuine annual competition event, not a cosmetic text label. The round should celebrate Aboriginal and Torres Strait Islander football culture through researched club-specific presentation, special guernseys and matchday visuals while treating the artwork, artists and cultural stories with care.

The implementation should reflect the real AFL model: all clubs wear specifically designed Indigenous guernseys for Sir Doug Nicholls Round, with the real competition treating those guernseys as storytelling pieces created in collaboration with Aboriginal and Torres Strait Islander artists. Since 2014, all AFL clubs have worn dedicated designs for the round; recent editions run across two rounds.

### Extensive research requirement
Before implementation, Claude must perform a **club-by-club historical design audit** covering, where source material is available, every AFL Sir Doug Nicholls / Indigenous Round guernsey from **2014 onward**, plus selected AFLW, VFL/VFLW, SANFL, WAFL, QAFL, NTFL and Tasmanian examples where they materially expand the design vocabulary.

For each researched design, record:
- club and season,
- artist/designer name,
- artist's Nation/community where publicly stated,
- whether a current/former player or family member was involved,
- the story/theme explicitly published by the club/AFL,
- base club colours retained or changed,
- major layout structure,
- reusable geometric/presentation ideas,
- which elements are culturally specific and **must not be copied**,
- source URL / provenance.

Start from official AFL/club sources wherever possible. The AFL's Sir Doug Nicholls Round guernsey galleries, annual all-club roundups and club reveal articles are preferred over fan recreations or merchandise photos without story/provenance.

### Cultural and IP guardrails
Treat the research primarily as **visual-style and design-language study**, not as a source of specific artwork or stories to reproduce.

Claude should learn from the broad visual vocabulary across many Indigenous guernseys — composition, flow, layering, connected forms, asymmetry, curved and concentric geometry, integration with club colours, and the way traditional football structures such as sashes, hoops, panels and yokes are reinterpreted — then create **new original designs** from that learned design language.

- Do not copy, trace or closely reconstruct any real artist's guernsey artwork.
- Do not lift a specific club design and merely recolour or rearrange it.
- Do not reuse Dreaming stories, clan-specific symbols, sacred/culturally restricted imagery or an artist's distinctive composition.
- Do not invent cultural narratives, Nations, symbolism or "meaning" for the game's fictional designs. **The designs do not need lore attached to them.**
- Preserve artist/source attribution in the research record so Claude knows what it studied, even though the shipped design should be original.
- If the project ever ships an exact real-world Sir Doug Nicholls guernsey, obtain the necessary club/artist rights first.
- The default game should use **original, club-specific fictional Indigenous-round guernseys** informed by the broad art style and football-design traditions found in the research, without pretending those designs represent a real community, artist or story.
- Prefer a future collaboration/commission with Aboriginal and Torres Strait Islander artists for a final commercial art pass if practical, but this is not required for prototyping the original in-game style.

### Per-club design depth
Target **5–10 unique Indigenous-round guernseys per club** over time.

For the existing AFL clubs:
- each club gets a rotating library rather than one permanent special strip;
- designs should still read immediately as that club through colour hierarchy, silhouette and recurring club identity;
- avoid simply recolouring the normal home guernsey with dots;
- vary composition meaningfully: pathway/connection structures, meeting-place geometry, river/land-flow layouts, animal/totem-inspired *abstract* structure only where a fictional/original treatment is culturally safe, layered bands, mapped-country-style flow, concentric community structures, side panels, yokes, sashes, hoops/stripes transformed into connected organic systems, etc.;
- no design should claim a real cultural story unless it is licensed from the people who own that story.

Tasmania and optional Canberra should also receive their own researched/original pools once they enter the competition.

For a user-created club:
- provide a small pool of **original fictional Indigenous-round templates** using the same culturally safe design system;
- the user may choose colours and broad composition but should not be asked to invent an Aboriginal story, Nation or sacred symbolism;
- the custom-club design must not borrow exact artwork from an existing real club.

### Seasonal rotation
- Assign each club one Indigenous-round guernsey from its library for that season.
- Rotate with enough memory that the same design does not appear every year.
- Historical/recent designs may be weighted toward club identity, but no one pattern should dominate indefinitely.
- Store the selected season design in the save so reloading cannot change it.
- Long careers should cycle through the library naturally; once exhausted, reuse after a sensible gap unless new designs have been added.

### Sir Doug Nicholls Round scheduling
Implement a designated **Sir Doug Nicholls Round window** in the fixture, modelled on the modern AFL's two-round celebration.

Core rule:
- each club wears its Indigenous-round guernsey for its designated Sir Doug Nicholls match;
- if a club has a **bye in the designated round**, that club wears its special guernsey in **its following match/round instead**;
- in that catch-up match, the opponent **does not** automatically wear its Indigenous-round guernsey unless that opponent also missed its own designated match because of a bye;
- therefore the guernsey state is tracked **per club**, not as a global "everyone this round" renderer switch;
- a club wears the season's special guernsey exactly once for its designated/catch-up appearance unless a future explicit rule says otherwise.

With odd-club competitions (19 or 21 clubs), the bye/catch-up logic is mandatory and must remain deterministic.

### Match and vignette presentation
For the club's actual Sir Doug Nicholls appearance:
- all match vignettes, pre-match figures, close-ups and other player-facing kit renderers must use that club's selected Indigenous-round guernsey;
- the normal home/away/clash readability rules still apply;
- if both clubs are wearing special guernseys, resolve contrast using dedicated Indigenous home/clash variants where available or a restrained alternate treatment;
- after that club's Sir Doug Nicholls appearance, immediately return to normal season guernseys for later matches.

The vignette system must read the **actual match kit assignment**, not independently guess from the calendar. This prevents a player from appearing in the special strip in a normal match or vice versa.

### Round presentation
Keep presentation meaningful but not exploitative:
- clearly label Sir Doug Nicholls Round in fixture/match presentation;
- provide concise, factual educational context about Sir Doug Nicholls and the round;
- where a design is an original fictional game design, say so rather than attaching a fabricated artist/story;
- where licensed real artwork is ever added, display the artist/story attribution prominently and accurately;
- avoid gamified rewards, stat buffs or arbitrary morale bonuses for the round.

Optional later presentation may include special ball/umpire visual treatment if it can be implemented from licensed/original artwork and does not distract from the core guernsey work.

### Data / implementation shape
Create a data-driven guernsey catalogue rather than hard-coded season checks.

Suggested fields:
- design id,
- club code,
- variant type (home / clash / alternate),
- colour mapping,
- procedural pattern primitives / texture reference,
- source/inspiration metadata,
- real-vs-original flag,
- artist attribution where applicable,
- season eligibility,
- copyright/licensing state,
- cultural-review state.

The normal match-kit resolver should receive the seasonal Sir Doug Nicholls assignment and choose the correct visual variant.

### Acceptance
- every active club has at least five distinct Indigenous-round designs available before the feature is marked complete; target 5–10 each,
- every design has provenance/research notes and no unlicensed artwork is shipped accidentally,
- the same club remains visually recognisable across its different special guernseys,
- the special kit is visible in the actual match/vignette presentation and nowhere else,
- bye clubs correctly defer their special kit to their next match without forcing the opponent into one,
- 19-, 20- and 21-club fixtures all handle the rule,
- save/reload preserves the year's design choice and whether the club has already worn it,
- long careers rotate designs instead of showing the same one annually.

### Validation
Test:
- normal two-club Sir Doug Nicholls match,
- one club coming off a bye,
- both clubs coming off byes,
- a club with no bye,
- 19/20/21-club seasons,
- home/away/clash contrast,
- watched match and simulated match,
- every vignette/figure renderer,
- save before round → reload → play,
- save after one club has worn its strip but before another bye club's catch-up,
- multiple seasons of rotation with no accidental annual reroll.

Phone-review at narrow Android widths and visually inspect a representative sample from every club before marking complete.

---

