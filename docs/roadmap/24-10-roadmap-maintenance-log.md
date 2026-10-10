# 10. Roadmap Maintenance Log

- **2026-10-10 — team board and queue refresh (docs only):** `docs/agents/STATUS.md` rewritten for the current team (boss, support, art, hygiene; the lanes, leader and helper archived by the director) with the standing rules of 2026-10-10, open PRs and what waits on the director. §0.4.1 header moved to `d355eefa`; item 1 records #575/#593/#594/#605. No scope or status change elsewhere.
- **2026-10-09 — design bible:** the director's design bible is now in `docs/DESIGN_BIBLE.md` and outranks this file on design (header, §0.1.1 lexicon, §0.2). Audited the design documents against it: `docs/BIBLE_AUDIT_2026-10-09.md`. Recorded, all unassigned: the press-answer dice-roll decisions under ARD-M6-008, the pre-timeskip survey under ARD-M1-007 and the balance sign-off rule in §1.10. No status, priority or queue order was changed; the audit lists the queue question for the director.

- **2026-10-07 — director chat coverage audit:** verified every actionable request and subsequent clarification from this chat against the live roadmap at blob `4401369ac59b`. No request was missing; this receipt records locations rather than adding duplicate tasks or declaring implementation complete:
  - **Complete Stats patch:** §1.11 Season stats hub — every listed metric, competition-wide match/season aggregation and sortable/filterable views, expanded ladder, fixture/results, awards and trophy room; real-event counts/derived ratios, reuse/tests, single highest priority, implementation authorised for 2026-10-07 and explicit implementation merge HOLD.
  - **Combine menu:** ARD-M5-014 — complete navigation/statistics, readable football interpretation and flavour; HIGH priority and integral to postseason.
  - **Coach retention/hierarchy:** ARD-M6-002 follow-up — Head coach → Head assistant → other assistants; opportunity-based promotion/succession counter-offers, no monetary bidding, genuine commitments and persistence.
  - **Roadmap cleanup:** §0.4.1 / canonical status reconciliation — shipped foundations distinguished from incomplete/verification scope; task IDs, original unresolved requirements and review/device gates preserved. The earlier complexity summary is not implementation evidence.
  - **Exit game:** ARD-M8-004 — explicit TODO main-menu button with clean shutdown/save preservation.
  - **Vignette motion audit:** ARD-M8-007 — Claude watches full sequences for ball transport/contact, limbs, robotic running, artefacts, clothing and perspective; latest priority is P3 LOW.
  - **Speccy:** ARD-M8-007 — identify who actually kicked the incoming ball, explain the umpire-only background and show credible delivery/contest continuity; P2 MEDIUM, separately from the broad P3 audit.
  - **All-artwork review:** ARD-M8-007 / STYLE-06 — inconsistent/overstrong cel shading, weak textures/flat colours, generic impersonal props/furniture, mimicked postures and uncanny/inhuman anatomy; actual scene/asset evidence and director-approved local treatment.
  - **All gameplay levers and copy:** §1.12 follow-up — exhaustive control-to-effect verification, no cosmetic/no-op gameplay promises, accurate concrete football descriptions, conditions/tradeoffs and evidence register.
  - **Onboarding:** ARD-M8-004 / §1.11 — fresh-save initial draft, weekly and postseason coverage; latest selective rule exempts clearly obvious controls from bombardment but explicitly explains essential/alternative interactions, multi-select, long press and important gameplay levers.
  - **Post-finals/recruitment onboarding:** ARD-M8-004 with M6-007/M5-014/M6-004 — first full postseason after competition finals finish, actual order/cadence/deadlines, interpreting Combine results and concise specific trade/contract explanations.
  - **Quick sim and waiting:** ARD-M1-007 — explicitly introduce Play round long press and its real endpoints; investigate/reduce reported five-minute season-skip wait without dropping simulation/stats or required decisions.
  - **Multi-day trades:** ARD-M6-004 — 3–5 game days, default three; user/rival submissions during the day, club/player final decisions at day close, equal mobility and no first-refusal exploit; failed day-one offers can be revised across the remaining two days.
  - **Awards and finals presentation:** ARD-M7-005 — genuine round-by-round Brownlow with continuous/pause/manual next-round/skip-round/skip-all controls; §1.11 existing Grand Final presentation owner — bespoke Finals hub review/prototype based on the supplied progression reference, available when the user's club is out, explicitly including wildcard matchups/results and their route into finals.

