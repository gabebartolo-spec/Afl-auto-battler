# AFL flavour and Australian culture research

Research date: 5 October 2026. Project: **Aussie Rules Dynasties**.

**Direction:** give the club, players and football year a recognisable life through presentation alone. Every proposal in this report has **zero gameplay effects**. Zero microtransactions remains the project rule.

The strongest opportunity is a few specific, affectionate details that belong to *this club and this save*: a milestone on the banner, a familiar nickname beside a full name, a room carrying its actual history, a crowd allowed to be heard, and a farewell that remembers where someone began. More text, more jokes and more interruptions are not the goal.

This is a focused research supplement to [the genre report](../GENRE_ENJOYMENT_RESEARCH.md), [visual design research](https://github.com/gabebartolo-spec/Afl-auto-battler/blob/b796b2181ccfb2f1eaef677375b0b0fd3572c60f/docs/research/AFL_VISUAL_DESIGN_RESEARCH.md) and [long-career research](https://github.com/gabebartolo-spec/Afl-auto-battler/blob/b796b2181ccfb2f1eaef677375b0b0fd3572c60f/docs/research/AFL_LONG_CAREER_STORY_RESEARCH.md). The latter two are in the separate intensive-research PR [#232](https://github.com/gabebartolo-spec/Afl-auto-battler/pull/232) at this checkpoint. **Director review completed 6 October 2026: FL-001–FL-008 are all included in Claude's queue.** The [canonical roadmap §9.3](../roadmap/21-9-3-approved-flavour-and-culture-work-director-decisions.md#93-approved-flavour-and-culture-work--director-decisions-2026-10-06) records the decisions, dependencies and acceptance criteria. Existing unrelated approvals and exclusions remain intact.

## 1. Scope and evidence

The [source ledger](AFL_FLAVOUR_SOURCE_LEDGER.md) records 23 external sources, their access depth, evidence type and limits. These include institutional histories, a club consultation with 120 women, club and player accounts, cultural criticism, a scholarly abstract, and supporter discussions. Sources accessed only through indexed text are explicitly labelled. A failed page fetch is not counted as a full reading.

This is desk research, not fieldwork, hands-on testing of a new build, a representative supporter survey or proof that an adaptation increases enjoyment. Museum histories establish context; club campaigns select positive examples; forum participants self-select. Our game adaptations and prototype budgets are hypotheses.

A purely flavourful addition may **reflect** an existing result, weather state, milestone, rivalry or career history. It must not create or modify football ability, fatigue, injuries, development, morale, relationships, contracts, finances, scouting knowledge, AI behaviour, fixture rules, disciplinary decisions or match outcomes. It must not conceal useful information or consume decision time.

Existing media choices can have ClubLife effects. This report does not add decorative choices to that effects path. It also does not convert the director-approved Rest/Keep trade-off into flavour.

## 2. Implementation reality: enrich what exists

Repository checkpoint: main at [b07a785](https://github.com/gabebartolo-spec/Afl-auto-battler/commit/b07a78525986c58921b9c51efb25477b6686087d). Findings below are from a static read of selected presentation files and the current roadmap, not an Android playtest.

| Existing foundation | What this pass can use | Boundary |
|---|---|---|
| PreMatchVignette already warms up, gathers players and runs through a banner; its banner text is the club name | A genuinely relevant banner message and a little material detail | Do not rebuild the introduction or extend the unavoidable loading wait |
| BroadcastVignette already selects scenes from authoritative events and has finish controls | Better atmosphere around existing scenes | No fictional highlights or altered targets; necessary new flavour scenes are authorised under FL-007 |
| SeasonAwards already reveals actual winners and allows finishing/skipping to review | Warmer recognition of a known winner | Preserve stored results and the existing viewed flag |
| M7-001 rivalries and M7-002 marquee identity are DONE | Present existing context accurately | No new rivalry engine, fixture changes or rivalry bonuses |
| M7-003 milestones are PARTIAL; M7-005 history and awards have substantial merged foundations | Show existing facts in evocative ways | No new awards calculation, bookmark archive or duplicate biography system |
| M8-009 plausible generated names is DONE | Optional identity details alongside those names | Do not reopen the name-generator replacement |
| Director requires complete migration of old vignette figures to the shared pre-rendered 2.5D style | Use that established art direction | Never retain legacy silhouettes; FL-007 authorises necessary new shared-style flavour scenes |
| PR #206 contains soundtrack work | Coordinate any atmosphere/audio proposal with it | Do not introduce a second sound system or assume it is merged |

The season story recap, awards improvements and former-player coaching continuity are already roadmap work. This pass proposes cultural treatment and smaller content details within those surfaces, not another framework.

## 3. Cultural findings and adaptations

### 3.1 Belonging is made by people and repetition

The National Museum describes early clubs forming around neighbourhoods, workplaces and other local institutions, including their role in communities of migrants. This supplies historical context, not a claim that modern clubs all retain the same social composition. [F02: National Museum](https://www.nma.gov.au/defining-moments/resources/australian-rules-football).

Carlton's 2016 consultation records friendship, taking grandchildren, familiar supporters, cross-club banter and continuity alongside complaints about exclusion and commercialisation. It involved 120 women at one invited club event; it is not a national probability sample. [F03: consultation report](https://s.afl.com.au/staticfile/AFL%20Tenant/Carlton/Documents/Carlton%20Listens%20to%20Women%20-%202016%20Report.pdf).

**Adaptation:** let the club feel inhabited. In existing non-interactive scenes, use a returning supporter in the same scarf, a volunteer taping a banner, or a noticeboard that changes with actual seasons. A very small authored cast of fictional background people could provide continuity without schedules, needs, conversation trees or management responsibilities.

Give those people lives of appropriate length. A supporter cannot remain a child for fifty simulated years. If persistent background people are selected, record their cosmetic identity and lifecycle; otherwise use anonymous environmental figures without biographical claims. The club can persist through objects and rituals even when individual people do not.

**Smallest useful change:** two recurring environmental details in an existing pre-match scene, with no text panel. Test whether players notice and enjoy the familiarity after several seasons.

### 3.2 Handmade banners carry personal recognition

The GIANTS' banner-making account describes an organised volunteer craft, changing materials, milestone imagery and the reuse of a Heath Shaw banner picture in the rooms. It also explains practical constraints. This directly challenges the idea that every club's banner is always crepe paper. [F04: banner makers' account](https://www.gwsgiants.com.au/news/690157/2026-grand-final-packages).

**Adaptation:** enrich the existing club-name banner with one supported fact: a milestone, a named debut where a genuine debut is known, or a major fixture already identified by the game. Use restrained tape joins and slight material irregularity. Typography must remain readable; deliberate misspellings and torn names are poor default jokes.

A milestone banner should honour the **selected player actually taking the field**. Career games and games for this club are different. Imported history may not support a first-ever claim. If the facts are missing, keep the existing club name.

**Smallest useful change:** one milestone banner treatment using the current scene. No banner editor, crafting economy, supporter task or additional loading phase.

### 3.3 Australian voice is more than a slang list

The Australian National Dictionary Centre describes sporting expressions as living language with varied origins and changing usage. Its examples support selective football vocabulary, rather than stuffing every sentence with Australianisms. [F01: Mark Gwynn, ANU](https://reporter.anu.edu.au/all-stories/word-playing-the-field).

Rolfe's scholarly abstract questions an isolated, uniquely national humour by examining cultural exchange. This is a useful corrective to a single compulsory “Australian personality”; the full paper was inaccessible in this pass. [F14: journal abstract](https://europeanjournalofhumour.org/ejhr/article/view/689).

**Adaptation:** plain football language for instructions; occasional dry, affectionate observation for optional atmosphere. Distinguish the voices of a restrained match report, a handmade banner and a fictional club notice. Do not make every speaker the same loud larrikin.

Good targets for humour are small inconveniences, ceremonial fuss and collective overconfidence. A close escape can earn an understated headline; an injury, sacking or culturally significant ceremony should not automatically trigger a joke. Avoid obscure slang in buttons and diagnoses: the player must understand what happened.

The [original writing samples](AFL_FLAVOUR_WRITING_SAMPLES.md) demonstrate tone, trigger requirements and plain alternatives. They are proposed copy, not quotations from real people.

### 3.4 Warmth works better when people keep their dignity

SBS's analysis of *The Castle* describes affectionate deadpan treatment of ordinary people, while also questioning its class, gender and racial assumptions. It is criticism, not evidence of a game-design effect. [F13: Dave Crewe's analysis](https://www.sbs.com.au/whats-on/article/the-castle-cheat-sheet/in7873wk3).

Bluey's official description places imaginative stories in ordinary family activity. That is a creative reference for scale and warmth, not a template for football dialogue or permission to borrow characters and catchphrases. [F12: official description](https://www.bluey.tv/media-hub/about-bluey/).

**Adaptation:** make small successes sincere. A first senior goal, a long-serving reserve finally appearing, or a player returning as an existing staff member can matter without pretending to be a premiership. Funny detail should make the person more recognisable, rather than dismiss their achievement.

Do not attach fictional domestic behaviour, drinking habits, embarrassing incidents or invented quotes to real players. Generated characters can have explicitly fictional cosmetic interests. Their interests must not indicate hidden ability or influence recruitment decisions.

### 3.5 Nicknames are remembered relationships, not extra ratings

Adelaide's account shows nicknames arising from name play, recruitment circumstances and ordinary incidents, with some attempts not sticking. An AFLPA teammate tribute explains a nickname that persisted from youth into a milestone career. These are specific published accounts, not universal rules. [F08: Adelaide](https://www.afc.com.au/news/72721/new-player-nicknames), [F09: AFLPA](https://www.aflplayers.com.au/news-feed/stories/pup-as-loyal-as-they-come).

**Adaptation:** an optional stable nickname for fictional generated players could provide a memorable handle beside the full name. It must survive transfers and retirement and never replace search identity. Let the user rename or remove it without spending currency or affecting relationships.

Start with name-derived, human-reviewed possibilities. Do not infer ethnicity, temperament, humour or off-field history from a surname. Avoid body-based ridicule and labels that look like ability descriptions. Do not label every player: excessive procedural nicknames become another kind of noise.

**Smallest useful change:** a handful of optional fictional profile nicknames, with name search and persistence checks. Real-player nickname imports require a source; fictive-name mode must not accidentally reveal real identity.

### 3.6 Place should change the background, not the football

The AFL's photography selections contain very different community settings and explicitly discuss how clear backgrounds and light make people and emotion readable. These are editorial choices; the photographs do not establish universal venue traits. [F20: Footy Focus](https://www.afl.com.au/news/1435953/revealed-footy-focus-2025-winner-captures-magical-red-centre-moment).

AFLNT's 2022–23 report records remote competitions, including a Tiwi competition changing season. That cautions against a blanket assumption that all northern football occurs in the wet season. [F19: AFLNT report, Remote Projects](https://play.afl/sites/default/files/2024-09/AFLNT%20Annual%20Report%202022-2023.pdf).

**Adaptation:** recognise places with a few sourced features: the stand outline, roof, boundary fence, nearby buildings or vegetation, and the light appropriate to the existing match. A metropolitan stadium, compact suburban ground and regional venue can share the same renderer. Use a matching real venue reference before assigning features; cars around an oval belong to some community settings, not every AFL venue.

Ground dress must never alter dimensions, wind, surface difficulty, crowd advantage or travel fatigue. Decorative rain must not contradict actual weather. If the game lacks a reliable weather or time field, use a neutral environment rather than inventing one that looks mechanically informative.

**Smallest useful change:** one venue background, one uncluttered establishing composition, one shared asset set. No explorable town, stadium development or new local-footy career mode.

### 3.7 Let the crowd provide atmosphere

The GWS song's composer discussed shoutable participation and longevity. Hawthorn's reported extra victory ritual demonstrates how a particular shared episode can become a repeated custom. The NFSA documents an unofficial football anthem's cultural history. None proves music improves this game's retention. [F05: GWS song](https://www.afl.com.au/news/130138/yellow-and-black-or-theres-a-big-big-sound-why-the-giants-song-is-a-banger), [F07: Hawthorn ritual](https://www.afl.com.au/news/88557/hawks-riding-the-horses-in-new-post-match-ritual), [F06: NFSA](https://www.nfsa.gov.au/collection/item/there-cazaly-two-man-band-0).

The sustained supporter discussion “I do not need to be entertained ALL THE TIME” complains that amplified music and announcements obscure the crowd and conversations. Other comments enjoy particular participatory songs. Treat this as disagreement about experience, not a referendum or representative percentage. [F21: supporter discussion](https://www.reddit.com/r/AFL/comments/1e23tgj/i_do_not_need_to_be_entertained_all_the_time/).

**Adaptation:** crowd anticipation, a brief natural reaction, room echo, boot contact and the existing siren can establish football with less audio clutter. Do not play a celebratory blast over every score. A routine behind and a genuine last-kick win should feel different because the underlying events differ.

Use original or appropriately licensed audio. Studying songs is not clearance to copy their recordings, melodies or lyrics. Coordinate with PR #206 and existing controls; do not duplicate audio architecture.

**Smallest useful change:** one layered atmosphere mix for an existing match scene, with separate atmosphere/music control and a quiet option if existing settings permit. No audio-dependent strategic information; muted play remains equally clear.

### 3.8 Football culture includes far more than a Melbourne pub

AFL Play's selected stories include a Taiwanese-born Darwin umpire, a deaf community advocate, women playing in Sydney and a longstanding Alice Springs club connection. The MCC's account of a Muslim–Jewish youth fixture gives another specific example. These are selected institutional stories, not demographics to assign procedurally to every player. [F10: AFL Play](https://www.afl.com.au/news/1282513/afl-play-launches-more-to-footy-campaign), [F11: MCC](https://mcg.org.au/whats-on/latest-news/2022/september/third-annual-jolson-houli-unity-cup-returns-to-mcg).

The Grand Final at-home discussion includes many food, family, overseas and solitary rituals. It demonstrates variation, not that one meal or household structure is compulsory. [F22: supporter accounts](https://www.reddit.com/r/AFL/comments/1wpqmyk/grand_final_traditions_watching_at_home/).

**Adaptation:** crowds, clubroom background people and optional fictional profile details should represent varied ages, genders and contemporary Australian backgrounds. Family support can be a sibling, friend or chosen family; everyone need not be a father and son drinking beer. Decorative food or a scarf is a detail, not a badge certifying someone's Australianness.

Avoid tourism collages and random wildlife cameos. A game's national character can live in how people speak, care, tease and gather without kangaroos on every menu. No ethnicity-to-talent mapping, religion-based attributes or nationality humour.

### 3.9 Significant occasions need their own tone

Essendon's accounts explain the continuing purpose of The Long Walk and identify the artist behind a Dreamtime guernsey. The National Museum's Winmar material supplies historical context for why inclusion cannot mean simply reproducing every old crowd behaviour. [F17: Long Walk](https://www.essendonfc.com.au/first-nations-hub/the-long-walk), [F18: artist and club gathering](https://www.essendonfc.com.au/news/2027600/essendon-come-together-to-celebrate-dreamtime), [F15: National Museum](https://aws-digital-classroom.nma.gov.au/defining-moments/nicky-winmars-stand).

**Adaptation:** where an existing fixture has a real cultural or commemorative identity, present its documented meaning respectfully. Do not randomly apply ceremony, invent Traditional Owner names, generate imitation First Nations art, or describe future real-world events as if already announced. Specific cultural assets call for work with the relevant creators and communities; Creative Australia's guidance supplies that collaboration context. [F16: protocols](https://www.creative.gov.au/first-nations-arts/protocols-for-using-first-nations-cultural-and-intellectual-property-in-the-arts).

Gather Round's documented community activity suggests how an existing festival fixture can feel distinct through surroundings and anticipation. It does not authorise moving the fixture or promising a fixed real-world arrangement decades into a save. [F23: community roadshow](https://www.afl.com.au/news/1277342/2025-gather-rounda-festival-of-footy-kicks-off-with-regional-footy-roadshow/amp).

## 4. Keep flavour beautiful and out of the way

Use the existing flat editorial UI. The cultural references are content and composition references; **AFCM is not a visual aspiration**.

**Director visual-audit requirement, 6 October:** decorative banners and flavour must be clearly distinct from actual game information. Audit phone-sized composition and motion for placement, hierarchy and context; do not rely on colour alone, copy tactical-card styles or imply stat changes. Apply the same distinction to optional headlines, identity details and mementos. Useful information remains primary.

- One focal subject per scene. Give figures room; background detail sits behind the action.
- One short optional sentence where a sentence earns its place. Do not add a flavour-card stack to the Hub.
- A banner can be handmade; the navigation must remain professionally typeset. Never put essential data into illegible handwriting.
- Reuse the shared 2.5D footballers and current kit/number/appearance data. Preserve the complete art migration requirement.
- Prefer a change in framing, material, light or sound to an explanatory paragraph.
- Keep controls immediate and reachable. Atmosphere must not delay a choice, extend a load, conceal the ball, interrupt fast-forward or require an extra tap to advance.
- Support reduced motion, muted audio, both themes and natural Android Back. A quiet presentation remains complete.

All content quantities and pacing below are **prototype assumptions**, not research findings or settled production targets.

## 5. Approved extensions — director review completed

The director included all eight proposals, one by one. FL IDs identify accepted extensions inside existing owners, not duplicate feature tickets. DONE foundations remain DONE; each extension is outstanding TODO work tracked in roadmap §9.3. Prototype content quantities remain assumptions.

| ID | Approved extension and player benefit | Existing owner / initial prototype | Evidence and trade-off |
|---|---|---|---|
| FL-001 | Sparse footy voice: warmer language without obscuring meaning | M8-006; revise twelve optional lines in existing surfaces | F01/F12/F13/F14. Humour is subjective; factual/action copy wins every conflict |
| FL-002 | Milestone banner: one player visibly belongs to the club | M7-003 + M8-007; one supported milestone in the existing pre-match banner | F04/F03. Avoid extra waiting, false firsts and tiny names |
| FL-003 | Ground atmosphere: a recognisable place to play | M8-003/007; one sourced venue background and reusable dress | F19/F20. Art effort and performance; no new venues or home advantage |
| FL-004 | Natural sound and breathing room: football feels present | M8-006 + existing audio work; one atmosphere mix | F05/F06/F07/F21. Repetition and sensory fatigue; avoid licensed-song dependency |
| FL-005 | Optional fictional identity details: remember people beyond OVR | M7-005 and existing M7-008/009 nickname fields; twelve fictional profiles with optional nickname and one harmless interest | F08/F09/F10. Persistence cost and misleading trait inference; no personality system |
| FL-006 | Truthful short headlines: your actual week has a voice | Existing report/news/season-story / M4-009 + M7-005/011; six conditional templates | F01/F13/F22. Can exaggerate or become repetitive; no newspaper app/feed |
| FL-007 | Small club rituals: arrival, first goal, farewell and recognition feel different | M7-003/005 + M8-007 shared art; necessary new scenes authorised, start with one complete occasion | F03/F04/F07/F17. Preserve skip/pacing; no forced ceremony or new awards engine |
| FL-008 | Club memory in the surroundings: decades feel accumulated | M7-005 + approved alumni refinement; one existing profile/history surface with a factual visual memento | F02/F03/F09/F20. Avoid a collectible/archive system or unsupported family claims |

### Minimum acceptance for approved work

Every candidate needs the common purity and phone checks in §6. Additional observable acceptance:

- **FL-001:** action labels retain their meaning; humour has a plain alternative; no attributed real-player quote is invented; repeat lines can be suppressed.
- **FL-002:** correct selected player, club, count and scope; unsupported imported firsts fall back; name readable before the existing transition ends. The director specifically requires a visual audit showing that decorative banner content is distinct from actual gameplay information.
- **FL-003:** environment matches the referenced venue and available match facts; no altered pitch geometry or reduced actor/ball visibility; low-end phone cost measured.
- **FL-004:** silence and muted play are valid; existing match cues remain intelligible; no music masks a meaningful crowd reaction; licensing/provenance recorded for actual assets.
- **FL-005:** metadata is explicitly cosmetic, stable across reload/transfer/retirement and independent of football generation; full-name search works; nickname removal is harmless; old saves need not acquire invented personal histories.
- **FL-006:** each factual assertion has a supported predicate; comeback/career-high/first/record claims require the necessary data; ties, draws, losses and empty context have neutral alternatives.
- **FL-007:** treatment follows the known event once; actual achievement is clear; routine events do not gain lengthy ceremony; replay is cosmetic and optional. Build new vignette scenes as necessary for genuine first goals, milestones, retirements and awards, using the shared approved art. This is explicit director authorisation, not a restriction to existing scenes.
- **FL-008:** names, stints, years and awards match stored history; no invented family, coaching appointment or trophy; new data missing after reload produces a neutral fallback.

FL-001 and FL-002 remain a sensible initial pair after the queue's correctness/dependency gates; all eight are approved, so that order is a recommendation rather than a further approval gate. FL-005 and persistent background characters require more care because stable cosmetic metadata must survive decades. FL-008 should first check the already-approved alumni/history presentation and avoid adding what exists.

## 6. Validation: enjoyment and absolute gameplay neutrality

Future implementation should compare the **same football seed and the same commands** with flavour on, off, skipped, replayed and reloaded. Football events, outcomes, progression, contracts and AI decisions must match. Compare canonical football state rather than the entire save file, since existing awards-view flags and optional cosmetic preferences may differ.

Cosmetic selection uses a separate stable identifier or presentation-only generator. Do not consume the football RNG. Hometown or nickname generation must not shift draft class generation. On-screen clocks and input windows must not progress while a blocking cosmetic presentation is shown. Prefer presentations that never block.

Content should be selected from available facts, not invented as a causal explanation. “The supporters enjoyed that” is decorative; “the speech lifted the team” implies an effect and is out of scope. If a caption looks strategically useful, players should be able to identify the existing fact behind it.

Prototype observed sessions with a small mixed group of experienced AFL followers and less experienced players, including supporters outside Victoria. A suggested first round is six to eight participants; this is a usability sample, not a national survey. Watch a few matches, revisit after multiple seasons, and ask:

- Which detail made this feel like your club?
- Can you remember a person or occasion without opening their ratings?
- Did any detail imply a gameplay bonus or new information?
- Which line felt forced, repetitive, mean or confusing?
- Did the extra presentation slow you down, hide a control or get skipped?

Record recognition, confusion, repeats, skips, reading time, audio comfort and phone performance. Repeat exposure matters more than a single amusing screenshot. Simulated long careers check factual/persistence errors, not whether people enjoy the writing.

## 7. Rejected and deferred adaptations

- No morale from songs, bonuses from banners, supporter loyalty scores, cultural attributes or ceremonial buffs.
- No flavour decisions with concealed consequences or another ClubLife event system.
- No daily news chores, social feed, collectible scrapbooks or revival of excluded RC-002 match bookmarks.
- No mandatory slang dialect, broad-accent spelling, constant swearing, class ridicule or fixed jokes about a club always losing.
- No fabricated private lives or scandals for named real players; no invented real-world quotes.
- No assumption that every venue is a country oval, every supporter drinks, or all northern competitions use the same season.
- No decorative claims that exceed known facts: precise attendance, inherited family lineage, unprecedented records or unseen training effort.
- No copied song lyrics, borrowed film catchphrase bank or autogenerated imitation cultural artwork.
- Necessary new FL-007 flavour scenes are approved; they use the shared art and retain correctness, readability and Android performance/verification gates. Unrelated tactical-library expansion is not added by this decision.

## 8. Delivery and next step

The initial research-only merge #254 added this report, its evidence ledger and sample copy without changing Claude's queue. This 6 October decision revision updates the canonical roadmap and Claude's queue after the director's eight answers. It changes no gameplay, APIs or save formats and preserves existing parent-ticket statuses.

All eight FL extensions are approved. Implement under the existing owners and roadmap §9.3, preserving correctness, shared art and Android verification gates and unrelated decisions in PR #232. The director added a visual-distinction audit and explicitly authorised necessary new ritual/farewell vignettes; no new include/exclude interview is required.
