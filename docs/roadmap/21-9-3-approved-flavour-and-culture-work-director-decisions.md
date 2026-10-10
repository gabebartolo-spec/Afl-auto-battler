# 9.3 Approved flavour and culture work — director decisions, 2026-10-06

**Authority:** the director reviewed FL-001 through FL-008 one by one and included all eight. These are now **authorised Claude execution work**, sequenced by §0.4.1 and the dependencies below. No further include/exclude interview is needed. The research-only merge #254 did not implement these features.

**Scope:** presentation and cosmetic identity only, with **zero gameplay effects**. Use the [research report](research/AFL_FLAVOUR_AND_CULTURE_RESEARCH.md), [source ledger](research/AFL_FLAVOUR_SOURCE_LEDGER.md) and [original sample copy](research/AFL_FLAVOUR_WRITING_SAMPLES.md). FL references identify accepted extensions within existing owners; do not create duplicate milestone, nickname, venue, news, audio or history systems. Existing parent-ticket statuses are not changed by approval; the extensions below are all TODO.

| Reference | Director decision | Canonical owner | Extension status / effort |
|---|---|---|---|
| FL-001 | Include authentic football language and restrained Australian humour | M8-006 | CLOSED as done (director, 2026-10-09; slice 1 #258, audit #381, fixes #386) / LOW |
| FL-002 | Include milestone banners; **audit their appearance so decorative content is distinct from actual game information** | M7-003 + M8-007 | DONE (#400, director approved) / MEDIUM |
| FL-003 | Include recognisable ground atmosphere | M8-003/007; reuse M7-009 venue identity/presets where available | DONE for the MCG (#537, director approved 2026-10-09) / HIGH |
| FL-004 | Include natural crowd sound, breathing room and volume controls | M8-006 + existing audio owner | DONE (#405 sounds, #409 crowd; director approved) / MEDIUM |
| FL-005 | Include persistent, harmless fictional-player nicknames and interests | M7-005 + existing M7-008/009 nickname/profile fields | DONE (#392, director approved) / MEDIUM |
| FL-006 | Include characterful, truthful headlines distinct from game information | M4-009 + M7-005/011 and existing news/season-story surfaces | DONE (#395, director approved, losses included) / MEDIUM |
| FL-007 | Include rituals and farewells; **build new vignette scenes as necessary** | M7-003/005 + M8-007 shared art/rendering | IN PROGRESS (milestone farewell #540) / HIGH |
| FL-008 | Include decorative club memories across decades | M7-005 + existing alumni/history presentation | DONE (#406, director approved, home games only) / MEDIUM |

### Common dependencies, limits and acceptance

1. Inspect current implementation and open PRs before starting. Reuse the active owner of any overlapping field, renderer, scene, news item or audio setting. Coordinate with current soundtrack work; do not assume PR #206 is merged or replace it with a competing system.
2. Preserve P0 correctness, phone-playtest and performance priorities. Shared vignette art must use the approved pre-rendered 2.5D footballers; complete the required migration of reachable legacy styles. FL-007 explicitly authorises necessary new **flavour** scenes, but does not waive the art/readability/performance gates or authorise unrelated tactical scenes.
3. Reflect authoritative facts. Do not modify ability, fatigue, injury, development, morale, relationships, board confidence, contracts, finances, scouting, AI, fixture rules, disciplinary outcomes or match results. Decorative interests/nicknames have no mechanical correlation. Do not invent private lives, quotations or scandals for real players.
4. **Visual audit required:** decorative banners, captions, profile details, mementos and scene copy must be recognisable as atmosphere rather than tactical advice, interactive choices, stat changes, warnings or new rules. Use placement, hierarchy and scene context, not colour alone. Keep useful information primary and unchanged; use a concise contextual label only where needed. Do not turn the distinction into more panels or explanation spam.
5. Compare the same seed and commands with flavour watched, skipped, muted, disabled and reloaded. Football events and canonical football state must agree; presentation preferences/viewed flags may differ. Cosmetic RNG/metadata must not consume the football generator stream or change draft generation.
6. Inspect phone-sized stills and motion at narrow portrait widths and native Android. Verify contrast, names, ball/actor visibility, touch, natural Back, scrolling, skip/replay and no extra loading wait. Record which checks remain untested. Observed sessions must check that viewers can distinguish flavour from actionable information and do not infer hidden buffs.
7. Prototype quantities in the report are starting budgets, not fixed content caps. Expand only within the approved purpose when the initial treatment works. Approval is not implementation: record evidence and outstanding work for each FL extension, without marking a completed parent foundation unfinished.

### FL-001 — Football voice and restrained humour
**Director decision (2026-10-09, ~21:45): FL-001 is CLOSED as done after slice 1.** The captions are already plain and warm, and the voice continues through the journalists (RPG-002), the sit-downs (RPG-001) and the headlines (FL-006). **Humour limits for every flavour line, game-wide:** at most one per screen; never beside a loss, an injury, a sacking or a suspension; never the same joke two weeks running. The older `PARTIAL` notes below are history.
**Scope:** revise optional captions and incidental details in existing surfaces. Give reports, banners and fictional clubroom notices appropriate voices; essential action labels remain plain.
**Dependencies:** UiKit writing/hierarchy and available event predicates.
**Exclusions:** a new dialogue/news framework, copied catchphrase bank, forced slang dialect or manufactured real-player quotes.
**Acceptance:** language feels natural, concise and affectionate; a newcomer understands controls; factual assertions have supported triggers; repeated jokes can be suppressed and silence is valid.
**Validation:** contextual copy review, repeated-season samples and phone reading. Test predicates only where new selection logic is introduced; do not add tests that merely duplicate static text.
**Status (2026-10-06):** `PARTIAL`. **Built:** slice 1 (#258), the two approved lines that have a truthful trigger: on a final (the fixture label says so; no round does) the pre-match scene opens with "Finals footy. Here we go." instead of "Warming up", and the run-out caption is "Through the banner". The copy audit of engine terms and software prose ([AFL_FLAVOUR_FL001_COPY_AUDIT.md](research/AFL_FLAVOUR_FL001_COPY_AUDIT.md), #381) and its three fixes (#386): the finals tie-break no longer says "seed", the Hub no longer says "match simulation", and the setting reads "Ask before playing a round for me". **Copy-review reconciliation (2026-10-07):** the second review (#487) is merged as documentation, not evidence that every proposed copy change shipped. Retain the director decisions/gaps below. **Waiting on the director's copy review** ([AFL_FLAVOUR_FL001_COPY_REVIEW.md](research/AFL_FLAVOUR_FL001_COPY_REVIEW.md)): the four plain captions (a bye, missed finals, empty offseason lists, no achievements), where the sheet recommends no change and calls FL-001 complete after slice 1; and five questions (how much humour and where, whether a loss is ever flavoured, fictive-name safety, whether headlines and banners belong to FL-006 and FL-002, whether clubroom notices want a place at all). **Decided by the director and built under FL-002 (#400):** "200 games. Take a bow, {display_name}." (not an unfinished FL-001 implementation), and the first-goal flavour headline, vague defender headline and tape notice are removed. **Audit reconciliation:** the Stat Guide percentage/weight prose was resolved by the director's “Words instead” decision and #398; the newer topic-navigation rewrite remains open under §1.11. The "Sim Round" button wording and ladder's "W-L" column remain copy-review questions unless a later director decision resolves them. **Not started, and not authorised without the copy review:** every other surface (reports, clubroom notices, headlines). No clubroom surface exists in the game.

### FL-002 — Personal milestone banners
**Director copy decisions (2026-10-06):** the approved 200-career-game line is **“200 games. Take a bow, {display_name}.”** Use the displayed real/fictive name and the authoritative milestone convention. Removed from the flavour samples: the first-goal headline, vague defender headline and tape notice. Do not restore those rejected lines; a defender headline under FL-006 must name the actual supported achievement. Pre-match banners may recognise only facts already known before the match, never predict goals or future events. Existing factual post-match milestone reports remain valid. See [updated writing samples](research/AFL_FLAVOUR_WRITING_SAMPLES.md).
**Scope:** use the existing pre-match banner to honour the selected player's genuine achievement, name and club. Distinguish senior-career and club-tenure counts. Use the ordinary club banner when history is insufficient.
**Dependencies:** M7-003 authoritative milestone facts, actual selection and the shared pre-match renderer.
**Exclusions:** banner crafting, extra loading phases, fabricated firsts or a second milestone calculation.
**Acceptance:** a late omission removes that player's message; imported history never creates an unsupported debut/first; long names remain readable. The director-requested visual audit demonstrates that the banner is celebration, clearly distinct from tactical/game information.
**Validation:** count thresholds, omission, two eligible milestones, real/fictive names, reload and phone-scale still/motion comparison. No duplicate reward, event or football-state change.

### FL-003 — Recognisable ground atmosphere
**Scope:** make existing venues identifiable through a sourced, restrained stand/fence/background/light treatment. Reuse shared assets and venue presets; do not require the entire Club Forge/expansion feature to build one existing venue treatment.
**Dependencies:** reliable venue identity, existing match context and approved art assets.
**Exclusions:** new venue scheduling, explorable towns, pitch-geometry changes, weather generation, home bonuses or travel effects.
**Acceptance:** a few accurate details establish place while players and ball remain primary; decorative conditions do not contradict available match facts; unknown time/weather uses a neutral fallback.
**Validation:** venue-reference review, quiet/busy backgrounds, both themes, camera/actor occlusion and measured Android performance.
**Director decisions (2026-10-09):** the MCG first, where the camera actually looks (three stand tiers, the fascia band, blue-grey night seats, two end screens; the light towers sit above every broadcast frame), kept subtle ("like the lighting"). It shows for a final at the MCG and for the home games of clubs whose ground is the MCG; every other ground is unchanged. Look approved and merged in #537.

### FL-004 — Natural sound and breathing room
**Scope:** add restrained ground/crowd atmosphere and differentiated reactions to actual events. Reuse existing music/volume architecture and provide natural pauses plus atmosphere/music control and a quiet option.
**Dependencies:** current audio work and authoritative event timing.
**Exclusions:** constant announcements, music over every score, a second audio system or a licensed-song dependency.
**Acceptance:** important information is equally clear when muted; routine and genuinely dramatic events sound appropriate; repetition and loudness remain comfortable; watch/skip/replay never repeats a football event.
**Validation:** original/licensed asset provenance, controls, muted play, simultaneous sound cues, skip/reload, frame/load cost and listening after several matches.

### FL-005 — Harmless fictional-player identity
**Scope:** optional nicknames and one small personal-interest detail for generated fictional players, visible in existing profiles and natural presentation. Reuse the already-approved nickname/commentary-short-name field in M7-008/009 rather than introduce another alias. Nicknames can be changed/removed without a cost or consequence.
**Dependencies:** stable player ID, displayed-name preference and backward-compatible cosmetic persistence.
**Exclusions:** new personality ratings, inferred ethnicity/character from names, gameplay traits, real-player invented habits or a separate player editor.
**Acceptance:** full-name records/search remain intact; nicknames/interests survive transfer and retirement; old saves remain valid and need not acquire invented histories; details are unmistakably cosmetic.
**Validation:** generated/custom players, changed/removed nickname, name search, fictive mode, same-name players, save/load and multiple decades. Cosmetic metadata never shifts football RNG or prospect abilities.

#### Director addition — Favourite club on every player bio card (2026-10-06)
**Status:** `TODO` — cosmetic profile detail; this explicitly extends the profile flavour scope to sourced real-player facts.

Add a **Favourite club** field to all player bio cards, for example **Favourite club: Demons**. "Demons" is an example value, not a universal assignment. The field records the club the player supported **before being drafted**, not their current employer.

- For real players, research and use their actual publicly documented pre-draft/childhood favourite club where available. Prefer player interviews and official club/AFL profiles; retain the source URL/date against the stable player ID and resolve conflicting accounts rather than guess.
- If no reliable source is found, show a restrained unknown state such as "Not recorded"; never infer allegiance from current club, hometown, surname or the director's example.
- Generated fictional players can have a persistent cosmetic favourite club; custom prospects can choose one. Keep this data separate from real-player research and preserve it through transfers, retirement, name-display changes and save/load.
- Reuse the existing player profile/card and club-label systems, with a concise readable row on phone. This is flavour only: no effect on contracts, recruitment, trades, morale, loyalty or gameplay, and cosmetic generation must not disturb football RNG.

Acceptance: every bio card supports the field; sourced real facts display correctly, unknowns remain honest, generated/custom values persist, and a transfer never changes the childhood allegiance. Validate phone layouts, old saves, fictive-name mode and stable-ID/source mapping.

### FL-006 — Truthful characterful headlines
**Scope:** sparse optional headlines in the existing match report, news feed and season recap. Coordinate with M7-011's veracity standard and existing season-story data; use a neutral fallback if a stronger claim lacks support.
**Dependencies:** reliable result/story predicates and existing reporting surfaces.
**Exclusions:** new feeds/apps, best-move advice, fake coach quotations or a bookmark/replay archive.
**Acceptance:** close win, comeback, first, record and elimination claims are made only with the required facts; ties and quiet losses remain truthful. Editorial flavour is visually separate from scores, tactical feedback and actionable information.
**Validation:** event-to-copy fixtures for thresholds, missing history, draws, transfers, repeat reload and scrolling; observed reading must not mistake a joke for a modifier or tactical recommendation.

### FL-007 — Club rituals, recognition and farewells
**Scope:** distinctive presentation for genuine first goals, milestones, retirements and awards. **The director explicitly authorises building new vignette scenes as necessary**, including scenes beyond the current tactical/pre-match set. Reuse existing scenes where suitable and the shared 2.5D figures/kit/appearance pipeline; build new scenes where the occasion needs a distinct treatment.
**Dependencies:** known event and participants, current milestone/retirement/award owners, shared art migration and presentation flow.
**Exclusions:** changed votes/winners, fabricated achievements, forced retirements, separate award engines, duplicated rewards or unrelated tactical-library expansion.
**Acceptance:** first implement one complete event-to-scene-to-return path, then cover the approved occasions coherently. Every scene honours the correct person/event, is skippable/acceleratable, and returns cleanly without changing the football or awards. Routine repeats avoid lengthy ceremony; meaningful recognition can remain sincere.
**Validation:** reachable scene inventory, new poses/assets, actual participants/club colours, factual triggers, once-only/replay handling, reload/Back/skip and native Android load/performance/pacing.
**Director decisions (2026-10-09):** the first occasion is the milestone farewell after the siren: both teams form a guard of honour and clap him off (hands meeting on a diagonal, cupping the air), then two teammates chair him off, hands holding his legs. About 6 seconds, skippable with a tap, full time already built underneath. It plays at a player's 200th, 250th, 300th... game (club or career) and on his last game; the debut, 50th, 100th and 150th keep their banner only. Board approved (guard of honour and chaired off); the built scene still needs its look approval before #540 merges. The tactical decision-clarity gate remains for tactical scenes; a flavour scene is judged on recognition, visual distinction and enjoyment, not a nonexistent tactical choice.

### FL-008 — Club memories across decades
**Scope:** use existing club/history/profile surfaces and surroundings to retain factual visual reminders of premierships, notable players and alumni. Audit already-approved former-player links before building another treatment.
**Dependencies:** stable stored years/stints/honours and actual coach-player links.
**Exclusions:** collectible economies, another archive, fabricated family lineage, guaranteed coaching careers or new history aggregation.
**Acceptance:** mementos evolve from genuine save events, remain clearly decorative, and preserve names/history after transfers and retirement. An anonymous/background character does not stay the same age for fifty years. Missing history gives a neutral fallback.
**Validation:** long-save/reload fixtures, transferred/retired/generated players, same-name/number collisions, imported history once and phone retrieval. Ask whether the player recognises their own club's history without adding a wall of information.

---

## ARD-M8-010 — Trailer production gate
**Status:** `DEFERRED`  
**Priority:** `P3`  
**Autonomy:** `SUPERVISED`

### Intent
Create a polished trailer for Aussie Rules Dynasties only when the game itself is sufficiently mature that the trailer can represent the real product rather than advertise unfinished systems or placeholder presentation.

This is a **hard-gated late-project item**.

### Start conditions
Claude must **not begin trailer production** until all of the following are true:
- the roadmap is **mostly complete**,
- major visual/presentation work is substantially finished,
- the game's visual polish is close to the intended shipping quality,
- the core loop, matchday presentation, Club Forge/customisation, long-career systems and other major player-facing features intended for the trailer are stable enough to capture,
- there are no known major placeholder visuals that would make the trailer misleading or immediately obsolete,
- the user has given **explicit go-ahead to start trailer work**.

Roadmap status alone does **not** authorise work on the trailer.

### Explicit approval gate
Claude has **no standing authority** to initiate this item.

Even if every technical prerequisite is satisfied, Claude must stop and wait until the user explicitly says to proceed with the trailer.

Do not:
- begin editing,
- capture footage,
- install trailer-production tools,
- create music specifically for the trailer,
- render title cards,
- assemble cuts,
- or open a trailer PR

before that explicit approval.

### High-effort agent responsibility
A high-effort Claude run should periodically reassess whether the project has reached the point where a trailer is sensible.

When Claude believes the roadmap is mostly complete and visual polish has reached a strong enough level, Claude should **tell the user that it believes the trailer gate is ready** and briefly explain why.

That message is a recommendation only. It does **not** authorise trailer production.

### Software permission
Once the user explicitly authorises trailer work, Claude may source additional software needed for trailer production under these constraints:

- **Free software only.**
- Open-source tools are preferred.
- No paid licences, subscriptions, trials that will later charge, or purchases without separate explicit user approval.
- Claude may research, download and use suitable free software if its environment permits.
- If Claude cannot install/use a required free tool directly, it should give the user concise instructions for obtaining/installing it and then continue once available.
- Record any new tool and its licence/source in the trailer implementation notes.

Potential categories include:
- video capture,
- editing,
- transcoding,
- audio cleanup/mixing,
- motion graphics,
- image compositing,
- subtitle/title-card production.

Do not lock the roadmap to one editor in advance; choose the simplest suitable free tool at production time.

### Trailer goals
The trailer should sell the actual strengths of the finished game:
- building and shaping a club over decades,
- meaningful matchday coaching decisions,
- recognisable players and evolving careers,
- drafts, trades and list construction,
- expansion/custom-club identity where visually mature,
- polished match vignettes and club visual identity,
- emergent stories rather than scripted fake drama.

Do not manufacture gameplay outcomes that the real game cannot produce.

### Capture rules
- Capture from a build representative of the intended release quality.
- Prefer genuine gameplay and real in-engine presentation.
- Do not hide major limitations with deceptive editing.
- Avoid debug UI, placeholder art and temporary assets.
- Use real game audio/music only if it is cleared for trailer use.
- If custom trailer music is required, it must also comply with the free/licensed-use rule.

### Pre-production deliverable
After the user explicitly approves trailer work, Claude should first produce a short trailer plan before editing:
- target length,
- audience,
- story arc,
- shot list,
- required game states/saves,
- capture list,
- music/audio approach,
- title-card copy,
- output formats,
- distribution targets.

The user should be able to review this plan before significant editing effort is spent.

### Acceptance
The trailer item can only move out of `DEFERRED` after:
1. Claude recommends that the gate is ready,
2. the user explicitly authorises trailer production.

It is complete only when:
- the trailer accurately represents current gameplay,
- footage is visually polished,
- audio levels are clean,
- text is readable on mobile and desktop,
- no unlicensed material is present,
- final exports are produced in suitable release formats,
- the user has reviewed the finished cut.

---