- **2026-10-07 — conservative implementation reconciliation:** checked live main at `7ebb7d5c`, current source/regression checks, merged PR metadata and the open-PR set. Updated the execution queue and stale effort references; recorded the merged team builder/opposition/report (#499/#500/#505), match-stats layout/break access (#507), draft age/filtering (#497), club paint flow (#493/#498), custom-club staffing (#490), scroll repair (#489), heading/ball-up/tagger repair (#492/#510), number/equal-choice repair (#496), sheet sizing (#495), six plans (#479), set-shot events/presentation (#467 including #471), weather (#449/#473), shape demos/labels (#475/#480), seam repair (#491) and Training alignment (#277). Generic custom-prospect creation (#309) is PARTIAL rather than absent; the named use case and creator follow-ups remain. Draft/POT (#494), shared team-builder and weather umbrellas remain PARTIAL where broader acceptance is unproven. #513 merged only into Stats integration #509, not main: Stats stays IN PROGRESS, complete scope and explicit merge HOLD preserved. Combine and coaching opportunity/succession additions stay TODO. Original unresolved requirements, histories, device/design gates, deferred items and evidence links are retained. Documentation-only audit: no gameplay changes, new simulation claims, fresh full-suite runs or implementation merges.

- **2026-10-06:** Included the director-requested free texture, artefact/anti-aliasing and frame-rate/loading/battery findings as P1 high priority in existing ARD-M8-007 LS/A4 and §1.11 owners, execution queue and MEDIUM effort list. Records source-art/CC0 options, packed-data accuracy, local AA/MSAA limits, atlas-safe filtering and measured idle/loading/rendering optimisation. Preserves active ownership, save/gameplay correctness and phone/appearance gates; no implementation or benchmark outcome marked complete.

- **2026-10-06:** Added the director-requested free shader-polish suggestions as P1 high priority under ARD-M8-007 and in the execution/effort queues. Prioritises existing-pass character treatment, ground shading and softer contact shadows; records optional local effects/outlines, free references, preserved packed-data contracts and measured Android/performance gates. No game implementation or visual verification marked complete.

- **2026-10-06:** Added sourced pre-draft Favourite club bio-card flavour under FL-005, with honest unknowns and persistent cosmetic generated/custom values. Added full match-to-date Stats access at every quarter break under ARD-M4-009, reusing the existing stats view and preserving the paused decision flow.
- **2026-10-06:** Added ARD-M4-016, match-day weather, from the director's decisions and the lead's evidence (docs/research/WEATHER_EVIDENCE.md).
- **2026-10-06:** Recorded the director's interview on the match-visualisation research.
  - ARD-M8-003 gains an agreed sequence: truth fixes, a tactical timeline, two demonstrations, then lanes. No overlay, and the play library is held.
  - New items: ARD-M4-012 (intercepts by zone), ARD-M4-013 (set-shot choices and a real bomb pack), ARD-M4-014 (kick lanes that matter) and ARD-M4-015 (merge the plan names to six).
  - 2026 centre ball-up approved.

- **2026-10-06:** Scars removed from the player look (director, in chat with the lead: "remove scarring from the game, unnecessary detail"); the Club Forge look specification no longer lists them.
- **2026-10-06:** Recorded two hair decisions in §9.1 (director, relayed by the lead): hair and beard look-dev stopped; the director's hair research adopted as the brief (three prototypes through the production path, reviewed in Blender and at game scale, before any rollout).
- **2026-10-06:** ARD-M5-003: development projects made to matter is merged (#379).
- **2026-10-06:** ARD-M7-009 status: the fair fixture for 18 to 21 clubs (#361) and the club-count board defaults (#359) are merged, with the Create a club engine (#340); the screen (#360) and Create a player (#309) wait on the director.

- **2026-10-06:** STYLE-07 (PC fullscreen readability) is IN REVIEW in #371, with the cause and fix recorded; it is DONE only after the director's PC review.
- **2026-10-06:** STYLE-07 (PC fullscreen readability) is DONE: #371 merged with the director's approval recorded on the PR.

- **2026-10-06:** Recorded five more director decisions in §9.1: trades at real volume; synergy selection and development projects must have an impact; the clearance winner keeps the first disposal; the Create a club screen is approved; freckles removed (confirmed in the director's words).
- **2026-10-06:** Merged-PR status lines in §9.1: trade volume data (#376), the clearance winner (#373) and freckles (#357).
- **2026-10-06:** Recorded the director's animation and Stat Guide decisions in §9.1 (centre-bounce prototype now; kick and press room behind hair; no reduced-motion setting; awards walk-on unchanged; Stat Guide in words, #398).

- **2026-10-06:** ARD-M7-009 Forge location research merged (#343, #351): 33 of 53 places have pattern tags and 46 of 53 have colour tags; the empties are listed in the status line.

- **2026-10-06:** Freckles removed from the player look (director, 2026-10-06, relayed by the lead): unnecessary detail. The Club Forge look specification no longer lists them; the 2026-10-05 entry below is history.

- **2026-10-06:** ARD-M5-001 is DONE (#331, 18 + 5, All-Australian 23, dual ruck); match-day wording in the roadmap follows 18 plus five (best side, 23), with dated evidence left as it was.

- **2026-10-06:** Recorded two director decisions (§9.1 and ARD-M7-009): a created club enters with the career and drafts in the League Draft with no concession package; a 21-club season is 24 rounds, 22 games and two byes a club (for reference, the existing fixture: 23 games at 18 and 20 clubs, 22 at 19).

- **2026-10-06:** Verified inherited 2026-list start and custom prospect are not implemented on main; promoted ARD-M5-016 to P0 and ARD-M7-008 to P1, with Alastair McNeil explicitly required as the first named custom-prospect use case under normal draft/generation rules.

- **2026-10-06:** Added Gather Round as a TODO follow-up under ARD-M7-002, covering hosted fixtures, calendar/match identity, venue consistency, expansion/bye-safe scheduling and persistent event data.

- **2026-10-06:** Required success/failure vignette endings where appropriate, using the authoritative post-choice roll with intermediate outcomes and deterministic reloads; no separate cinematic reroll or artificial result for ceremonies.

- **2026-10-06:** Added a fat-side switch vignette and explicitly made all five newly requested concepts decision gates: setup/readable trade-offs, pre-action pause, meaningful alternatives and authoritative consequences, with restrained triggering.

- **2026-10-06:** Added a hip-and-shoulder vignette concept: potentially powerful removal from the immediate play, balanced by free-kick risk and a very small context-dependent chance of report/potential suspension through the existing MRO system.

- **2026-10-06:** Added three requested match-vignette concepts under ARD-M8-007: blocking the opposition star midfielder at a stoppage, a torpedo kick-out down the centre after a behind, and an inside-50 kick into space for a running forward to collect and shoot.

- **2026-10-06:** Added director consideration under ARD-M7-004 for Leadership as a numerical player stat (not a trait), independent of OVR/age/appointment, for Claude to refine alongside modest captaincy effects and save compatibility.

- **2026-10-06:** Added red/yellow match-ball support under ARD-M8-007, including yellow balls in appropriate vignettes and one persistent, consistent colour across all scenes from the same match.

- **2026-10-06:** Added the Danny Frawley Golden Fist season award for the best defender, with role-aware judging, season-end recognition and persistent career/award records.

- **2026-10-06:** Added solo vs dual ruck match-prep follow-up under ARD-M4-004, with meaningful trade-offs, trait/personnel fit and AI parity. Ruck King, Extra Midfielder and Unicorn are optional design references for Claude to refine, not mandated traits or effects.

- **2026-10-06:** Promoted ARD-M5-001 (18 + 5 interchange) to P0 at director request after verifying main still uses four bench players; added complete fifth-player participation and save-compatibility acceptance criteria.

- **2026-10-06:** On the director's request, added free lighting/surface-detail findings and five scoped follow-ups under ARD-M8-007 (LS-01–05): offline lighting, restrained player materials, environment/prop surfaces, optional runtime 2D lighting and phone/performance review. Reuses the existing pipeline and shadow work; records free CC0 sources, Material Maker/Krita options and Laigter's paid-binary caveat. Final appearance remains subject to the existing art-agent/director gate; no art or game implementation marked complete.

- **2026-10-06:** Added a BALANCE-GATED career-stage OVR economy follow-up under ARD-M5-010. Phone playtesting shows too many high-POT rookies can enter looking stronger than established AFL professionals. Audit rookie starting OVR, established-player compression and age/development assumptions; create more development headroom for most prospects and modestly strengthen genuinely established players where performance evidence supports it, without blind age modifiers or making OVR cease to represent current strength.

- **2026-10-06:** Added a phone-playtest correctness defect for the post-match **Needs a lift** section: injured/injury-shortened players are being mistaken for poor performers. Exclude reduced-opportunity injury cases from criticism, keep injuries in their own surfaces, and allow the section to be empty when nobody genuinely underperformed.

- **2026-10-06:** The director approved implementing the best findings of the Codex research (project, workforce and art reports). §0.4a gains the team workflow rules W1–W7: fresh sessions at task boundaries with handoffs, direct messages, explicit states, event-driven monitoring, process ownership, semantic review for lifecycle changes, and the check-floor collision rule. §9.4 gains G1 (one interruption budget) and G7 (one career-fact record) as prerequisites. G10 (safe save replacement) is fixed in its own PR, and A4 (data textures stay lossless; colour atlases ASTC 4×4) in the art agent's.

- **2026-10-06:** Added a phone-playtest visual defect under ARD-M8-007: the boundary-snap vignette shows an unexplained curved white line. Audit whether it is a trajectory/debug/mask/sprite artefact and remove it without breaking any intentional ball-flight readability.

- **2026-10-06:** Added a director-requested **Defensive forward** archetype/trait under ARD-M4-004. It should provide a personnel-dependent way to make a damaging loose/intercept defender accountable, with a real attacking sacrifice rather than a magic debuff. Claude is explicitly asked to ponder and propose the smallest football-credible implementation and how it fits the existing archetype/trait/role systems before expanding mechanics.

- **2026-10-06:** Added two phone-playtest follow-ups: simplify the text-heavy “This week v …” comparison into a faster visual read without prescribing red/green or violating anti-slop/anti-psychic rules; and allow an assigned specialist tagger to remain selectable/assigned while on the bench, with sensible interchange shadowing of his target rather than on-field-only eligibility.

- **2026-10-06:** Expanded ARD-M8-003 from general authenticity polish into a concrete visualiser truthfulness pass from phone playtesting: tactical calls such as Flood the backline must visibly alter authoritative team shape; investigate receiver-seeking ball movement, unexplained disposals into empty space and distant-player contest wait states (including possible ruck-arrival waits); and keep tactically important actors such as taggers, hot players and roaming interceptors named on the visualiser. Presentation must expose real simulation behaviour, not fake it.

- **2026-10-06:** After the complete one-at-a-time interview, included all eight STYLE-01–STYLE-08 work packages in §9.5 and the execution/effort queues; no rejections. Added the director-confirmed Training player-row vertical-alignment defect, dark Android priority, art-agent visual authority and director approval of all final treatments. Extended existing owners rather than reopening DONE foundations or duplicating M8-007. Research/source evidence is preliminary; implementation and native Android verification remain outstanding.

- **2026-10-06:** Low agent, docs steward and CI owner. Added §0.4a: effort tags (`LOW` / `MEDIUM` / `HIGH`) with every open item sized into a lane, and the parallel-work rules for the agents working at once (hot files, check floors, local Godot use, no pushes mid-CI). Replaced 15 §1.11 observed-failure bullets that are built and tested on `main` with one "Closed from this list" line naming the evidence. CI now runs the Godot suites as parallel shards (`tools/ci_shards.txt`, plan job, extras job, the required check still `test`) and long audits run on GitHub (`audit.yml`). README, DESIGN and `tests/README.md` corrected against the code.

- **2026-10-06:** After all eight director answers, authorised FL-001–FL-008 in §9.3 and the execution/effort queues under existing owners. Added the explicit visual-distinction audit and permission for necessary new ritual/farewell vignette scenes. Every addition is presentation-only with zero gameplay effects; existing feature statuses and unrelated review gates remain unchanged.

- **2026-10-06:** FL statuses in §9.3 set from what has merged: FL-002 (#400), FL-004 (#405, #409), FL-005 (#392), FL-006 (#395) and FL-008 (#406) are DONE with the director's approval; FL-001 is PARTIAL (#381 audit, #386 fixes); FL-003 and FL-007 stay TODO.

- **2026-10-06:** Merged-PR status lines: #438 (ARD-M8-003 step 1, the truth fixes), #393 (ruck clearances and middle-zone carrying; reverted in #443 and being reworked), #360 (the Create a club screen), #423 (STYLE-02 type roles at today's sizes) and #428 (audit seeding: `run_audit.gd` seeds the global RNG, `AUDIT_SEED` default 2026).

- **2026-10-06:** The director approved the ARD Signwriter typeface ("Approve and merge") and #419 is merged: STYLE-02's typeface is DONE. #408 (the type specimen) is closed as superseded.

- **2026-10-06:** Extended the art-agent tooling permission to fonts: it may research, download and use free/licensed fonts suitable for game distribution, or direct the user to install them. Paid font licences and subscription services remain disallowed without explicit approval.

- **2026-10-06:** Granted the art agent permission to investigate and use free-only software for bespoke UI/art production, or direct the user to install suitable free tools when required. Paid software, subscriptions, paid plugins and charging trials remain disallowed without explicit approval.

- **2026-10-06:** Clarified the anti-slop warning: the problem is specifically visual style (rounded-card geometry, corner radii, generic palette, button/card silhouettes and app-template aesthetics), not information density or "visual vomit". Footy Redraft and AFCM are explicit negative visual references for this criterion only.

- **2026-10-06:** Added an explicit warning that the current UI policy/implementation has drifted from the project's anti-slop criteria. Reasserted restrained, mobile-first, football-specific UI guidance and instructed future UI work to remove unnecessary cards/chips/boxes/accents rather than layering on more template-style chrome.

- **2026-10-06:** Added ARD-M8-010 as a hard-gated late-project trailer task. Claude may recommend when the roadmap/visual polish are mature enough, but cannot begin trailer work without explicit user approval. Once approved, Claude may source/use free software only, or direct the user to install suitable free tools.
- **2026-10-06:** Merged-PR status lines: the tactical timeline (#445, M8-003 step 2), trades at real volume (#383), and the synergy-trait (#440) and rating-parity (#446) audits. ARD-M4-004 gets its line when #303 lands.

- **2026-10-05:** Tightened ARD-M7-011 with a footyhead-proof veracity standard: real AFL facts must be sourced and auditable, ambiguous/non-trivial claims should be cross-checked against multiple strong sources, and disputed or uncertain claims should be omitted rather than guessed.

- **2026-10-05:** Refined ARD-M7-011 so historical facts/stats should primarily enrich the existing news feed and other natural football stories, e.g. “Essendon has won its first final in X days,” rather than appearing as detached Wikipedia-style trivia. Loading-screen/dead-time fact dumps are explicitly lower priority.

- **2026-10-05:** Added speculative ARD-M7-011 for an AFL knowledge layer. Claude should investigate unobtrusive places to surface sourced fun facts, records, venue/competition history and factual achievements/stories of real AFL players already in the game, with dynamic context and strict anti-trivia-spam guardrails.

- **2026-10-05:** Expanded Club Forge character creation with boots, independent hair/beard colours, skin tone, freckles, subtle scars, dominant foot, preferred guernsey number and an optional nickname/commentary short name. Dominant foot has modest football/presentation meaning; all other additions are cosmetic, and number conflicts must resolve through normal club numbering rules.

- **2026-10-05:** Expanded Club Forge player appearance again: substantially more hairstyles including a proper Bald option, plus independent beard/moustache choices. Hair and facial-hair variation should also feed generated players, with compatibility rules for headbands and vignette-scale readability.

- **2026-10-05:** Expanded player appearance variation in Club Forge: headbands, bandaging and tattoos now join Tall/Short socks as persistent cosmetic options. These can also seed generated-player visual variety; all are gameplay-neutral, with original/non-copied tattoo art and restrained football-appropriate bandage placement.

- **2026-10-05:** Added Tall socks / Short socks as a cosmetic player-appearance variant. It is a toggle in Club Forge character creation, persists per player, appears in match/vignette rendering where visible, and may also be used for generated-player visual variation. No gameplay effect.

- **2026-10-05:** Clarified ARD-M7-010 Indigenous guernsey direction: Claude should learn the broad visual language and art-style vocabulary from extensive real-world research, then create original club-specific designs. The game does not need to copy specific artworks or fabricate cultural narratives/meanings for fictional guernseys.

- **2026-10-05:** Added ARD-M7-010 for a full Sir Doug Nicholls Round system: extensive official-source research of Indigenous guernsey history from 2014 onward, a 5–10 design rotating library per club, per-club bye/catch-up wearing logic, vignette integration, save-stable seasonal kit assignment, and strong cultural/IP safeguards against copying artist-owned or culturally specific artwork without permission.

- **2026-10-05:** Expanded ARD-M7-009 Club Forge with a researched Australian football location/venue library and deeper procedural guernsey vocabulary. Create-a-club should offer major unrepresented suburbs/football centres nationwide, explicitly including Darwin and Alice Springs and preferring established second-tier football locations such as Southport, Norwood and Peel. Added real-ground mapping, stable venue names separate from sponsor aliases, lower-league design research requirements, and licensing/cultural guardrails for club trademarks and First Nations artwork.

- **2026-10-05:** Added ARD-M7-009 for expansion-club career setup: Tasmania 2028, optional Canberra 2030, real Tasmania-style premium draft concessions, a bespoke main-menu Club Forge for create-a-club/create-a-player, support for a 21st custom club and fair odd-club fixtures. Clarified that all AFL players must reach expansion years through normal ageing/development/list turnover rather than frozen-roster age jumps. Updated ARD-M7-008 so a custom prospect has a one-time hidden POT roll with a usable role-player floor and a rare S-tier ceiling.

- **2026-10-05:** Added independent genre enjoyment research covering eight cross-genre references plus Footy Redraft/AFCM, Crusader Kings and Esoteric Ebb, including the director's replayability/trust/storytelling and short-question preferences. Refined existing tactical, role, development, market, history and QA owners with dependencies, exclusions, observable outcomes and validation. Added accepted ARD-M5-016 (inherited end-2026 lists → 2026 National Draft → 2027), separate from review-only ARD-RC-001–005. Reconciled merged #210/#213/#214/#217/#220/#221/#222/#225 and open #206/#223/#224/#226 against main `4b9eecc3858e970c46e25366701907f1cb4c6070`; preserved phone and balance gates. Documentation only; no gameplay merge or Claude assignment.

- **2026-10-05:** Overall difficulty, second pass: active management measured against autopilot; weekly cards, early extensions, market-tested starters, trade pricing and rival trades, the match-day assistant and the opening draft's rival scouting changed (director's calls). Contract-talk item done; trade valuation and key match-ups statuses updated.

- **2026-10-04:** Competitive-balance first pass (`docs/COMPETITIVE_BALANCE.md`): fixed the user-only morale edge; verified fatigue, training and development parity; explained List Profile (a rank, not a threshold) and synergy counts; fixed the expansion-list ceiling behind the age-28, 89-POT generated player; recorded list-management pressure as the remaining design-level cause.

- **2026-10-04:** Added Academies / NGA and tied-prospect draft mechanics as a later draft-pathway layer, explicitly downstream of core draft depth, Combine/scouting and AI drafting fixes.

- **2026-10-04:** Consolidated the multi-season Android/Italy playtest findings: P0 bye/progression and football-sanity bugs; overall difficulty/list-profile/synergy calibration; fatigue parity, generated-player provenance, trade/potential and coaching-mobility audits; contract/off-season pressure; weekly selection and matchup decision support; mobile selection/training UX; and observed presentation formatting issues.

- **2026-10-05:** Playtest audits part 2 (PR #214, now merged): How we get beaten copy no longer says "yet" once settled; training rows name the plan as a plan; coaching mobility verified, with assistant contracts identified as the missing layer. Evidence in `docs/PLAYTEST_AUDIT_2_2026-10-05.md`.
- **2026-10-05:** Playtest fix batch (PR #210, now merged): mid-season bye no longer enters post-season; match-up copy names both players; the quarter break shows the plan the opposition actually ran; training rows ignore scrolls; player-facing money uses compact AFL formatting. Recorded the three-game Coaching gate, week-by-week finals and Season Review scroll as already fixed on `main`.
- **2026-10-05:** Reconciled statuses for PRs closed without a direct merge. #182, #183, #185, #186, #187, #188, #191, #193, #195, #196 and #198 were carried onto `main` by the consolidated squash merge #208 (verified: their production code and tests are on `main`; #196's separate free-kick helpers were superseded by the #202 contextual-frees work in #208). Marked M2-010, M3-004, M3-005, M3-006, M3-009, M5-002, M5-011, M6-005 and M8-004 DONE; M3-008, M3-011, M5-014 and M6-008 VERIFY (balance evidence / phone playtest remain); M6-004, M7-003 and M7-005 PARTIAL. Recorded #118 and #120 as merged in §1.11, and collapsed the stale finish-the-stack steps in §0.4.1.
- **2026-10-05:** Playtest audits and Langford (PR #213, now merged): expansion lists no longer give seasoned players a draftee's POT ceiling (the generated-player provenance finding); season fatigue parity audited with no defect; Harvey Langford +15% attributes. Evidence in `docs/PLAYTEST_AUDIT_2026-10-05.md`.

- **2026-10-02:** Added the ultra-rare GOAT prospect concept: roughly once per 30 seasons, independent of super drafts, foreshadowed anonymously through draft whispers/Combine clues, with superstar salary and godfather-offer trade economics if he develops.

- **2026-10-02:** Added the requested SAFE roadmap batch to the existing consolidated #208 branch instead of opening another stack: League Draft career-stage filtering (M5-011) and contextual first-Hub weekly-loop onboarding completing the M8-004 menu/onboarding intent. Refreshed stale SAFE-item references: training multi-select (#192) is already merged, the milestone expansion from closed #186 is carried by #208, and Android app identity remains a device-verification item rather than new code.

- **2026-10-02:** Full progress reconciliation against current `main` plus open/merged PRs. Corrected stale statuses for M3/M5/M6/M7/M8, replaced the near-term queue with the actual merge/finish stacks, recorded GPS distance tracking (#195) as ARD-M2-010, recorded real AFL money (#198) under M6-004, and normalised several legacy compound statuses to the canonical status vocabulary.

- **2026-09-30:** Clarified AI parity as a global design rule: AI must never be psychic. It may infer and react to observable/scouted information, but must not read hidden player choices or concealed simulation state to counter the player.
- **2026-09-30:** Audit repair sprint (A–G) merged in #104–#111; statuses and measurements are in the audit appendix.

- **2026-09-29:** Merged PR #102 (real Momentum) and PR #103 (System Reality Audit). ARD-M4-010 and §1.12 are now DONE. The Current Execution Queue now starts with a user-review hold on the audit repair pass, led by the live-match plan reset and other measured no-op/questionable systems.

- **2026-09-29:** Added an authoritative Current Execution Queue so Claude does not infer priority from milestone numbering alone. The queue now finishes #102, runs the P0 System Reality Audit, closes the phone playtest gate, then moves through core match agency, football authenticity, team management, management depth, and finally flavour/polish. Added §1.12 as the canonical System Reality Audit gate after the display-only Momentum discovery.

- **2026-09-29:** Status-sync pass after merged work was allowed to drift: recorded M1-005, M1-009, M1-011, M3-010, M4-002, M4-008, M4-009, M6-002, M6-003 and M6-005 as completed; M3-003 and M7-003 as partial; and M4-010 as actively in progress on PR #102. Refreshed stale current-state notes so agents do not rebuild already-finished systems.

- **2026-09-29:** Added a very-maybe MRO flavour idea: “Spin the MRO wheel”, a tongue-in-cheek nod to footy-fan perceptions of inconsistent suspension outcomes. Presentation joke only; do not make the underlying system arbitrary.

- **2026-09-29:** Recorded a design idea for Unicorn players to act as flexible synergy wildcards. Hold for the broader synergy-system design review; avoid making Unicorn a universal automatic buff.

- **2026-09-29:** Tightened ChatGPT workflow ownership for concurrent PRs: inspect the whole open-PR set and establish merge order before merging, then re-check/sync remaining branches immediately after each merge so stale CI and preventable merge conflicts do not accumulate.

- **2026-09-29:** Extended the party-RPG lens to matches: each match is a quest/encounter testing the player's party, and emergent storytelling is a core design goal. Matches should generate legible arcs, turning points and memorable individual moments that the player can recount afterward without scripted drama.

- **2026-09-29:** Added the party-based RPG design lens: the club is the campaign, the playing group is the party, and matches test the group. Preserve simulation uncertainty while making player identity, composition, development and deployment create CRPG-like attachment and agency without literal RPG genre furniture.

- **2026-09-29:** Codified the project's game-first philosophy: realism supports believable football, but fun and meaningful player agency take precedence over simulation purity. Gamification is explicitly welcome when it makes deliberate choices materially influence outcomes.

- **2026-09-29:** Added ARD-M8-008 to replace the Android prototype identity: installed app name becomes **Aussie Rules Dynasties** and the launcher/App info icon must be purpose-built around the game's identity rather than the generic football-field placeholder.

- **2026-09-29:** Added ARD-M8-007 for cinematic tactical vignettes: prototype one high-value decision moment first using 2D/2.5D presentation, use visual detail to make the football problem legible, and explicitly keep 3D out of scope. Deferred until the §1.11 decision-clarity gate proves the underlying choices are good.
Keep this short. Add only meaningful structural changes, not every code commit.

- **2026-09-29:** Added a P0 playtest gate for core fun/readability: pause unrelated feature expansion while match freezes/stalls, implausible loose-ball waiting, opaque synergies, uninformed choices and weak decision feedback are addressed. Core test is whether the player can understand a decision, form an expectation, observe the consequence and learn from it without number-vomit or best-choice hints.
- **2026-09-29:** Added ARD-M5-012 to audit/fix implausible opening League Draft AI asset valuation after Bodhi Uwland was observed going pick #1; fix the valuation model, not individual player ratings.
- **2026-09-29:** CI-waiting PRs do not count toward Claude's two-active-implementation-branch limit. Only branches being actively coded/debugged count; a branch re-enters the limit while resolving a genuine `[CI HANDOFF]` and leaves it again once pushed back to CI.
- **2026-09-28:** Added ARD-M7-008, an optional custom/self-insert draft prospect that enters the normal national draft and career ecosystem without custom OVR/potential or preferential treatment.
- **2026-09-28:** Docs-only CI optimisation: PRs/pushes that change only `docs/**` or Markdown skip the full Godot game suite; mixed docs+code changes still run it.
- **2026-09-28:** Added lean validation ownership: Claude uses targeted tests while coding; GitHub CI/ChatGPT owns the routine full-suite PR gate, log triage, selective reruns and merge verification. Avoid duplicate full-suite and long-run testing.
- **2026-09-28:** Added Phase 4 former-player coaching guidance: test ~25% pathway entry first, let generated coaches act as top-up supply, and treat low player-career turnover as a separate upstream issue rather than forcing the coaching percentage.
- **2026-09-28:** Added ARD-M5-011 for opening League Draft career-stage filters (Rookies / Prime / Veterans), with exact age cut-offs to be chosen from the actual 2027 pool distribution.
- **2026-09-28:** Added OVR calibration sanity notes: keep #47's measured pressure weighting; use Toby Greene in the low-80s as a broader-model spot-check rather than a manual patch.
- **2026-09-28:** Removed stale per-PR/phase approval gates. Claude now has standing authority to action ready roadmap work and merge clean validated PRs; supervised/balance labels are risk gates, not ceremonial user-approval gates.
- **2026-09-28:** Converted roadmap from conversation-style backlog into a canonical execution roadmap with milestones, stable task IDs, dependency ordering, global guardrails, validation matrix, balance template, Claude task prompt and duplicate map.
- **2026-09-28:** Consolidated repeated concepts including season momentum/team form, reports, opponent scouting, forward scoring, match-ups, history/records, simulation controls, AFL rules/restarters, rivalries, marquee games and secondary-position learning.


