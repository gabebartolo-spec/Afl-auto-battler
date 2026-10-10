## ARD-M7-009 — Expansion clubs, Canberra toggle & Club Forge
**Status:** `PARTIAL` — groundwork merged: the full player look (#305) and the location library, `data/forge_locations.json` with 53 researched places and a `tools/validate_data.py` check (#304). The pattern and colour research is merged (#343, #351): from each heritage club's Wikipedia infobox home kit, plus South Adelaide's own site (#351). 33 of 53 places have a pattern tag and 46 of 53 have colour tags; nothing is guessed. Still empty: 20 patterns (custom kit images, or the page is the town: werribee, shepparton, warrnambool, newcastle, wollongong, albury, maroochydore, morningside, norwood, sturt, woodville-west-torrens, claremont, subiaco, bunbury, ainslie, eastlake, tuggeranong, palmerston, weston-creek, alice-springs) and 7 colours (shepparton, southport, morningside, central-district, burnie, weston-creek, alice-springs). **Create a club, engine (merged in #340):** `ClubForge` turns a spec (name, nickname, 2-4 letter abbreviation, a library place and one of its grounds, three colours, a guernsey design and which colour goes where, entry season) into a club, refusing taken names and codes, unknown places and patterns that can't be told apart; `GameState.create_club` adds the one created club before the League Draft; `GameDB.club_order` replaces `CLUB_ORDER` wherever every club is walked; the club is saved with the career and comes back on load. Director decisions (2026-10-06): a created club **enters with the career** and drafts its list in the League Draft like every club (no separate concession package); a 21-club season is **24 rounds, 22 games and two byes a club**. The screen is built (#360, approved by the director in their own words); #309 (Create a player), which it is stacked on, is merged. The fair fixture for 18 to 21 clubs is merged (#361): every club plays the same number of games, home games are within one of half, and byes follow the season seed (a 21-club season is 24 rounds, 22 games and two byes a club); the board goals and expectations follow the club count (#359). _(2026-10-06)_  
**Implementation reconciliation (2026-10-07):** #493/#498 finish the director-selected club paint flow; #490 supplies new-club staff and repairs bare old saves. Club creation, fair fixtures and board scaling are already implemented. **Remaining:** the explicit missing researched library entries, custom-player appearance/preview follow-ups, and any expansion lifecycle/concession/dependency acceptance not evidenced by those PRs. Keep PARTIAL; do not rebuild merged creation/fixture/staff foundations.

**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

### Intent
Make expansion a major long-career option rather than a background database event. Tasmania remains the grounded 19th club, Canberra is an optional 20th club, and the player may create one additional bespoke club that joins the competition as a 21st side.

### New Career expansion setup
Keep the ordinary New Career flow concise.

- **Tasmania:** scheduled to enter in 2028.
- **Canberra:** optional career toggle, **off by default**, scheduled to enter in 2030 when enabled.
- Persist the Canberra choice at career creation because draft capital, list building, staff, fixtures and future-pick ownership need to prepare before entry.
- Do not allow a mid-save Canberra toggle after expansion preparation has begun.
- A created-club career adds the custom club as a new competition member rather than replacing an existing club.

### Existing-player chronology before expansion
Tasmania and Canberra enter years after the 2027 career baseline. By the time either club enters, **every existing AFL player must have reached that season through the normal career simulation**.

- Do not load a frozen 2027 roster into a 2028/2030 expansion state and then merely add years to displayed ages.
- Age, development, decline, injuries, contracts, trades, free agency, awards, club movement and career history must all reflect the seasons actually simulated before expansion.
- Retirements, delistings, list turnover and replacement-generation need a robust lifecycle that preserves believable league population and career provenance. The exact retirement/delisting implementation is an engineering/design task for Claude when this item is actioned; do not fake continuity with silent respawns or retroactive history.
- Expansion list building must draw from the league state that genuinely exists at the expansion date.
- Long-save validation must prove that players present in 2028/2030 have coherent ages, histories and club stints, and that retired/delisted players are not resurrected accidentally.

### Real-expansion draft model
Use the AFL's confirmed Tasmania list-establishment package as the authenticity baseline rather than inventing a weak generic expansion draft.

For Tasmania:
- 2027 National Draft: picks **1, 3, 5, 7, 9, 11 and 13**, plus the first selection of each subsequent round.
- Picks **5, 7, 11 and 13** are trade-required/rollable according to the real concession concept.
- 2028: concession picks **5 and 9** plus the first selection of each subsequent round and the natural hand; pick 5 is trade-required/rollable.
- 2029: concession picks **5 and 9** plus the natural hand; pick 5 is trade-required.
- Where practical, later expansion work may also model the real package's mature-player access, rookie priorities and other list-building concessions, but first-round capital and real trade ownership are the minimum accepted foundation.

For Canberra:
- There is no confirmed real AFL Canberra expansion package to reproduce, so use the **same design philosophy as Tasmania**: heavy premium draft capital beginning before entry, spread across multiple drafts, with some premium selections required to be traded so the club must mix elite youth with established talent.
- Tune the exact Canberra pick schedule against the game's entry year, draft order and competitive balance rather than pretending a fictional package is an AFL rule.
- AI-controlled Canberra receives exactly the same concessions as a user-controlled Canberra.

Expansion picks must be real persistent tradable assets in the normal trade/draft system. Do not fake concessions as hidden list-strength boosts or spawn a strong list without provenance.

### Main-menu creation destination — Club Forge
Add a bespoke main-menu destination named **Club Forge** as the current working title.

Club Forge is the home for:
1. **Create a club**
2. **Create a player**

It should feel purpose-built rather than like a debug/settings form, while remaining mobile-first and restrained.

### Create a club
Allow one custom club per career in V1.

**Director decision (2026-10-06):** a created club enters with the career and drafts its list in the League Draft like every club. There is no separate concession package.

Player-facing customisation should include, at minimum:
- club name,
- short name / abbreviation,
- **home location chosen from a researched Australian football location library**,
- primary / secondary / accent colours,
- guernsey design using the existing procedural guernsey system,
- shorts / socks where supported,
- simple badge/marker identity built from the same visual language as existing club markers rather than imported trademarked logos.

Do not turn V1 into a full vector-logo editor or stadium builder.

#### Location library — real football geography first
The location picker should not be a generic list of capital cities. Offer major suburbs, regional centres and football towns that do not already have an AFL club representing that exact place. Prefer locations with an established state-league / second-tier football identity when one exists.

Minimum curated coverage should include candidates such as:

- **Victoria:** Port Melbourne, Williamstown, Werribee, Frankston, Sandringham, Coburg and other major VFL/VFA football centres not already represented by an AFL club.
- **New South Wales:** Newcastle, Wollongong/Illawarra, North Shore and other major Sydney/NSW football centres without an AFL club of their own.
- **Queensland:** Southport, Broadbeach, Sunshine Coast/Maroochydore, Cairns and other established QAFL/Queensland football centres outside the existing Brisbane Lions and Gold Coast Suns identities.
- **South Australia:** Norwood, Glenelg, Sturt/Unley, Central District/Elizabeth, South Adelaide/Noarlunga and other established SANFL centres distinct from Adelaide and Port Adelaide.
- **Western Australia:** Peel/Mandurah, Claremont, Subiaco, East Perth, West Perth/Joondalup, Swan Districts/Bassendean and other WAFL centres distinct from Fremantle and West Coast.
- **Tasmania:** Launceston, North Hobart/Hobart-region heritage centres, Devonport and Burnie where appropriate, while respecting the scheduled statewide Tasmania AFL club.
- **ACT:** if the optional Canberra AFL club is enabled, avoid presenting a second generic 'Canberra' identity; use genuine local football districts such as Ainslie, Belconnen, Gungahlin, Tuggeranong, Weston Creek or Eastlake/Kingston where appropriate.
- **Northern Territory:** **Darwin** and **Alice Springs** are mandatory choices. Additional NT football centres may be added where venue/list support is strong.

Examples above are a seed list, not a hard-coded final catalogue. Claude should build the library from researched competition/club data and keep it data-driven so more places can be added without rewriting the creator UI.

Where an existing lower-league club provides useful authenticity (for example **Southport, Norwood, Peel, Williamstown, Werribee, Port Melbourne, Claremont**), use its location, football history, colours/pattern vocabulary and home venue as research input. **Do not ship protected club logos, exact trademarks or unlicensed branded assets merely because the real club informed the preset.** Existing club names/nicknames should only be shipped verbatim if the project is comfortable with the licensing/trademark position; otherwise use the place and football tradition as inspiration while keeping the user's club name editable.

#### Home grounds — researched venue mapping
Each location preset should propose a real Australian-rules football ground wherever a credible venue exists.

Store a stable/common venue identity separately from a changeable sponsorship name where possible, so saves do not become wrong every time naming rights change.

Research anchors already confirmed for implementation include:
- **Norwood:** Norwood Oval / current Coopers Stadium.
- **Peel/Mandurah:** Rushton Park / current Lane Group Stadium.
- **Southport:** Fankhauser Reserve.
- **Port Melbourne:** North Port Oval / current ETU Stadium.
- **Williamstown:** Point Gellibrand Oval / current DSV Stadium.
- **Werribee:** Chirnside Park / current Melbourne Avalon Airport Oval.
- **Alice Springs:** Traeger Park (also presented as TIO Traeger Park in AFLNT material).
- **Darwin:** TIO Stadium as the major venue, with AFLNT also using Gardens Oval, Nightcliff Oval and other genuine NTFL grounds.
- **Canberra districts:** use researched local grounds such as Alan Ray Oval (Ainslie), Aranda Oval (Belconnen), Kingston Oval (Eastlake), Amaroo Oval (Gungahlin), Isabella Oval (Tuggeranong) and Stirling Oval (Weston Creek) where the selected district maps naturally.

Do not invent a stadium where a real football oval exists. If a region has several plausible grounds, offer a small venue choice rather than pretending one is canonical.

#### Guernsey creator — state-league depth
Expand the procedural guernsey system using researched VFL/VFA, SANFL, WAFL, QAFL, NTFL and Tasmanian football design language rather than only AFL templates.

The point is **more construction vocabulary**, not copying protected artwork. Research traditional/home strips and encode reusable primitives such as:
- plain body + trim,
- vertical stripes of configurable count/width,
- hoops,
- sash / reverse sash,
- yoke,
- chest band,
- V / chevron and stacked chevrons,
- side panels,
- shoulder panels,
- central panel / contrasting back,
- split / half-and-half body,
- monogram/letter-zone placeholder where legally safe,
- contrasting cuffs/collar,
- sock hoops/bands,
- independent shorts colour,
- optional heritage-style narrow stripes or broad bars.

Use real second-tier clubs as pattern references. Confirmed research examples include:
- **Norwood:** traditional navy guernsey with red trim and red socks; the club itself documents those colours.
- **Peel Thunder:** teal and navy are the club's documented colours.
- **Williamstown:** royal blue and gold.
- **Werribee:** black and gold.
- **Port Melbourne:** long-standing red/blue identity; North Port Oval is its home.
- **Claremont:** navy and old gold.
- SANFL/VFL/WAFL clubs collectively provide strong references for stripes, hoops, sashes, yokes, bands, chevrons and contrasting trim; Claude should complete a sourced pattern audit before implementing new primitives.

First Nations and commemorative guernseys are useful **research for how clubs layer story and geometry**, but their artwork must not be copied into a generic creator. Indigenous artwork is culturally specific, artist-owned work: do not turn it into a selectable decorative pattern unless an original/licensed design is created for the game.

#### Data model
Keep the creator data-driven:
- location id,
- display place,
- state/territory,
- optional football-region label,
- canonical ground name,
- current/sponsor ground alias where useful,
- latitude/longitude only if later venue/weather systems need them,
- researched colour/pattern inspiration tags,
- optional lower-league heritage reference kept as internal/source metadata rather than necessarily player-facing branding.

This library should be reusable by create-a-club, venue presentation, weather/ground dimensions and future generated-club features.

The created club:
- is an **additional competition member**, never a reskin/replacement of an existing club;
- participates in the same salary cap, list size, contracts, draft, trades, free agency, coaching, injuries, suspensions, development and AI rules;
- gets an expansion-list establishment package comparable in opportunity to the other expansion clubs, with balance measured rather than guaranteed dominance;
- stores its identity and colours in save data so every ladder, fixture, match, report, guernsey, history and long-career record uses the created identity consistently;
- remains valid after reload and across decades of history.

### Create a player
Move/route ARD-M7-008 through Club Forge so character creation and club creation share one bespoke creative destination.

The player creator should expose identity/aesthetic and football-profile choices without exposing exact OVR/POT. Its hidden one-time POT roll, usable-role-player floor and rare S-tier outcome remain owned by ARD-M7-008.

Appearance customisation should include:
- **Hair style** from a much larger library,
- **Bald** as a proper explicit hair option rather than a missing-texture/default state,
- **Hair colour**,
- **Facial hair** from a dedicated beard/moustache library,
- **Facial-hair colour**, independently selectable,
- **Skin tone**,
- **Boots** with a compact set of silhouettes and colour treatments,
- **Tall socks / Short socks**,
- **Headband On / Off**,
- **Bandaging by location: head, knee, shoulder, elbow and broken-nose tape**,
- **Tattoos by selectable original design and placement**, with optional density variation and None/remove controls.

Persist these on the player and use them consistently anywhere visible: creator preview, match figures, vignettes and future portrait/full-body presentation.

These are cosmetic only. They should also be available to generated-player appearance variation where practical so the league does not look uniform. Hair and facial-hair colour may differ occasionally for generated players within a believable natural range.

### Hair / facial-hair library
Expand beyond a token set of cuts. The target should include enough silhouettes that players are recognisable at a glance even at vignette scale.

Hair should cover a useful range such as:
- **“Bailey Fritsch” haircut** — add a Bailey Fritsch–inspired option to the shared hairstyle library for player creation/customisation and generated-player variety. Use visual references to capture the recognisable silhouette in the existing art style; persist it like other hairstyles and use it consistently in previews and vignettes. Cosmetic only.
- bald / shaved,
- very short buzz,
- short crop,
- crew cut,
- side part,
- textured short,
- messy medium,
- longer swept-back,
- mullet variants,
- curly/coily short,
- curly/coily medium,
- **dreadlocks (locs)** — add a distinct selectable hairstyle to the shared library for player creation/customisation and generated-player variety. Persist the choice and show it consistently in previews and vignettes; cosmetic only, with readable silhouettes and headband compatibility where supported.
- afro-style volume where supported by the art pipeline,
- long hair / tied-back variants where supported.

Facial hair should be independently selectable where the face/figure resolution supports it:
- clean shaven,
- light stubble,
- heavy stubble,
- moustache,
- short beard,
- full beard,
- goatee / chin beard,
- beard + moustache combinations.

Do not tie beard availability to hairstyle. Hair colour and facial-hair colour should usually harmonise but do not need to be identical in every generated case.

### Appearance variation guardrails
- Headbands should sit naturally with the hairstyle/figure rather than float as an overlay.
- Hair/headband combinations need compatibility rules so bald/shaved and bulky styles do not clip.
- Beards/moustaches must not obscure player numbers, guernsey details or facial readability in close-up vignettes.
- Bandages should use believable football placements such as shoulder/upper arm, wrist/forearm, thigh/knee or lower leg; avoid covering every limb at once unless a deliberately rare heavy preset is selected.
- Tattoos should be **original generic designs**. Do not copy a real player's identifiable tattoo layout, Indigenous artwork, gang symbols, extremist imagery, copyrighted characters/logos or other protected/sensitive designs.
- Use multiple tattoo placements/pattern families so "tattoos on" does not make every player look identical.
- **Director-requested tattoo motifs (2026-10-06):** rose, snake, barbed wire, bird, **666**, love heart, **Southern Cross stars**, and **Asian-script lettering**. Include these in the selectable/shared tattoo library alongside similar original designs, with placement and density variations. For lettering, use real characters with checked meanings rather than invented glyphs; the choice is cosmetic and independent of player ethnicity or football traits. Reuse the existing tattoo persistence and preview/vignette rendering.
- Appearance traits should remain visually legible at vignette scale without becoming noisy or overpowering the guernsey.


### Premiership-year tattoos — director addition (2026-10-06)
**Status:** TODO — cosmetic implementation for Claude.
- **Only some players get one.** An eligible premiership player may adopt a tattoo of the winning year on their bicep; other players remain without one. This is an occasional cosmetic detail, not a mandatory tattoo for every premiership player or a management chore.
- **Once adopted, continue automatically:** every subsequent AFL premiership the player personally wins adds that year to the bicep/sleeve. Do not reroll adoption for later flags.
- Use the existing authoritative player-premiership honours after the Grand Final result is final; do not treat every member of the winning club list as a premiership player. Preserve actual imported honours, but do not infer a real person's pre-existing tattoo from their honours alone.
- Persist adoption and a unique chronological year list on the player. Save/reload must preserve the tattoo rather than erase it or reroll the decision; transfers retain earlier years and later flags at another club extend the same sleeve. A new career uses its own history.
- Use a separate cosmetic decision/seed, original year-digit artwork and the shared appearance/rendering pipeline. Keep added years legible in close previews/vignettes, with no gameplay effects or football-RNG changes.
- Validate adoption and non-adoption, subsequent wins, deduplication when a result is processed twice, transfers, reload and several years on one arm.
**Research handoff:** Codex researched 13 named player examples, placements, branded-art exclusions and the distinction between source evidence and usable original art in [AFL_TATTOO_REFERENCES.md](research/AFL_TATTOO_REFERENCES.md). Claude should use that handoff to integrate the requested motifs rather than repeat the research.

### Dominant foot, number and nickname
**Dominant foot** is the one creator choice here that can have modest football meaning.

- Left/right foot should influence preferred kicking side, body orientation and appropriate vignette/animation facing where the presentation supports it.
- It may slightly influence which side a player naturally opens the ground from, but must **not** become a hidden global accuracy bonus or make one foot objectively better.
- Weak-foot use should remain possible; do not hard-lock players from ordinary AFL actions.
- AI/generated players should also have a dominant foot so the system is not a user-only gimmick.

**Preferred guernsey number**:
- allow the user to nominate a number for the custom player,
- if unavailable at the club that drafts/signs him, resolve the conflict transparently using the club's normal numbering rules,
- preserve the preference so the player can receive it later if it becomes available where practical,
- never duplicate active squad numbers.

**Nickname / commentary short name**:
- optional field for a custom player,
- useful for long surnames or personal flavour,
- may appear in commentary/vignettes where natural,
- must not replace the legal/display surname in records, awards, history or contracts,
- generated players do not require nicknames by default.



### 21-club fixture support
A created club may take the competition to **21 clubs**.

**Director decision (2026-10-06):** a 21-club season is 24 rounds, 22 games and two byes a club. (For reference, the existing fixture: 23 games at 18 and 20 clubs, 22 at 19.)

- The fixture generator must support odd club counts cleanly.
- Every club must receive an equal number of home-and-away matches.
- Use a fair rotating bye structure; do not give the custom/user club a scheduling advantage.
- Expanding the calendar beyond the current fixture length is allowed if required to keep equal games, sensible opponent coverage and clean bye rotation.
- Revisit finals qualification and wildcard presentation only if the larger league makes the existing structure materially unfair; do not automatically add more finals teams just because the league grew.
- Validate season rollover, draft order, ladder percentages/points, awards, contracts, fatigue and long-save performance with 19, 20 and 21 clubs.

### UX guardrails
- Main menu remains clean: Club Forge is one deliberate destination, not several creator buttons.
- New Career should summarise expansion choices without number-vomit.
- Creation must work comfortably in narrow portrait layouts.
- Colour/guernsey controls should be tap-friendly; avoid dropdown-heavy forms.
- Show enough preview to understand the club/player being created without telling the user the optimal football build.

### Tests
- Canberra off: career remains valid with Tasmania and no ghost Canberra data.
- Canberra on: expansion preparation, entry, draft assets and fixtures survive save/reload.
- Players reaching 2028/2030 have naturally evolved ages, histories and list states rather than frozen-start data with adjusted labels.
- Retirement/delisting/list-turnover handling does not resurrect players or corrupt career history.
- Created club is unique, persists through reload and uses its identity everywhere.
- 19-, 20- and 21-club fixtures give every club equal games and fair byes.
- Custom club obeys the same cap/list/contract/trade/draft/coaching rules as AI clubs.
- Long-run simulation reaches multiple post-expansion seasons without fixture, draft-order, history or save corruption.

---

